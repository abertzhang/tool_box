// ruler_page.dart
//
// 直尺（Ruler）工具页。
// 所属模块：feature/tool（工具箱）· 直尺子工具。
// 设计稿：Pixso 浅色 186:121 / 深色 202:469（横向木质刻度尺 + 单位切换 +
//          测量长度显示 + 手电筒照明开关）。
//
// 关键依赖：
//   - services（SystemChrome：强制横屏 + 沉浸式全屏，离开页面恢复）；
//   - routeObserver（全局路由观察者，感知本页被 push 覆盖/重新可见/被 pop）；
//   - flashlightProvider（手电筒子工具：真实闪光灯，封装相机后置闪光灯常亮）。
//
// 功能实现：
//   1) 实时直尺：CustomPaint 绘制木质刻度（1cm 主刻度在顶部 + 数字标签，
//      5mm 中刻度与 1mm 次刻度在底部），刻度按真实物理像素密度映射，1:1 还原长度。
//   2) 可拖拽测量：两个手柄（起点/终点）在尺上拖动，实时计算并高亮测量段。
//   3) 单位切换：厘米 / 英寸，读数徽标同时展示两种单位（激活单位高亮），
//      并联动尺面刻度——选英寸时刻度切成英寸制（1in 主刻 + 1/2、1/4、1/8in 次刻），
//      选厘米时刻度切成厘米制（1cm 主刻 + 5mm、1mm 次刻）。
//   4) 手电筒照明：调用 [flashlightProvider] 真正点亮相机后置闪光灯（torch 常亮），
//      屏幕背景同时提亮为暖白，便于在暗处看清被测物边缘与尺面刻度。
//   5) 沉浸式全屏：进入本页强制横屏并隐藏系统 UI（尺面贴近屏幕边缘），
//      离开本页（pop 或 push 覆盖）自动恢复正常屏幕 + 竖屏。
//
// ⚠️ 尺寸单位约定（2026-09-14 定）：
//   本页**强制横屏**，一律使用「逻辑像素常量」，不使用 ScreenUtil 的 .w/.h/.sp/.r。
//   原因：ScreenUtil 以设计稿 393×852 为基准，`.w = 屏幕宽 / 393`；横屏时屏幕宽
//   变为 852，`.w` 被放大约 2.17 倍 —— 直尺高度 88.w 会变成 191px、内边距 16.w
//   变成 35px，整页被撑大，尺面反而无法全屏铺开。竖屏下 `.w == 1`，故改用逻辑
//   像素后竖屏视觉与原来完全一致，横屏则保持设计稿原始尺寸。
//
// 代码复用说明：
//   本页与水平仪页（level_page）共享 lib/feature/tool/shared/tool_panel_palette.dart
//   中的 [ToolPanelPalette]（卡片/按钮/文字色板）。

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome（全屏/朝向）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/feature/tool/provider/flashlight_provider.dart';
import 'package:tool_box/feature/tool/shared/tool_panel_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';
import 'package:tool_box/router/app_router.dart'; // 全局 routeObserver

/// 逻辑像素 → 厘米 的换算系数。
///
/// Flutter 的逻辑像素以「密度无关」定义：160 逻辑像素 ≈ 1 参考英寸，
/// 而参考英寸已按设备真实物理密度校准，故 1 逻辑像素 = 1/160 英寸在已校准的
/// 手机上即等于真实物理长度。因此 cm = 逻辑像素 / (160 / 2.54)。
/// 该系数与 devicePixelRatio 无关（物理密度已在系统中抵消），任意手机通用。
const double _logicalPxPerCm = 160 / 2.54;

/// 直尺本体高度（逻辑像素）。
const double _rulerHeight = 88;

/// 手柄直径（逻辑像素）。
const double _handleSize = 28;

/// 直尺页。
///
/// 进入本页强制横屏 + 沉浸式全屏（尺面贴近屏幕边缘），离开本页
/// （pop 或 push 覆盖）恢复正常屏幕 + 竖屏。
class RulerPage extends ConsumerStatefulWidget {
  const RulerPage({super.key});

  @override
  ConsumerState<RulerPage> createState() => _RulerPageState();
}

