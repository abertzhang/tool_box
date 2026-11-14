#!/bin/bash
set -euo pipefail

# CHECK_KEY_ONLY：命中 `-k/--check` 时置为 yes（见「前置校验三」那段），
# 作用是「只探测 key 是否被蒲公英认，不打包不上传」，10 秒出结论。
CHECK_KEY_ONLY="${CHECK_KEY_ONLY:-no}"

# ===================== Tool Box 打包 + 上传蒲公英（Pgyer）一键脚本 =====================
#
# 定位：一条命令走完「选平台 → 选模式 → 打包 → 归档 →（可选）上传蒲公英」。
#   与 dev.sh（仅本地调试）、prd.sh（仅 Release 发布）互补，本脚本是**分发内测包**的入口：
#   打出来的包要直接丢给测试/审核人员在蒲公英上扫码装，所以内置上传步骤。
#
# 交互三步（均可回车取默认值，也支持位置参数跳过交互）：
#   [1] 平台        android（默认） | ios
#   [2] 构建模式    debug（默认）   | release
#   [3] 是否上传    是（默认）      | 否
#
# 用法：
#   ./scripts/pgy.sh                        # 全交互
#   ./scripts/pgy.sh android debug yes      # 非交互直达（与默认一致）
#   ./scripts/pgy.sh ios release yes        # iOS Release 包并上传
#   ./scripts/pgy.sh android release no     # 只归档不上传
#   ./scripts/pgy.sh -h                     # 帮助
#
# ⚠️ 环境变量覆盖（不想把密钥明文留在脚本里时）：
#     PGYER_API_KEY=<你的密钥> ./scripts/pgy.sh
#
# 产物：与 dev.sh / prd.sh 同一套扁平结构，不再插日期子目录
#   Android → build/aab-apk/<debug|release>/tool_box_<模式>_<月日时分>.apk
#   iOS     → build/aab-apk/<debug|release>/tool_box_<模式>_<月日时分>.ipa
#   时间戳 = date +%m%d%H%M（MMDDHHMM）；同名会被覆盖，要多留几版请手工改名。
#   ⚠️ build/ 已被 .gitignore 忽略，产物不会入库。
#
# 上传成功后会额外打印「蒲公英应用页链接」（默认 https://www.pgyer.com/tool-box，可用
# PGYER_APP_PAGE_URL 覆盖），并用 segno 在本地生成这张链接的二维码：
#   · 终端里直接用半块字符画一张，命令行窗口拿手机就能扫；
#   · 同时存 PNG 到 build/aab-apk/<模式>/pgyer_tool_box_qr.png（文件名不带时间戳，固定名好找）。
#   本机没装 segno 不会报错，降级为打印一个在线二维码图片的网址。
#
# 注入的 dart-define（与 dev.sh / prd.sh 对齐）：
#   debug   → ENV=dev   ENABLE_DEBUG_LOG=true   （调试包，日志全开）
#   release → ENV=prd   ENABLE_DEBUG_LOG=false  （正式包）
#   Supabase 凭据统一走 --dart-define-from-file=local/env/prd.json（脚本内不硬编码密钥）。
# ======================================================================================

APP_NAME="tool_box"

# Flutter SDK 路径：本机 flutter wrapper 已损坏，显式依赖 SDK（允许外部覆盖）。
FLUTTER_ROOT="${FLUTTER_ROOT:-/Users/zhangchunhua/sdk/flutter/master}"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"

# 绝对路径：以脚本自身位置反推项目根，保证从任意目录调用都能定位到产物目录
# 与 local/env/prd.json（旧实现用 $PWD，在别的目录调用会写错路径）。
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE="local/env/prd.json"

# 服务端凭据文件：只被 scripts/ 下的命令行脚本读取，**不参与 Flutter 构建注入**。
# 与 prd.json 是两条不同的红线（prd.json 会被整份打进 App 包，只能放 anon key）。
DEV_ENV_FILE="local/env/dev.json"

