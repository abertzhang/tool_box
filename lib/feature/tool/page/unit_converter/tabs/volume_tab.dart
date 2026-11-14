// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/volume_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：体积换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置。TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-volume（浅）/ unit-conversion-体积-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 体积分类配置（基准单位：升 L）。
///
/// factor 含义：1 个该单位 = factor 个升。美制单位采用美液体加仑等标准系数。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildVolumeCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'liter', label: l10n.unitLiter, factor: 1),
    UcUnit(key: 'milliliter', label: l10n.unitMilliliter, factor: 0.001),
    UcUnit(key: 'cubic_meter', label: l10n.unitCubicMeter, factor: 1000),
    UcUnit(key: 'cubic_centimeter', label: l10n.unitCubicCentimeter, factor: 0.001),
    UcUnit(key: 'gallon', label: l10n.unitGallon, factor: 3.785411784),
    UcUnit(key: 'quart', label: l10n.unitQuart, factor: 0.946352946),
    UcUnit(key: 'pint', label: l10n.unitPint, factor: 0.473176473),
    UcUnit(key: 'cup', label: l10n.unitCup, factor: 0.2365882365),
    UcUnit(key: 'cubic_foot', label: l10n.unitCubicFoot, factor: 28.316846592),
    UcUnit(key: 'cubic_inch', label: l10n.unitCubicInch, factor: 0.016387064),
  ],
  formula: '1 ${l10n.unitLiter} = 0.2642 ${l10n.unitGallon}',
  common: <String>[
    '1 ${l10n.unitLiter} = 1000 ${l10n.unitMilliliter}',
    '1 ${l10n.unitCubicMeter} = 1000 ${l10n.unitLiter}',
    '1 ${l10n.unitGallon} = 3.785 ${l10n.unitLiter}',
    '1 ${l10n.unitCup} = 236.6 ${l10n.unitMilliliter}',
  ],
);

/// 体积换算页签。
class VolumeTab extends StatelessWidget {
  /// 创建体积换算页签（无参数）。
  const VolumeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'volume', category: _buildVolumeCategory(l10n));
  }
}
