#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
# 文件：scripts/apple_secret.py
# 模块：tool_box / 构建运维脚本
# 职责：生成并（可选）自动轮换 Supabase「Sign in with Apple」所需的 client secret。
#
# 背景 —— 为什么需要这个脚本：
#   Apple 的 OAuth 与 Google/GitHub 不同：它不发放长期静态的 client_secret，
#   而是要求你用 Apple Developer 后台下载的 .p8 私钥自己签一个 ES256 JWT，
#   当作 client_secret 交给 Supabase。Apple 硬性限制该 JWT 的
#   exp - iat <= 15777000 秒（约 182.6 天），所以最长 6 个月必然过期。
#
#   过期后：Supabase 后台不会报错、Apple 也不会提醒，只有在用户点「用 Apple
#   注册」时才会静默失败，返回 invalid_client。也就是说，这是颗定时炸弹。
#
#   本脚本用 macOS / Linux 自带的 openssl 完成 ES256 签名，除 Python 标准库
#   外零第三方依赖（不需要 pip install cryptography）。
#
# 产物用途：
#   生成出来的 JWT 填到 Supabase Dashboard → Authentication → Providers →
#   Apple → Secret Key。本脚本加 --apply 可跳过手工粘贴，直接写回 Supabase。
#
# 用法：
#   1) 把 .p8 存进 macOS 钥匙串（推荐 —— 私钥不再以明文躺在磁盘上）
#      ./scripts/apple_secret.py keychain-import --p8 ~/Downloads/AuthKey_XXXXXXXXXX.p8
#
#   2) 生成并打印（自动从钥匙串取私钥）
#      ./scripts/apple_secret.py gen \
#          --team A1B2C3D4E5 \
#          --service uk.aknot.toolbox.service
#
#   3) 检查当前生效的 secret 什么时候过期（不需要私钥，JWT 可公开解码）
#      ./scripts/apple_secret.py check --secret "eyJraWQiOi..."
#
#   4) 查询 Supabase 线上当前配置（Apple provider 是否已启用 / client id 是什么）
#      export SUPABASE_ACCESS_TOKEN="sbp_xxx"
#      ./scripts/apple_secret.py inspect
#
#   5) 生成并直接写回 Supabase（自动化轮换用）
#      export SUPABASE_ACCESS_TOKEN="sbp_xxx"
#      ./scripts/apple_secret.py gen ... --apply
#
#   敏感参数均支持环境变量，避免出现在 shell history / ps 输出里：
#     APPLE_P8_PATH / APPLE_P8_B64 / APPLE_TEAM_ID / APPLE_KEY_ID
#     APPLE_SERVICES_ID / SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_REF
#     APPLE_KEYCHAIN_ACCOUNT（钥匙串条目名，默认 default）
#
# 私钥来源优先级（先命中先用）：
#   --p8  >  APPLE_P8_PATH  >  APPLE_P8_B64  >  macOS 钥匙串
#   把 .p8 明文留在磁盘上是最薄弱的一环：一旦仓库被 clone、机器被同步备份
#   或 Time Machine 快照外泄，私钥就泄露了，而它恰恰是唯一无法重新下载的凭据。
#   放进钥匙串后：内容受 ACL + 磁盘加密保护，轮换时按需取出，用完不留盘。
#
# 关键依赖：
#   - openssl 命令行（macOS 自带 LibreSSL、Linux 自带 OpenSSL 均可）
#   - security 命令行（仅 keychain-* 用到，macOS 专用）
#   - Python 3.8+ 标准库
# ============================================================================

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------

# Apple 官方文档写死的 client_secret 受众，固定值，不要改。
APPLE_AUD = "https://appleid.apple.com"

# Apple 允许的 exp - iat 上限：15777000 秒 ≈ 182.6 天。
# 这里取 180 天留约 2.6 天缓冲，避免卡在上限被拒。
DEFAULT_TTL_SECONDS = 180 * 24 * 3600  # 15552000

