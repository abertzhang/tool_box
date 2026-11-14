// level_page.dart
//
// 水平仪（Spirit Level）工具页。
// 所属模块：feature/tool（工具箱）· 水平仪子工具。
// 设计稿：Pixso 浅色 186:17 / 深色 202:371（圆型牛眼水平仪 + 管式水平仪
//           + 读数卡 + 锁定/校准按钮 + 测量记录历史）。
//
// 关键依赖：
//   - sensors_plus（加速度计实时采集，换算设备倾斜角度）；
//   - isar_community + level_record（「水平仪表」本地持久化，与 compass/noise 同库）；
//   - flutter_riverpod（订阅 levelRecordsProvider 历史列表）；
//   - flutter_screenutil_plus（按设计稿 393×852 做 .w/.h/.sp 适配）；
//   - intl（DateFormat 历史时间格式化）。
//
// 功能实现：
//   1) 实时倾斜：加速度计 → 垂直角度(Y 轴) / 水平角度(X 轴)，经校准偏移后显示。
//   2) 圆型牛眼水平仪：气泡随二维倾斜在表盘内移动，居中即水平。
//   3) 管式水平仪：横向气泡随水平角度左右移动。
//   4) 读数卡：已校准徽标 + 当前状态（水平/接近水平/倾斜）+ 双轴角度。
//   5) 锁定读数：冻结当前显示值（不再随传感器刷新）。
//   6) 校准水平仪：把当前姿态记为 0° 基准。
//   7) 测量记录：写入「水平仪表」、历史列表查看/删除、保存测量弹窗。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart'; // DateFormat 时间格式化
import 'package:sensors_plus/sensors_plus.dart';

import 'package:tool_box/common/ads/banner_ad_view.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/common/provider/app_settings/save_name_prompt_provider.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/feature/profile/provider/membership_provider.dart';
import 'package:tool_box/feature/tool/data/model/level_record.dart';
import 'package:tool_box/feature/tool/provider/level_records_provider.dart';
import 'package:tool_box/feature/tool/shared/tool_panel_palette.dart';
import 'package:tool_box/feature/tool/shared/tool_share_service.dart';
import 'package:tool_box/l10n/app_localizations.dart';
import 'package:tool_box/router/app_router.dart'; // 全局 routeObserver（感知本页 push/pop 切换全屏）
import 'package:flutter/services.dart'; // SystemChrome（沉浸式全屏）

/// 水平仪页。
///
/// 通过 ConsumerStatefulWidget 订阅 [levelRecordsProvider]，写入/删除后
/// 通过 `ref.invalidate` 刷新历史列表。
class LevelPage extends ConsumerStatefulWidget {
  const LevelPage({super.key});

