// compass_record.dart
//
// 指南针「记录点」的 Isar 本地持久化模型（即需求中的「指南针表」）。
// 所属模块：feature/tool（工具箱）· 指南针子工具。
// 关键依赖：isar_community（本地数据库）；生成的 `compass_record.g.dart`
//           提供 Isar schema（由 build_runner 基于本文件自动生成，请勿手改）。
//
// 职责：
//   当用户在指南针页点击「记录当前位置」时，把当前方位角 + GPS（海拔/纬度/
//   经度，可能为 null）+ 命名 + 时间戳写入此表。历史记录列表即从此表读取，
//   实现「指南针表」的本地持久化与回看。
//
// 设计要点：
//   - 方位角(heading)、方向缩写(cardinalAbbrev)、方向本地化名(cardinalName)
//     三项一起保存，使历史卡片可直接还原设计稿中「N 15° 北」这类展示。
//   - 海拔/纬度/经度为可空 double：设备无 GPS 权限/信号时仅记录方位角，
//     不强制写入坐标（体验不崩）。
//   - createdAt 用于历史列表按时间倒序展示，并作为卡片上的「时间」标签。

import 'package:isar_community/isar.dart';

part 'compass_record.g.dart';

/// 指南针记录点（一条已保存的位置/方位书签）。
///
/// 对应设计稿 Pixso 2:3 中的一条 history-card：名称 + 时间 + 方向 + 海拔 +
/// 经纬度。每个实例即「指南针表」中的一行。
@collection
class CompassRecord {
  /// 自增主键（由 Isar 分配）。
  Id id = Isar.autoIncrement;

  /// 记录点名称（用户输入，如「营地 A」「溪流交叉口」）。
  String name;

  /// 方位角（度，0=北，顺时针）。
  double heading;

  /// 方向缩写（8 向，如 "N" / "NE" / "NW"）。
  String cardinalAbbrev;

  /// 方向本地化名（如「北」/「东北」），录制时按当前语言写入。
  String cardinalName;

  /// 海拔（米），无 GPS 时为 null。
  double? altitude;

  /// 纬度（度，北纬为正），无 GPS 时为 null。
  double? latitude;

  /// 经度（度，东经为正），无 GPS 时为 null。
  double? longitude;

  /// 记录创建时间，用于排序与时间标签。
  DateTime createdAt;

  /// 创建一条指南针记录。
  ///
  /// - [name] 用户命名；[heading] 方位角；[cardinalAbbrev]/[cardinalName]
  ///   方向缩写与本地化名；[altitude]/[latitude]/[longitude] 可选 GPS；
  /// - [createdAt] 记录时间（通常由调用方传入 `DateTime.now()`）。
  CompassRecord({
    required this.name,
    required this.heading,
    required this.cardinalAbbrev,
    required this.cardinalName,
    this.altitude,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });
}