# ---------- 蒲公英（Pgyer）配置 ----------
#
# ⚠️ 密钥存哪：本项目红线是「凭据不进 git」。scripts/ 下的 .sh 是会提交的，
#    所以这里**不写明文 key**，改成三处按优先级取，谁先有用谁：
#      ① 环境变量      PGYER_API_KEY=xxx ./scripts/pgy.sh（CI / 不入库场景）
#      ② local/env/dev.json 的 PGYER_API_KEY（默认路径，本地直接双击跑即可）
#      ③ 都取不到 → die 并提示去哪拿
#    dev.json 属于「服务端 / CLI 凭据」，已被 .gitignore 的 /local/ 规则整体忽略，
#    既不会进 App 包，也不会被 git 提交。
PGYER_API_KEY="${PGYER_API_KEY:-}"

# 可选参数（都能改）：
# ⚠️ 用 ${VAR:-默认} 兜底而不是直接赋值：这样测试时能用
#    PGYER_UPLOAD_URL=http://127.0.0.1:8765/... 把「上传」这一步打到假接口上做冒烟测试，
#    不必为了自测把真实地址写死后再改回来。
PGYER_UPLOAD_URL="${PGYER_UPLOAD_URL:-https://www.pgyer.com/apiv2/app/upload}"   # 蒲公英 v2 上传接口（旧版，一次请求直接返回短链）
PGYER_TOKEN_URL="${PGYER_TOKEN_URL:-https://www.pgyer.com/apiv2/app/getCOSToken}" # 快速上传：取 COS 上传凭证（更快，但需两步）
PGYER_INSTALL_TYPE="${PGYER_INSTALL_TYPE:-0}"   # 0=公开安装（默认） 1=设置安装密码 2=指定可见人员
PGYER_PASSWORD="${PGYER_PASSWORD:-}"            # 安装密码：非空时强制 installType=1；留空=公开安装
PGYER_CHANNEL="${PGYER_CHANNEL:-}"              # 渠道标记，可留空

# 上传完要给人看的「应用页链接」：蒲公英上这个短 slug 直接就是 App 主页，
# 扫码/点开即可看到刚传上去的版本与更新说明。可用环境变量覆盖（换 App 时用）。
PGYER_APP_PAGE_URL="${PGYER_APP_PAGE_URL:-https://www.pgyer.com/tool-box}"

# 生成二维码用的 Python：按下面顺序挑一个**能 import segno** 的解释器（见 detect_qr_python）：
#   ① 环境变量 QR_PYTHON（自己指一个装了 segno 的解释器）
#   ② QR_VENV_PY（脚本默认指向已隔离安装的 venv，见下）
#   ③ /usr/bin/python3 → PATH 里的 python3
# ⚠️ 不写一个「没装库就 pip install」的自动安装：脚本会提交进 git，不该在别人机器上
#    静默改环境。装/不装都能跑：装了就本地出 PNG，没装就退化成打印在线二维码图片地址。
QR_VENV_PY="${QR_VENV_PY:-/Users/zhangchunhua/.workbuddy/binaries/python/envs/pgyer/bin/python}"
QR_PYTHON="${QR_PYTHON:-}"   # 想强制指定生成器解释器就给这个变量赋值

# 统一的错误退出：打印红色前缀后非零码终止。
die() {
    echo "❌ $*" >&2
    exit 1
}

# 帮助信息。
usage() {
    cat <<'USAGE'
用法：./scripts/pgy.sh [android|ios] [debug|release] [yes|no] [-h]

  android   打包 Android APK（默认）
  ios       打包 iOS IPA（需本机 Xcode 签名可正常出包）
  debug     构建模式（默认）
  release   构建模式
  yes       上传蒲公英（默认）
  no        只打包归档，不上传
  -h        查看帮助
  -k        只做 API Key 自检（打一个探测请求看返回码），不打包、不上传

产物：build/aab-apk/<debug|release>/tool_box_<模式>_<MMDDHHMM>.{apk,ipa}
默认等价于：./scripts/pgy.sh android debug yes

遇到上传报 code=1002「_api_key not found」时，先跑 ./scripts/pgy.sh -k 定位，别急着重新打包。
⚠️ 注意：1002 有两个不同成因，排查时务必区分——
  · 走 getCOSToken（或旧版接口且字段名写错）→ 1002 才代表 key 真的无效；
  · 旧版 /apiv2/app/upload 用 app= 传文件时也会回 1002，那是字段名错，改成 file= 即可。
USAGE
}

