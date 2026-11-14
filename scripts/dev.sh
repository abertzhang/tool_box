#!/bin/bash
set -euo pipefail

# ===================== Tool Box 本地调试/打包脚本 =====================
# 说明：
#   tool_box 是独立工具 App（riverpod + go_router + dio + hive + isar），
#   通过 --dart-define 注入编译期常量
#   （见 lib/config/app_env.dart）：
#     - ENV                ：dev / uat / prd，默认 dev
#     - SUPABASE_ANON_KEY  ：Supabase 匿名公钥（anon key 公开，随包分发安全）
#     - ENABLE_DEBUG_LOG   ：是否开启调试日志
#
APP_NAME="tool_box"
# ⚠️ Supabase 配置统一从本地密钥文件 local/env/prd.json 读取（由 --dart-define-from-file 注入）：
#    运行前请确认 local/env/prd.json 已存在（填入 SUPABASE_URL 与 SUPABASE_ANON_KEY）。
#    anon key 是公开的、随包分发安全；local/ 已被 .gitignore 忽略，不会入库。
# ============================================================================

# 绝对路径：以脚本自身位置反推项目根（与 prd.sh 同款写法），
# 保证从任意目录调用都能定位到产物目录与源文件；
# 旧实现直接用 $PWD，在别的目录调用会写错位置、也读不到正确的源文件。
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ACTION="run"
BUILD_PLATFORM="android"
BUILD_MODE="debug"

# 时间戳（仅用于文件名，不再按日期分子目录）
TIME_STAMP=$(date +%m%d%H%M)  # 月日时分（MMDDHHMM），如 10011014

# 绝对路径定义：dev 固定 Debug，产物**直接**归档到 build/aab-apk/debug/，
# 不在中间插 MMDD 日期层；命名形如：
#     build/aab-apk/debug/tool_box_debug_10011014.apk
#   └─ 与 prd.sh 的 OUTPUT_BASE_DIR（build/aab-apk）保持同一根，产物目录不分裂。
# ⚠️ 注意两点：
#   ① 本脚本用 cp 归档（保留 flutter 原始输出），归档位置在 build/ 下，会被
#      `flutter clean` 连同 flutter 自身产物一起清空；需长期保档请自行拷到
#      build/ 之外，或改用 mv（prd.sh 走的就是 mv）。
#   ② 同分钟重复跑两次会覆盖同一个文件（文件名只带到分钟），prd.sh 同理，这是预期行为；
#      想多留几版请手工加后缀，或把 TIME_STAMP 的时间粒度改细（如加 %S）。
#   ③ build/ 已被 .gitignore 忽略，产物不会入库。
OUTPUT_DIR="$PROJECT_ROOT/build/aab-apk/debug"

echo "==================== Tool Box 交互式运行/打包脚本 ===================="
echo "产物目录：${OUTPUT_DIR}"

# 前置清理+依赖
echo -e "\n========== 前置初始化 =========="
#echo "执行 flutter clean"
#flutter clean
#echo "执行 flutter pub get"
#flutter pub get
#echo "初始化完成"
echo -e "================================\n"

# 1、选择 run/build
echo "[1] 选择操作模式"
echo "1) run 运行调试（默认）"
echo "2) build 编译打包"
read -p "请输入序号(回车默认1): " opt1
case $opt1 in
    2) ACTION="build" ;;
    *) ACTION="run" ;;
esac
echo "已选择：$ACTION"

if [ "$ACTION" = "build" ]; then
    echo -e "\n[2] 选择打包平台"
    echo "1) Android（默认）"
    echo "2) iOS"
    read -p "请输入序号(回车默认1): " opt2
    case $opt2 in
        2) BUILD_PLATFORM="ios" ;;
        *) BUILD_PLATFORM="android" ;;
    esac
    echo "打包平台：${BUILD_PLATFORM}"

    # ⚠️ 固定只打 debug 包；发布包请使用 scripts/prd.sh。
    BUILD_MODE="debug"
    echo "构建模式：${BUILD_MODE}（固定 Debug）"
else
    BUILD_MODE="debug"
    echo -e "\n运行固定Debug模式"
fi

# --dart-define 参数：flutter run 与 flutter build 通用，二者都支持，安全。
# Supabase 凭据走 local/env/prd.json（--dart-define-from-file），不在脚本里硬编码。
DART_DEFINE=(
    --dart-define=ENV="dev"
    --dart-define=ENABLE_DEBUG_LOG="true"
    --dart-define-from-file=local/env/prd.json
)

