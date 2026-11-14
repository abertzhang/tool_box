#!/usr/bin/env bash
#
# 设置 Supabase 邮箱 OTP（验证码）长度 —— 使服务端下发的位数与 App 端一致。
#
# 背景（必须理解，否则注册验证必然失败）：
#   Supabase 的邮箱 OTP 长度由服务端配置 `mailer_otp_length` 决定，默认 8 位；
#   App 端 `lib/feature/login/page/verify_email_page.dart` 的 `_kCodeLength`
#   写死一个位数并限制输入框长度。两者不一致时，用户拿到的邮件码填不进输入框
#   （或填进去也校验失败），表现为「验证码一直无效」，且**极难自查**。
#   因此改任一侧，都必须同步改另一侧 —— 本脚本改服务端那一侧。
#
# 用法：
#   1) 在 local/env/dev.json 里填好 SUPABASE_ACCESS_TOKEN
#   2) bash scripts/set_otp_length.sh          # 默认设为 4 位
#      OTP_LENGTH=6 bash scripts/set_otp_length.sh   # 想设成别的位数时这样传
#
# ⚠️ 注意：`mailer_otp_length` 是**全局 email OTP 长度**，会同时影响
#    「邮箱登录验证码 / 魔术链接」等场景；但不影响找回密码（走 TokenHash + 深链）。
# ⚠️ 安全：local/env/dev.json 已被 .gitignore 忽略，脚本不回显令牌。

set -euo pipefail

# tool_box 项目的 ref（Supabase 项目唯一标识），可用环境变量覆盖。
PROJECT_REF="${PROJECT_REF:-nfoishlluynelazgwduc}"

# 目标验证码位数，与 App 端 _kCodeLength 保持一致。
OTP_LENGTH="${OTP_LENGTH:-4}"

# 脚本所在目录（用绝对路径，避免从别处调用时路径错乱）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 服务端密钥统一从 local/env/dev.json 读取：该文件不进 App 包，
# 专门存 service_role / access token / 密码等敏感凭据（绝不放进会被注入 App 的 prd.json）。
DEV_ENV="$SCRIPT_DIR/../local/env/dev.json"

if [[ ! -f "$DEV_ENV" ]]; then
  echo "❌ 找不到 $DEV_ENV"
  echo "   请在 local/env/dev.json 中填入 SUPABASE_ACCESS_TOKEN 等服务端密钥"
  exit 1
fi

# 从 dev.json 精确抽取单个 key（用 python3 解析 JSON，避免误读其它字段）。
# 原因：dev.json 里还放着 service_role key 等其它密钥，在受限环境（沙箱 / CI）
# 里「密钥进内存」会被安全策略直接 SIGTERM（exit 137，stdout 全丢）。
get_env() {
  local key="$1"
  python3 -c "import json,sys; d=json.load(open('$DEV_ENV')); print(d.get('$key',''))" 2>/dev/null
}

SUPABASE_ACCESS_TOKEN="$(get_env SUPABASE_ACCESS_TOKEN)"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" || "$SUPABASE_ACCESS_TOKEN" == sbp_这里粘贴* ]]; then
  echo "❌ local/env/dev.json 里没填 SUPABASE_ACCESS_TOKEN"
  echo "   去 https://supabase.com/dashboard/account/tokens 生成一个（不要勾选任何权限限制）"
  exit 1
fi

# 位数合法性：纯数字，且不小于服务端下限 6（小于 6 会被 API 直接 400）。
if ! [[ "$OTP_LENGTH" =~ ^[0-9]+$ ]] || (( OTP_LENGTH < 6 )); then
  echo "❌ OTP_LENGTH 必须是不小于 6 的数字，当前是：$OTP_LENGTH"
  echo "   实测：设为 4 会被拒 —— mailer_otp_length: Too small: expected number to be >=6"
  exit 1
fi

echo "▶ 正在把项目 $PROJECT_REF 的 mailer_otp_length 设为 $OTP_LENGTH ..."

RESPONSE="$(
  curl -sS -w '\n%{http_code}' \
    -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"mailer_otp_length\": $OTP_LENGTH}"
)"

# 最后一行是 HTTP 状态码，前面是响应体。
HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"
BODY="$(echo "$RESPONSE" | sed '$d')"

echo
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
  echo "✅ 已提交，HTTP $HTTP_CODE"
  echo "$BODY" | grep -o -E '"mailer_otp_length":[0-9]*' || true
  echo
  echo "下一步（务必核对）："
  echo "  1. App 端 _kCodeLength 是否也是 $OTP_LENGTH（verify_email_page.dart）"
  echo "  2. i18n 文案里的位数是否已同步（verifyEmailDesc / verifyCodeHint，中英双语）"
  echo "  3. Confirm signup 邮件模板输出的是 {{ .Token }} 而不是 {{ .ConfirmationURL }}"
else
  echo "❌ 提交失败，HTTP $HTTP_CODE"
  echo "$BODY"
  echo
  echo "常见原因："
  echo "  • 401/403 → token 无效/过期，或用了只读 scoped 令牌（sbp_fc 前缀）"
  echo "  • 400     → 位数超出服务端允许范围（过小会被拒，一般最小 4）"
  exit 1
fi
