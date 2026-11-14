// ============================================================================
// 文件：feature/home/widget/main_bottom_nav.dart
// 模块：首页 / 应用主壳（home）
//
// 职责：
//   1. 定义底部导航的 Tab 枚举 BottomTab；
//   2. 提供全局 Tab 下标状态源 tabIdxProvider（Riverpod Notifier）；
//   3. 实现自绘的底部导航栏 MainBottomNav 及其单项 _MainBottomNavItem。
//
// 为什么自绘而不用 BottomNavigationBar / NavigationBar：
//   设计稿（Pixso 节点 3:262）要求「选中项带主色投影的浮起效果」、固定 83pt 高、
//   自定义图标/文字尺寸与 0.3pt 分隔线，Material 内置组件无法在不 hack 的前提下
//   还原，因此用 Material + Row + Expanded 自行实现。
//
// 关键依赖：
//   - flutter_riverpod：跨组件共享当前 Tab 下标。
//   - l10n/app_localizations.dart：Tab 文案多语言。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 底部导航 Tab 枚举。
///
/// 声明顺序即为界面从左到右的顺序，也对应 [tabIdxProvider] 的下标语义，
/// 并且必须与 [MainTabPage] 中 body 页面数组的顺序保持一致。
enum BottomTab { tools, profile }

/// 当前选中 Tab 的下标 Provider（全局唯一状态源）。
///
/// 由 [MainBottomNav] 写入、[MainTabPage] 读取；
/// 其他业务代码也可通过它以编程方式跳转 Tab。
final tabIdxProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);

/// Tab 下标状态管理器。
///
/// 仅维护一个 int 下标，不持有页面实例，保证状态足够轻量、可随时重建。
class TabIndexNotifier extends Notifier<int> {
  /// 初始下标：0，即默认落在「工具」Tab（本工程的主页面）。
  @override
  int build() {
    return 0;
  }

  /// 切换到指定下标的 Tab。
  ///
  /// [idx] 取值需在 0 ~ items.length-1 之间；这里不做越界校验，
  /// 因为调用方是 [MainBottomNav] 内基于 items 长度生成的按钮，天然安全。
  void setIdx(int idx) {
    state = idx;
  }
}

/// 应用底部导航栏。
///
/// 自绘实现，负责渲染两个 Tab 项、处理点击写入 [tabIdxProvider]，
/// 并按当前明暗模式切换色板。
///
/// 标记为 `final class`：该导航栏样式与设计稿强绑定，不希望被继承改写。
final class MainBottomNav extends ConsumerWidget {
  /// 创建底部导航栏。
  ///
  /// 无参数：选中态与切换逻辑全部走 [tabIdxProvider]，
  /// 因此可以被声明为 const，避免父级重建时产生无谓的 Widget 实例。
  const MainBottomNav({super.key});

  /// 构建底部导航栏。
  ///
  /// - 监听 [tabIdxProvider] 得到选中下标；
  /// - 依据 [Brightness] 选择双主题色板；
  /// - 文案取自 [AppLocalizations]，切换语言即时生效。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIdx = ref.watch(tabIdxProvider);
    // read：只在点击回调里调用 setIdx，无需监听 Notifier 本身的变化。
    final tabLogic = ref.read(tabIdxProvider.notifier);
    // 语义色板：背景与分隔线取自它，以跟随「主题色方案 + 明暗」两个维度变化。
    final AppPalette app = AppPalette.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    //   深色：背景 #1C1C1E / 选中 = 主题主色 / 未选中 #5A5450 / 分隔线 #3A3A3C
    //   浅色：背景 #F5F3EF / 选中 = 主题主色 / 未选中 #B5AFA7 / 分隔线 #E4E0D9
    final palette = _BottomNavPalette(
      background: app.pageBg,
      // 选中态直接取当前主题主色：咖啡色下即暖金 #C8A97E / 深咖 #6B5C44，
      // 切到蓝色主题后自动变为晴空蓝，无需在此维护第二组值。
      selected: Theme.of(context).colorScheme.primary,
      // 未选中项用中性灰：与色卡无关，两套主题共用同一组值，
      // 避免切主题后未选中图标的对比度发生不必要的变化。
      unselected: isDark ? const Color(0xFF5A5450) : const Color(0xFFB5AFA7),
      divider: app.divider,
    );
    final localizations = AppLocalizations.of(context)!;
    // Tab 清单：顺序必须与 BottomTab 枚举、MainTabPage 的 body 数组三方一致。
    // tool_box 仅保留「工具」与「我的」两项。
    final items = <_BottomNavItemData>[
      _BottomNavItemData(Icons.build_outlined, localizations.tools),
      _BottomNavItemData(Icons.person_outline, localizations.profile),
    ];

