// ============================================================================
// 文件：common/ads/admob_init.dart
// 模块：广告（ads）· AdMob SDK 初始化
//
// 职责：
//   在 App 启动阶段完成「UMP 同意状态拉取 + MobileAds SDK 初始化 + 测试设备登记」
//   三件事，供 main.dart 调用。刻意与 admob_config.dart / banner_ad_view.dart
//   分开：配置是常量、组件是 UI，初始化是**有副作用的过程**，三者职责不同、
//   生命周期也不同。
//
//   三件事的顺序是固定的，不能调换：
//     ① AdsConsent.requestInfoUpdate —— 先问「能不能请求广告」（无 UI）；
//     ② MobileAds.initialize          —— 再初始化 SDK；
//     ③ updateRequestConfiguration   —— 最后注入测试设备（必须在 initialize 之后，
//        否则配置会被 SDK 初始化过程覆盖掉）。
//
// 为什么必须在 runApp 之前初始化：
//   SDK 初始化需要与原生 GMA SDK 握手（Android 建 Billing 之外的
//   MobileAds 单例；iOS 读 Info.plist 的 GADApplicationIdentifier 并做
//   SKAdNetwork 注册）。首次 `load()` 若发现未初始化，插件内部也会补一次
//   initialize()，但那次补做**无法被 try/catch 捕获**，失败会直接冒泡红屏。
//   提前显式初始化并兜住异常，是「广告挂了也不能拖垮 App」的关键一道防线。
//
// 失败策略（重要）：
//   初始化失败（无网络 / 原生清单漏配 App ID / 模拟器无 GMS）**绝不能**中断启动。
//   App ID 漏配时原生侧会直接 crash，Dart 层救不了；其余失败一律只打日志，
//   由 [AdBannerSlot] 在加载广告时自然失败并隐藏自己，用户看到的就是「没广告」。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'consent_helper.dart';

/// 初始化 AdMob SDK。
///
/// 必须在 `runApp` 之前调用（见文件头说明）。本方法**永不抛异常**：
/// 所有失败都降级为「广告不可用」，保证启动链路不被广告模块阻塞。
///
/// 调用处：main.dart 的初始化序列末尾（紧邻 Track 初始化之后）。
Future<void> initAdMob() async {
  // 桌面端（mac / windows / linux）：插件无原生实现，直接跳过。
  // 不判会在初始化时抛 MissingPluginException。
  if (!AdMobIds.isSupported) {
    debugPrint('[AdMob] 当前平台未接入广告 SDK（仅 Android / iOS 支持），跳过初始化。');
    return;
  }

  // ① 先拉 UMP 同意状态（纯网络、无 UI）。
  //
  // 顺序很关键：必须在 initialize / 任何广告请求**之前**问一次「能不能请求广告」，
  // 否则首个广告请求会带着上次的（可能已过期的）同意状态发出去。
  // 放在 try 之外：requestInfoUpdate 内部已兜住所有异常并自带 3s 超时
  // （UMP 走 Google 服务，国内网络下大概率超时，所以必须给上限，
  //  否则这段等待会直接变成冷启动白屏时间），
  // 即便完全失败也只是「按拉取失败降级放行」，不应影响下面的 SDK 初始化。
  await AdsConsent.requestInfoUpdate();

  try {
    // initialize() 返回 InitializationStatus（含各 mediation adapter 的就绪状态），
    // 这里不需要逐个 adapter 处理，只要整体成功即可。
    await MobileAds.instance.initialize();

    // ② 登记测试设备（开发调试用，生产包默认为空 → 整段跳过）。
    //
    // 命中设备只会收到测试广告，这样开发期反复请求不会产生无效流量
    // （无效流量是 AdMob 封号最常见的原因）。等价于控制台「测试设备」名单，
    // 但不用登录控制台、也不会把设备 ID 写死进版本库。
    final List<String> testDevices = AdMobIds.testDeviceIds;
    if (testDevices.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDevices),
      );
      debugPrint('[AdMob] 已登记测试设备 ${testDevices.length} 台（只收测试广告）。');
    }

    // 启动自检日志：把当前生效的 App ID 打印出来。
    // 用途是核对「Dart 常量 / AndroidManifest / Info.plist」三处是否一致 ——
    // 这三处不一致是最常见的接入故障（现象多为广告一直加载失败、错误码 3）。
    //
    // ⚠️ 注意：这里打印的是 Dart 侧的常量值，**不等于**原生实际读到的值；
    // 若只改了 Dart 没改清单，日志会显示新 ID 但原生仍用旧 ID，
    // 所以这条日志只能用来发现「我改了吗」，不能用来证明「改对了」。
    debugPrint(
      '[AdMob] SDK 初始化完成；App ID = ${AdMobIds.appId}；'
      '${AdMobIds.usingTestIds ? "⚠️ 当前使用 Google 官方测试 ID（无真实收入），上线前请在 admob_config.dart 与两端原生清单中替换为真实 ID。" : "已使用自定义 ID。"}',
    );
  } catch (e, s) {
    // 只记录不重抛：广告是变现功能，不是核心功能，
    // 绝不能因为 SDK 初始化失败导致 App 起不来。
    debugPrint('[AdMob] SDK 初始化失败：$e');
    debugPrint('$s');
  }
}
