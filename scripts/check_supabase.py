#!/usr/bin/env python3
# ============================================================================
# tool_box · Supabase 配置自检脚本
#
# 职责：
#   在不启动 App 的前提下，一次性确认「本地密钥配置」与「Supabase 服务端状态」
#   是否已经就绪，避免在真机上点了报错再回头二分排查。
#
# 检查项：
#   1. local/env/prd.json 是否存在、字段是否齐全、URL 形态是否合法
#   2. 密钥类型：解 JWT payload 判断 role 是 anon 还是 service_role（安全红线）
#   3. Auth 配置：Email / Google Provider 是否启用、邮箱验证开关、是否禁注册
#   4. 业务表 public.users 是否已创建（PostgREST 探测）
#
# 使用：
#   cd tool_box
#   python3 scripts/check_supabase.py
#
# 依赖：仅 Python 标准库（urllib），无需 pip install。
#
# 注意：
#   - 全程不打印完整密钥，只输出前缀/后缀与长度。
#   - 只做只读请求，不会写入或注册任何数据。
# ============================================================================

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# local/env/prd.json 位于工程根目录下的 local/ 子目录（本脚本上级目录的 local/）
ENV_PATH = Path(__file__).resolve().parent.parent / 'local/env/prd.json'

# PostgREST 返回的错误码：
#   PGRST205 —— 表/视图不在 schema cache 中（通常意味着表不存在）
#   PGRST204 —— 列不在 schema cache 中（表存在但字段缺失，需要跑升级 SQL）
PGRST_TABLE_NOT_FOUND = 'PGRST205'
PGRST_COLUMN_NOT_FOUND = 'PGRST204'

# Postgres 原生错误码：permission denied for table xxx
# ⚠️ 2026-04-28 Supabase 破坏性变更：2026-05-30 起新建项目，public schema 里的
#    新表不再自动 GRANT 给 anon/authenticated/service_role，必须显式授权。
#    缺 GRANT 时 PostgREST 在 RLS 之前就返回 42501（而不是 PGRST205）。
#    参考：https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically
PG_PERMISSION_DENIED = '42501'

# public.users 表中我们关心的业务字段（用于判定建表脚本是否执行到位）
# 2026-09-02 新增 5 个支付字段（订单号 / 金额 / 支付时间 / 是否成功 / 收款方），
# 建表脚本升级后执行，自检会把它们一并纳入探测。
REQUIRED_COLUMNS = (
    'display_name',
    'avatar_url',
    'is_member',
    'member_expire_at',
    'payment_order_no',
    'payment_amount',
    'payment_paid_at',
    'payment_success',
    'payment_provider',
)

# 网络超时（秒）
TIMEOUT = 25

# 网络层偶发抖动（TLS 握手超时等）会导致自检误报「项目被暂停」，
# 所以对「没拿到 HTTP 状态码」的失败重试一次。
NET_RETRY = 2
RETRY_WAIT = 1.5


def _mask(secret: str) -> str:
    """把密钥脱敏成 'eyJhbG...xxxxxx' 形式，避免整串落到终端或日志里。"""
    if not secret:
        return '(空)'
    if len(secret) <= 16:
        return f'{secret[:3]}...({len(secret)}字符)'
    return f'{secret[:6]}...{secret[-6:]} (共 {len(secret)} 字符)'


def _decode_jwt_payload(token: str) -> dict:
    """解析 JWT 第二段（payload）。

    Supabase 的 anon / service_role key 都是 JWT，payload 里带：
      - role: 'anon' 或 'service_role'
      - ref : 项目 ref，应与 SUPABASE_URL 中的子域名一致
    解析失败时返回 {'_err': 原因}，调用方据此提示 key 不合法。
    """
    try:
        part = token.split('.')[1]
        # base64url 需要补齐 '=' 才能被标准 base64 解码
        part += '=' * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part))
    except Exception as exc:  # noqa: BLE001 - 这里的异常种类不重要，统一降级处理
        return {'_err': str(exc)}


