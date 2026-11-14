#!/usr/bin/env bash
# ============================================================================
# 文件：scripts/flutter.sh
# 模块：tool_box / 开发脚本
#
# 职责：
#   统一包装 flutter 命令，自动注入本机跑 Flutter 必需的环境变量，
#   让你不用每次都在 shell 里手敲 export。
#
# 用法：
#   ./scripts/flutter.sh analyze                 # 静态检查（等价 flutter analyze lib）
#   ./scripts/flutter.sh test                    # widget test（headless）
#   ./scripts/flutter.sh integration [device_id] # 集成测试（自动带 local/env/prd.json）
#   ./scripts/flutter.sh run [device_id]         # 在模拟器/真机上跑 App
#   ./scripts/flutter.sh raw <任意 flutter 参数>  # 直通模式
#
# 例：
#   ./scripts/flutter.sh integration
#   ./scripts/flutter.sh integration 30757355-C790-4CBB-8752-36EDDB21CFBA
#   ./scripts/flutter.sh raw build bundle --debug
#
# ── 为什么必须设置 no_proxy（2026-09-03 踩坑，本脚本存在的唯一理由）──────
#   本机（以及 CI 沙箱）若设置了 HTTP_PROXY / HTTPS_PROXY 却没配 no_proxy，
#   Dart 的 HttpClient 会把连本机 127.0.0.1 的 flutter_tester / VM service
#   请求也发给代理。代理处理不了 WebSocket 升级，于是报：
#       Unable to connect to flutter_tester process:
#       WebSocketException: Invalid WebSocket upgrade request
#   或：
#       WebSocketException: Connection to '.../ws' was not upgraded to
#       websocket, HTTP status code: 502
#
#   这个报错极具误导性：看起来像 Xcode / Flutter / 模拟器版本不兼容，
#   实际只是代理把本地回环吃掉了。当时误判成「Xcode 26 + Flutter master
#   的集成测试在 iOS / macOS / Chrome 三平台全不可用」，白绕了一整圈。
#
#   只排除回环地址，外网仍走代理，不影响访问 Supabase / pub.dev。
#
# ── 为什么 PATH 要加 /usr/local/bin ──────────────────────────────────────
#   CocoaPods 的 pod 可执行文件装在 /usr/local/bin，而部分 shell 环境
#   默认不带它。缺了会报 "CocoaPods not installed"，哪怕 ios/Pods 已装好。
# ============================================================================

set -euo pipefail

# 定位到 tool_box 根目录（本脚本在 scripts/ 下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# —— 环境变量注入 ——
# Flutter SDK：master 分支装在 ~/sdk/flutter/master
export PATH="$HOME/sdk/flutter/master/bin:/usr/local/bin:$PATH"
# 关键：本地回环不走代理（详见文件头注释）
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost,::1"
export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost,::1"

# 默认设备：iPhone 17 模拟器。可用 `flutter devices` 查看其它 id。
DEFAULT_DEVICE="30757355-C790-4CBB-8752-36EDDB21CFBA"

subcommand="${1:-}"
shift || true

case "$subcommand" in
  analyze)
    exec flutter analyze lib
    ;;

  test)
    exec flutter test "$@"
    ;;

  integration)
    # 集成测试需要真实的 Supabase 凭据，统一从 local/env/prd.json 注入
    # （local/env/prd.json 已被 .gitignore 忽略；service_role 等敏感密钥另放 local/env/dev.json）。
    device="${1:-$DEFAULT_DEVICE}"
    shift || true
    exec flutter test integration_test/app_test.dart \
      -d "$device" \
      --dart-define-from-file=local/env/prd.json \
      "$@"
    ;;

  run)
    device="${1:-$DEFAULT_DEVICE}"
    shift || true
    exec flutter run -d "$device" --dart-define-from-file=local/env/prd.json "$@"
    ;;

  raw)
    exec flutter "$@"
    ;;

  *)
    echo "用法: $0 {analyze|test|integration [device]|run [device]|raw <args>}" >&2
    echo "      默认 device = $DEFAULT_DEVICE（iPhone 17 模拟器）" >&2
    exit 64
    ;;
esac
