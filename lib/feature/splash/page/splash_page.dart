// splash_page.dart
//
// 职责：启动屏的「第二段」——Flutter 引擎就绪后接手原生启动屏，
//      在 splash.jpg 铺满底图之上，将工具图标按 compass → level → noise
//      顺序做淡入淡出轮播（三张各停 1 秒，峰值不透明度 0.8），
//      同时在右上角展示 3 秒倒计时（可点击跳过），
//      倒计时归零或用户点击跳过时进入首页。
// 所属模块：tool_box / feature / splash（应用启动体验）。
// 关键依赖：
//  - flutter（AnimatedSwitcher / Image.asset）：交叉淡入淡出动画与底图铺满。
//  - go_router：轮播结束后以 context.go('/home') 跳转，替换当前路由栈，
//    避免用户按返回键又退回启动屏。
//  - flutter_screenutil_plus：按设计稿 393×852 做图标与胶囊尺寸自适应。
//  - AppLocalizations：倒计时「跳过 Ns」文案走中英双语。
//
// 设计说明（为什么需要这一页）：
//  原生启动屏（flutter_native_splash 生成）运行在 Flutter 引擎加载「之前」，
//  系统只支持静态图，无法播放轮播动画。因此拆成两段：
//    第一段（原生）：splash.jpg 铺满 + 中间 compass 静态图 —— 消灭冷启动白屏。
//    第二段（本页）：引擎就绪后立刻接手，视觉与第一段首帧完全一致，
//          再在其上播放四图轮播 + 倒计时，实现「无缝衔接 + 动画」的效果。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 启动屏轮播页。
///
/// 展示顺序固定为 compass → level → noise，单张停留 1000ms，
/// 三张合计 3000ms；右上角同步显示 3 → 2 → 1 的倒计时，
/// 归零后自动跳转首页，用户也可随时点击倒计时胶囊提前跳过。
class SplashPage extends StatefulWidget {
  /// 创建启动屏轮播页。
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// 轮播图标资源路径，顺序即展示顺序：指南针 → 水平仪 → 噪音。
  ///
  /// 原为四张（含 ruler），因张数偏多导致单张停留过短、淡入淡出尚未走完
  /// 就被下一张打断，观感发「赶」，故去掉直尺保留三张，让每张停满 1 秒。
  static const List<String> _icons = <String>[
    'assets/images/compass.png',
    'assets/images/level.png',
    'assets/images/noise.png',
  ];

  /// 单张图标停留时长：1000ms × 3 张 = 3000ms（即需求要求的总时长 3 秒）。
  ///
  /// 由 [_totalMs] 均分而来：三张图各占一秒，恰好与倒计时 3 → 2 → 1 一一对应，
  /// 每次跳秒正好换图，节奏比原先四张 / 750ms 更稳。
  /// 注意：本值与 [_icons] 长度、[_totalMs] 三者联动，改任意一个都要同步另外两个。
  static const int _perIconMs = 1000;

  /// 启动屏总时长（毫秒）：既是轮播总时长，也是倒计时初始值。
  static const int _totalMs = 3000;

  /// 计时推进粒度（毫秒）。
  ///
  /// 取值 50ms 是为了兼顾精度与开销：切图点（1000 的整数倍）与倒计时
  /// 秒边界（1000 的整数倍）都能被 50ms 整除，不会跨过切换点导致漏帧；
  /// 同时配合「仅在派生值变化时才 setState」，实际重建次数极少。
  static const int _tickMs = 50;

  /// 交叉淡入淡出时长。
  ///
  /// 取值需明显小于单张停留时长 [_perIconMs]，否则上一张还没淡出完下一张
  /// 就已开始淡入，会出现两张图长时间重叠的脏画面。
  static const Duration _fade = Duration(milliseconds: 350);

  /// 图标轮播的最大不透明度（淡入的终点）。
  ///
  /// 需求为「从透明到不透明的 0.8」，即峰值是 0.8 而非全不透明。
  /// 这里用外层 [Opacity] 统一控制，而不是在 transitionBuilder 里写
  /// `Tween(begin: 0, end: 0.8)`，原因见 build 中的说明——
  /// 后者会让首帧（AnimatedSwitcher 首次挂载不播动画）保持 1.0，
  /// 切到第二张时才落到 0.8，中间出现一次 0.2 的亮度突变。
  static const double _iconPeakOpacity = 0.8;

  /// 图标边长：设计稿 393×852 下的 180dp，随屏幕自适应缩放。
  ///
  /// 由 160 提到 180，配合张数精简到三张，进一步强化中间的视觉主体。
  static const double _iconSize = 180;