  @override
  ConsumerState<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends ConsumerState<LevelPage> with RouteAware {
  /// 加速度计数据流订阅，取消即停止采集。
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// 实时水平角度（X 轴，由加速度计换算，单位：度）。
  double _rollX = 0;

  /// 实时垂直角度（Y 轴，由加速度计换算，单位：度）。
  double _pitchY = 0;

  /// 校准基准：记录校准瞬间的原始角度，显示值 = 实时值 - 基准。
  double _calRoll = 0;
  double _calPitch = 0;

  /// 是否已校准（控制读数卡「已校准」徽标）。
  bool _calibrated = false;

  /// 是否锁定读数（锁定后不再随传感器刷新，冻结显示）。
  bool _locked = false;

  /// 历史区「查看全部」开关（多于 3 条时展开）。
  bool _showAll = false;

  /// AppBar 分享按钮的 GlobalKey：仅用于 iPad / Mac 上给分享弹出层提供锚点矩形
  /// （这两类设备弹层是 popover，不指定会从屏幕正中冒出来）。手机上无作用。
  final GlobalKey _shareBtnKey = GlobalKey();

  /// 进入本页：沉浸式全屏，隐藏系统状态栏与导航条，让水平仪表盘占满整个屏幕。
  ///
  /// 水平仪为竖屏工具，此处**只隐藏系统 UI、不改变屏幕朝向**
  /// （与直尺页强制横屏不同），竖屏握持更自然。
  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 离开本页：恢复正常屏幕（[SystemUiMode.edgeToEdge] 为 Flutter 默认模式，
  /// 恢复后续页面正常的状态栏/导航条显示）。
  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void initState() {
    super.initState();
    // 进入即沉浸式全屏（隐藏系统 UI），水平仪表盘占满屏幕。
    _enterFullScreen();
    _startSensors();
  }

  /// 启动加速度计流。
  ///
  /// 用 try/catch 兜住平台异常（如设备无传感器），避免崩溃。
  void _startSensors() {
    try {
      _subscription = accelerometerEventStream().listen(_onSensor);
    } catch (e) {
      // 启动失败（无传感器设备）：保持 0° 显示，不崩溃。
    }
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

  /// 本页之上被 push 了其它页面（本页不可见）→ 恢复系统 UI（退出沉浸式全屏）。
  @override
  void didPushNext() {
    _exitFullScreen();
  }

  /// 覆盖本页的页面被 pop，本页重新可见 → 再次进入沉浸式全屏。
  @override
  void didPopNext() {
    _enterFullScreen();
  }

  /// 收到一次加速度计事件：换算垂直/水平角度，未锁定时刷新显示。
  void _onSensor(AccelerometerEvent event) {
    if (_locked || !mounted) return;
    // 设备平放时 z≈9.8、x≈y≈0 → 角度≈0（水平）。
    // 绕 Y 轴转动 → x 变化（垂直角度）；绕 X 轴转动 → y 变化（水平角度）。
    final double pitch = _toDeg(math.atan2(
      event.x,
      math.sqrt(event.y * event.y + event.z * event.z),
    ));
    final double roll =
        _toDeg(math.atan2(event.y, event.z));
    setState(() {
      _pitchY = pitch.clamp(-90, 90);
      _rollX = roll.clamp(-90, 90);
    });
  }

  /// 弧度转角度。
  double _toDeg(double rad) => rad * 180 / math.pi;

  /// 显示用水平角度（已扣除校准基准）。
  double get _dispRoll => (_rollX - _calRoll).clamp(-90, 90);

  /// 显示用垂直角度（已扣除校准基准）。
  double get _dispPitch => (_pitchY - _calPitch).clamp(-90, 90);

  /// 按最大倾角返回状态键：level / near / tilt。
  String _statusKey() {
    final double m = math.max(_dispRoll.abs(), _dispPitch.abs());
    if (m <= 0.5) return 'level';
    if (m <= 2.0) return 'near';
    return 'tilt';
  }

  /// 角度格式化：带正负号，保留 1 位小数，如 `-0.3°` / `+0.5°`。
  String _formatAngle(double a) {
    final String sign = a >= 0 ? '+' : '-';
    return '$sign${a.abs().toStringAsFixed(1)}°';
  }

  /// 状态对应颜色：水平/接近水平→绿，倾斜→琥珀。
  Color _statusColor(String key, LevelGaugePalette p) =>
      key == 'tilt' ? p.amber : p.green;

  /// 状态文案（水平 / 接近水平 / 倾斜）。
  String _statusText(String key, AppLocalizations l10n) {
    switch (key) {
      case 'level':
        return l10n.levelStatusLevel;
      case 'near':
        return l10n.levelStatusNear;
      default:
        return l10n.levelStatusTilt;
    }
  }

  /// 状态描述文案（用于历史卡片）。
  String _statusDesc(String key, AppLocalizations l10n) {
    switch (key) {
      case 'level':
        return l10n.levelDescLevel;
      case 'near':
        return l10n.levelDescNear;
      default:
        return l10n.levelDescTilt;
    }
  }

  /// 格式化时间：今天 / 昨天 / MM-DD + HH:mm。
  String _formatTime(DateTime dt, AppLocalizations l10n) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime d = DateTime(dt.year, dt.month, dt.day);
    final int diff = today.difference(d).inDays;
    final String hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '${l10n.noiseToday} $hm';
    if (diff == 1) return '${l10n.noiseYesterday} $hm';
    return '${DateFormat('MM-dd').format(dt)} $hm';
  }

  /// 校准水平仪：把当前姿态记为 0° 基准。
  void _calibrate() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // 校准前先取偏差量：用户是在「已经歪了很多」时才想起来校准，
    // 还是刚打开就顺手校准？前者说明应该做「进入即自动校准」。
    // 只上报偏差桶，不上报具体角度值（无分析价值）。
    final double offset = (_rollX.abs() + _pitchY.abs());
    // 必须在 setState **之前**取旧值：setState 后 _calibrated 已恒为 true，
    // 届时再读就永远只能看到「重复校准」。
    final bool wasCalibrated = _calibrated;
    setState(() {
      _calRoll = _rollX;
      _calPitch = _pitchY;
      _calibrated = true;
    });
    AppTrack.log(
      TrackEvents.levelCalibrate,
      params: <String, Object?>{
        'offset_bucket': TrackBuckets.magnitude(offset),
        // 首次校准 vs 重新校准：后者偏高说明校准基准不够稳。
        'repeat': wasCalibrated,
      },
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.levelCalibratedToast)));
  }

  /// 锁定 / 解锁读数切换。
  void _toggleLock() {
    setState(() => _locked = !_locked);
  }

  /// 分享 App 介绍（拉新传播用，不分享当前读数）。
  ///
  /// 走系统面板（iOS UIActivityViewController / Android ACTION_SEND），
  /// 本机装了哪些应用就出现哪些目标（微信、朋友圈、微博、QQ、邮件、信息等），
  /// 不需要接入任何第三方 SDK。
  Future<void> _shareApp() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ToolShareStatus result = await ToolShareService.shareAppIntro(
      context: context,
      tool: 'level',
      // iPad / Mac 上把弹出层锚在分享按钮上；手机无作用（返回 null 时居中弹出）。
      sharePositionOrigin: ToolShareService.originRectOf(_shareBtnKey),
    );

    // 只有面板真的起不来才提示；用户主动取消不给任何反馈（否则很烦）。
    if (result == ToolShareStatus.failed && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.appShareFailed)));
    }
  }

  /// 保存当前测量：弹窗命名（可选）→ 写 Isar → 刷新。
  Future<void> _saveMeasurement() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double vRoll = _dispRoll;
    final double vPitch = _dispPitch;
    final String status = _statusKey();

    // 是否弹命名框由全局开关决定（profile 设置「保存弹框」，默认关闭）。
    // 未就绪（首帧异步读 sp）时用 `?? false` 回落到默认：不弹框、直接存，
    // 即便误判也只是少问一次名称，不会丢数据。
    final bool askName = ref.read(saveNamePromptProvider).value ?? false;

    final LevelRecord record;
    if (askName) {
      final LevelRecord? named = await _showSaveDialog(l10n, vRoll, vPitch, status);
      if (named == null) return; // 用户取消
      record = named;
    } else {
      // 不弹框：记录名取毫秒级时间戳，多条同时保存也不重名，且可按名排序。
      record = LevelRecord(
        name: defaultRecordName(),
        verticalAngle: vPitch,
        horizontalAngle: vRoll,
        status: status,
        createdAt: DateTime.now(),
      );
    }

    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.levelRecords.put(record);
    });

    // 保存埋点：status 区分「找平」与「测斜」两种使用场景；
    // calibrated=false 的比例高，说明校准入口不够明显（用户没校准就存了）。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'level',
        'has_name': record.name?.trim().isNotEmpty ?? false,
        // 本次保存是否经过命名弹窗：用于观察「设置项开启率」与保存转化
        // （弹框路径下若取消率高，说明命名这一步在赶客）。
        'prompt': askName,
        'status': record.status,
        'calibrated': _calibrated,
      },
    );

    ref.invalidate(levelRecordsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.levelSavedToast)));
    }
  }

  /// 命名弹窗（名称可选，留空用默认标题）。
  Future<LevelRecord?> _showSaveDialog(AppLocalizations l10n, double vRoll,
      double vPitch, String status) async {
    final TextEditingController nameCtl = TextEditingController();
    return showDialog<LevelRecord>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.levelRecordTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前角度预览。
                Text(
                  '${l10n.levelVertical}: ${_formatAngle(vPitch)}  ·  '
                  '${l10n.levelHorizontal}: ${_formatAngle(vRoll)}',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: l10n.levelName,
                    hintText: l10n.levelNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.levelCancel),
            ),
            TextButton(
              onPressed: () {
                final String name = nameCtl.text.trim();
                final LevelRecord rec = LevelRecord(
                  name: name.isEmpty ? null : name,
                  verticalAngle: vPitch,
                  horizontalAngle: vRoll,
                  status: status,
                  createdAt: DateTime.now(),
                );
                Navigator.of(ctx).pop(rec);
              },
              child: Text(l10n.levelSaveAction),
            ),
          ],
        );
      },
    );
  }

  /// 删除一条测量记录（带确认弹窗）。
  Future<void> _deleteRecord(LevelRecord r) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.levelDelete),
        content: Text(l10n.levelDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.levelCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.levelDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.levelRecords.delete(r.id);
    });
    final int remaining =
        (ref.read(levelRecordsProvider).value?.length ?? 1) - 1;
    AppTrack.log(
      TrackEvents.toolDataDeleted,
      params: <String, Object?>{
        'tool': 'level',
        'remaining': remaining < 0 ? 0 : remaining,
      },
    );
    ref.invalidate(levelRecordsProvider);
  }

  @override
  void dispose() {
    // 释放传感器流，避免后台持续采集。
    _subscription?.cancel();
    // 取消路由观察订阅，避免泄漏。
    routeObserver.unsubscribe(this);
    // 本页被 pop 移除（不再显示）→ 恢复系统 UI，避免影响后续页面。
    _exitFullScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final LevelGaugePalette gp = LevelGaugePalette.of(context);
    final ToolPanelPalette p = ToolPanelPalette.of(context);
    // 会员状态：决定「Measurements」上方的横幅广告是否入树。
    //
    // 与 tools / noise 两页同口径：VIP 卖点写着 No ads，已买断时**整块不放进树**，
    // 只隐藏不够 —— 摘出树才会触发 AdBannerSlot.dispose() 释放原生广告实例。
    final bool isMember = ref.watch(isMemberProvider);

    final String statusKey = _statusKey();
    final Color statusColor = _statusColor(statusKey, gp);
    final String statusText = _statusText(statusKey, l10n);

    // ★ 不使用 Material AppBar：immersiveSticky 已隐藏系统状态栏/导航条，
    //   再叠一个固定高度的 AppBar 会吃掉顶部空间，水平仪表盘无法占满屏幕。
    //   返回入口与分享按钮改为自定义顶部操作条（见 [_buildTopBar]），
    //   [_shareBtnKey] 仍挂在分享按钮上，供 iPad / Mac 分享弹出层定位锚点。
    return Scaffold(
      backgroundColor: p.pageBg,
      body: SafeArea(
        // 沉浸式全屏下系统 UI 已隐藏，这里仅用 SafeArea 防刘海/圆角遮挡内容顶部；
        // 底部不强制安全区，让滚动内容可贴边（返回/分享按钮已在顶部条内）。
        bottom: false,
        child: Column(
          children: [
            // 自定义顶部操作条：返回 + 居中标题 + 分享。
            _buildTopBar(l10n, p),
            // 主体内容可滚动。
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                child: Column(
                  children: [
                    // 仪表区：圆型牛眼水平仪 + 管式水平仪。
                    _BullseyeLevel(
                      roll: _dispRoll,
                      pitch: _dispPitch,
                      palette: gp,
                      label: l10n.levelBullseye,
                    ),
                    SizedBox(height: 16.h),
                    _TubularLevel(
                      roll: _dispRoll,
                      palette: gp,
                      label: l10n.levelTubular,
                    ),
                    SizedBox(height: 16.h),
                    // 读数卡：已校准徽标 + 当前状态 + 双轴角度。
                    _buildReadingsCard(l10n, p, gp, statusKey, statusColor, statusText),
                    SizedBox(height: 16.h),
                    // 操作按钮：锁定读数 / 校准水平仪。
                    _buildActionButtons(l10n, p, gp, statusColor),
                    SizedBox(height: 24.h),
                    // 横幅广告：位于「Measurements（历史记录）」标题之上。
                    //
                    // 位置理由与噪音页一致：上方两个水平仪 + 读数卡是需要盯着看的核心区，
                    // 广告不能插进去打断操作；历史区上方是内容自然的分段点。
                    // 会员（已买断）时整块不入树：既不请求也不展示，且会 dispose 掉实例。
                    if (!isMember) ...[
                      AdBannerSlot(
                        labelText: l10n.adLabel,
                        slot: 'level_measurements_top',
                        position: BannerPosition.level,
                      ),
                      SizedBox(height: 16.h),
                    ],
                    // 历史记录（英文文案为 Measurements）。
                    _buildHistorySection(l10n, p, gp),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 自定义顶部操作条：返回入口 + 居中标题 + 分享按钮。
  ///
  /// 取代 Material [AppBar]（沉浸式全屏下不需要固定高度的 AppBar，否则会吃掉
  /// 顶部空间），返回/分享交互与 AppBar 一致。
  /// [_shareBtnKey] 仍挂在本条分享按钮上，iPad / Mac 的分享弹出层以它为锚点。
  Widget _buildTopBar(AppLocalizations l10n, ToolPanelPalette p) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 4.h),
      child: Row(
        children: [
          // 返回入口（取代 AppBar 自带的 leading）。
          IconButton(
            icon: Icon(Icons.arrow_back, color: p.titleText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          // 居中标题：用 Expanded + 居中文本，使其在剩余空间内居中
          // （AppBar 的 centerTitle 会额外扣除 leading/actions 宽度，
          // 这里视觉上已足够居中，且避免再引入一条固定高度）。
          Expanded(
            child: Text(
              l10n.levelTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: p.titleText,
              ),
            ),
          ),
          // 分享当前读数（调起系统面板，可到微信 / 微博 / QQ / 邮件等）。
          IconButton(
            key: _shareBtnKey,
            icon: Icon(Icons.share_outlined, color: p.titleText),
            onPressed: _shareApp,
          ),
        ],
      ),
    );
  }

  /// 读数卡：徽标 + 当前状态 + 垂直/水平角度。
  Widget _buildReadingsCard(
      AppLocalizations l10n,
      ToolPanelPalette p,
      LevelGaugePalette gp,
      String statusKey,
      Color statusColor,
      String statusText) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: p.cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
      child: Column(
        children: [
          // 第一行：已校准徽标 + 当前状态。
          Row(children: [
            // 已校准 / 未校准 徽标。
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _calibrated
                    ? gp.green.withValues(alpha: 0.15)
                    : p.muted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _calibrated ? l10n.levelCalibrated : l10n.levelUncalibrated,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: _calibrated ? gp.green : p.muted,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // 当前状态：彩色圆点 + 文案。
            // ⚠️ 必须用 Expanded 占满剩余宽度：水平 Row 的「非 flex child」会收到
            // 宽度无界的约束，内部再放 Flexible(statusText) 会报
            // "non-zero flex but unbounded"（中文长状态文案把行撑爆卡片边界）。
            // Expanded 让本行获得有界宽度，Flexible + ellipsis 才能正常收尾。
            Expanded(
              child: Row(children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(l10n.levelStatusLabel,
                    style: TextStyle(fontSize: 12.sp, color: p.labelText)),
                SizedBox(width: 4.w),
                // 状态文案可能较长，用 Flexible + 省略避免把整行撑破。
                Flexible(
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ]),
          // 行间分隔线。
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            height: 1.h,
            color: p.divider,
          ),
          // 第二行：垂直角度 (Y) / 水平角度 (X)。
          Row(children: [
            Expanded(
              child: ReadingItem(
                label: l10n.levelVertical,
                value: _formatAngle(_dispPitch),
                valueColor: p.valueText,
                valueSize: 18,
                valueWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ReadingItem(
                label: l10n.levelHorizontal,
                value: _formatAngle(_dispRoll),
                valueColor: p.valueText,
                valueSize: 18,
                valueWeight: FontWeight.w800,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// 操作按钮行：锁定读数（次）+ 校准水平仪（主）。
  Widget _buildActionButtons(AppLocalizations l10n, ToolPanelPalette p,
      LevelGaugePalette gp, Color statusColor) {
    // 宽度配比：次按钮 150 : 主按钮 180（合计仍为 330，与 12 间距一起占满整行）。
    // 演进：91 : 239（设计稿）→ 120 : 210 → 150 : 180。
    // 起因是次按钮只有 91 宽，装不下英文「Lock Reading」（图标 18 + 间距 6 +
    // 文本约 90 ≈ 114），在 Row 里直接 RenderFlex 溢出若干像素。
    // 主按钮文案无论中英文都很短（「校准水平仪」约 106 /「Calibrate」约 96，含图标），
    // 故持续从主按钮匀宽度给次按钮。
    // ⚠️ 下限：主按钮低于约 120 时中文「校准水平仪」会开始挤（次按钮此时 210，
    // 也远超其需要的 114），再往下调就得改用「右侧按内容自适应」的排版了。
    return Row(children: [
      // 次按钮：锁定 / 解锁。
      Expanded(
        flex: 150,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _toggleLock,
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
                Icon(_locked ? Icons.lock : Icons.lock_open,
                    size: 18.sp, color: p.accent),
                SizedBox(width: 6.w),
                // 文本兜底：极端语言（如德语长词）即使宽度仍不够，也只截断成
                // 省略号，不会再抛 RenderFlex 溢出；Row 在 Expanded 内宽度有界，
                // 这里的 Flexible 合法（放无界 Row 里会报 non-zero flex）。
                Flexible(
                  child: Text(
                    _locked ? l10n.levelUnlock : l10n.levelLock,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(width: 12.w),
      // 主按钮：校准水平仪（宽度已由 239 → 210 → 180，见上方配比注释）。
      Expanded(
        flex: 180,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _calibrate,
          child: Container(
            height: 51.h,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gps_fixed, size: 18.sp, color: p.recordBtnText),
                SizedBox(width: 8.w),
                Text(
                  l10n.levelCalibrate,
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
    ]);
  }

  /// 历史记录区：标题 + 保存测量 + 查看全部/收起 + 记录卡片。
  Widget _buildHistorySection(
      AppLocalizations l10n, ToolPanelPalette p, LevelGaugePalette gp) {
    final AsyncValue<List<LevelRecord>> recordsAsync =
        ref.watch(levelRecordsProvider);
    final List<LevelRecord> all = recordsAsync.value ?? [];
    final bool hasMore = all.length > 3;
    final List<LevelRecord> visible = _showAll ? all : all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(l10n.levelHistory,
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: p.titleText)),
          const Spacer(),
          // 保存测量：写入「水平仪表」。
          TextButton(
            onPressed: _saveMeasurement,
            child: Text(
              l10n.levelSave,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: p.accent),
            ),
          ),
          if (hasMore)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? l10n.levelCollapse : l10n.levelViewAll,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: p.labelText),
              ),
            ),
        ]),
        SizedBox(height: 12.h),
        recordsAsync.isLoading
            ? HistoryPlaceholder(text: l10n.levelHistory)
            : all.isEmpty
                ? HistoryPlaceholder(text: l10n.levelNoRecords)
                : Column(
                    children: visible
                        .map((r) => _buildHistoryCard(r, l10n, p, gp))
                        .toList(),
                  ),
      ],
    );
  }

  /// 单条历史卡片：名称 + 时间 + 删除；状态标签 + 描述；双轴角度。
  Widget _buildHistoryCard(LevelRecord r, AppLocalizations l10n,
      ToolPanelPalette p, LevelGaugePalette gp) {
    // 本地可空变量承接 Isar 非 final 字段，规避非空断言告警。
    final String? nameVal = r.name;
    final Color tagColor = _statusColor(r.status, gp);
    final String tagText = _statusText(r.status, l10n);
    final String descText = _statusDesc(r.status, l10n);
    // 角度需经本地拷贝后再判空（Isar 字段非 final，Dart 无法提升）。
    final double vRollVal = r.horizontalAngle;
    final double vPitchVal = r.verticalAngle;

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
          Row(children: [
            Expanded(
              child: Text(nameVal ?? l10n.levelDefaultName,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: p.titleText)),
            ),
            Text(_formatTime(r.createdAt, l10n),
                style: TextStyle(fontSize: 12.sp, color: p.labelText)),
            SizedBox(width: 4.w),
            IconButton(
              constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.delete_outline, size: 18.sp, color: p.muted),
              onPressed: () => _deleteRecord(r),
            ),
          ]),
          SizedBox(height: 10.h),
          // 状态标签（彩色芯片）+ 描述。
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(tagText,
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: tagColor)),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(descText,
                  style: TextStyle(fontSize: 12.sp, color: p.labelText)),
            ),
          ]),
          SizedBox(height: 8.h),
          // 双轴角度整行。
          Text(
            '${l10n.levelVertical}: ${_formatAngle(vPitchVal)}   '
            '${l10n.levelHorizontal}: ${_formatAngle(vRollVal)}',
            style: TextStyle(fontSize: 12.sp, color: p.labelText),
          ),
        ],
      ),
    );
  }
}


