#!/usr/bin/env python3
# ============================================================================
# 文件：tool_box/scripts/smoke_signup.py
# 职责：不开 App，直接在命令行验证「邮箱注册 → 触发器同步 → 读视图」整条链路
#
# 用法：
#   # ① 默认：走 anon 注册端点（会消耗一封验证邮件额度）
#   python3 scripts/smoke_signup.py
#
#   # ② 推荐（开发期）：用 service_role 直建「已确认」用户，完全绕开发信限流
#      service_role key 统一收口在 local/env/dev.json（见下方「安全红线」说明）
#   python3 scripts/smoke_signup.py --mode admin
#
#   # ③ 只做登录探针 + 读视图，不建号（0 邮件消耗，适合反复验）
#   python3 scripts/smoke_signup.py --mode probe --email a@b.com --password 'xxx'
#
#   # ④ 清理测试账号
#   python3 scripts/smoke_signup.py --mode cleanup --email smoke_xxx@example.com
#
#   # ⑤ 复位演示账号的资料（昵称回邮箱前缀、头像清空）。
#      integration_test 的阶段 4 断言昵称 = 邮箱前缀，一旦被改脏就跑不过，
#      跑集成测试前先执行这条复位。
#   python3 scripts/smoke_signup.py --mode reset --email demouser@example.com
#
# ----------------------------------------------------------------------------
# ★ 为什么要有 --mode admin（这是本脚本存在的最大理由）
#
#   Supabase 免费版内置 SMTP 限流极狠（约 2~3 封/小时），而且**限流时账号根本
#   不会创建** —— 注册接口先回 429 over_email_send_rate_limit，auth.users 里
#   一行都没有。于是「注册 → 触发器 → public.users → 视图」这条链路在免费版上
#   天然验不了，只能干等或手动去关 Confirm email。
#
#   Admin API（POST /auth/v1/admin/users + email_confirm:true）是官方给服务端
#   用的建号口子：不触发邮件、直接把 email_confirmed_at 填上、并且**同样会触发
#   auth.users 上的 after insert 触发器**。所以它能一次验完：
#     ① 触发器 on_auth_user_created 有没有把行同步到 public.users
#     ② 视图 user_profiles 列齐不齐、RLS 让不让自己读
#     ③ ProfilPage 那条查询到底通不通
#
# ----------------------------------------------------------------------------
# ★ service_role key 的安全红线（务必读完再操作）
#
#   · 这个 key **绕过 RLS**，等同于数据库管理员，泄露 = 全库裸奔。
#   · 绝对 **不要** 写进 tool_box/local/env/prd.json —— 那个文件是给
#     `--dart-define-from-file=local/env/prd.json` 用的，整份会被注入构建流程。
#     本脚本刻意不从 local/env/prd.json 读取 service_role key，只认下面三处。
#   · 推荐存放位置：local/env/dev.json（已在 .gitignore 忽略，集中存放所有服务端密钥）；
#     次选 shell 环境变量，最不推荐命令行参数（会留在 shell history）。
#     注意 dev.json 与 prd.json 的分工：prd.json 打进 App 构建、dev.json 绝不进构建。
#
# ----------------------------------------------------------------------------
# ★ email_confirm 的两种开关语义（容易搞反）
#
#   GoTrue 的 signup 请求体里也可以带 `email_confirm`，但**只有 service_role
#   才有资格置 true**；用 anon key 带这个字段会被静默忽略（服务端按项目配置
#   的 mailer_autoconfirm 走）。所以「用 anon key + email_confirm 绕限流」
#   这条路是不通的，别浪费时间试。
#
# 副作用：会在 auth.users 里建一个测试账号，跑完默认自动删除（--keep 可保留）。
# ============================================================================

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

# anon key / URL（打进 App 构建用的 prd.json，不含任何敏感服务端密钥）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(os.path.dirname(SCRIPT_DIR), 'local/env/prd.json')
# service_role key 的落盘位置：统一收口到 local/env/dev.json（所有服务端密钥集中于此）。
# 它不被 --dart-define-from-file 注入，关键是绝不进 App 构建。
DEV_ENV_PATH = os.path.join(os.path.dirname(SCRIPT_DIR), 'local/env/dev.json')
# dev.json 存在但没读出 service_role key 时的诊断文案，由 load_service_key 填
LOCAL_SECRET_HINT = ''

# 判定「邮件发不出去」的错误码。这两种都意味着账号根本没建。
EMAIL_BLOCKED_CODES = ('over_email_send_rate_limit', 'over_request_rate_limit')


def load_env(path):
    """读取 local/env/prd.json，返回 (url, anon_key)。

    刻意不做任何兜底：拿不到就直接退出并提示，
    避免带着空 key 去打接口、拿到一堆看不懂的 401。
    """
    if not os.path.exists(path):
        sys.exit(f'[FAIL] 找不到 {path}\n'
                 f'       在 local/ 下创建配置文件并填入真实值。')
    with open(path, encoding='utf-8') as f:
        cfg = json.load(f)
    url = cfg.get('SUPABASE_URL', '').rstrip('/')
    key = cfg.get('SUPABASE_ANON_KEY', '')
    if not url or not key:
        sys.exit('[FAIL] local/env/prd.json 缺 SUPABASE_URL 或 SUPABASE_ANON_KEY。')
    return url, key


