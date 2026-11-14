// noise_page.dart
//
// 噪音检测器页面（feature/tool 子工具）。
// 设计稿：Pixso 184:8（浅色）/ 202:267（深色）。
// 关键依赖：noise_meter（麦克风实时分贝）、permission_handler（麦克风权限）、
//           isar_service + noise_record（「噪音表」本地持久化）、
//           noise_records_provider（历史列表）、flutter_screenutil_plus（尺寸）。
//
// 页面结构（自上而下，与设计稿一一对应）：
//   1. 导航头：返回 + 标题「噪音检测器」+ 分享（占位）；
//   2. 噪音表盘：实时 dB 大数字 + 分区（安静/适中/嘈杂）彩色弧 + 指针；
//   3. 读数卡：当前 / 平均 / 最低 / 最高 四宫格；
//   4. 操作按钮：记录当前噪音（主）+ 导出（次）；
//   5. 历史记录：来自「噪音表」，可查看全部 / 删除。
//
// 设计要点：
//   - 实时读数来自 noise_meter 的 meanDecibel 流；指针/弧按 0~120 dB 钳制；
//   - 分区阈值：安静 0~50、适中 50~90、嘈杂 >90（与设计稿 scale-legends 一致）；
//   - 录音后把「当前 dB + 自动分区 + 命名 + 环境类型」写入 Isar「噪音表」。

import 'dart:async';
import 'dart:math' as math;

import 'dart:io'; // Platform.isIOS（iOS 权限只能通过设置页挽回）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard 剪贴板
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:intl/intl.dart'; // DateFormat 时间格式化
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:tool_box/common/ads/banner_ad_view.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/common/provider/app_settings/save_name_prompt_provider.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/feature/profile/provider/membership_provider.dart';
import 'package:tool_box/feature/tool/data/model/noise_record.dart';
import 'package:tool_box/feature/tool/provider/noise_records_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 噪音检测器页面。
///
/// 通过 ConsumerStatefulWidget 订阅 [noiseRecordsProvider]，写入/删除后
/// 调用 `ref.invalidate` 即时刷新历史列表。
class NoisePage extends ConsumerStatefulWidget {
  /// 创建噪音检测器页面。
  const NoisePage({super.key});

  @override
  ConsumerState<NoisePage> createState() => _NoisePageState();
}

