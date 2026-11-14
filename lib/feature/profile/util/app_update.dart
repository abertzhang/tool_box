// ============================================================================
// 文件：feature/profile/util/app_update.dart
// 模块：我的 / 个人中心（profile）/ 检查更新
//
// 职责：
//   封装「检查更新」能力，供 profile 页「关于」分组的「检查更新」行调用。
//
// 为什么单独抽一个文件：
//   与 app_review.dart 同理 —— 把「取当前版本 / 拉远端版本 / 比较 / 跳商店」这套
//   逻辑与平台差异收在一处，profile 页面只管调用与弹 UI，不关心实现细节；
//   纯逻辑（解析 / 比较）是独立函数，方便单测覆盖，不依赖 Flutter 绑定。
//
// 两种工作模式（由 [kAppUpdateInfoUrl] 决定）：
//   1. **未配置远端地址（默认，空串）**：点击检查更新 → 直接打开商店详情页，
//      由 App Store / Play Store / Microsoft Store 告知是否有更新可装。
//      零后端、最省事，适合刚上架、还没搭版本服务的阶段。
//   2. **配置了远端地址**：拉取一份版本 JSON，与本地版本比较，
//      - 有更新 → 弹「发现新版本」对话框（Update / Later）；
//      - 已最新 → 提示「已是最新 (vx.x.x)」；
//      - 拉取失败 → 回落到「打开商店」（商店仍是更新入口）。
//
// 远端 JSON 约定（最小集，字段均可选除 latest_version）：
//   {
//     "latest_version": "2.2.0",   // 必填：线上最新版本号
//     "min_version":   "2.0.0",    // 可选：最低可运行版本（预留，UI 暂未强制）
//     "force":         false,      // 可选：是否强制更新（预留）
//     "release_notes": "..."       // 可选：更新说明，展示在对话框正文
//   }
//
// 关键依赖：
//   - package_info_plus：读取本地安装版本（[getCurrentVersion]）；
//   - in_app_review：打开商店详情页（[openStoreForUpdate]，复用评分模块的落点）；
//   - flutter/foundation 的 [NetworkAssetBundle]：拉取远端 JSON，无需额外 http 依赖；
//   - app_review 的 [kAppStoreId]：iOS / macOS 打开商店详情页必需。
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_review.dart';

/// 远端「最新版本」配置 JSON 的 URL。
///
/// ⚠️ 留空（默认）表示走「模式 1：直接打开商店」；
/// 想获得「有更新 / 已是最新」的精确反馈，把它指向你部署的版本 JSON
/// （如 Supabase Storage / GitHub raw / 自有接口），本文件会自动拉取并比较。
///
/// 为什么留空而不是填占位：模式 1 在没后端时也能用，避免指向一个
/// 不存在的地址导致每次检查都走失败回落。
const String kAppUpdateInfoUrl = '';

/// 检查更新结果。
enum UpdateCheckResult {
  /// 已是最新（远端版本号不大于本地）。
  upToDate,

  /// 远端版本更新，应提示用户升级。
  updateAvailable,

  /// 未配置远端地址：直接打开商店由平台判断（模式 1）。
  openStore,

  /// 远端拉取 / 解析失败：调用方应回落到打开商店。
  error,
}

/// 远端版本信息（解析后的结构化数据）。
class UpdateInfo {
  /// 创建远端版本信息。
  const UpdateInfo({
    required this.latestVersion,
    this.minVersion,
    this.force = false,
    this.releaseNotes,
  });

  /// 线上最新版本号（必填，解析时缺失会抛 [FormatException]）。
  final String latestVersion;

  /// 最低可运行版本（可选）。
  final String? minVersion;

  /// 是否强制更新（可选，UI 暂未强制拦截）。
  final bool force;

  /// 更新说明（可选，展示在对话框正文）。
  final String? releaseNotes;
}

/// 拉取远端 JSON 的函数类型（可注入，便于单测）。
typedef UpdateFetcher = Future<String> Function(String url);

/// 默认实现：用 [NetworkAssetBundle] 拉取 [url] 的内容。
///
/// 不引第三方 http 包；[NetworkAssetBundle] 在 iOS / Android / macOS 上
/// 走系统网络栈，对 https 无额外权限要求（清单位已声明互联网权限）。
Future<String> _defaultFetch(String url) =>
    NetworkAssetBundle(Uri.parse(url)).loadString(url);