  /// 倒计时数字切换的淡入淡出时长，比图标轮播更短，避免数字拖影。
  static const Duration _countFade = Duration(milliseconds: 200);

  /// 当前展示的图标索引。
  int _index = 0;

  /// 剩余秒数，初始即总时长 3 秒，随时间递减到 1 后归零跳转。
  int _remainSec = _totalMs ~/ 1000;

  /// 已经过的毫秒数，由 [_timer] 累加，用于派生 [_index] 与 [_remainSec]。
  int _elapsedMs = 0;

  /// 驱动轮播与倒计时的定时器，dispose 时必须取消，避免页面销毁后回调野指针。
  Timer? _timer;

  /// 是否已触发跳转。
  ///
  /// 用于防重入：定时器自然结束与用户点击「跳过」可能同时发生，
  /// 若不拦截会导致连续两次 context.go('/home')，产生重复的路由栈条目。
  bool _finished = false;

  /// 启动屏挂载时刻，用于计算 [TrackEvents.appOpen] 的 `splash_ms`。
  ///
  /// 刻意取「启动屏可见时长」而非「进程启动到首页的耗时」：前者可直接回答
  /// 「3 秒启动屏要不要缩短」这一产品问题，后者会被 Isar / Supabase 初始化
  /// 等与本页无关的成本污染，无法据此决策。
  DateTime _mountedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mountedAt = DateTime.now();