class _NoisePageState extends ConsumerState<NoisePage>
    with WidgetsBindingObserver {
  /// 权限申请时机标记：进页即自动申请。
  static const String _kPermissionTriggerPageOpen = 'page_open';

  /// 权限申请时机标记：用户点引导卡按钮才申请。
  static const String _kPermissionTriggerRecord = 'record';

  /// 权限申请时机标记：点「打开设置」/ 从系统设置返回后的复查。
  static const String _kPermissionTriggerOpenSettings = 'open_settings';

  /// 麦克风数据流订阅，取消即停止采集。
  StreamSubscription<NoiseReading>? _subscription;

  /// 麦克风权限被拒（可重试）时置 true，用于展示不可用提示。
  bool _micDenied = false;

  /// 麦克风权限被「永久拒绝」（用户在系统弹窗点了不再询问）时置 true。
  /// 此时 request() 不会再弹窗，必须引导用户去系统设置开启。
  bool _micPermanentlyDenied = false;

  /// 实时当前分贝（来自 meanDecibel）；未读数前为 null。
  double? _currentDb;

  /// 运行期统计：最低 / 最高 / 平均（平均用累加均值）。
  double? _minDb;
  double? _maxDb;
  double? _avgDb;
  double _sum = 0;
  int _count = 0;

  /// 历史区「查看全部」开关（多于 3 条时展开）。
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // 进页即申请麦克风权限（与 compass 页定位权限同口径）。
    //
    // ⚠️ 必须延到**首帧渲染之后**再弹：initState 阶段系统授权弹窗往往还没挂上，
    //    直接与页面构建抢帧会出现「弹窗不显示 / 闪一下就没」的问题。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestMicOnEnter();
    });
    // 监听前后台：从「系统设置」返回时复查麦克风权限。
    WidgetsBinding.instance.addObserver(this);
  }

  /// 应用生命周期变化：从系统设置返回时复查麦克风权限。
  ///
  /// `openAppSettings()` 只是把设置页拉起来就立即返回，**不会等用户操作完**，
  /// 所以不能在它后面直接查状态（那时用户还没授权）。真正的复查必须放在这里：
  /// 用户切回 App 时若已在设置里开启，立即开始采集并撤掉引导卡。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (!_micDenied && !_micPermanentlyDenied) return;
    final PermissionStatus status = await Permission.microphone.status;
    if (!mounted) return;
    _logMicPermission(
      granted: status.isGranted,
      permanentlyDenied: status.isPermanentlyDenied,
      trigger: _kPermissionTriggerOpenSettings,
    );
    if (!status.isGranted) return;
    setState(() {
      _micDenied = false;
      _micPermanentlyDenied = false;
    });
    _startListening();
  }

  /// 该状态是否「只能靠系统设置页挽回」。
  ///
  /// - **Android**：仅 `permanentlyDenied`（用户勾了「不再询问」）需要跳设置；
  ///   普通 `denied` 下次 `request()` 仍会弹系统框，留在引导卡重试即可。
  /// - **iOS**：系统授权框**每个权限一生只弹一次**，用户拒绝后 `request()` 不再弹框、
  ///   直接回调 denied/permanentlyDenied —— 所以 iOS 下只要「申请后仍未授权」
  ///   就等同只能去设置，此时再给「重试」按钮是无效入口（点了必然失败）。
  ///
  /// 不直接用 `status.isPermanentlyDenied` 是因为它在 iOS 各版本/插件版本上
  /// 映射不一致（有时返回普通 denied），这里显式补一层平台判定更稳。
  bool _isSettingsOnly(PermissionStatus status) {
    if (status.isPermanentlyDenied) return true;
    return Platform.isIOS && !status.isGranted;
  }

  /// 进入页面即申请麦克风权限：已授权直接采集，未授权弹系统授权框。
  ///
  /// 与 compass 页定位权限保持同一套交互口径：
  ///   - 已授权 → 直接开始采集，且**不上报**埋点（没有产生申请动作，报了会把
  ///     granted 数据口径搅浑）；
  ///   - 未决定 / 普通拒绝 → `request()` 真弹系统框（只有这两种状态会弹，
  ///     已授权或已永久拒绝都不会再弹，重复进页不会骚扰用户）；
  ///   - 结果仍不通过 → 切到引导态，卡片上提供「授权」与「打开设置」两个入口。
  ///
  /// 注意：底层 [audio_streamer] 不会自行申请权限，必须由本页显式申请。
  Future<void> _requestMicOnEnter() async {
    PermissionStatus status = await Permission.microphone.status;
    if (!mounted) return;
    if (status.isGranted) {
      _startListening();
      return;
    }
    status = await Permission.microphone.request();
    if (!mounted) return;
    // iOS 上「申请后仍未授权」= 系统框已弹过且被拒，只能去设置页挽回。
    final bool needsSettings = _isSettingsOnly(status);
    _logMicPermission(
      granted: status.isGranted,
      permanentlyDenied: needsSettings,
      trigger: _kPermissionTriggerPageOpen,
    );
    if (status.isGranted) {
      setState(() {
        _micDenied = false;
        _micPermanentlyDenied = false;
      });
      _startListening();
      return;
    }
    // 区分「只能去设置」：此时 request() 不会再弹窗，主按钮改成「打开设置」。
    setState(() {
      _micDenied = !needsSettings;
      _micPermanentlyDenied = needsSettings;
    });
    // iOS 拒绝后直接把系统设置页拉起来：既然系统授权框不会再弹，这是唯一
    // 能继续的路径，帮用户省一次点击。Android 保持停在引导卡（它还能再弹框）。
    // ⚠️ openAppSettings() 只是拉起设置页就返回，结果由 didChangeAppLifecycleState
    //    在用户切回 App 时复查。
    if (needsSettings) await _openMicSettings();
  }

  /// 上报麦克风权限申请结果。
  ///
  /// 与指南针的 [_logLocationPermission] 同理：失败分支散落在
  /// `_retryMic` 多处，收口成一个方法才不会漏埋。
  ///
  /// 只在**真正申请过**（request() 或从系统设置返回复查）后调用；
  /// 进页面静默检查 [_checkMicrophone] 不算申请，不上报。
  /// 区分 `permanently_denied` 是因为它只能靠跳系统设置挽回，
  /// 需要在弹窗里前置说明才能降低发生率。
  void _logMicPermission({
    required bool granted,
    required bool permanentlyDenied,
    required String trigger,
  }) {
    AppTrack.log(
      TrackEvents.toolPermissionResult,
      params: <String, Object?>{
        'tool': 'noise',
        'permission': 'microphone',
        'granted': granted,
        'permanently_denied': permanentlyDenied,
        // 与 compass 页同口径（`page_open` / `record` / `open_settings`），
        // 便于横向对比两个工具、两种时机的授权率。
        'trigger': trigger,
      },
    );
  }

  /// 引导卡主按钮：普通拒绝 → 重新申请；永久拒绝 → 跳系统设置。
  ///
  /// 首次申请已挪到进页（[_requestMicOnEnter]），这里承担的是**被拒后的重试**：
  /// 用户点按钮代表「我现在确实要测」，此时再弹一次系统框才不突兀。
  Future<void> _retryMic() async {
    if (_micPermanentlyDenied) {
      await _openMicSettings();
      return;
    }
    // 普通拒绝分支：重新申请。
    final PermissionStatus status = await Permission.microphone.request();
    if (!mounted) return;
    // 同 [_requestMicOnEnter]：iOS 下只要仍未授权就是「只能去设置」。
    final bool needsSettings = _isSettingsOnly(status);
    _logMicPermission(
      granted: status.isGranted,
      permanentlyDenied: needsSettings,
      trigger: _kPermissionTriggerRecord,
    );
    if (status.isGranted) {
      setState(() {
        _micDenied = false;
        _micPermanentlyDenied = false;
      });
      _startListening();
      return;
    }
    // 这次之后系统不再弹框：把主按钮切换成「打开设置」。
    setState(() {
      _micDenied = !needsSettings;
      _micPermanentlyDenied = needsSettings;
    });
    // iOS：直接拉起系统设置（重试已无意义），Android 停在引导卡等用户再点。
    if (needsSettings) await _openMicSettings();
  }

  /// 打开系统设置页，让用户手动开启麦克风权限。
  ///
  /// ⚠️ `openAppSettings()` 只是把设置页拉起来就返回，**不会等用户操作**，
  ///    所以这里**不查**状态 —— 真正的复查在 [didChangeAppLifecycleState] 的
  ///    resumed 分支（用户切回 App 时才判定）。
  /// 失败（平台不支持 / 插件异常）只上报，不提示：静默失败不影响其他功能。
  Future<void> _openMicSettings() async {
    try {
      await openAppSettings();
      AppTrack.log(
        TrackEvents.toolPermissionResult,
        params: <String, Object?>{
          'tool': 'noise',
          'permission': 'microphone',
          'granted': false,
          'permanently_denied': true,
          'trigger': _kPermissionTriggerOpenSettings,
        },
      );
    } catch (e, s) {
      AppTrack.error('noise_open_settings', e, s);
    }
  }

  /// 启动麦克风分贝流。
  ///
  /// 用 try/catch 兜住平台异常（如其他录音应用占用、无麦克风设备），避免崩溃。
  void _startListening() {
    try {
      _subscription = NoiseMeter().noise.listen(
        _onReading,
        onError: (_) {
          // 采集异常（权限被收回 / 被通话或其他录音应用打断 / 无麦克风）：
          // 进入可重试的不可用态，而不是静默卡在「—」。
          if (mounted) {
            setState(() {
              _currentDb = null;
              _micDenied = true;
              _micPermanentlyDenied = false;
            });
          }
        },
      );
    } catch (e) {
      // 启动失败（如设备无麦克风）：进入不可用态。
      if (mounted) {
        setState(() {
          _micDenied = true;
          _micPermanentlyDenied = false;
        });
      }
    }
  }

  /// 收到一次分贝读数：更新当前值并累加统计。
  ///
  /// ⚠️ 非有限值（NaN / ±Infinity）必须单独处理（2026-09-14 修复）：
  /// 原生层按 `20 * log10(振幅)` 计算分贝，环境静音或音量极低时振幅为 0，
  /// `log10(0)` 得到 **-Infinity**；麦克风尚未就绪时也可能给出 NaN。
  /// 这类值一旦进入统计就会**永久污染、再也恢复不了**：
  ///   - [_minDb] 取最小后永远停在 -inf（后续任何正常分贝都比它大），显示被 [_clamp] 夹成 0；
  ///   - [_sum] 累加 -inf 后恒为 -inf，`_avgDb = _sum / _count` 也恒为 -inf，同样显示 0；
  /// 而 [_maxDb]（取最大，会忽略 -inf）与 [_currentDb]（每次被新值覆盖）看起来完全正常，
  /// 于是表现为「Average / Min 长期显示 0 或 —，只有 Current / Max 有数值」。
  /// 处理原则：无效读数只把当前值按静音（0 dB）展示，**不进入任何统计**。
  void _onReading(NoiseReading reading) {
    if (!mounted) return;
    final double v = reading.meanDecibel;
    // 丢弃 -inf / +inf / NaN：不计入 min / max / avg，避免不可逆污染。
    if (!v.isFinite) {
      setState(() {
        // 静音时按展示区间下限 0 dB 呈现（语义即「几乎没有声音」）。
        _currentDb = 0;
      });
      return;
    }
    setState(() {
      _currentDb = v;
      _minDb = _minDb == null ? v : math.min(_minDb!, v);
      _maxDb = _maxDb == null ? v : math.max(_maxDb!, v);
      _sum += v;
      _count += 1;
      _avgDb = _sum / _count;
    });
  }

  /// 把任意分贝值钳制到 0~120 展示区间。
  ///
  /// 非有限值（NaN / ±Infinity）统一按下限 0 处理，原因有二：
  ///   1. `double.clamp` 对 NaN 会返回**上限**（实测 `nan.clamp(0, 120) == 120`），
  ///      会把「无读数」误显示成满量程 120 dB；
  ///   2. NaN / Infinity 调 `round()` 直接抛 `Unsupported operation: Infinity or NaN toInt`。
  /// 这里先挡一层，保证展示层永远不会因为异常读数而崩溃或显示假峰值。
  double _clamp(double db) {
    if (!db.isFinite) return 0;
    return db.clamp(0, 120);
  }

  /// 按分贝返回分区键：quiet / moderate / loud。
  String _zoneKey(double db) {
    if (db > 90) return 'loud';
    if (db >= 50) return 'moderate';
    return 'quiet';
  }

  /// 表盘中心分区文案（安静环境 / 适中环境 / 嘈杂环境）。
  String _zoneEnvLabel(double db, AppLocalizations l10n) {
    switch (_zoneKey(db)) {
      case 'loud':
        return l10n.noiseZoneLoudEnv;
      case 'moderate':
        return l10n.noiseZoneModerateEnv;
      default:
        return l10n.noiseZoneQuietEnv;
    }
  }

  /// 历史卡片分区标签（安静 / 正常 / 嘈杂）。
  String _catLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'loud':
        return l10n.noiseCatLoud;
      case 'moderate':
        return l10n.noiseCatModerate;
      default:
        return l10n.noiseCatQuiet;
    }
  }

  /// 分区分区颜色（与设计稿 zone 色一致）。
  Color _zoneColor(String key, NoiseGaugePalette p) {
    switch (key) {
      case 'loud':
        return p.loud;
      case 'moderate':
        return p.moderate;
      default:
        return p.quiet;
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

  /// 记录当前噪音：校验有读数 → 弹窗命名 + 环境类型 → 写 Isar → 刷新。
  Future<void> _recordCurrentNoise() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double? db = _currentDb;
    if (db == null) {
      // 尚无实时读数，提示用户稍候。
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noiseNoReading)));
      return;
    }
    // 是否弹命名框由全局开关决定（profile 设置「保存弹框」，默认关闭）。
    // 未就绪（首帧异步读 sp）时 `?? false` 回落不弹框，直接存、不丢数据。
    final bool askName = ref.read(saveNamePromptProvider).value ?? false;

    final NoiseRecord record;
    if (askName) {
      // 弹窗收集名称与环境类型，返回构造好的记录（取消为 null）。
      final NoiseRecord? named = await _showRecordDialog(l10n, db);
      if (named == null) return; // 用户取消或名称为空
      record = named;
    } else {
      // 不弹框：名称取毫秒时间戳，环境类型无法询问故留空（历史列表可后续编辑）。
      final double clamped = _clamp(db);
      record = NoiseRecord(
        name: defaultRecordName(),
        levelDb: clamped,
        category: _zoneKey(clamped),
        environmentType: null,
        createdAt: DateTime.now(),
      );
    }

    // 写入「噪音表」，再令 Provider 失效以刷新历史列表。
    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.noiseRecords.put(record);
    });

    // 保存埋点：db_bucket 记录用户真实所处的环境分布，
    // 用于指导默认量程区间与「嘈杂告警」阈值定在多少合适。
    // 只上传分贝桶不上传原值 —— 分贝序列配合时间戳有可能反推用户所在场所。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'noise',
        'has_name': record.name.trim().isNotEmpty,
        // 本次是否经过命名弹窗（受全局开关控制），与 level / compass 同口径。
        'prompt': askName,
        'has_env': record.environmentType?.isNotEmpty ?? false,
        'db_bucket': TrackBuckets.decibel(record.levelDb),
      },
    );

    ref.invalidate(noiseRecordsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noiseSaved)));
    }
  }

  /// 命名弹窗：名称（必填）+ 环境类型（可选），附带当前读数与分区预览。
  Future<NoiseRecord?> _showRecordDialog(
      AppLocalizations l10n, double db) async {
    final TextEditingController nameCtl = TextEditingController();
    final TextEditingController envCtl = TextEditingController();
    final double clamped = _clamp(db);
    final String zone = _zoneEnvLabel(clamped, l10n);

    return showDialog<NoiseRecord>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.noiseRecordTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前读数预览：分贝 + 分区。
                Text(
                  '${l10n.noiseLevel}: ${clamped.round()} ${l10n.noiseDbUnit} · $zone',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: l10n.noiseName,
                    hintText: l10n.noiseNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: envCtl,
                  decoration: InputDecoration(
                    labelText: l10n.noiseEnvType,
                    hintText: l10n.noiseEnvHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.noiseCancel),
            ),
            TextButton(
              onPressed: () {
                final String name = nameCtl.text.trim();
                if (name.isEmpty) return; // 名称必填，空名不关闭
                // 构造记录：分区按分贝自动判定，时间取当前。
                final NoiseRecord rec = NoiseRecord(
                  name: name,
                  levelDb: clamped,
                  category: _zoneKey(clamped),
                  environmentType:
                      envCtl.text.trim().isEmpty ? null : envCtl.text.trim(),
                  createdAt: DateTime.now(),
                );
                Navigator.of(ctx).pop(rec);
              },
              child: Text(l10n.noiseSave),
            ),
          ],
        );
      },
    );
  }

  /// 导出历史记录为 TSV 并写入剪贴板。
  Future<void> _exportRecords(List<NoiseRecord> list) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final StringBuffer buf = StringBuffer();
    // 表头行。
    buf.writeln(
        '${l10n.noiseName}\t${l10n.noiseLevel}(${l10n.noiseDbUnit})\t'
        '${l10n.noiseEnvType}\t${l10n.noiseHistory}');
    for (final NoiseRecord r in list) {
      buf.writeln(
          '${r.name}\t${r.levelDb.toStringAsFixed(1)}\t'
          '${_catLabel(r.category, l10n)}\t'
          '${r.environmentType ?? ''}\t'
          '${_formatTime(r.createdAt, l10n)}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    // 导出埋点：与指南针同为「重度用户信号」，count 反映单人数据规模。
    AppTrack.log(
      TrackEvents.toolExport,
      params: <String, Object?>{'tool': 'noise', 'count': list.length},
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noiseExported)));
    }
  }

  /// 删除一条记录（带确认弹窗）。
  Future<void> _deleteRecord(NoiseRecord r) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.noiseDelete),
        content: Text(l10n.noiseDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.noiseCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.noiseDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 从「噪音表」删除并刷新列表。
    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.noiseRecords.delete(r.id);
    });
    final int remaining =
        (ref.read(noiseRecordsProvider).value?.length ?? 1) - 1;
    AppTrack.log(
      TrackEvents.toolDataDeleted,
      params: <String, Object?>{
        'tool': 'noise',
        'remaining': remaining < 0 ? 0 : remaining,
      },
    );
    ref.invalidate(noiseRecordsProvider);
  }

  @override
  void dispose() {
    // 释放麦克风流，避免后台持续采集。
    _subscription?.cancel();
    // 必须反注册，否则页面销毁后生命周期回调仍会触发（持有已卸载的 State）。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final NoiseGaugePalette gp = NoiseGaugePalette.of(context);
    final _PanelPalette p = _PanelPalette.of(context);
    // 会员状态：决定「历史记录」上方的横幅广告是否入树。
    //
    // 与 tools 页同口径：VIP 卖点写着 No ads，所以已买断时**整块不放进树**，
    // 只隐藏是不够的 —— 摘出树才会触发 AdBannerSlot.dispose() 释放原生广告实例。
    // 由页面持有会员状态、广告组件保持通用（不感知会员体系）。
    final bool isMember = ref.watch(isMemberProvider);

    // 麦克风不可用（未授权 / 被拒 / 永久拒绝）：表盘换成引导卡，并收起读数与操作区。
    // 收口成一个布尔量，避免「永久拒绝时 _micDenied 为 false」导致下面几处
    // 仍渲染出空读数卡的漏判（原逻辑只判断 _micDenied）。
    final bool micUnavailable = _micDenied || _micPermanentlyDenied;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        backgroundColor: p.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.titleText),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.noiseTitle,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: p.titleText)),
        centerTitle: true,
        actions: [
          // 分享占位按钮（设计稿 share-2 图标）。
          IconButton(
            icon: Icon(Icons.share_outlined, color: p.titleText),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            children: [
              // 表盘：未授权 / 不可用时换成引导卡，提供授权入口。
              if (micUnavailable)
                _UnavailableView(
                  message: _micPermanentlyDenied
                      ? l10n.noiseMicDenied
                      : l10n.noiseMicNeedPermission,
                  actionLabel: _micPermanentlyDenied
                      ? l10n.noiseMicOpenSettings
                      : l10n.noiseMicGrant,
                  palette: gp,
                  permanentlyDenied: _micPermanentlyDenied,
                  onRetry: _retryMic,
                  // 普通拒绝时主按钮是「授权」，额外给一个「打开设置」入口：
                  // 有的用户不想再看到系统弹窗，只想自己去设置里开。
                  // 永久拒绝时主按钮本身就是「打开设置」，不再重复显示。
                  onOpenSettings: _micPermanentlyDenied ? null : _openMicSettings,
                )
              else
                _NoiseGauge(db: _currentDb, palette: gp),
              SizedBox(height: 8.h),
              // 分区图例（安静 / 适中 / 嘈杂）。
              if (!micUnavailable) _buildZoneLegends(l10n, gp),
              SizedBox(height: 16.h),
              // 读数卡：当前 / 平均 / 最低 / 最高。
              if (!micUnavailable) _buildReadingsCard(l10n, p),
              SizedBox(height: 16.h),
              // 操作按钮：记录 + 导出。
              if (!micUnavailable) _buildActionButtons(l10n, p),
              SizedBox(height: 24.h),
              // 横幅广告：位于「历史记录」标题之上。
              //
              // 为什么放这里而不是页面最底部：
              //   1) 表盘 + 读数卡是核心功能区，广告不能插在它们中间打断操作流；
              //   2) 历史区上方是内容自然的分段点，广告在此处既可见又不挡主功能；
              //   3) 与 tools 页不同，本页是二级页面、没有底部 Tab，
              //      不存在「紧贴高频点击区易误触」的违规风险。
              // 会员（已买断）时整块不入树：既不请求也不展示，且会 dispose 掉实例。
              if (!isMember) ...[
                AdBannerSlot(
                  labelText: l10n.adLabel,
                  slot: 'noise_history_top',
                  position: BannerPosition.noise,
                ),
                SizedBox(height: 16.h),
              ],
              // 历史记录。
              _buildHistorySection(l10n, p, gp),
            ],
          ),
        ),
      ),
    );
  }

  /// 分区图例：三个色点 + 区间文案。
  Widget _buildZoneLegends(AppLocalizations l10n, NoiseGaugePalette gp) {
    Widget legend(String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: 4.w),
            Text(label,
                style: TextStyle(fontSize: 12.sp, color: gp.subText)),
          ],
        );
    // 三个图例标签英文下较长，Row 居中横排会超出屏宽导致横向溢出；
    // 改用 Wrap 居中换行，窄屏自动折行而非溢出。
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14.w,
      runSpacing: 8.w,
      children: [
        legend('${l10n.noiseZoneQuiet} (0-50)', gp.quiet),
        legend('${l10n.noiseZoneModerate} (50-90)', gp.moderate),
        legend('${l10n.noiseZoneLoud} (>90)', gp.loud),
      ],
    );
  }

  /// 读数卡：四宫格（当前 / 平均 / 最低 / 最高）。
  Widget _buildReadingsCard(AppLocalizations l10n, _PanelPalette p) {
    // 以本地可空变量承接，避免对可能为 null 的字段误用非空断言。
    final double? cur = _currentDb;
    final double? avg = _avgDb;
    final double? min = _minDb;
    final double? max = _maxDb;
    final String curText = cur != null ? '${_clamp(cur).round()}' : '—';
    final String avgText = avg != null ? '${_clamp(avg).round()}' : '—';
    final String minText = min != null ? '${_clamp(min).round()}' : '—';
    final String maxText = max != null ? '${_clamp(max).round()}' : '—';

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
          // 第一行：当前 / 平均。
          Row(children: [
            Expanded(
              child: ReadingItem(
                label: l10n.noiseCurrent,
                value: '$curText ${l10n.noiseDbUnit}',
                valueColor: p.accent,
                valueSize: 18,
                valueWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ReadingItem(
                label: l10n.noiseAverage,
                value: '$avgText ${l10n.noiseDbUnit}',
                valueColor: p.valueText,
                valueSize: 16,
                valueWeight: FontWeight.w700,
              ),
            ),
          ]),
          // 行间分隔线。
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            height: 1.h,
            color: p.divider,
          ),
          // 第二行：最低 / 最高。
          Row(children: [
            Expanded(
              child: ReadingItem(
                label: l10n.noiseMin,
                value: '$minText ${l10n.noiseDbUnit}',
                valueColor: p.valueText,
                valueSize: 16,
                valueWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ReadingItem(
                label: l10n.noiseMax,
                value: '$maxText ${l10n.noiseDbUnit}',
                valueColor: p.valueText,
                valueSize: 16,
                valueWeight: FontWeight.w700,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// 操作按钮行：主按钮「记录当前噪音」+ 次按钮「导出」。
  Widget _buildActionButtons(AppLocalizations l10n, _PanelPalette p) {
    return Row(children: [
      // 主按钮：占较大比例，填充强调色。
      Expanded(
        flex: 239,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: _recordCurrentNoise,
          child: Container(
            height: 51.h,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, size: 18.sp, color: p.recordBtnText),
                SizedBox(width: 8.w),
                Text(
                  l10n.noiseRecord,
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
      // 次按钮：占较小比例，浅底强调字。
      Expanded(
        flex: 91,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () {
            final List<NoiseRecord> list =
                ref.read(noiseRecordsProvider).value ?? [];
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
                  l10n.noiseExport,
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
    ]);
  }

  /// 历史记录区：标题 + 查看全部/收起 + 记录卡片（来自「噪音表」）。
  Widget _buildHistorySection(
      AppLocalizations l10n, _PanelPalette p, NoiseGaugePalette gp) {
    final AsyncValue<List<NoiseRecord>> recordsAsync =
        ref.watch(noiseRecordsProvider);
    final List<NoiseRecord> all = recordsAsync.value ?? [];
    final bool hasMore = all.length > 3;
    final List<NoiseRecord> visible =
        _showAll ? all : all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(l10n.noiseHistory,
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: p.titleText)),
          const Spacer(),
          if (hasMore)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? l10n.noiseCollapse : l10n.noiseViewAll,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: p.labelText),
              ),
            ),
        ]),
        SizedBox(height: 12.h),
        recordsAsync.isLoading
            ? HistoryPlaceholder(text: l10n.noiseHistory)
            : all.isEmpty
                ? HistoryPlaceholder(text: l10n.noiseNoRecords)
                : Column(
                    children: visible
                        .map((r) => _buildHistoryCard(r, l10n, p, gp))
                        .toList(),
                  ),
      ],
    );
  }

  /// 单条历史卡片：名称 + 时间 + 删除；分区 + 环境类型；噪音值。
  Widget _buildHistoryCard(NoiseRecord r, AppLocalizations l10n,
      _PanelPalette p, NoiseGaugePalette gp) {
    // 本地可空变量承接 Isar 非 final 字段，规避非空断言告警。
    final String? envVal = r.environmentType;
    final Color catColor = _zoneColor(r.category, gp);
    final String catText = _catLabel(r.category, l10n);

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
              child: Text(r.name,
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
              icon: Icon(Icons.delete_outline,
                  size: 18.sp, color: p.muted),
              onPressed: () => _deleteRecord(r),
            ),
          ]),
          SizedBox(height: 10.h),
          // 分区标签（彩色芯片）+ 环境类型。
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(catText,
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: catColor)),
            ),
            SizedBox(width: 8.w),
            if (envVal != null && envVal.isNotEmpty)
              Expanded(
                child: Text('${l10n.noiseEnvType}: $envVal',
                    style: TextStyle(fontSize: 12.sp, color: p.labelText)),
              ),
          ]),
          SizedBox(height: 8.h),
          // 噪音值整行。
          Text(
            '${l10n.noiseLevel}: ${r.levelDb.toStringAsFixed(1)} ${l10n.noiseDbUnit}',
            style: TextStyle(fontSize: 12.sp, color: p.labelText),
          ),
        ],
      ),
    );
  }
}

