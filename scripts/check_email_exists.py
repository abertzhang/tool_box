#!/usr/bin/env python3
# ============================================================================
# tool_box · 邮箱存在性校验函数自检脚本
#
# 职责：
#   在**不启动 App** 的前提下，确认 scripts/sql/check_email_exists.sql 是否真的
#   在 Supabase 上生效，以及 anon（未登录）角色能否正常调用该 RPC。
#
#   忘记密码页的流程是「先查邮箱是否已注册，已注册才发信」。如果这个函数没部署
#   或没授权给 anon，App 里的表现是：随便填什么邮箱都提示「邮箱校验失败」且不发
#   信（代码刻意不降级发信）。用本脚本可以提前把这类问题挡在真机之前。
#
# 检查项：
#   1. local/env/prd.json 是否存在、字段是否齐全
#   2. 以 anon 身份调用 POST /rest/v1/rpc/check_email_exists
#      - 一个必定不存在的随机邮箱 → 期望 false
#      - 一个你指定的已注册邮箱   → 期望 true（不传则跳过该项）
#   3. 针对常见错误码给出可执行的排查建议
#
# 使用：
#   cd tool_box
#   python3 scripts/check_email_exists.py                     # 只测「不存在」分支
#   python3 scripts/check_email_exists.py you@example.com     # 同时测「已注册」分支
#
# 依赖：仅 Python 标准库（urllib），无需 pip install。
#
# 注意：
#   - 全程不打印完整密钥，只输出脱敏前缀/后缀。
#   - 只做只读调用（函数本身是 stable，不写任何数据）。
#   - ⚠️ 本脚本会读取 local/env/prd.json 里的密钥。若在你自己的终端执行没问题；
#     若在某些受限沙箱里进程被系统杀掉（SIGTERM / exit 137），那属于环境的密钥
#     防护策略，换个普通终端重跑即可。
# ============================================================================

import json
import secrets
import sys
import urllib.error
import urllib.request
from pathlib import Path

# local/env/prd.json 位于工程根目录下的 local/ 子目录（本脚本上级目录的 local/）
ENV_PATH = Path(__file__).resolve().parent.parent / 'local' / 'env' / 'prd.json'

# 被测的 RPC 名称（与 scripts/sql/check_email_exists.sql 中的函数名保持一致）
RPC_NAME = 'check_email_exists'

# 网络超时（秒）
TIMEOUT = 25

# 已知错误码 → 结论 + 处理办法
#   PGRST202 : 函数不在 PostgREST 的 schema cache 里（没建 / 没授权 / 缓存未刷新）
#   PGRST205 : 对象不在 schema cache（通常是名字写错或建到了别的 schema）
#   42501    : permission denied（缺 grant execute）
ERROR_HINTS = {
    'PGRST202': (
        '函数不在 PostgREST schema cache 里',
        [
            '① 确认 scripts/sql/check_email_exists.sql 已在 SQL Editor 整段执行；',
            '② 执行脚本末尾的 notify pgrst, \'reload schema\'; 刷新缓存（通常几秒生效）；',
            '③ 若仍失败，用 SQL 复核函数是否落在 public schema：'
            ' select n.nspname, p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace'
            ' where p.proname=\'check_email_exists\';',
        ],
    ),
    'PGRST205': (
        '对象不在 schema cache（函数名或 schema 不对）',
        [
            '确认函数建在 public schema 且名字拼写为 check_email_exists。',
        ],
    ),
    '42501': (
        'permission denied（缺 EXECUTE 授权）',
        [
            '在 SQL Editor 补跑授权段：'
            ' grant execute on function public.check_email_exists(text) to anon;',
            '再执行 notify pgrst, \'reload schema\';',
        ],
    ),
}


def _mask(secret: str) -> str:
    """把密钥脱敏成 'eyJhbG...xxxxxx' 形式，避免整串落到终端或日志里。"""
    if not secret:
        return '(空)'
    if len(secret) <= 16:
        return f'{secret[:3]}...({len(secret)}字符)'
    return f'{secret[:6]}...{secret[-6:]} (共 {len(secret)} 字符)'


