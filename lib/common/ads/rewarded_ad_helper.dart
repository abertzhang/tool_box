// ============================================================================
// 文件：common/ads/rewarded_ad_helper.dart
// 模块：广告（ads）· 激励（Rewarded）广告加载 / 展示助手
//
// 职责：
//   把「加载一条激励广告 → 全屏播放 → 等用户看完 → 发放奖励」这一串 AdMob 生命周期
//   封装成一个 [Future<RewardedAdResult>]：调用方只要 await 它，看结果里 [earned]
//   是否为 true 就知道该不该发奖，不必关心 RewardedAd 的 load / show / 回调细节。
//
// 与插页广告（interstitial_ad_helper.dart）的关键差异：
//   插页是「看完/关掉就结束」的单向展示，激励广告多一个 **奖励回调**
//   （[RewardedAd.show] 的 onUserEarnedReward）——只有该回调触发才算「真的拿到奖励」。
//   因此本文件把「展示成功」与「获得奖励」拆成两个布尔：
//     · [RewardedAdResult.shown]  ：广告确实全屏播放过；
//     · [RewardedAdResult.earned] ：用户走到了奖励回调（调用方应据此发奖）。
//   正常路径两者都为 true；用户中途退出会出现 shown=true / earned=false，
//   此时**不发奖**（否则等于白送次数）。
//
// 关键约定：
//   - 仅在 [AdMobIds.isSupported] 且配置了单元 ID 时发起请求；否则立即返回
//     earned=false，不抛异常、不卡 UI。
//   - 任何异常都不向上抛出：网络抖动、SDK 未初始化、单元 ID 配错都属于「正常降级」，
//     交由调用方决定提示用户还是静默跳过。
//   - 两级看门狗：加载阶段 20s、展示阶段 150s。前者与插页一致；后者放得宽是因为
//     激励视频本身可能长达数十秒，误杀会让「看完了却没发奖」，是严重的负体验。
//
// 关键依赖：
//   - google_mobile_ads：RewardedAd / RewardedAdLoadCallback / RewardItem。
//   - common/ads/admob_config.dart：单元 ID（rewardedUnitId）。
//   - common/analytics：结果埋点（成功 / 失败 / 是否发奖）。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';

import 'admob_config.dart';

/// 激励广告展示并发奖结果。
///
/// 调用方据此判定「是否该发放奖励」以及「失败原因」。
class RewardedAdResult {
  /// 创建激励广告结果。
  ///
  /// - [earned]：是否真的走到奖励回调（**发奖的唯一依据**）。
  /// - [shown]：广告是否成功全屏展示过（用于区分「没广告」与「看了但没看完」）。
  /// - [code]：加载 / 展示失败时的错误码（成功为 null）；-1 表示兜底超时。
  /// - [supported]：平台是否支持（桌面端为 false）。
  const RewardedAdResult({
    required this.earned,
    this.shown = false,
    this.code,
    this.supported = true,
  });

  /// 用户是否获得了奖励（走到 onUserEarnedReward 回调）。
  ///
  /// 为 true 时调用方才应发放免费次数；中途退出、加载失败等情况均为 false。
  final bool earned;

  /// 广告是否成功全屏展示过。
  final bool shown;

  /// 失败错误码（成功为 null）；-1 表示兜底超时。
  final int? code;

  /// 平台是否支持激励广告。
  final bool supported;
}

