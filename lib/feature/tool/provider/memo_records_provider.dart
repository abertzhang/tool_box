// memo_records_provider.dart
//
// 备忘录（Memo）的数据源。
// 所属模块：feature/tool/provider（工具箱状态层）。
// 关键依赖：flutter_riverpod（FutureProvider）、isar_community。
//
// 复用说明：与 tide/level/ruler 同源，统一订阅 Isar 的 memoRecords 集合，
// 按 updatedAt 倒序返回；页面写入 / 删除后调用 ref.invalidate 刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/data/model/memo_record.dart';

/// 备忘列表（按最后更新时间倒序）。
///
/// 返回 Isar「备忘表」全部记录，最近编辑的排在前面。页面新增 / 编辑 / 删除
/// 后，调用 `ref.invalidate(memoRecordsProvider)` 即可刷新本 Provider。
final FutureProvider<List<MemoRecord>> memoRecordsProvider =
    FutureProvider<List<MemoRecord>>((ref) async {
  // 链式查询在 isar_community 中需经 buildQuery + Dart 侧排序。
  final List<MemoRecord> list = await IsarService.instance.memoRecords
      .buildQuery<MemoRecord>() // ignore: experimental_member_use
      .findAll();
  // 倒序：最后更新的备忘排在最前。
  list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return list;
});
