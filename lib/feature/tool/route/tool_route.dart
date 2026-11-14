// tool_route.dart
//
// 工具箱（tool）feature 的路由定义。
// 关键依赖：go_router（GoRoute）。集中声明本模块所有子工具页面入口，
// 供 App 级路由表合并使用（模块自治 + 统一入口），与 faq_route.dart 组织方式一致。
// 路径常量与页面一一对应，便于跨页用 context.push 引用，避免硬编码字符串散落。

import 'package:go_router/go_router.dart';

import '../page/compass_page.dart';
import '../page/noise_page.dart';
import '../page/level_page.dart';
import '../page/ruler_page.dart';
import '../page/tide_page.dart';
import '../page/world_clock_page.dart';
import '../page/unit_converter/unit_converter_page.dart';
import '../page/force_converter_page.dart';
import '../page/memo_page.dart';
import '../page/memo_template_page.dart';

/// 工具箱模块路由。
///
/// 集中管理本模块路由路径常量与 GoRoute 列表。新增子工具时在此追加即可。
class ToolRoute {
  /// 指南针页路径。
  static const String compass = '/tool/compass';

  /// 噪音检测器页路径。
  static const String noise = '/tool/noise';

  /// 水平仪页路径。
  static const String level = '/tool/level';

  /// 直尺页路径。
  static const String ruler = '/tool/ruler';

  /// 潮汐页路径。
  ///
  /// ⚠️ 2026-09-25 起 tools 页入口已改为「世界时钟」，但本页与路由**保留不删**，
  /// 仍可通过路由直达（仅无页面入口引用）。
  static const String tide = '/tool/tide';

  /// 世界时钟页路径。
  static const String worldClock = '/tool/world-clock';

  /// 单位换算页路径。
  static const String unitConverter = '/tool/unit-converter';

  /// 拉力 / 承重换算器页路径。
  static const String forceConverter = '/tool/force-converter';

  /// 备忘录页路径。
  static const String memo = '/tool/memo';

  /// 备忘录模板列表页路径。
  static const String memoTemplate = '/tool/memo/templates';

  /// 本模块的全部路由表。
  static List<GoRoute> routes = [
    GoRoute(path: compass, builder: (context, state) => const CompassPage()),
    GoRoute(path: noise, builder: (context, state) => const NoisePage()),
    GoRoute(path: level, builder: (context, state) => const LevelPage()),
    GoRoute(path: ruler, builder: (context, state) => const RulerPage()),
    GoRoute(path: tide, builder: (context, state) => const TidePage()),
    GoRoute(
      path: worldClock,
      builder: (context, state) => const WorldClockPage(),
    ),
    GoRoute(
      path: unitConverter,
      builder: (context, state) => const UnitConverterPage(),
    ),
    GoRoute(
      path: forceConverter,
      builder: (context, state) => const ForceConverterPage(),
    ),
    GoRoute(
      path: memo,
      builder: (context, state) => const MemoPage(),
    ),
    GoRoute(
      path: memoTemplate,
      builder: (context, state) => const MemoTemplatePage(),
    ),
  ];
}
