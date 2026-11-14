// ============================================================================
// 文件：common/provider/app_settings/save_name_prompt_provider.dart
// 模块：common/provider/app_settings（全局设置状态层）
//
// 职责：
//   管理「保存记录时是否弹命名框」这一个全局开关，并持久化到 SharedPreferences。
//
// 需求背景：
//   各工具页（level / noise …）保存记录时原本**必定**弹出命名弹窗，快速连续测量时
//   多一次打断。改为：默认不弹框，直接用时间戳命名、一步保存；想要命名的用户
//   到 profile 设置里把开关打开即可。
//
// 为什么用 SharedPreferences 而不是 Hive：
//   这是「一个 bool 开关」级别的极简偏好，sp 读写无需开 Box、无类型适配成本；
//   Hive 仍承担语言 / 主题等结构化设置。两者分工，不混用。
//
// 用法：
//   final bool ask = ref.watch(saveNamePromptProvider).value ?? false;   // 读（默认 false）
//   await ref.read(saveNamePromptProvider.notifier).setEnabled(true);    // 写
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 生成默认记录名：**当前时间戳（毫秒级）**。
///
/// 不弹命名框时用它作为记录名，保证同时保存多条时不会重名、可按名称排序
/// （毫秒字符串等长，字典序即时间序）。
///
/// 例：`1757401234567`。
String defaultRecordName() => DateTime.now().millisecondsSinceEpoch.toString();

/// 「保存时是否弹命名框」的状态管理者，异步读取并持久化到 SharedPreferences。
///
/// 用 [AsyncNotifier] 而非 [Notifier]：sp 的 getInstance() 是异步的，
/// 与 theme_color_provider（读 Hive）保持同一套写法，便于统一理解。
class SaveNamePromptNotifier extends AsyncNotifier<bool> {
  /// sp 中的键名。
  static const String _key = 'save_name_prompt';

  @override
  Future<bool> build() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    // 默认 false：不弹框，直接用时间戳命名（保存一步到位）。
    return sp.getBool(_key) ?? false;
  }

  /// 修改并持久化开关。
  ///
  /// 参数：[enabled] true = 保存时弹命名框；false = 直接用时间戳命名。
  /// 与当前值相同时跳过写入，避免无意义的磁盘 IO 与整树重建。
  Future<void> setEnabled(bool enabled) async {
    if (state.value == enabled) return;
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, enabled);
    state = AsyncData(enabled);
  }
}

/// 「保存时是否弹命名框」Provider。
///
/// 状态为 `bool`：`true` 弹框询问名称，`false`（默认）直接用毫秒时间戳命名。
/// 读取未就绪（首帧异步加载中）时，调用方用 `?? false` 回落到默认不弹框。
final saveNamePromptProvider = AsyncNotifierProvider<SaveNamePromptNotifier, bool>(
  SaveNamePromptNotifier.new,
);