def load_service_key(cli_value):
    """取 service_role key，取不到返回 None（不是报错 —— 允许降级走 anon）。

    优先级（谁先找到用谁）：--service-key > 环境变量 > local/env/dev.json。
      注意这是「查找顺序」，不等于「安全排序」。

    ★ 刻意不读 local/env/prd.json：local/env/prd.json 是给 `--dart-define-from-file` 用的，
      整份会被注入 Flutter 构建；service_role key 一旦进去，就有被打进
      App 产物的风险。本脚本只从 local/env/dev.json 取 service_role key。

    ★ 安全性排序（推荐程度，与上面的查找顺序无关）：
      local/env/dev.json  >  环境变量  >  命令行参数
      命令行参数会明文留在 shell history 里，排在查找第一位纯粹是为了
      兼容 CI 场景；日常开发请用 dev.json（已 gitignore，不进 history）。
    """
    global LOCAL_SECRET_HINT
    LOCAL_SECRET_HINT = ''

    if cli_value:
        return cli_value.strip()

    v = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
    if v:
        return v

    # dev.json 是 JSON（含 SUPABASE_SERVICE_ROLE_KEY 等所有服务端密钥），
    # 用 python 精确取单键，避免整文件读入内存被安全策略回收（沙箱会 SIGTERM）。
    if not os.path.exists(DEV_ENV_PATH):
        LOCAL_SECRET_HINT = (f'文件不存在：{DEV_ENV_PATH}\n'
                             f'       → 复制 service_role key 后执行：\n'
                             f'         python3 scripts/smoke_signup.py --save-key-from-clipboard')
        return None

    try:
        with open(DEV_ENV_PATH, encoding='utf-8') as f:
            cfg = json.load(f)
        val = (cfg.get('SUPABASE_SERVICE_ROLE_KEY') or '').strip()
    except (json.JSONDecodeError, OSError) as e:
        LOCAL_SECRET_HINT = (f'读取 {DEV_ENV_PATH} 失败：{e}\n'
                             f'       → 用 --save-key-from-clipboard 重新写入，'
                             f'或 export SUPABASE_SERVICE_ROLE_KEY=\'...\'')
        return None

    if val:
        return val

    # 文件在，但没填 service_role key
    LOCAL_SECRET_HINT = (f'{DEV_ENV_PATH} 里没有 SUPABASE_SERVICE_ROLE_KEY\n'
                         f'       → 最快的修法：复制 key 后执行\n'
                         f'         python3 scripts/smoke_signup.py --save-key-from-clipboard')
    return None


def jwt_payload(token):
    """解 JWT 的第二段（payload）为 dict，失败返回 None。

    只做 base64url 解码，**不验签** —— 这里的目的只是看 `role` / `iss` / `exp`
    帮用户判断「我是不是拿错 key 了」，不需要也不该验证签名。
    """
    parts = token.split('.')
    if len(parts) != 3:
        return None
    seg = parts[1]
    seg += '=' * (-len(seg) % 4)  # base64url 补等号
    try:
        return json.loads(base64.urlsafe_b64decode(seg.encode('utf-8')))
    except Exception:
        return None


def describe_key(token, label, project_ref):
    """打印一个 key 的「身份信息」—— role / 归属项目 / 过期时间。

    只输出元数据，**绝不打印 token 本身**（日志会被贴到聊天里）。
    """
    head = token[:8] + '...' + token[-4:] if len(token) > 16 else '（太短，不是 JWT）'
    print(f'{label}: {head}')

    p = jwt_payload(token)
    if not p:
        print('   ⚠️ 不是 JWT 结构（Supabase 的 service_role 一定是很长的 JWT；'
              '短的 sb_publishable_xxx 是新版 anon key）')
        return

    role = p.get('role')
    print(f'   role   = {role}')
    if role != 'service_role':
        print(f'   ❌ 这不是 service_role！拿成了 role={role} 的 key。'
              f'去 Project Settings → API Keys 复制 **service_role** 那一行。')
    else:
        print('   ✅ role 正确')

    # 归属项目核对：iss 形如 https://<ref>.supabase.co/auth/v1 或 legacy 的 ref 字段
    iss = str(p.get('iss') or '')
    ref = p.get('ref')
    if isinstance(ref, str) and ref:
        iss = iss or f'https://{ref}.supabase.co/auth/v1'
    m = re.search(r'https?://([^.]+)\.supabase\.(?:co|in|net)', iss)
    if m:
        got = m.group(1)
        ok = (got == project_ref)
        print(f'   项目ref = {got}  ' + ('✅ 与 local/env/prd.json 的 URL 一致' if ok
                                     else f'❌ 与 URL 的 {project_ref} 不一致 —— 拿错项目了！'))
    else:
        print(f'   iss    = {iss or "(空)"}（无法据此核对项目）')

    exp = p.get('exp')
    if isinstance(exp, (int, float)):
        left = exp - time.time()
        if left <= 0:
            print(f'   ❌ 已过期（exp={int(exp)}，{time.strftime("%Y-%m-%d", time.localtime(exp))}）')
        elif left < 86400 * 30:
            print(f'   ⚠️ 将在 {int(left / 86400)} 天后过期'
                  f'（{time.strftime("%Y-%m-%d", time.localtime(exp))}）')
        else:
            print(f'   exp    = {time.strftime("%Y-%m-%d", time.localtime(exp))}（未过期）')


