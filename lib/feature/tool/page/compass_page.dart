// ============================================================================
// 文件：feature/tool/page/compass_page.dart
// 模块：工具箱（tool）· 指南针子工具
//
// 职责：
//   1) 指南针本体：接入设备磁力计/加速度计（flutter_compass），实时计算方位角
//      并驱动罗盘指针旋转；无传感器时优雅降级为占位态，绝不红屏。
//   2) 读数与记录面板（Pixso 2:3 浅色稿）：在指南针下方展示实时读数卡
//      （方位角/海拔/纬度/经度，经纬度来自 geolocator），提供「记录当前位置」
//      与「导出」操作，并以本地 Isar「指南针表」(CompassRecord) 持久化历史记录，
//      支持查看、删除与导出。
//
// 设计对齐：
//   - 配色严格复用工程暖棕大地色系，通过 [CompassPalette] / [_PanelPalette]
//     双主题色板集中管理，与 tool_page.dart 的 [_ToolPalette] 写法一致。
//   - 所有尺寸使用 flutter_screenutil_plus 的 .w/.h/.sp/.r（设计稿 393×852）。
//   - 卡片零 elevation、圆角 16r、1px 描边，与工具页/FAQ 页统一。
//   - 结构：Scaffold(AppBar) + SafeArea + SingleChildScrollView + Column。
//
// 关键依赖：
//   - flutter_compass：提供 [CompassEvent]{ heading, accuracy } 流。
//   - geolocator：提供纬度/经度/海拔实时读数（按需申请定位权限，无权限时降级）。
//   - flutter_riverpod：页面为 ConsumerStatefulWidget（动画需 Stateful），
//     并通过 compassRecordsProvider 订阅「指南针表」。
//   - dart:math：指针旋转的最短路环绕修正。
//   - isar_community + IsarService：历史记录的写入与读取。
//
// 结构一览：
//   CompassPage(Stateful) ─ 订阅传感器流 + 动画 + GPS
//        ├ CompassWidget(Stateless) ─ _CompassDialPainter / _TopMarkerPainter
//        └ 读数卡 / 操作按钮 / 历史记录（均来自 Pixso 2:3）
//   CompassPalette / _PanelPalette：双主题色板
//   compassRecordsProvider：指南针表的声明式读取
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Ticker 单独import：它住在 scheduler 库，不在 material / widgets 的导出链上。
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:tool_box/common/ads/banner_ad_view.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/common/provider/app_settings/save_name_prompt_provider.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/feature/profile/provider/membership_provider.dart';
import 'package:tool_box/feature/tool/data/model/compass_record.dart';
import 'package:tool_box/feature/tool/provider/compass_records_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 指南针工具页。
///
/// 设计稿：复用工程暖棕大地色系（浅 #F5F3EF / 深 #1C1C1E）。
/// 布局自上而下：AppBar 标题 → 居中的旋转罗盘 → 度数读数 → 方位标签 →
/// （Pixso 2:3 面板）实时读数卡 → 记录/导出按钮 → 历史记录列表。
/// 无传感器时整页切换为友好占位态，但读数/记录面板仍可用（仅方位角显示「—」）。
class CompassPage extends ConsumerStatefulWidget {
  /// 创建指南针页。无参数：配色由色板现场解析，传感器流在 [initState] 订阅。
  const CompassPage({super.key});

  @override
  ConsumerState<CompassPage> createState() => _CompassPageState();
}