# ---------- 帮助信息优先级最高 ----------
# 没配环境/密钥的环境也要能先看用法（否则用户被报错困住、不知道脚本怎么用）。
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

# ---------- 前置校验一：Flutter SDK ----------
[ -x "$FLUTTER_BIN" ] || die "找不到 flutter：${FLUTTER_BIN}（可用 FLUTTER_ROOT=<sdk 路径> 覆盖）"

# ---------- 前置校验二：Supabase 配置文件 ----------
# 缺 key 就不再往下打，从源头杜绝「装得上但登录报 Supabase not initialized」的包。
[ -f "$ENV_FILE" ] || die "缺少 Supabase 配置文件：${ENV_FILE}"

# 只检查键存在且非空，不打印值，避免密钥落到终端日志。
/usr/bin/python3 - "$ENV_FILE" <<'PY' || die "prd.json 校验未通过"
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
missing = [k for k in ('SUPABASE_URL', 'SUPABASE_ANON_KEY') if not str(data.get(k, '')).strip()]
if missing:
    print('❌ %s 缺少或为空的键：%s' % (sys.argv[1], ', '.join(missing)))
    sys.exit(1)
print('✅ Supabase 配置校验通过（键齐全；值不打印）')
PY

# ---------- 位置参数解析（支持非交互直接跑） ----------
# ⚠️ 必须放在「蒲公英 API Key 校验」之前：否则没配 key 时连 -h 都看不了，
#    用户被困在报错里、不知道脚本到底怎么用。
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)   usage; exit 0 ;;
        -k|--check)  CHECK_KEY_ONLY="yes" ;;   # 只自检 key，跳过打包
        android|ios)         BUILD_PLATFORM="$1" ;;
        debug|release)       BUILD_MODE="$1" ;;
        yes|y|no|n)          NEED_UPLOAD="$1" ;;
        *) die "未知参数：${1}（用 -h 查看用法）" ;;
    esac
    shift
done

# ---------- 前置校验三：解析蒲公英 API Key ----------
# 取用顺序：环境变量 → dev.json；dev.json 缺失或没这个键就当空值走后面 die。
# ⚠️ python 只输出密钥本身，任何日志里都不打印它。
if [ -z "$PGYER_API_KEY" ] && [ -f "$DEV_ENV_FILE" ]; then
    PGYER_API_KEY="$(/usr/bin/python3 -c '
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        print(str(json.load(f).get("PGYER_API_KEY", "")).strip())
except Exception:
    pass
' "$DEV_ENV_FILE" 2>/dev/null || true)"
fi

# ---------- -k/--check：只做 key 自检，秒回结果、不打包 ----------
# 探测点选 **getCOSToken**（快速上传）而不是旧版 /apiv2/app/upload：
#   - 有效 key + getCOSToken（即使不带 buildType）→ 会返回 1040/1014 之类「参数错」，
#     这本身就证明 key 已经过了鉴权；
#   - 无效 key → 一律 1002。
# 也就是说 1002 在这里等价于「key 无效」，而旧版接口在字段名写错（app= 而非 file=）时
# 也会回 1002，会误导排查 —— 所以自检统一走 getCOSToken，更干净。
check_key_only() {
    local resp
    resp="$(curl -sS -m 30 \
        -d "_api_key=${PGYER_API_KEY}" \
        -d "buildType=android" \
        "${PGYER_TOKEN_URL}" 2>&1 || true)"
    printf '%s' "$resp" | /usr/bin/python3 -c '
import json, sys
raw = sys.stdin.read().strip()
try:
    d = json.loads(raw)
    code = d.get("code")
    msg = d.get("message", "")
except Exception:
    code, msg = "?", raw[:200]
print("接口返回：code=%s message=%s" % (code, msg))
if code == 1002:
    print("""
🔍 1002 = 「API Key 无效或账号类型不支持」→ 这个 key 蒲公英不认。按下面顺序自查：
  ① 复制错字段：appKey / userKey 也都是 32 位十六进制、长得和 API Key 一模一样！
     必须在「个人中心 / 账号设置 → API 密钥」（或开发者中心 → API 信息）页取 API Key，
     不是 App 管理页里的 appKey，也不是「User Key」。
  ② 账号没实名：蒲公英强制实名后才能用 API 上传，未实名会直接被判 1002。
     后台看是否提示「上传需完成实名认证 / 缺少身份证正面、反面、手持照片」。
  ③ key 被重新生成过（旧的自动失效），或子账号没被授权。
  ④ 确认复制时没多带空格、换行、全角字符（脚本里已 strip 过两端空白）。""")
elif code == 1001:
    print("🔍 1001 = key 为空：key 没读到（dev.json 路径不对或键名写错）。")
elif code == 0:
    print("✅ key 有效，且已拿到 COS 上传凭证（返回 code=0）。问题不在 key。")
else:
    print("✅ 服务端认这个 key（返回码 %s %s 说明已通过鉴权），" % (code, msg))
    print("   问题在上传参数/文件格式，不在 key。")
'
}

