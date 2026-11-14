#!/usr/bin/env bash
#
# 用 Gmail 给 Supabase 项目配置自定义 SMTP（Auth 邮件走 smtp.gmail.com）。
#
# 背景：Supabase 自带 SMTP 仅供开发体验，有两大硬限制 ——
#   1. 只能发给「组织团队成员」的邮箱，其他地址一律报 Email address not authorized
#   2. 限流 2 封/小时
# 配置自定义 SMTP 后解除上述限制，可发给任意地址（默认限流放宽到 30 封/小时）。
#
# 前置条件（两件都必须先做完，否则脚本会失败）：
#   1. Gmail 账号 zhang13655179933@gmail.com 已开启「两步验证」
#      → https://myaccount.google.com/signinoptions/two-step-verification
#   2. 已生成「应用专用密码 App Password」
#      → https://myaccount.google.com/apppasswords （应用选「邮件」，设备选「其他」）
#      注意：Gmail 不接受账号登录密码做 SMTP 认证，只认 16 位应用专用密码。
#
# 用法：
#   1) 在 local/env/dev.json 里填 SUPABASE_ACCESS_TOKEN 和 GMAIL_APP_PASSWORD
#   2) bash scripts/setup_smtp_gmail.sh
#
# ⚠️ 安全：local/env/dev.json 已被 .gitignore 忽略，切勿提交；本脚本不回显任何密码。

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置区
# ---------------------------------------------------------------------------

# tool_box 项目的 ref（Supabase 项目唯一标识），可用环境变量覆盖。
PROJECT_REF="${PROJECT_REF:-nfoishlluynelazgwduc}"

# 发件邮箱 = SMTP 登录账号。Gmail 强制二者必须一致，改别的会被拒。
SMTP_USER="${SMTP_USER:-zhang13655179933@gmail.com}"

# 收件人看到的发件人显示名。
SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-Tool Box}"

# Gmail SMTP 服务器：
#   smtp.gmail.com       → 587(STARTTLS) 或 465(SSL) 都可用，推荐 587
#   smtp-relay.gmail.com → 只有 465 能用（Google Workspace 专用，个人账号选上面那个）
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"

# 脚本所在目录（用绝对路径，避免从别处调用时路径错乱）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 服务端密钥统一从 local/env/dev.json 读取：该文件不进 App 包，
# 专门存 service_role / access token / 密码等敏感凭据（绝不放进会被注入 App 的 prd.json）。
DEV_ENV="$SCRIPT_DIR/../local/env/dev.json"

# ---------------------------------------------------------------------------
# 读取本地密钥文件
# ---------------------------------------------------------------------------

if [[ ! -f "$DEV_ENV" ]]; then
  echo "❌ 找不到 $DEV_ENV"
  echo "   请在 local/env/dev.json 中填入 SUPABASE_ACCESS_TOKEN 与 GMAIL_APP_PASSWORD"
  exit 1
fi

# 按需精确抽取单个 key（用 python3 解析 JSON，避免误读其它字段）。
# 原因：dev.json 里同时还放着 service_role key，逐行 read 会把每一行的值都赋给 shell 变量，
# 在受限环境（沙箱 / CI）里「密钥进内存」会被安全策略直接 SIGTERM（exit 137，stdout 全丢）。
# 只抽取需要的两行，service_role key 自始至终不进内存，脚本在任何环境都能跑。
get_env() {
  local key="$1"
  python3 -c "import json,sys; d=json.load(open('$DEV_ENV')); print(d.get('$key',''))" 2>/dev/null
}

SUPABASE_ACCESS_TOKEN="$(get_env SUPABASE_ACCESS_TOKEN)"
GMAIL_APP_PASSWORD="$(get_env GMAIL_APP_PASSWORD)"

