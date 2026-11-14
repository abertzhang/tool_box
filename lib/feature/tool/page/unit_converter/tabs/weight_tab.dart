// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/weight_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：重量（质量）换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置。TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-weight（浅）/ unit-conversion-重量-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 重量（质量）分类配置（基准单位：千克 kg）。
///
/// factor 含义：1 个该单位 = factor 个千克。斤=0.5kg，两=0.05kg（市制）。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildWeightCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'kilogram', label: l10n.unitKilogram, factor: 1),
    UcUnit(key: 'gram', label: l10n.unitGram, factor: 0.001),
    UcUnit(key: 'milligram', label: l10n.unitMilligram, factor: 0.000001),
    UcUnit(key: 'ton', label: l10n.unitTon, factor: 1000),
    UcUnit(key: 'pound', label: l10n.unitPound, factor: 0.45359237),
    UcUnit(key: 'ounce', label: l10n.unitOunce, factor: 0.028349523125),
    UcUnit(key: 'jin', label: l10n.unitJin, factor: 0.5),
    UcUnit(key: 'liang', label: l10n.unitLiang, factor: 0.05),
  ],
  formula: '1 ${l10n.unitKilogram} = 2.2046 ${l10n.unitPound}',
  common: <String>[
    '1 ${l10n.unitKilogram} = 1000 ${l10n.unitGram}',
    '1 ${l10n.unitJin} = 0.5 ${l10n.unitKilogram}',
    '1 ${l10n.unitPound} = 0.4536 ${l10n.unitKilogram}',
    '1 ${l10n.unitTon} = 1000 ${l10n.unitKilogram}',
  ],
);

/// 重量换算页签。
class WeightTab extends StatelessWidget {
  /// 创建重量换算页签（无参数）。
  const WeightTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'weight', category: _buildWeightCategory(l10n));
  }
}