# 命中自检模式：解析完 key 就打一次接口看返回码，不打包、不上传。
if [ "${CHECK_KEY_ONLY:-no}" = "yes" ]; then
    echo "==================== 蒲公英 API Key 自检（只发一个探测请求） ===================="
    echo "接口：${PGYER_TOKEN_URL}"
    echo "密钥：已读到（长度 ${#PGYER_API_KEY}，值不打印）"
    echo "------------------------------------------------------------------"
    check_key_only
    echo "------------------------------------------------------------------"
    exit 0
fi

# 取不到就直退，避免拿着空 key 上传后收到一堆看不懂的签名错误。
case "$PGYER_API_KEY" in
    "")
        die "尚未配置蒲公英 API Key，取用顺序（环境变量 → ${DEV_ENV_FILE}）。
   请在蒲公英「账号设置 → API 密钥」复制 32 位 API Key，二选一：
    ① 写入 ${DEV_ENV_FILE}：  \"PGYER_API_KEY\": \"<你的密钥>\"
    ② 运行时注入：PGYER_API_KEY=<你的密钥> ./scripts/pgy.sh" ;;
esac

echo "==================== Tool Box 打包 + 上传蒲公英 ===================="
echo "项目根：${PROJECT_ROOT}"
echo "=================================================================="

# ---------- 第 1 步：选择平台（默认 android） ----------
if [ -z "${BUILD_PLATFORM:-}" ]; then
    echo ""
    echo "[1/3] 选择平台"
    echo "1) Android（默认）"
    echo "2) iOS"
    read -r -p "请输入序号(回车默认1): " opt1
    case "$opt1" in
        2) BUILD_PLATFORM="ios" ;;
        *) BUILD_PLATFORM="android" ;;
    esac
fi

# ---------- 第 2 步：选择 debug / release（默认 debug） ----------
if [ -z "${BUILD_MODE:-}" ]; then
    echo ""
    echo "[2/3] 选择构建模式"
    echo "1) debug（默认）"
    echo "2) release"
    read -r -p "请输入序号(回车默认1): " opt2
    case "$opt2" in
        2) BUILD_MODE="release" ;;
        *) BUILD_MODE="debug" ;;
    esac
fi

# ---------- 第 3 步：是否上传蒲公英（默认 yes） ----------
if [ -z "${NEED_UPLOAD:-}" ]; then
    echo ""
    echo "[3/3] 是否上传到蒲公英"
    echo "1) 上传（默认）"
    echo "2) 只打包不上传"
    read -r -p "请输入序号(回车默认1): " opt3
    case "$opt3" in
        2) NEED_UPLOAD="no" ;;
        *) NEED_UPLOAD="yes" ;;
    esac
fi

