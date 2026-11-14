// ============================================================================
// 文件：common/analytics/track_page_observer.dart
// 模块：埋点 · 页面浏览（analytics）
//
// 职责：
//   以 NavigatorObserver 统一采集 `page_view`，挂在 GoRouter 的 observers 上，
//   **不要求任何页面手写埋点**。
//
// 为什么用观察者而不是每个页面手写（doc/track.md 10.1）：
//   手写意味着「新增页面」和「加埋点」是两件事，漏埋是必然的；
//   观察者把这件事收敛成一处，新增路由自动获得 PV 统计。
//
// 关键依赖：
//   - go_router：路由名来自 RouteSettings.name，go_router 填的是
//     `state.name ?? state.path`（见 go_router 源码 builder.dart），
//     即稳定路径如 '/home' '/tool/compass'，不带 query 参数 —— 正好可作为页面 ID。
//   - common/track/track.dart + app_track.dart：上报出口。
// ============================================================================

import 'package:flutter/widgets.dart';

import 'app_track.dart';
import 'track_events.dart';

/// 全局页面浏览埋点观察者。
///
/// 覆盖三种导航动作：
///   - [didPush]：新页面入栈（含启动屏 → 首页、工具卡片 push 子页）；
///   - [didPop]：栈顶弹出，**被露出的是 previousRoute**，因此记录 previousRoute；
///   - [didReplace]：路由替换（go 到同分支时可能走这条）。
///
/// 弹窗（showDialog / showModalBottomSheet）推入的路由 `settings.name` 为 null，
/// 会在 [_log] 开头被过滤掉 —— 弹窗不是「页面」，计入 PV 会污染页面维度。
class TrackPageObserver extends NavigatorObserver {
  /// 同一页面在该窗口内的重复上报会被丢弃。
  ///
  /// 存在的理由：连点两次工具卡片、或 go_router 在同一次跳转里同时派发
  /// replace + push，都会让同一页面在几十毫秒内被记录两次。
  /// 800ms 足以吃掉这类抖动，又不会影响正常的用户往返浏览。
  static const Duration _dedupeWindow = Duration(milliseconds: 800);

  /// 页面 → 上次记录时间，用于去重。
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // pop 之后露出的是下面的那一页，所以 page 取 previousRoute。
    _log(previousRoute?.settings.name, route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log(newRoute?.settings.name, oldRoute?.settings.name);
  }

  /// 记录一次页面浏览。
  ///
  /// - [page]：当前可见页面（路由路径）；
  /// - [from]：来源页面（路由路径），可能为 null（首屏无来源）。
  ///
  /// 走 [AppTrack.log] 而非 logNow：`page_view` 是量级最大的事件之一
  /// （doc/track.md 10.2），必须批量上报，逐条 flush 会拖慢导航动画。
  void _log(String? page, String? from) {
    // 无名字的路由（弹窗等）直接忽略。
    if (page == null || page.isEmpty) return;

    final DateTime now = DateTime.now();
    final DateTime? last = _lastSeen[page];
    if (last != null && now.difference(last) < _dedupeWindow) return;
    _lastSeen[page] = now;

    AppTrack.log(
      TrackEvents.pageView,
      params: <String, Object?>{'page': page, 'from': from, 'via': 'router'},
    );
  }
}
