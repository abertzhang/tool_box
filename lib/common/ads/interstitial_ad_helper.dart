// ============================================================================
// 文件：common/ads/interstitial_ad_helper.dart
// 模块：广告（ads）· 插页（Interstitial）广告加载 / 展示助手
//
// 职责：
//   把「加载一条插页广告 → 全屏展示 → 等待用户关闭」这一串 AdMob 生命周期
//   封装成一个简单的 [Future<InterstitialAdResult>]：调用方无需关心
//   InterstitialAd 的 load / show / 回调细节，只要 await 它，拿到结果即可。
//
// 为什么单独成文件：
//   横幅 [banner_ad_view.dart] 是「放进布局的持续组件」，而插页是「按需全屏弹出」
//   的一次性流程，两者生命周期完全不同，混在一起会让任一方都难读。本文件只服务
//   「点击按钮 → 看一条插页广告 → 结束后发奖 / 返回」这类场景（如购买页
//   「看广告得免费次数」）。
//
// 关键约定：
//   - 仅在 [AdMobIds.isSupported] 且配置了单元 ID 时发起请求；否则立即返回
//     [InterstitialAdResult.shown]=false，不抛异常、不卡 UI。
//   - 「广告看完」以用户关闭全屏
//     （[FullScreenContentCallback.onAdDismissedFullScreenContent]）为准；
//     该回调触发后 Future 才完成，调用方据此发放奖励最稳妥。
//   - 加载失败 / 展示失败 / 平台不支持 / 20s 兜底超时，均返回 shown=false，
//     绝不向上抛异常（避免红屏或按钮卡死在 loading）。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';

import 'admob_config.dart';

/// 插页广告展示结果。
///
/// 调用方据此判定「广告是否真的看完」以及「失败原因」。
class InterstitialAdResult {
  /// 创建插页广告展示结果。
  ///
  /// - [shown]：广告是否成功展示并在用户关闭后结束（用于判定「看完」并奖励）。
  /// - [code]：加载 / 展示失败时的错误码（成功为 null）；-1 表示 20s 兜底超时。
  /// - [supported]：平台是否支持（桌面端为 false）。
  const InterstitialAdResult({
    required this.shown,
    this.code,
    this.supported = true,
  });

  /// 广告是否成功展示并结束（用户关闭全屏）。
  final bool shown;

  /// 失败错误码（成功为 null）；-1 表示兜底超时。
  final int? code;

  /// 平台是否支持插页广告。
  final bool supported;
}

/// 加载并全屏展示一条插页广告。
///
/// 参数：
/// - [slot]：埋点用的广告位标识（snake_case），用于区分不同入口的插页广告。
///
/// 返回：
/// - [InterstitialAdResult.shown]=true 表示广告完整展示并由用户关闭；
/// - 其余情况（不支持 / 无 ID / 加载失败 / 展示失败 / 超时）均为 false。
///
/// 任何异常都不向上抛出：网络抖动、SDK 未初始化、单元 ID 配错都属于「正常降级」，
/// 交由调用方决定是提示用户还是静默跳过。
Future<InterstitialAdResult> showInterstitialAd({required String slot}) async {
  // 桌面端插件无实现：直接返回不支持，不要尝试任何原生调用。
  if (!AdMobIds.isSupported) {
    return const InterstitialAdResult(shown: false, supported: false);
  }
  // 单元 ID 为空（极端情况）：同样跳过，避免 AdMob 抛「invalid ad unit id」。
  final String unitId = AdMobIds.interstitialUnitId;
  if (unitId.isEmpty) {
    return const InterstitialAdResult(shown: false, supported: false);
  }

  final Completer<InterstitialAdResult> completer =
      Completer<InterstitialAdResult>();
  InterstitialAd? ad;
  // 防止 onAdFailedToShow 与 dispose 竞态导致重复结算。
  bool settled = false;

  void finish(InterstitialAdResult result) {
    if (!settled) {
      settled = true;
      completer.complete(result);
    }
  }

  // 兜底超时：20s 内若系统没有任何回调（极少见但会发生，如 SDK 卡死），
  // 强制标记为「未展示」并结束，避免调用方按钮永远卡在 loading。
  final Timer watchdog = Timer(const Duration(seconds: 20), () {
    ad?.dispose();
    finish(const InterstitialAdResult(shown: false, code: -1));
  });

  try {
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        // 加载成功：立刻挂上全屏生命周期监听并展示。
        onAdLoaded: (InterstitialAd loaded) {
          ad = loaded;
          loaded.fullScreenContentCallback = FullScreenContentCallback(
            // 用户关闭全屏（点 X 或看完自动关）：视为「看完」，结算成功。
            onAdDismissedFullScreenContent: (Ad dismissed) {
              dismissed.dispose();
              AppTrack.log(
                TrackEvents.adInterstitialResult,
                params: <String, Object?>{
                  'slot': slot,
                  'success': true,
                  'platform': defaultTargetPlatform.name,
                },
              );
              finish(const InterstitialAdResult(shown: true));
            },
            // 广告加载成功但展示失败（如另一个全屏正在展示）：标记失败。
            onAdFailedToShowFullScreenContent: (Ad failed, AdError error) {
              failed.dispose();
              AppTrack.log(
                TrackEvents.adInterstitialResult,
                params: <String, Object?>{
                  'slot': slot,
                  'success': false,
                  'platform': defaultTargetPlatform.name,
                  'code': error.code,
                },
              );
              finish(InterstitialAdResult(shown: false, code: error.code));
            },
          );
          // 展示本身可能抛异常（极少数时序问题），就地捕获降级为失败。
          try {
            loaded.show();
          } catch (e) {
            loaded.dispose();
            finish(const InterstitialAdResult(shown: false));
          }
        },
        // 加载失败（无填充 / 单元 ID 错 / 网络）：标记失败并埋点。
        onAdFailedToLoad: (LoadAdError error) {
          AppTrack.log(
            TrackEvents.adInterstitialResult,
            params: <String, Object?>{
              'slot': slot,
              'success': false,
              'platform': defaultTargetPlatform.name,
              'code': error.code,
            },
          );
          finish(InterstitialAdResult(shown: false, code: error.code));
        },
      ),
    );
  } catch (e) {
    // load 抛异常（SDK 未初始化 / 通道异常）：直接标记失败。
    finish(const InterstitialAdResult(shown: false));
  }

  final InterstitialAdResult result = await completer.future;
  // 正常结算后取消看门狗，避免它晚一步再触发一次 dispose。
  watchdog.cancel();
  return result;
}