# Supabase Management API 基址。
SUPABASE_API = "https://api.supabase.com/v1/projects"

# tool_box 项目的 project ref（可环境变量覆盖）。
DEFAULT_PROJECT_REF = "nfoishlluynelazgwduc"

# macOS 钥匙串中存放 .p8 的条目名。
# service 固定、account 可配：这样同一台机器上可以为多个项目各存一把私钥。
KEYCHAIN_SERVICE = "uk.aknot.toolbox.apple-p8"
DEFAULT_KEYCHAIN_ACCOUNT = "default"

# 判断 Supabase 是否对 secret 字段做了掩码的特征串。
# Management API 出于安全通常不回显明文 secret，而是返回这类占位值。
_MASK_HINTS = ("...", "•••", "***", "redacted", "masked")


# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------


def b64url_raw(data: bytes) -> str:
    """把字节序列编码成 JWT 要求的 base64url（无填充 '='）。"""
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def b64url_json(obj: dict) -> str:
    """把 dict 序列化为紧凑 JSON 再 base64url，用作 JWT 的 header / payload 段。"""
    raw = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return b64url_raw(raw)


def b64url_decode(seg: str) -> bytes:
    """解码 base64url 段，自动补齐缺失的 '=' 填充。"""
    pad = "=" * (-len(seg) % 4)
    return base64.urlsafe_b64decode(seg + pad)


def der_to_p1363(der: bytes) -> bytes:
    """把 openssl 输出的 DER 编码 ECDSA 签名转成 JWT 要求的 raw r||s（IEEE P1363）。

    openssl 的 `dgst -sign` 对 EC 密钥输出的是 ASN.1 DER：
        SEQUENCE { INTEGER r, INTEGER s }
    而 JWS ES256 规范要求的是 r 与 s 各 32 字节大端拼接（共 64 字节）。
    两者不兼容，必须手写转换——这是本脚本唯一有技术含量的地方。

    INTEGER 的编码有两个坑：
      1. 若最高位为 1，DER 会在前面多补一个 0x00（正数符号位），此时长度 33；
      2. 若高字节是 0x00，DER 会省略前导零，此时长度可能小于 32。
    所以统一按「左补零到 32 字节」处理，长度超过 32 视为异常。
    """
    if not der or der[0] != 0x30:
        raise ValueError("不是合法的 DER SEQUENCE（首字节应为 0x30）")

    # 解析 SEQUENCE 长度：支持短格式（< 0x80）与长格式（0x81/0x82 + n 字节）
    idx = 1
    if der[idx] < 0x80:
        idx += 1
    else:
        num_bytes = der[idx] & 0x7F
        idx += 1 + num_bytes

    def read_integer(pos: int) -> tuple[int, int]:
        """从 pos 处读一个 DER INTEGER，返回 (整数值的字节串起始位置, 长度)。"""
        if der[pos] != 0x02:
            raise ValueError("期望 DER INTEGER（tag 0x02）")
        length = der[pos + 1]
        return pos + 2, length

    r_start, r_len = read_integer(idx)
    s_start, s_len = read_integer(r_start + r_len)

    r = der[r_start : r_start + r_len]
    s = der[s_start : s_start + s_len]

    # 去掉 DER 为表示正数补的 0x00 前缀
    r = r.lstrip(b"\x00")
    s = s.lstrip(b"\x00")

    if len(r) > 32 or len(s) > 32:
        raise ValueError("r/s 长度超过 32 字节，不是 P-256 签名")

    # 左补零到 32 字节，拼成 64 字节的 raw r||s
    return r.rjust(32, b"\x00") + s.rjust(32, b"\x00")