/// 读数卡中的「标签 + 值」单元（与 CompassPage 同款）。
class ReadingItem extends StatelessWidget {
  const ReadingItem({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.valueSize,
    required this.valueWeight,
  });

  final String label;
  final String value;
  final Color valueColor;
  final double valueSize;
  final FontWeight valueWeight;

  @override
  // ignore: library_private_types_in_public_api
  Widget build(BuildContext context) {
    final _PanelPalette p = _PanelPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: p.labelText)),
        SizedBox(height: 4.h),
        Text(value,
            style: TextStyle(
                fontSize: valueSize.sp,
                fontWeight: valueWeight,
                color: valueColor)),
      ],
    );
  }
}

/// 历史区占位（加载中 / 空列表）。
class HistoryPlaceholder extends StatelessWidget {
  const HistoryPlaceholder({super.key, required this.text});

  final String text;

  @override
  // ignore: library_private_types_in_public_api
  Widget build(BuildContext context) {
    final _PanelPalette p = _PanelPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp, color: p.labelText)),
    );
  }
}

/// 噪音分贝表盘组件（无状态）。
///
/// 仅负责绘制：彩色分区弧 + 刻度 + 指向当前分贝的指针，中心大数字由 Stack
/// 叠加层呈现（见 [NoisePage] 中的 [_NoiseGauge]）。
class _NoiseGauge extends StatelessWidget {
  const _NoiseGauge({required this.db, required this.palette});