def _http_get(url: str, api_key: str, bearer: str | None = None):
    """发起只读 GET 请求，返回 (状态码, 响应体字符串)。

    用 ProxyHandler({}) 显式禁用代理：部分环境（CI / 沙箱）设置了
    http_proxy，会让请求指向不可达的代理而超时。
    """
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    headers = {'apikey': api_key, 'Accept': 'application/json'}
    if bearer:
        headers['Authorization'] = f'Bearer {bearer}'
    request = urllib.request.Request(url, headers=headers, method='GET')

    # 网络层偶发抖动（TLS 握手超时等）很常见，重试一次即可消除误报。
    # 只重试「没拿到 HTTP 状态码」的情况；4xx/5xx 是服务端的真实回答，不重试。
    last_error = ''
    for attempt in range(1, NET_RETRY + 1):
        try:
            with opener.open(request, timeout=TIMEOUT) as response:
                return response.status, response.read().decode('utf-8', errors='replace')
        except urllib.error.HTTPError as exc:
            # 4xx/5xx 也携带有用的响应体（例如 PGRST205 的 JSON），照常返回
            return exc.code, exc.read().decode('utf-8', errors='replace')
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)
            if attempt < NET_RETRY:
                print(f'       （网络异常，{RETRY_WAIT} 秒后重试 {attempt}/{NET_RETRY}）')
                time.sleep(RETRY_WAIT)

    return -1, last_error


