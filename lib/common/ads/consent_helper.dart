// ============================================================================
// 文件：common/ads/consent_helper.dart
// 模块：广告（ads）· UMP 用户同意管理（User Messaging Platform）
//
// 职责：
//   封装 Google UMP SDK 的同意流程，回答一个核心问题：**现在能不能请求广告？**
//   并向广告组件广播「同意状态已变化」，让它们在用户做出选择后自动补加载。
//
// 为什么要它（合规 + 收益双重动机，不只是合规）：
//   - 合规：面向 EEA / UK / 部分美国州的用户，必须先取得同意才能投放个性化广告；
//     GDPR 下未接 CMP（同意管理平台）是 AdMob 明确列出的违规类型（第 5 类），
//     后果是这些地区的变现被限制。
//   - 收益：**没拿到同意时只能填充非个性化广告，单价低 60~80%**。
//     换句话说，同意率是最被低估的收益杠杆——做好这一项的收益通常超过
//     全年所有广告位位置实验的总和。
//
//   关键设计：UMP 已内置在 `google_mobile_ads` 包里（lib/src/ump/*，由包入口
//   export），**不依赖 pubspec 新增任何包**，因此接入不需要跑 pub get。
//
// 流程（分两阶段，刻意拆开）：
//   阶段一（runApp 之前，见 admob_init.dart）：
//     [requestInfoUpdate] —— 纯网络请求，向 UMP 拉取本设备需要的同意状态。
//     **不弹任何 UI**，但**会走网络**，因此不能无条件 await：
//     UMP 走 Google 服务，国内网络下大概率超时，而本阶段在 runApp 之前，
//     等待时长直接等于冷启动白屏时长。故只等 [_kStartupWait]（3 秒），
//     超时就放行启动，并挂一个迟到补正回调：结果晚到时刷新状态并广播
//     [revision]，让此前跳过加载的广告组件自动补一次加载。
//   阶段二（App 首帧之后，见 main_tab_page.dart）：
//     [showFormIfRequired] —— 若状态为「需要征求同意」则弹出同意表单。
//     ⚠️ 必须在首帧之后调用：表单是原生 UI，需要一个已就绪的
//     Activity / ViewController 来 present，runApp 之前弹有失败风险。
//     ⚠️ 绝不 await 它来阻塞启动：用户可能长时间不关闭表单，
//     await 等于把 App 卡在启动页。
//     它内部会先等阶段一的**最终**结果（最多 [_kFormWait]）——
//     否则会基于超时的 `unknown` 误判成「无需征求同意」，漏掉真正该弹的设备。
//
//   同意状态变化后 [revision] 自增，[AdBannerSlot] 等组件监听它重新请求广告 ——
//   否则会出现「用户同意了，但横幅因为启动时不同意而永久空白」的死角。
//
// 失败策略：
//   UMP 任何环节失败都**降级为「视为可以请求广告」**（[canRequestAds] 异常返回 true）：
//   同意模块是合规与收益增强，不是核心功能，绝不能因为它故障让全站广告消失。
//
// 关键依赖：
//   - google_mobile_ads：ConsentInformation / ConsentForm / ConsentRequestParameters /
//     ConsentDebugSettings / FormError / ConsentStatus / PrivacyOptionsRequirementStatus。
//   - common/ads/admob_config.dart：testDeviceIds / consentDebugGeography / isSupported。
//   - common/analytics：同意流程结果埋点。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';

import 'admob_config.dart';

/// 广告同意状态（UMP）的集中管理入口。
///
/// 全部为静态方法，进程内单例（UMP SDK 本身也是单例）。
abstract final class AdsConsent {
  // --------------------------------------------------------------------------
  // 内部状态
  // --------------------------------------------------------------------------

  // --------------------------------------------------------------------------
  // 超时常量
  // --------------------------------------------------------------------------

  /// 启动阶段等待同意信息的上限（[requestInfoUpdate]）。
  ///
  /// ⚠️ 这个值**直接等于冷启动最多多白屏几秒**：本阶段在 `runApp` 之前被 await，
  /// 而 UMP 走 Google 服务，国内网络下几乎必然超时。原先的 8 秒会让每次启动
  /// 都明显卡顿；压到 3 秒后，配合「迟到补正」（结果晚到仍会广播 [revision]
  /// 让广告补加载），既不拖慢启动也不会丢掉广告。
  static const Duration _kStartupWait = Duration(seconds: 3);

  /// 阶段二弹表单前，额外等待阶段一**最终结果**的上限。
  ///
  /// 与启动等待不同：此时 App 已经起来了，多等几秒没有体验代价，
  /// 换来的是「是否弹表单」基于最终状态判定，而不是基于超时的 `unknown`。
  static const Duration _kFormWait = Duration(seconds: 12);