def cmd_save_key_from_clipboard():
    """从系统剪贴板读取 service_role key 并写入 local/env/dev.json。

    存在意义：手动改 JSON 容易出错（key 名打错、存错目录、把其他密钥整段覆盖），
    而 `export` 会让密钥留在 shell history 里。复制后跑这一条最省事也最安全
    —— key 既不进 history，也不进对话记录。写入时只更新 SUPABASE_SERVICE_ROLE_KEY 一个字段，
    保留 dev.json 里其他服务端密钥（access token / Apple 配置等）。

    写完立刻校验 role，拿错 key 当场拦下，不用等打接口撞 401。
    """
    try:
        out = subprocess.run(['pbpaste'], capture_output=True, text=True, timeout=5)
        text = (out.stdout or '').strip()
    except FileNotFoundError:
        sys.exit('[FAIL] 找不到 pbpaste（本功能依赖 macOS 剪贴板）。\n'
                 '       手动写：把 service_role key 填进 local/env/dev.json 的 '
                 'SUPABASE_SERVICE_ROLE_KEY 字段')
    except subprocess.TimeoutExpired:
        sys.exit('[FAIL] 读剪贴板超时。')

    if not text:
        sys.exit('[FAIL] 剪贴板是空的 —— 先去 Dashboard 复制 service_role key。')

    # 两种输入都兼容：整行 "SUPABASE_SERVICE_ROLE_KEY=xxx"，或裸 token
    if '=' in text and not text.startswith('eyJ'):
        k, _, val = text.partition('=')
        if k.strip() != 'SUPABASE_SERVICE_ROLE_KEY':
            sys.exit(f'[FAIL] 剪贴板里是 {k.strip()}，不是 SUPABASE_SERVICE_ROLE_KEY。\n'
                     f'       直接复制 Dashboard 上的 key 原文即可（不要带别的内容）。')
        token = val.strip().strip('\'"')
    else:
        token = text

    # 多行内容（比如把整页 JSON 复制了）直接拒，避免写进去一堆垃圾
    if '\n' in token or len(token) < 40:
        sys.exit(f'[FAIL] 剪贴板内容不像一个 key（长 {len(token)}，含换行={chr(10) in token}）。\n'
                 f'       请只复制 service_role 那一行原文。')

    p = jwt_payload(token)
    if not p:
        sys.exit('[FAIL] 这不是 JWT。service_role 是很长的 JWT（以 eyJhbGciOi 开头）。\n'
                 '       短的 sb_publishable_xxx 是 anon key，不是这个。')
    if p.get('role') != 'service_role':
        sys.exit(f'[FAIL] 拿错 key 了 —— 它的 role 是 {p.get("role")!r}，不是 service_role。\n'
                 f'       去 Project Settings → API Keys 复制 **service_role** 那一行。')

    # 只更新 dev.json 里的 service_role 字段，保留其他服务端密钥（access token / Apple 配置等）。
    # 文件不存在则新建一个最小 JSON；存在则读改写，避免整段覆盖。
    if os.path.exists(DEV_ENV_PATH):
        try:
            with open(DEV_ENV_PATH, encoding='utf-8') as f:
                existing = json.load(f)
            if not isinstance(existing, dict):
                existing = {}
        except (json.JSONDecodeError, OSError):
            existing = {}
    else:
        existing = {}

    existing['SUPABASE_SERVICE_ROLE_KEY'] = token
    # 权限 600：只有本人可读写；先写临时文件再 rename，避免半截文件残留。
    tmp_path = DEV_ENV_PATH + '.tmp'
    with open(tmp_path, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)
        f.write('\n')
    os.replace(tmp_path, DEV_ENV_PATH)
    os.chmod(DEV_ENV_PATH, 0o600)

    print(f'[PASS] 已写入 {DEV_ENV_PATH}（权限 600，仅更新 SUPABASE_SERVICE_ROLE_KEY）')
    print('  校验结果：')
    describe_key(token, '  service_role', '(稍后按 local/env/prd.json 的 URL 核对)')
    print()
    print('接着跑：python3 scripts/smoke_signup.py --mode admin')


def request(method, url, key, payload=None, timeout=20, apikey=None):
    """统一发 HTTP 请求（GET/POST/DELETE），返回 (status, body_text)。

    把 HTTPError 也当成正常返回处理 —— 4xx 的 body 里才有真正的错误原因
    （比如 User already registered / Signups not allowed），直接抛异常就看不见了。

    ★ `apikey` 与 `Authorization` 是两个不同的东西，别混用：
        · apikey        —— 项目标识，恒为 anon/publishable key
        · Authorization —— 身份凭证：anon key（匿名）或用户 access_token（已登录）
      早期版本把二者写成同一个值，导致「拿用户 token 读视图」实际仍以 anon
      身份发出，必然撞 42501，还被误判成「视图没授权」。需要分开时显式传
      `apikey=`（默认与 key 相同，即匿名请求）。
    """
    data = json.dumps(payload).encode('utf-8') if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            'apikey': apikey or key,
            'Authorization': f'Bearer {key}',
            'Content-Type': 'application/json',
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace')
    except urllib.error.URLError as e:
        # 无 HTTP 状态码 = 网络层问题（DNS / SSL / 代理），单独标出来
        return 0, f'NETWORK_ERROR: {e.reason}'


