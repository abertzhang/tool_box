// ============================================================================
// 文件：common/provider/theme/theme_color_provider.dart
// 模块：common/provider/theme（主题状态层）
//
// 职责：
//   管理「主题色方案」（咖啡色 / 蓝色）的选择与持久化，与既有
//   [themeProvider]（亮/暗模式）正交：前者决定用哪套色卡，
//   后者决定取该色卡的浅色版还是深色版。
//
// 关键依赖：
//   - flutter_riverpod：AsyncNotifier 表达「异步读 Hive」的加载态。
//   - hive_flutter：持久化键 `theme_color`，存枚举索引（int）。
//   - AppBox：统一 Box 名称，避免各处散落字符串常量。
//
// 设计说明：
//   之所以与 ThemeNotifier 分开而不是塞进同一个类，是因为两者的变化维度不同
//   且互不依赖（切换色卡不影响亮暗、切换亮暗不影响色卡）。拆开后
//   MaterialApp 只需各自 watch 一次，任一变化都能独立触发重建。
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../constants/app_box.dart';

/// 可选的主题色方案。
///
/// 每个枚举值对应 `common/provider/theme/` 下的一套完整 ThemeData 实现：
/// - [coffee]：暖棕咖啡色（AppTheme），工程默认，主色 #6B5C44。
/// - [blue]：晴空蓝（SkyTheme），新增备选，主色 #4290E8。
///
/// ⚠️ 枚举顺序即持久化索引，**只允许在末尾追加**，中间插入会导致
/// 老用户读到的索引指向错误方案（虽有越界兜底，但语义会错）。
enum AppThemeColor {
  /// 咖啡色主题（默认）。
  coffee,

  /// 蓝色主题。
  blue,
}

/// 主题色方案的状态管理者，异步加载并持久化 [AppThemeColor]。
class ThemeColorNotifier extends AsyncNotifier<AppThemeColor> {
  /// Hive 中保存主题色方案的键名。
  static const String _themeColorKey = 'theme_color';

  @override
  Future<AppThemeColor> build() async {
    // 从 Hive 读取持久化的方案索引；无记录时默认咖啡色。
    final Box box = Hive.box(AppBox.boxName);
    final int index = box.get(_themeColorKey) ?? AppThemeColor.coffee.index;
    // 防御：索引越界（如枚举变更、脏数据）时回落默认方案，避免取值崩溃。
    if (index < 0 || index >= AppThemeColor.values.length) {
      return AppThemeColor.coffee;
    }
    return AppThemeColor.values[index];
  }

  /// 切换并持久化主题色方案。
  ///
  /// 参数：[color] 目标方案，其索引会被写入 Hive，
  /// 并通过 [AsyncData] 更新状态以通知监听者（触发 MaterialApp 重建）。
  Future<void> setColor(AppThemeColor color) async {
    // 已是当前方案则跳过写入，避免无意义的磁盘 IO 与整树重建。
    if (state.value == color) return;
    final Box box = await Hive.openBox(AppBox.boxName);
    await box.put(_themeColorKey, color.index);
    state = AsyncData(color);
  }
}

/// 主题色方案 Provider，对外暴露 [ThemeColorNotifier] 及其 [AppThemeColor] 状态。
final themeColorProvider =
    AsyncNotifierProvider<ThemeColorNotifier, AppThemeColor>(
  ThemeColorNotifier.new,
);
