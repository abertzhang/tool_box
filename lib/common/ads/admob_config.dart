// ============================================================================
// 文件：common/ads/admob_config.dart
// 模块：广告（ads）· AdMob 配置中心
//
// 职责：
//   集中存放 AdMob 的 **App ID** 与 **广告位单元 ID**，是整个工程唯一读写
//   广告 ID 的地方。业务代码只通过 [AdMobIds.bannerUnitId] / [AdMobIds.interstitialUnitId]
//   取值，不出现任何 ID 字面量，避免「Android 改了 iOS 没改」这类漏改。
//
// 当前状态（2026-09-10 更新）：
//   **横幅（banner）已换成生产 ID**（AdMob 账号 ca-app-pub-4627610691741188 下为本 App
//   创建的 Android / iOS 两个应用，各带按页面位置区分的横幅广告单元）。真 ID 会随代码进版本库 ——
//   这是刻意的：本 App 单人维护、ID 本身不是密钥，集中在一处反而最不容易漏改。
//
//   ⚠️ 插页（interstitial）单元 ID：Android / iOS 均已于 2026-09-13 回填生产单元
//   （Android .../5469115330 挂在 ...~8306626111；iOS .../9297066743 挂在 ...~4914070814）。
//   两平台均已走生产单元，[usingTestIds] 不再报警；本地想复跑测试广告请用
//   --dart-define=ADMOB_INTERSTITIAL_UNIT_ANDROID/IOS=... 注入 Google 测试 ID 覆盖。
//
//   ⚠️ 真 ID 的调试代价：用真 ID 反复请求广告会产生**无效流量**，点击自家广告更是
//   AdMob 封号的常见原因。本地开发请用上面的 --dart-define 临时切回谷歌测试 ID，
//   或在 AdMob 控制台「设置 → 测试设备」把开发机加为测试设备。
//
//   ⚠️ 激励（rewarded）单元 ID：Android 已于 2026-09-17 回填生产单元 .../8224330670、
//   iOS 同日回填 .../9160428818，两平台均走生产激励单元，[usingTestIds] 不再报警；
//   本地想复跑测试广告请用 --dart-define=ADMOB_REWARDED_UNIT_ANDROID/IOS=... 注入
//   Google 测试 ID 覆盖。
//   激励广告用于购买页「看一次广告得 5 次免费使用」（见 rewarded_ad_helper.dart）。
//
// 同意管理（UMP）与测试设备（2026-09-17 新增）：
//   三个调试开关全部走 --dart-define，**默认值都是「关闭」**，生产包不带就自动失效：
//     - ADMOB_TEST_DEVICE_IDS=ID1,ID2   → [testDeviceIds]，命中设备只收测试广告；
//     - ADMOB_CONSENT_DEBUG_GEOGRAPHY   → [consentDebugGeography]，eea/other/... 模拟地区；
//     - ADMOB_TAG_UNDER_AGE_OF_CONSENT  → [tagForUnderAgeOfConsent]，未成年标记。
//   业务流程见 consent_helper.dart：启动时拉取同意状态，首帧后按需弹表单。
//   ⚠️ 另有 **app-ads.txt** 需托管到站点根目录（否则会被限流），内容见 doc/app-ads.txt。
//
// ⚠️ 除本文件外还有**两处原生配置**需要同步填写 App ID，缺一启动即崩溃：
//   - android/app/src/main/AndroidManifest.xml → com.google.android.gms.ads.APPLICATION_ID
//   - ios/Runner/Info.plist                    → GADApplicationIdentifier
//   这两处无法从 Dart 注入（它们在引擎启动前就被原生 SDK 读取），
//   所以「换真 ID」这件事必须三处（本文件 + 两个原生清单）一起改。
//
// 关键依赖：
//   - package:flutter/foundation.dart：defaultTargetPlatform 判定 Android / iOS。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 横幅广告位所在的页面位置。
///
/// AdMob 控制台为 Android / iOS 的**每个页面位置**都单独创建了横幅单元
/// （便于分位置统计收益与对比填充率）；业务侧通过 [AdBannerSlot.position] 指定，
/// [AdMobIds.bannerUnitIdFor] 据此取 ID。
enum BannerPosition {
  /// 工具总览页（tools）。
  tools,

