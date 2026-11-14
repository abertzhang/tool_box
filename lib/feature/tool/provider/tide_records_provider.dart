// tide_records_provider.dart
//
// 潮汐（Tide）历史记录的数据源。
// 所属模块：feature/tool/provider（工具箱状态层）。
// 关键依赖：flutter_riverpod（FutureProvider）、isar_community。
//
// 复用说明：与 noise/level/ruler 同源，统一订阅 Isar 的 tideRecords 集合，
// 按 createdAt 倒序返回；页面写入（记录当前）后调用 ref.invalidate 刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/data/model/tide_record.dart';

/// 潮汐历史记录列表（按创建时间倒序）。
///
/// 返回 Isar「潮汐表」全部记录，最新在前。页面「记录当前」写入后，
/// 调用 `ref.invalidate(tideRecordsProvider)` 即可刷新本 Provider。
final FutureProvider<List<TideRecord>> tideRecordsProvider =
    FutureProvider<List<TideRecord>>((ref) async {
      // 链式查询在 isar_community 中需经 buildQuery + Dart 侧排序。
      final List<TideRecord> list = await IsarService.instance.tideRecords
          .buildQuery<TideRecord>() // ignore: experimental_member_use
          .findAll();
      // 倒序：最新记录排在最前。
      return list.reversed.toList();
    });
