import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 文件职责：定义应用设置（语言 + 主题）的数据模型与 Riverpod 状态管理。
///
/// 所属模块：common/provider/app_settings（全局设置状态层）。
/// 关键依赖：[flutter_riverpod]（状态管理）、[hive]（本地持久化）。
///
/// 说明：语言与主题均持久化到名为 `app_settings` 的 Hive Box 中，
/// 应用启动时通过 [AppSettingsNotifier.build] 读取并恢复。

/// 应用设置的不可变数据模型，包含语言代码与主题模式。
final class AppSettings {
  /// 语言代码，如 `en` / `zh`。
  final String languageCode;
  /// 主题模式（亮色 / 暗色 / 跟随系统）。
  final ThemeMode themeMode;

  AppSettings({required this.languageCode, required this.themeMode});

  /// 基于当前实例生成一个副本，仅替换传入的非空字段。
  ///
  /// 参数：[languageCode] / [themeMode] 为可选，传 `null` 时沿用原值。
  /// 返回：新的 [AppSettings] 实例（保持不可变特性）。
  AppSettings clone({String? languageCode, ThemeMode? themeMode}) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// 语言与主题的全局状态管理者，负责读写 Hive 并对外暴露更新方法。
final class AppSettingsNotifier extends Notifier<AppSettings> {
  final Box _box = Hive.box('app_settings');
  @override
  AppSettings build() {
    final lang = _box.get('lang', defaultValue: 'en');
    final themeIdx = _box.get('theme', defaultValue: 0);
    // 将持久化的整数索引还原为对应的 ThemeMode（默认回落到亮色）
    final theme = switch (themeIdx) {
      1 => ThemeMode.dark,
      2 => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return AppSettings(languageCode: lang, themeMode: theme);
  }

  /// 切换应用语言并持久化。
  ///
  /// 参数：[langCode] 目标语言代码，会写入 Hive 的 `lang` 键，
  /// 并通过 [Notifier.state] 通知监听者刷新。
  Future<void> setLanguage(String langCode) async {
    await _box.put('lang', langCode);
    state = state.clone(languageCode: langCode);
  }

  /// 切换主题模式并持久化。
  ///
  /// 参数：[mode] 目标 [ThemeMode]，会转换为整数索引写入 Hive 的 `theme` 键。
  Future<void> setThemeMode(ThemeMode mode) async {
    // 将 ThemeMode 映射回整数索引以便持久化
    final index = switch (mode) {
      ThemeMode.light => 0,
      ThemeMode.dark => 1,
      ThemeMode.system => 2,
    };
    await _box.put('theme', index);
    state = state.clone(themeMode: mode);
  }
}
