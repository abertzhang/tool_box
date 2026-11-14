// ============================================================================
// 文件：test/app_review_test.dart
// 模块：我的 / 个人中心（profile）
//
// 职责：
//   覆盖 `util/app_review.dart` 的两级回落逻辑与平台判定。
//   全部是纯 Dart 测试：平台通过参数注入、评分能力通过 [AppReviewer] 假实现
//   注入，**不会真的去调系统评分 API**，因此可以在模拟器 / CI 上稳定跑。
//
// 重点锁住两条行为（改坏了会直接影响线上体验）：
//   1. iOS / macOS 在未配置 App Store ID 时**绝不能**调用 openStoreListing
//      —— 三方包在这两个平台传空 ID 会抛异常，等于把「评分」点崩；
//   2. 任一环节抛异常都要被兜住并继续回落 / 返回 unavailable，
//      绝不能让异常冒泡到页面。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/profile/util/app_review.dart';

/// [AppReviewer] 的假实现，用于精确控制各环节的行为与失败方式。
class _FakeReviewer implements AppReviewer {
  _FakeReviewer({
    this.available = true,
    this.isAvailableError,
    this.requestReviewError,
    this.openStoreError,
  });

  /// isAvailable 的返回值。
  final bool available;

  /// isAvailable 抛出的异常（非空时该方法直接 throw）。
  final Object? isAvailableError;

  /// requestReview 抛出的异常。
  final Object? requestReviewError;

  /// openStoreListing 抛出的异常。
  final Object? openStoreError;

  // —— 调用计数，用于断言「有没有误调 / 漏调」——
  int isAvailableCalls = 0;
  int requestReviewCalls = 0;
  int openStoreCalls = 0;

  /// 最后一次 openStoreListing 收到的 appStoreId。
  String? lastAppStoreId;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    if (isAvailableError != null) throw isAvailableError!;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (requestReviewError != null) throw requestReviewError!;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    openStoreCalls++;
    lastAppStoreId = appStoreId;
    if (openStoreError != null) throw openStoreError!;
  }
}

