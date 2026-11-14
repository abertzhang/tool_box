/// 文件职责：定义应用全局使用的 Hive 存储盒子（Box）名称常量。
///
/// 所属模块：common/constants（通用常量层）。
/// 关键依赖：无第三方依赖，仅作为字符串常量供需要本地持久化的模块
/// （provider、http 等）统一引用，避免散落的硬编码字面量。
class AppBox {
  /// 应用统一的 Hive Box 名称。
  ///
  /// 所有需要本地持久化的数据（语言、主题等）都应存放于该 Box 下，
  /// 便于统一管理其生命周期与初始化时机。
  static const String boxName = 'KnotBox';
}
