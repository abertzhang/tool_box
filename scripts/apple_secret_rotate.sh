#!/bin/bash
# ============================================================================
# 文件：scripts/apple_secret_rotate.sh
# 模块：tool_box / 构建运维脚本
# 职责：一键轮换 Supabase「Sign in with Apple」的 client secret，并可安装定时。
#
# 为什么需要轮换：
#   Apple 的 client secret 是一个自己签名的 ES256 JWT，最长只能活 6 个月。
#   过期后 Apple 不提醒、Supabase 后台不报错，只有用户点「用 Apple 注册」时
#   才会静默失败（invalid_client）——典型的静默故障，必须提前自动化。
#
#   本脚本每跑一次就重新签发一个 180 天有效期的 secret 并写回 Supabase，
#   配合 launchd 每月 1 号自动执行，就永远不会撞到过期。
#
# 用法：
#   ./scripts/apple_secret_rotate.sh rotate      # 轮换一次（生成 + 写回 Supabase）
#   ./scripts/apple_secret_rotate.sh gen-only    # 只生成并打印，不写回
#   ./scripts/apple_secret_rotate.sh status      # 看上次轮换时间和下次到期日
#   ./scripts/apple_secret_rotate.sh inspect     # 查 Supabase 线上 Apple 配置
#   ./scripts/apple_secret_rotate.sh keychain --p8 <路径>   # 私钥存入钥匙串（推荐）
#   ./scripts/apple_secret_rotate.sh install     # 安装 launchd 每月自动轮换
#   ./scripts/apple_secret_rotate.sh uninstall   # 卸载定时任务
#
# 前置：密钥统一写在 local/env/dev.json（含 APPLE_TEAM_ID / APPLE_KEY_ID /
#       APPLE_SERVICES_ID / APPLE_P8_B64 / SUPABASE_ACCESS_TOKEN）。
#       APPLE_P8_B64 是 .p8 私钥的 base64，签名脚本会自动还原为临时文件。
#
# 私钥两种存放方式，二选一：
#   A. 钥匙串（推荐）：先跑 keychain 子命令导入，dev.json 里不写 APPLE_P8_B64。
#      .p8 是唯一无法补领的凭据，明文躺在磁盘上是整套体系最薄弱的一环。
#   B. dev.json 内联：把 .p8 的 base64 写入 APPLE_P8_B64（CI / 无钥匙串环境）。
#
# 关键依赖：
#   - scripts/apple_secret.py（真正干活的签名脚本）
#   - openssl（macOS 自带 LibreSSL 即可）
#   - security（仅 keychain 子命令用到，macOS 专用）
#   - launchctl（仅 install/uninstall 用到，macOS 专用）
# ============================================================================

set -euo pipefail

# 定位脚本自身所在目录，保证从任意 cwd 调用都正确
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 服务端密钥统一从 local/env/dev.json 读取（含 Apple 配置与 Supabase token）
DEV_ENV="$REPO_DIR/local/env/dev.json"
PY_SCRIPT="$SCRIPT_DIR/apple_secret.py"
STATE_FILE="$SCRIPT_DIR/.apple_secret_last"
LOG_FILE="$SCRIPT_DIR/.apple_rotate.log"

# launchd 任务标识：沿用新的包名前缀，避免与其他任务冲突
LAUNCH_LABEL="uk.aknot.toolbox.apple-secret-rotate"
LAUNCH_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_LABEL}.plist"

# Python 解释器探测：系统自带 3.9 即可运行（脚本已用 __future__ annotations 兼容）
PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v python3)"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v python)"
    else
        echo "错误：找不到 python3" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------