/// 圆型牛眼水平仪。
///
/// 仪表盘绘制：背景圆 + 同心环 + 十字轴 + 中心靶标 + 随二维倾斜移动的白气泡。
class _BullseyeLevel extends StatelessWidget {
  const _BullseyeLevel({
    required this.roll,
    required this.pitch,
    required this.palette,
    required this.label,
  });

  /// 水平角度（度），驱动气泡横向偏移。
  final double roll;

  /// 垂直角度（度），驱动气泡纵向偏移。
  final double pitch;

  /// 表盘色板（随主题明暗切换）。
  final LevelGaugePalette palette;

  /// 仪表标题（圆型牛眼水平仪）。
  final String label;

  @override
  Widget build(BuildContext context) {
    final ToolPanelPalette p = ToolPanelPalette.of(context);
    const double size = 240;
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 13.sp, color: p.labelText)),
        SizedBox(height: 10.h),
        SizedBox(
          width: size.w,
          height: size.w,
          child: CustomPaint(
            size: Size.square(size.w),
            painter: _BullseyePainter(roll, pitch, palette),
          ),
        ),
      ],
    );
  }
}

/// 圆型牛眼水平仪表盘绘制。
class _BullseyePainter extends CustomPainter {
  _BullseyePainter(this.roll, this.pitch, this.palette);

