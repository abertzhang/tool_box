// ruler_records_provider.dart
//
// 直尺（Ruler）测量记录的历史列表数据源。
// 所属模块：feature/tool/provider（工具箱状态层）。
// 关键依赖：flutter_riverpod（FutureProvider）、isar_community。
//
// 复用说明：与 compass_records_provider / noise_records_provider /
// level_records_provider 同源，统一订阅 Isar 的 rulerRecords 集合，
// 按 createdAt 倒序返回，写入/删除后由页面 ref.invalidate 刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/data/model/ruler_record.dart';

/// 直尺测量记录列表（按创建时间倒序）。
///
/// 返回 Isar「直尺表」全部记录，最新在前。页面写入/删除后调用
/// `ref.invalidate(rulerRecordsProvider)` 即可刷新本 Provider。
final FutureProvider<List<RulerRecord>> rulerRecordsProvider =
    FutureProvider<List<RulerRecord>>((ref) async {
  // 链式查询在 isar_community 中需经 buildQuery + Dart 侧排序。
  final List<RulerRecord> list =
      await IsarService.instance.rulerRecords
          .buildQuery<RulerRecord>() // ignore: experimental_member_use
          .findAll();
  // 倒序：最新测量排在最前。
  return list.reversed.toList();
});
