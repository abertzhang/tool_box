// ============================================================================
// 文件：feature/profile/model/sdk_list.dart
// 模块：我的 / 个人中心（profile）/ 第三方 SDK 清单
//
// 职责：
//   定义「第三方 SDK 清单」页面的数据结构。清单正文（分组标题、字段标签、
//   每个 SDK 的用途 / 权限 / 数据说明、说明章节）不走 i18n，
//   而是拆成独立的中英文两份数据文件：
//     - data/sdk_list_en.dart（英文整篇）
//     - data/sdk_list_zh.dart（中文整篇）
//   页面按当前语言整体切换，理由见页面文件头部注释。
//
// 为什么这样设计：
//   1. 合规文档需要「整篇同语言」，中英混排会被审核方认为披露不完整；
//   2. 条目文案是长句说明，塞进 arb 会让 key 数量翻倍且难以通读校对；
//   3. 版本、包名、厂商、政策链接这些字段本就不需要翻译，
//      只有说明性长句需要，用数据文件可以按条目整体维护。
// ============================================================================

import 'package:flutter/material.dart';

/// 单个 SDK / 库的披露条目。
///
/// 字段对齐常见商店审核与「第三方信息共享清单」的要求：
/// 名称、版本、提供方、使用目的、涉及权限、数据收集情况、隐私政策链接。
@immutable
class SdkEntry {
  /// 创建一个披露条目。
  ///
  /// [sensitive] 为 true 表示该条目涉及系统权限或存在数据外传，
  /// 会被页面的「仅看敏感项」过滤保留。
  const SdkEntry({
    required this.name,
    required this.version,
    required this.vendor,
    required this.purpose,
    required this.permissions,
    required this.data,
    this.privacyUrl,
    this.sensitive = false,
  });

  /// 包 / SDK 名称（通常与 pub.dev 包名一致）。
  final String name;

  /// 实际集成版本（取自 pubspec.lock 的解析结果）。
  final String version;

  /// 提供方 / 维护方。
  final String vendor;

  /// 在本应用中的使用目的。
  final String purpose;

  /// 涉及的系统权限；不涉及则填写「无 / None」。
  final String permissions;

  /// 数据收集与外传说明；不涉及则填写「不收集 / Not collected」。
  final String data;

  /// 隐私政策或项目主页链接；为空则不展示链接行。
  final String? privacyUrl;

  /// 是否属于「敏感项」（涉及权限或数据外传），供过滤使用。
  final bool sensitive;
}

/// 一个分组（如「设备能力」「数据与存储」）。
@immutable
class SdkGroup {
  /// 创建分组。
  const SdkGroup({required this.title, required this.entries});

  /// 分组标题。
  final String title;

  /// 该组下的条目。
  final List<SdkEntry> entries;
}

/// 整篇清单内容（单一语言版本）。
///
/// 页面根据当前语言整体取用其中一份，避免中英混排。
@immutable
class SdkListContent {
  /// 创建整篇清单内容。
  const SdkListContent({
    required this.updatedAt,
    required this.intro,
    required this.filterAll,
    required this.filterSensitive,
    required this.labelVendor,
    required this.labelPurpose,
    required this.labelPermissions,
    required this.labelData,
    required this.labelPolicy,
    required this.tapCopyHint,
    required this.copiedToast,
    required this.groups,
    required this.platformTitle,
    required this.platformNote,
    required this.platforms,
    required this.noteTitle,
    required this.noteBody,
  });

  /// 清单最后更新日期（写死常量：内容没变就不该随打开时间变化）。
  final String updatedAt;

  /// 顶部引言。
  final String intro;

  /// 过滤按钮：全部。
  final String filterAll;

  /// 过滤按钮：仅看敏感项。
  final String filterSensitive;

  /// 字段标签：提供方。
  final String labelVendor;

  /// 字段标签：用途。
  final String labelPurpose;

  /// 字段标签：涉及权限。
  final String labelPermissions;

  /// 字段标签：数据收集。
  final String labelData;

  /// 字段标签：隐私政策。
  final String labelPolicy;

  /// 链接行的点击提示。
  final String tapCopyHint;

  /// 复制成功提示。
  final String copiedToast;

  /// 第三方库分组。
  final List<SdkGroup> groups;

  /// 「系统平台框架」小节标题。
  final String platformTitle;

  /// 「系统平台框架」小节说明。
  final String platformNote;

  /// 系统平台框架条目（非第三方 SDK，仅补充说明）。
  final List<SdkEntry> platforms;

  /// 末章「说明」标题。
  final String noteTitle;

  /// 末章「说明」正文。
  final String noteBody;
}