/// 加载并全屏播放一条激励广告，返回用户是否获得奖励。
///
/// 参数：
/// - [slot]：埋点用的广告位标识（snake_case），用于区分不同入口的激励广告。
///
/// 返回：
/// - [RewardedAdResult.earned]=true 表示用户完整看完并触发了奖励回调，应发奖；
/// - 其余情况（平台不支持 / 无 ID / 加载失败 / 展示失败 / 中途退出 / 超时）均为 false。
///
/// 埋点：无论成败都上报 [TrackEvents.adRewardedResult]，带 slot / success /
/// rewarded / 错误码，便于线上观察填充率与「看了却没发奖」的异常组合。
Future<RewardedAdResult> showRewardedAd({required String slot}) async {
  // 桌面端插件无实现：直接返回不支持，不要尝试任何原生调用。
  if (!AdMobIds.isSupported) {
    return const RewardedAdResult(earned: false, supported: false);
  }
  // 单元 ID 为空（极端情况）：同样跳过，避免 AdMob 抛「invalid ad unit id」。
  final String unitId = AdMobIds.rewardedUnitId;
  if (unitId.isEmpty) {
    return const RewardedAdResult(earned: false, supported: false);
  }

  final Completer<RewardedAdResult> completer = Completer<RewardedAdResult>();
  RewardedAd? ad;
  // 防止多个回调竞态导致重复结算（如 dismiss 与 watchdog 同时触发）。
  bool settled = false;
  // 用户是否已走到奖励回调：这是发奖的唯一依据。
  bool earned = false;
  // 广告是否已成功全屏展示（用于区分「没广告」与「看了没看完」）。
  bool shown = false;
  Timer? watchdog;

  void finish(RewardedAdResult result) {
    if (!settled) {
      settled = true;
      watchdog?.cancel();
      completer.complete(result);
    }
  }

  /// 上报一次激励广告结果（成功 / 失败统一走这里，保证埋点口径一致）。
  ///
  /// - [success]：本次是否算成功（以是否发奖为准）；
  /// - [code]：失败错误码，成功时为 null。
  void track(bool success, {int? code}) {
    AppTrack.log(
      TrackEvents.adRewardedResult,
      params: <String, Object?>{
        'slot': slot,
        'success': success,
        'rewarded': earned,
        'platform': defaultTargetPlatform.name,
        'code': code,
      },
    );
  }

  /// 装载看门狗：[seconds] 秒内无任何系统回调则强制结算，
  /// 避免调用方按钮永久卡在 loading。
  ///
  /// 超时结算仍以 [earned] 为准：展示阶段超时但用户已拿到奖励时不能吞掉奖励。
  void armWatchdog(int seconds) {
    watchdog?.cancel();
    watchdog = Timer(Duration(seconds: seconds), () {
      ad?.dispose();
      // 展示阶段超时且已拿到奖励：仍按「已发奖」结算，避免用户白看。
      finish(
        RewardedAdResult(
          earned: earned,
          shown: shown,
          code: -1,
        ),
      );
    });
  }

  try {
    // 阶段一：加载（20s 兜底，与插页一致）。
    armWatchdog(20);
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        // 加载成功：挂上全屏生命周期监听后展示。
        onAdLoaded: (RewardedAd loaded) {
          ad = loaded;
          loaded.fullScreenContentCallback = FullScreenContentCallback(
            // 广告已全屏展示：标记为「展示过」。
            onAdShowedFullScreenContent: (Ad showed) {
              shown = true;
            },
            // 用户关闭全屏（看完或点 X）：按 [earned] 结算。
            onAdDismissedFullScreenContent: (Ad dismissed) {
              dismissed.dispose();
              track(earned);
              finish(RewardedAdResult(earned: earned, shown: shown));
            },
            // 加载成功但展示失败（如另一个全屏正在展示）：标记失败。
            onAdFailedToShowFullScreenContent: (Ad failed, AdError error) {
              failed.dispose();
              track(false, code: error.code);
              finish(
                RewardedAdResult(earned: false, shown: shown, code: error.code),
              );
            },
          );
          // 展示本身可能抛异常（极少数时序问题），就地捕获降级为失败。
          try {
            // 阶段二：展示（150s 兜底，激励视频可能较长）。
            armWatchdog(150);
            loaded.show(
              onUserEarnedReward: (AdWithoutView _, RewardItem reward) {
                // 奖励回调：记录已获得，真正的结算等 dismiss 时统一进行
                // （此时 UI 已回到本页，发奖不会出现「广告还盖着就刷新」的视觉跳变）。
                earned = true;
                debugPrint(
                  '[RewardedAd] 用户获得奖励: ${reward.amount} ${reward.type}',
                );
              },
            );
          } catch (e) {
            loaded.dispose();
            track(false);
            finish(const RewardedAdResult(earned: false));
          }
        },
        // 加载失败（无填充 / 单元 ID 错 / 网络）：标记失败并埋点。
        onAdFailedToLoad: (LoadAdError error) {
          track(false, code: error.code);
          finish(RewardedAdResult(earned: false, code: error.code));
        },
      ),
    );
  } catch (e) {
    // load 抛异常（SDK 未初始化 / 通道异常）：直接标记失败。
    track(false);
    finish(const RewardedAdResult(earned: false));
  }

  return completer.future;
}
