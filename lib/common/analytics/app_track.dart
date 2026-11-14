// ============================================================================
// 文件：common/analytics/app_track.dart
// 模块：埋点 · 业务侧上报门面（analytics）
//
// 职责：
//   业务代码**唯一**的埋点出口。所有页面只调 [AppTrack]，不直接碰 TrackService。
//   这样一层收敛带来三个好处：
//     1) 会话级事件计数（app_session_end 的 event_count）有统一采集点；
//     2) 高频事件节流（单位换算防抖等）有统一收口，不必每个页面各写一遍；
//     3) 将来换埋点后端（友盟 / Kafka）只改这一个文件。
//
// 关键依赖：
//   - common/track/track.dart：底层埋点工具（队列 / 批量 / 传输）。
//
// 高频事件策略（doc/track.md 10.2）：
//   - 默认走 [log]（入队 + 批量上报），不打断 UI；
//   - 只有必须立刻落库的关键节点（支付漏斗各层）才用 [logNow]；
//   - 输入驱动型事件必须先经 [throttle] 去重，否则每敲一个字符就是一条事件。
// ============================================================================

import 'package:tool_box/common/track/track.dart';

import 'track_events.dart';

/// 业务侧埋点门面。
///
/// 全部为静态成员：埋点是全局单例能力，没有「多个实例」的语义。
abstract final class AppTrack {
  /// 当前前台会话内已上报的事件数，供 [TrackEvents.appSessionEnd] 的
  /// `event_count` 参数使用（衡量「会话深度」：一次打开用了多少功能）。
  ///
  /// 会话结束时由 [resetSession] 归零。
  static int _sessionEventCount = 0;

  /// 当前会话已产生的事件数（只读）。
  static int get sessionEventCount => _sessionEventCount;

  /// 全局节流器，供高频事件共用。
  ///
  /// 单独持有而非每次 new：节流依赖「上次触发时间」这一跨调用状态，
  /// 每次新建会让去重失效。
  static final TrackThrottle throttle = TrackThrottle();

  /// 上报一条事件：入队 + 由 batcher 批量/定时上传。
  ///
  /// **默认路径**。绝大多数事件走这里 —— 入队是同步且极廉价的操作
  /// （一次 Hive put），不会阻塞 UI。
  ///
  /// - [event]：事件名，取自 [TrackEvents] 常量；
  /// - [params]：业务参数。公共字段（user_id / session_id / platform 等）
  ///   由底层自动注入，这里**不要**重复传。
  static void log(String event, {Map<String, Object?>? params}) {
    _sessionEventCount++;
    TrackService.instance.log(event, params: params ?? const <String, Object?>{});
  }

  /// 上报一条事件并**立即尝试上传**（绕过批量等待）。
  ///
  /// 只用于必须尽快落库的关键节点 —— 目前仅会员支付漏斗
  /// （[TrackEvents.vipSheetShown] 起各层）。原因：支付链路中途 App 被杀的
  /// 概率不高但代价大（丢一条就少一层漏斗），而支付页本身交互稀疏，
  /// 立即 flush 不会造成性能问题。
  ///
  /// 其余事件一律用 [log]：频繁 flush 会让每条事件都单独发一次 HTTPS，
  /// 既费电又拖慢 UI。
  static Future<void> logNow(String event, {Map<String, Object?>? params}) {
    _sessionEventCount++;
    return TrackService.instance.logNow(
      event,
      params: params ?? const <String, Object?>{},
    );
  }

  /// 上报账号流程（登录 / 注册）结果。
  ///
  /// 登录与注册共用一套参数结构，因为两者的分析诉求完全一致：
  /// **成功率 + 渠道拆分**。拆成 login_success / login_failed 两个事件名
  /// 反而算不出成功率（分母要 union 两个事件），故统一一个事件 + `success` 参数。
  ///
  /// - [method]：`password` / `google` / `apple`；
  /// - [success]：成功或失败；
  /// - [errorCode]：失败时的归一化错误码（取自 `AuthException.code`）。
  ///   只上传错误码**不上传 message** —— message 可能回显用户输入的邮箱；
  /// - [register]：true 走 [TrackEvents.authRegisterResult]，false 走登录事件。
  static void authResult({
    required String method,
    required bool success,
    String? errorCode,
    bool register = false,
  }) {
    log(
      register ? TrackEvents.authRegisterResult : TrackEvents.authLoginResult,
      params: <String, Object?>{
        'method': method,
        'success': success,
        // 成功时 error_code 为 null，入库时会被自动过滤，不留空值噪声。
        'error_code': errorCode,
      },
    );
  }

  /// 上报一条异常。
  ///
  /// - [module]：出错模块（auth / isar / iap / track / flutter / platform）；
  /// - [error]：异常对象；
  /// - [stack]：可选堆栈，用于算 `stack_hash`。
  ///
  /// `stack_hash` 取栈顶帧的哈希而非完整堆栈：完整堆栈太长、逐条唯一，
  /// 无法聚合；取栈顶能让「同一类问题」归成一个计数而不是刷屏。
  /// 注意栈顶只取第一行（最内层帧），不含具体行列号以外的敏感信息。
  static void error(String module, Object error, [StackTrace? stack]) {
    final String top = stack == null
        ? ''
        : stack.toString().split('\n').first.trim();
    log(
      TrackEvents.appError,
      params: <String, Object?>{
        'module': module,
        'error_type': error.runtimeType.toString(),
        // 只留类型与栈顶，不含 message —— message 可能带用户输入或 URL 参数。
        'stack_hash': top.isEmpty ? null : top.hashCode.toRadixString(16),
      },
    );
  }

  /// 会话结束并归零计数（由 AppLifecycleTracker 在进入后台时调用）。
  static void resetSession() => _sessionEventCount = 0;
}