class _RulerPageState extends ConsumerState<RulerPage> with RouteAware {
  /// 本页强制横屏的朝向列表（左/右均可）。
  static const List<DeviceOrientation> _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// 离开本页后恢复的竖屏朝向（与 main.dart 启动时的全局竖屏保持一致：上/下）。
  static const List<DeviceOrientation> _portrait = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  /// 进入本页：强制横屏 + 沉浸式全屏。
  ///
  /// 沉浸式全屏（[SystemUiMode.immersiveSticky]）隐藏系统状态栏与导航条，
  /// 让尺面真正贴近屏幕底部/边缘，便于 1:1 贴合被测物测量。
  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(_landscape);
    // 全屏进入埋点：本页「进入即全屏」无开关可点，故只在进入时计一次。
    // 用它除以 tool_entry_open{tool:'ruler'} 即全屏使用占比，
    // 高则说明横屏测量是主场景，值得投入横屏适配与边缘防误触。
    AppTrack.log(
      TrackEvents.rulerFullscreen,
      params: <String, Object?>{'enter': true},
    );
  }

  /// 离开本页：恢复正常屏幕（显示系统 UI）+ 恢复竖屏。
  ///
  /// [SystemUiMode.edgeToEdge] 为 Flutter 默认模式，恢复后续页面
  /// 正常的状态栏/导航条显示。
  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(_portrait);
    AppTrack.log(
      TrackEvents.rulerFullscreen,
      params: <String, Object?>{'enter': false},
    );
  }

  /// 起点手柄在尺上的水平位置（逻辑像素，相对尺左边缘）。
  double _startDx = 0;

  /// 终点手柄在尺上的水平位置（逻辑像素）。
  double _endDx = 0;

  /// 尺面可用宽度（逻辑像素），由 LayoutBuilder 首次测得后填充。
  double _rulerWidth = 0;

  /// 当前主单位：'cm' 或 'in'。
  ///
  /// 既控制读数徽标高亮，也决定直尺刻度按厘米制 / 英寸制绘制。
  String _unit = 'cm';

  /// 切换主单位。
  ///
  /// - [unit]：'cm' 或 'in'。
  ///
  /// 抽成方法而非在 onTap 里直接 setState：单位切换要带埋点，
  /// 写成方法才能顺带做「没真正切换就跳过」的判断，避免点当前已选单位也计一次。
  void _switchUnit(String unit) {
    if (_unit == unit) return;
    setState(() => _unit = unit);
    // 单位偏好分布：决定是否按系统地区自动选默认单位，
    // 让大部分用户少一次手动切换。
    AppTrack.log(
      TrackEvents.rulerUnitSwitch,
      params: <String, Object?>{'unit': unit},
    );
  }

  @override
  void initState() {
    super.initState();
    // 本页横向读数 + 沉浸式全屏：进入即强制横屏并隐藏系统 UI。
    _enterFullScreen();
    // 初始给一个默认测量段，进入页面即显示有效读数。
    // 起点默认落在刻度 0（尺左边缘的零点），即从零点开始量；终点给一个默认长度。
    _startDx = 0;
    _endDx = 220;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅全局路由观察者，感知本页被 push 覆盖 / 重新可见 / 被 pop。
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  /// 本页之上被 push 了其它页面（本页不可见）→ 关闭手电筒 + 恢复正常屏幕 + 竖屏。
  @override
  void didPushNext() {
    // 离开本页时关闭闪光灯，避免被其它页面盖住后闪光灯仍常亮。
    unawaited(ref.read(flashlightProvider.notifier).turnOff());
    _exitFullScreen();
  }

  /// 覆盖本页的页面被 pop，本页重新可见 → 再次进入全屏横屏。
  @override
  void didPopNext() {
    _enterFullScreen();
  }

  /// 本页被 pop 移除 → 立即恢复正常屏幕 + 竖屏。
  ///
  /// 关键修复（2026-09-20）：此前仅在 [dispose] 中恢复竖屏，而 [dispose] 在 pop
  /// 动画结束后才触发，部分机型/系统下返回后会残留横屏。改为在路由被 pop 的这一刻
  /// （[didPop]，早于 [dispose]）即恢复竖屏，配合返回按钮 onPressed 的主动恢复，
  /// 确保回到上一页一定是竖屏。
  @override
  void didPop() {
    _exitFullScreen();
  }

  @override
  void dispose() {
    // 本页被 pop 移除（不再显示）→ 关闭手电筒 + 恢复正常屏幕 + 竖屏，避免影响后续页面。
    unawaited(ref.read(flashlightProvider.notifier).turnOff());
    routeObserver.unsubscribe(this);
    _exitFullScreen();
    super.dispose();
  }

  /// 测量长度（逻辑像素）→ 毫米。
  double get _lengthMm {
    final double px = (_endDx - _startDx).abs();
    return px / _logicalPxPerCm * 10; // 像素 → cm → mm
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ToolPanelPalette p = ToolPanelPalette.of(context);

    // 当前长度（两种单位）。
    final double cm = _lengthMm / 10;
    final double inch = _lengthMm / 25.4;

    // 手电筒状态：来自 [flashlightProvider]（真实闪光灯常亮 = true）。
    // UI 据此切换图标与背景提亮，不再使用任何本地布尔 + 覆盖层。
    final bool flashOn = ref.watch(flashlightProvider);

    // 页面为固定布局：顶部保留「标题行 + 长度行 + 单位切换行」三行操作条——
    // 标题行（返回 + 标题）；长度行（当前测量长度双单位换算，手电筒开关置右侧）；
    // 单位切换行（厘米 / 英寸，置于长度行下方），其余空间全部留给直尺，
    // 并用 Spacer 把直尺推到屏幕底部边缘。
    //
    // ★ 不使用 AppBar：AppBar 会固定占用顶部一条 56px 高度（外加状态栏），
    //   在横屏本就只有 393px 高的情况下吃掉近 1/5 高度，尺面无法全屏铺开。
    //   返回入口改为操作条最左侧的图标按钮（见 _buildNavRow）。
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作条：仅顶部/左右保留 SafeArea（防刘海与圆角遮挡），
        // 底部安全区域去掉，让直尺尽量贴底。
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行（标题行）：返回 + 标题。
                _buildNavRow(l10n, p),
                const SizedBox(height: 6),
                // 第二行（长度行）：当前测量长度的双单位换算结果，
                // 随拖拽手柄实时更新（cm 1 位小数 / inch 2 位小数）；
                // 手电筒开关放在本行右侧（自标题行移来）。
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '${l10n.rulerLengthLabel} : '
                          '${cm.toStringAsFixed(1)} cm / '
                          '${inch.toStringAsFixed(2)} inch',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.accent,
                          ),
                          // 长文本（英文单位）避免与右侧按钮争抢空间。
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    _buildFlashlightBtn(l10n, p, flashOn),
                  ],
                ),
                const SizedBox(height: 6),
                // 第三行（单位切换行）：厘米 / 英寸切换，放在「长度行」下方。
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _buildUnitRow(l10n, p),
                ),
              ],
            ),
          ),
        ),
        // 弹性空间：把直尺推到屏幕底部边缘。
        const Spacer(),
        // 直尺本体（可拖拽测量）：整体贴近屏幕底部，便于贴合被测物边缘测量。
        // 沉浸式全屏下主动忽略 left/right 安全区，让尺面铺满横屏全宽；再在左右各
        // 手动内收 20 逻辑像素（见下方 Padding），避免刻度贴到屏幕最左/最右边缘。
        // 顶部操作条仍保留 left/right 安全区，保护返回按钮与手电筒不被遮挡。
        SafeArea(
          top: false,
          bottom: false,
          left: false,
          right: false,
          // 左右各手动内收 20 逻辑像素，避免刻度贴到屏幕最左/最右边缘。
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: LayoutBuilder(
            builder: (ctx, constraints) {
              // 首次测得尺宽后，确保默认起止点落在范围内。
              final double w = constraints.maxWidth;
              if (_rulerWidth == 0 && w > 0) {
                _rulerWidth = w;
                // 起点默认落在刻度 0（尺左边缘的零点），不再按屏宽的 15% 偏移，
                // 这样进入页面时读数就是「从零点量到终点」的直观长度。
                _startDx = 0;
                _endDx = (w * 0.55).clamp(0, w);
              }
              return _RulerView(
                width: w,
                // 传入前 clamp：横竖屏切换使尺宽变窄时，旧手柄位置可能落到尺外。
                startDx: _startDx.clamp(0.0, w),
                endDx: _endDx.clamp(0.0, w),
                palette: p,
                // 单位开关联动刻度：选英寸时刻度切成英寸制，选厘米时切回厘米制。
                isInch: _unit == 'in',
                onStartDrag: (dx) => setState(() => _startDx = dx.clamp(0, w)),
                onEndDrag: (dx) => setState(() => _endDx = dx.clamp(0, w)),
              );
            },
          ),
          ),
        ),
      ],
    );

    // 手电筒开启时：真实闪光灯已由 [flashlightProvider] 点亮（相机后置闪光灯 torch 常亮），
    // 这里仅把**页面背景**提亮为暖白，便于暗处看清尺面——不再叠加任何遮挡层，
    // 以免把尺子与操作条整个盖白（旧实现「点击后页面变空白」即源于 Positioned.fill 覆盖层）。
    return Scaffold(
      backgroundColor: flashOn ? const Color(0xFFFBF7E8) : p.pageBg,
      body: body,
    );
  }

  /// 顶部标题行：返回 + 标题。
  ///
  /// 手电筒开关已移至第二行（长度行）右侧（见 [_buildFlashlightBtn]）。
  Widget _buildNavRow(AppLocalizations l10n, ToolPanelPalette p) {
    return Row(
      children: [
        // 返回入口（取代 AppBar 自带的 leading）。
        IconButton(
          icon: Icon(Icons.arrow_back, color: p.titleText),
          // 返回前主动恢复竖屏 + 系统 UI：确保 pop 动画一开始即为竖屏，
          // 不依赖 [dispose] 时序（部分机型会残留横屏一帧）。[dispose] 仍兜底。
          onPressed: () {
            _exitFullScreen();
            Navigator.of(context).maybePop();
          },
        ),
        Text(
          l10n.rulerTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: p.titleText,
          ),
        ),
      ],
    );
  }

  /// 手电筒开关按钮：真正调用 [flashlightProvider] 点亮相机闪光灯（torch 常亮）。
  ///
  /// 原位于标题行右侧，现移至第二行（长度行）右侧；行为不变。
  Widget _buildFlashlightBtn(
    AppLocalizations l10n,
    ToolPanelPalette p,
    bool flashOn,
  ) {
    return IconButton(
      onPressed: () async {
        try {
          // 真实开关闪光灯：首次开启会初始化后置相机并触发系统的相机权限弹窗
          // （Android CAMERA / iOS NSCameraUsageDescription，工程已具备）。
          // 权限被拒或设备不支持时 provider 抛 CameraException，这里捕获并提示，
          // 不要静默吞掉——否则用户会以为「点了没反应」。
          await ref.read(flashlightProvider.notifier).toggle();
        } on CameraException {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.flashlightPermissionDenied)));
        }
        // 手电筒埋点：本页的开关带 source='ruler'，与工具页的同名事件区分开，
        // 用于判断「测量时补光」是否是一个独立的高频场景。
        AppTrack.log(
          TrackEvents.toolFlashlightToggle,
          params: <String, Object?>{
            'on': ref.read(flashlightProvider),
            'source': 'ruler',
          },
        );
      },
      icon: Icon(
        flashOn ? Icons.flashlight_on : Icons.flashlight_off,
        color: flashOn ? const Color(0xFFF0C850) : p.muted,
      ),
    );
  }

  /// 单位切换行：厘米 / 英寸切换，放在「长度行」下方。
  ///
  /// 仅内容宽度（[MainAxisSize.min]），左对齐贴在长度行下方，不占满整行。
  /// 切换逻辑复用 [_switchUnit]（带埋点 + 未真正切换则跳过）。
  Widget _buildUnitRow(AppLocalizations l10n, ToolPanelPalette p) {
    final bool cmActive = _unit == 'cm';
    return Container(
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UnitOption(
            text: l10n.rulerUnitInch,
            active: !cmActive,
            palette: p,
            onTap: () => _switchUnit('in'),
          ),
          const SizedBox(width: 4),
          _UnitOption(
            text: l10n.rulerUnitCm,
            active: cmActive,
            palette: p,
            onTap: () => _switchUnit('cm'),
          ),
        ],
      ),
    );
  }
}

