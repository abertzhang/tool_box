import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../constants/app_box.dart';

/// 文件职责：以 Riverpod（AsyncNotifier）管理应用主题模式（亮/暗/跟随系统），
/// 并与 Hive 持久化打通。
///
/// 所属模块：common/provider/theme（主题状态层）。
/// 关键依赖：[flutter_riverpod]、[hive_flutter]、[AppBox]（统一 Box 名称）。
///
/// 说明：主题以 [ThemeMode] 的索引（int）持久化在 [AppBox.boxName] 指定
/// Box 的 `theme_mode` 键下。由于初始化依赖异步读取 Hive，本类使用
/// [AsyncNotifier] 以 `AsyncData<ThemeMode>` 表达加载完成后的状态。

/// 主题状态管理者，异步加载并持久化 [ThemeMode]。
class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  static const String _themeKey = "theme_mode";
  @override
  Future<ThemeMode> build() async {
    // 从 Hive 读取持久化的主题索引；无记录时默认跟随系统
    final Box box = Hive.box(AppBox.boxName);
    int index = box.get(_themeKey) ?? ThemeMode.system.index;
    // 防御：若存储的索引越界（如枚举变更），回落到系统默认，避免取值崩溃
    if (index >= ThemeMode.values.length) {
      index = ThemeMode.system.index;
    }
    return ThemeMode.values[index];
  }

  /// 切换并持久化主题模式。
  ///
  /// 参数：[mode] 目标 [ThemeMode]，其索引会被写入 Hive，
  /// 并通过 [AsyncData] 更新状态以通知监听者。
  Future<void> setMode(ThemeMode mode) async {
    final box = await Hive.openBox(AppBox.boxName);
    await box.put(_themeKey, mode.index);
    state = AsyncData(mode);
  }

  /// 在亮色与暗色之间快速切换（系统模式时视为非亮色，回落到暗色）。
  Future<void> toggleLightDark() async {
    if (state == AsyncData(ThemeMode.light)) {
      await setMode(ThemeMode.dark);
    } else {
      await setMode(ThemeMode.light);
    }
  }
}

/// 主题状态 Provider，对外暴露 [ThemeNotifier] 及其 [ThemeMode] 状态。
final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
