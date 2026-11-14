// ============================================================================
// 文件：feature/home/page/main_tab_page.dart
// 模块：应用主壳（home）
//
// 职责：
//   App 的一级容器（Tab 壳层）。底部固定 MainBottomNav，body 根据当前选中的
//   Tab 下标切换到 工具 / 我的 两个页面之一。
//
// 关键依赖：
//   - widget/main_bottom_nav.dart：底部导航栏 + tabIdxProvider（下标状态源）。
//   - 两个 Tab 页面：ToolPage / ProfilePage。
//
// 状态管理说明：
//   当前 Tab 下标不由本页 State 持有，而是放在 Riverpod 的 tabIdxProvider 中，
//   这样底部导航（写入方）与本页（读取方）可以彼此独立，
//   也便于其他业务代码在任意位置以编程方式切换 Tab。
//
// 返回手势守卫（2026-09-14 新增，2026-10-02 抽出为 ClickUtil）：
//   本页是路由栈根页面，一次侧滑（系统返回手势/返回键）默认会直接退出 App。
//   为避免误触采用「连滑两次才退出」模型，判定逻辑已收敛到
//   common/util/click_util.dart 的 [ClickUtil]（阈值 600ms、纯静态、可复用）：
//   单次侧滑（与上次间隔 >= 600ms）仅停留、不提示、不退出；
//   若 600ms 内连滑两下则退出 App。
//
// 中间区域横向滑动切换 Tab（2026-09-14 新增）：
//   在 body 中间区域横向滑动可在两个 Tab 间切换，与系统边缘的返回手势互不干扰：
//   - 工具页（下标 0）向左滑 → 切到「我的」（下标 1）；
//   - 我的页（下标 1）向右滑 → 切回「工具」（下标 0）。
//   仅响应明显的横向滑动（位移阈值 + 横向位移须大于纵向），避免误触竖向滚动。
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/ads/consent_helper.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/util/click_util.dart';

import '../../profile/page/profile_page.dart';
import '../../tool/page/tool_page.dart';
import '../widget/main_bottom_nav.dart';

/// Tab 下标 → 埋点用的稳定页面名。
///
/// 顺序必须与 [MainTabPage.build] 里 body 的页面列表严格一致。
/// 用常量列表而不是 switch，是为了让「新增 Tab」只需改一处。
const List<String> _tabPageNames = <String>['tab_tool', 'tab_profile'];

/// 主 Tab 页（应用一级壳层）。
///
/// 通过监听 [tabIdxProvider] 决定 body 展示哪一个 Tab 页面，
/// 底部则常驻 [MainBottomNav]。
///
/// 因需在 body 上识别横滑切 Tab 手势（跨回调共享采样点），
/// 由 [ConsumerWidget] 改为 [ConsumerStatefulWidget] 持有少量可变状态
/// （横滑手势采样点），足够轻量。
///
/// 注：返回守卫的时间戳不在本 State 里，而在 [ClickUtil] 的静态字段中
/// ——同一时刻只可能有一个返回手势在计时，放全局更合理，详见 common/util/click_util.dart。
class MainTabPage extends ConsumerStatefulWidget {
  /// 创建主 Tab 壳层页。
  ///
  /// 不接收初始 Tab 参数：初始下标由 [TabIndexNotifier.build] 返回 0（工具箱），
  /// 需要指定初始 Tab 时应改写该 Notifier，而非从外部透传。
  const MainTabPage({super.key});