# 归档目录跟着模式走：debug → build/aab-apk/debug，release → build/aab-apk/release
OUTPUT_DIR="$PROJECT_ROOT/build/aab-apk/$BUILD_MODE"
# 文件名沿用 dev.sh 的规则：<APP_NAME>_<模式>_<月日时分>，如 tool_box_debug_10021009.apk
FINAL_NAME="${APP_NAME}_${BUILD_MODE}_$(date +%m%d%H%M)"
# 平台对应的扩展名：android 出 APK，ios 出 IPA
case "$BUILD_PLATFORM" in
    android) ART_EXT="apk" ;;
    ios)     ART_EXT="ipa" ;;
esac

echo ""
echo "平台：${BUILD_PLATFORM}"
echo "模式：${BUILD_MODE}"
echo "上传：${NEED_UPLOAD}"
echo "产物目录：${OUTPUT_DIR}"
echo "文件名：${FINAL_NAME}.${ART_EXT}"
echo ""

# ---------- dart-define：debug 与 release 的策略不同（对齐 dev.sh / prd.sh） ----------
if [ "$BUILD_MODE" = "release" ]; then
    DART_DEFINE=(
        --dart-define=ENV="prd"
        --dart-define=ENABLE_DEBUG_LOG="false"
        --dart-define-from-file="$ENV_FILE"
    )
else
    DART_DEFINE=(
        --dart-define=ENV="dev"
        --dart-define=ENABLE_DEBUG_LOG="true"
        --dart-define-from-file="$ENV_FILE"
    )
fi

# ---------- 打包 ----------
case "$BUILD_PLATFORM" in
    android)
        echo ">>> 构建 Android ${BUILD_MODE} APK"
        "$FLUTTER_BIN" build apk --"$BUILD_MODE" "${DART_DEFINE[@]}"
        SRC_ART="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
        ;;
    ios)
        # ⚠️ Release 模式不支持 iOS 模拟器（Flutter 硬限制：gen_snapshot 只认真机），
        #    这里走 flutter build ipa 出真机包；若报 aot_assembly 异常先检查是否有 iOS 真机连接。
        echo ">>> 构建 iOS ${BUILD_MODE} IPA"
        "$FLUTTER_BIN" build ipa --"$BUILD_MODE" "${DART_DEFINE[@]}"
        SRC_ART="$(find "$PROJECT_ROOT/build/ios/ipa" -maxdepth 1 -name "*.ipa" 2>/dev/null | head -n 1 || true)"
        ;;
esac

[ -n "${SRC_ART:-}" ] && [ -f "$SRC_ART" ] || die "构建结束但未找到产物：${SRC_ART:-<未定位到>}"

# ---------- 归档到 build/aab-apk/<模式>/（扁平结构，不插日期子目录） ----------
mkdir -p "$OUTPUT_DIR"
DEST_ART="${OUTPUT_DIR}/${FINAL_NAME}.${ART_EXT}"
mv -f "$SRC_ART" "$DEST_ART"
[ -f "$DEST_ART" ] || die "归档失败：$DEST_ART"
echo "✅ 产物：$DEST_ART"

