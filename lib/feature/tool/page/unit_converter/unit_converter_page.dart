// ============================================================================
// 文件：feature/tool/page/unit_converter/unit_converter_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   单位换算页。顶部 AppBar 居中标题「单位换算」，其下为可横向滚动的分类选择行
//   （面积 / 体积 / 温度 / 速度 / 重量 / 长度），采用 Flutter TabBar 实现
//   （设计稿 4:1 / 4:2 中该行即为 pill 选择器）。TabBarView 的每个页签对应一个
//   独立组件，统一放在同目录的 tabs/ 子文件夹，各分类（面积/体积/温度/速度/重量/长度）
//   的换算逻辑均已实现，按设计稿填充。
//
// 设计稿配色（逐项硬编码，避免深浅串色）：
//   浅色：页面 #F5F3EF / 未选中 pill #EBE7E0 + 文字 #7A746B /
//         选中 pill 棕 #8B5C44 + 反白文字；标题 #2C2924。
//   深色：页面 #1C1C1E / 未选中 pill #2C2C2E + 文字 #8E8E93 /
//         选中 pill 浅棕 #B87B5C + 反白文字；标题 #FFFFFF。
//
// 关键依赖：
//   - flutter_screenutil_plus：响应式尺寸（.w / .h / .r / .sp）。
//   - go_router：本页路由由 ToolPage 的入口卡片触发跳转（context.push）。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';
import 'tabs/area_tab.dart';
import 'tabs/volume_tab.dart';
import 'tabs/temperature_tab.dart';
import 'tabs/speed_tab.dart';
import 'tabs/weight_tab.dart';
import 'tabs/length_tab.dart';

/// 单位换算分类（与设计稿 pill 顺序一致）。
///
/// 该顺序即 TabBar 与 TabBarView 的对应顺序，新增/调整分类时须同步修改两处。
/// 文案为多语言，故以「下标 → 本地化函数」形式持有，在 build 阶段解析。
List<String Function(AppLocalizations)> _ucCategoryLabels = <
    String Function(AppLocalizations)>[
  (l) => l.ucCatArea,
  (l) => l.ucCatVolume,
  (l) => l.ucCatTemp,
  (l) => l.ucCatSpeed,
  (l) => l.ucCatWeight,
  (l) => l.ucCatLength,
];

/// 单位换算页双主题色板。
///
/// 颜色严格取自 Pixso 设计稿（浅色 4:1 / 深色 4:2）。通用语义色（页面底 /
/// 未选中 pill 底色·文字 / 标题文字）取自 [AppPalette]，随「色卡（咖啡 / 蓝）
/// + 明暗」两个维度变化；设计稿专属的深色选中 pill 底色 #B87B5C 及其反白文字
/// 在 AppPalette 中无同值字段，保留硬编码。
class _UcTheme {
  /// 创建单位换算双主题色板。
  const _UcTheme({
    required this.pageBg,
    required this.pillBg,
    required this.pillText,
    required this.accent,
    required this.pillSelectedText,
    required this.titleText,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 未选中 pill 底色（浅色米色 / 深色深灰）。
  final Color pillBg;

  /// 未选中 pill 文字色（次级灰）。
  final Color pillText;

  /// 选中 pill 强调色（浅色棕 / 深色浅棕，对应设计稿高亮项）。
  final Color accent;

  /// 选中 pill 上的反白文字色。
  final Color pillSelectedText;

  /// 标题文字色。
  final Color titleText;

  /// 根据当前主题返回对应色板实例。
  ///
  /// 通用语义色（页面底 / 未选中 pill 底色·文字 / 选中 pill 强调色·反白文字 /
  /// 标题文字）统一取自 [AppPalette]，使其同时响应「主题色方案（咖啡色 / 蓝色）」
  /// 与「明暗模式」两个维度的切换。
  /// 深色选中 pill 底色 #B87B5C 为设计稿提亮档，[AppPalette.coffeeDark] 的
  /// accent 是 #8B5C44，两者不等，保留常量以免咖啡色主题下的视觉回归。
  static _UcTheme of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return _UcTheme(
        pageBg: app.pageBg,
        pillBg: app.cardBg,
        pillText: app.hintText,
        // 深色选中 pill 为设计稿提亮档，AppPalette 无同值字段。
        accent: const Color(0xFFB87B5C),
        // 与上面的深色 accent 配对：底为提亮棕，文字须保持反白，
        // 故不取 [AppPalette.accentText]（蓝色深底为深蓝，压在此底上对比度不足）。
        pillSelectedText: const Color(0xFFFFFFFF),
        titleText: app.titleText,
      );
    }
    return _UcTheme(
      pageBg: app.pageBg,
      pillBg: app.cardBg,
      pillText: app.labelText,
      accent: app.accent,
      pillSelectedText: app.accentText,
      titleText: app.titleText,
    );
  }
}

/// 单位换算页。
///
/// 采用 TabBar + TabBarView 实现分类切换：顶部 pill 选择器即 TabBar，
/// 下方每个分类对应一个独立页签组件，换算逻辑均已实现。
class UnitConverterPage extends StatefulWidget {
  /// 创建单位换算页（无参数）。
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage>
    with SingleTickerProviderStateMixin {
  // 设计稿中「长度」为高亮选中项（置于末位），初始即定位到它。
  late final TabController _tabController;

  /// 当前选中下标，用于驱动 pill 选中态配色（独立于 controller 缓存，便于重建）。
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // 「长度」位于分类列表末位（下标 length-1），初始即定位到它。
    _currentIndex = _ucCategoryLabels.length - 1;
    _tabController = TabController(
      length: _ucCategoryLabels.length,
      vsync: this,
      initialIndex: _currentIndex,
    );
    // 监听下标变化以重绘 pill 配色：TabBar 自身只更新其默认指示器，
    // 我们的自定义 pill 背景需在 index 实际改变时 setState 才能跟着变色。
    _tabController.addListener(_onTabChanged);
  }

  /// 下标变化回调：仅在下标真正改变时重建，刷新 pill 选中态。
  void _onTabChanged() {
    if (_tabController.index != _currentIndex) {
      setState(() => _currentIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _UcTheme theme = _UcTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(
        // 标题居中显示（设计稿为居中排布）。
        centerTitle: true,
        title: Text(l10n.ucTitle),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类选择行：可横向滚动的 pill TabBar（设计稿 4:1 / 4:2）。
          Container(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 4.h),
            child: TabBar(
              controller: _tabController,
              // 横向滚动以容纳 6 个分类 pill。
              isScrollable: true,
              // 选中态由自定义 pill 背景表达，隐藏默认下划线指示器。
              indicator: const BoxDecoration(),
              labelPadding: EdgeInsets.zero,
              tabs: _ucCategoryLabels
                  .map((f) => f(l10n))
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final int index = entry.key;
                final String category = entry.value;
                final bool selected = _currentIndex == index;
                return Tab(
                  child: Container(
                    // 仅用右侧间距分隔 pill，避免 TabBar 默认 labelPadding 叠加。
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? theme.accent : theme.pillBg,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: selected
                            ? theme.pillSelectedText
                            : theme.pillText,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // TabBarView：每个分类对应一个已实现的独立页签组件。
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const <Widget>[
                AreaTab(),
                VolumeTab(),
                TemperatureTab(),
                SpeedTab(),
                WeightTab(),
                LengthTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
