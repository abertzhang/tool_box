// tide_record.dart
//
// 潮汐（Tide）工具的「历史记录」表模型。
// 所属模块：feature/tool/data/model（工具箱数据层）。
// 关键依赖：isar_community（@collection 注解 + 自动生成 schema）。
//
// 复用说明：与 compass_record / noise_record / level_record / ruler_record 同源，
// 一次「记录当前」即生成一条记录：保存当时潮型、潮高、观测点与时间，便于历史回溯。

import 'package:isar_community/isar.dart';

// 由 build_runner 依据 @collection 自动生成 schema 与集合扩展。
part 'tide_record.g.dart';

/// 潮汐历史记录。
///
/// 一条记录对应一次「记录当前」操作，把当时的潮型（涨/退/满/低）、
/// 潮高（米）、观测点名称与经纬度、记录时间一并落库。
/// [recordDate] 为展示用日期文案（mock 场景直接存字符串，避免再次解析）；
/// [createdAt] 为真实时间戳，用于历史列表排序（倒序）。
@collection
class TideRecord {
  /// 主键，Isar 自增。
  Id id = Isar.autoIncrement;

  /// 观测点名称（如「金沙滩 • 1号观测点」）。
  String location;

  /// 经纬度文案（如「N 36.04° E 120.35°」）。
  String coords;

  /// 潮型文案：满潮 / 低潮 / 涨潮中 / 退潮中。
  String tideType;

  /// 潮高（米）。
  double height;

  /// 涨 / 退标记：true=涨潮（trending-up 图标），false=退潮（trending-down）。
  bool isRising;

  /// 展示用日期文案（如「10月10日 19:20」），直接用于历史卡片，免去二次格式化。
  String recordDate;

  /// 创建时间，用于历史列表倒序排序。
  DateTime createdAt;

  /// 构造方法。
  ///
  /// 各参数含义见字段注释；[isRising] 决定历史卡片右侧趋势图标方向。
  TideRecord({
    required this.location,
    required this.coords,
    required this.tideType,
    required this.height,
    required this.isRising,
    required this.recordDate,
    required this.createdAt,
  });
}