  /// 当前分贝（null 表示尚未读数，指针归零）。
  final double? db;

  /// 表盘色板（随主题明暗切换）。
  final NoiseGaugePalette palette;

  /// 表盘直径（逻辑像素，已乘 .w）。
  static const double _size = 260;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double displayDb = _clampSafe(db);
    final bool has = db != null;
    final String zoneEnv = has ? _zoneEnvOf(displayDb, l10n) : '';
    final Color zoneColor = has
        ? _zoneColorOf(displayDb, palette)
        : palette.subText;

    return SizedBox(
      width: _size.w,
      height: _size.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 表盘绘制层（弧 + 刻度 + 指针）。
          CustomPaint(
            size: Size.square(_size.w),
            painter: _GaugePainter(displayDb, palette),
          ),
          // 中心读数叠加层。
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                has ? displayDb.round().toString() : '—',
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w800,
                  color: palette.bigText,
                ),
              ),
              SizedBox(height: 2.h),
              Text(l10n.noiseDbUnit,
                  style: TextStyle(fontSize: 14.sp, color: palette.subText)),
              SizedBox(height: 6.h),
              if (has)
                Text(
                  zoneEnv,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: zoneColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 安全钳制：null 视为 0。
  double _clampSafe(double? v) => (v ?? 0).clamp(0, 120);

  String _zoneEnvOf(double db, AppLocalizations l10n) {
    if (db > 90) return l10n.noiseZoneLoudEnv;
    if (db >= 50) return l10n.noiseZoneModerateEnv;
    return l10n.noiseZoneQuietEnv;
  }

  Color _zoneColorOf(double db, NoiseGaugePalette p) {
    if (db > 90) return p.loud;
    if (db >= 50) return p.moderate;
    return p.quiet;
  }
}