/// 指南针页状态：持有传感器订阅、平滑插值动画、GPS 状态与记录列表刷新。
class _CompassPageState extends ConsumerState<CompassPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// 埋点常量：权限触发时机 —— 进页即自动申请。
  static const String _kPermissionTriggerPageOpen = 'page_open';

  /// 埋点常量：权限触发时机 —— 点「记录当前位置」时的兜底申请。
  static const String _kPermissionTriggerRecord = 'record';

  /// 埋点常量：权限触发时机 —— 点引导里的「打开设置」跳系统设置。
  static const String _kPermissionTriggerOpenSettings = 'open_settings';

  /// 传感器事件流订阅，[dispose] 时取消避免泄漏。
  StreamSubscription<CompassEvent>? _subscription;

  // ===== 表盘旋转：帧驱动的一阶低通跟随（2026-09-18 定稿）=====
  //
  // 为什么不用 AnimationController：
  //   它的 value 被强制夹在 [0,1]（`_internalSetValue` / `_tick` 都做 clampDouble），
  //   而表盘角是弧度（量纲 ±2π）。早期实现把弧度交给 animateTo，负角全被压成 0，
  //   表现就是「指针只会朝一个方向转」。
  //   更隐蔽的问题是：传感器 20~100Hz、动画 600ms，每次 forward(from: 0) 都把动画
  //   打回原点重算补间，配合「显示角作为起点」会出现跟随滞后与方向抖动。
  //   ⇒ 改为自己按帧积分：角度活在两个普通 double 字段里，**不存在任何边界**。
  //
  // 为什么偏要用「懒创建」而不是 late final 字段：
  //   State 的字段初始化与 initState 只在**首次创建**时跑一次。热重载（Hot Reload）
  //   保留老 State 实例却不重跑它们，于是新增的监听/字段全是空的 ——
  //   典型症状就是「底下数字在动（ setState 走了）、指针却完全不动」。
  //   懒创建让「第一次用到」的时候自己补上，任何情况下都能自愈。

  /// 表盘**当前实际显示角**（弧度，= -heading），恒等于 [_dialTarget] 的滞后跟随值。
  ///
  /// 活在连续空间里，可随转动无限累加，没有任何 [0,1] 之类的边界约束。
  double _dialAngle = 0;

  /// 本轮要转到位的**目标角**（弧度），由 [_animateToHeading] 累加更新。
  ///
  /// 与 [_dialAngle] 模 2π 同余；保留累加值是为了让跨 0°/360° 时走短弧。
  double _dialTarget = 0;

  /// 帧回调器（懒创建）。负责每帧把显示角推向目标角，收敛后自动停止。
  Ticker? _ticker;

  /// 上一帧的 Ticker 时间戳，用于算真实帧间隔（使滤波与帧率无关）。
  ///
  /// 为 null 表示「本轮刚开始」，此时按 1/60 秒走第一帧。
  Duration? _lastElapsed;

  /// 表盘角度的可监听对象（懒创建，见 [_dial]）。
  ValueNotifier<double>? _dialNotifier;

  /// debug 模式下的帧计数，仅用于把日志节流到每 30 帧一条。
  int _debugFrames = 0;

  /// 表盘角度可监听值 —— 只驱动 [CompassWidget] 重建，不牵连整页。
  ///
  /// 懒创建的意义见本文件「表盘旋转」块注释：热重载保留老 State 时不跑 initState，
  /// 用懒创建可以让它在第一次被读取时补建，避免「数字动、指针不动」的假故障。
  ValueNotifier<double> get _dial => _dialNotifier ??= ValueNotifier<double>(_dialAngle);

  /// 当前目标方位角（度，0=北，顺时针），用于读数展示。
  double _heading = 0;

  /// 传感器是否可用（流曾给出非 null 的 heading）。
  bool _available = false;

  /// 是否锁定当前读数（锁定后停止跟随传感器）。
  bool _locked = false;

  /// 是否正在保存一条记录（连点保护，避免同一点存两条）。
  bool _saving = false;

  /// 最近一次已知的 GPS 位置（可能为 null：未授权/无信号）。
  /// 读数卡与记录操作都以其作为经纬度/海拔来源。
  Position? _position;

  /// 定位是否处于「被用户挡住」状态：权限被拒（含永久拒绝）或系统定位服务关闭。
  ///
  /// true 时在读数卡下方显示一条引导，提供「打开设置」入口；
  /// 用户在系统设置里开启后回到本页会自动重试（见 [didChangeAppLifecycleState]）。
  bool _locationBlocked = false;

  /// 被挡的原因是否是「系统定位总开关关闭」（区别于应用权限被拒）。
  ///
  /// 两者文案不同：前者要用户去开总开关，后者要去开本 App 的权限。
  bool _locationServiceOff = false;

  /// 历史记录是否展开为「全部」（超过 3 条时用于「查看全部 / 收起」切换）。
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // 注意：这里**刻意什么都不初始化**。
    // 帧驱动 Ticker 与角度通知器都改成懒创建（见字段区注释），
    // 让它们在第一次传感器事件 / 第一次 build 时自行建立 —— 这样即使 State 来自
    // 热重载保留下来的老实例，表盘也能正常工作，不会退化成「数字动、指针不动」。
    _initCompass();
    // 预取最近一次已知位置填充读数卡（不弹权限窗，仅用缓存）。
    _loadLastPosition();
    // 进页即申请定位权限，而不是等到点「记录当前位置」才弹授权框。
    //
    // ⚠️ 必须延到**首帧渲染之后**再弹：initState 阶段系统授权弹窗往往还没挂上，
    //    直接与页面构建抢帧会出现「弹窗不显示 / 闪一下就没」的问题。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ⚠️ 还要再等一小会儿：此刻**路由转场动画可能仍在进行**（从 tools 页 push 进来），
      //    转场途中弹系统授权框会被 iOS 直接丢弃（表现就是"什么都没发生"）。
      //    350ms 足够覆盖默认转场时长（MaterialPageRoute 约 300ms）。
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _requestLocationOnEnter();
    });
    // 监听前后台：从「系统设置」返回时重新判定定位权限。
    WidgetsBinding.instance.addObserver(this);
  }

  /// 应用生命周期变化：从系统设置返回时重新尝试定位。
  ///
  /// 用户在系统设置里开启权限后回到的就是本页，此时 [_locationBlocked] 还是旧的
  /// true，必须重新判定一次并撤掉引导条；如果用户没开启，recheck 也不会重复弹框
  /// （已拒绝状态下 requestPermission 不会再弹），不会骚扰。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _locationBlocked) {
      await _requestLocationOnEnter();
    }
  }

  /// 订阅指南针传感器流。
  ///
  /// [FlutterCompass.events] 为可空流：流本身为 null（平台不支持）或首帧即返回
  /// null heading（权限未授予/无传感器）时，统一进入 [_available]=false 占位态。
  void _initCompass() {
    final Stream<CompassEvent>? events = FlutterCompass.events;
    if (events == null) {
      // 平台根本不支持（理论上罕见），直接占位。
      if (mounted) setState(() => _available = false);
      return;
    }
    _subscription = events.listen(
      (event) {
        // heading 为 null 表示当前不可用（如 iOS 运动权限被拒）。
        if (event.heading == null) {
          if (mounted) setState(() => _available = false);
          return;
        }
        if (mounted) setState(() => _available = true);
        // 锁定态下冻结读数，不更新目标角度。
        if (!_locked) _animateToHeading(event.heading!);
      },
      onError: (_) {
        if (mounted) setState(() => _available = false);
      },
    );
  }

  /// 跟随时间常数（秒）：每一帧吃掉剩余角差的 `1 - exp(-dt / tau)`。
  ///
  /// 0.12s 时单帧（16ms）约推进 12%，观感是「指针平顺吸附到新方位」：
  /// 既不像 600ms 缓出那样追不上快速转动，也不会生硬跳变。
  static const double _followTau = 0.12;

  /// 收敛阈值（弧度）：约 0.006°，比传感器噪声还小一个量级。
  /// 到这个量级已不可见，直接停表省电。
  static const double _convergeEpsilon = 1e-4;

  /// 每帧把显示角指数逼近目标角（一阶低通 / 临界阻尼跟随）。
  ///
  /// 用 Ticker 的 [elapsed] 算真实帧间隔，因此**与帧率无关**：
  /// 60Hz / 120Hz 屏上的跟随速度一致，掉帧也只是推进慢一点，不会甩针。
  void _onTick(Duration elapsed) {
    // 本轮首帧没有参照，按 60fps 估算一帧。
    final double dt = _lastElapsed == null
        ? 1 / 60
        : (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    // 卡顿 / 从后台切回来时 dt 可能是好几秒，必须夹住：
    // 不夹的话理论上会一帧跳到目标，视觉上是表盘甩一下。
    final double dtClamped = dt.clamp(0.0, 0.1);
    final double delta = _dialTarget - _dialAngle;
    if (delta.abs() < _convergeEpsilon) {
      _finishDial();
      return;
    }
    // 指数逼近：按剩余角差的固定比例推进，且与符号无关 ——
    // 顺时针 / 逆时针走的是同一条分支，不存在「负角被截成 0」的可能。
    _dialAngle += delta * (1 - math.exp(-dtClamped / _followTau));
    // 只动通知器：由 ValueListenableBuilder 局部重建 CompassWidget，不整页刷新。
    _dial.value = _dialAngle;
    if (kDebugMode) {
      _debugFrames++;
      // 节流到每 30 帧一条，避免刷屏。
      if (_debugFrames % 30 == 0) {
        debugPrint(
          '[Compass] dial=${(_dialAngle * 180 / math.pi).toStringAsFixed(1)}° '
          'target=${(_dialTarget * 180 / math.pi).toStringAsFixed(1)}° '
          'gap=${(delta * 180 / math.pi).toStringAsFixed(2)}°',
        );
      }
    }
  }

  /// 收敛收尾：对齐到目标角并停表（不让 Ticker 空转耗电）。
  void _finishDial() {
    _dialAngle = _dialTarget;
    _dial.value = _dialAngle;
    // 本轮结束：丢掉帧参照，下次启动重新按「无参照」走第一帧。
    _lastElapsed = null;
    _ticker?.stop();
  }

  /// 将表盘平滑转到新方位角对应的角度（走最短弧，跨 0°/360° 不倒着绕一圈）。
  ///
  /// - [headingDeg]：目标方位角（度）。表盘旋转角 = -headingDeg（N 始终指向真北）。
  ///
  /// 这里**只改目标角，不碰正在进行的跟随**：传感器每秒几十次，
  /// 若每次都重启一段补间，动画永远被从 0 打回，指针就会「追不上 / 只有一边动」。
  /// 交给 [_onTick] 按帧收敛，转向还能自然接力、反向即时生效。
  void _animateToHeading(double headingDeg) {
    _heading = headingDeg;
    final double targetRad = -headingDeg * math.pi / 180;
    // 相对**当前目标角**（而不是显示角）求最短弧差，并归一到 [-π, π]：
    //   · 用目标角做参考，连续转动时目标角单调推进，不会因显示角滞后而反复改变方向；
    //   · 累加（而非直接赋值）让目标角活在连续空间里，不受 [-2π, 0] 约束 ——
    //     于是 359°→0° 是 +1° 的短弧，而不是倒着绕近一整圈。
    double delta = targetRad - _dialTarget;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    _dialTarget += delta;
    _ensureTickerRunning();
  }

  /// 确保帧驱动在跑（幂等）：目标一变，就得有帧回调把显示角推过去。
  ///
  /// Ticker 与通知器都在这里懒创建 —— 使得本页**不依赖 initState 也能自愈**：
  /// 热重载保留老 State 实例时不跑 initState，正是「数字动了、指针不动」的来源。
  void _ensureTickerRunning() {
    final Ticker? existing = _ticker;
    if (existing != null && existing.isActive) return;
    // 新一轮开始：丢掉旧的帧参照，由 [_onTick] 按 60fps 走首帧。
    _lastElapsed = null;
    // createTicker 每个 State 只允许调一次（SingleTickerProviderStateMixin 有断言），
    // 所以必须是 ??= 而不是每次新建。
    _ticker ??= createTicker(_onTick);
    _ticker!.start();
  }

  /// 切换锁定/解锁。解锁时立即用最新 heading 重新对齐指针。
  void _toggleLock() {
    setState(() => _locked = !_locked);
    // 读数锁定埋点：使用率极低则可简化 UI，把空间让给主读数。
    AppTrack.log(
      TrackEvents.compassLockToggle,
      params: <String, Object?>{'locked': _locked},
    );
  }

  /// 预取系统缓存的最近一次位置（不弹权限窗），用于读数卡初始填充。
  Future<void> _loadLastPosition() async {
    try {
      final Position? p = await Geolocator.getLastKnownPosition();
      // 只在还没有位置时写入：进页授权流程（_requestLocationOnEnter）可能已经
      // 先一步拿到实时坐标，此时不能被这份陈旧缓存覆盖回去。
      if (mounted && p != null && _position == null) {
        setState(() => _position = p);
      }
    } catch (_) {
      // 桌面/Web 等不支持定位的平台忽略，读数卡相应字段显示「—」。
    }
  }

  /// 进页即申请定位权限，并在已授权时取一次实时位置填充读数卡。
  ///
  /// 这样用户点「记录当前位置」时权限已经是就绪状态，不会先被系统授权框打断；
  /// 未授权（本次拒绝 / 永久拒绝 / 定位服务关闭）也不影响指南针本体与保存记录，
  /// 只是经纬度与海拔为空。
  ///
  /// 不抛异常：任何失败都静默降级，并统一由 [_logLocationPermission] 记一次埋点。
  ///
  /// ⚠️ 「没弹授权框」时按这几条自查（debug 模式下控制台都有 `[Compass][perm]` 日志）：
  ///   1. `checkPermission=deniedForever` → iOS/安卓对已永久拒绝的应用**不再弹框**，
  ///      只能引导去设置（或删 App 重装复位）；
  ///   2. `serviceEnabled=false` → 系统定位总开关关着，插件不会弹框；
  ///   3. 热重载（Hot Reload）**不会重跑 initState**，进页申请逻辑压根没执行，
  ///      必须 Hot Restart 或重新运行。
  Future<void> _requestLocationOnEnter() async {
    // 是否已拿到授权：用于区分「权限被挡」与「已授权但取位置失败（室内无 fix）」——
    // 后者不该显示权限引导条，否则会误导用户去改一个本来没问题的权限。
    bool granted = false;
    _logPermission('start trigger=page_open');
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _logPermission('serviceEnabled=$serviceEnabled');
      if (!serviceEnabled) {
        _logLocationPermission(
          granted: false,
          permanentlyDenied: false,
          trigger: _kPermissionTriggerPageOpen,
          serviceEnabled: false,
        );
        _setLocationBlocked(true, serviceOff: true);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      _logPermission('checkPermission=${perm.name}');
      // 只有「从未决定 / 普通拒绝」时系统才会真的弹框；已授权 / 已永久拒绝都不会再弹，
      // 重复进页是安全的（不会骚扰用户）。
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        _logPermission('requestPermission=${perm.name}');
      }
      granted =
          perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
      _logLocationPermission(
        granted: granted,
        permanentlyDenied: perm == LocationPermission.deniedForever,
        trigger: _kPermissionTriggerPageOpen,
        serviceEnabled: true,
        status: perm.name,
      );
      // 用户拒绝 → 自动打开系统设置页（2026-09-10 按用户口径改为直跳），
      // 同时保留页内引导条兜底（openAppSettings 失败 / 平台不支持时仍可见）。
      // 返回页面后由 WidgetsBindingObserver 的 resumed 回调重新检查权限并自动撤条。
      _setLocationBlocked(!granted);
      if (!granted) {
        _logPermission('denied -> auto openAppSettings');
        try {
          await GeolocatorPlatform.instance.openAppSettings();
        } catch (e) {
          // 跳转失败不影响页面：引导条仍在，用户可手动点「打开设置」。
          _logPermission('openAppSettings error=$e');
        }
        return;
      }
      // 已授权 → 顺带取一次实时位置，让读数卡一进页就有经纬度/海拔。
      // 同样带 8 秒超时，室内等不到 fix 也不会把页面流程卡住。
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) setState(() => _position = p);
      _setLocationBlocked(false);
    } catch (e) {
      _logPermission('error=$e');
      // 权限/定位相关的平台异常一律降级，不影响指南针其他功能。
      _logLocationPermission(
        granted: false,
        permanentlyDenied: false,
        trigger: _kPermissionTriggerPageOpen,
      );
      // 只有**没拿到授权**才亮权限引导；已授权却取不到坐标（室内无 fix、超时）
      // 属于信号问题，显示「权限未开启」会把用户带偏。
      if (!granted) _setLocationBlocked(true);
    }
  }

  /// 输出定位权限流程的诊断日志（仅 debug 模式）。
  ///
  /// 排查「授权框没弹出来」时，按控制台 `[Compass][perm]` 的顺序即可判断
  /// 流程停在哪一步，无需加断点。
  void _logPermission(String message) {
    if (kDebugMode) debugPrint('[Compass][perm] $message');
  }

  /// 更新「定位被挡住」状态（仅在变化时刷新，避免无意义的重建）。
  ///
  /// - [blocked]：是否显示引导条。
  /// - [serviceOff]：是否因「系统定位总开关关闭」被挡（决定引导文案）。
  void _setLocationBlocked(bool blocked, {bool serviceOff = false}) {
    if (!mounted) return;
    if (_locationBlocked == blocked && _locationServiceOff == serviceOff) return;
    setState(() {
      _locationBlocked = blocked;
      _locationServiceOff = serviceOff;
    });
  }

  /// 打开系统设置页，让用户手动开启定位权限。
  ///
  /// ⚠️ 走 `GeolocatorPlatform.instance.openAppSettings()`：geolocator 14 的
  /// [Geolocator] 主类没有这个方法（只有平台接口层有）。平台未实现时返回 false
  /// 或抛异常，均只上报不提示——不支持跳转时静默失败即可，不影响其他功能。
  Future<void> _openLocationSettings() async {
    try {
      await GeolocatorPlatform.instance.openAppSettings();
      // 埋点：统计「拒绝后愿意进设置」的比例，衡量引导是否值得保留。
      AppTrack.log(
        TrackEvents.toolPermissionResult,
        params: <String, Object?>{
          'tool': 'compass',
          'permission': 'location',
          'granted': false,
          'permanently_denied': true,
          'trigger': _kPermissionTriggerOpenSettings,
        },
      );
    } catch (e, s) {
      AppTrack.error('compass_open_settings', e, s);
    }
  }

  /// 取一个当前位置用于记录：**只读权限状态、不弹授权框**，失败或不可用时返回 null。
  ///
  /// 权限申请只发生在进页时（[_requestLocationOnEnter]，页面一打开就弹）；
  /// 保存路径绝不 requestPermission——否则进页拒绝过的用户点保存会二次弹框，
  /// 体验突兀且违背「进页即申请」的统一口径。
  ///
  /// 不抛异常——无 GPS 时记录功能仍可用（仅写入方位角，坐标留空）。
  Future<Position?> _ensureCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _logLocationPermission(
          granted: false,
          permanentlyDenied: false,
          trigger: _kPermissionTriggerRecord,
        );
        return null;
      }
      // 只读检查权限现状，不做任何申请：正常情况下进页已授权，这里直接通过；
      // 进页被拒 / 永久拒绝的用户到保存时依然不弹框，直接走「坐标留空」降级。
      final LocationPermission perm = await Geolocator.checkPermission();
      // 三种结局分开上报：被拒会让「记录位置」直接不可用，
      // 而「永久拒绝」比「本次拒绝」严重得多（后者进页时还能再弹窗，前者只能去系统设置）。
      final bool granted =
          perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
      _logLocationPermission(
        granted: granted,
        permanentlyDenied: perm == LocationPermission.deniedForever,
        trigger: _kPermissionTriggerRecord,
      );
      // 进页拒绝过的用户，保存时仍亮着「打开设置」引导（仅更新引导条，不弹系统框）。
      _setLocationBlocked(!granted);
      if (!granted) return null;
      // 保存性能优化（2026-09-10）：不要每次都傻等 GPS 新鲜 fix ——
      // getCurrentPosition 在室内/信号弱时会把 timeLimit 的 8 秒等满，
      // 用户感知就是「保存比 level 页慢好几秒」。改为两级策略：
      //   1) 先取系统缓存的最近一次定位（getLastKnownPosition，毫秒级返回），
      //      缓存在 5 分钟内视为足够新鲜，直接使用（记录点位场景精度足够）；
      //   2) 没有缓存或缓存太旧，才真正等待 GPS fix（同样带 8 秒超时兜底）。
      final Position? cached = await Geolocator.getLastKnownPosition();
      // 5 分钟内的缓存坐标对「记录点位」足够；太久远的漂移风险大，不采用。
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) <
              const Duration(minutes: 5)) {
        return cached;
      }
      // 缓存不可用才走实时定位。
      //
      // ⚠️ timeLimit 必须给（写在 LocationSettings 里，顶层同名参数已废弃）：
      // 不传时 iOS/安卓在室内、无 GPS 信号或权限刚授予的场景下 getCurrentPosition
      // 可能**一直不返回**（等不到定位 fix），「记录当前位置」就永远卡在这一步 ——
      // 表现是点了按钮毫无反应、既没保存也没提示。超时后抛 TimeoutException，
      // 由下面 catch 兜住返回 null，记录照常保存（只是没有坐标）。
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      // 异常路径同样记一次失败，否则「定位服务崩溃」这类问题在埋点里完全不可见。
      _logLocationPermission(
        granted: false,
        permanentlyDenied: false,
        trigger: _kPermissionTriggerRecord,
      );
      return null;
    }
  }

  /// 上报定位权限申请结果。
  ///
  /// 抽成方法是因为失败分支有四条（服务未开 / 本次拒绝 / 永久拒绝 / 异常），
  /// 逐条手写会漏。
  ///
  /// - [trigger]：触发时机（`page_open` 进页自动申请 / `record` 点记录按钮时兜底申请），
  ///   用于对比「进页申请」的授权率与「用到了才申请」的差异。
  void _logLocationPermission({
    required bool granted,
    required bool permanentlyDenied,
    required String trigger,
    bool? serviceEnabled,
    String? status,
  }) {
    final Map<String, Object?> params = <String, Object?>{
      'tool': 'compass',
      'permission': 'location',
      'granted': granted,
      'permanently_denied': permanentlyDenied,
      'trigger': trigger,
    };
    // 这两个是排查「授权框没弹出来」的关键：service_enabled=false 说明系统
    // 定位总开关关着；permission_status=deniedForever 说明已被永久拒绝（不会再弹框）。
    if (serviceEnabled != null) params['service_enabled'] = serviceEnabled;
    if (status != null) params['permission_status'] = status;
    AppTrack.log(TrackEvents.toolPermissionResult, params: params);
  }

  /// 方位角 → 8 向（字母缩写 + 本地化全名）。
  ///
  /// - [heading]：方位角（度）。
  /// - [l10n]：用于取本地化方位名。
  ///
  /// 返回 `[缩写, 本地化名]`，如 `['NE', '东北']`。
  (String, String) _cardinal(double heading, AppLocalizations l10n) {
    // 8 个扇区中心角与对应文案，顺时针排列。
    final List<(int, String, String)> dirs = [
      (0, 'N', l10n.compassDirN),
      (45, 'NE', l10n.compassDirNE),
      (90, 'E', l10n.compassDirE),
      (135, 'SE', l10n.compassDirSE),
      (180, 'S', l10n.compassDirS),
      (225, 'SW', l10n.compassDirSW),
      (270, 'W', l10n.compassDirW),
      (315, 'NW', l10n.compassDirNW),
    ];
    // 归一化到 [0,360) 后加 22.5° 再除 45°，落入最接近的扇区。
    final double h = ((heading % 360) + 360) % 360;
    final int idx = ((h + 22.5) / 45).floor() % 8;
    return (dirs[idx].$2, dirs[idx].$3);
  }

  /// 将记录时间格式化为「年/月/日 时:分」，跨语言一致、无歧义。
  String _formatTime(DateTime t) {
    final String hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} $hm';
  }

  /// 记录当前位置：取实时 GPS →（可选）弹窗命名 → 写入「指南针表」→ 刷新列表。
  ///
  /// 全流程包在 try/catch 里：任何一步抛异常都必须让用户**看见**
  /// （旧实现异常直接冒泡，异步回调里被框架吞掉 → 表现为「点了没反应」）。
  Future<void> _recordCurrentLocation() async {
    // 连点保护：第一次点击未走完前忽略后续点击，避免同一点存两条。
    if (_saving) return;
    // 提前捕获 context 相关对象，避免 await 后跨异步间隙使用 BuildContext 的告警。
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (mounted) setState(() => _saving = true);
    try {
      await _doRecordCurrentLocation(l10n);
    } catch (e, s) {
      // 失败要留痕：上传异常，否则线上「保存不了」这类问题在埋点里完全看不见。
      AppTrack.error('compass_record', e, s);
      debugPrint('[Compass] 记录失败: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.compassSaveFailed)),
        );
      }
    } finally {
      // 无论成功失败都解锁；页面已销毁则只改字段不 setState。
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  /// 实际的记录流程（由 [_recordCurrentLocation] 调起，异常交给上层处理）。
  Future<void> _doRecordCurrentLocation(AppLocalizations l10n) async {
    // 1) 取实时位置（会按需弹权限窗）；失败则沿用已有的缓存位置。
    final Position? pos = await _ensureCurrentPosition();
    if (mounted && pos != null) setState(() => _position = pos);

    // 2) 记录名：是否弹命名框由全局开关决定（profile 设置「保存弹框」，
    //    默认关闭 → 用毫秒时间戳命名、一步保存）。未就绪时 `?? false` 回落不弹框。
    final bool askName = ref.read(saveNamePromptProvider).value ?? false;
    final String name;
    if (askName) {
      final String? input = await _showNameDialog();
      // 取消或留空一律放弃保存（弹窗路径下名称是必填项，沿用原逻辑）。
      if (input == null || input.trim().isEmpty) return;
      name = input.trim();
    } else {
      name = defaultRecordName();
    }

    // 3) 组装并持久化记录（方位角取自罗盘，坐标取自 GPS，可能为 null）。
    final (abbr, name_) = _cardinal(_heading, l10n);
    final record = CompassRecord(
      name: name,
      heading: _heading,
      cardinalAbbrev: abbr,
      cardinalName: name_,
      altitude: _position?.altitude,
      latitude: _position?.latitude,
      longitude: _position?.longitude,
      createdAt: DateTime.now(),
    );
    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.compassRecords.put(record);
    });

    // 保存成功埋点：区分「打开看看」与「真的在用」的关键指标。
    // has_gps 为 false 的比例过高 → 权限引导有问题（记录里缺坐标，价值打折）；
    // cardinal 的分布可验证罗盘读数是否存在系统性偏斜。
    // 注意只上报方位扇区，绝不上报经纬度原值（隐私红线，见 doc/track.md 1.3）。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'compass',
        'has_name': name.isNotEmpty,
        // 本次是否经过命名弹窗（受全局开关控制），与 level / noise 同口径。
        'prompt': askName,
        'has_gps': _position != null,
        'cardinal': TrackBuckets.cardinal(_heading),
      },
    );

    if (mounted) {
      // 重新拉取「指南针表」，使历史记录区立即出现新条目。
      ref.invalidate(compassRecordsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compassRecordSaved)),
      );
    }
  }

  /// 弹出命名对话框，返回用户输入的名称（取消时返回 null）。
  Future<String?> _showNameDialog() async {
    final TextEditingController ctl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.compassRecordDialogTitle),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.compassRecordNameHint),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.compassCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: Text(l10n.compassSave),
          ),
        ],
      ),
    );
    // 一次性对话框的控制器交由 GC 回收（短生命周期，无泄漏风险）。
    return result;
  }

  /// 导出全部记录：拼成 TSV 文本并复制到剪贴板（无需额外分享依赖）。
  Future<void> _exportRecords(List<CompassRecord> records) async {
    if (records.isEmpty) return;
    final StringBuffer sb = StringBuffer();
    for (final CompassRecord r in records) {
      final double? latVal = r.latitude;
      final double? lngVal = r.longitude;
      final double? altVal = r.altitude;
      final String lat = latVal != null
          ? '${latVal.toStringAsFixed(4)}°${latVal >= 0 ? 'N' : 'S'}'
          : '—';
      final String lng = lngVal != null
          ? '${lngVal.toStringAsFixed(4)}°${lngVal >= 0 ? 'E' : 'W'}'
          : '—';
      final String alt = altVal != null ? '${altVal.round()} m' : '—';
      final String dir = '${r.cardinalAbbrev} ${r.heading.round()}° ${r.cardinalName}';
      sb.writeln(
        '${r.name}\t${_formatTime(r.createdAt)}\t$dir\t$alt\t$lat, $lng',
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));

    // 导出埋点：重度用户信号 —— 愿意把数据带走的人，才会需要「文件分享 / 云同步」。
    // count 反映单人数据规模，用于判断做云同步时单用户的存储成本量级。
    AppTrack.log(
      TrackEvents.toolExport,
      params: <String, Object?>{'tool': 'compass', 'count': records.length},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.compassExported),
        ),
      );
    }
  }

  /// 删除一条记录（先确认），成功后刷新列表。
  Future<void> _deleteRecord(CompassRecord r) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.compassDelete),
        content: Text(l10n.compassDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.compassCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.compassDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await IsarService.instance.writeTxn(() async {
        await IsarService.instance.compassRecords.delete(r.id);
      });
      // 删除埋点：删除频次高说明记录质量差或误操作多，可能需要撤销 / 批量管理。
      // remaining 用于识别重度用户（删完还剩很多 = 深度使用者）。
      final int remaining =
          (ref.read(compassRecordsProvider).value?.length ?? 1) - 1;
      AppTrack.log(
        TrackEvents.toolDataDeleted,
        params: <String, Object?>{
          'tool': 'compass',
          'remaining': remaining < 0 ? 0 : remaining,
        },
      );
      if (mounted) ref.invalidate(compassRecordsProvider);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Ticker / 通知器都是懒创建的，可能从未建立，一律判空。
    // 必须先 stop 掉活跃的 Ticker：SingleTickerProviderStateMixin 在 super.dispose
    // 里断言「不允许遗留正在 tick 的 Ticker」，遗留会直接抛 FlutterError。
    _ticker?.dispose();
    _dialNotifier?.dispose();
    // 必须反注册，否则页面销毁后生命周期回调仍会触发（持有已卸载的 State）。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = CompassPalette.of(context);
    final panel = _PanelPalette.of(context);
    final (abbr, name) = _cardinal(_heading, l10n);
    // 会员状态：决定「历史记录」上方的横幅广告是否入树。
    //
    // 与 tools / noise / level 三页同口径：VIP 卖点写着 No ads，
    // 已买断时**整块不放进树**——只隐藏不够，摘出树才会触发
    // AdBannerSlot.dispose() 释放原生广告实例。
    final bool isMember = ref.watch(isMemberProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.compassTitle),
        // 右侧锁定按钮：冻结/恢复读数，是罗盘常见交互。
        actions: [
          IconButton(
            icon: Icon(_locked ? Icons.lock : Icons.lock_open),
            tooltip: _locked ? l10n.compassUnlock : l10n.compassLock,
            onPressed: _toggleLock,
          ),
        ],
      ),
      body: SafeArea(
        // 顶部由 AppBar 处理；底部避让 Home Indicator，避免内容贴边。
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
          child: Column(
            children: [
              SizedBox(height: 16.h),
              // 罗盘本体 + 度数 + 方位：仅在传感器可用时展示，否则占位。
              if (_available) ...[
                // 只让罗盘跟着角度重建：读数卡、历史列表不参与每帧重建。
                //
                // ⚠️ 这里取 valueListenable 的当前值而不是 [_dialAngle] 字段：
                // 通知器是唯一重建信号，两者恒等，但用前者能保证「值变了就一定重建」。
                ValueListenableBuilder<double>(
                  valueListenable: _dial,
                  builder: (context, double angle, _) => CompassWidget(
                    rotation: angle,
                    palette: palette,
                    size: 260,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  '${_heading.round()}°',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: palette.degreeText,
                      ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$abbr · $name',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.labelText,
                      ),
                ),
                SizedBox(height: 24.h),
              ] else
                _UnavailableView(
                  palette: palette,
                  message: l10n.compassSensorUnavailable,
                ),
              SizedBox(height: 24.h),
              // ===== Pixso 2:3 面板：读数卡 + 操作按钮 + 历史记录 =====
              _buildReadingsCard(l10n, panel),
              SizedBox(height: 16.h),
              _buildActionButtons(l10n, panel),
              SizedBox(height: 24.h),
              // 横幅广告：位于「历史记录」标题之上。
              //
              // 位置理由与 noise / level 两页一致：上方的罗盘与读数卡是需要
              // 盯着看的核心区，广告不能插进去打断操作；历史区上方是内容自然的
              // 分段点。会员（已买断）时整块不入树：既不请求也不展示，
              // 且移除动作会 dispose 掉原生广告实例。
              if (!isMember) ...[
                AdBannerSlot(
                  labelText: l10n.adLabel,
                  slot: 'compass_history_top',
                  position: BannerPosition.compass,
                ),
                SizedBox(height: 16.h),
              ],
              _buildHistorySection(l10n, panel),
            ],
          ),
        ),
      ),
    );
  }

  /// 实时读数卡：方位角 / 海拔 / 纬度 / 经度（经纬度海拔来自 GPS，无则显示「—」）。
  Widget _buildReadingsCard(AppLocalizations l10n, _PanelPalette p) {
    // 当前方位角展示（无传感器时显示占位破折号）。
    final (abbr, name) = _cardinal(_heading, l10n);
    final String headingText = _available ? '$abbr ${_heading.round()}° $name' : '—';
    // 拷贝到本地可空变量后再判空：本地变量可被可靠地提升为非空，
    // 规避「Isar 字段非 final 无法提升」导致的可空告警。
    final double? alt = _position?.altitude;
    final double? lat = _position?.latitude;
    final double? lng = _position?.longitude;
    final String altitudeText = alt != null
        ? '${NumberFormat('#,##0').format(alt.round())} m'
        : '—';
    final String latitudeText = lat != null
        ? '${lat.toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}'
        : '—';
    final String longitudeText = lng != null
        ? '${lng.toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}'
        : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: p.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
      child: Column(
        children: [
          // 第一行：方位角（强调色，字号更大）/ 海拔。
          Row(
            children: [
              Expanded(
                child: ReadingItem(
                  label: l10n.compassHeading,
                  value: headingText,
                  valueColor: p.accent,
                  valueSize: 18,
                  valueWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ReadingItem(
                  label: l10n.compassAltitude,
                  value: altitudeText,
                  valueColor: p.valueText,
                  valueSize: 16,
                  valueWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // 行间分隔线（呼应设计稿 2:3 的横线）。
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            height: 1.h,
            color: p.divider,
          ),
          // 第二行：纬度 / 经度。
          Row(
            children: [
              Expanded(
                child: ReadingItem(
                  label: l10n.compassLatitude,
                  value: latitudeText,
                  valueColor: p.valueText,
                  valueSize: 16,
                  valueWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ReadingItem(
                  label: l10n.compassLongitude,
                  value: longitudeText,
                  valueColor: p.valueText,
                  valueSize: 16,
                  valueWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // 定位被挡住（权限拒绝 / 系统定位关闭）时才出现的引导条：
          // 说明原因 + 「打开设置」入口，不自动跳转，避免打断用户。
          if (_locationBlocked) ...[
            Container(
              margin: EdgeInsets.only(top: 12.h),
              height: 1.h,
              color: p.divider,
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.location_off_outlined, size: 16.sp, color: p.accent),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    // 区分原因：系统总开关关着 vs 本 App 权限被拒，
                    // 两种情况的处置路径不同（开总开关 / 开应用权限）。
                    _locationServiceOff
                        ? l10n.compassLocationServiceOff
                        : l10n.compassLocationDenied,
                    style: TextStyle(fontSize: 12.sp, color: p.valueText),
                  ),
                ),
                SizedBox(width: 8.w),
                // 文字按钮：点击跳系统设置（App 自己的权限页）。
                InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: _openLocationSettings,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    child: Text(
                      l10n.compassOpenSettings,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: p.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 操作按钮行：主按钮「记录当前位置」+ 次按钮「导出」。
  Widget _buildActionButtons(AppLocalizations l10n, _PanelPalette p) {
    return Row(
      children: [
        // 主按钮：占较大比例（设计稿约 239/342），填充强调色。
        Expanded(
          flex: 239,
          child: InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: _recordCurrentLocation,
            child: Container(
              height: 51.h,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 保存中（最多等 GPS 8 秒）显示转圈：否则这段等待期按钮毫无反馈，
                  // 用户会以为没点上而反复点击（连点已由 _saving 挡住，但仍需可见反馈）。
                  _saving
                      ? SizedBox(
                          // 必须锁 1:1 正方形，否则指示器被压成椭圆。
                          width: 18.sp,
                          height: 18.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.recordBtnText,
                          ),
                        )
                      : Icon(
                          Icons.location_on,
                          size: 18.sp,
                          color: p.recordBtnText,
                        ),
                  SizedBox(width: 8.w),
                  Text(
                    l10n.compassRecordLocation,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: p.recordBtnText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // 次按钮：占较小比例（设计稿约 91/342），浅底强调字。
        Expanded(
          flex: 91,
          child: InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () {
              // 导出当前列表（取最新一份快照）。
              final list = ref.read(compassRecordsProvider).value ?? [];
              _exportRecords(list);
            },
            child: Container(
              height: 51.h,
              decoration: BoxDecoration(
                color: p.secondaryBtnBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: p.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload, size: 18.sp, color: p.accent),
                  SizedBox(width: 6.w),
                  Text(
                    l10n.compassExport,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 历史记录区：标题 + 「查看全部/收起」+ 记录卡片列表（来自 Isar「指南针表」）。
  Widget _buildHistorySection(AppLocalizations l10n, _PanelPalette p) {
    // 订阅「指南针表」，数据变化自动重建本区。
    final AsyncValue<List<CompassRecord>> recordsAsync =
        ref.watch(compassRecordsProvider);

    // 标题行：左标题，右「查看全部 / 收起」（仅多于 3 条时显示）。
    final List<CompassRecord> all = recordsAsync.value ?? [];
    final bool hasMore = all.length > 3;
    final List<CompassRecord> visible =
        _showAll ? all : all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.compassHistory,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: p.titleText,
              ),
            ),
            const Spacer(),
            if (hasMore)
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? l10n.compassCollapse : l10n.compassViewAll,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: p.labelText,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        // 加载/空/列表三种状态。
        recordsAsync.isLoading
            ? HistoryPlaceholder(text: l10n.compassHistory)
            : all.isEmpty
                ? HistoryPlaceholder(text: l10n.compassNoRecords)
                : Column(
                    children: visible
                        .map((r) => _buildHistoryCard(r, l10n, p))
                        .toList(),
                  ),
      ],
    );
  }

  /// 单条历史记录卡片：名称 + 时间 + 删除；方向 + 海拔；经纬度。
  Widget _buildHistoryCard(
    CompassRecord r,
    AppLocalizations l10n,
    _PanelPalette p,
  ) {
    final double? latVal = r.latitude;
    final double? lngVal = r.longitude;
    final double? altVal = r.altitude;
    final String lat = latVal != null
        ? '${latVal.toStringAsFixed(4)}°${latVal >= 0 ? 'N' : 'S'}'
        : '—';
    final String lng = lngVal != null
        ? '${lngVal.toStringAsFixed(4)}°${lngVal >= 0 ? 'E' : 'W'}'
        : '—';
    final String alt = altVal != null ? '${altVal.round()} m' : '—';
    final String dir = '${r.cardinalAbbrev} ${r.heading.round()}°';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: p.cardBorder),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称 + 时间 + 删除。
          Row(
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: p.titleText,
                  ),
                ),
              ),
              Text(
                _formatTime(r.createdAt),
                style: TextStyle(fontSize: 12.sp, color: p.labelText),
              ),
              SizedBox(width: 4.w),
              // 删除按钮（淡色，避免抢视觉重心）。
              IconButton(
                constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
                padding: EdgeInsets.zero,
                icon: Icon(Icons.delete_outline,
                    size: 18.sp, color: p.muted),
                onPressed: () => _deleteRecord(r),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // 方向 + 海拔（标签:值 同行）。
          Row(
            children: [
              Expanded(
                child: _historyMetric(
                  l10n.compassDirection,
                  '$dir ${r.cardinalName}',
                  p.accent,
                  p.labelText,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _historyMetric(
                  l10n.compassAltitude,
                  alt,
                  p.valueText,
                  p.labelText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // 经纬度整行。
          Text(
            '${l10n.compassLatLng}: $lat, $lng',
            style: TextStyle(fontSize: 12.sp, color: p.labelText),
          ),
        ],
      ),
    );
  }

  /// 历史卡片中的「标签: 值」单元（标签用次级色，值用强调/正文色）。
  Widget _historyMetric(
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(fontSize: 13.sp, color: labelColor),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 读数卡中的「标签 + 值」单元。
///
/// [label] 为小字次级色；[value] 为下方主值，可配置颜色/字号/字重。
class ReadingItem extends StatelessWidget {
  /// 创建读数单元。
  const ReadingItem({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.valueSize,
    required this.valueWeight,
  });

  /// 标签（如「方位角」）。
  final String label;

  /// 主值（如「N 15° 北」）。
  final String value;

  /// 主值颜色（方位角用强调色，其余用正文色）。
  final Color valueColor;

  /// 主值字号。
  final double valueSize;

  /// 主值字重。
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    final _PanelPalette p = _PanelPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: p.labelText,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize.sp,
            fontWeight: valueWeight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// 历史区占位（加载中 / 空列表提示）。
class HistoryPlaceholder extends StatelessWidget {
  const HistoryPlaceholder({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final _PanelPalette p = _PanelPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, color: p.labelText),
      ),
    );
  }
}

/// 指南针可视化组件（无状态）。
///
/// 仅负责绘制：固定尺寸的圆形表盘 + 可旋转的刻度/字母/指针 + 顶部固定指向三角。
/// 旋转角由外部 [rotation]（弧度）驱动，自身不订阅传感器、不做动画。
class CompassWidget extends StatelessWidget {
  /// 创建罗盘组件。
  ///
  /// - [rotation]：表盘旋转角（弧度，= -heading），由父级动画控制器传入；
  /// - [palette]：当前主题色板；
  /// - [size]：直径（逻辑像素，外部已乘 .w）。
  const CompassWidget({
    required this.rotation,
    required this.palette,
    this.size = 260,
    super.key,
  });

  final double rotation;
  final CompassPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.w,
      height: size.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 表盘底色 + 描边（固定层）。
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.dialFace,
              border: Border.all(color: palette.dialRing, width: 1.w),
            ),
          ),
          // 旋转层：刻度 + 字母 + 指针整体随 rotation 转动，使 N 永远指向真北。
          // 必须显式指定绕中心旋转：Transform.rotate 默认绕左上角原点转，
          // 会导致表盘甩出自身区域、视觉上像整页在旋转。
          Transform.rotate(
            angle: rotation,
            alignment: Alignment.center,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _CompassDialPainter(palette),
                // size 由 SizedBox.expand 撑满父级圆形区域。
                size: Size.square(size.w),
              ),
            ),
          ),
          // 顶部固定指向三角：始终指示「你正面对的方向」，不随表盘旋转。
          Positioned(
            top: 0,
            child: CustomPaint(
              size: Size(18.w, 16.h),
              painter: _TopMarkerPainter(palette.topMarker),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表盘绘制：刻度、N/E/S/W 字母、红黑指针、中心轴。
///
/// 绘制于表盘本地坐标系（0° 在顶部），由 [CompassWidget] 的 Transform 统一旋转。
class _CompassDialPainter extends CustomPainter {
  /// 创建表盘绘制器。
  const _CompassDialPainter(this.palette);

  final CompassPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;

    // 刻度：每 10° 一根，整 30° 为主刻度（更长更粗）。
    final Paint minorPaint = Paint()
      ..color = palette.tickMinor
      ..strokeWidth = 1.w
      ..strokeCap = StrokeCap.round;
    final Paint majorPaint = Paint()
      ..color = palette.tickMajor
      ..strokeWidth = 2.w
      ..strokeCap = StrokeCap.round;
    for (int deg = 0; deg < 360; deg += 10) {
      final bool isMajor = deg % 30 == 0;
      // 0° 置于顶部：屏幕坐标下角度 = (deg-90)°。
      final double angle = (deg - 90) * math.pi / 180;
      final double outer = r * 0.92;
      final double inner = isMajor ? r * 0.80 : r * 0.87;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // 四方位字母：N 用罗盘红强调，其余用品牌色。
    const List<(String, int)> cardinals = [
      ('N', 0),
      ('E', 90),
      ('S', 180),
      ('W', 270),
    ];
    for (final (label, deg) in cardinals) {
      final double angle = (deg - 90) * math.pi / 180;
      final Offset pos = center +
          Offset(math.cos(angle) * r * 0.70, math.sin(angle) * r * 0.70);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: label == 'N' ? palette.compassRed : palette.cardinalText,
          ),
        ),
        textAlign: TextAlign.center,
        // 必须显式声明：TextPainter 不读 ambient，缺了会在 layout 时抛
        // "textDirection must be set to a non-null value"（罗盘无法绘制）。
        // ⚠️ 用 ui.TextDirection 而不是 TextDirection：intl 0.20.3 导出了自己的
        // TextDirection 类（用于 DateFormat），会遮蔽 Flutter 从 dart:ui re-export
        // 的那个；显式加前缀绕开遮蔽。
        textDirection: ui.TextDirection.ltr,
      )..layout();
      // 字母锚定中心：减去自身一半宽高。
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // 指针：北半红、南半灰，菱形（两枚三角拼成），尖端指向表盘 N。
    final double northLen = r * 0.78;
    final double southLen = r * 0.66;
    final double halfW = r * 0.06;
    final Paint northPaint = Paint()..color = palette.compassRed;
    final Paint southPaint = Paint()..color = palette.needleSouth;
    // 北针（尖端朝上）。
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - northLen)
        ..lineTo(center.dx - halfW, center.dy)
        ..lineTo(center.dx + halfW, center.dy)
        ..close(),
      northPaint,
    );
    // 南针（尖端朝下）。
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy + southLen)
        ..lineTo(center.dx - halfW, center.dy)
        ..lineTo(center.dx + halfW, center.dy)
        ..close(),
      southPaint,
    );
    // 中心轴。
    canvas.drawCircle(center, r * 0.07, Paint()..color = palette.hub);
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter old) => old.palette != palette;
}

/// 顶部固定指向三角（尖端朝下，指向表盘中心方向）。
class _TopMarkerPainter extends CustomPainter {
  const _TopMarkerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, size.height) // 底部中点（尖）
        ..lineTo(0, 0)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TopMarkerPainter old) => old.color != color;
}

/// 传感器不可用时的占位视图。
///
/// 灰显罗盘（复用 CompassWidget 静态展示） + 说明文案，保证无传感器场景不崩。
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.palette, required this.message});

  final CompassPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 以 0° 静态展示罗盘，靠 muted 描边体现「未激活」。
        Opacity(
          opacity: 0.5,
          child: CompassWidget(
            rotation: 0,
            palette: palette,
            size: 260,
          ),
        ),
        SizedBox(height: 24.h),
        Icon(Icons.explore_off, size: 32.sp, color: palette.muted),
        SizedBox(height: 12.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, color: palette.labelText),
        ),
      ],
    );
  }
}

