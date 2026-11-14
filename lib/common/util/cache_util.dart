// ============================================================================
// 文件：common/util/cache_util.dart
// 模块：通用工具 / 缓存管理
//
// 职责：
//   提供「计算应用缓存占用」与「清理缓存」两个能力，供「我的」页「清除缓存」行使用。
//
// 关键依赖：
//   - path_provider：定位系统的临时目录与应用缓存目录；
//   - dart:io：遍历目录、统计与删除文件；
//   - flutter/widgets：通过 PaintingBinding 清空内存图片缓存。
//
// 设计取舍（重要）：
//   仅清理「可安全丢弃」的缓存（临时目录 + 应用缓存目录 + 内存图片缓存），
//   不触碰 Hive / Isar(FAQ) / Gemma 模型等用户数据——它们位于应用文档目录，
//   删除会导致已存绳结 FAQ、已下载模型丢失。清理时只删除目录内的子项、
//   保留目录本身，避免系统在目录尚未重建时的竞态。
// ============================================================================

import 'dart:io';

import 'package:flutter/widgets.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 计算「应用可清理缓存」的总占用字节数。
///
/// 汇总两个安全目录：
///   - [getTemporaryDirectory]：系统临时目录（如 Android 的 cache 临时文件）；
///   - [getApplicationCacheDirectory]：应用专属缓存目录（下载缓存、Web 缓存等）。
///
/// 任一目录获取失败时跳过该目录，不影响整体统计，保证方法不会因单个目录异常而中断。
///
/// 返回：字节数（int）。
Future<int> computeCacheBytes() async {
  final dirs = <Directory?>[];
  try {
    dirs.add(await getTemporaryDirectory());
  } catch (_) {
    // 临时目录不可用时忽略，继续统计其余目录。
  }
  try {
    dirs.add(await getApplicationCacheDirectory());
  } catch (_) {
    // 应用缓存目录不可用时忽略。
  }

  int total = 0;
  for (final dir in dirs) {
    if (dir == null || !await dir.exists()) continue;
    total += await _dirBytes(dir);
  }
  return total;
}

/// 递归累加一个目录下所有常规文件的字节数。
///
/// - [followLinks] 为 false，避免符号链接形成环导致无限遍历；
/// - 单文件在遍历瞬间被删除或无权限时跳过，不中断整体统计。
Future<int> _dirBytes(Directory dir) async {
  int sum = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        sum += await entity.length();
      } catch (_) {
        // 文件临时不可访问则忽略。
      }
    }
  }
  return sum;
}

/// 将字节数格式化为「XX.X MB」或「XX.X KB」。
///
/// 以 1024 为进制：大于等于 1 MB 用 MB，否则若大于等于 1 KB 用 KB，
/// 极小（< 1 KB）时直接用字节展示，避免「0.0 KB」显得不真实。
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

/// 清理应用缓存。
///
/// 行为：
/// 1. 删除临时目录与应用缓存目录内的全部子项（文件与子目录），保留目录本身；
/// 2. 清空 Flutter 内存图片缓存（[PaintingBinding.instance.imageCache]），
///    释放已解码的位图，下次访问重新解码。
///
/// 注意：本方法不清除任何用户数据（Hive / Isar / 模型），仅清理可再生的缓存。
Future<void> clearAppCache() async {
  final toClear = <Directory?>[];
  try {
    toClear.add(await getTemporaryDirectory());
  } catch (_) {
    // 获取失败则跳过。
  }
  try {
    toClear.add(await getApplicationCacheDirectory());
  } catch (_) {
    // 获取失败则跳过。
  }

  for (final dir in toClear) {
    if (dir == null) continue;
    await _deleteContents(dir);
  }

  // 内存图片缓存与磁盘目录无依赖，独立清空即可。
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

/// 删除目录内的所有直接/间接子项，但保留 [dir] 自身。
///
/// 先复制子项列表再逐个删除，避免遍历过程中集合被修改导致的并发异常。
Future<void> _deleteContents(Directory dir) async {
  if (!await dir.exists()) return;
  final children = await dir.list().toList();
  for (final entity in children) {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      // 个别文件被占用或无权限则跳过，不影响其它子项清理。
    }
  }
}

/// 缓存占用字节数的响应式 Provider。
///
/// 供埋点等需要**数值**而非展示文案的场景使用（清除缓存时要上报清理前的占用量级）。
/// 遍历磁盘目录有成本，因此只此一份数据源，展示用的 [cacheSizeProvider] 依赖它，
/// 避免同一份数据被算两遍。
final cacheBytesProvider = FutureProvider<int>((ref) => computeCacheBytes());

/// 缓存占用大小的响应式 Provider。
///
/// 返回格式化后的字符串（如「23.5 MB」「512.0 KB」），供「清除缓存」行右侧展示。
/// 清理完成后通过 [ref.invalidate] 该 Provider 重新计算，使右侧数字刷新为清理后的占用。
final cacheSizeProvider = FutureProvider<String>((ref) async {
  // 复用 [cacheBytesProvider] 的结果：目录遍历较重，不能为展示文案再走一遍。
  final bytes = await ref.watch(cacheBytesProvider.future);
  return formatBytes(bytes);
});