def parse(body):
    """解析 JSON，失败返回空 dict（调用处只看字段，缺字段当 None 处理）。"""
    try:
        return json.loads(body)
    except (json.JSONDecodeError, TypeError):
        return {}


def is_email_blocked(data, body):
    """判断是否撞上「邮件发不出去」类限流。

    只看 error_code 不看 HTTP 码：429 也可能是请求太密，
    但 error_code 是权威的，两种 429 的处理方式完全不同。
    """
    code = str(data.get('error_code') or '')
    if code in EMAIL_BLOCKED_CODES:
        return True
    # 有些版本只把原因写在 msg 里，兜一层字符串匹配
    return 'email rate limit' in body.lower()


# ---------------------------------------------------------------------------
# Admin API（service_role）
# ---------------------------------------------------------------------------

def admin_create_user(url, skey, email, password):
    """用 Admin API 建一个「已确认」用户，返回 (status, data, body)。

    email_confirm=true 是关键：它直接把 email_confirmed_at 填上，
    登录接口立刻能给 access_token，不需要点验证链接、不发任何邮件。
    """
    return request(
        'POST', f'{url}/auth/v1/admin/users', skey,
        {'email': email, 'password': password, 'email_confirm': True},
    )


def admin_find_by_email(url, skey, email):
    """按邮箱查 Admin 用户列表，返回 user 对象或 None。

    Admin 列表接口是分页的，测试账号量很小，取第一页（默认 50 条）足够。
    用于 cleanup 模式：用户只记得邮箱、不记得 uid 时反查。
    """
    st, body = request('GET', f'{url}/auth/v1/admin/users?page=1&per_page=50', skey)
    if st != 200:
        return None, st, body
    data = parse(body)
    users = data.get('users') if isinstance(data, dict) else data
    for u in (users or []):
        if (u.get('email') or '').lower() == email.lower():
            return u, st, body
    return None, st, body


def admin_delete_user(url, skey, uid):
    """删除测试账号。auth.users 删掉后 public.users 会按外键级联删除。"""
    return request('DELETE', f'{url}/auth/v1/admin/users/{uid}', skey)


# ---------------------------------------------------------------------------
# 通用步骤
# ---------------------------------------------------------------------------

def probe_login(url, key, email, password):
    """登录探针：判断账号到底建没建，并顺带取 access_token。

    为什么需要它：
      注册接口在「已建号但发不出验证邮件」时也可能返回 429/200，
      单看注册响应分不清账号建没建。用登录接口反查一次即可确认：
        · 200 + access_token        → 已建且已验证
        · 400 email_not_confirmed   → 已建但未验证（触发器应该已经跑过）
        · 400 invalid_credentials   → 账号没建成功
    登录不消耗邮件额度，可以随便重试。
    """
    st, body = request(
        'POST', f'{url}/auth/v1/token?grant_type=password',
        key, {'email': email, 'password': password},
    )
    data = parse(body)
    return st, data, body


def report_login_probe(st, data, body):
    """把登录探针结果翻译成人话。返回是否拿到了 access_token。"""
    code = str(data.get('error_code') or data.get('msg') or body[:120])
    if st == 200 and data.get('access_token'):
        print('  [PASS] 登录成功 → 账号已建且已验证')
        return True
    if 'email_not_confirmed' in code:
        print('  [PASS] 账号已建（未验证）→ 触发器 on_auth_user_created 应该已经跑过，')
        print('         去 SQL Editor 查 public.users 应能看到这一行。')
        return False
    if 'invalid_credentials' in code or 'invalid_login' in code:
        print('  [FAIL] 账号没建成功（invalid_credentials）—— 注册那步真的失败了')
        return False
    print(f'  未预期：HTTP {st} / {code}')
    return False


def check_profile_read(url, key, token, uid):
    """按 ProfilePage 的实际请求读一次 `user_profiles` 视图并判读结果。

    为什么单独验这一步：
      匿名 key 已经被建表脚本收掉了权限，用 anon 探视图永远是 42501，
      看不出「视图不存在」和「视图存在但我没权限」的区别。
      只有拿到用户 token 才能真正验证 App 端那条链路通不通。
    """
    print('-' * 60)
    print('会员资料读取（复刻 ProfilePage 的实际请求）：')
    # 与 Dart 侧一致：from('user_profiles').select().eq('id', uid)
    query = f'{url}/rest/v1/user_profiles?id=eq.{uid}&select=*'
    print(f'  GET {query}（apikey=anon / Authorization=用户 token）')
    # ★ 必须分开传：Authorization 用用户 token 才是 authenticated 身份，
    #   apikey 仍用 anon（与 supabase_flutter 客户端行为一致）。
    st, body = request('GET', query, token, apikey=key)
    if st == 0:
        print(f'  [FAIL] 网络层失败：{body}')
        return
    if st == 200:
        try:
            rows = json.loads(body)
        except json.JSONDecodeError:
            print(f'  [FAIL] 响应不是 JSON：{body[:200]}')
            return
        if not rows:
            print('  [WARN] 200 但 0 行 → 视图可读，但 public.users 还没有这一行。')
            print('         原因多半是 handle_new_user 触发器没跑或还没落库。')
            print('         App 端表现：头像/会员徽章走兜底，邮箱仍显示（不会白屏）。')
            return
        row = rows[0]
        # 只打印 App 真正用到的列，输出短一点更好读。
        for col in ('email', 'display_name', 'avatar_url',
                    'is_member', 'member_expire_at', 'is_member_active'):
            print(f'     {col:18}= {row.get(col)!r}')
        # 缺任何一列，Dart 侧解析都会静默变成 null（模型里全部做了容错），
        # 所以必须在命令行这层明确报出来。
        need = ('id', 'email', 'display_name', 'avatar_url', 'is_member_active')
        missing = [c for c in need if c not in row]
        if missing:
            print(f'  [FAIL] 视图缺列：{missing} → 补跑建表脚本第 9 段（视图定义）')
        else:
            print('  [PASS] 视图列齐全 → ProfilePage 能渲染头像 / 邮箱 / 会员状态')
            print('  [PASS] 触发器 on_auth_user_created 已把行同步到 public.users')
        return
    if 'PGRST205' in body:
        print('  [FAIL] PGRST205 → 视图 user_profiles 不存在，补跑建表脚本第 9 段')
    elif '42501' in body or st in (401, 403):
        print('  [FAIL] 权限被拒（42501）。两种可能，按顺序排查：')
        print('         ① 用了用户 token 仍被拒 → 确实缺 GRANT：')
        print('            补跑建表脚本第 9 段末尾 grant select ... to authenticated')
        print('         ② 请求其实是以 anon 身份发出的（Authorization 传成了 anon key）')
        print('            → 本脚本已修：request() 的 apikey 与 Authorization 分离，')
        print('              这里恒为「apikey=anon + Authorization=用户 token」。')
    else:
        print(f'  [FAIL] 未预期响应 HTTP {st}：{body[:300]}')