/// 指南针双主题色板（罗盘本体专用）。
///
/// 与 tool_page.dart 的 [_ToolPalette] 同理：深浅两版分别给定，逐项硬编码。
///
/// ⚠️ 本类全部字段都属「仪表语义固定色」：表盘底/描边、主次刻度、四方位字母、
/// 指针、中心轴、顶部指向三角、度数读数、方位标签、降级弱化色，均表达罗盘本体
/// 的黄铜质感，在咖啡色与蓝色两套主题下应保持一致，因此**不接** [AppPalette]。
/// 页面级通用语义色（卡片 / 文字 / 强调 / 分隔线）见 [_PanelPalette]。
class CompassPalette {
  /// 创建色板。所有颜色必填，避免深浅色下出现「串色」。
  const CompassPalette({
    required this.dialFace,
    required this.dialRing,
    required this.tickMajor,
    required this.tickMinor,
    required this.cardinalText,
    required this.compassRed,
    required this.needleSouth,
    required this.hub,
    required this.topMarker,
    required this.degreeText,
    required this.labelText,
    required this.muted,
  });

  /// 表盘底色。
  final Color dialFace;
  /// 表盘描边色。
  final Color dialRing;
  /// 主刻度（整 30°）颜色。
  final Color tickMajor;
  /// 次刻度颜色。
  final Color tickMinor;
  /// 四方位字母色（N 除外，N 永远是 compassRed）。
  final Color cardinalText;
  /// 北针尖红（暖调，不破坏大地色统一感）。
  final Color compassRed;
  /// 南针尖色。
  final Color needleSouth;
  /// 中心轴色。
  final Color hub;
  /// 顶部固定指向三角色。
  final Color topMarker;
  /// 度数读数色。
  final Color degreeText;
  /// 方位标签色。
  final Color labelText;
  /// 降级态用的弱化色。
  final Color muted;