  final double roll;
  final double pitch;
  final LevelGaugePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset center = Offset(r, r);
    final Paint bg = Paint()..color = palette.dialBg;
    final Paint border = Paint()
      ..color = palette.dialBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.w;
    final Paint ring = Paint()
      ..color = palette.ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5.w;
    final Paint axis = Paint()
      ..color = palette.axis
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.w;
    final Paint target = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.w;
    final Paint bubbleFill = Paint()..color = palette.bubble;
    final Paint bubbleStroke = Paint()
      ..color = palette.bubbleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.w;

    // 背景圆。
    canvas.drawCircle(center, r, bg);
    canvas.drawCircle(center, r, border);

    // 同心环（ring-1）。
    canvas.drawCircle(center, r * 0.7, ring);

    // 十字轴。
    canvas.drawLine(Offset(center.dx - r, center.dy),
        Offset(center.dx + r, center.dy), axis);
    canvas.drawLine(Offset(center.dx, center.dy - r),
        Offset(center.dx, center.dy + r), axis);

    // 中心靶标。
    canvas.drawCircle(center, r * 0.1, target);

    // 气泡：随倾斜移动，限制在环内。
    final double scale = (r * 0.42) / 30.0; // 30° 触达边缘
    double bx = roll * scale;
    double by = -pitch * scale; // 屏幕 y 向下，垂直角度取反
    final double maxOff = r * 0.7 - r * 0.16;
    final double dist = math.sqrt(bx * bx + by * by);
    if (dist > maxOff) {
      bx = bx / dist * maxOff;
      by = by / dist * maxOff;
    }
    final Offset bubbleC = center + Offset(bx, by);
    canvas.drawCircle(bubbleC, r * 0.16, bubbleFill);
    canvas.drawCircle(bubbleC, r * 0.16, bubbleStroke);
  }

  @override
  bool shouldRepaint(covariant _BullseyePainter old) =>
      old.roll != roll || old.pitch != pitch || old.palette != palette;
}

