#!/bin/bash
# ============================================================================
# 脚本：scripts/iapsmoke.sh
# 模块：tool_box 开发辅助 · IAP 健康检查（bash 包装）
#
# 职责：
#   把 scripts/smoke_iap.dart 包成 CLI。两种用法：
#     1) --check-config    静态扫：不依赖设备，只看源码 / 平台配置完备度，
#                         用于「还没接设备 / 还没登录 Xcode」时也能定位问题。
#     2) --device <id>     实链路跑：调 flutter run -d <id> -t smoke_iap.dart，
#                         解析 stdout 里的 JSON 行，把报告打回终端。
#     3) --devices         列可用设备（包装 flutter devices）。
#
#   不带任何参数：打印 usage，列出上面三种用法。
#
# 退出码：
#   - 静态扫：每个检查独立给 PASS / WARN / FAIL，最终 exit code =
#     FAIL 数（无 FAIL 时 0）。便于在 CI 流水线里直接作为门禁。
#   - 实链路：解析到 JSON 行 exit 0；启动失败 / JSON 未命中 exit 1。
#
# 与 lib/feature/profile/provider/membership_provider.dart 的关系：
#   smoke_iap.dart 内置的商品 ID 与 kMemberProductId 同值；脚本的 --check-config
#   会 grep 源码确认它存在，防止某天有人把它改了忘了同步商店后台。
# ============================================================================
set -euo pipefail

# 项目根目录 = 脚本所在目录的上两级（scripts/ 与 package root 同级）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SMOKE_DART="${SCRIPT_DIR}/smoke_iap.dart"

# dart-define 参数：复用 dev.sh 的注入约定，让 smoke 跑出来的全局开关与正式
# 开发期一致（避免明明在 dev 但跑出 uat 行为之类的诡异现象）。
DART_DEFINE=(
    --dart-define=ENV="dev"
    --dart-define-from-file=local/env/prd.json
    --dart-define=ENABLE_DEBUG_LOG="true"
)

# 商品 ID 在两端统一为 uk.aknot.toolbox.pro（App Store Connect 与
# Google Play Console 商品 ID 一致）。这里仅 grep 校验该 ID 在 lib/ 中声明，
# 不参与运行时（运行时由 smoke_iap.dart 内部常量提供）。
EXPECTED_PRODUCT_ID="uk.aknot.toolbox.pro"

# ----------------------------------------------------------------------------
# usage
# ----------------------------------------------------------------------------
function usage() {
    cat <<'USAGE'
用法：
  ./scripts/iapsmoke.sh --check-config               静态扫配置（不需要设备/账号）
  ./scripts/iapsmoke.sh --devices                    列出 flutter devices
  ./scripts/iapsmoke.sh --device <id>                跑实链路 smoke（不购买，随时安全）
  ./scripts/iapsmoke.sh --buy --device <id>          沙盒购买（明确调 buyNonConsumable，仅沙盒账号）
  ./scripts/iapsmoke.sh --help                       显示这条帮助

说明：
  --check-config  会扫描以下 4 项并按 PASS/WARN/FAIL 打分：
    1) lib/ 内含 kMemberProductId 声明；
    2) AndroidManifest.xml 含 com.android.vending.BILLING 权限；
    3) iOS Runner*.entitlements 不应含 com.apple.developer.in-app-purchases
       （这是 Apple 官方「幻觉键」：写入反而让 Xcode 自动签名失败。
        内购是 App Service，显式 App ID 即自动具备，**不写这个 key**。
        正确配置下该 key 应 ABSENT —— 命中则 FAIL，提示删掉它）；
    4) pubspec.yaml 锁定了 in_app_purchase 与 in_app_purchase_storekit。

  --device <id> 会 flutter run -t scripts/smoke_iap.dart -d <id>，
    并把 stdout 中 '[smoke_iap] json::' 开头的 JSON 行打回终端。
    默认不接 --buy → smoke 模式（绝不购买）。

  --buy 是修饰符，必须配合 --device 使用 → buy 模式：
    会向 smoke_iap.dart 注入 --dart-define=SMOKE_BUY=1，明确调用
    buyNonConsumable 拉起系统支付 UI，需要你在沙盒账号下手动点完成；
    脚本只负责发起 + 收结果 + 自动 completePurchase。沙盒不真实扣费，
    生产账号请勿使用。未查到商品时自动跳过并给出原因。