  /// 本会话是否已发起过同意信息请求（幂等；桌面端始终为 false）。
  static bool _requested = false;

  /// 是否真的发起过请求（桌面端直接返回，不会走到网络）。
  ///
  /// 与 [_requested] 分开：桌面端 [_requested] 不会被置位，
  /// 而这里表示「有一个在途或已结束的请求」，用于判断要不要等 [_resultReady]。
  static bool _requestStarted = false;

  /// 请求是否已有最终结局（成功回调或失败回调到达，含迟到到达）。
  static bool _requestSettled = false;

  /// 结局是否为**成功**（失败回调 / 通道异常时为 false）。
  static bool _requestSucceeded = false;

  /// 阶段一最终结果的到达信号（成功 / 失败都会 complete）。
  ///
  /// 供 [showFormIfRequired] 等待，避免它在超时窗口内基于 `unknown` 做判定。
  static final Completer<void> _resultReady = Completer<void>();

  /// 是否已尝试展示过同意表单（一次会话只弹一次，避免烦扰用户）。
  static bool _formShown = false;

  /// 阶段一拉取到的同意状态（用于日志与埋点）。
  static ConsentStatus _status = ConsentStatus.unknown;

  // --------------------------------------------------------------------------
  // 对外：状态广播
  // --------------------------------------------------------------------------

  /// 同意状态变化计数器。
  ///
  /// 每当用户完成一次同意选择（关闭同意表单 / 隐私选项表单）就自增。
  /// 广告组件在「因未取得同意而跳过加载」时应监听它，
  /// 变化后重新调用 [canRequestAds] 并补一次加载。
  ///
  /// 用 `ValueNotifier<int>` 而不是 Stream：组件只需在 dispose 里 removeListener，
  /// 没有订阅生命周期与广播时机的额外心智负担。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // --------------------------------------------------------------------------
  // 阶段一：拉取同意信息（无 UI，可安全 await）
  // --------------------------------------------------------------------------

  /// 向 UMP 请求本设备所需的同意状态。**不弹任何 UI**。
  ///
  /// 在 [initAdMob] 中、[MobileAds.initialize] 之前调用：先知道要不要征求同意，
  /// 再决定广告请求的行为。
  ///
  /// 幂等：重复调用只有第一次真正发请求。
  /// 超时保护：UMP 在弱网下可能长时间不回调（它是回调式 API，不是 Future），
  /// 这里用 Completer 包一层，最多等 [_kStartupWait]，避免拖慢冷启动。
  /// 超时**不等于放弃**：结果迟到时仍会刷新状态并广播 [revision]，
  /// 让此前跳过加载的广告组件补一次（见 [_onLateResult]）。
  static Future<void> requestInfoUpdate() async {
    // 桌面端：UMP 与 GMA 共用同一套平台通道，无实现 → 直接跳过。
    if (!AdMobIds.isSupported) return;
    if (_requested) return;
    _requested = true;
    _requestStarted = true;

    final Completer<void> done = Completer<void>();
    final ConsentDebugSettings? debug = _buildDebugSettings();

    // 标记本次请求的最终结局并放行等待者（成功 / 失败都算「已有结局」）。
    void settle(bool success) {
      _requestSettled = true;
      _requestSucceeded = success;
      if (!_resultReady.isCompleted) _resultReady.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          // 未成年标记：true 时 UMP 按未成年人处理（不个性化）。
          tagForUnderAgeOfConsent: AdMobIds.tagForUnderAgeOfConsent,
          consentDebugSettings: debug,
        ),
        () {
          // 成功：本设备需要什么级别的同意由 UMP 决定，这里只需放行。
          settle(true);
          if (!done.isCompleted) done.complete();
        },
        (FormError error) {
          // 失败：多为网络问题或控制台尚未配置同意消息。降级继续 ——
          // 拿不到同意状态时 [canRequestAds] 会放行，由 SDK 沿用上次缓存、
          // 自行降级为非个性化广告（绝不让全站广告因一次网络故障而消失）。
          debugPrint(
            '[AdsConsent] 同意信息拉取失败：code=${error.errorCode} ${error.message}',
          );
          _track(false, error.errorCode);
          settle(false);
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (e) {
      // 通道异常（如插件未注册）：同样降级继续。
      debugPrint('[AdsConsent] 同意信息请求异常：$e');
      settle(false);
      if (!done.isCompleted) done.complete();
      return;
    }

    // 超时兜底：最多等 [_kStartupWait]，到点直接放行（不阻塞 runApp）。
    bool timedOut = false;
    await done.future.timeout(_kStartupWait, onTimeout: () {
      timedOut = true;
      debugPrint(
        '[AdsConsent] 同意信息拉取超时（${_kStartupWait.inSeconds}s），'
        '按「拉取失败」降级放行并继续启动；结果迟到时会再通知广告组件。',
      );
    });

    if (timedOut) {
      // 迟到补正：请求可能只是慢，不是失败。等它真正落地后刷新状态并广播，
      // 否则本次会话会一直停在 unknown（表现为广告全站空白直到下次冷启动）。
      unawaited(done.future.then((_) => _onLateResult()));
    }

    // 记录当前状态，供启动日志与后续判断使用。
    await _refreshStatus();
  }

  /// 当前是否可以请求广告（已取得同意 / 本地区无需同意）。
  ///
  /// 广告组件在 `load()` 之前应先过这一关。
  ///
  /// ⚠️ 以下两种情况都返回 **true**（降级放行）：
  ///   ① 查询抛异常；② 阶段一的同意信息**拉取失败或超时**（详见 [_fallbackAllow]）。
  /// 宁可让广告照常请求，也不让同意模块的一次网络故障导致全站广告消失 ——
  /// 这种情况下 GMA SDK 自身会沿用缓存状态并按非个性化广告处理。
  static Future<bool> canRequestAds() async {
    if (!AdMobIds.isSupported) return false;
    if (_fallbackAllow()) {
      debugPrint(
        '[AdsConsent] 同意状态未知（拉取失败 / 超时），降级允许请求广告。',
      );
      return true;
    }
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('[AdsConsent] canRequestAds 查询失败，降级放行：$e');
      return true;
    }
  }

