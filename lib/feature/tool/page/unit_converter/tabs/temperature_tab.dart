// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/temperature_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：温度换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置。温度是特例：走偏移公式而非线性因子，故 units 的
// [UcUnit.tempKey] 标为 'C'/'F'/'K'，且 [UcCategory.temperature] 为 true。
// TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-temperature（浅）/ unit-conversion-温度-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 温度分类配置（基准：摄氏度 °C）。
///
/// 线性因子不适用，tempKey 标识各单位的偏移换算类型。换算公式与常用换算式为纯
/// 符号表达式，无需本地化；仅单位名称依赖 [AppLocalizations]，故整体为方法而非 const。
UcCategory _buildTemperatureCategory(AppLocalizations l10n) => UcCategory(
  temperature: true,
  units: <UcUnit>[
    UcUnit(key: 'celsius', label: l10n.unitCelsius, tempKey: 'C'),
    UcUnit(key: 'fahrenheit', label: l10n.unitFahrenheit, tempKey: 'F'),
    UcUnit(key: 'kelvin', label: l10n.unitKelvin, tempKey: 'K'),
  ],
  formula: '°C = (°F − 32) × 5/9',
  common: <String>[
    '0 °C = 32 °F',
    '100 °C = 212 °F',
    '0 °C = 273.15 K',
    '37 °C = 98.6 °F',
  ],
);

/// 温度换算页签。
class TemperatureTab extends StatelessWidget {
  /// 创建温度换算页签（无参数）。
  const TemperatureTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'temp', category: _buildTemperatureCategory(l10n));
  }
}
