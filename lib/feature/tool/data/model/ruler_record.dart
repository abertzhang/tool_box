// ruler_record.dart
//
// 直尺（Ruler）工具的「测量记录」表模型。
// 所属模块：feature/tool/data/model（工具箱数据层）。
// 关键依赖：isar_community（@collection 注解 + 自动生成 schema）。
//
// 复用说明：与 compass_record / noise_record / level_record 同源，
// 长度以「毫米」为基准存储，展示时再按 cm / inch 换算，避免精度损失。

import 'package:isar_community/isar.dart';

// 由 build_runner 依据 @collection 自动生成 schema 与集合扩展。
part 'ruler_record.g.dart';

/// 直尺测量记录。
///
/// 一条记录代表一次测量：在屏幕直尺上拖出起点与终点，得到长度（毫米）。
/// 命名可选，未命名时回退到默认标题。
@collection
class RulerRecord {
  /// 主键，Isar 自增。
  Id id = Isar.autoIncrement;

  /// 记录名称（可选）。留空表示未命名，展示时用默认标题。
  String? name;

  /// 测量长度（毫米）。基准单位，展示时换算 cm / inch。
  double lengthMm;

  /// 保存时选用的主单位：'cm' 或 'in'（仅用于历史卡片标注）。
  String unit;

  /// 创建时间，用于历史列表排序（倒序）与时间格式化。
  DateTime createdAt;

  /// 构造方法。
  ///
  /// [name] 可选；[lengthMm] 为测量长度（毫米）；[unit] 为主单位
  /// （'cm' / 'in'）；[createdAt] 为记录时间。
  RulerRecord({
    this.name,
    required this.lengthMm,
    required this.unit,
    required this.createdAt,
  });
}
