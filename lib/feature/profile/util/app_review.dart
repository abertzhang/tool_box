// ============================================================================
// 文件：feature/profile/util/app_review.dart
// 模块：我的 / 个人中心（profile）
//
// 职责：
//   封装「给我们评分（Rate Us）」能力，供 profile 页「关于」分组调用。
//
// 为什么单独抽一个文件：
//   评分涉及**两级回落**（系统内评分弹窗 → 商店详情页），且 iOS / macOS 侧还依赖
//   一个随发布状态变化的配置（App Store 数字 ID）。集中在一处之后，
//   profile 页面只管调用，不用关心平台差异与配置是否就绪。
//
// 关键依赖：
//   - in_app_review 2.x：Google 官方维护，内部封装 iOS 的
//     `SKStoreReviewController` 与 Android 的 In-App Review API。
//   - package:flutter/foundation.dart 的 [defaultTargetPlatform]：
//     用 [TargetPlatform] 做判断而不是 `dart:io` 的 Platform，
//     这样纯 Dart 单元测试可以直接注入平台枚举（见 test/app_review_test.dart）。
//
// 设计取舍：
//   1. **优先系统内弹窗**：`requestReview()` 不跳出 App，转化率更高，
//      也是两家商店官方推荐的做法。
//   2. **弹不出来才跳商店页**：iOS 模拟器、系统年度配额用尽（iOS 约 3 次/年）、
//      部分 Android 设备不支持时，`isAvailable()` 会返回 false。
//      此时跳商店详情页，用户至少还能手动写评论。
//   3. **两条路都不通就明确告知**：由调用方弹 toast，而不是静默无响应 ——
//      「点了没反应」比「点了说不支持」体验差得多。
//   4. **自有 [AppReviewer] 接口**：in_app_review 的 [InAppReview] 构造器是私有的，
//      无法在测试里直接伪造；抽一层薄接口后，单测可注入假实现覆盖全部分支，
//      业务代码也不与三方包的具体类型绑死。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// App Store 数字 ID（形如 `6448311069`）。
///
/// ⚠️ **上架后必须替换为真实 ID**，否则 iOS / macOS 侧无法跳转到商店详情页
/// （[requestAppReview] 会返回 [AppReviewResult.unavailable]）。
/// 获取方式：App Store Connect → App 信息 → 综合信息 → Apple ID。
///
/// 为什么留空而不是填占位数字：填错会导致跳转到一个不存在的商店页面，
/// 用户看到的是「无法完成操作」的报错，比明确的「暂不支持」更糟。
/// Android / Windows 不需要它 —— 分别用包名与 microsoftStoreId 定位。
const String kAppStoreId = '';

/// 评分请求的执行结果。
///
/// 让调用方据此给出不同反馈（弹窗 / 跳转本身就是明确反馈，
/// 只有 [unavailable] 需要额外提示用户）。
enum AppReviewResult {
  /// 已唤起系统应用内评分弹窗（用户停留在 App 内）。
  inAppDialog,

  /// 未能弹窗，已改为跳转到商店详情页（会离开 App）。
  storeListing,

  /// 两条路都走不通（如 iOS 未配置 App Store ID、平台不支持、调用抛异常）。
  unavailable,
}

/// 评分能力的抽象接口。
///
/// 存在的意义见文件头「设计取舍 4」：让单测能注入假实现，
/// 同时隔离 in_app_review 的具体类型。
abstract class AppReviewer {
  /// 当前设备能否显示系统内评分弹窗。
  Future<bool> isAvailable();

  /// 请求显示系统内评分弹窗。
  Future<void> requestReview();

  /// 打开商店详情页。[appStoreId] 在 iOS / macOS 上必需。
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId});
}

/// [InAppReview] 的适配器，把三方包的类型接到自有接口上。
class InAppReviewAdapter implements AppReviewer {
  /// 基于指定实例创建适配器，默认使用全局单例。
  InAppReviewAdapter([InAppReview? delegate])
    : _delegate = delegate ?? InAppReview.instance;

  final InAppReview _delegate;

  @override
  Future<bool> isAvailable() => _delegate.isAvailable();

  @override
  Future<void> requestReview() => _delegate.requestReview();

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) => _delegate.openStoreListing(
    appStoreId: appStoreId,
    microsoftStoreId: microsoftStoreId,
  );
}

/// 判断当前平台能否打开商店详情页。
///
/// 抽成纯函数是为了可测试（不需要 Flutter binding）：
/// - **iOS / macOS**：必须提供 [kAppStoreId] 才能拼出商店 URL ——
///   这是 in_app_review 在这两个平台上的硬性要求，传空会抛异常；
/// - **Android / Windows / 其他**：靠包名或 microsoftStoreId 定位，
///   无需 App Store ID。
bool canOpenStoreListing(TargetPlatform platform) {
  const needsStoreId = <TargetPlatform>{
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  };
  return !needsStoreId.contains(platform) || kAppStoreId.isNotEmpty;
}

/// 触发应用评分。
///
/// 流程：先尝试系统内评分弹窗；不可用时回落到商店详情页；都不可用返回
/// [AppReviewResult.unavailable]。
///
/// 参数：
/// - [platform] 目标平台，默认取 [defaultTargetPlatform]；
///   单测可注入任意平台以覆盖两条分支。
/// - [reviewer] 评分能力实现，默认 [InAppReviewAdapter]；
///   单测可注入假实现，避免真的去调系统 API。
///
/// 全程 try/catch：Android 侧 In-App Review 在部分 ROM / Play 服务异常时
/// 会直接抛异常而不是返回 false，不兜住就会连带把页面点崩。
Future<AppReviewResult> requestAppReview({
  TargetPlatform? platform,
  AppReviewer? reviewer,
}) async {
  final AppReviewer impl = reviewer ?? InAppReviewAdapter();

  // ── 第一级：系统应用内评分弹窗 ──
  try {
    if (await impl.isAvailable()) {
      await impl.requestReview();
      return AppReviewResult.inAppDialog;
    }
  } catch (e) {
    // 弹不出来不算致命错误，继续尝试下一级。
    // 用 debugPrint 而不是静默吞掉：真机上如果频繁走到这里，
    // 说明设备不支持，需要看日志定位。
    debugPrint('[AppReview] requestReview 失败，回落商店页面: $e');
  }

  // ── 第二级：跳商店详情页 ──
  if (!canOpenStoreListing(platform ?? defaultTargetPlatform)) {
    return AppReviewResult.unavailable;
  }
  try {
    // Android 会忽略 appStoreId（用包名）；iOS / macOS 必需。
    // 能走到这一行说明要么平台不需要 ID、要么 ID 已配置
    //（未配置的情况上面已提前返回）。
    await impl.openStoreListing(appStoreId: kAppStoreId);
    return AppReviewResult.storeListing;
  } catch (e) {
    debugPrint('[AppReview] openStoreListing 失败: $e');
    return AppReviewResult.unavailable;
  }
}