USAGE
}

# ----------------------------------------------------------------------------
# 静态扫：不依赖设备 / 商店账号，可随时跑。
# 输出每项一行：'[OK]/[WARN]/[FAIL] <check-name> : <说明>'。
# 最终 exit code = FAIL 数；WARN 不阻塞。
# ----------------------------------------------------------------------------
function check_config() {
    local fail_count=0
    local warn_count=0

    echo "==================== IAP 静态配置检查 ===================="
    echo "项目根：${PROJECT_ROOT}"
    echo ""

    # ---- 1) kMemberProductId 声明在 lib/ 中，且值 = EXPECTED_PRODUCT_ID ----
    if grep -rq "kMemberProductId" "${PROJECT_ROOT}/lib" 2>/dev/null; then
        local declared
        declared="$(grep -rh "kMemberProductId = " "${PROJECT_ROOT}/lib" | head -1 | sed -E "s/.*'([^']+)'.*/\1/" || true)"
        if [[ "${declared}" == "${EXPECTED_PRODUCT_ID}" ]]; then
            echo "[OK]   kMemberProductId          : 声明在 lib/，值 = ${declared}"
        else
            echo "[FAIL] kMemberProductId          : 声明存在但值不是 ${EXPECTED_PRODUCT_ID}（实际：${declared:-<未解析>})"
            fail_count=$((fail_count+1))
        fi
    else
        echo "[FAIL] kMemberProductId          : lib/ 中找不到声明，请确认 membership_provider.dart 是否还在"
        fail_count=$((fail_count+1))
    fi

    # ---- 2) AndroidManifest.xml 含 BILLING 权限 ----
    local manifest="${PROJECT_ROOT}/android/app/src/main/AndroidManifest.xml"
    if [[ -f "${manifest}" ]]; then
        if grep -q "com.android.vending.BILLING" "${manifest}"; then
            echo "[OK]   AndroidManifest BILLING    : 已声明 com.android.vending.BILLING"
        else
            echo "[FAIL] AndroidManifest BILLING    : 缺 com.android.vending.BILLING，Play Billing 客户端建连会被拒"
            fail_count=$((fail_count+1))
        fi
    else
        echo "[FAIL] AndroidManifest            : 文件不存在 ${manifest}"
        fail_count=$((fail_count+1))
    fi

    # ---- 3) iOS entitlements 不应含 IAP 幻觉键 ----
    # Apple 官方「常见幻觉键」：com.apple.developer.in-app-purchases。
    # 写入 entitlements 会让 Xcode 自动签名失败（profile 查不到该 key）；
    # 内购是 App Service，显式 App ID 即自动具备，**不写这个 key**。
    # 因此本检查「反向断言」：命中该 key 即 FAIL，提示删掉它。
    # 文件名可能是 Runner.entitlements / RunnerDebug.entitlements /
    # RunnerRelease.entitlements 等，glob 全量收集再逐个解析。
    local ent_pattern="${PROJECT_ROOT}/ios/Runner/Runner*.entitlements"
    local ent_files=()
    for f in $ent_pattern; do
        [[ -f "$f" ]] && ent_files+=("$f")
    done
    local iap_phantom="0"
    local checked=""
    for f in "${ent_files[@]}"; do
        checked="${checked}$(basename "$f") "
        if grep -q "com.apple.developer.in-app-purchases" "$f"; then
            iap_phantom="1"
        fi
    done
    if [[ "${iap_phantom}" == "1" ]]; then
        echo "[FAIL] iOS entitlements IAP       : ${checked}含幻觉键 com.apple.developer.in-app-purchases（写入会让 Xcode 签名失败，请删掉）"
        fail_count=$((fail_count+1))
    else
        echo "[OK]   iOS entitlements IAP       : ${checked:-<无 entitlements>} 未含 IAP 幻觉键（正确）"
    fi

    # ---- 4) pubspec.yaml 含 in_app_purchase + storekit ----
    local pubspec="${PROJECT_ROOT}/pubspec.yaml"
    if [[ -f "${pubspec}" ]]; then
        local has_iap="0"
        local has_storekit="0"
        grep -qE "^[[:space:]]+in_app_purchase:" "${pubspec}" && has_iap="1"
        grep -qE "^[[:space:]]+in_app_purchase_storekit:" "${pubspec}" && has_storekit="1"
        if [[ "${has_iap}" == "1" && "${has_storekit}" == "1" ]]; then
            echo "[OK]   pubspec in_app_purchase    : 已锁定 in_app_purchase 与 in_app_purchase_storekit"
        else
            echo "[FAIL] pubspec in_app_purchase    : 缺 in_app_purchase(${has_iap}) 或 in_app_purchase_storekit(${has_storekit})"
            fail_count=$((fail_count+1))
        fi
    else
        echo "[FAIL] pubspec.yaml               : 文件不存在"
        fail_count=$((fail_count+1))
    fi

    echo ""
    echo "==================== 静态扫结果 ===================="
    echo "FAIL: ${fail_count}    WARN: ${warn_count}"
    echo ""
    if [[ ${fail_count} -gt 0 ]]; then
        echo "❌ 有 ${fail_count} 项必须修复后才能进入实链路联调"
        # 把 fail 数当 exit code，方便 CI 直接捕获。
        exit "${fail_count}"
    else
        echo "✅ 静态配置已就绪（忽略 WARN）"
        exit 0
    fi
}