    // 沉浸式全屏：隐藏状态栏与导航栏。
    // 原生启动屏已配置 fullscreen: true，此处必须保持一致，
    // 否则从原生段切到 Flutter 段时状态栏会突然出现，造成明显的视觉跳变。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // 单一时钟推进：以 50ms 为粒度累加已过时间，再由已过时间派生
    // 「当前图标索引」与「剩余秒数」。相比开两个定时器（750ms 轮播 + 1s 倒计时），
    // 单一时钟能保证两者严格同源，不会出现倒计时已归零但动画还没结束的错位。
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (
      Timer timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsedMs += _tickMs;

      // 派生新值：索引上限为最后一张；剩余秒数向上取整，
      // 保证 t=0 显示 3、t=1000 显示 2、t=2000 显示 1，视觉上不会出现 0 秒停留。
      final int nextIndex = (_elapsedMs ~/ _perIconMs).clamp(
        0,
        _icons.length - 1,
      );
      // 下限钳到 1：倒计时最末只显示「跳过 1s」，归零的那一帧直接跳转，
      // 避免闪现「跳过 0s」这种没有意义的文案。
      final int nextRemain = ((_totalMs - _elapsedMs) / 1000).ceil().clamp(
        1,
        _totalMs ~/ 1000,
      );

      // 仅在派生值真正变化时才 setState：避免每 50ms 全树重建。
      // 由于三张图各停 1 秒、倒计时也是 1 秒一格，切图与跳秒恰好落在同一 tick，
      // 因此整个 3 秒周期内实际只有 t=1000 与 t=2000 两次重建。
      if (nextIndex != _index || nextRemain != _remainSec) {
        setState(() {
          _index = nextIndex;
          _remainSec = nextRemain;
        });
      }

      // 到达总时长：停止计时并进入首页（_goHome 内部已做防重入）。
      if (_elapsedMs >= _totalMs) {
        timer.cancel();
        _timer = null;
        _goHome();
      }
    });
  }

  /// 跳转首页。
  ///
  /// 使用 [GoRouter.go]（而非 push）替换当前路由栈，
  /// 确保启动屏不会残留在栈中——否则用户按返回键会退回启动屏。
  /// 通过 [_finished] 保证只执行一次，兼容「倒计时自然结束」与「用户点击跳过」。
  ///
  /// - [skipped]：是否由用户点击「跳过」触发。
  ///   该标记随 `app_open.skipped` 上报，用于计算「跳过率」——
  ///   这是判断 3 秒启动屏是否拖累体验的另一半证据
  ///   （`splash_ms` 看停留时长分布，`skipped` 看等不及的人占比）。
  void _goHome({bool skipped = false}) {
    if (!mounted || _finished) return;
    _finished = true;
    _timer?.cancel();
    _timer = null;

    // 冷启动埋点：DAU 与启动次数的分母，同时带出启动屏实际停留时长。
    // 用 logNow 而非 log —— 这是每次会话的第一条事件，必须尽快落库，
    // 若留在队列里等阈值/定时器，用户「打开即退出」的场景会漏掉当天活跃。
    // 一条/会话的频率也完全不会造成性能问题。
    // 注意：热启动不经过本页，由 AppLifecycleTracker 补 launch_type='warm'。
    unawaited(
      AppTrack.logNow(
        TrackEvents.appOpen,
        params: <String, Object?>{
          'launch_type': 'cold',
          'splash_ms': DateTime.now().difference(_mountedAt).inMilliseconds,
          'skipped': skipped,
        },
      ),
    );

    context.go('/home');
  }

  @override
  void dispose() {
    // 先取消定时器，防止页面已销毁仍触发 setState。
    _timer?.cancel();
    _timer = null;
    // 恢复系统 UI（状态栏 / 导航栏），否则后续页面会一直处于全屏无状态栏状态。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景色兜底：与 splash.jpg 主色 #6FC6FC 一致，
      // 在图片解码完成前的极短空窗期内避免闪白屏。
      backgroundColor: const Color(0xFF6FC6FC),
      body: Stack(
        // StackFit.expand：让子层撑满全屏，底图才能真正铺满而非居中留白。
        fit: StackFit.expand,
        children: <Widget>[
          // 底层：启动屏底图，cover 模式保证任意屏幕比例下都铺满且不变形。
          Image.asset(
            'assets/images/splash.jpg',
            fit: BoxFit.cover,
            // 原生启动屏已加载过同一张图，此处命中缓存，不会重复解码。
            gaplessPlayback: true,
          ),
          // 上层：居中轮播的工具图标，透明 → 0.8 不透明 交叉淡入淡出。
          Center(
            child: AnimatedSwitcher(
              duration: _fade,
              // 默认即为淡入淡出（FadeTransition），无需显式指定 transitionBuilder：
              // 淡入 0 → 1、淡出 1 → 0，再乘以外层 Opacity 的 0.8，
              // 等效于 0 → 0.8 的淡入与 0.8 → 0 的淡出。
              child: Opacity(
                // 统一峰值：首帧（无切换动画）与后续切换帧都命中 0.8，
                // 避免「第一张全不透明、之后突然变淡」的跳变。
                opacity: _iconPeakOpacity,
                // 必须绑定随内容变化的 key：AnimatedSwitcher 靠 key 变化
                // 判定「子组件已更换」，从而触发淡出旧图 / 淡入新图。
                key: ValueKey<String>(_icons[_index]),
                child: Image.asset(
                  _icons[_index],
                  width: _iconSize.w,
                  height: _iconSize.w,
                ),
              ),
            ),
          ),
          // 上层：右上角倒计时胶囊，点击可立即跳过启动屏。
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              // 沉浸式模式下系统栏 padding 可能为 0，
              // 这里用 minimum 兜一个最小边距，确保胶囊不会贴着刘海或圆角。
              minimum: EdgeInsets.only(top: 12.h, right: 16.w),
              child: _CountdownCapsule(
                seconds: _remainSec,
                fade: _countFade,
                // 用户主动点击「跳过」：skipped=true 随 app_open 上报（见 _goHome）。
                onTap: () => _goHome(skipped: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 倒计时胶囊按钮。
///
/// 半透明白底圆角胶囊，居中显示「跳过 Ns」，数字变化时做短促淡入淡出；
/// 整块区域可点击，点击后立即结束启动屏进入首页。
class _CountdownCapsule extends StatelessWidget {
  /// 创建倒计时胶囊。
  ///
  /// [seconds]：剩余秒数；[fade]：数字切换动画时长；[onTap]：点击跳过回调。
  const _CountdownCapsule({
    required this.seconds,
    required this.fade,
    required this.onTap,
  });

  /// 剩余秒数。
  final int seconds;

  /// 数字切换的淡入淡出时长。
  final Duration fade;

  /// 点击跳过回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 启动屏位于 MaterialApp 之下，本地化一定可用，故这里用 ! 解包。
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Material(
      // 透明底：只让 Ink 的装饰提供视觉，避免 Material 自身背景色叠色。
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // 水波纹跟随胶囊圆角，否则会溢出成矩形。
        borderRadius: BorderRadius.circular(999.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            // 半透明白底：底图是浅蓝渐变，白底能保证文字在任意渐变位置都清晰。
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: AnimatedSwitcher(
            duration: fade,
            // 默认即为淡入淡出（FadeTransition），无需显式指定 transitionBuilder；
            // 这里保持默认，让数字安静地交替，避免干扰中间的图标轮播。
            child: Text(
              l10n.splashSkip(seconds),
              // key 绑定剩余秒数：秒数变化时触发淡入淡出。
              key: ValueKey<int>(seconds),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                // 深灰蓝文字，与浅蓝底图形成足够对比度。
                color: const Color(0xFF2C3E50),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