def main() -> int:
    print('=' * 62)
    print('tool_box · Supabase 配置自检')
    print('=' * 62)

    # ---------- 1. 本地密钥文件 ----------
    if not ENV_PATH.exists():
        print(f'\n[失败] 找不到 {ENV_PATH}')
        print('       请先在 local/ 下创建配置文件并填入 SUPABASE_URL 与 SUPABASE_ANON_KEY')
        return 1

    try:
        env = json.loads(ENV_PATH.read_text(encoding='utf-8'))
    except json.JSONDecodeError as exc:
        print(f'\n[失败] local/env/prd.json 不是合法 JSON: {exc}')
        return 1

    url = (env.get('SUPABASE_URL') or '').strip().rstrip('/')
    key = (env.get('SUPABASE_ANON_KEY') or '').strip()

    print('\n【1】本地密钥文件')
    print(f'  路径        : {ENV_PATH}')
    print(f'  SUPABASE_URL: {url or "(空)"}')
    print(f'  ANON_KEY    : {_mask(key)}')

    problems: list[str] = []
    if not url or not key:
        problems.append('local/env/prd.json 缺少 SUPABASE_URL 或 SUPABASE_ANON_KEY')
    if url and not (url.startswith('https://') and '.supabase.co' in url):
        problems.append(f'URL 形态异常（应为 https://<ref>.supabase.co）: {url}')
    if problems:
        for item in problems:
            print(f'  [错误] {item}')
        return 1

    # ---------- 2. 密钥类型（安全红线） ----------
    print('\n【2】密钥类型')
    payload = _decode_jwt_payload(key)
    if '_err' in payload:
        print(f'  [错误] key 不是合法 JWT: {payload["_err"]}')
        return 1

    role = payload.get('role')
    key_ref = payload.get('ref')
    url_ref = url.replace('https://', '').split('.supabase.co')[0]

    if role == 'service_role':
        print(f'  [危险] role = {role}')
        print('         这是 service_role key，会绕过 RLS 拿到全库权限，')
        print('         绝不能打进 App！请立即到控制台轮换该密钥，并改填 anon key。')
        return 1
    if role != 'anon':
        print(f'  [警告] role = {role}（预期 anon），请确认拿对了 key')

    print(f'  role        : {role} {"OK" if role == "anon" else "异常"}')
    ref_ok = bool(key_ref) and key_ref == url_ref
    print(f'  项目 ref    : key={key_ref} / url={url_ref} -> {"一致 OK" if ref_ok else "不一致！key 可能拿错项目"}')
    if not ref_ok:
        problems.append('key 与 URL 不属于同一个 Supabase 项目')

    # ---------- 3. Auth 服务端配置 ----------
    print('\n【3】Auth 配置（GET /auth/v1/settings）')
    status, body = _http_get(f'{url}/auth/v1/settings', key)
    if status != 200:
        print(f'  [失败] HTTP {status} — {body[:200]}')
        print('         常见原因：URL 写错、网络不通、项目被暂停')
        return 1

    try:
        settings = json.loads(body)
    except json.JSONDecodeError:
        print(f'  [失败] 响应不是 JSON: {body[:200]}')
        return 1

    external = settings.get('external', {})
    email_on = bool(external.get('email'))
    google_on = bool(external.get('google'))
    disable_signup = bool(settings.get('disable_signup'))
    autoconfirm = bool(settings.get('mailer_autoconfirm'))

    def flag(ok: bool) -> str:
        return 'OK  ' if ok else '未启用'

    print(f'  Email 注册      : {flag(email_on)}')
    print(f'  Google Provider : {flag(google_on)}')
    print(f'  禁止注册        : {disable_signup}（true 表示服务端关了注册）')
    print(f'  mailer_autoconfirm : {autoconfirm}'
          f'  -> 邮箱验证{"关闭（注册即登录）" if autoconfirm else "开启（注册后需去邮箱确认）"}')

    # ---------- 4. 业务表与字段探测 ----------
    # 探测原理：PostgREST 会先按 schema cache 校验 select 里的列名，
    # 列不存在时直接返回 PGRST204 —— 即使请求最终被 RLS 挡回空数组，
    # 这个校验也发生在 RLS 之前，因此匿名请求同样能判断字段是否存在。
    print('\n【4】业务表 public.users')
    table_status, table_body = _http_get(
        f'{url}/rest/v1/users?select=id&limit=1', key, bearer=key
    )

    # 建表脚本里显式 `revoke all on public.users from anon`，
    # 所以「表已建好」时，匿名探测拿到 42501 才是符合预期的健康状态。
    # 三种响应的判读：
    #   200    —— 表存在，且 anon 仍有读权限（2026-05-30 之前创建的老项目默认行为）
    #   42501  —— 表存在，但当前角色（anon）无权限 → 说明建表 SQL 已执行
    #   PGRST205 —— 表不在 schema cache 里 → 表尚未创建（或刚建好、缓存未刷新）
    if table_status == 200:
        print('  表已创建 OK（anon 仍有读权限，老项目的默认授权）')
        print('     建议：建表脚本里已 revoke anon，若已执行过脚本这里应为 42501。')
        print('     行数据仍受 RLS 保护（策略只给 authenticated，anon 查不到任何行）。')
        table_ok, anon_granted = True, True
    elif PG_PERMISSION_DENIED in table_body:
        print('  表已创建 OK（anon 已被收回权限，符合建表脚本的预期）')
        print('     说明：42501 发生在 RLS 之前，代表表存在但当前角色无权访问。')
        table_ok, anon_granted = True, False
    elif PGRST_TABLE_NOT_FOUND in table_body:
        print('  表未创建 —— 需要执行建表 SQL（见 scripts/create_users_table.sql）')
        table_ok, anon_granted = False, False
    else:
        print(f'  状态未知：HTTP {table_status} — {table_body[:200]}')
        table_ok, anon_granted = False, False

    # 表存在才需要逐字段探测；表都没有的话探测字段只会得到同一句「表不存在」
    missing_columns: list[str] = []
    if table_ok:
        if not anon_granted:
            # anon 连表都访问不了，列名校验自然也做不了（同样返回 42501）。
            # 这时改用 SQL Editor 里的验证语句 ① 确认字段。
            print('  字段探测：跳过（anon 无权限，无法用 REST 校验列名）')
            print('     请在 SQL Editor 执行建表脚本末尾「验证 ① information_schema.columns」。')
        else:
            print('  字段探测：')
            for column in REQUIRED_COLUMNS:
                col_status, col_body = _http_get(
                    f'{url}/rest/v1/users?select={column}&limit=1', key, bearer=key
                )
                if col_status == 200:
                    print(f'    OK   {column}')
                elif PGRST_COLUMN_NOT_FOUND in col_body:
                    print(f'    缺失 {column}  <- 需要执行建表/升级 SQL 补上')
                    missing_columns.append(column)
                else:
                    print(f'    未知 {column}（HTTP {col_status}）: {col_body[:120]}')
                    missing_columns.append(column)

        # ---------------------------------------------------------------------
        # 视图探测（注意原理性限制）：
        # 脚本第 9 段只把 user_profiles 授权给 authenticated / service_role，
        # 并 revoke 了 anon —— 所以**用 anon key 永远探测不到它**。
        # PostgREST 对「无任何角色权限」的对象返回 PGRST205（不是 42501），
        # 跟「视图不存在」的错误码一模一样，两者无法靠 anon key 区分。
        # 因此这里不判定「视图不存在」，只给出需要用 SQL 复核的提示。
        # ---------------------------------------------------------------------
        view_status, view_body = _http_get(
            f'{url}/rest/v1/user_profiles?select=is_member_active&limit=1',
            key, bearer=key,
        )
        if view_status == 200:
            view_ok = True
            print('  视图 user_profiles : 可访问（anon 有读权限）')
            print('     注：脚本第 9 段 revoke 了 anon，若你已执行应有权限错误；'
                  '\n         能读到说明 revoke 没跑，需补跑第 9 段')
        elif PG_PERMISSION_DENIED in view_body:
            view_ok = True
            print('  视图 user_profiles : 已创建 OK（anon 已被收回权限，符合预期）')
        else:
            # PGRST205：可能是视图真没建，也可能是 anon 无权限 —— 无法区分
            view_ok = False
            print('  视图 user_profiles : ★ anon key 无法判定（预计之中，非故障）')
            print('     视图只授权给 authenticated/service_role，anon 探测必然失败；'
                  '\n     且 PostgREST 对「无权限」和「不存在」都返回 PGRST205。')
            print('     要确认它在不在，请在 SQL Editor 跑：'
                  'scripts/verify_users_table.sql 的第 7/8/9 项')

    # ---------- 汇总 ----------
    print('\n' + '=' * 62)
    print('结论')
    print('=' * 62)

    if problems:
        for item in problems:
            print(f'  [待处理] {item}')
        return 1

    if table_ok:
        # anon key 只能证明「表存在且可读」，证明不了 GRANT / RLS / 触发器 / 视图在位。
        # 那些东西一律要回到 SQL Editor 查，所以这里把用户直接引到体检脚本。
        print('  【下一步 1】跑建表体检（anon key 查不了授权/RLS/触发器，必须走 SQL）：')
        print('     SQL Editor 全选执行 → tool_box/scripts/verify_users_table.sql')
        print('     返回 12 行 PASS/FAIL，按 FAIL 项补跑 create_users_table.sql 对应段落（全段幂等）。')
        print()
        print('  【下一步 2】注册冒烟：App 里用邮箱注册一个账号，然后 SQL Editor 跑')
        print('     select id, email, is_member, payment_success from public.users order by created_at desc limit 5;')
        print('     应看到该用户 1 行，is_member=false、payment_* 全为 null。')
        print('     若注册成功但表里没这一行 → 触发器 on_auth_user_created 没建成（体检第 6 项会 FAIL）。')

    if missing_columns:
        print(f'  待处理 ⓪：public.users 缺少字段 {", ".join(missing_columns)}')
        print('           执行 tool_box/scripts/create_users_table.sql')
        print('           （脚本用 add column if not exists，旧表也能直接升级）')

    if google_on and table_ok and not missing_columns:
        print('  全部就绪：邮箱注册 + Google 登录 + 用户表（含会员字段）均已配置完成。')
        print('  下一步：真机验证（Google 登录与邮箱验证邮件无法在模拟器上完整验证）。')
        return 0

    print('  可立即验证：邮箱注册（不依赖 public.users 表，表里不同步也不影响注册）。')
    if not table_ok:
        print('  待处理 ①：执行建表 SQL')
        print('            tool_box/scripts/create_users_table.sql → 贴进 SQL Editor 执行')
        print('            建议先建表再注册；若已注册过，补数据见文档 §2.5')
    if not google_on:
        print('  待处理 ②：启用 Google Provider')
        print('            doc/tool_box_supabase_setup.md §3')
        print('            注意 OAuth 客户端类型必须选 Web application')
    return 0


if __name__ == '__main__':
    sys.exit(main())