  /// 罗盘页（compass）。
  compass,

  /// 噪音页（noise）。
  noise,

  /// 水平仪 / 测距页（level）。
  level,

  /// 潮汐页（tides）。
  tides,

  /// 个人资料页（profile）。
  profile,
}

/// AdMob 的 App ID 与广告位单元 ID。
///
/// 全部为编译期常量（[String.fromEnvironment] 在 const 上下文可用），
/// 因此可以在 `const` 表达式里使用，也不会有任何运行期读取开销。
abstract final class AdMobIds {
  // --------------------------------------------------------------------------
  // 编译期注入（优先级最高）
  //
  // 未注入时 String.fromEnvironment 返回空字符串，下面的 getter 会据此回落到
  // 默认常量。刻意不用 nullable（String?）——那样每个取值处都要判空，
  // 而「空串 = 未注入」的表达更简洁，且在 ID 语义上空串是非法值。
  // --------------------------------------------------------------------------

  /// 编译期注入的 Android App ID。
  static const String _appIdAndroidOverride = String.fromEnvironment(
    'ADMOB_APP_ID_ANDROID',
  );

  /// 编译期注入的 iOS App ID。
  static const String _appIdIosOverride = String.fromEnvironment(
    'ADMOB_APP_ID_IOS',
  );