# ----------------------------------------------------------------------------
# 列设备：flutter devices 输出全打到 stdout。
# ----------------------------------------------------------------------------
function list_devices() {
    echo "==================== flutter devices ===================="
    cd "${PROJECT_ROOT}"
    flutter devices
}

# ----------------------------------------------------------------------------
# 跑实链路烟雾：flutter run -d <id> -t smoke_iap.dart，解析 JSON 行。
# ----------------------------------------------------------------------------
function run_smoke() {
    local device_id="$1"
    local buy_mode="${2:-0}"
    cd "${PROJECT_ROOT}"

    if [[ ! -f "${SMOKE_DART}" ]]; then
        echo "❌ 找不到烟雾入口 ${SMOKE_DART}" >&2
        exit 1
    fi

    echo "==================== IAP 实链路烟雾 ===================="
    echo "设备 ID : ${device_id}"
    echo "模式    : $([[ "$buy_mode" == "1" ]] && echo 'BUY（沙盒购买，会调 buyNonConsumable）' || echo 'smoke（不购买）')"
    echo "入口    : ${SMOKE_DART}"
    echo ""

    # 把 smoke_iap.dart 当独立 target 跑，--machine 让输出便于抓 JSON。
    # stdout 全部走 tee 到临时文件再 grep，确保主进程拿到 JSON 行。
    local tmp_log
    tmp_log="$(mktemp -t iap_smoke_log.XXXXXX)"
    trap 'rm -f "${tmp_log}"' EXIT

    # buy 模式向入口注入 SMOKE_BUY=1；空字符串展开为无参数（set -u 安全）。
    local buy_flag=""
    if [[ "$buy_mode" == "1" ]]; then
        buy_flag="--dart-define=SMOKE_BUY=1"
    fi

    # 阻塞式调用：等 flutter run 跑完（main exit(0) 后引擎会停）。
    # 重要：不要加 &，那会让我们在 smoke 还没跑完就拿到结果。
    # buy 模式下会弹系统支付 UI，需要你在沙盒账号下手动点完成（最长 120s）。
    flutter run \
        -d "${device_id}" \
        -t "${SMOKE_DART}" \
        --machine \
        ${buy_flag} \
        --dart-define=ENV="dev" \
        --dart-define-from-file=local/env/prd.json \
        --dart-define=ENABLE_DEBUG_LOG="true" \
        2>&1 | tee "${tmp_log}"

    # flutter run 退出后，从 log 里抽 [smoke_iap] json:: 那行。
    # 用 grep -F 字面量匹配，避免 json 里花括号被当成扩展正则。
    local json_line
    json_line="$(grep -F '[smoke_iap] json::' "${tmp_log}" | tail -n 1 | sed -E 's/^.*\[smoke_iap\] json:://' || true)"

    if [[ -z "${json_line}" ]]; then
        echo ""
        echo "❌ 没抓到 JSON 行（可能是入口异常崩溃），请看上面的日志"
        exit 1
    fi

    echo ""
    echo "==================== 报告（pretty） ===================="

    # 没有 jq 时用 python3 解析（macOS 自带），逐字段打出来便于人读。
    # 注意：python3 来自 macOS 系统 / xcode-select --install，不引入新依赖。
    python3 - "${json_line}" <<'PY' || true
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception as e:
    print(f"[!] JSON 解析失败: {e}")
    sys.exit(1)

def emit(key, label):
    val = data.get(key)
    if val is None:
        print(f"{label:<22}: (none)")
        return
    if isinstance(val, list) and not val:
        print(f"{label:<22}: (none)")
        return
    if isinstance(val, list):
        print(f"{label:<22}:")
        for it in val:
            if isinstance(it, dict):
                # 商品详情多键展示
                if 'price' in it:
                    print(f"  - {it.get('id')} | {it.get('price')} {it.get('currency_code','')} | {it.get('title')}")
                else:
                    print(f"  - {it}")
            else:
                print(f"  - {it}")
    elif isinstance(val, dict):
        print(f"{label:<22}:")
        for k, v in val.items():
            print(f"  {k:<14}: {v}")
    else:
        print(f"{label:<22}: {val}")

emit('platform', 'platform')
emit('product_id', 'product_id')
emit('is_available', 'is_available')
if data.get('available_error'):
    print(f"available_error      : {data['available_error']}")
emit('product_details', 'product_details')
emit('not_found_ids', 'not_found_ids')
if data.get('query_error_code'):
    print(f"query_error_code     : {data['query_error_code']}")
emit('restored_purchase', 'restored_purchase')
emit('buy', 'buy')
print(f"elapsed_ms           : {data.get('elapsed_ms')}")

print("recommendations:")
for line in data.get('recommendations', []) or []:
    print(f"  {line}")

# 顶部汇总：是否有命中的商品、是否需要人工介入
avail = data.get('is_available')
nf = data.get('not_found_ids') or []
pd = data.get('product_details') or []
print()

# buy 段小结（仅 buy 模式有）
buy = data.get('buy')
if buy and isinstance(buy, dict):
    st = buy.get('status')
    if st in ('purchased', 'restored'):
        print("✅ 沙盒购买成功，已 completePurchase（会员应点亮）")
    elif st == 'canceled':
        print("ℹ️  用户在支付 UI 取消，未扣费")
    elif st == 'timeout':
        print("⚠️  120s 超时：确认已登录沙盒账号后重试")
    elif st == 'skipped':
        print(f"⚠️  buy 跳过：{buy.get('reason')}")
    elif st == 'pending':
        print("ℹ️  购买进入 pending（如家长批准流程），等待平台回调")
    else:
        print(f"⚠️  购买异常（{st}）：{buy.get('error','')}")

print("=================== summary ===================")
if avail and pd and not nf:
    print("✅ 链路就绪，可进入联调（点 Upgrade Now）")
elif avail and nf:
    print(f"⚠️  商店可达但缺商品 {nf}，请到 App Store Connect / Play Console 后台建")
elif not avail:
    print("⚠️  isAvailable=false，按上方 recommendations 排查")
else:
    print("⚠️  状态不明，请贴日志")
PY
}

# ----------------------------------------------------------------------------
# main 入口：参数分发
# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
# 收集式参数解析：--buy 作为修饰符，可与 --device 任意顺序组合。
# ----------------------------------------------------------------------------
BUY_MODE=0
DEVICE_ID=""
DO_CHECK=0
DO_LIST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-config) DO_CHECK=1; shift ;;
        --devices) DO_LIST=1; shift ;;
        --buy) BUY_MODE=1; shift ;;
        --device)
            if [[ $# -lt 2 ]]; then
                echo "❌ --device 后面必须接设备 ID" >&2
                usage
                exit 1
            fi
            DEVICE_ID="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "未知参数：$1" >&2; usage; exit 1 ;;
    esac
done

if [[ $DO_CHECK -eq 1 ]]; then check_config; fi
if [[ $DO_LIST -eq 1 ]]; then list_devices; fi
if [[ -n "$DEVICE_ID" ]]; then run_smoke "$DEVICE_ID" "$BUY_MODE"; fi

# 没有任何有效动作时打印 usage。
if [[ $DO_CHECK -eq 0 && $DO_LIST -eq 0 && -z "$DEVICE_ID" ]]; then
    usage
    exit 0
fi
