// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/speed_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：速度换算 TabView。复用共享组件 [UcConverterTab]，仅提供本分类的
// [UcCategory] 配置。TabBar 头部不在本文件。
// 设计稿：pixso 5:2 中 unit-speed（浅）/ unit-conversion-速度-dark（深）。
// ============================================================================

import 'package:flutter/material.dart';

import 'package:tool_box/l10n/app_localizations.dart';
import 'uc_converter_tab.dart';

/// 速度分类配置（基准单位：米/秒 m/s）。
///
/// factor 含义：1 个该单位 = factor 个米/秒。mph=英里/时，kn=节(海里/时)。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
UcCategory _buildSpeedCategory(AppLocalizations l10n) => UcCategory(
  units: <UcUnit>[
    UcUnit(key: 'meter_per_sec', label: l10n.unitMeterPerSec, factor: 1),
    UcUnit(key: 'km_per_hour', label: l10n.unitKmPerHour, factor: 0.2777778), // 1000/3600
    UcUnit(key: 'mile_per_hour', label: l10n.unitMilePerHour, factor: 0.44704), // 1609.344/3600
    UcUnit(key: 'foot_per_sec', label: l10n.unitFootPerSec, factor: 0.3048),
    UcUnit(key: 'knot', label: l10n.unitKnot, factor: 0.5144444), // 1852/3600
  ],
  formula: '1 ${l10n.unitMeterPerSec} = 3.6 ${l10n.unitKmPerHour}',
  common: <String>[
    '1 ${l10n.unitKmPerHour} = 0.2778 ${l10n.unitMeterPerSec}',
    '1 ${l10n.unitMilePerHour} = 1.609 ${l10n.unitKmPerHour}',
    '1 ${l10n.unitKnot} = 1.852 ${l10n.unitKmPerHour}',
    '1 ${l10n.unitMeterPerSec} = 3.281 ${l10n.unitFootPerSec}',
  ],
);

/// 速度换算页签。
class SpeedTab extends StatelessWidget {
  /// 创建速度换算页签（无参数）。
  const SpeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UcConverterTab(trackCategory: 'speed', category: _buildSpeedCategory(l10n));
  }
}