  /// 编译期注入的 Android Banner 广告位 ID。
  static const String _bannerAndroidOverride = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ANDROID',
  );

  /// 编译期注入的 iOS Banner 广告位 ID。
  static const String _bannerIosOverride = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_IOS',
  );

  /// 编译期注入的 Android 插页广告位 ID。
  static const String _interstitialAndroidOverride = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ANDROID',
  );

  /// 编译期注入的 iOS 插页广告位 ID。
  static const String _interstitialIosOverride = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_IOS',
  );

  /// 编译期注入的 Android 激励广告位 ID。
  static const String _rewardedAndroidOverride = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ANDROID',
  );

  /// 编译期注入的 iOS 激励广告位 ID。
  static const String _rewardedIosOverride = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_IOS',
  );

  /// 编译期注入的**测试设备**广告 ID（多个用英文逗号分隔）。
  ///
  /// 填了之后这些设备只会收到测试广告——既避免开发期产生无效流量，
  /// 又不必把真机加到 AdMob 控制台的测试设备名单里。
  static const String _testDeviceIdsOverride = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
  );

  /// 编译期注入的**同意调试地区**，取值见 [AdMobIds.consentDebugGeography]。
  ///
  /// 只在测试设备上生效（UMP 会忽略非测试设备的调试地区），用于在国内
  /// 调试 EEA 同意表单的展示效果。
  static const String _consentDebugGeographyOverride = String.fromEnvironment(
    'ADMOB_CONSENT_DEBUG_GEOGRAPHY',
  );

  /// 编译期注入：是否把用户标记为「未达同意年龄」（'true' = 未成年）。
  ///
  /// 置为 true 时 UMP 会按未成年人处理（不收集、不个性化）。
  /// 本项目面向普通工具用户，默认 false。
  static const String _tagUnderAgeOverride = String.fromEnvironment(
    'ADMOB_TAG_UNDER_AGE_OF_CONSENT',
  );

  // --------------------------------------------------------------------------
  // 生产 ID（banner 默认值，2026-09-10 由谷歌测试 ID 切换而来）
  //
  // 来自 AdMob 控制台为本 App 创建的 iOS / Android 两个应用：
  //   Android App  → App ID ...~8306626111，横幅单元已按页面位置区分（见 [_bannerAndroidByPosition]）
  //   iOS App      → App ID ...~4914070814，横幅单元亦按页面位置区分（见 [_bannerIosByPosition]）
  // 前缀 ca-app-pub-4627610691741188 是同一个 AdMob 账号（publisher ID）。
  // ⚠️ 这两处原生清单必须同步改，缺一启动即崩溃：AndroidManifest / Info.plist。
  // --------------------------------------------------------------------------

  /// 生产 App ID —— Android。
  static const String _appIdAndroid = 'ca-app-pub-4627610691741188~8306626111';

  /// 生产 App ID —— iOS。
  static const String _appIdIos = 'ca-app-pub-4627610691741188~4914070814';

  /// 生产 Banner 广告位 ID —— iOS，按页面位置区分（2026-09-19 更新）。
  ///
  /// 各位置单元来自 AdMob 控制台为 iOS App 创建的独立横幅单元，
  /// 便于分位置统计收益；与 Android 对称见 [_bannerAndroidByPosition]：
  ///   tools   → .../9082747669（即原单一单元，保持不变）
  ///   compass → .../1102346523
  ///   noise   → .../7280742066
  ///   level   → .../7493239911
  ///   tides   → .../6644473939
  ///   profile → .../3553994905
  static const Map<BannerPosition, String> _bannerIosByPosition =
      <BannerPosition, String>{
    BannerPosition.tools: 'ca-app-pub-4627610691741188/9082747669',
    BannerPosition.compass: 'ca-app-pub-4627610691741188/1102346523',
    BannerPosition.noise: 'ca-app-pub-4627610691741188/7280742066',
    BannerPosition.level: 'ca-app-pub-4627610691741188/7493239911',
    BannerPosition.tides: 'ca-app-pub-4627610691741188/6644473939',
    BannerPosition.profile: 'ca-app-pub-4627610691741188/3553994905',
  };

  /// 生产 Banner 广告位 ID —— Android，按页面位置区分（2026-09-19 更新）。
  ///
  /// 各位置单元来自 AdMob 控制台为 Android App 创建的独立横幅单元，
  /// 便于分位置统计收益；iOS 对称见 [_bannerIosByPosition]：
  ///   tools   → .../7640763350
  ///   compass → .../3040270843
  ///   noise   → .../6294963452
  ///   level   → .../1533591367
  ///   tides   → .../7176800289
  ///   profile → .../1924473602
  static const Map<BannerPosition, String> _bannerAndroidByPosition =
      <BannerPosition, String>{
    BannerPosition.tools: 'ca-app-pub-4627610691741188/7640763350',
    BannerPosition.compass: 'ca-app-pub-4627610691741188/3040270843',
    BannerPosition.noise: 'ca-app-pub-4627610691741188/6294963452',
    BannerPosition.level: 'ca-app-pub-4627610691741188/1533591367',
    BannerPosition.tides: 'ca-app-pub-4627610691741188/7176800289',
    BannerPosition.profile: 'ca-app-pub-4627610691741188/1924473602',
  };

  // --------------------------------------------------------------------------
  // 插页（interstitial）生产 ID
  //
  // 2026-09-13 更新：Android 与 iOS 插页单元均已创建并回填
  //   （Android .../5469115330 挂在 ...~8306626111；iOS .../9297066743 挂在 ...~4914070814）。
  // 两平台现在都走生产插页单元，[usingTestIds] 不再报警；如需本地复跑测试广告，
  // 用 --dart-define=ADMOB_INTERSTITIAL_UNIT_ANDROID/IOS=... 注入 Google 测试 ID 覆盖即可。
  // --------------------------------------------------------------------------

  /// 生产插页广告位 ID —— Android（2026-09-13 已填：App ...~8306626111 下的插页单元）。
  static const String _interstitialAndroid =
      'ca-app-pub-4627610691741188/5469115330';

  /// 生产插页广告位 ID —— iOS（2026-09-13 已填：App ...~4914070814 下的插页单元）。
  static const String _interstitialIos =
      'ca-app-pub-4627610691741188/9297066743';

  // --------------------------------------------------------------------------
  // 激励（rewarded）生产 ID —— ⚠️ 待填
  //
  // 2026-09-16 新增「看一次激励广告得 5 次免费使用」时，AdMob 控制台**还没建**激励单元，
  // 因此这里先留空串，[rewardedUnitId] 会回落 Google 官方测试激励 ID（不会请求到
  // 别人的广告位，也不会产生无效流量）。
  // 上线前请在控制台为本 App 的 Android / iOS 两个应用各建一个「激励广告」单元，
  // 把形如 ca-app-pub-4627610691741188/XXXXXXXXXX 的 ID 填到下面两个常量里。
  // --------------------------------------------------------------------------

  /// 生产激励广告位 ID —— Android（2026-09-17 已填：App ...~8306626111 下的激励单元
  /// `android_rewarded_use`）。
  static const String _rewardedAndroid = 'ca-app-pub-4627610691741188/8224330670';

  /// 生产激励广告位 ID —— iOS（2026-09-17 已填：App ...~4914070814 下的激励单元）。
  static const String _rewardedIos = 'ca-app-pub-4627610691741188/9160428818';

  // --------------------------------------------------------------------------
  // Google 官方测试 ID（仅用于本地调试，不参与线上默认取值）
  //
  // 文档：https://developers.google.com/admob/flutter/test-ads
  // 这四个 ID 来自 Google 的公开示例工程，任何账号都能用，且只会返回
  // 带「Test Ad」水印的测试广告。想临时切回测试广告，用上面的
  // --dart-define 注入即可（注入值优先于本文件的生产 ID）。
  // --------------------------------------------------------------------------

  /// Google 官方测试 App ID —— Android。
  static const String _testAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';

  /// Google 官方测试 App ID —— iOS。
  static const String _testAppIdIos = 'ca-app-pub-3940256099942544~1458002511';

  /// Google 官方测试 Banner 单元 ID —— Android。
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';

  /// Google 官方测试 Banner 单元 ID —— iOS。
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  /// Google 官方测试插页单元 ID —— Android。
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';

  /// Google 官方测试插页单元 ID —— iOS。
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  /// Google 官方测试激励单元 ID —— Android。
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';

  /// Google 官方测试激励单元 ID —— iOS。
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // --------------------------------------------------------------------------
  // 对外取值
  // --------------------------------------------------------------------------

  /// 当前平台的 AdMob App ID（优先取编译期注入值）。
  ///
  /// ⚠️ 这个值在 Dart 侧**仅用于日志与自检**：真正的 App ID 一定来自
  /// AndroidManifest / Info.plist，原生 SDK 在 Flutter 引擎启动前就已读取完毕，
  /// Dart 侧再传一次是无效的。这里保留它是为了在启动时打印出来，
  /// 便于核对「三处配置是否一致」（见 admob_init.dart）。
  static String get appId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _appIdAndroidOverride.isNotEmpty
            ? _appIdAndroidOverride
            : _appIdAndroid;
      case TargetPlatform.iOS:
        return _appIdIosOverride.isNotEmpty ? _appIdIosOverride : _appIdIos;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        // 桌面端 google_mobile_ads 无实现（插件只注册了 android / ios 两个平台），
        // 返回空串由调用方识别为「不支持」，不要返回测试 ID 以免误导。
        return '';
    }
  }

  /// 当前平台的 Banner 广告位 ID（优先取编译期注入值）。
  ///
  /// 桌面端返回空串：[AdBannerSlot] 见到空串会直接不加载广告，
  /// 避免在 mac / windows / linux 上抛 MissingPluginException。
  /// 当前平台、默认位置（[BannerPosition.tools]）的 Banner 广告位 ID。
  ///
  /// 历史调用大多不带位置参数，因此回落到 tools 位置；带位置的调用请直接用
  /// [bannerUnitIdFor]。桌面端返回空串（见 [bannerUnitIdFor]）。
  static String get bannerUnitId => bannerUnitIdFor(BannerPosition.tools);

  /// 指定 [position] 的横幅广告位 ID（优先取编译期注入的全局覆盖值）。
  ///
  /// - Android：按 [BannerPosition] 返回各自独立的单元（见 [_bannerAndroidByPosition]），
  ///   便于分位置统计收益与对比填充率；
  /// - iOS：同样按 [BannerPosition] 返回各自独立的单元（见 [_bannerIosByPosition]）；
  /// - 桌面端（linux / mac / windows / fuchsia）：返回空串，[AdBannerSlot] 据此
  ///   不加载广告、避免抛 MissingPluginException。
  ///
  /// 全局覆盖键 [ADMOB_BANNER_UNIT_ANDROID] / [ADMOB_BANNER_UNIT_IOS] 注入时，
  /// 所有位置统一回落到覆盖值（供本地调试一次性切测试 ID）。
  static String bannerUnitIdFor(BannerPosition position) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_bannerAndroidOverride.isNotEmpty) return _bannerAndroidOverride;
        return _bannerAndroidByPosition[position]!;
      case TargetPlatform.iOS:
        return _bannerIosOverride.isNotEmpty
            ? _bannerIosOverride
            : _bannerIosByPosition[position]!;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return '';
    }
  }

  /// 当前平台的插页（interstitial）广告位 ID（优先取编译期注入值）。
  ///
  /// 回落链：编译期注入 → 生产常量（已填）→ Google 官方测试插页 ID。
  /// Android / iOS 生产常量均已于 2026-09-13 填入真实单元
  /// （Android .../5469115330、iOS .../9297066743），两平台均走生产插页，
  /// [usingTestIds] 不再报警；如需本地复跑测试广告，用上面的 --dart-define 注入覆盖。
  /// 桌面端返回空串，调用方据此跳过插页广告、不抛异常。
  static String get interstitialUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_interstitialAndroidOverride.isNotEmpty) {
          return _interstitialAndroidOverride;
        }
        if (_interstitialAndroid.isNotEmpty) return _interstitialAndroid;
        return _testInterstitialAndroid;
      case TargetPlatform.iOS:
        if (_interstitialIosOverride.isNotEmpty) {
          return _interstitialIosOverride;
        }
        if (_interstitialIos.isNotEmpty) return _interstitialIos;
        return _testInterstitialIos;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return '';
    }
  }

  /// 当前平台的激励（rewarded）广告位 ID（优先取编译期注入值）。
  ///
  /// 回落链：编译期注入 → 生产常量（⚠️ 目前为空）→ Google 官方测试激励 ID。
  /// 生产常量还没填时走测试 ID，这是**有意为之的降级**：请求一个不存在的广告位
  /// 只会得到无填充，而填错别人的 ID 会产生无效流量甚至封号。
  /// 桌面端返回空串，调用方据此跳过激励广告、不抛异常。
  static String get rewardedUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_rewardedAndroidOverride.isNotEmpty) {
          return _rewardedAndroidOverride;
        }
        if (_rewardedAndroid.isNotEmpty) return _rewardedAndroid;
        return _testRewardedAndroid;
      case TargetPlatform.iOS:
        if (_rewardedIosOverride.isNotEmpty) return _rewardedIosOverride;
        if (_rewardedIos.isNotEmpty) return _rewardedIos;
        return _testRewardedIos;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return '';
    }
  }

  /// 当前生效的 ID 是否仍是 Google 官方测试 ID。
  ///
  /// 用途：启动日志里提醒「还没换成真 ID / 当前在测试模式」，防止上线时忘记替换
  /// （用测试 ID 上线 = 有广告位但零收入，且很难从界面上看出来）。
  ///
  /// 判定方式为**比对最终生效值**而不是「有没有注入」：
  /// 早期实现只判断注入非空，2026-09-10 默认改成生产 ID 后该逻辑就失效了
  /// （未注入时会误报 true）。现在无论 ID 来自本文件常量还是 --dart-define，
  /// 只要落到测试 ID 上就会被识别出来。
  /// 桌面端（appId 与 bannerUnitId 均为空串）视为非测试模式。
  static bool get usingTestIds {
    const Set<String> testIds = <String>{
      _testAppIdAndroid,
      _testAppIdIos,
      _testBannerAndroid,
      _testBannerIos,
      _testInterstitialAndroid,
      _testInterstitialIos,
      _testRewardedAndroid,
      _testRewardedIos,
    };
    if (testIds.contains(appId)) return true;
    // 横幅按位置可能用不同的单元 ID，逐一比对以免漏报「仍在使用测试 ID」。
    for (final BannerPosition position in BannerPosition.values) {
      if (testIds.contains(bannerUnitIdFor(position))) return true;
    }
    return testIds.contains(interstitialUnitId) ||
        testIds.contains(rewardedUnitId);
  }

  /// 登记为「测试设备」的广告 ID 列表（开发调试用）。
  ///
  /// 来源：`--dart-define=ADMOB_TEST_DEVICE_IDS=ID1,ID2`（逗号分隔，空白会被 trim）。
  /// 未注入时返回空列表，[initAdMob] 据此跳过 `updateRequestConfiguration`，
  /// 生产包因此不会残留任何调试配置。
  ///
  /// ⚠️ 这是**比 AdMob 控制台「测试设备」更轻的办法**：不必登录控制台，
  /// 也不用把设备 ID 写死进代码——用 `scripts/dev.sh` 之类的方式注入即可，
  /// 打包生产（`scripts/prd.sh` 读 prd.json）时不带这个 key 就自动失效。
  ///
  /// 设备 ID 从哪来：用真 ID 跑一次广告请求，logcat / Xcode 控制台会打印
  /// 「Use RequestConfiguration.Builder().setTestDeviceIds(...) to get test ads
  /// on this device」，引号里那串就是本机的广告 ID。
  static List<String> get testDeviceIds {
    final String raw = _testDeviceIdsOverride;
    if (raw.isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// UMP 同意表单的调试地区；未注入或取值不可识别时返回 null（= 用真实地区）。
  ///
  /// 取值：`eea` / `other` / `regulated_us_state` / `disabled`。
  /// 用途：人在国内也能弹出 EEA 同意表单，用来验证表单样式与同意后的行为。
  /// ⚠️ 只在 [testDeviceIds] 命中的设备上生效，普通用户不受影响。
  static DebugGeography? get consentDebugGeography {
    switch (_consentDebugGeographyOverride.toLowerCase()) {
      case 'eea':
        return DebugGeography.debugGeographyEea;
      case 'other':
      case 'not_eea':
        return DebugGeography.debugGeographyOther;
      case 'us_state':
      case 'regulated_us_state':
        return DebugGeography.debugGeographyRegulatedUsState;
      case 'disabled':
        return DebugGeography.debugGeographyDisabled;
      default:
        return null;
    }
  }

  /// 是否把用户标记为「未达同意年龄」（默认 false）。
  ///
  /// 置 true 时 UMP 按未成年人处理：不展示个性化广告、不收集相关数据。
  /// 注入方式：`--dart-define=ADMOB_TAG_UNDER_AGE_OF_CONSENT=true`。
  static bool get tagForUnderAgeOfConsent =>
      _tagUnderAgeOverride.toLowerCase() == 'true';

  /// 当前平台是否被 google_mobile_ads 支持。
  ///
  /// 插件的 pubspec 只注册了 android / ios 两个平台通道；
  /// 在桌面端调用任何 API 都会抛 MissingPluginException，必须先判。
  ///
  /// ⚠️ UMP（同意管理）依赖同一套通道，因此本判定同样适用于 [consent_helper]，
  /// 桌面端直接跳过整个同意流程。
  static bool get isSupported {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