    return Material(
      // 固定 Key：供 Widget 测试定位背景层并校验背景色是否随主题切换。
      key: const Key('main-bottom-nav-background'),
      color: palette.background,
      child: Container(
        // 顶部 0.3pt 细分隔线（设计稿要求的发丝线），
        // 用 Border 而非 Divider，避免额外占用布局高度。
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: palette.divider, width: 0.3.w),
          ),
        ),
        child: SafeArea(
          // 关闭 SafeArea 的自动上下内边距，改用 minimum 手动指定：
          // 全面屏机型 Home Indicator 高度不一，这里统一预留 20pt 底部安全距，
          // 保证不同机型下导航项的视觉位置一致（设计稿按 20pt 出图）。
          top: false,
          bottom: false,
          minimum: .only(bottom: 5.h),
          child: SizedBox(
            key: const Key('main-bottom-nav-content'),
            // 83pt：设计稿规定的导航内容区高度，写死以保证还原度。
            height: 83.h,
            child: Row(
              // 用 List.generate 而非 map：需要 index 同时用于选中判定、
              // 点击回调传参以及生成稳定的测试 Key。
              children: List.generate(items.length, (index) {
                final item = items[index];
                // Expanded：两个 Tab 等分宽度，适配不同屏宽。
                return Expanded(
                  child: _MainBottomNavItem(
                    key: Key('main-bottom-nav-item-$index'),
                    iconKey: Key('main-bottom-nav-icon-$index'),
                    icon: item.icon,
                    label: item.label,
                    selected: currentIdx == index,
                    palette: palette,
                    onTap: () => tabLogic.setIdx(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个 Tab 的静态数据（图标 + 文案）。
///
/// 仅作为 [MainBottomNav.build] 内部的临时数据载体，
/// 不承载状态，因此定义为不可变的私有 final class。
final class _BottomNavItemData {
  /// [icon] 为线性图标，[label] 需传入已本地化的文案。
  const _BottomNavItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// 底部导航双主题色板。
///
/// 把「深色/浅色」两套取值收敛到一个对象里，向下传递，
/// 避免子组件各自再去判断 [Brightness]，也便于单元测试直接注入色板。
///
/// 取值来源：Pixso 设计稿底部导航节点（深色 / 浅色两版），
/// 详见 [MainBottomNav.build] 中的构造处注释。
final class _BottomNavPalette {
  const _BottomNavPalette({
    required this.background,
    required this.selected,
    required this.unselected,
    required this.divider,
  });

  /// 导航栏底色。
  final Color background;

  /// 选中态图标/文字颜色，同时用作选中项投影的基色。
  final Color selected;

  /// 未选中态图标/文字颜色。
  final Color unselected;

  /// 顶部分隔线颜色。
  final Color divider;
}

/// 底部导航单项。
///
/// 负责渲染「图标 + 文字」、选中态的浮起投影，以及无障碍语义与点击响应。
final class _MainBottomNavItem extends StatelessWidget {
  /// 创建导航单项。
  ///
  /// - [iconKey]：图标专用测试 Key，便于测试直接断言图标颜色；
  /// - [icon]/[label]：展示内容，[label] 需为已本地化文案；
  /// - [selected]：是否选中，决定配色、字重与是否渲染浮起投影；
  /// - [palette]：由父级按明暗模式选好的色板；
  /// - [onTap]：点击回调，实际写入 [tabIdxProvider]。
  const _MainBottomNavItem({
    required super.key,
    required this.iconKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final Key iconKey;
  final IconData icon;
  final String label;
  final bool selected;
  final _BottomNavPalette palette;
  final VoidCallback onTap;

  /// 构建单个 Tab。
  ///
  /// 选中/未选中之间的颜色与字重变化都带 160ms 过渡动画，
  /// 避免切换时的生硬跳变。
  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.selected : palette.unselected;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标颜色渐变：Icon 本身没有 Animated 版本，
        // 用 TweenAnimationBuilder 只给 color 做 160ms 补间，
        // 让选中/取消选中时颜色平滑过渡而非瞬间跳变。
        TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 160),
          tween: ColorTween(end: color),
          builder: (context, animatedColor, child) =>
              Icon(icon, key: iconKey, color: animatedColor, size: 18),
        ),
        SizedBox(height: 6.h),
        // 文字同步做 160ms 过渡：颜色 + 字重（选中 w600 / 未选中 w500）一起动，
        // 与上方图标动画时长保持一致，视觉上是一个整体。
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: TextStyle(
            color: color,
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2.h,
            letterSpacing: 0.5.sp,
          ),
          // clip 而非 ellipsis：Tab 文案很短，极端窄屏下宁可裁切也不显示省略号，
          // 省略号会让四个 Tab 的视觉重心失衡。
          child: Text(label, maxLines: 1, overflow: TextOverflow.clip),
        ),
      ],
    );

    // Pixso 设计（节点 3:262）：选中态为「圆角 12 + 主色投影（透明度 33% / y+3 / 模糊 12 / 扩散 1）+ 透明填充」的凸起浮起效果。
    final child = selected
        ? Container(
            margin: EdgeInsets.symmetric(vertical: 6.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: Colors.transparent,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.selected.withValues(alpha: 0.33),
                  blurRadius: 12,
                  offset: Offset(0.w, 3.h),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: content,
          )
        : content;

    // 无障碍处理：
    // 外层 Semantics 把整项声明为「可点击的按钮 + 选中态 + 文案」，
    // 内层再用 ExcludeSemantics 屏蔽子树（Icon/Text）自带的语义节点，
    // 避免读屏软件把同一个 Tab 重复播报两次。
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          // opaque：让整个等分区域（含空白处）都能响应点击，
          // 而不是只有图标/文字所在的像素可点，扩大触控热区。
          behavior: .opaque,
          onTap: onTap,
          // containedInkWell: false,
          // highlightShape: BoxShape.circle,
          // canRequestFocus: false,
          child: Center(child: child),
        ),
      ),
    );
  }
}