/// 单位切换单选项（厘米 / 英寸）。
class _UnitOption extends StatelessWidget {
  const _UnitOption({
    required this.text,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  final String text;
  final bool active;
  final ToolPanelPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? palette.recordBtnText : palette.labelText,
          ),
        ),
      ),
    );
  }
}

/// 横向直尺视图（刻度绘制 + 可拖拽起止手柄）。
///
/// ⚠️ 必须是 [StatefulWidget]（2026-09-14 修复）：
/// 拖拽期间父级会因 setState 反复重建本组件，此前「当前活动手柄」是 build()
/// 里的局部变量，每次重建都会重置为 0，导致终点手柄永远选不中、只有起点会动。
/// 改由 State 持有该状态后，选中关系才能跨重建保持。
class _RulerView extends StatefulWidget {
  const _RulerView({
    required this.width,
    required this.startDx,
    required this.endDx,
    required this.palette,
    required this.isInch,
    required this.onStartDrag,
    required this.onEndDrag,
  });

  /// 尺面可用宽度（逻辑像素）。
  final double width;

  /// 起点手柄水平位置（逻辑像素）。
  final double startDx;

  /// 终点手柄水平位置（逻辑像素）。
  final double endDx;

  /// 面板色板（深浅主题）。
  final ToolPanelPalette palette;