def sign_es256(signing_input: bytes, p8_path: str) -> bytes:
    """用 .p8 私钥对 JWT 待签串做 ES256 签名，返回 64 字节 raw r||s。

    走 openssl 子进程而不是第三方库，保证零依赖、跨机器可移植。
    """
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp.write(signing_input)
        msg_path = tmp.name

    sig_path = msg_path + ".sig"
    try:
        with open(msg_path, "rb") as fin, open(sig_path, "wb") as fout:
            proc = subprocess.run(
                ["openssl", "dgst", "-sha256", "-sign", p8_path],
                stdin=fin,
                stdout=fout,
                stderr=subprocess.PIPE,
            )
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", "replace").strip()
            raise RuntimeError(f"openssl 签名失败（退出码 {proc.returncode}）：{err}")

        with open(sig_path, "rb") as f:
            der = f.read()
        return der_to_p1363(der)
    finally:
        # 签名文件含私钥运算结果，用完立即清理，避免留在 /tmp
        for p in (msg_path, sig_path):
            try:
                os.unlink(p)
            except OSError:
                pass


def build_client_secret(p8_path: str, team_id: str, key_id: str, services_id: str,
                        ttl: int, now: int | None = None) -> tuple[str, int, int]:
    """构造 Apple client_secret（ES256 JWT）。

    返回 (jwt, iat, exp)。

    JWT 结构：
      header  = {"alg":"ES256","kid":"<Key ID>"}
      payload = {"iss":"<Team ID>","sub":"<Services ID>","aud":"https://appleid.apple.com",
                 "iat":<签发时间>,"exp":<过期时间>}

    三个最容易填错、且填错都只报 invalid_client 的字段：
      - sub 必须是 **Services ID**，不是 App ID、也不是 bundle id；
      - kid 是 Keys 页面那个 Key ID（也可从 AuthKey_XXXX.p8 文件名推断）；
      - iss 是 Team ID（10 位），不是 App ID Prefix 以外的任何东西。
    """
    iat = now if now is not None else int(time.time())
    exp = iat + ttl

    header = {"alg": "ES256", "kid": key_id}
    payload = {
        "iss": team_id,
        "sub": services_id,
        "aud": APPLE_AUD,
        "iat": iat,
        "exp": exp,
    }

    signing_input = f"{b64url_json(header)}.{b64url_json(payload)}".encode("ascii")
    signature = sign_es256(signing_input, p8_path)
    jwt = f"{signing_input.decode('ascii')}.{b64url_raw(signature)}"
    return jwt, iat, exp


def guess_key_id(p8_path: str) -> str:
    """从 Apple 下载的文件名 AuthKey_XXXXXXXXXX.p8 推断 Key ID。

    Apple 只在下载时给这个名字，改名后就推断不出来了——此时必须显式传 --key。
    """
    name = os.path.basename(p8_path)
    if name.startswith("AuthKey_") and name.endswith(".p8"):
        return name[len("AuthKey_") : -len(".p8")]
    return ""


def fmt_time(ts: int) -> str:
    """把 Unix 时间戳格式化成本地时间字符串，便于人工核对到期日。"""
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ts))


def mask(s: str, keep: int = 6) -> str:
    """脱敏：密钥类内容只保留前 keep 位，避免整串打进终端/日志。"""
    if not s:
        return "(空)"
    return s[:keep] + "…" + f"(共 {len(s)} 字符)" if len(s) > keep else s


def looks_masked(s: str) -> bool:
    """判断一个值是不是管理平台返回的掩码（而非真实内容）。"""
    if not s:
        return True
    return any(h in s for h in _MASK_HINTS)


# ---------------------------------------------------------------------------
# macOS 钥匙串：.p8 私钥的安全存放处
# ---------------------------------------------------------------------------


def keychain_available() -> bool:
    """判断当前机器能否使用钥匙串（仅 macOS 有 security 命令）。"""
    return sys.platform == "darwin" and _which("security")


def _which(prog: str) -> bool:
    """简易 which：避免依赖 shutil.which 在不同 Python 版本上的行为差异。"""
    for d in os.environ.get("PATH", "").split(os.pathsep):
        if d and os.path.isfile(os.path.join(d, prog)):
            return True
    return False