# ---------------------------------------------------------------------------
# 校验入参
# ---------------------------------------------------------------------------

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" || "$SUPABASE_ACCESS_TOKEN" == sbp_这里粘贴* ]]; then
  echo "❌ local/env/dev.json 里没填 SUPABASE_ACCESS_TOKEN"
  echo "   去 https://supabase.com/dashboard/account/tokens 生成一个"
  exit 1
fi

if [[ -z "${GMAIL_APP_PASSWORD:-}" || "$GMAIL_APP_PASSWORD" == 这里粘贴* ]]; then
  echo "❌ local/env/dev.json 里没填 GMAIL_APP_PASSWORD"
  echo "   去 https://myaccount.google.com/apppasswords 生成 16 位应用专用密码"
  exit 1
fi

# Google 显示的密码是 "abcd efgh ijkl mnop" 四段形式，SMTP 认证时要去掉空格。
SMTP_PASS="$(echo "$GMAIL_APP_PASSWORD" | tr -d '[:space:]')"

if [[ ${#SMTP_PASS} -ne 16 ]]; then
  echo "⚠️  应用专用密码去掉空格后是 ${#SMTP_PASS} 位，正常应为 16 位。"
  echo "   如果贴的是 Gmail 登录密码，认证一定失败 —— 请确认用的是 App Password。"
  read -r -p "   仍要继续吗？[y/N] " yn
  [[ "$yn" == "y" || "$yn" == "Y" ]] || exit 1
fi

# ---------------------------------------------------------------------------
# 提交配置到 Supabase Management API
# ---------------------------------------------------------------------------

echo "▶ 正在为项目 $PROJECT_REF 配置自定义 SMTP ..."
echo "  host=$SMTP_HOST port=$SMTP_PORT user=$SMTP_USER sender=$SMTP_SENDER_NAME"

# 只 PATCH 需要改的字段，其余（如 mailer_autoconfirm）保持原值不动。
# external_email_enabled=true 是启用自定义 SMTP 的总开关，必须带。
RESPONSE="$(
  curl -sS -w '\n%{http_code}' \
    -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(cat <<EOF
{
  "external_email_enabled": true,
  "smtp_host": "$SMTP_HOST",
  "smtp_port": "$SMTP_PORT",
  "smtp_user": "$SMTP_USER",
  "smtp_pass": "$SMTP_PASS",
  "smtp_admin_email": "$SMTP_USER",
  "smtp_sender_name": "$SMTP_SENDER_NAME"
}
EOF
)"
)"

# 最后一行是 HTTP 状态码，前面是响应体。
HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"
BODY="$(echo "$RESPONSE" | sed '$d')"

echo
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
  echo "✅ 配置已提交，HTTP $HTTP_CODE"
  # 响应体会回显 smtp_pass，这里只截取脱敏后的关键字段展示，避免密码落到终端历史。
  echo "$BODY" | grep -o -E '"smtp_(host|port|user|sender_name|admin_email)":[^,}]*' || true
  echo
  echo "下一步（务必做）："
  echo "  1. 打开 https://supabase.com/dashboard/project/$PROJECT_REF/auth/smtp 确认开关是 Enabled"
  echo "  2. 用一个**非团队成员**的邮箱注册一次，验证能否真收到邮件"
  echo "  3. 到 https://supabase.com/dashboard/project/$PROJECT_REF/auth/rate-limits"
  echo "     把邮件限流调到 20/小时以内 —— Gmail 个人账号每天上限约 500 封，"
  echo "     用 Supabase 默认的 30/小时跑满一天会撞上 Gmail 限额导致账号被临时封禁。"
else
  echo "❌ 提交失败，HTTP $HTTP_CODE"
  echo "$BODY"
  echo
  echo "常见原因："
  echo "  • 401/403 → access token 无效或过期，重新生成一个"
  echo "  • 404     → PROJECT_REF 不对，或该 token 的账号没有这个项目权限"
  echo "  • 400     → 字段值不合法，检查端口是否是数字、邮箱格式是否正确"
  exit 1
fi