/// 解析远端版本 JSON（纯函数，便于单测）。
///
/// 参数：[json] 已解码的 JSON 对象。
/// 返回：[UpdateInfo]。
/// 抛：[FormatException] 当缺少 [latest_version]。
UpdateInfo parseUpdateInfo(Map<String, dynamic> json) {
  final latest =
      (json['latest_version'] as String?) ?? (json['version'] as String?) ?? '';
  if (latest.isEmpty) {
    throw const FormatException('版本 JSON 缺少 latest_version 字段');
  }
  return UpdateInfo(
    latestVersion: latest,
    minVersion: json['min_version'] as String?,
    force: json['force'] as bool? ?? false,
    releaseNotes: json['release_notes'] as String?,
  );
}

/// 比较点分版本号：返回 true 表示 [latest] 比 [current] 更新。
///
/// 规则：逐段按整数比较（去前缀 v、非数字段记 0）；前缀相等时，段数更多的一方更新
/// （如 2.1 < 2.1.1）。完全相等 → false。
///
/// 例：
///   isUpdateAvailable('2.1.0', '2.1.0') → false
///   isUpdateAvailable('2.1.0', '2.2.0') → true
///   isUpdateAvailable('2.1',   '2.1.1') → true
bool isUpdateAvailable(String current, String latest) {
  final c = current
      .split('.')
      .where((e) => e.trim().isNotEmpty)
      .map(_segToInt)
      .toList();
  final l = latest
      .split('.')
      .where((e) => e.trim().isNotEmpty)
      .map(_segToInt)
      .toList();
  final n = c.length > l.length ? c.length : l.length;
  for (var i = 0; i < n; i++) {
    final a = i < c.length ? c[i] : 0;
    final b = i < l.length ? l[i] : 0;
    if (a != b) return b > a;
  }
  return false;
}

/// 把版本号单段解析成整数（去前缀 v、取前导数字，非数字记 0）。
int _segToInt(String s) {
  final cleaned = s.trim().replaceFirst(RegExp(r'^v'), '');
  final m = RegExp(r'^\d+').firstMatch(cleaned);
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// 当前安装版本的缓存 Future。
///
/// 懒加载 + 记忆化：首次调用才真正读取 [PackageInfo]，之后复用同一结果，
/// 避免 profile 页每次 build 都重新取平台信息。
Future<String>? _cachedVersion;

/// 读取当前安装的 App 版本号（不含 build 号，如 "2.1.0"）。
Future<String> getCurrentVersion() =>
    _cachedVersion ??= PackageInfo.fromPlatform().then((i) => i.version);

/// 构建「关于 / 检查更新」行右侧显示的版本标签。
///
/// 区分构建模式，便于在开发包上直观区分于正式发布版本：
/// - Release 模式 → `vX.X.X`（例如 `v1.0.0`）；
/// - 非 Release（Debug / Profile）→ `debug vX.X.X`（例如 `debug v1.0.0`）。
///
/// 纯函数，便于单测；构建模式依赖 [kReleaseMode]（来自 foundation）。
String buildVersionLabel(String version) {
  final v = 'v$version';
  return kReleaseMode ? v : 'debug $v';
}

/// 打开商店详情页（用户可在此更新）。
///
/// iOS / macOS 需要 [kAppStoreId]（见 app_review.dart，上架后必填）；
/// 未配置时空跑并打日志，不抛异常波及页面。
Future<void> openStoreForUpdate() async {
  try {
    await InAppReview.instance.openStoreListing(appStoreId: kAppStoreId);
  } catch (e) {
    debugPrint('[AppUpdate] openStoreListing 失败: $e');
  }
}

/// 检查更新。
///
/// 参数：
/// - [fetcher] 远端拉取实现，默认 [_defaultFetch]；单测可注入假实现。
///
/// 返回：(结果, 远端信息?)——仅 [updateAvailable] 时 [UpdateInfo] 非空。
Future<(UpdateCheckResult, UpdateInfo?)> checkForUpdate({
  UpdateFetcher? fetcher,
}) async {
  final current = await getCurrentVersion();

  // 模式 1：未配置远端地址 → 交给商店判断，标记 openStore。
  if (kAppUpdateInfoUrl.isEmpty) {
    return (UpdateCheckResult.openStore, null);
  }

  // 模式 2：拉取并比较。
  final fetch = fetcher ?? _defaultFetch;
  try {
    final raw = await fetch(kAppUpdateInfoUrl);
    final UpdateInfo info = parseUpdateInfo(
      json.decode(raw) as Map<String, dynamic>,
    );
    final newer = isUpdateAvailable(current, info.latestVersion);
    return newer
        ? (UpdateCheckResult.updateAvailable, info)
        : (UpdateCheckResult.upToDate, info);
  } catch (e) {
    debugPrint('[AppUpdate] 检查更新失败，回落商店: $e');
    return (UpdateCheckResult.error, null);
  }
}
