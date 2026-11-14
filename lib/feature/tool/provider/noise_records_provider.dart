// noise_records_provider.dart
//
// 噪音检测「记录」列表的 Riverpod Provider。
// 所属模块：feature/tool（工具箱）· 噪音检测子工具。
// 关键依赖：isar_service（本地数据库单例）、noise_record（数据模型）。
//
// 职责：
//   以声明式方式暴露「噪音表」的全部记录，按创建时间倒序（最新在前），
//   供 NoisePage 的历史记录区直接订阅。新增/删除记录后调用方通过
//   `ref.invalidate(noiseRecordsProvider)` 重新拉取即可刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/data/model/noise_record.dart';

/// 噪音记录列表（按创建时间倒序，最新一条在最前）。
///
/// 实现要点：
///   - 用 `buildQuery<NoiseRecord>().findAll()` 取出全部行（isar_community
///     的泛型扩展需忽略 experimental 提示，与 faq_provider 一致）；
///   - Isar 默认按 id 升序返回，反转后即“最新在前”，契合历史记录展示习惯。
final noiseRecordsProvider = FutureProvider<List<NoiseRecord>>((ref) async {
  final list = await IsarService.instance.noiseRecords
      .buildQuery<NoiseRecord>() // ignore: experimental_member_use
      .findAll();
  return list.reversed.toList();
});