def print_manual_steps(email):
    """打印必须去 SQL Editor 做的确认步骤。"""
    print('-' * 60)
    print('下一步（必须去 SQL Editor 做，脚本原理上看不到）：')
    print("""
  -- ① 看触发器有没有把行同步过来（应多出刚才那个邮箱的一行）
  select id, email, display_name, avatar_url,
         is_member, payment_success, created_at
  from public.users
  order by created_at desc limit 5;

  -- ② 顺便确认「防提权」生效（自己试着改会员字段，应报错 42501）
  --    update public.users set is_member = true;   -- 预期被触发器拒绝

  -- ③ 清理测试账号（auth.users 删掉后 public.users 会级联删除）
  delete from auth.users where email = '%s';
""" % email)
    print('说明：①②都在 SQL Editor 里跑（走 service_role，不受 RLS 限制）。')


def print_unblock_help(has_skey):
    """撞上邮件限流时，把「怎么解开」讲清楚。"""
    print('  ── 怎么解开（两条路，任选其一）──')
    if has_skey:
        print('  [路 A · 推荐，已经能用] 用 service_role 走 Admin API：')
        print('     python3 scripts/smoke_signup.py --mode admin')
        print('     不发邮件、不受限流，且能验证触发器 + 视图（覆盖更全）。')
    elif LOCAL_SECRET_HINT:
        print(f'  [路 A · 推荐] 用 service_role 走 Admin API（本脚本 --mode admin）：')
        print('     先看一眼 dev.json 为什么没被读到：')
        print(f'       {LOCAL_SECRET_HINT}')
        print('     修好后重跑：python3 scripts/smoke_signup.py --mode admin')
    else:
        print('  [路 A · 推荐] 用 service_role 走 Admin API（本脚本 --mode admin）：')
        print('     ① Dashboard → Project Settings → API Keys → 复制 service_role（secret）')
        print('     ② 复制后直接执行：')
        print('        python3 scripts/smoke_signup.py --save-key-from-clipboard')
        print('        （自动写入 local/env/dev.json 并校验 role，key 不进 shell history）')
        print('     ③ python3 scripts/smoke_signup.py --mode admin')
        print('     ⚠️ 只放 local/env/dev.json，别写进 local/env/prd.json（会被打进 App 构建）。')
    print('  [路 B · 改平台配置] 关掉邮箱验证（生产环境别这么做）：')
    print('     Authentication → Sign In / Providers → Email → 关 Confirm email')
    print('     之后注册直接返回 session，不再发邮件。')
    print('  [路 C · 治本] 配自定义 SMTP（Authentication → Emails → SMTP Settings），')
    print('     免费版内置 SMTP 只有约 2~3 封/小时，开发期基本必撞。')


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def run_admin_mode(url, key, skey, email, password, keep):
    """Admin 建号模式：绕开发信，直建已确认用户，验完默认删除。"""
    print('模式：admin（service_role 直建已确认用户，不消耗邮件额度）')
    print('-' * 60)

    st, body = admin_create_user(url, skey, email, password)
    data = parse(body)
    uid = data.get('id')
    print(f'HTTP {st}')

    if st in (200, 201) and uid:
        print(f'[PASS] 账号已建（email_confirm=true → 无需点验证链接）')
        print(f'       user_id = {uid}')
        print(f'       email_confirmed_at = {data.get("email_confirmed_at")!r}')
        created = True
    elif st == 422 or 'already been registered' in body or 'already registered' in body:
        # 已存在不算失败：反查 uid 后继续验视图，这本来就是最常复用的路径
        print('[WARN] 该邮箱已存在 → 反查 uid 后继续验证（不重复建号）')
        found, s2, b2 = admin_find_by_email(url, skey, email)
        if not found:
            print(f'[FAIL] 列表里找不到 {email}（HTTP {s2}）：{b2[:200]}')
            return
        uid = found.get('id')
        created = False
        print(f'       user_id = {uid}')
    elif st == 401 or st == 403:
        print('[FAIL] 401/403 —— service_role key 无效，或拿成了 anon key。')
        print('       去 Project Settings → API Keys 复制 **service_role** 那一行')
        print('       （它是很长的 JWT，不是短的 publishable key）。')
        return
    else:
        print(f'[FAIL] Admin 建号失败 HTTP {st}：{body[:300]}')
        return

    # ---------------------------------------------------------------- 登录
    print('-' * 60)
    print('登录探针（拿 access_token 用于下一步读视图）：')
    s2, d2, b2 = probe_login(url, key, email, password)
    got = report_login_probe(s2, d2, b2)
    token = d2.get('access_token')

    if token and uid:
        check_profile_read(url, key, token, uid)
    else:
        print('-' * 60)
        print('会员资料读取：跳过 —— 没拿到 access_token。')
        if got is False:
            print('  上面探针已说明原因；最常见是密码不对（沿用旧测试账号的新密码）。')

    # ---------------------------------------------------------------- 清理
    if keep:
        print('-' * 60)
        print(f'保留测试账号（--keep）：{email}')
        print_manual_steps(email)
        return

    print('-' * 60)
    print('清理测试账号：')
    s3, b3 = admin_delete_user(url, skey, uid)
    if s3 in (200, 204):
        print(f'  [PASS] 已删除 {email}（public.users 会级联删除）')
    else:
        print(f'  [WARN] 删除失败 HTTP {s3}：{b3[:200]}')
        print(f'         手动清：delete from auth.users where email = \'{email}\';')
    if created:
        print('  （本次新建的账号已清理；若是复用的旧账号请自行判断是否保留）')