# ---------- 上传蒲公英 ----------
upload_to_pgyer() {
    local file="$1"
    local version desc resp
    version="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1)"
    desc="${APP_NAME} ${BUILD_PLATFORM} ${BUILD_MODE} ${version:-unknown} · 自动构建上传"

    # ---------- 安装类型与密码互相兜底 ----------
    # 蒲公英只在 installType=1 时才认 buildPassword：
    #   ① 填了密码却 type=0 → 密码被静默丢弃，别人仍可无密码安装（与预期不符）→ 强制改成 1；
    #   ② type=1 却没密码   → 服务端多半直接拒（必填项），不如降级成公开安装并说清楚。
    local install_type="${PGYER_INSTALL_TYPE:-0}"
    local pw_given="no"
    if [ -n "${PGYER_PASSWORD:-}" ]; then
        install_type="1"
        pw_given="yes"
    fi
    if [ "$install_type" != "0" ] && [ "$install_type" != "1" ] && [ "$install_type" != "2" ]; then
        install_type="0"
    fi
    if [ "$install_type" = "1" ] && [ "$pw_given" = "no" ]; then
        echo "⚠️  installType=1 需要密码但 PGYER_PASSWORD 为空 → 临时按「公开安装(0)」上传"
        install_type="0"
    fi

    # 密码字段只有填了才追加（不传 installType=1 时服务端依旧走公开安装逻辑）。
    local -a pw_field=()
    if [ "$pw_given" = "yes" ]; then
        pw_field=(-F "buildPassword=${PGYER_PASSWORD}")
    fi

    echo ""
    echo ">>> 上传蒲公英：$(basename "$file")（安装方式：${install_type}）"
    # -sS 静默但仍报传输错误；-m 600 兜底防止大文件卡死。
    # 注意：**不加** --noproxy '*'——蒲公英在国内需直连，走 curl 默认的代理设置即可。
    # ⚠️ 文件字段名必须是 **file**（不是 app）——蒲公英 v2 上传接口只认 file=。
    #   早期写成 app= 时服务端连 key 都不判，直接回 1002「_api_key not found」，
    #   极易误判成「key 无效」，实际是字段名错。见 2026-10-02 排查记录。
    resp="$(curl -sS -m 600 \
        -F "_api_key=${PGYER_API_KEY}" \
        -F "file=@${file}" \
        -F "buildInstallType=${install_type}" \
        -F "buildUpdateDescription=${desc}" \
        -F "buildChannel=${PGYER_CHANNEL}" \
        ${pw_field[@]+"${pw_field[@]}"} \
        "${PGYER_UPLOAD_URL}" 2>&1 || true)"

    # 响应是 JSON（v2 接口 code=0 为成功，老的 code=200 已废弃），用 python 解析比 sed 可靠。
    printf '%s' "$resp" | /usr/bin/python3 -c '
import json, sys
raw = sys.stdin.read().strip()
try:
    d = json.loads(raw)
except Exception:
    print("❌ 蒲公英返回非 JSON（多半是网络/风控拦截或接口变更）：")
    print(raw[:400])
    sys.exit(1)
if d.get("code") != 0:
    print("❌ 上传失败 code=%s message=%s" % (d.get("code"), d.get("message")))
    sys.exit(1)
data = d.get("data") or {}
short = data.get("buildShortUrl") or data.get("buildQRCodeURL") or ""
print("✅ 上传成功")
print("   版本：%s（build %s）" % (data.get("buildShortVersion") or "?", data.get("buildBuildNumber") or "?"))
print("   短链：%s" % (short or "(未返回)"))
if not short:
    print("   备注：蒲公英未返回短链时，请到后台「应用管理 → 版本列表」查看。")
' || return 1
    return 0
}

# ---------- 打印应用页链接 + 生成它的二维码 ----------
# 上传完这一步才是给人用的：测试同学只要一个链接/一张图，不用去后台翻版本列表。
# 二维码用 segno（纯 Python、无 C 扩展依赖）本地生成，既不出网也不依赖第三方图床；
# 本机没装 segno 时降级成打印「在线二维码图片网址」，让对方把这条 URL 贴到浏览器就能看到图。
# 全局变量 PY 由 detect_qr_python 挑出可用解释器。

# 按优先级试若干个候选解释器，第一个能 import segno 的就用（结果写进全局 PY）。
detect_qr_python() {
    local cand
    for cand in "$QR_PYTHON" "$QR_VENV_PY" /usr/bin/python3 "$(command -v python3)"; do
        [ -n "$cand" ] || continue        # 候选为空就跳过（set -u 下不能直接引用未定义变量）
        [ -x "$cand" ] || continue        # 不是可执行文件说明路径不对/venv 不存在
        if "$cand" -c 'import segno' >/dev/null 2>&1; then
            PY="$cand"
            return 0
        fi
    done
    return 1
}