void main() {
  // 初始化 binding：最后一条用例走的是真实 InAppReviewAdapter，
  // 不初始化的话插件调用会先炸在 ServicesBinding 上，日志里刷一屏
  //「Binding has not yet been initialized」，淹没真正有用的信息。
  // 初始化之后它依然会因为渠道未注册而失败（预期行为），
  // 但错误是干净的 MissingPluginException。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canOpenStoreListing —— 平台是否需要 App Store ID', () {
    test('Android / Windows / Linux / Fuchsia 无需 App Store ID，恒为 true', () {
      // 这几个平台靠包名或 microsoftStoreId 定位，与 kAppStoreId 无关，
      // 即便 ID 为空也不影响跳转。
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          canOpenStoreListing(platform),
          isTrue,
          reason: '$platform 不依赖 App Store ID，应始终可打开商店页',
        );
      }
    });

    test('iOS / macOS 取决于 kAppStoreId 是否已配置', () {
      // 不写死 true/false 而是跟随常量：将来上架后填入真实 ID，
      // 这条用例依然成立，不会因为配置变更而误报。
      final expected = kAppStoreId.isNotEmpty;
      expect(
        canOpenStoreListing(TargetPlatform.iOS),
        expected,
        reason: 'iOS 需要 App Store ID 才能拼商店 URL',
      );
      expect(
        canOpenStoreListing(TargetPlatform.macOS),
        expected,
        reason: 'macOS 同样走 App Store，规则与 iOS 一致',
      );
    });
  });

  group('requestAppReview —— 两级回落', () {
    test('系统弹窗可用 → 走 inAppDialog，且不跳商店页', () async {
      final fake = _FakeReviewer(available: true);

      final result = await requestAppReview(
        platform: TargetPlatform.android,
        reviewer: fake,
      );

      expect(result, AppReviewResult.inAppDialog);
      expect(fake.requestReviewCalls, 1, reason: '应唤起一次系统评分弹窗');
      expect(fake.openStoreCalls, 0, reason: '弹窗已成功，不该再跳转商店页（会让用户莫名其妙离开 App）');
    });

    test('弹窗不可用 + Android → 回落 storeListing', () async {
      final fake = _FakeReviewer(available: false);

      final result = await requestAppReview(
        platform: TargetPlatform.android,
        reviewer: fake,
      );

      expect(result, AppReviewResult.storeListing);
      expect(fake.requestReviewCalls, 0, reason: '不可用时不该尝试弹窗');
      expect(fake.openStoreCalls, 1, reason: '应回落到商店详情页');
      expect(
        fake.lastAppStoreId,
        kAppStoreId,
        reason: 'appStoreId 应透传（Android 侧三方包会忽略）',
      );
    });

    test('弹窗不可用 + iOS 且未配置 ID → unavailable，绝不调 openStoreListing', () async {
      // ★ 本条是文件头强调的核心风险：iOS 未配置 ID 时若仍调用
      //   openStoreListing，三方包会抛异常，用户点「给我们评分」直接崩。
      final fake = _FakeReviewer(available: false);

      final result = await requestAppReview(
        platform: TargetPlatform.iOS,
        reviewer: fake,
      );

      // 配置为空时结果必然是 unavailable；配置就绪则允许回落跳商店。
      expect(
        result,
        kAppStoreId.isEmpty
            ? AppReviewResult.unavailable
            : AppReviewResult.storeListing,
      );
      if (kAppStoreId.isEmpty) {
        expect(
          fake.openStoreCalls,
          0,
          reason: 'iOS 未配置 App Store ID 时禁止调用 openStoreListing',
        );
      }
    });

    test('isAvailable 抛异常 → 兜住并继续回落商店页', () async {
      // 真实场景：部分 Android ROM / Play 服务异常时直接 throw 而不是返回 false。
      final fake = _FakeReviewer(
        available: true,
        isAvailableError: Exception('Play service unavailable'),
      );

      final result = await requestAppReview(
        platform: TargetPlatform.android,
        reviewer: fake,
      );

      expect(
        result,
        AppReviewResult.storeListing,
        reason: '异常应被兜住并继续下一级，不能让调用方拿到异常',
      );
    });

    test('requestReview 抛异常 → 兜住并继续回落商店页', () async {
      final fake = _FakeReviewer(
        available: true,
        requestReviewError: Exception('SKStoreReviewController failed'),
      );

      final result = await requestAppReview(
        platform: TargetPlatform.android,
        reviewer: fake,
      );

      expect(result, AppReviewResult.storeListing);
    });

    test('openStoreListing 抛异常 → 返回 unavailable 而非抛出', () async {
      final fake = _FakeReviewer(
        available: false,
        openStoreError: Exception('cannot launch store url'),
      );

      final result = await requestAppReview(
        platform: TargetPlatform.android,
        reviewer: fake,
      );

      expect(
        result,
        AppReviewResult.unavailable,
        reason: '两级都失败时应返回 unavailable，由页面给友好提示',
      );
    });

    test('默认参数可用（走真实 defaultTargetPlatform 与 InAppReviewAdapter）', () async {
      // 不注入任何参数：验证默认分支能正常构造适配器。
      // 测试环境下 defaultTargetPlatform 为 android，
      // 会尝试调真实插件；插件在单测里没有注册渠道，
      // 因此结果只会是 storeListing 或 unavailable —— 只要不抛异常即可，
      // 这条用例的意义是守住「默认参数不炸」。
      final result = await requestAppReview();
      expect(
        result,
        isIn(<AppReviewResult>{
          AppReviewResult.inAppDialog,
          AppReviewResult.storeListing,
          AppReviewResult.unavailable,
        }),
      );
    });
  });
}
