// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/area_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：面积换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置（单位列表 / 公式文案 / 常用对照）。TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-area（浅）/ unit-conversion-面积-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 面积分类配置（基准单位：平方米 m²）。
///
/// factor 含义：1 个该单位 = factor 个平方米。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildAreaCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'square_meter', label: l10n.unitSquareMeter, factor: 1),
    UcUnit(key: 'square_kilometer', label: l10n.unitSquareKilometer, factor: 1000000),
    UcUnit(key: 'hectare', label: l10n.unitHectare, factor: 10000),
    UcUnit(key: 'mu', label: l10n.unitMu, factor: 666.6667),
    UcUnit(key: 'square_foot', label: l10n.unitSquareFoot, factor: 0.09290304),
    UcUnit(key: 'square_mile', label: l10n.unitSquareMile, factor: 2589988.110336),
    UcUnit(key: 'square_yard', label: l10n.unitSquareYard, factor: 0.83612736),
    UcUnit(key: 'acre', label: l10n.unitAcre, factor: 4046.8564224),
    UcUnit(key: 'square_inch', label: l10n.unitSquareInch, factor: 0.00064516),
  ],
  formula: '1 ${l10n.unitSquareMeter} = 10.7639 ${l10n.unitSquareFoot}',
  common: <String>[
    '1 ${l10n.unitHectare} = 2.471 ${l10n.unitAcre}',
    '1 ${l10n.unitSquareMeter} = 10.764 ${l10n.unitSquareFoot}',
    '1 ${l10n.unitSquareKilometer} = 0.386 ${l10n.unitSquareMile}',
    '1 ${l10n.unitMu} = 666.7 ${l10n.unitSquareMeter}',
  ],
);

/// 面积换算页签。
class AreaTab extends StatelessWidget {
  /// 创建面积换算页签（无参数）。
  const AreaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'area', category: _buildAreaCategory(l10n));
  }
}