# --------------------------------------------------------------------------
# AdMob 测试广告开关（仅调试用，生产包 prd.sh 不带此分支，自动失效）。
#
# 背景：iOS 模拟器会被 GMA SDK 自动识别为测试设备、直接出测试广告；
# 但安卓模拟器**不会**被自动标记，生产广告位在模拟器上通常「无填充」
# （无 GAID、新账号、未过审都会触发），表现为「没广告也没 test mode」。
#
# 用法：跑本脚本前加 ADMOB_TEST=1 即可，例如
#   ADMOB_TEST=1 ./scripts/dev.sh
#   ADMOB_TEST=1 ./scripts/dev.sh   # 选 1 运行 / 选 2 build
# 注入的是 Google 官方测试广告单元（ca-app-pub-3940256099942544/...），
# 在任何设备/模拟器上都强制返回带「Test Ad」水印的测试广告，
# 不需要在 AdMob 控制台登记测试设备，也不会产生无效流量。
# 同时注入 App ID 测试值仅用于启动日志自检（真实 App ID 仍来自原生清单）。
# --------------------------------------------------------------------------
if [[ "${ADMOB_TEST:-}" == "1" ]]; then
    echo "⚠️ [AdMob] ADMOB_TEST=1：已注入 Google 官方测试广告单元（带 Test Ad 水印）。"
    DART_DEFINE+=(
        --dart-define=ADMOB_APP_ID_ANDROID="ca-app-pub-3940256099942544~3347511713"
        --dart-define=ADMOB_APP_ID_IOS="ca-app-pub-3940256099942544~1458002511"
        --dart-define=ADMOB_BANNER_UNIT_ANDROID="ca-app-pub-3940256099942544/6300978111"
        --dart-define=ADMOB_BANNER_UNIT_IOS="ca-app-pub-3940256099942544/2934735716"
        --dart-define=ADMOB_INTERSTITIAL_UNIT_ANDROID="ca-app-pub-3940256099942544/1033173712"
        --dart-define=ADMOB_INTERSTITIAL_UNIT_IOS="ca-app-pub-3940256099942544/4411468910"
        --dart-define=ADMOB_REWARDED_UNIT_ANDROID="ca-app-pub-3940256099942544/5224354917"
        --dart-define=ADMOB_REWARDED_UNIT_IOS="ca-app-pub-3940256099942544/1712485313"
    )
fi

FINAL_NAME="${APP_NAME}_${BUILD_MODE}_${TIME_STAMP}"
TARGET_OUTPUT_DIR="${OUTPUT_DIR}"

#echo -e "\n=================================================="
#echo "操作: $ACTION | 平台: $BUILD_PLATFORM | 模式: ${BUILD_MODE}"
#echo "目标存放目录: ${TARGET_OUTPUT_DIR}"
#echo "新文件名: ${FINAL_NAME}"
#echo "=================================================="
#read -p "确认执行？回车继续，Ctrl+C终止"

# 执行逻辑
if [ "$ACTION" = "run" ]; then
    flutter run "${DART_DEFINE[@]}" --debug

elif [ "$ACTION" = "build" ]; then
    if [ "$BUILD_PLATFORM" = "android" ]; then
        echo -e "\n开始编译Android ${BUILD_MODE} APK"
        flutter build apk --"$BUILD_MODE" "${DART_DEFINE[@]}"

        SRC_APK="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
        DEST_APK="${TARGET_OUTPUT_DIR}/${FINAL_NAME}.apk"

        echo "源APK路径：$SRC_APK"
        echo "目标路径：${DEST_APK}"

        # ==========核心：不存在目录就自动创建==========
        if [ ! -d "${TARGET_OUTPUT_DIR}" ]; then
            echo "目录不存在，正在创建：${TARGET_OUTPUT_DIR}"
            mkdir -p "${TARGET_OUTPUT_DIR}"
        fi

        if [ ! -f "${SRC_APK}" ]; then
            echo "❌ 源APK不存在，编译异常终止"
            exit 1
        fi

        echo "正在复制APK文件……"
        cp -f "${SRC_APK}" "${DEST_APK}"

        if [ -f "${DEST_APK}" ]; then
            echo "✅ APK复制完成：${DEST_APK}"
        else
            echo "❌ 文件复制失败，请检查目录写入权限"
            exit 1
        fi

    elif [ "$BUILD_PLATFORM" = "ios" ]; then
        echo -e "\n开始编译iOS ${BUILD_MODE} IPA"
        flutter build ipa --"$BUILD_MODE" "${DART_DEFINE[@]}"

        SRC_IPA=$(find "$PROJECT_ROOT/build/ios/ipa" -maxdepth 1 -name "*.ipa" | head -n1)
        DEST_IPA="${TARGET_OUTPUT_DIR}/${FINAL_NAME}.ipa"

        # IPA同样自动建目录
        if [ ! -d "${TARGET_OUTPUT_DIR}" ]; then
            echo "目录不存在，正在创建：${TARGET_OUTPUT_DIR}"
            mkdir -p "${TARGET_OUTPUT_DIR}"
        fi

        if [[ -z "$SRC_IPA" || ! -f "$SRC_IPA" ]]; then
            echo "❌ IPA文件未找到"
            exit 1
        fi

        cp -f "$SRC_IPA" "$DEST_IPA"
        if [ -f "$DEST_IPA" ]; then
            echo "✅ IPA复制成功：${DEST_IPA}"
        else
            echo "❌ IPA复制失败"
            exit 1
        fi
    fi
fi

echo -e "\n🎉 全部流程执行完毕"