def keychain_read(account: str) -> str:
    """从钥匙串读出 .p8 的 base64 内容；不存在返回空串。

    -w 让 security 只输出密码本身，便于脚本取值。
    失败时静默返回空串，由调用方决定是报错还是回退到其他来源。
    """
    proc = subprocess.run(
        ["security", "find-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE, "-w"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def keychain_write(account: str, b64: str) -> None:
    """把 .p8 的 base64 内容写入钥匙串。

    -U 表示「已存在则更新」，所以重复导入不会产生重复条目。
    存 base64 而不是原始 PEM：钥匙串的密码字段是单行文本，
    而 PEM 是多行的，直接塞进去会被截断。
    """
    proc = subprocess.run(
        ["security", "add-generic-password",
         "-a", account, "-s", KEYCHAIN_SERVICE, "-w", b64, "-U"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"写入钥匙串失败：{(proc.stderr or '').strip()}")


def keychain_delete(account: str) -> bool:
    """删除钥匙串中的私钥条目，返回是否删除成功。"""
    proc = subprocess.run(
        ["security", "delete-generic-password", "-a", account, "-s", KEYCHAIN_SERVICE],
        capture_output=True,
        text=True,
    )
    return proc.returncode == 0


# ---------------------------------------------------------------------------
# 子命令：check —— 解码现有 secret，看还剩多久过期
# ---------------------------------------------------------------------------


def cmd_check(args: argparse.Namespace) -> int:
    """解码一个已存在的 client_secret，输出 kid / sub / iss / 到期时间。

    JWT 的 payload 只是 base64url，本身不含机密（机密性由签名保证），
    所以可以放心地本地解码，不需要私钥，也不联网。
    """
    parts = args.secret.strip().split(".")
    if len(parts) != 3:
        print("错误：这不是一个合法的 JWT（应由两段 '.' 分成三部分）", file=sys.stderr)
        return 1

    try:
        header = json.loads(b64url_decode(parts[0]))
        payload = json.loads(b64url_decode(parts[1]))
    except Exception as exc:  # noqa: BLE001 - 解码失败统一给出可读提示
        print(f"错误：JWT 解码失败：{exc}", file=sys.stderr)
        return 1

    now = int(time.time())
    exp = int(payload.get("exp", 0))
    iat = int(payload.get("iat", 0))
    remain = exp - now

    print("=== header ===")
    print(f"  alg : {header.get('alg')}   （必须是 ES256）")
    print(f"  kid : {header.get('kid')}   （Key ID）")
    print("=== payload ===")
    print(f"  iss : {payload.get('iss')}   （Team ID，10 位）")
    print(f"  sub : {payload.get('sub')}   （Services ID，不是 bundle id）")
    print(f"  aud : {payload.get('aud')}   （必须是 {APPLE_AUD}）")
    print(f"  iat : {iat}  ->  {fmt_time(iat)}")
    print(f"  exp : {exp}  ->  {fmt_time(exp)}")

    print("=== 结论 ===")
    if remain <= 0:
        print(f"  ✗ 已过期 {abs(remain) // 86400} 天 —— 现在 Apple 登录应当报 invalid_client")
        return 2
    days = remain // 86400
    print(f"  ✓ 仍然有效，剩余 {days} 天（{remain} 秒）")
    if days < 30:
        print("  ⚠ 剩余不足 30 天，建议尽快轮换")
    return 0


# ---------------------------------------------------------------------------
# 子命令：gen —— 生成新 secret，可选写回 Supabase
# ---------------------------------------------------------------------------


def _read_dev_env_p8() -> str:
    """兜底：从仓库内 local/env/dev.json 读取 APPLE_P8_B64。

    这样即便没有设 APPLE_P8_B64 环境变量、也没导入钥匙串，
    只要 dev.json 里填了私钥 base64，脚本也能直接签名（与 rotate.sh 共用同一密钥源）。
    """
    try:
        here = os.path.dirname(os.path.abspath(__file__))
        # scripts/apple_secret.py -> ../../local/env/dev.json
        dev = os.path.join(here, "..", "local", "env", "dev.json")
        if os.path.isfile(dev):
            return json.load(open(dev, encoding="utf-8")).get("APPLE_P8_B64", "")
    except Exception:
        pass
    return ""


def resolve_p8(args: argparse.Namespace) -> str:
    """定位 .p8 私钥，按优先级依次尝试。

    1. --p8 命令行参数（rotate.sh 走这条，值取自 dev.json 的 APPLE_P8_B64 或钥匙串）
    2. APPLE_P8_PATH 环境变量 —— 手工指定 .p8 磁盘路径，CI 场景中可用
    3. APPLE_P8_B64 环境变量 —— 把私钥内容 base64 内联，适合 CI / 无文件系统的场景
       本脚本也会从 local/env/dev.json 回退读取该字段（见 _read_dev_env_p8）
    4. macOS 钥匙串 —— 明文文件的安全替代，推荐长期使用这种方式

    顺序很关键：Apple 的 .p8 只能下载一次，丢了大概率没法恢复，
    所以宁可早点报错，也不要静默地用一个不存在的路径继续往下跑。
    """
    if args.p8 and os.path.isfile(args.p8):
        return args.p8

    env_path = os.environ.get("APPLE_P8_PATH", "")
    if env_path and os.path.isfile(env_path):
        return env_path

    b64 = os.environ.get("APPLE_P8_B64", "") or _read_dev_env_p8()
    if not b64 and keychain_available():
        account = os.environ.get("APPLE_KEYCHAIN_ACCOUNT", "") or DEFAULT_KEYCHAIN_ACCOUNT
        b64 = keychain_read(account)
        if b64:
            print(f"--- 私钥来源：macOS 钥匙串（service={KEYCHAIN_SERVICE}, account={account}）",
                  file=sys.stderr)

    if b64:
        # 从环境变量/钥匙串还原成临时文件，用完由调用方在进程结束时自动清理
        fd, path = tempfile.mkstemp(prefix="AuthKey_", suffix=".p8")
        with os.fdopen(fd, "wb") as f:
            f.write(base64.b64decode(b64))
        return path

    hint = ""
    if keychain_available():
        hint = ("\n      也可以先导入钥匙串：\n"
                "        ./scripts/apple_secret.py keychain-import --p8 <你的.p8 路径>")
    print(
        "错误：找不到 .p8 私钥。请用 --p8 指定路径，或设置 APPLE_P8_B64 环境变量。"
        + hint
        + "\n      Apple 的 .p8 只能下载一次，丢了只能去后台 revoke 后重建。",
        file=sys.stderr,
    )
    sys.exit(1)


def cmd_gen(args: argparse.Namespace) -> int:
    p8_path = resolve_p8(args)
    team_id = args.team or os.environ.get("APPLE_TEAM_ID", "")
    services_id = args.service or os.environ.get("APPLE_SERVICES_ID", "")
    key_id = args.key or os.environ.get("APPLE_KEY_ID", "") or guess_key_id(p8_path)

    # 参数自检：这三个值填错都不会在生成时报错，只会在真机登录时报 invalid_client
    missing = [
        name
        for name, val in (("--team / APPLE_TEAM_ID", team_id),
                          ("--service / APPLE_SERVICES_ID", services_id),
                          ("--key / APPLE_KEY_ID", key_id))
        if not val
    ]
    if missing:
        print(f"错误：缺少必填参数 -> {', '.join(missing)}", file=sys.stderr)
        return 1

    if not os.path.isfile(p8_path):
        print(f"错误：私钥文件不存在：{p8_path}", file=sys.stderr)
        return 1

    jwt, iat, exp = build_client_secret(
        p8_path=p8_path,
        team_id=team_id,
        key_id=key_id,
        services_id=services_id,
        ttl=args.ttl,
    )

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(jwt)
        os.chmod(args.out, 0o600)
        print(f"✓ 已写入文件（权限 600）：{args.out}")
    else:
        print(jwt)

    print(f"--- iat {iat} ({fmt_time(iat)})", file=sys.stderr)
    print(f"--- exp {exp} ({fmt_time(exp)})，有效期 {(exp - iat) // 86400} 天", file=sys.stderr)
    print(f"--- kid={key_id}  sub={services_id}（sub 必须是 Services ID）", file=sys.stderr)

    if args.apply:
        return apply_to_supabase(jwt, args)
    return 0


def apply_to_supabase(jwt: str, args: argparse.Namespace) -> int:
    """通过 Supabase Management API 把新 secret 直接写回项目配置。

    注意：这是 **项目级** 配置接口，不是数据库接口；
    用的 token 必须是 https://supabase.com/dashboard/account/tokens 生成的
    个人 access token，anon key / service_role key 都没有权限。
    """
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    ref = args.ref or os.environ.get("SUPABASE_PROJECT_REF", "") or DEFAULT_PROJECT_REF

    if not token:
        print(
            "错误：未设置 SUPABASE_ACCESS_TOKEN，无法自动写回。\n"
            "      获取地址：https://supabase.com/dashboard/account/tokens\n"
            "      或者不加 --apply，把上面的 JWT 手工粘到 Dashboard 的 Secret Key 里。",
            file=sys.stderr,
        )
        return 1

    body = json.dumps(
        {
            "external_apple_enabled": True,
            "external_apple_client_id": args.service or os.environ.get("APPLE_SERVICES_ID", ""),
            "external_apple_secret": jwt,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        f"{SUPABASE_API}/{ref}/config/auth",
        data=body,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "tool_box-apple-secret-rotator",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        print(f"✓ 已写回 Supabase 项目 {ref}", file=sys.stderr)
        # 响应会回显 secret，做脱敏再打印，避免整串进终端
        if isinstance(data, dict) and data.get("external_apple_secret"):
            data["external_apple_secret"] = mask(str(data["external_apple_secret"]))
        print(json.dumps(data, ensure_ascii=False, indent=2)[:800], file=sys.stderr)
        return 0
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:500]
        print(f"✗ 写回失败 HTTP {exc.code}：{detail}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"✗ 写回失败：{exc}", file=sys.stderr)
        return 1


def _api_get(ref: str, token: str) -> dict:
    """调用 Supabase Management API 读取项目 auth 配置。"""
    req = urllib.request.Request(
        f"{SUPABASE_API}/{ref}/config/auth",
        method="GET",
        headers={
            "Authorization": f"Bearer {token}",
            "User-Agent": "tool_box-apple-secret-rotator",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def cmd_inspect(args: argparse.Namespace) -> int:
    """查询 Supabase 线上当前的 Apple provider 配置。

    用途：确认「Secret Key 到底是填了还是空着」「Client IDs 顺序对不对」，
    以及——如果 API 愿意回显明文——直接算出还剩几天过期。

    注意：多数情况下 Management API 出于安全不会回显 secret 原文，
    而是返回掩码；此时到期日只能靠本地状态文件（.apple_secret_last）推算。
    """
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    ref = args.ref or os.environ.get("SUPABASE_PROJECT_REF", "") or DEFAULT_PROJECT_REF

    if not token:
        print(
            "错误：未设置 SUPABASE_ACCESS_TOKEN，无法查询线上配置。\n"
            "      获取地址：https://supabase.com/dashboard/account/tokens",
            file=sys.stderr,
        )
        return 1

    try:
        data = _api_get(ref, token)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:500]
        print(f"✗ 查询失败 HTTP {exc.code}：{detail}", file=sys.stderr)
        if exc.code == 401:
            print("  token 无效或已过期，请重新生成。", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"✗ 查询失败：{exc}", file=sys.stderr)
        return 1

    enabled = data.get("external_apple_enabled")
    client_ids = data.get("external_apple_client_id")
    secret = data.get("external_apple_secret")

    print(f"项目 ref        : {ref}")
    print(f"Apple 已启用    : {enabled}")
    print(f"Client IDs      : {client_ids or '(未设置)'}")

    # Client IDs 允许填多个（native bundle id + web Services ID），
    # 但 GoTrue 的 web OAuth 只取第一项，顺序错了会导致「iOS 正常、网页挂」。
    if client_ids and "," in str(client_ids):
        first = str(client_ids).split(",")[0].strip()
        print(f"  └ web 实际使用第一项：{first}")
        print("    若这一项不是 Services ID，网页端登录会被 Apple 拒绝。")

    if not secret:
        print("Secret Key      : (未设置) —— Apple 登录现在必定失败")
        return 0

    if looks_masked(str(secret)):
        print(f"Secret Key      : {secret}  （平台已掩码，无法解析到期日）")
        print("  → 到期日请用本地记录推算：./scripts/apple_secret_rotate.sh status")
        return 0

    # 极少数情况下能拿到明文，顺手解析到期时间
    print(f"Secret Key      : {mask(str(secret))}")
    parts = str(secret).split(".")
    if len(parts) == 3:
        try:
            payload = json.loads(b64url_decode(parts[1]))
            exp = int(payload.get("exp", 0))
            remain = exp - int(time.time())
            print(f"  └ 到期：{fmt_time(exp)}", end="  ")
            if remain <= 0:
                print("✗ 已过期")
            else:
                print(f"✓ 剩余 {remain // 86400} 天")
        except Exception:  # noqa: BLE001 - 解析失败不影响主流程
            pass
    return 0


def cmd_keychain_import(args: argparse.Namespace) -> int:
    """把 .p8 私钥导入 macOS 钥匙串，并可选删除磁盘上的明文文件。

    这是「自动管理」里最重要的一步：.p8 是整套体系里唯一无法补领的凭据，
    明文躺在磁盘上时，一次仓库误提交 / 备份外泄就永久失守。
    导入后脚本在需要签名时才临时取出，用完立即删除临时文件。
    """
    if not keychain_available():
        print("错误：钥匙串功能仅支持 macOS（依赖 security 命令）。\n"
              "      Linux / CI 请改用 APPLE_P8_B64 环境变量。", file=sys.stderr)
        return 1

    p8_path = args.p8 or os.environ.get("APPLE_P8_PATH", "")
    if not p8_path:
        print("错误：请用 --p8 指定 .p8 文件路径。", file=sys.stderr)
        return 1
    if not os.path.isfile(p8_path):
        print(f"错误：文件不存在：{p8_path}", file=sys.stderr)
        return 1

    raw = open(p8_path, "rb").read()
    # 基本校验：Apple 给的私钥是 PKCS#8 格式的 EC 私钥。
    # 提前拦一道，避免把错误文件（比如 .cer / 文本说明）存进钥匙串后难以排查。
    text = raw.decode("utf-8", "replace")
    if "BEGIN PRIVATE KEY" not in text:
        print("错误：这不像一个 .p8 私钥（缺少 '-----BEGIN PRIVATE KEY-----'）。\n"
              "      请确认下载的是 Keys 页面生成的 AuthKey_XXXXXXXXXX.p8。",
              file=sys.stderr)
        return 1

    account = (args.account or os.environ.get("APPLE_KEYCHAIN_ACCOUNT", "")
               or DEFAULT_KEYCHAIN_ACCOUNT)
    b64 = base64.b64encode(raw).decode("ascii")

    try:
        keychain_write(account, b64)
    except RuntimeError as exc:
        print(f"✗ {exc}\n  若系统弹窗被拒绝，请重新执行并点「允许」。", file=sys.stderr)
        return 1

    # 回读校验：写入成功不等于内容正确，读回来比对一次才敢删源文件
    back = keychain_read(account)
    if back != b64:
        print("✗ 写入后回读不一致，已中止（源文件未删除）。", file=sys.stderr)
        return 1

    print(f"✓ 已导入钥匙串：service={KEYCHAIN_SERVICE}  account={account}")
    print(f"  私钥长度：{len(raw)} 字节（base64 后 {len(b64)} 字符）")

    if args.delete_source:
        os.unlink(p8_path)
        print(f"✓ 已删除明文文件：{p8_path}")
    else:
        print(f"\n建议确认无误后手动删除明文文件：rm -f \"{p8_path}\"")
        print("（.p8 只能下载一次，删前请确认钥匙串里已能正常读回）")
    return 0


def cmd_keychain_delete(args: argparse.Namespace) -> int:
    """从钥匙串移除私钥条目（换 key / 弃用 Apple 登录时用）。"""
    if not keychain_available():
        print("错误：仅 macOS 支持。", file=sys.stderr)
        return 1
    account = (args.account or os.environ.get("APPLE_KEYCHAIN_ACCOUNT", "")
               or DEFAULT_KEYCHAIN_ACCOUNT)
    if keychain_delete(account):
        print(f"✓ 已删除钥匙串条目：account={account}")
        return 0
    print(f"未找到条目或删除失败：account={account}", file=sys.stderr)
    return 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="apple_secret.py",
        description="生成 / 轮换 Supabase「Sign in with Apple」的 client secret（ES256 JWT，最长 6 个月）",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    # --- gen ---
    g = sub.add_parser("gen", help="生成新的 client secret")
    g.add_argument("--p8", help="Apple 下载的 AuthKey_XXXXXXXXXX.p8 路径")
    g.add_argument("--team", help="Apple Team ID（10 位）")
    g.add_argument("--key", help="Apple Key ID（省略则从 .p8 文件名推断）")
    g.add_argument("--service", help="Apple Services ID（不是 bundle id）")
    g.add_argument("--ttl", type=int, default=DEFAULT_TTL_SECONDS,
                   help=f"有效期秒数，默认 {DEFAULT_TTL_SECONDS}（180 天）")
    g.add_argument("--out", help="写入文件（权限 600）而非打印到 stdout")
    g.add_argument("--apply", action="store_true", help="生成后直接写回 Supabase（需 SUPABASE_ACCESS_TOKEN）")
    g.add_argument("--ref", help="Supabase project ref，默认取 tool_box 的 ref")
    g.set_defaults(func=cmd_gen)

    # --- check ---
    c = sub.add_parser("check", help="解码已有 secret，查看过期时间")
    c.add_argument("--secret", required=True, help="现有的 client secret JWT")
    c.set_defaults(func=cmd_check)

    # --- inspect ---
    i = sub.add_parser("inspect", help="查询 Supabase 线上当前的 Apple 配置")
    i.add_argument("--ref", help="Supabase project ref，默认取 tool_box 的 ref")
    i.set_defaults(func=cmd_inspect)

    # --- keychain-import ---
    k = sub.add_parser("keychain-import", help="把 .p8 私钥存入 macOS 钥匙串")
    k.add_argument("--p8", help="AuthKey_XXXXXXXXXX.p8 路径")
    k.add_argument("--account", help=f"钥匙串条目名，默认 {DEFAULT_KEYCHAIN_ACCOUNT}")
    k.add_argument("--delete-source", action="store_true",
                   help="导入并回读校验通过后，删除磁盘上的明文 .p8")
    k.set_defaults(func=cmd_keychain_import)

    # --- keychain-delete ---
    kd = sub.add_parser("keychain-delete", help="从钥匙串移除私钥条目")
    kd.add_argument("--account", help=f"钥匙串条目名，默认 {DEFAULT_KEYCHAIN_ACCOUNT}")
    kd.set_defaults(func=cmd_keychain_delete)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
