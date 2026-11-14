import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// 文件职责：封装 YAML 配置文件的读取能力，支持从「文件系统路径」
/// 与「Flutter assets 资源」两种方式加载。
///
/// 所属模块：common/utils（通用工具层）。
/// 关键依赖：[yaml]（解析 YAML）、[flutter/services]（读取 assets）。
class YamlUtil {
  /// 从文件系统的绝对/相对路径加载 YAML 文件。
  ///
  /// 参数：[filePath] 目标 yaml 文件的路径（相对路径基于进程工作目录）。
  ///
  /// 返回：解析后的 [YamlMap]，文件不存在时返回 `null`（不抛异常），
  /// 便于调用方做「可选配置」降级处理。
  // 读取根目录下相对路径的yaml文件
  static Future<YamlMap?> loadFile(String filePath) async {
    // 当前项目根目录下 config/app_config.yaml
    final file = File(filePath);
    if (!await file.exists()) {
      // throw Exception('配置文件不存在');
      return null;
    }
    final content = await file.readAsString();
    return loadYaml(content);
  }
  // 读取资源文件夹assets的yaml，需要配置好地址

  /// 从 Flutter assets 中加载 YAML 文件。
  ///
  /// 参数：[asset] 资源路径，需在 `pubspec.yaml` 的 `assets:` 下已正确声明，
  /// 否则会抛出资源未找到异常。
  ///
  /// 返回：解析后的 [YamlMap]。
  static Future<YamlMap?> loadAssetsFile(String asset) async {
    final String yamlStr = await rootBundle.loadString(asset);
    return loadYaml(yamlStr);
  }
}