/// 管式水平仪。
///
/// 横向液管：棕底 + 中心靶标线 + 随水平角度左右移动的白气泡。
class _TubularLevel extends StatelessWidget {
  const _TubularLevel({
    required this.roll,
    required this.palette,
    required this.label,
  });

  /// 水平角度（度），驱动气泡左右偏移。
  final double roll;

  final LevelGaugePalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ToolPanelPalette p = ToolPanelPalette.of(context);
    const double w = 320;
    const double h = 64;
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 13.sp, color: p.labelText)),
        SizedBox(height: 10.h),
        SizedBox(
          width: w.w,
          height: h.w,
          child: CustomPaint(
            size: Size(w.w, h.w),
            painter: _TubularPainter(roll, palette),
          ),
        ),
      ],
    );
  }
}

/// 管式水平仪绘制。
class _TubularPainter extends CustomPainter {
  _TubularPainter(this.roll, this.palette);

  final double roll;
  final LevelGaugePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double radius = h / 2;
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius),
    );
    final Paint liquid = Paint()..color = palette.liquid;
    final Paint border = Paint()
      ..color = palette.dialBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.w;
    final Paint target = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5.w;
    final Paint bubbleFill = Paint()..color = palette.bubble;
    final Paint bubbleStroke = Paint()
      ..color = palette.bubbleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.w;

    // 液管主体（棕底）。
    canvas.drawRRect(body, liquid);
    canvas.drawRRect(body, border);

    // 中心靶标线（两条短竖线标示水平位置）。
    final double cx = w / 2;
    canvas.drawLine(Offset(cx, h * 0.2), Offset(cx, h * 0.8), target);
    canvas.drawLine(Offset(cx - 10.w, h * 0.5),
        Offset(cx + 10.w, h * 0.5), target);

    // 气泡：随水平角度左右移动，限制在管内。
    final double maxX = (w / 2) * 0.82;
    final double scale = maxX / 30.0; // 30° 触达边缘
    double dx = (roll * scale).clamp(-maxX, maxX);
    final Offset bubbleC = Offset(cx + dx, h / 2);
    final double br = h * 0.32;
    canvas.drawCircle(bubbleC, br, bubbleFill);
    canvas.drawCircle(bubbleC, br, bubbleStroke);
  }

  @override
  bool shouldRepaint(covariant _TubularPainter old) =>
      old.roll != roll || old.palette != palette;
}