def run_anon_mode(url, key, skey, email, password, keep):
    """anon 注册模式：走公开注册端点，会消耗一封验证邮件额度。"""
    print('模式：anon（公开注册端点，会消耗邮件额度）')
    print('-' * 60)

    status, body = request(
        'POST', f'{url}/auth/v1/signup', key,
        {'email': email, 'password': password},
    )
    if status == 0:
        print(f'[FAIL] 网络层失败：{body}')
        print('       → 检查代理/VPN；sandbox 里 curl 需要 --noproxy \'*\'')
        return

    data = parse(body)
    if not data and status >= 400:
        print(f'[FAIL] 响应不是 JSON（HTTP {status}）：{body[:300]}')
        return

    print(f'HTTP {status}')

    # uid 需要在各分支之外可用：注册直返 session 时才有，
    # 失败分支（429 / 422）里为 None，后续步骤据此跳过。
    uid = None
    blocked = False

    if status in (200, 201):
        uid = data.get('id') or (data.get('user') or {}).get('id')
        has_session = data.get('access_token') is not None
        print('[PASS] 注册成功，Auth 端点与 anon key 均正常')
        print(f'       user_id     = {uid}')
        print(f'       返回 session = {has_session}'
              f'（false = 开了邮箱验证，符合 mailer_autoconfirm=false）')
        if not has_session:
            print('       注：没返回 session 是预期行为，去邮箱点验证链接后才会建 session。')
    elif status == 422:
        print('[WARN] 422 —— 通常是「该邮箱已注册」。')
        print('       若确认没注册过，多半是 Auth 的密码策略/邮箱域名黑名单。')
    elif status == 429:
        # 两种 429 含义完全不同，必须看 error_code 区分
        print('[WARN] 429 —— 限流：')
        print(f'       {data}')
        if is_email_blocked(data, body):
            blocked = True
            print('       → over_email_send_rate_limit：内置 SMTP 发不出验证邮件。')
            print('         ★ 关键：限流时 auth.users **一行都不会建**，')
            print('           所以后续触发器/视图全都没法验，不是代码问题。')
            print_unblock_help(bool(skey))
        else:
            print('       → over_request_rate_limit：请求太密，等几秒重跑即可。')
    elif status == 400 and 'email_address_invalid' in body:
        print('[FAIL] 400 email_address_invalid —— 邮箱格式被拒。两个高频原因：')
        print('       · 用了 .test/.invalid/.example 等保留 TLD（换成真实域名）')
        print('       · 邮箱名里带下划线 _ —— 很多校验器不接受，用数字/字母代替')
    elif status == 401:
        print('[FAIL] 401 —— anon key 无效，或 key 与 URL 不属于同一个项目。')
    else:
        print(f'[FAIL] 未预期状态码。响应：{body[:300]}')
        return

    # ---------------------------------------------------------------- 登录探针
    print('-' * 60)
    print('登录探针（判断账号到底建没建，不消耗邮件额度）：')
    s2, d2, b2 = probe_login(url, key, email, password)
    report_login_probe(s2, d2, b2)

    # ------------------------------------------------- 会员资料读取（App 同款请求）
    # token 来源优先级：注册直返（关了邮箱验证）> 登录探针返回。
    # 两个都拿不到说明开着邮箱验证且账号未验证 —— 此时 anon 又读不了视图，
    # 这步只能等关掉 Confirm email、或改用 admin 模式后才能验。
    token = data.get('access_token') or d2.get('access_token')
    read_uid = uid or (d2.get('user') or {}).get('id')
    if token and read_uid:
        check_profile_read(url, key, token, read_uid)
    else:
        print('-' * 60)
        print('会员资料读取：跳过 —— 没拿到 access_token。')
        if blocked and skey:
            print('  ★ 已检测到 service_role key，直接重跑即可验完这条链路：')
            print('      python3 scripts/smoke_signup.py --mode admin '
                  f'--email {email} --password \'{password}\'')
        elif blocked:
            print('  → 见上面的「怎么解开」，选一条路后再重跑本脚本。')
        else:
            print('  开着邮箱验证时注册只返回「已建号待验证」，不返回 token；')
            print('  而 anon 又被收掉了读权限，所以 anon 模式原理上验不了这一步。')

    print('-' * 60)
    if keep:
        print_manual_steps(email)
    else:
        print('清理：anon key 无权删号，测试账号需手动清 ——')
        print(f"  delete from auth.users where email = '{email}';")
        print('（或用 --mode cleanup 走 Admin API 删）')