  /// 是否按英寸制绘制刻度（true=英寸，false=厘米），由页面单位开关决定。
  final bool isInch;

  /// 起点拖动回调（传入新的逻辑像素 x，已在父级 clamp）。
  final ValueChanged<double> onStartDrag;

  /// 终点拖动回调。
  final ValueChanged<double> onEndDrag;

  @override
  State<_RulerView> createState() => _RulerViewState();
}

class _RulerViewState extends State<_RulerView> {
  /// 当前被拖动的手柄（0=起点，1=终点），跨重建保持（见类注释）。
  int _active = 0;

  /// 按下点与被选中手柄中心的水平偏移。
  ///
  /// 拖动时按「手指位移」增量移动手柄，而不是把手柄直接吸到手指位置，
  /// 避免按在手柄边缘时手柄瞬间跳一下。
  double _grabOffset = 0;

  /// 手柄命中判定的额外容差（逻辑像素），叠加在手柄视觉半径之上，
  /// 让手指不必像素级精确落在 28px 的手柄圆点上也能选中它。
  static const double _handleHitSlop = 14;

  @override
  Widget build(BuildContext context) {
    // 通过 Directionality 获取当前文本方向（绕开分析 SDK 对 TextDirection.ltr
    // 静态常量的解析差异，运行表现一致）。
    final TextDirection dir = Directionality.of(context);
    // 显示前统一 clamp：横竖屏切换导致尺宽变窄时，旧的手柄位置可能越界。
    final double startDx = widget.startDx.clamp(0.0, widget.width);
    final double endDx = widget.endDx.clamp(0.0, widget.width);

    return SizedBox(
      width: widget.width,
      height: _rulerHeight,
      child: Stack(
        // 允许子件溢出边界：起点手柄默认落在刻度 0 时，其圆心也在 0，
        // 左半边会伸到尺外。默认 hardEdge 会把这半个手柄裁掉，
        // 改为 none 后它可绘制到左右各 20px 的内边距里（半宽 14 < 20），完整可见。
        clipBehavior: Clip.none,
        children: [
          // 刻度尺本体。
          CustomPaint(
            size: Size(widget.width, _rulerHeight),
            painter: _RulerPainter(
              startDx: startDx,
              endDx: endDx,
              pixelsPerCm: _logicalPxPerCm,
              palette: widget.palette,
              isInch: widget.isInch,
              textDirection: dir,
            ),
          ),
          // 起点手柄（视觉）。
          _Handle(dx: startDx, palette: widget.palette),
          // 终点手柄（视觉）。
          _Handle(dx: endDx, palette: widget.palette),
          // 全层手势：必须放在 Stack 的**最后一层（最上层）**。
          //
          // Stack 的命中测试从最后一个 child 开始、命中即停止；此前手势层排在
          // 手柄之下，手指按在手柄上时命中被手柄（带 decoration 的 Container）
          // 吞掉，手势层收不到任何事件 —— 表现就是「拖动滑块毫无反应」。
          // 同时显式指定 opaque：无 child 的 GestureDetector 默认 translucent，
          // 命中测试返回 false，无法保证独占事件。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _onDragStart(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => _onDragUpdate(d.localPosition.dx),
            ),
          ),
        ],
      ),
    );
  }

  /// 按下：选中手柄并记录抓取偏移。
  ///
  /// 选中优先级：先判断是否落在某个手柄的命中范围内（容差 [_handleHitSlop]），
  /// 是则精确选中它；都不在范围内时退化为「取距离更近的那个」，
  /// 这样在尺面任意位置起手拖动都能自然地带动最近的手柄。
  void _onDragStart(double x) {
    final double s = widget.startDx.clamp(0.0, widget.width);
    final double e = widget.endDx.clamp(0.0, widget.width);
    // 命中范围与手柄视觉尺寸保持一致，保证「看到的圆点」=「能按中的区域」。
    final double hit = _handleSize / 2 + _handleHitSlop;
    final double ds = (x - s).abs();
    final double de = (x - e).abs();

    if (ds <= hit && ds <= de) {
      _active = 0;
    } else if (de <= hit) {
      _active = 1;
    } else {
      _active = ds <= de ? 0 : 1;
    }
    // 记录偏移，后续按增量移动，避免按下瞬间手柄跳到手指下。
    _grabOffset = (_active == 0 ? s : e) - x;
  }

  /// 拖动中：按增量把活动手柄移动到新位置。
  void _onDragUpdate(double x) {
    _move(_active, x + _grabOffset);
  }

  /// 将活动手柄移动到 x（clamp 到尺宽后回调父级）。
  void _move(int activeHandle, double x) {
    final double clamped = x.clamp(0.0, widget.width);
    if (activeHandle == 0) {
      widget.onStartDrag(clamped);
    } else {
      widget.onEndDrag(clamped);
    }
  }
}