  /// 依据当前主题明暗返回对应色板。
  static CompassPalette of(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      // 深色版（近黑底 #1C1C1E，卡片 #2C2C2E，品牌暖金 #C8A97E）。
      return const CompassPalette(
        dialFace: Color(0xFF2C2C2E),
        dialRing: Color(0xFF48484A),
        tickMajor: Color(0xFFF2F2F7),
        tickMinor: Color(0xFF636366),
        cardinalText: Color(0xFFC8A97E),
        compassRed: Color(0xFFE15A4A),
        needleSouth: Color(0xFFAEAEB2),
        hub: Color(0xFFC8A97E),
        topMarker: Color(0xFFC8A97E),
        degreeText: Color(0xFFF2F2F7),
        labelText: Color(0xFFAEAEB2),
        muted: Color(0xFF636366),
      );
    }
    // 浅色版（米白底 #F5F3EF，白表盘，深咖品牌 #6B5C44，暖红北针）。
    return const CompassPalette(
      dialFace: Color(0xFFFFFFFF),
      dialRing: Color(0xFFD1CDC4),
      tickMajor: Color(0xFF2C2924),
      tickMinor: Color(0xFFB5AFA7),
      cardinalText: Color(0xFF6B5C44),
      compassRed: Color(0xFFC0392B),
      needleSouth: Color(0xFF7A746B),
      hub: Color(0xFF6B5C44),
      topMarker: Color(0xFF6B5C44),
      degreeText: Color(0xFF2C2924),
      labelText: Color(0xFF7A746B),
      muted: Color(0xFFB5AFA7),
    );
  }
}