show_pgyer_page() {
    local url="$1"
    local qr_png="$2"          # 落盘位置：与 APK 同目录，方便一起翻找
    local online_qr

    echo ""
    echo ">>> 蒲公英应用页（链接）：${url}"
    echo "    手机/浏览器直接打开这个地址即可看到刚上传的版本与更新说明。"

    if detect_qr_python; then
        # 参数走 argv、代码走 heredoc，省掉临时文件；$1/$2 就是上面的 url / qr_png
        "$PY" - "$url" "$qr_png" <<'PY'
# 二维码生成：把给定网址编码成 PNG 存盘，并在终端用「上下半块字符」就地画一张，
# 这样命令行窗口里就能直接拿手机扫；终端不支持半块字符时以 PNG 文件为准。
import sys

import segno

url, qr_png = sys.argv[1], sys.argv[2]
# error='h' = 30% 容错等级：截图被压缩、贴到群里画质变差后仍然扫得出来。
qr = segno.make(url, error="h")
# scale=10 → 每个模块 10×10 像素，放大后在相册/聊天窗口里也清晰；border=2 是留白（静区）。
qr.save(qr_png, kind="png", scale=10, border=2)
print("    二维码 PNG：%s" % qr_png)

# segno 的 save() 只认文件格式（png/svg/text/pdf…），并没有 kind="terminal" 这种
# 「直接画到终端」的写法，所以这里自己按 matrix 用「上下半块字符」拼方阵：
# 每两行模块压成一个字符，横向字符数砍半，iTerm2 / macOS 终端里拿手机能直接扫。
# 对应关系：上下都实心 → █，只有上半 → ▀，只有下半 → ▄，都没有 → 空格（静区）。
rows = list(qr.matrix)
width = len(rows[0])
border = 2  # 静区：二维码三边最好留 4 个模块，这里 2 个够看，先省终端横向空间


def px(x, y):
    """取第 y 行第 x 列是否为黑块；越界（右下角补白）时当作空白。"""
    if 0 <= y < len(rows) and 0 <= x < width:
        return bool(rows[y][x])
    return False


def half_row(y):
    """把矩阵第 y / y+1 两行压成终端里的一行（半块字符横向刚好占一列，奇偶行各管一行）。"""
    cells = [" "] * border
    for x in range(width):
        top, bottom = px(x, y), px(x, y + 1)
        cells.append("█" if top and bottom else "▀" if top else "▄" if bottom else " ")
    return "".join(cells) + " " * border


print(" " * (width + 2 * border))  # 顶部静区
for y in range(0, len(rows), 2):  # ⚠️ 每行都要重算：不能把第一行的结果复用到所有行
    print(half_row(y))
print(" " * (width + 2 * border))  # 底部静区：让整个方阵上下留白对称
print("")
PY
    else
        # 降级：拿在线二维码图床（goqr.me）现成一张，把地址打印出来让用户贴到浏览器。
        # ⚠️ URL 里含 &，整条必须加单引号，否则 shell 会把它当后台任务理解。
        online_qr="https://api.qrserver.com/v1/create-qr-code/?data=${url}&size=300x300"
        echo "    ⚠️ 本机没找到 segno（装它：pip install segno），已降级为在线二维码图："
        echo "    ${online_qr}"
    fi
}

if [ "$NEED_UPLOAD" = "yes" ]; then
    upload_to_pgyer "$DEST_ART" || die "上传失败（产物仍在本地：${DEST_ART:-<未生成产物>}）"
else
    echo ""
    echo "（已按选择跳过上传）"
fi

echo ""
echo "🎉 流程执行完毕"
echo "产物：${DEST_ART}"
if [ "$NEED_UPLOAD" = "yes" ]; then
    echo "提示：这是 ${BUILD_MODE} 包，装包后登录所用 Supabase 环境为 $([ "$BUILD_MODE" = "release" ] && echo prd || echo dev)，与蒲公英上的二维码保持一致即可复现问题。"
else
    echo "本地安装（Android）：adb install -r $DEST_ART"
fi

# 最后一步：把「应用页链接 + 它的二维码」打出来（上传与否都打，本地只打包的人也用得上）。
# 文件名固定不带时间戳：同一目录已经有一堆带时间戳的 apk，二维码每次都换名反而难找。
show_pgyer_page "$PGYER_APP_PAGE_URL" "$OUTPUT_DIR/pgyer_tool_box_qr.png"