/// 渐变弧四段锚色：低→高 依次为绿 / 黄 / 橙 / 深红。
/// 与 [NoiseGaugePalette] 的 quiet/moderate/loud 保持一致，视觉统一。
///
/// ⚠️ 高分贝端（120 dB）用**深红**而非亮红：分贝越高越危险，深色在浅底上更醒目，
/// 也避免与中间段的橙黄在明度上撞色、导致「高分贝看起来不够警示」。
const Color _gradGreen = Color(0xFF4CAF50);
const Color _gradYellow = Color(0xFFFFC107);
const Color _gradOrange = Color(0xFFFB8C00);
const Color _gradRed = Color(0xFFC62828);

/// 表盘绘制：背景轨道 + 绿→红渐变弧 + 刻度 + 指针 + 中心轴。
class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.db, this.p);

  /// 当前分贝（0~120）。
  final double db;
  final NoiseGaugePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    // 表盘从左下 135° 起顺时针扫 270°，底部留缺口（与罗盘风格一致）。
    const double start = 135 * math.pi / 180;
    const double sweep = 270 * math.pi / 180;
    final double ringR = r * 0.82;

    // 背景轨道（浅灰底）。
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringR),
      start,
      sweep,
      false,
      Paint()
        ..color = p.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.w
        ..strokeCap = StrokeCap.round,
    );

    // 渐变分区弧：0~120 dB 从绿（低）→黄→橙→深红（高）连续渐变，
    // 颜色随分贝线性过渡，不再用三色硬分区。
    //
    // ⚠️ 坑一（2026-09-14 修复）：SweepGradient 的 shader 只认当前点的**原始**角度
    // （归一化到 [0, 2π)），再按 t = (原始角度 - startAngle) / (endAngle - startAngle) 取色。
    // 本弧从 135° 扫到 405°，越过 360° 的那一段（3 点钟方向 → 右下角，即 100~120 dB 的
    // 高分贝区）其原始角度回落到 [0°, 45°]，算出的 t 落进区间左侧，被 TileMode.clamp
    // 夹住，于是那段高分贝被画成渐变首色（绿）——“高分贝显示绿色”的元凶。
    // 解法：先把画布旋转，让弧在局部坐标系里从正角扫到 sweep（不跨 0°），}t 全程落在
    // 渐变区间内，不会再依赖 clamp 兜底。
    //
    // ⚠️ 坑二（2026-09-18 修复）：仅仅「转成正角」还不够 —— StrokeCap.round 的圆角帽是
    // 以端点为圆心、半径 = strokeWidth/2 的圆，会朝**弧外侧再探出**
    // asin((strokeWidth/2) / ringR) ≈ 4.3°（本机读数：8.w / 106.6）。
    // 于是起点那一小撮像素的局部角是**负的**，又掉出渐变区间；规范化后接近 358°，
    // 取到的是**末色深红** —— 这就是「左侧起弧处有一点点红色」。
    // 解法：给弧整体让出 [capPad] 的余量 —— 画布少转 capPad、弧起始角抬到 capPad，
    // 全局位置（仍是 start）完全不变，但圆角帽溢出后依然是**正角**，稳稳落在渐变内。
    const double capPad = 8 * math.pi / 180; // 8° > 圆角帽溢出 4.3°，留足余量
    const double full = 2 * math.pi; // 一整圈，用于把色标换算成整圈占比
    final double ringOuter = ringR + 8.w; // 弧带外半径（strokeWidth 16 的一半）
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // 少转 capPad + 弧起点抬 capPad ⇒ 弧的全局位置与原来完全一致。
    canvas.rotate(start - capPad);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: ringR),
      capPad, // 旋转后：弧起点抬到 +capPad，圆角帽溢出后仍为正角
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.w
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          // 渐变直接覆盖**整圈**（默认 0 → 2π），色标按弧的真实角度换算成整圈占比。
          // 如此颜色在整个 [0, 2π) 上单调连续，弧覆盖范围内不可能触发 clamp：
          //   · 首色之前（起点圆角帽溢出段）取首色 —— 绿色，正是 0 dB 应有的颜色
          //   · 末色之后（末端圆角帽溢出段）取末色 —— 深红，正是 120 dB 应有的颜色
          colors: const [
            _gradGreen, // 绿：安静（0 dB）
            _gradYellow, // 黄：适中偏下（50 dB）
            _gradOrange, // 橙：适中偏上（90 dB）
            _gradRed, // 深红：嘈杂（120 dB）
          ],
          stops: <double>[
            capPad / full, // 0 dB：弧起点
            (capPad + sweep * (50 / 120)) / full, // 50 dB
            (capPad + sweep * (90 / 120)) / full, // 90 dB
            (capPad + sweep) / full, // 120 dB：弧末端
          ],
        ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: ringOuter)),
    );
    canvas.restore();

    // 刻度：每 10 dB 一根，整 30 dB 为主刻度（更长）。
    // 弧带加宽后，刻度内移，落在指针与弧带之间的空隙里。
    final Paint tickPaint = Paint()
      ..color = p.tick
      ..strokeWidth = 1.5.w
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= 120; i += 10) {
      final double a = start + (i / 120) * sweep;
      final double outer = r * 0.80;
      final double inner = (i % 30 == 0) ? r * 0.74 : r * 0.77;
      canvas.drawLine(
        center + Offset(math.cos(a) * inner, math.sin(a) * inner),
        center + Offset(math.cos(a) * outer, math.sin(a) * outer),
        tickPaint,
      );
    }

    // 指针：指向当前分贝，颜色取当前分区色。
    final double na = start + (db / 120) * sweep;
    final Color needleColor =
        db > 90 ? p.loud : (db >= 50 ? p.moderate : p.quiet);
    canvas.drawLine(
      center,
      center + Offset(math.cos(na) * r * 0.72, math.sin(na) * r * 0.72),
      Paint()
        ..color = needleColor
        ..strokeWidth = 3.w
        ..strokeCap = StrokeCap.round,
    );
    // 中心轴。
    canvas.drawCircle(center, r * 0.05, Paint()..color = p.hub);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.db != db || old.p != p;
}

