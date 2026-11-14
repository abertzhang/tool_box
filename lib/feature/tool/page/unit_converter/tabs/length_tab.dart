// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/length_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：长度换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置。本分类是设计稿中 TabBar 的初始高亮项。TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-conversion-page（浅）/ unit-conversion-长度-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 长度分类配置（基准单位：米 m）。
///
/// factor 含义：1 个该单位 = factor 个米。mi=英里，ft=英尺，in=英寸，yd=码，nmi=海里。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildLengthCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'meter', label: l10n.unitMeter, factor: 1),
    UcUnit(key: 'kilometer', label: l10n.unitKilometer, factor: 1000),
    UcUnit(key: 'centimeter', label: l10n.unitCentimeter, factor: 0.01),
    UcUnit(key: 'millimeter', label: l10n.unitMillimeter, factor: 0.001),
    UcUnit(key: 'mile', label: l10n.unitMile, factor: 1609.344),
    UcUnit(key: 'foot', label: l10n.unitFoot, factor: 0.3048),
    UcUnit(key: 'inch', label: l10n.unitInch, factor: 0.0254),
    UcUnit(key: 'yard', label: l10n.unitYard, factor: 0.9144),
    UcUnit(key: 'nautical_mile', label: l10n.unitNauticalMile, factor: 1852),
  ],
  formula: '1 ${l10n.unitMeter} = 3.2808 ${l10n.unitFoot}',
  common: <String>[
    '1 ${l10n.unitKilometer} = 1000 ${l10n.unitMeter}',
    '1 ${l10n.unitMile} = 1.609 ${l10n.unitKilometer}',
    '1 ${l10n.unitFoot} = 0.3048 ${l10n.unitMeter}',
    '1 ${l10n.unitInch} = 2.54 ${l10n.unitCentimeter}',
    '1 ${l10n.unitNauticalMile} = 1.852 ${l10n.unitKilometer}',
  ],
);

/// 长度换算页签。
class LengthTab extends StatelessWidget {
  /// 创建长度换算页签（无参数）。
  const LengthTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'length', category: _buildLengthCategory(l10n));
  }
}