  @override
  ConsumerState<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends ConsumerState<MainTabPage> {
  // 说明：原先的「上次侧滑时间戳 _lastBackMs / 阈值 _quickBackThresholdMs」
  // 已收敛到 common/util/click_util.dart 的 ClickUtil（静态状态，全局生效，
  // 因此不需要在页面 State 里再存一份）。
  // 注意不要在 dispose 里调 ClickUtil.reset()：热重载/整量重启后时间戳自然为旧值，
  // 首次返回必定按「单次」处理（不退出），正是期望行为。

  // 以下四字段用于 body 中间的「横向滑动切换 Tab」手势识别：
  // 记录一次横滑的起点与当前采样点（localPosition），在拖拽结束时计算位移与方向。
  // 单独存放而不是临时变量，是因为 GestureDetector 的 start/update/end
  // 分三个回调，需要跨回调共享采样值。
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragLastX = 0;
  double _dragLastY = 0;

  @override
  void initState() {
    super.initState();
    // UMP 同意表单：必须等**首帧渲染完**再弹。
    //
    // 两个原因：
    // 1) 表单是原生 UI，需要一个已完全就绪的 Activity / ViewController 来 present，
    //    放在 initState 里同步调用（此时原生窗口可能还没 attach）有失败风险；
    // 2) 绝不能 await 它 —— 用户可能长时间不关闭表单，await 等于把 App 卡在启动页。
    //    这里用 addPostFrameCallback + 不等待，只是「到点了就弹一下」。
    //
    // 同意状态已在启动阶段由 initAdMob → AdsConsent.requestInfoUpdate 拉好，
    // 本方法内部会判断「本设备是否需要征求同意」，国内用户通常直接跳过。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AdsConsent.showFormIfRequired());
    });
  }

  /// 系统返回手势 / 返回键触发时的守卫逻辑。
  ///
  /// 触发条件：本页面位于路由栈顶（已无内层可 pop 的子路由），
  /// 此时一次侧滑本应直接退出 App。[PopScope] 设 `canPop: false` 接管返回，
  /// 由本方法决定放行还是拦截——采用「连滑两次才退出」模型：
  ///   - 与上次侧滑间隔 >= 600ms（即单次侧滑）→ 不退出、不提示，仅停留在当前页；
  ///   - 与上次侧滑间隔 < 600ms（即 600ms 内连滑两下）→ 调用 [SystemNavigator.pop] 交由系统关闭 App。
  ///
  /// 「是不是连滑」的判定与时间戳记账全部委托 [ClickUtil.shouldExit]，
  /// 本方法只保留「要不要真的关 App」这一个决策（原实现也是这个语义，未改行为）。
  void _onBackInvoked() {
    // shouldExit 内部先按「与上次间隔 < 600ms」判定、再刷新时间戳（顺序不能反）。
    if (ClickUtil.shouldExit()) {
      // 600ms 内连滑两下 → 视为有意退出，交给系统关闭 Activity
      // （非 Android 平台本调用为 no-op，无副作用）。
      SystemNavigator.pop();
    }
    // 单次侧滑（间隔充足）→ 不退出、不提示，仅停留在当前页。
  }

  /// body 中间区域横向滑动手势的起点采样。
  ///
  /// 记录触摸起点坐标，供 [onBodyHorizontalDragEnd] 计算总体位移。
  void onBodyHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _dragStartY = details.localPosition.dy;
    _dragLastX = details.localPosition.dx;
    _dragLastY = details.localPosition.dy;
  }

  /// body 中间区域横向滑动手势的过程采样。
  ///
  /// 持续更新当前触点，使 [onBodyHorizontalDragEnd] 拿到整段拖拽的真实位移
  /// （而非某一刻的瞬时速度，慢滑也能正确识别）。
  void onBodyHorizontalDragUpdate(DragUpdateDetails details) {
    _dragLastX = details.localPosition.dx;
    _dragLastY = details.localPosition.dy;
  }

  /// body 中间区域横向滑动手势结束时的切 Tab 判定。
  ///
  /// 该手势只作用于本页 body 中间区域，与系统从屏幕边缘触发的返回手势互不冲突；
  /// Flutter 手势竞技场会按本次拖拽的主要方向自动分流：横向为主时本识别器获胜，
  /// 纵向为主（如竖向列表滚动）时交给内部列表，本回调即便触发也会被下方过滤条件拦截。
  ///
  /// 判定规则：
  ///   - 横向位移必须 ≥ 60px，且明显大于纵向位移（确保是横向滑动而非斜向/纵向）；
  ///   - dx < 0（向左滑）且当前在工具页(0) → 切到「我的」(1)；
  ///   - dx > 0（向右滑）且当前在「我的」页(1) → 切回工具页(0)。
  void onBodyHorizontalDragEnd(DragEndDetails details) {
    final double dx = _dragLastX - _dragStartX;
    final double dy = _dragLastY - _dragStartY;
    // 横向位移过小，或本次主要为纵向滚动 → 不切换 Tab。
    if (dx.abs() < 60 || dx.abs() < dy.abs()) return;

    final int current = ref.read(tabIdxProvider);
    if (dx < 0 && current == 0) {
      // 工具页向左滑：切到「我的」。
      ref.read(tabIdxProvider.notifier).setIdx(1);
    } else if (dx > 0 && current == 1) {
      // 「我的」页向右滑：切回工具。
      ref.read(tabIdxProvider.notifier).setIdx(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当前选中的 Tab 下标，来源与底部导航完全一致，保证两者永不失步。
    final currentTab = ref.watch(tabIdxProvider);

    // Tab 切换埋点：路由观察者（TrackPageObserver）只能捕获 push / pop，
    // 而 Tab 切换是在同一个 route 内换 body，不会触发任何导航事件。
    // 因此这里必须手动补一条 page_view —— 否则「工具 / 我的」这两个
    // 最高频的浏览行为在 PV 统计里完全缺失。
    ref.listen<int>(tabIdxProvider, (int? prev, int next) {
      if (prev == null || prev == next) return;
      AppTrack.log(
        TrackEvents.pageView,
        params: <String, Object?>{
          'page': _tabPageNames[next],
          'from': _tabPageNames[prev],
          // via 区分来源：tab 切换 vs 路由跳转，两者语义不同，
          // 分析入口效果时只看 router，分析 Tab 热度时只看 tab。
          'via': 'tab',
        },
      );
    });

    return PopScope(
      // 恒为 false：由本页完全接管返回手势，是否真正退出在 _onBackInvoked 内裁定。
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) => _onBackInvoked(),
      child: Scaffold(
        bottomNavigationBar: const MainBottomNav(),
        // 页面顺序必须与 MainBottomNav 的 items 顺序严格一一对应，
        // 否则会出现「点了工具却进了我的」这类错位；新增 Tab 时两处需同步修改。
        // body 外层包一层横向拖拽识别，实现「中间区域横滑切 Tab」：
      // 工具页左滑 → 我的；我的页右滑 → 工具。
      // translucent 让整片 body（含空白）都能识别横滑，且不阻止内部竖向滚动。
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: onBodyHorizontalDragStart,
        onHorizontalDragUpdate: onBodyHorizontalDragUpdate,
        onHorizontalDragEnd: onBodyHorizontalDragEnd,
        child: const [ToolPage(), ProfilePage()][currentTab],
      ),
      ),
    );
  }
}