/// 水平仪表盘双主题色板（表盘 / 气泡 / 液体 / 轴）。
///
/// 与 NoiseGaugePalette 同理：深浅两版逐项硬编码。
class LevelGaugePalette {
  const LevelGaugePalette({
    required this.dialBg,
    required this.dialBorder,
    required this.liquid,
    required this.bubble,
    required this.bubbleStroke,
    required this.axis,
    required this.ring,
    required this.accent,
    required this.green,
    required this.amber,
  });

  /// 表盘背景色。
  final Color dialBg;

  /// 表盘描边色。
  final Color dialBorder;

  /// 管式液管液体色（棕）。
  final Color liquid;

  /// 气泡填充色（白）。
  final Color bubble;

  /// 气泡描边色（棕）。
  final Color bubbleStroke;

  /// 十字轴颜色。
  final Color axis;

  /// 同心环颜色。
  final Color ring;

  /// 强调色（靶标 / 校准）。
  final Color accent;

  /// 水平/接近水平状态色（绿）。
  final Color green;

  /// 倾斜状态色（琥珀）。
  final Color amber;

  /// 根据当前主题返回对应色板实例。
  ///
  /// 表盘容器相关的通用语义色（[dialBg] / [dialBorder]）与强调色（[accent]，用于靶标、
  /// 校准标记）取自 [AppPalette]，使其同时响应「主题色方案（咖啡色 / 蓝色）」与
  /// 「明暗模式」两个维度的切换；咖啡色下的取值与此处原硬编码逐项一致。
  ///
  /// ⚠️ 以下字段属**仪表专用固定语义色**，不随主题变化，保留常量：
  /// - [liquid] / [bubble] / [bubbleStroke]：管式水平仪的「液体 + 气泡」是物理拟物表达，
  ///   棕色液体与白色气泡是行业通用认知，换成主题色会丧失可读性；
  /// - [axis] / [ring]：十字轴与同心环是表盘刻度线条，且两分支原值在 [AppPalette] 中
  ///   没有统一的语义对应（深色 ring=页面底色、浅色 ring=分隔线），套用任一都会
  ///   造成咖啡色主题下回归，故保留；
  /// - [green] / [amber]：水平 / 倾斜状态色，属状态语义（安全 / 警告），与主题色无关。
  static LevelGaugePalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return LevelGaugePalette(
        // 深色下「表盘」是浮在页面之上的一块深色卡片，取卡片底色。
        dialBg: app.cardBg,
        dialBorder: app.cardBorder,
        liquid: const Color(0xFF8B5C44),
        bubble: const Color(0xFFFFFFFF),
        bubbleStroke: const Color(0xFF8B5C44),
        axis: const Color(0xFFA1A1AA),
        ring: const Color(0xFF1C1C1E),
        accent: app.accent,
        green: const Color(0xFF5C7A54),
        amber: const Color(0xFFD29137),
      );
    }
    return LevelGaugePalette(
      // 浅色下「表盘」与页面底色同色（靠描边与同心环区分层次），取页面底色。
      dialBg: app.pageBg,
      dialBorder: app.cardBorder,
      liquid: const Color(0xFF8B5C44),
      bubble: const Color(0xFFFFFFFF),
      bubbleStroke: const Color(0xFF8B5C44),
      axis: const Color(0xFF7A746B),
      ring: const Color(0xFFE4E0D9),
      accent: app.accent,
      green: const Color(0xFF5C7A54),
      amber: const Color(0xFFD29137),
    );
  }
}
