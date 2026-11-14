// ============================================================================
// 文件：common/analytics/app_lifecycle_tracker.dart
// 模块：埋点 · 会话生命周期（analytics）
//
// 职责：
//   采集两个「会话级」事件，它们无法由任何单个页面负责，只能在 App 层观察：
//     - [TrackEvents.appOpen]     warm 启动（冷启动由启动屏负责，见 splash_page.dart）
//     - [TrackEvents.appSessionEnd] 进入后台，带本次前台时长与事件数
//
// 冷 / 热启动为什么要分开打：
//   冷启动要带 `splash_ms`（验证 3 秒启动屏是否拖慢进入主流程），
//   这个数据只有启动屏自己知道；热启动没有启动屏，只能由生命周期观察者补。
//   两者 `launch_type` 不同，落到库里可以直接 `group by launch_type` 拆开看。
//
// 关键依赖：
//   - WidgetsBindingObserver：监听 AppLifecycleState。
//   - app_track.dart：上报出口。
// ============================================================================

import 'package:flutter/widgets.dart';
import 'package:tool_box/common/track/track.dart';

import 'app_track.dart';
import 'track_events.dart';

/// 会话级埋点观察者。
///
/// 使用方式：在 `main()` 里 `runApp` 之前 [install] 一次，进程等长，无需卸载。
///
/// 为什么不在 Widget tree 里做：冷启动的第一个 `resumed` 事件在
/// ProviderScope / MaterialApp 建立之前就可能派发，挂在 Widget 上会漏掉。
class AppLifecycleTracker with WidgetsBindingObserver {
  /// 本次前台会话的起点（首次 resumed 或 install 时刻）。
  DateTime _foregroundSince = DateTime.now();

  /// 上次进入后台的时刻；null 表示尚未经历过后退到后台。
  DateTime? _pausedAt;

  /// 是否已经上报过至少一次「进入前台」后的会话，用于判断首帧。
  bool _installed = false;

  /// 判定为「热启动」而非「误触切后台」的最小后台时长。
  ///
  /// 30 秒：短于这个时长的进出（看下通知、切去复制验证码再回来）
  /// 在体感上仍是同一次使用，算成两次会话会把 DAU 与会话时长都算虚高。
  static const Duration _warmThreshold = Duration(seconds: 30);

  /// 注册到全局 WidgetsBinding，开始监听生命周期。
  ///
  /// 幂等：重复调用不会重复注册（避免 hot reload 后成对出现 session_end）。
  void install() {
    if (_installed) return;
    _installed = true;
    _foregroundSince = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  /// 生命周期变化回调。
  ///
  /// 只关心两件事：回到前台（可能要补一次 warm 的 [TrackEvents.appOpen]）
  /// 与离开前台（上报 [TrackEvents.appSessionEnd]）。
  /// `inactive` 不处理：它在 iOS 下拉通知栏、接来电时也会触发，
  /// 此时用户并没有离开 App，记为会话结束会严重低估使用时长。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _onBackground();
      case AppLifecycleState.inactive:
        // 见上：下拉通知栏 / 来电 / 切 App 切换器都属于 inactive，
        // 不计入会话结束。
        break;
    }
  }

  /// 回到前台：按后台停留时长决定是否补一次热启动。
  void _onResumed() {
    final DateTime now = DateTime.now();
    final DateTime? pausedAt = _pausedAt;

    if (pausedAt != null) {
      final Duration gap = now.difference(pausedAt);
      if (gap >= _warmThreshold) {
        // 后台待得够久 —— 视为一次新的使用。
        AppTrack.log(
          TrackEvents.appOpen,
          params: <String, Object?>{
            'launch_type': 'warm',
            // 后台停留时长：用于校准 30 秒阈值合不合理
            // （若大量 warm 事件的 bg_ms 集中在阈值附近，说明阈值定偏了）。
            'bg_ms': gap.inMilliseconds,
          },
        );
      }
      _pausedAt = null;
    }
    _foregroundSince = now;
  }

  /// 离开前台：结算本次会话。
  ///
  /// 重复调用是安全的（paused 与 hidden 在部分平台会连续派发），
  /// 第二次进入时 [_pausedAt] 已非 null 会直接返回，不会重复计数。
  void _onBackground() {
    // 已经结算过：paused / hidden / detached 可能连续派发，只认第一次。
    if (_pausedAt != null) return;
    final DateTime now = DateTime.now();
    _pausedAt = now;

    AppTrack.log(
      TrackEvents.appSessionEnd,
      params: <String, Object?>{
        'duration_ms': now.difference(_foregroundSince).inMilliseconds,
        // 本次会话产生了多少条事件 —— 即「会话深度」。
        // 用它区分「打开看一眼就走」和「连着用了五六个功能」。
        'event_count': AppTrack.sessionEventCount,
      },
    );
    // 会话已结算，计数归零，下次前台重新累计。
    AppTrack.resetSession();
    // 离开前台是最后的上传窗口：进程随时可能被系统回收，
    // 此时 flush 能把队列里的事件尽量送出去。
    _flushQuietly();
  }

  /// 触发一次队列 flush，忽略返回值与异常。
  ///
  /// 埋点绝不能反过来影响 App 退出流程，因此不 await、不抛异常：
  /// 网络失败时事件仍留在 Hive 队列里，下次启动会补传。
  void _flushQuietly() {
    Future<void>.sync(() async {
      try {
        await TrackService.instance.flush();
      } catch (_) {
        // 静默：退出后台时的网络失败属常态，重试交给下次启动。
      }
    });
  }
}