/// 麦克风不可用时的占位视图。
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({
    required this.message,
    required this.actionLabel,
    required this.palette,
    required this.permanentlyDenied,
    required this.onRetry,
    this.onOpenSettings,
  });

  final String message;
  final NoiseGaugePalette palette;

  /// 按钮文案由外部给定：未授权是「授权并开始测量」、被拒是重试、
  /// 永久拒绝是「去系统设置开启」——三种状态语义不同，写死在组件里会词不达意。
  final String actionLabel;

  /// 是否「永久拒绝」：决定按钮图标（去设置 vs 麦克风）。
  final bool permanentlyDenied;

  /// 点击按钮的回调：普通拒绝→重新申请；永久拒绝→跳转系统设置。
  final VoidCallback onRetry;

  /// 次级入口「打开设置」的回调。
  ///
  /// 为 null 时不渲染该按钮（永久拒绝场景下主按钮已经是「打开设置」，
  /// 再显示一个同功能入口没有意义）。
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.mic_off, size: 48.sp, color: palette.subText),
        SizedBox(height: 16.h),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: palette.subText)),
        SizedBox(height: 16.h),
        // 恢复入口：永久拒绝去系统设置，否则重新申请权限。
        FilledButton.icon(
          onPressed: onRetry,
          icon: Icon(permanentlyDenied ? Icons.settings : Icons.mic),
          label: Text(actionLabel),
          style: FilledButton.styleFrom(
            backgroundColor: palette.bigText,
            foregroundColor: palette.track,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          ),
        ),
        // 次级入口：不想再看系统弹窗、想自己去设置里开的用户走这里。
        if (onOpenSettings != null) ...[
          SizedBox(height: 8.h),
          TextButton(
            onPressed: onOpenSettings,
            child: Text(
              AppLocalizations.of(context)!.noiseMicOpenSettings,
              style: TextStyle(fontSize: 13.sp, color: palette.subText),
            ),
          ),
        ],
      ],
    );
  }
}