def run_probe_mode(url, key, email, password):
    """只做登录探针 + 读视图，不建号、不发邮件，适合反复验证。"""
    print('模式：probe（只登录，不建号，0 邮件消耗）')
    if not email or not password:
        sys.exit('[FAIL] probe 模式必须同时给 --email 和 --password。')
    print('-' * 60)
    st, data, body = probe_login(url, key, email, password)
    got = report_login_probe(st, data, body)
    uid = (data.get('user') or {}).get('id')
    token = data.get('access_token')
    if token and uid:
        check_profile_read(url, key, token, uid)
    elif not got:
        print('-' * 60)
        print('会员资料读取：跳过（没拿到 token）。')


def run_cleanup_mode(url, skey, email):
    """按邮箱删除测试账号。"""
    print('模式：cleanup')
    if not skey:
        sys.exit('[FAIL] cleanup 需要 service_role key：'
                 'export SUPABASE_SERVICE_ROLE_KEY=\'...\'')
    print('-' * 60)
    found, st, body = admin_find_by_email(url, skey, email)
    if not found:
        print(f'[WARN] 没找到 {email}（HTTP {st}）：{body[:200]}')
        return
    uid = found.get('id')
    s3, b3 = admin_delete_user(url, skey, uid)
    if s3 in (200, 204):
        print(f'[PASS] 已删除 {email}（uid={uid}）')
    else:
        print(f'[FAIL] 删除失败 HTTP {s3}：{b3[:200]}')


def reset_user_profile(url, skey, uid, display_name, avatar_url=None):
    """把 public.users 的一行资料复位成基线值，返回 (status, body)。

    为什么要走 PATCH 而不是 upsert：reset 是「改已有行」，PATCH 语义更准，
    且不会在 uid 写错时凭空插一行脏数据（upsert 会）。

    ★ 字段选择的红线（改这里之前务必读一遍）：
      users_before_update 触发器会拒绝 is_member / member_expire_at /
      payment_* 的任何变动并抛 42501。PostgREST 只为 payload 里出现的列生成
      UPDATE，所以这里**只带 display_name 与 avatar_url 两个字段**，
      就不会误触触发器。updated_at 由触发器自己维护，不要手写。
    """
    return request(
        'PATCH',
        f'{url}/rest/v1/users?id=eq.{uid}',
        skey,
        {
            'display_name': display_name,
            # 传 None 会序列化成 JSON null —— PostgREST 据此把列清空，
            # 这正是「复位头像」想要的效果（回到触发器建号时的初始状态）。
            'avatar_url': avatar_url,
        },
    )


def run_reset_mode(url, skey, email, name=None):
    """把演示账号的资料复位到基线（昵称 = 邮箱前缀，头像清空）。

    ── 为什么需要这个模式（集成测试的血泪坑）────────────────────────────
      integration_test/app_test.dart 的阶段 4 会断言「已登录态展示昵称
      demouser」—— 这个值来自建号触发器 `on_auth_user_created` 自动填的
      邮箱前缀，触发器**只在 INSERT 时填一次**，之后被覆盖就再也不会回来。

      而演示账号是 `--mode admin --keep` 建出来的**长期保留账号**，
      于是任何一次「改了昵称但没改回」的中断（测试中途失败、手工探针、
      拿真 token 复刻 upsert 验链路）都会留下脏数据，
      下一次跑集成测试就会挂在阶段 4，报：
          Found 0 widgets with text "demouser"
      看起来像功能坏了，实际只是演示账号的昵称被改成了 probe_name。

      所以复位能力必须固化成脚本，而不是每次手写 SQL：
        跑集成测试前若阶段 4 红了，先跑本模式，再重跑测试。
    """
    print('模式：reset（复位演示账号资料到基线）')
    if not skey:
        sys.exit('[FAIL] reset 需要 service_role key：'
                 'export SUPABASE_SERVICE_ROLE_KEY=\'...\' 或写入 local/env/dev.json')
    print('-' * 60)

    found, st, body = admin_find_by_email(url, skey, email)
    if not found:
        print(f'[FAIL] 没找到 {email}（HTTP {st}）：{body[:200]}')
        print('       → 演示账号可能已被清理，用 --mode admin --keep 重建一个。')
        return
    uid = found.get('id')

    # 不传 --name 时按触发器规则推导：取邮箱 @ 前面的部分。
    # 必须与建号触发器 on_auth_user_created 的 fill 规则保持一致，
    # 否则复位出来的值和测试期望值还是对不上。
    target_name = name or email.split('@')[0]
    print(f'目标账号 : {email}（uid={uid}）')
    print(f'复位昵称 : {target_name}')
    print('复位头像 : 清空（回到建号时的 null）')

    st2, body2 = reset_user_profile(url, skey, uid, target_name)
    if st2 in (200, 204):
        print(f'[PASS] 资料已复位（HTTP {st2}）')
    elif st2 == 0:
        print(f'[FAIL] 网络层失败：{body2}')
        print('       → 检查代理/VPN；sandbox 里 curl 需要 --noproxy \'*\'')
        return
    else:
        print(f'[FAIL] 复位失败 HTTP {st2}：{body2[:300]}')
        if st2 == 42501:
            print('       → 42501：多半是 payload 里带了会员/支付相关字段，'
                  '被 users_before_update 触发器拦下。检查 reset_user_profile 的字段。')
        return

    # 复位后读回一行确认，避免「PATCH 返回 204 但什么都没改」的假成功
    # （比如 id 过滤条件写错时，PostgREST 匹配 0 行也照样返回 200/204）。
    st3, body3 = request('GET', f'{url}/rest/v1/users?id=eq.{uid}', skey)
    rows = parse(body3) if st3 == 200 else []
    if isinstance(rows, list) and rows:
        row = rows[0]
        print(f'读回确认 : display_name={row.get("display_name")!r} '
              f'avatar_url={row.get("avatar_url")!r}')
        ok = row.get('display_name') == target_name and not row.get('avatar_url')
        print('[PASS] 复位生效' if ok else '[WARN] 读回值与期望不一致，请人工核对')
    else:
        print(f'[WARN] 复位后读不回该行（HTTP {st3}）：{body3[:200]}')