def call_rpc(url: str, api_key: str, email: str):
    """以 anon 身份调用一次 RPC，返回 (状态码, 响应体文本)。

    用 ProxyHandler({}) 显式禁用代理：部分环境（CI / 沙箱）设置了 http_proxy，
    会让请求指向不可达的代理而超时，表现为「函数没部署」的假阳性。
    """
    endpoint = f'{url}/rest/v1/rpc/{RPC_NAME}'
    payload = json.dumps({'p_email': email}).encode('utf-8')
    request = urllib.request.Request(
        endpoint,
        data=payload,
        method='POST',
        headers={
            'apikey': api_key,
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        },
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=TIMEOUT) as response:
            return response.status, response.read().decode('utf-8', errors='replace')
    except urllib.error.HTTPError as exc:
        # 4xx/5xx 也带着有用的响应体（例如 PGRST202 的 JSON 详情），照常返回
        return exc.code, exc.read().decode('utf-8', errors='replace')
    except Exception as exc:  # noqa: BLE001 - 网络层异常统一降级为 (-1, 原因)
        return -1, str(exc)


def _report(label: str, expect: bool, status: int, body: str) -> bool:
    """打印单次调用结果，返回是否与期望一致。"""
    if status != 200:
        print(f'  [失败] HTTP {status} — {body[:200]}')
        for code, (title, tips) in ERROR_HINTS.items():
            if code in body:
                print(f'          诊断：{title}')
                for tip in tips:
                    print(f'            {tip}')
                break
        else:
            print('          诊断：未匹配到已知错误码，请把上面的响应体发出来一起看。')
        return False

    text = body.strip()
    # PostgREST 对 returns boolean 的函数返回裸标量：true / false
    if text == 'true':
        actual = True
    elif text == 'false':
        actual = False
    else:
        print(f'  [失败] 返回值不是布尔量：{text[:200]}')
        return False

    ok = actual == expect
    print(f'  {"OK  " if ok else "异常"} {label} → 返回 {actual}（期望 {expect}）')
    return ok


def main() -> int:
    # 命令行第一个参数：一个**确实已注册**的邮箱，用于验证 true 分支
    known_email = sys.argv[1].strip() if len(sys.argv) > 1 else ''

    print('=' * 62)
    print('tool_box · 邮箱存在性校验函数自检')
    print('=' * 62)

    # ---------- 1. 本地密钥文件 ----------
    if not ENV_PATH.exists():
        print(f'\n[失败] 找不到 {ENV_PATH}')
        print('       请先在 local/ 下创建该配置文件并填入 SUPABASE_URL 与 SUPABASE_ANON_KEY')
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

    if not url or not key:
        print('  [错误] 缺少 SUPABASE_URL 或 SUPABASE_ANON_KEY')
        return 1
    if not (url.startswith('https://') and '.supabase.co' in url):
        print(f'  [错误] URL 形态异常（应为 https://<ref>.supabase.co）: {url}')
        return 1

    # ---------- 2. 「不存在」分支 ----------
    # 用随机本地部分构造一个几乎不可能已注册的邮箱，期望返回 false。
    fake_email = f'not-registered-{secrets.token_hex(6)}@example.com'
    print('\n【2】未注册邮箱（期望 false）')
    passed = _report(fake_email, False, *call_rpc(url, key, fake_email))

    # ---------- 3. 「已注册」分支 ----------
    print('\n【3】已注册邮箱（期望 true）')
    if known_email:
        passed = _report(known_email, True, *call_rpc(url, key, known_email)) and passed
    else:
        print('  跳过：未传入邮箱参数。')
        print(f'  用法：python3 scripts/check_email_exists.py 你的已注册邮箱')
        print('  说明：不给参数时只验证 false 分支，无法证明函数真能查到已注册账号。')

    # ---------- 汇总 ----------
    print('\n' + '=' * 62)
    print('结论')
    print('=' * 62)
    if passed:
        print('  check_email_exists 已部署且对 anon 可用。')
        print('  下一步：App 里进 Forgot Password ——')
        print('    · 填未注册邮箱 → 提示「该邮箱尚未注册」且**不发信**；')
        print('    · 填已注册邮箱 → 正常发送重置邮件。')
        return 0

    print('  函数尚未就绪，请按上面的诊断提示处理。')
    print('  补充：SQL 里已含 notify pgrst 刷新缓存，若刚执行完立刻测到 PGRST202，')
    print('        等 10 秒再跑一次本脚本即可。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