/// 直尺手柄（圆形标记，叠加在尺上指示起止点）。
class _Handle extends StatelessWidget {
  const _Handle({required this.dx, required this.palette});

  /// 手柄中心水平位置（逻辑像素）。
  final double dx;

  final ToolPanelPalette palette;

  @override
  Widget build(BuildContext context) {
    const double size = _handleSize;
    return Positioned(
      left: dx - size / 2,
      top: (_rulerHeight - size) / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.accent,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(width: 3, height: 14, color: Colors.white),
        ),
      ),
    );
  }
}

/// 横向直尺绘制。
///
/// 绘制：木质底色条 + 测量段高亮 + 刻度与数字标签。
/// 刻度随当前单位切换：厘米制（1cm 主刻度 + 5mm / 1mm 次刻度）或
/// 英寸制（1in 主刻度 + 1/2、1/4、1/8in 次刻度）。
/// 刻度按真实物理像素密度（_logicalPxPerCm）映射，确保 1:1 长度。
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.startDx,
    required this.endDx,
    required this.pixelsPerCm,
    required this.palette,
    required this.isInch,
    required this.textDirection,
  });

  final double startDx;
  final double endDx;
  final double pixelsPerCm;
  final ToolPanelPalette palette;

  /// 是否按英寸制绘制刻度（true=英寸，false=厘米）。
  final bool isInch;

  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double top = h * 0.18; // 刻度起始 y（给数字留空间）
    final double bottom = h; // 刻度延伸到尺底

    // 尺面底色（浅木色卡片）。
    final Paint barBg = Paint()..color = palette.cardBg;
    final Paint barBorder = Paint()
      ..color = palette.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final RRect bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(10),
    );
    canvas.drawRRect(bar, barBg);
    canvas.drawRRect(bar, barBorder);

    // 测量段高亮（起点→终点之间半透明强调色）。
    final double a = math.min(startDx, endDx);
    final double b = math.max(startDx, endDx);
    final Paint hl = Paint()..color = palette.accent.withValues(alpha: 0.18);
    canvas.drawRect(Rect.fromLTRB(a, top, b, bottom - top), hl);

    // 刻度与数字：按当前单位选择厘米制 / 英寸制绘制逻辑。
    final Paint tick = Paint()
      ..color = palette.accent
      ..strokeWidth = 1;
    final TextPainter tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: textDirection,
    );
    if (isInch) {
      _paintInchTicks(canvas, w, top, bottom, tick, tp);
    } else {
      _paintCmTicks(canvas, w, top, bottom, tick, tp);
    }
  }

  /// 在刻度线顶部绘制居中的数字标签。
  void _paintLabel(Canvas canvas, TextPainter tp, double x, String text) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: palette.accent,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, 2));
  }

  /// 厘米制刻度：1cm 主刻度（顶部满高线 + 数字）+ 5mm 中刻度 + 1mm 次刻度（底部）。
  ///
  /// 主刻度在顶部：满高线 + 数字标注；中/次刻度在底部（直尺另一边），自底边向上延伸。
  void _paintCmTicks(Canvas canvas, double w, double top, double bottom,
      Paint tick, TextPainter tp) {
    double cm = 0;
    while (true) {
      final double x = cm * pixelsPerCm;
      if (x > w) break;
      final int mm = (cm * 10).round();
      if (mm % 10 == 0) {
        // 主刻度（1cm）：顶部满高线。
        canvas.drawLine(Offset(x, top), Offset(x, bottom), tick);
        if (cm > 0) {
          _paintLabel(canvas, tp, x, cm.round().toString());
        }
      } else if (mm % 5 == 0) {
        // 中刻度（5mm）：从底部向上延伸 0.7 高度。
        canvas.drawLine(
          Offset(x, bottom),
          Offset(x, bottom - (bottom - top) * 0.7),
          tick,
        );
      } else {
        // 次刻度（1mm）：从底部向上延伸 0.4 高度。
        canvas.drawLine(
          Offset(x, bottom),
          Offset(x, bottom - (bottom - top) * 0.4),
          tick,
        );
      }
      cm += 0.1; // 步进 1mm
    }
  }

  /// 英寸制刻度：1in 主刻度（顶部满高线 + 数字）+ 1/2、1/4、1/8in 次刻度（底部）。
  void _paintInchTicks(Canvas canvas, double w, double top, double bottom,
      Paint tick, TextPainter tp) {
    // 1 英寸 = 2.54 厘米；以 1/8 英寸为最小步进，对应真实直尺的刻度层级。
    final double pxPerInch = pixelsPerCm * 2.54;
    const int perInch = 8; // 每英寸 8 格（即 1/8 英寸）
    final double step = pxPerInch / perInch;
    for (int i = 0;; i++) {
      final double x = i * step;
      if (x > w) break;
      if (i % perInch == 0) {
        // 1 英寸主刻度：顶部满高线 + 数字。
        canvas.drawLine(Offset(x, top), Offset(x, bottom), tick);
        final int inch = i ~/ perInch;
        if (inch > 0) {
          _paintLabel(canvas, tp, x, inch.toString());
        }
      } else if (i % (perInch ~/ 2) == 0) {
        // 1/2 英寸：从底部向上延伸 0.7 高度。
        canvas.drawLine(
          Offset(x, bottom),
          Offset(x, bottom - (bottom - top) * 0.7),
          tick,
        );
      } else if (i % (perInch ~/ 4) == 0) {
        // 1/4 英寸：从底部向上延伸 0.5 高度。
        canvas.drawLine(
          Offset(x, bottom),
          Offset(x, bottom - (bottom - top) * 0.5),
          tick,
        );
      } else {
        // 1/8 英寸：从底部向上延伸 0.32 高度。
        canvas.drawLine(
          Offset(x, bottom),
          Offset(x, bottom - (bottom - top) * 0.32),
          tick,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.startDx != startDx ||
      old.endDx != endDx ||
      old.pixelsPerCm != pixelsPerCm ||
      old.palette != palette ||
      old.isInch != isInch ||
      old.textDirection != textDirection;
}