/// 读数卡 / 操作按钮 / 历史记录区的双主题色板（Pixso 2:3 浅色稿对齐）。
///
/// 浅色严格按设计稿：卡片 #EBE7E0、强调 #8B5C44、正文 #2C2924、次级 #7A746B、
/// 次按钮底 #F5F0E9。深色按工程色卡逐项给定（卡片 #2C2C2E、强调金 #C8A97E 等）。
class _PanelPalette {
  /// 创建面板色板。所有颜色必填，避免深浅串色。
  const _PanelPalette({
    required this.cardBg,
    required this.cardBorder,
    required this.titleText,
    required this.labelText,
    required this.valueText,
    required this.accent,
    required this.recordBtnText,
    required this.secondaryBtnBg,
    required this.divider,
    required this.muted,
  });

  /// 卡片底色。
  final Color cardBg;
  /// 卡片描边色。
  final Color cardBorder;
  /// 标题/名称文字色。
  final Color titleText;
  /// 标签/时间/经纬度次级文字色。
  final Color labelText;
  /// 读数主值与海拔值文字色。
  final Color valueText;
  /// 强调色（方位角值、记录按钮底、导出文字、方向值）。
  final Color accent;
  /// 主按钮上的文字色（浅色为白，深色为深底）。
  final Color recordBtnText;
  /// 次按钮底色（导出）。
  final Color secondaryBtnBg;
  /// 行间分隔线色。
  final Color divider;
  /// 弱化色（删除图标等）。
  final Color muted;