  // --------------------------------------------------------------------------
  // 阶段二：展示同意表单（首帧之后调用，不要 await 来阻塞启动）
  // --------------------------------------------------------------------------

  /// 若需要征求同意则弹出 UMP 同意表单。
  ///
  /// 每次会话最多尝试一次（[_formShown]）；表单关闭后自增 [revision]，
  /// 让此前因未同意而跳过的广告组件补加载。
  ///
  /// 调用处：MainTabPage 的首帧之后（addPostFrameCallback）。
  static Future<void> showFormIfRequired() async {
    if (!AdMobIds.isSupported) return;
    if (_formShown) return;
    _formShown = true;

    // 先等阶段一的**最终**结果再判定。
    //
    // 原因：本方法在首帧之后执行，很可能落在启动等待窗口内 ——
    // 若此时状态还是超时留下的 `unknown`，就会误判成「无需征求同意」而直接返回，
    // 于是真正需要弹表单的设备（EEA 用户）永远看不到表单。
    // 这里等到结果落地（或 [_kFormWait] 超时）再往下走，判定才准确。
    // 本方法是 unawaited 调用的，等一会儿不会阻塞 UI。
    if (_requestStarted && !_resultReady.isCompleted) {
      await _resultReady.future.timeout(_kFormWait, onTimeout: () {
        debugPrint('[AdsConsent] 等待最终同意状态超时，按当前状态判定是否弹表单。');
      });
    }

    try {
      final bool available =
          await ConsentInformation.instance.isConsentFormAvailable();
      final ConsentStatus status =
          await ConsentInformation.instance.getConsentStatus();
      // 没有可用表单，或本设备根本不需要征求同意（如国内用户）→ 直接返回。
      if (!available || status != ConsentStatus.required) {
        debugPrint('[AdsConsent] 无需展示同意表单（status=${status.name}）。');
        return;
      }

      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        // 表单关闭（无论用户选了同意还是拒绝）都会走到这里。
        if (error != null) {
          debugPrint(
            '[AdsConsent] 同意表单异常：code=${error.errorCode} ${error.message}',
          );
          _track(false, error.errorCode);
        } else {
          _track(true, null);
        }
        // 关键：通知广告组件重新判断（用户可能刚刚同意）。
        revision.value++;
      });
    } catch (e) {
      debugPrint('[AdsConsent] 展示同意表单失败：$e');
    }
  }

  // --------------------------------------------------------------------------
  // 隐私选项入口（GDPR 要求：用户须能随时修改同意）
  // --------------------------------------------------------------------------

  /// 本设备是否**必须**提供「隐私选项」入口。
  ///
  /// 为 true 时 App 必须在可见位置提供一个入口让用户修改同意选择，
  /// 否则属违规。profile 页据此决定是否显示「广告隐私设置」一行。
  ///
  /// ⚠️ 返回值被**缓存**（[privacyRequiredCache]）：本查询要走平台通道，
  /// 而调用方是 [FutureBuilder]，每次 rebuild 都会重新取 future ——
  /// 不缓存会导致每帧都发一次通道调用。一个会话内该状态不会变，缓存是安全的。
  static Future<bool> privacyOptionsRequired() {
    privacyRequiredCache ??= _queryPrivacyRequired();
    return privacyRequiredCache!;
  }

  /// [privacyOptionsRequired] 的查询结果缓存（进程内单例）。
  static Future<bool>? privacyRequiredCache;

  /// 真正向 UMP 查询「是否需要隐私选项入口」。
  static Future<bool> _queryPrivacyRequired() async {
    if (!AdMobIds.isSupported) return false;
    try {
      final PrivacyOptionsRequirementStatus status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('[AdsConsent] 读取隐私选项要求失败：$e');
      return false;
    }
  }

  /// 弹出 UMP 隐私选项表单（用户可在此修改同意）。
  ///
  /// 由 profile 页的设置项触发；关闭后自增 [revision]，
  /// 让广告按新状态重新加载（例如从「拒绝」改成「同意」后立即生效）。
  static Future<void> showPrivacyOptionsForm() async {
    if (!AdMobIds.isSupported) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) {
          debugPrint(
            '[AdsConsent] 隐私选项表单异常：code=${error.errorCode} ${error.message}',
          );
        }
        revision.value++;
      });
    } catch (e) {
      debugPrint('[AdsConsent] 展示隐私选项表单失败：$e');
    }
  }

  // --------------------------------------------------------------------------
  // 内部工具
  // --------------------------------------------------------------------------

  /// 重新读取并记录当前同意状态（供日志 / 埋点 / 判定使用）。
  ///
  /// 抽出这个方法是因为状态需要**多次**刷新：启动时一次，
  /// 超时后迟到结果到达时还要再刷一次。
  static Future<void> _refreshStatus() async {
    try {
      _status = await ConsentInformation.instance.getConsentStatus();
      debugPrint('[AdsConsent] 同意状态 = ${_status.name}');
    } catch (e) {
      debugPrint('[AdsConsent] 读取同意状态失败：$e');
    }
  }

  /// 阶段一结果**迟到到达**时的补正（网络慢但不是失败的情况）。
  ///
  /// 只刷新状态不够 —— 此前广告组件已经因为 `unknown` 跳过加载了，
  /// 必须自增 [revision] 才能让它们重新判定并补一次加载。
  /// 少了这一步的现象是：广告整场空白，必须杀进程重启才恢复。
  static Future<void> _onLateResult() async {
    debugPrint('[AdsConsent] 同意信息迟到到达，刷新状态并通知广告组件补加载。');
    await _refreshStatus();
    // 迟到结果可能是「需要征求同意」：广播后若仍不能请求，
    // 广告组件会保持空白，随后由 [showFormIfRequired] 弹出表单。
    revision.value++;
  }

  /// 是否应因「拉取失败 / 超时」而降级放行广告。
  ///
  /// 判定口径（与文件头「失败一律降级」的承诺保持一致）：
  ///   - 从未发起请求（桌面端）→ 不干预，交给调用方；
  ///   - 拉取**成功** → 不干预，由 UMP SDK 自己的合规判定说了算
  ///     （`required` 就是 `required`，绝不能因为我们想多赚广告费而绕过）；
  ///   - 拉取失败 / 超时且尚未迟到成功 → **放行**。
  ///
  /// 为什么最后一条要放行：此时我们连「本设备属不属于 EEA」都不知道，
  /// SDK 会按 `unknown` 一律拒绝请求广告，代价是**全站广告空白直到下次冷启动**。
  /// 这既没有换来任何合规收益（用户根本没机会做出选择），
  /// 又白白损失一次会话的全部广告收入，属于纯粹的网络故障连带损失。
  /// 放行后由 GMA SDK 沿用上次的缓存同意状态 / 降级为非个性化广告。
  static bool _fallbackAllow() {
    if (!_requestStarted) return false;
    if (_requestSettled && _requestSucceeded) return false;
    return true;
  }

  /// 构造 UMP 调试设置（仅调试用，生产包默认为 null）。
  ///
  /// 只有同时满足「配了调试地区」或「配了测试设备」时才返回非 null：
  /// - [AdMobIds.consentDebugGeography] —— 模拟用户所在地区（eea / other / ...）；
  /// - [AdMobIds.testDeviceIds] —— 命中设备才启用调试特性。
  ///
  /// ⚠️ 两者都来自 --dart-define，生产构建不带这些 key 时本方法返回 null，
  /// 不会给线上用户带来任何调试副作用。
  static ConsentDebugSettings? _buildDebugSettings() {
    final DebugGeography? geography = AdMobIds.consentDebugGeography;
    final List<String> devices = AdMobIds.testDeviceIds;
    if (geography == null && devices.isEmpty) return null;
    return ConsentDebugSettings(
      debugGeography: geography,
      testIdentifiers: devices.isEmpty ? null : devices,
    );
  }

  /// 上报一次同意流程结果（成功 / 失败统一口径）。
  static void _track(bool success, int? code) {
    AppTrack.log(
      TrackEvents.adConsentResult,
      params: <String, Object?>{
        'success': success,
        if (success == false) 'code': code,
        'status': _status.name,
      },
    );
  }
}
