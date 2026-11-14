// ============================================================================
// 文件：common/util/click_util.dart
// 模块：通用工具 / 返回手势守卫
//
// 职责：
//   承载「连按 / 连滑两次才退出 App」的判定逻辑，供路由栈的根页面接管返回手势时使用。
//
// 抽出来的原因：
//   原实现把「上次侧滑时间戳 + 600ms 阈值」散落在 MainTabPage 的 State 里
//   （_lastBackMs / _quickBackThresholdMs / _onBackInvoked），这是一段与 UI 无关的纯判定，
//   任何「根页面」（主壳层、未来的单页入口）都会需要同一套规则。这里收成 [ClickUtil]，
//   调用方只关心「这次返回要不要退出」，不必自己再存一个可变的 int。
//
// 判定规则（与抽出前的行为严格一致，未做任何语义改动）：
//   - 本次返回距上次 < 600ms → 视为「连滑第二次」→ 应当退出 App；
//   - 距上次 >= 600ms        → 视为单次返回 → 不退出、不提示，仅停留在当前页。
//   ⚠️ 顺序约束：「判定」必须先于「更新时间戳」。
//      若先更新时间戳，下一次返回永远落在阈值内，退出判定会彻底失效。
//
// 设计取舍：
//   - 用**静态**状态（单个时间戳）而非每页一个实例：同一时刻只可能有一个返回手势在计时，
//     全局唯一，静态实现更简单，调用方也不需要持有对象、不需要 dispose。
//   - 只返回 [bool]「该不该退出」，不在内部直接 pop：把「要不要真的关 App」留给调用方，
//     便于将来某些页面想先弹二次确认框、或只想吞掉这次返回；
//     [ClickUtil.handleBack] 提供了「判定 + 直接退出」的一步到位重载。
// ============================================================================

import 'package:flutter/services.dart';

/// 返回手势（侧滑 / 系统返回键 / 返回键）的「连点两次退出」守卫。
///
/// 典型用法（路由栈根页面接管返回手势时）：
///
/// ```dart
/// PopScope(
///   canPop: false,
///   onPopInvokedWithResult: (bool didPop, Object? result) {
///     // 连滑两次（间隔 < 600ms）才真正退出；单次返回只停留在当前页。
///     if (ClickUtil.shouldExit()) {
///       SystemNavigator.pop();
///     }
///   },
///   child: ...,
/// )
/// ```
///
/// 也可直接用一步到位版 [ClickUtil.handleBack]，它内部完成判定与退出。
///
/// 阈值可通过 [thresholdMs] 按次覆盖，默认值见 [defaultThresholdMs]；
/// [reset] 用于页面销毁或热重载后清空计时，避免旧时间戳把「第一次返回」误判成连滑。
class ClickUtil {
  /// 私有构造：纯工具类，不允许实例化。
  const ClickUtil._();

  /// 默认阈值（毫秒）：两次返回间隔小于该值即视为「连滑两次」。
  ///
  /// 600ms 是「手抖连滑」与「有意识连按」的分界：误触通常几十毫秒内连发，
  /// 而真正想退出时的第二次按压一般在数百毫秒以上。
  static const int defaultThresholdMs = 600;

  /// 上一次返回手势发生的时间戳（毫秒，epoch）。
  ///
  /// 初值 0（epoch），保证「刚打开 App 时的第一次返回」与上次间隔必然远大于阈值，
  /// 从而按单次返回处理，不会被误判成连滑而直接退出。
  static int _lastBackMs = 0;

  /// 当前时间戳（毫秒）。
  ///
  /// 抽成方法而不是直接用 DateTime.now()，是为了让调用方（或测试）能替换时钟来源。
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// 清空「上次返回」时间戳，回到初始状态（下一次返回必定按单次处理）。
  ///
  /// 建议在页面 [State.dispose] 里调用：静态字段在**热重载**时可能保留上一次运行的
  /// 时间戳（ hot reload 不会重置 isolate 上的静态变量），不清空的话新一次
  /// 「第一次返回」会被误判成连滑、直接把 App 关掉。
  static void reset() => _lastBackMs = 0;

  /// 本次返回手势是否应当退出 App（「连点 / 连滑两次」判定）。
  ///
  /// 会顺带刷新内部时间戳，所以一次调用即完成「判定 + 记账」。
  ///
  /// [thresholdMs] 传 null（默认）时使用 [defaultThresholdMs]（600ms）。
  ///
  /// 返回：true = 这次是「连滑第二次」，应当退出；false = 单次返回，调用方应吞掉本次手势。
  static bool shouldExit({int? thresholdMs}) {
    final int now = nowMs();
    final int threshold = thresholdMs ?? defaultThresholdMs;
    // 顺序关键：先用「与上次间隔」判定，再更新时间戳（见文件头的顺序约束）。
    final bool quick = now - _lastBackMs < threshold;
    _lastBackMs = now;
    return quick;
  }

  /// 一步到位版：判定「是否该退出」，命中时直接调用 [SystemNavigator.pop]
  /// 交由系统关闭 App（非 Android 平台该调用为 no-op，无副作用）。
  ///
  /// [thresholdMs] 传 null（默认）时使用 [defaultThresholdMs]。
  ///
  /// 返回：true = 已触发退出（调用方无需再 pop）；false = 本次返回被吞掉、仅停留。
  /// 若只想拿判定结果、不想真的退出，改用 [shouldExit]。
  static bool handleBack({int? thresholdMs}) {
    final bool exit = shouldExit(thresholdMs: thresholdMs);
    if (exit) {
      SystemNavigator.pop();
    }
    return exit;
  }
}