/// 噪音表盘双主题色板。
///
/// 与 CompassPage 的 [_PanelPalette] 同理：深浅两版逐项硬编码，避免串色。
class NoiseGaugePalette {
  const NoiseGaugePalette({
    required this.track,
    required this.quiet,
    required this.moderate,
    required this.loud,
    required this.tick,
    required this.bigText,
    required this.subText,
    required this.hub,
  });

  /// 背景轨道色。
  final Color track;
  /// 安静分区色（绿）。
  final Color quiet;
  /// 适中分区色（琥珀）。
  final Color moderate;
  /// 嘈杂分区色（红棕）。
  final Color loud;
  /// 刻度色。
  final Color tick;
  /// 中心大数字色。
  final Color bigText;
  /// 次级文字（dB / 提示）色。
  final Color subText;
  /// 中心轴色。
  final Color hub;

  /// 依据当前主题返回对应色板实例。
  ///
  /// 仅文字色接 [AppPalette]（中心大数字 → valueText、次级文字 → labelText），
  /// 使其响应「主题色方案（咖啡色 / 蓝色）× 明暗模式」两个维度。
  ///
  /// ⚠️ 仪表语义固定色一律保留原值：背景轨道 [track]、刻度 [tick]、中心轴 [hub]
  /// 属表盘专用色；[quiet] / [moderate] / [loud] 是分贝等级色（绿 / 黄 / 红），
  /// 表达「安静→嘈杂」这一跨主题一致的语义，若随色卡变化会让读数失去直觉。
  /// 另外深色态 bigText #F2F2F7 / subText #AEAEB2 与 AppPalette 深色的
  /// #FFFFFF / #A1A1AA 不同，按「咖啡色主题零回归」原则也保留原值。
  static NoiseGaugePalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      // 深色版：暗底、暖金中心轴，分区色保持可辨。
      return const NoiseGaugePalette(
        track: Color(0xFF3A3A3C),
        quiet: Color(0xFF66BB6A),
        moderate: Color(0xFFFFCA28),
        loud: Color(0xFFEF5350),
        tick: Color(0xFF8A8A8E),
        bigText: Color(0xFFF2F2F7),
        subText: Color(0xFFAEAEB2),
        hub: Color(0xFFC8A97E),
      );
    }
    // 浅色版：严格对齐 Pixso 184:8。
    return NoiseGaugePalette(
      track: const Color(0xFFE4E0D9),
      quiet: const Color(0xFF4CAF50),
      moderate: const Color(0xFFFFC107),
      loud: const Color(0xFFE53935),
      tick: const Color(0xFFB5AFA7),
      bigText: app.valueText,
      subText: app.labelText,
      hub: const Color(0xFF8B5C44),
    );
  }
}

