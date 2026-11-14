// level_record.dart
//
// 水平仪「测量记录」的 Isar 本地持久化模型（即需求中的「水平仪表」）。
// 所属模块：feature/tool（工具箱）· 水平仪子工具。
// 关键依赖：isar_community（本地数据库）；生成的 `level_record.g.dart`
//           提供 Isar schema（由 build_runner 基于本文件自动生成，请勿手改）。
//
// 职责：
//   用户在水平仪页点击「保存测量」时，把当前垂直角度（Y 轴）、水平角度（X 轴）、
//   自动判定的状态（水平/接近水平/倾斜）、命名 + 时间戳写入此表。
//   历史记录列表即从此表读取，实现「水平仪表」的本地持久化与回看。
//
// 设计要点：
//   - verticalAngle / horizontalAngle 保存录制瞬间的角度（单位：度，已按 ±90° 钳制）；
//   - status 保存状态「键」(level/near/tilt) 而非本地化文案，
//     使历史记录不依赖录制时的语言，展示时再按当前语言还原；
//   - name 为可空字符串：用户可留空，留空时历史卡片显示默认标题；
//   - createdAt 用于历史列表按时间倒序展示，并作卡片上的「时间」标签。

import 'package:isar_community/isar.dart';

part 'level_record.g.dart';

/// 一条水平仪测量记录（「水平仪表」中的一行）。
///
/// 对应设计稿 Pixso 186:17 中的一条 history-card：
/// 状态标签 + 状态描述 + 垂直/水平角度 + 时间 + 名称。
@collection
class LevelRecord {
  /// 自增主键（由 Isar 分配）。
  Id id = Isar.autoIncrement;

  /// 记录名称（用户输入，如「营地摄影三脚架」「帐篷支架校准」）；
  /// 可空：未填写时历史卡片显示默认标题。
  String? name;

  /// 录制的垂直角度（度，对应设计稿「垂直角度 (Y-Axis)」，已钳制 ±90°）。
  double verticalAngle;

  /// 录制的水平角度（度，对应设计稿「水平角度 (X-Axis)」，已钳制 ±90°）。
  double horizontalAngle;

  /// 状态键：level（水平）/ near（接近水平）/ tilt（倾斜）。
  /// 录制时按最大倾角阈值自动判定，展示时再映射为本地化文案。
  String status;

  /// 记录创建时间，用于排序与时间标签。
  DateTime createdAt;

  /// 创建一条水平仪测量记录。
  ///
  /// - [name] 可选命名；[verticalAngle]/[horizontalAngle] 角度（度）；
  /// - [status] 状态键；[createdAt] 记录时间（通常 `DateTime.now()`）。
  LevelRecord({
    this.name,
    required this.verticalAngle,
    required this.horizontalAngle,
    required this.status,
    required this.createdAt,
  });
}