log() {
    # 同时写日志文件和 stdout；launchd 场景下 stdout 会进 StandardOutPath
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

die() {
    log "错误：$*"
    exit 1
}

load_env() {
    # 从 local/env/dev.json 读取 Apple 配置与 Supabase token，并以环境变量导出，
    # 供 apple_secret.py 读取（该脚本支持 APPLE_* / SUPABASE_ACCESS_TOKEN 等环境变量）。
    if [ ! -f "$DEV_ENV" ]; then
        cat >&2 <<EOF
错误：找不到密钥文件 $DEV_ENV

请在 local/env/dev.json 中填入以下字段：
  APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_SERVICES_ID / APPLE_P8_B64 / SUPABASE_ACCESS_TOKEN
（Apple .p8 私钥以 base64 存于 APPLE_P8_B64，签名脚本会自动还原为临时文件）
EOF
        exit 1
    fi

    export APPLE_TEAM_ID="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('APPLE_TEAM_ID',''))" 2>/dev/null)"
    export APPLE_KEY_ID="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('APPLE_KEY_ID',''))" 2>/dev/null)"
    export APPLE_SERVICES_ID="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('APPLE_SERVICES_ID',''))" 2>/dev/null)"
    export APPLE_KEYCHAIN_ACCOUNT="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('APPLE_KEYCHAIN_ACCOUNT','default'))" 2>/dev/null)"
    export SUPABASE_ACCESS_TOKEN="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('SUPABASE_ACCESS_TOKEN',''))" 2>/dev/null)"
    export SUPABASE_PROJECT_REF="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('SUPABASE_PROJECT_REF',''))" 2>/dev/null)"
    export APPLE_P8_B64="$(python3 -c "import json;print(json.load(open('$DEV_ENV')).get('APPLE_P8_B64',''))" 2>/dev/null)"
}

