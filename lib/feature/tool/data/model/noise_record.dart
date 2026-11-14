// noise_record.dart
//
// 噪音检测「记录」的 Isar 本地持久化模型（即需求中的「噪音表」）。
// 所属模块：feature/tool（工具箱）· 噪音检测子工具。
// 关键依赖：isar_community（本地数据库）；生成的 `noise_record.g.dart`
//           提供 Isar schema（由 build_runner 基于本文件自动生成，请勿手改）。
//
// 职责：
//   当用户在噪音检测页点击「记录当前噪音」时，把当前分贝值 + 自动判定的
//   噪音等级（安静/适中/嘈杂）+ 可选的环境类型 + 命名 + 时间戳写入此表。
//   历史记录列表即从此表读取，实现「噪音表」的本地持久化与回看。
//
// 设计要点：
//   - levelDb 保存录制瞬间的分贝（已按 0~120 区间钳制）；
//   - category 保存等级「键」(quiet/moderate/loud) 而非本地化文案，
//     使历史记录不依赖录制时的语言，展示时再按当前语言还原；
//   - environmentType 为可空字符串：用户可填写「室内机械」「装备测试」
//     等环境说明，留空亦允许；
//   - createdAt 用于历史列表按时间倒序展示，并作卡片上的「时间」标签。

import 'package:isar_community/isar.dart';

part 'noise_record.g.dart';

/// 一条噪音检测记录（「噪音表」中的一行）。
///
/// 对应设计稿 Pixso 184:8 中的一条 history-card：等级标签 + 环境类型 +
/// 噪音值 + 时间 + 名称。
@collection
class NoiseRecord {
  /// 自增主键（由 Isar 分配）。
  Id id = Isar.autoIncrement;

  /// 记录名称（用户输入，如「风绳拉紧机舱操作」「营地周边环境」）。
  String name;

  /// 录制的噪音值（分贝 dB，已钳制在 0~120）。
  double levelDb;

  /// 噪音等级键：quiet（安静）/ moderate（适中）/ loud（嘈杂）。
  /// 录制时按分贝阈值自动判定，展示时再映射为本地化文案。
  String category;

  /// 环境类型（可选，用户输入，如「室内机械」「装备测试」「户外林地」）。
  String? environmentType;

  /// 记录创建时间，用于排序与时间标签。
  DateTime createdAt;

  /// 创建一条噪音记录。
  ///
  /// - [name] 用户命名；[levelDb] 分贝值；[category] 等级键；
  /// - [environmentType] 可选环境说明；[createdAt] 记录时间（通常 `DateTime.now()`）。
  NoiseRecord({
    required this.name,
    required this.levelDb,
    required this.category,
    this.environmentType,
    required this.createdAt,
  });
}