def main():
    ap = argparse.ArgumentParser(
        description='Supabase 注册链路冒烟测试（支持绕过邮件限流的 admin 模式）')
    ap.add_argument('--mode', default='anon',
                    choices=('anon', 'admin', 'probe', 'cleanup', 'reset'),
                    help='anon=公开注册端点（耗邮件）；admin=service_role 直建已确认用户'
                         '（推荐，不受限流且能验触发器/视图）；probe=只登录不建号；'
                         'cleanup=删测试账号；reset=把账号资料复位到基线'
                         '（昵称=邮箱前缀、头像清空）')
    ap.add_argument('--email', default=f'smoke_{int(time.time())}@example.com',
                    help='测试邮箱，默认按时间戳生成，避免撞号。'
                         '别用 .test / .invalid 等保留 TLD —— Supabase 会判 email_address_invalid')
    ap.add_argument('--password', default='SmokeTest@12345', help='测试密码')
    ap.add_argument('--name', default=None,
                    help='仅 reset 模式：要复位成的昵称。'
                         '不给则按建号触发器规则取邮箱 @ 前缀（推荐保持默认）')
    ap.add_argument('--service-key', default=None,
                    help='service_role key。更推荐用环境变量 SUPABASE_SERVICE_ROLE_KEY，'
                         '避免出现在 shell history 里')
    ap.add_argument('--keep', action='store_true',
                    help='跑完保留测试账号（默认自动删除，仅 admin 模式生效）')
    ap.add_argument('--save-key-from-clipboard', action='store_true',
                    help='从剪贴板读 service_role key 写入 local/env/dev.json（会自动校验 role，'
                         '只更新该字段、保留其他密钥，key 不进 shell history）。macOS 专用')
    ap.add_argument('--key-info', action='store_true',
                    help='只打印已配置密钥的 role / 归属项目 / 过期时间（不打印密钥本身），'
                         '用来确认「有没有拿错 key」')
    args = ap.parse_args()

    url, key = load_env(ENV_PATH)

    # 这两个动作与注册无关，提前处理掉，免得还要先加载一堆东西
    if args.save_key_from_clipboard:
        cmd_save_key_from_clipboard()
        return
    if args.key_info:
        # 项目 ref 从 URL 主机名里取（https://<ref>.supabase.co）
        m = re.match(r'https?://([^.]+)\.', url)
        ref = m.group(1) if m else '?'
        print(f'项目 URL : {url}\n')
        describe_key(key, 'anon / publishable', ref)
        print()
        skey = load_service_key(args.service_key)
        if skey:
            describe_key(skey, 'service_role', ref)
        else:
            print('service_role: 未配置')
            if LOCAL_SECRET_HINT:
                print('   ' + LOCAL_SECRET_HINT.replace('\n', '\n   '))
        return

    skey = load_service_key(args.service_key)

    print(f'项目 URL : {url}')
    print(f'测试邮箱 : {args.email}')
    print(f'service  : {"已提供（可走 Admin API）" if skey else "未提供（只能走 anon）"}')

    if args.mode == 'admin':
        if not skey:
            print()
            print('[FAIL] admin 模式需要 service_role key。')
            print_unblock_help(False)
            sys.exit(1)
        run_admin_mode(url, key, skey, args.email, args.password, args.keep)
    elif args.mode == 'probe':
        run_probe_mode(url, key, args.email, args.password)
    elif args.mode == 'cleanup':
        run_cleanup_mode(url, skey, args.email)
    elif args.mode == 'reset':
        run_reset_mode(url, skey, args.email, name=args.name)
    else:
        run_anon_mode(url, key, skey, args.email, args.password, args.keep)


if __name__ == '__main__':
    main()