require_env() {
    local missing=()
    [ -z "${APPLE_TEAM_ID:-}" ] && missing+=("APPLE_TEAM_ID")
    [ -z "${APPLE_KEY_ID:-}" ] && missing+=("APPLE_KEY_ID")
    [ -z "${APPLE_SERVICES_ID:-}" ] && missing+=("APPLE_SERVICES_ID")
    # APPLE_P8_PATH 故意不设为必填：私钥更推荐放 macOS 钥匙串，
    # 此时签名脚本会自己从钥匙串取，不必在磁盘上留明文文件。

    if [ ${#missing[@]} -gt 0 ]; then
        die "凭据文件缺少：${missing[*]}（$ENV_FILE）"
    fi

    [ -f "$PY_SCRIPT" ] || die "找不到签名脚本：$PY_SCRIPT"
}

# 组装传给签名脚本的私钥参数。
# 配了 APPLE_P8_PATH 就用文件；没配则不传，让签名脚本回退到 macOS 钥匙串。
# 用数组而不是字符串拼接，保证路径里含空格也不会被错误分词。
P8_ARGS=()
p8_args() {
    P8_ARGS=()
    if [ -n "${APPLE_P8_PATH:-}" ]; then
        P8_ARGS=(--p8 "$APPLE_P8_PATH")
    fi
}

# ---------------------------------------------------------------------------
# 子命令
# ---------------------------------------------------------------------------

cmd_rotate() {
    load_env
    require_env

    # 仅在显式配置了明文路径时才校验文件存在；走钥匙串时无需任何磁盘文件。
    if [ -n "${APPLE_P8_PATH:-}" ] && [ ! -f "${APPLE_P8_PATH}" ]; then
        die ".p8 私钥不存在：${APPLE_P8_PATH}
      Apple 的 .p8 只能下载一次，丢了只能去后台 revoke 后重建。"
    fi

    if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
        cat >&2 <<'EOF'
错误：未设置 SUPABASE_ACCESS_TOKEN，无法自动写回。

获取地址：https://supabase.com/dashboard/account/tokens
拿到后填进 local/env/dev.json 的 SUPABASE_ACCESS_TOKEN 字段。

或者改用 `gen-only`，把生成的 JWT 手工粘到
Supabase Dashboard → Authentication → Providers → Apple → Secret Key。
EOF
        exit 1
    fi

    log "开始轮换 Apple client secret（Services ID: ${APPLE_SERVICES_ID}）"
    p8_args

    # 生成并直接写回；--out 落一份本地副本便于 check 与审计
    "$PYTHON_BIN" "$PY_SCRIPT" gen \
        ${P8_ARGS[@]+"${P8_ARGS[@]}"} \
        --team "$APPLE_TEAM_ID" \
        --key "$APPLE_KEY_ID" \
        --service "$APPLE_SERVICES_ID" \
        --out "$STATE_FILE" \
        --apply

    chmod 600 "$STATE_FILE" 2>/dev/null || true
    log "轮换完成，新 secret 已写回 Supabase 项目 ${SUPABASE_PROJECT_REF:-（未指定 ref）}"
    log "到期日：$(date -v+180d '+%Y-%m-%d' 2>/dev/null || echo '约 180 天后')"

    # 顺手校验一下刚写进去的内容，避免"生成成功但内容不对"的假象
    if [ -s "$STATE_FILE" ]; then
        "$PYTHON_BIN" "$PY_SCRIPT" check --secret "$(cat "$STATE_FILE")" >>"$LOG_FILE" 2>&1 || true
    fi
}

cmd_gen_only() {
    load_env
    require_env
    p8_args

    echo "生成 client secret（仅打印，不写回 Supabase）："
    echo "---------------------------------------------"
    "$PYTHON_BIN" "$PY_SCRIPT" gen \
        ${P8_ARGS[@]+"${P8_ARGS[@]}"} \
        --team "$APPLE_TEAM_ID" \
        --key "$APPLE_KEY_ID" \
        --service "$APPLE_SERVICES_ID"
    echo "---------------------------------------------"
    echo "把上面整行粘到：Supabase → Authentication → Providers → Apple → Secret Key"
}

cmd_keychain() {
    # 透传给 python 脚本：把 .p8 存进钥匙串。
    # 额外接收 --delete-source 等参数，原样转发。
    shift
    exec "$PYTHON_BIN" "$PY_SCRIPT" keychain-import "$@"
}

cmd_inspect() {
    # 查询线上配置：确认 Apple provider 是否已启用、Client IDs 顺序是否正确。
    # 需要 SUPABASE_ACCESS_TOKEN（从凭据文件加载或已在环境中）。
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$ENV_FILE"
        set +a
    fi
    if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
        cat >&2 <<'EOF'
错误：未设置 SUPABASE_ACCESS_TOKEN。
获取地址：https://supabase.com/dashboard/account/tokens
EOF
        exit 1
    fi
    exec "$PYTHON_BIN" "$PY_SCRIPT" inspect
}

cmd_status() {
    if [ ! -s "$STATE_FILE" ]; then
        echo "尚无轮换记录（$STATE_FILE 不存在或为空）"
        echo "先跑一次：$0 rotate"
        exit 0
    fi

    local last_mod expire_epoch
    # BSD stat 取 mtime（epoch 秒）；注意它没有 GNU 的 -d/-v 偏移选项，
    # 所以到期日要自己加秒数后再用 `date -r` 格式化。
    last_mod="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$STATE_FILE" 2>/dev/null || echo '未知')"
    expire_epoch=$(( $(stat -f '%m' "$STATE_FILE" 2>/dev/null || echo 0) + 180 * 86400 ))
    local expire_date
    expire_date="$(date -r "$expire_epoch" '+%Y-%m-%d' 2>/dev/null || echo '推算失败')"

    echo "上次轮换：$last_mod"
    echo "到期日  ：$expire_date（按 180 天有效期推算）"
    echo
    echo "当前 secret 详情："
    "$PYTHON_BIN" "$PY_SCRIPT" check --secret "$(cat "$STATE_FILE")"
}

cmd_install() {
    # 生成 launchd plist 并加载。
    # 选「每月 1 号」而不是「每 5 个月」：
    #   - launchd 的 StartCalendarInterval 表达「每 5 个月」很别扭，而每月 1 号是一个 dict 就够；
    #   - 180 天有效期下，每月轮换有充足冗余，且重新签发无副作用（旧的立即失效，新的生效）；
    #   - 机器关机错过时 launchd 会在下次唤醒后补跑一次。
    mkdir -p "$HOME/Library/LaunchAgents"

    cat >"$LAUNCH_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/apple_secret_rotate.sh</string>
        <string>rotate</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Day</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

    # 先卸载同名旧任务，避免重复加载导致 plist 修改不生效
    launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCH_PLIST"

    echo "✓ 已安装定时任务：${LAUNCH_LABEL}"
    echo "  plist : $LAUNCH_PLIST"
    echo "  频率  ：每月 1 号 04:00（错过会在下次开机补跑）"
    echo "  日志  ：$LOG_FILE"
    echo
    echo "确认状态： launchctl list | grep apple-secret-rotate"
    echo "立即试跑： launchctl start ${LAUNCH_LABEL}"
}

cmd_uninstall() {
    launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
    rm -f "$LAUNCH_PLIST"
    echo "✓ 已卸载定时任务：${LAUNCH_LABEL}"
}

# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
    rotate)    cmd_rotate ;;
    gen-only)  cmd_gen_only ;;
    status)    cmd_status ;;
    inspect)   cmd_inspect ;;
    keychain)  cmd_keychain "$@" ;;
    install)   cmd_install ;;
    uninstall) cmd_uninstall ;;
    *)         usage; exit 1 ;;
esac