  /// 依据当前主题返回对应色板实例。
  ///
  /// 通用语义色（卡片 / 文字 / 强调 / 次按钮 / 分隔线）统一取自 [AppPalette]，
  /// 使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」两个维度的切换。
  ///
  /// ⚠️ 逐项比对后仍保留原常量的字段（与 [AppPalette] 取值不一致，套用会让
  /// 咖啡色主题出现视觉回归，安全优先）：
  ///   - cardBorder / divider：浅色 #D1CDC4、深色 #48484A，比 AppPalette 的
  ///     描边更深一档，是 Pixso 2:3 稿的既定描边强度；
  ///   - 深色态 titleText / labelText / valueText：本页用 #F2F2F7·#AEAEB2，
  ///     AppPalette 深色为纯白 #FFFFFF·#A1A1AA；
  ///   - 深色态 accent：本页为罗盘暖金 #C8A97E，AppPalette.coffeeDark.accent 是
  ///     #8B5C44（工程已知的深色强调差异）；
  ///   - 深色态 recordBtnText / secondaryBtnBg：暖金底配深字 #1C1C1E、次按钮
  ///     暖棕底 #3D3429，同样与 AppPalette 深色值不同。
  static _PanelPalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      // 深色版：近黑卡片，暖金强调，浅字保证对比度。
      return _PanelPalette(
        cardBg: app.cardBg,
        // 描边 / 分隔线沿用稿面灰阶，AppPalette 深色值更暗更冷，保留原值。
        cardBorder: const Color(0xFF48484A),
        titleText: const Color(0xFFF2F2F7),
        labelText: const Color(0xFFAEAEB2),
        valueText: const Color(0xFFF2F2F7),
        // 深色强调色直接取主题主色：咖啡色下即暖金 #C8A97E（与原设计稿完全一致），
        // 切到蓝色主题后自动变为晴空蓝 #79B8F3，无需在此维护第二组值。
        accent: Theme.of(context).colorScheme.primary,
        recordBtnText: const Color(0xFF1C1C1E),
        secondaryBtnBg: const Color(0xFF3D3429),
        divider: const Color(0xFF48484A),
        muted: app.muted,
      );
    }
    // 浅色版：严格对齐 Pixso 2:3。
    return _PanelPalette(
      cardBg: app.cardBg,
      cardBorder: const Color(0xFFD1CDC4),
      titleText: app.titleText,
      labelText: app.labelText,
      valueText: app.valueText,
      accent: app.accent,
      // 主按钮文字：即强调底上的反色文字。
      recordBtnText: app.accentText,
      secondaryBtnBg: app.secondaryBtnBg,
      divider: const Color(0xFFD1CDC4),
      muted: app.muted,
    );
  }
}
