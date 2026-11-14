// isar_service.dart
//
// Isar 本地数据库的单例服务封装。
// 所属模块：common/database（通用数据层）。
//
// 关键依赖：isar_community（本地数据库）、path_provider（获取应用文档目录）、
//           工具箱六张记录表的 Isar schema（由 build_runner 生成于各 *.g.dart）。

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

// 指南针「记录点」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/compass_record.dart';
// 噪音检测「记录」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/noise_record.dart';
// 水平仪「测量记录」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/level_record.dart';
// 直尺「测量记录」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/ruler_record.dart';
// 潮汐「历史记录」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/tide_record.dart';
// 备忘录「备忘」表（工具箱模块）：随 Isar 库统一打开。
import 'package:tool_box/feature/tool/data/model/memo_record.dart';

/// Isar 数据库服务
///
/// 单例封装 Isar 实例的初始化与访问。
/// 数据库文件存储在 getApplicationDocumentsDirectory() 下，名为 'tool_box'，
/// 包含 CompassRecord、NoiseRecord、LevelRecord、RulerRecord、TideRecord、
/// MemoRecord 共六个 collection（工具箱各子工具各占一张表）。
class IsarService {
  /// 单例实例，未初始化时为 null
  static Isar? _instance;

  /// 数据库是否已初始化（已 open 则返回 true）
  static bool get isInitialized => _instance != null;

  /// 初始化 Isar 数据库
  ///
  /// 在 App 启动时调用，注册 schema 并打开数据库。
  /// 已初始化时直接返回，不重复打开。
  static Future<Isar> initialize() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [
        CompassRecordSchema,
        NoiseRecordSchema,
        LevelRecordSchema,
        RulerRecordSchema,
        TideRecordSchema,
        MemoRecordSchema,
      ],
      directory: dir.path,
      name: 'tool_box',
    );
    debugPrint('IsarService: database opened at ${dir.path}/tool_box');
    return _instance!;
  }

  /// 获取 Isar 实例（必须先调用 initialize）
  static Isar get instance {
    if (_instance == null) {
      throw StateError('IsarService not initialized. Call initialize() first.');
    }
    return _instance!;
  }
}
