// ============================================================================
// 文件：feature/tool/page/force_converter_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   拉力 / 承重换算器页。把「力 / 承重」相关单位（牛顿、千牛、千克力、
//   磅力、吨力）做双向实时换算。UI 直接复用单位换算模块的共享组件
//   [UcConverterTab]（含公式卡 + 主换算卡 + 常用换算网格），本页只负责
//   提供一份力单位分类配置 [UcCategory]，零重复实现换算交互。
//
// 设计稿：
//   无独立 Pixso 稿，沿用单位换算（5:2）已有的双主题配色（浅 #F5F3EF /
//   深 #1C1C1E 页面底，卡片配色由 UcConverterTab 内部色板管控），保持
//   工具箱视觉一致。
//
// 关键依赖：
//   - flutter_screenutil_plus：响应式尺寸（.w / .h / .r / .sp）。
//   - UcConverterTab：来自 unit_converter/tabs/uc_converter_tab.dart，
//     其 [UcUnit]/[UcCategory] 为公开类，可被本页直接引用。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';
import 'package:tool_box/feature/tool/page/unit_converter/tabs/uc_converter_tab.dart';

/// 拉力 / 承重换算器页。
///
/// 复用 [UcConverterTab]，仅传入力单位分类配置；页面自身只管 AppBar 与背景。
class ForceConverterPage extends StatelessWidget {
  /// 创建拉力 / 承重换算器页（无参数）。
  const ForceConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // 页面背景改从语义色板取：使其跟随「主题色方案 + 明暗」两个维度，
    // 切到蓝色主题后与单位换算页同步变蓝（二者共用同一套色板）。
    final Color pageBg = AppPalette.of(context).pageBg;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        // 标题居中显示，与工具箱既有页面风格一致。
        centerTitle: true,
        title: Text(l10n.forceTitle),
      ),
      body: UcConverterTab(trackCategory: 'force', category: _buildForceCategory(l10n)),
    );
  }
}

/// 力 / 承重单位换算分类配置（数据驱动 [UcConverterTab]）。
///
/// 以「牛顿 (N)」为基准单位（factor=1），其余单位按与 N 的换算关系给出线性因子：
/// - 千牛 kN = 1000 N
/// - 千克力 kgf ≈ 9.80665 N（标准重力加速度下 1 kg 质量所受重力）
/// - 磅力 lbf ≈ 4.44822 N
/// - 吨力 tf = 1000 kgf ≈ 9806.65 N（公吨力）
/// 全部为线性因子，[UcConverterTab] 用 value × 源factor ÷ 目标factor 即可换算。
/// 力 / 承重单位换算分类配置（数据驱动 [UcConverterTab]）。
///
/// 以「牛顿 (N)」为基准单位（factor=1），其余单位按与 N 的换算关系给出线性因子：
/// - 千牛 kN = 1000 N
/// - 千克力 kgf ≈ 9.80665 N（标准重力加速度下 1 kg 质量所受重力）
/// - 磅力 lbf ≈ 4.44822 N
/// - 吨力 tf = 1000 kgf ≈ 9806.65 N（公吨力）
/// 全部为线性因子，[UcConverterTab] 用 value × 源factor ÷ 目标factor 即可换算。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildForceCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'newton', label: l10n.unitNewton, factor: 1),
    UcUnit(key: 'kilonewton', label: l10n.unitKilonewton, factor: 1000),
    UcUnit(key: 'kilogram_force', label: l10n.unitKilogramForce, factor: 9.80665),
    UcUnit(key: 'pound_force', label: l10n.unitPoundForce, factor: 4.44822),
    UcUnit(key: 'ton_force', label: l10n.unitTonForce, factor: 9806.65),
  ],
  // 公式卡文案（前缀「换算公式：」由 i18n 提供）。
  formula: '1 ${l10n.unitKilogramForce} ≈ 9.80665 ${l10n.unitNewton}',
  // 「常用换算」对照网格内容。
  common: <String>[
    '1 ${l10n.unitKilonewton} = 101.97 ${l10n.unitKilogramForce}',
    '1 ${l10n.unitKilogramForce} = 2.2046 ${l10n.unitPoundForce}',
    '1 ${l10n.unitTonForce} = 9.80665 ${l10n.unitKilonewton}',
    '1 ${l10n.unitPoundForce} = 4.44822 ${l10n.unitNewton}',
  ],
);