/// 面板双主题色板（读数卡 / 按钮 / 历史）。
///
/// 与 CompassPage 的 [_PanelPalette] 字段一致、取值一致，保证工具箱视觉统一。
class _PanelPalette {
  const _PanelPalette({
    required this.pageBg,
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

  final Color pageBg;
  final Color cardBg;
  final Color cardBorder;
  final Color titleText;
  final Color labelText;
  final Color valueText;
  final Color accent;
  final Color recordBtnText;
  final Color secondaryBtnBg;
  final Color divider;
  final Color muted;

  /// 依据当前主题返回对应色板实例。
  ///
  /// 通用语义色（页面底 / 卡片 / 文字 / 强调 / 次按钮 / 分隔线）统一取自
  /// [AppPalette]，使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」
  /// 两个维度的切换。字段与 CompassPage 的 [_PanelPalette] 一一对应，取值一致。
  ///
  /// ⚠️ 逐项比对后仍保留原常量的字段（与 [AppPalette] 取值不一致，套用会让
  /// 咖啡色主题出现视觉回归，安全优先）：
  ///   - cardBorder / divider：浅色 #D1CDC4、深色 #48484A，比 AppPalette 的
  ///     描边更深一档；
  ///   - 深色态 titleText / valueText #F2F2F7、labelText #AEAEB2，AppPalette
  ///     深色为 #FFFFFF / #A1A1AA；
  ///   - 深色态 accent：本页为暖金 #C8A97E，AppPalette.coffeeDark.accent 是
  ///     #8B5C44（工程已知的深色强调差异）；
  ///   - 深色态 recordBtnText #1C1C1E（暖金底上的深字）与 secondaryBtnBg
  ///     #3D3429，同样与 AppPalette 深色值不同。
  static _PanelPalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return _PanelPalette(
        pageBg: app.pageBg,
        cardBg: app.cardBg,
        // 描边 / 分隔线沿用稿面灰阶，AppPalette 深色值更暗更冷，保留原值。
        cardBorder: const Color(0xFF48484A),
        titleText: const Color(0xFFF2F2F7),
        labelText: const Color(0xFFAEAEB2),
        valueText: const Color(0xFFF2F2F7),
        // 深色强调色直接取主题主色：咖啡色下即暖金 #C8A97E（与原设计稿一致），
        // 切到蓝色主题后自动变为晴空蓝 #79B8F3。
        accent: Theme.of(context).colorScheme.primary,
        recordBtnText: const Color(0xFF1C1C1E),
        secondaryBtnBg: const Color(0xFF3D3429),
        divider: const Color(0xFF48484A),
        muted: app.muted,
      );
    }
    return _PanelPalette(
      pageBg: app.pageBg,
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
