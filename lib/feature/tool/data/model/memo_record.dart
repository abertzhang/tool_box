// memo_record.dart
//
// 备忘录（Memo）工具的「备忘」表模型。
// 所属模块：feature/tool/data/model（工具箱数据层）。
// 关键依赖：isar_community（@collection 注解 + 自动生成 schema）。
//
// 复用说明：与 tide_record / ruler_record 等同源，统一由 IsarService 在
// 同一 Isar 库（tool_box）中打开，无需新建数据库。一条记录即一条用户备忘
// （标题 + 正文 + 创建 / 更新时间），便于历史回溯与编辑。

import 'package:isar_community/isar.dart';

// 由 build_runner 依据 @collection 自动生成 schema 与集合扩展。
part 'memo_record.g.dart';

/// 备忘。
///
/// 记录用户随手记下的一条备忘：标题、正文、创建时间与最后更新时间。
/// [id] 为自增主键；[createdAt]/[updatedAt] 为真实时间戳，
/// 列表按 [updatedAt] 倒序展示（最近编辑的在最前）。
@collection
class MemoRecord {
  /// 主键，Isar 自增。
  Id id = Isar.autoIncrement;

  /// 备忘标题（如「出差清单」）。
  String title;

  /// 备忘正文（想记下的任意内容）。
  String content;

  /// 创建时间。
  DateTime createdAt;

  /// 最后更新时间，用于列表排序（倒序）。
  DateTime updatedAt;

  /// 构造方法。
  ///
  /// 各参数含义见字段注释；[title]/[content] 为必填正文，
  /// 时间字段由调用方在落库前填入当前时间。
  MemoRecord({
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}
