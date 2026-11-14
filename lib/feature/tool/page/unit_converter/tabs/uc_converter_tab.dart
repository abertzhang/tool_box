// ============================================================================
// 文件：feature/tool/page/unit_converter/tabs/uc_converter_tab.dart
// 模块：工具箱（tool）→ 单位换算
//
// 职责：
//   单位换算的「共享」TabView 组件。所有分类（面积/体积/温度/速度/重量/长度）
//   复用本文件，仅在各自的 tab 文件中传入一份 [UcCategory] 配置即可，避免
//   6 个分类各写一遍重复的 UI 与换算逻辑。
//
//   页面内容（与设计稿 5:2 中每个分类页一致，TabBar 头部不在此处）：
//   1) 顶部「换算公式」提示卡；
//   2) 主换算卡：上下两个输入框，各带单位下拉选择 + 数值，中间「交换」按钮，
//      选中单位后实时双向换算；
//   3) 「常用换算」参考网格：若干「1 X = Y Z」对照卡。
//
// 设计稿配色（逐项硬编码，避免深浅串色，取自 5:2 浅色 unit-* / 深色 unit-conversion-*-dark）：
//   浅色：卡底 #FFFFFF / 强调棕 #8B5C44（结果值）/ 文字 #2C2924 / 下拉底 #EBE7E0。
//   深色：卡底 #2C2C2E / 浅棕 #E0926D（结果值）/ 白字 / 下拉底 #3A3A3C / 交换钮 #B87B5C。
//
// 关键依赖：
//   - flutter_screenutil_plus：响应式尺寸（.w / .h / .r / .sp）。
//   - 不引入 intl（避免与 ruler_page 同样的 TextDirection 遮蔽冲突），数值格式化自写。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 单个计量单位定义。
///
/// [label] 为展示名（含符号，如「平方米 (m²)」）；[factor] 表示
/// 「1 个该单位 = factor 个基准单位」（线性换算用）。[tempKey] 仅温度类使用，
/// 取值 'C'/'F'/'K'，用于偏移量换算（线性因子不适用）。
class UcUnit {
  /// 创建单位定义。
  const UcUnit({
    required this.key,
    required this.label,
    this.factor = 1,
    this.tempKey,
  });

  /// 埋点用的稳定单位标识（snake_case，如 `kilogram_force`）。
  ///
  /// 为什么不能直接用 [label]：label 是 [AppLocalizations] 解析出的多语言文案，
  /// 同一个单位在中英文下是两个不同字符串，拿它当埋点维度会把
  /// 「米 → 英尺」和「Meter → Foot」拆成两行，统计不出真实的高频单位对。
  final String key;

  /// 展示名（中文 + 符号）。
  final String label;

  /// 相对基准单位的线性因子（1 单位 = factor 基准单位）。
  final double factor;

  /// 温度标识（'C'/'F'/'K'），非温度分类为 null。
  final String? tempKey;
}

/// 一个换算分类的完整配置（数据驱动 UI）。
///
/// 各 tab 文件持有各自的 [UcCategory] 常量，传给 [UcConverterTab] 即可渲染。
class UcCategory {
  /// 创建分类配置。
  const UcCategory({
    required this.units,
    required this.formula,
    required this.common,
    this.temperature = false,
  });

  /// 该分类支持的单位列表（长度即单位个数）。
  final List<UcUnit> units;

  /// 公式卡文案（不含「换算公式：」前缀，前缀由 i18n 提供）。
  final String formula;

  /// 常用换算对照文本列表（如 "1 公顷 (ha) = 2.471 英亩 (ac)"）。
  final List<String> common;

  /// 是否为温度分类（温度用偏移公式而非线性因子）。
  final bool temperature;
}

/// 单位换算内容区双主题色板。
///
/// 颜色取自 Pixso 5:2 设计稿（浅色 unit-* / 深色 unit-conversion-*-dark）。
/// 通用语义色（卡片 / 文字 / 下拉底 / 交换钮 / 分隔线）取自 [AppPalette]，
/// 随「色卡（咖啡 / 蓝）+ 明暗」两个维度变化；公式文字·底色、结果值色与深色
/// 交换钮底属设计稿固定语义色，在 AppPalette 中无同值字段，保留硬编码。
class _UcContentTheme {
  /// 创建内容区双主题色板。
  const _UcContentTheme({
    required this.cardBg,
    required this.formulaText,
    required this.formulaBg,
    required this.resultText,
    required this.labelText,
    required this.sectionTitle,
    required this.dropdownBg,
    required this.dropdownText,
    required this.swapBg,
    required this.swapIcon,
    required this.divider,
  });

  /// 卡片底色（主换算卡 / 常用对照卡）。
  final Color cardBg;

  /// 公式卡文字（强调色）。
  final Color formulaText;

  /// 公式卡底色（强调色低透明度的淡底）。
  final Color formulaBg;

  /// 结果值文字（换算结果、常用对照的等号右侧，强调色）。
  final Color resultText;

  /// 标签文字（单位名、常用对照的等号左侧、主卡输入值）。
  final Color labelText;

  /// 区块标题文字（「常用换算」）。
  final Color sectionTitle;

  /// 单位下拉选择器底色（pill）。
  final Color dropdownBg;

  /// 单位下拉文字色。
  final Color dropdownText;

  /// 交换按钮底色（强调色）。
  final Color swapBg;

  /// 交换按钮图标色（反白）。
  final Color swapIcon;

  /// 交换行分隔线颜色。
  final Color divider;

  /// 按当前主题返回色板实例。
  ///
  /// 通用语义色（卡片 / 文字 / 下拉底 / 交换钮 / 分隔线）统一取自 [AppPalette]，
  /// 使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」两个维度的切换。
  /// 公式文字·公式底色·结果值色是设计稿的「强调色 + 提亮档 + 低透明度淡底」
  /// 组合，深色档（#E0926D / #26B87B5C）在 AppPalette 中无同值字段，
  /// 浅色分隔线 #E5E0D8 亦为设计稿独立取值，均保留常量避免视觉回归。
  static _UcContentTheme of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return _UcContentTheme(
        cardBg: app.cardBg,
        // 公式文字 / 底色 / 结果值：设计稿固定的强调提亮档，不随色卡变化。
        formulaText: const Color(0xFFE0926D),
        formulaBg: const Color(0x26B87B5C),
        resultText: const Color(0xFFE0926D),
        labelText: app.titleText,
        sectionTitle: app.titleText,
        dropdownBg: app.fieldBg,
        dropdownText: app.titleText,
        // 深色交换钮是设计稿提亮档，AppPalette 无同值字段。
        swapBg: const Color(0xFFB87B5C),
        // 与上面的深色 swapBg 配对：底为提亮棕，图标须保持反白，
        // 故不取 [AppPalette.accentText]（蓝色深底为深蓝，压在此底上对比度不足）。
        swapIcon: const Color(0xFFFFFFFF),
        divider: app.divider,
      );
    }
    return _UcContentTheme(
      // 浅色下卡片为「浮起」的白卡，取抬升卡片色。
      cardBg: app.cardElevated,
      // 浅色下公式文字与结果值即强调色，取 [AppPalette.accent] 以跟随色卡切换。
      formulaText: app.accent,
      // 公式底色是强调色的低透明度淡底，无对应语义字段，保留设计稿取值。
      formulaBg: const Color(0x148B5C44),
      resultText: app.accent,
      labelText: app.titleText,
      sectionTitle: app.titleText,
      dropdownBg: app.fieldBg,
      dropdownText: app.titleText,
      swapBg: app.accent,
      swapIcon: app.accentText,
      // 设计稿独立取值，比 AppPalette.divider 略暖一档。
      divider: const Color(0xFFE5E0D8),
    );
  }
}

/// 单位换算 TabView（共享组件）。
///
/// 由各自分类 tab 文件传入 [category] 配置，渲染「公式卡 + 主换算卡 + 常用换算」。
/// 支持双向实时换算：编辑上方输入框重算下方，编辑下方重算上方；
/// 交换按钮互换两侧单位。温度分类走偏移公式，其余走线性因子。
class UcConverterTab extends StatefulWidget {
  /// 创建换算 TabView。
  ///
  /// - [category]：单位 / 公式 / 常用对照配置；
  /// - [trackCategory]：埋点用的稳定分类标识（snake_case）。
  ///   传入 `'force'` 时上报 [TrackEvents.convForceConvert]，其余上报
  ///   [TrackEvents.convUnitConvert] 并把本值作为 `category` 参数。
  const UcConverterTab({
    super.key,
    required this.category,
    required this.trackCategory,
  });

  /// 当前分类配置（单位 / 公式 / 常用对照）。
  final UcCategory category;

  /// 埋点分类标识。
  ///
  /// 刻意与 [category] 解耦：[category] 里的文案全是多语言字符串，
  /// 无法作为埋点维度；分类身份必须由调用方显式给出。
  final String trackCategory;

  @override
  State<UcConverterTab> createState() => _UcConverterTabState();
}

class _UcConverterTabState extends State<UcConverterTab> {
  // 上、下两侧当前选中的单位下标（初始为前两个单位）。
  late int _topIdx;
  late int _bottomIdx;

  // 上、下两侧输入框控制器；双向绑定，编辑一侧重算另一侧。
  final TextEditingController _topCtrl = TextEditingController(text: '1');
  final TextEditingController _bottomCtrl = TextEditingController();

  /// 是否已完成首帧初始化。
  ///
  /// [initState] 里会调一次 [_recomputeFromTop] 来给下方输入框填初值，
  /// 那是程序行为不是用户换算，不能记进埋点 —— 否则每次打开页面都白送一条
  /// 「1 米 → 3.28 英尺」，把真实的用户换算分布稀释掉。
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _topIdx = 0;
    // 下方默认取第二个单位（若只有 1 个单位则仍为 0）。
    _bottomIdx = widget.category.units.length > 1 ? 1 : 0;
    _recomputeFromTop();
    _ready = true;
  }

  @override
  void dispose() {
    _topCtrl.dispose();
    _bottomCtrl.dispose();
    super.dispose();
  }

  /// 数值格式化：去除无意义的尾随零，最多保留 6 位小数。
  ///
  /// 例如 10.764000 → "10.764"，1.0 → "1"，0.09290304 → "0.092903"。
  String _format(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    // 整数直接输出，避免 "1.0"。
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    String s = value.toStringAsFixed(6);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  /// 核心换算：把 [value] 从 [fromIdx] 单位换算到 [toIdx] 单位。
  double _convert(double value, int fromIdx, int toIdx) {
    final List<UcUnit> units = widget.category.units;
    if (widget.category.temperature) {
      // 温度：先转到摄氏度基准，再转到目标。
      final double c = _toCelsius(value, units[fromIdx].tempKey);
      return _fromCelsius(c, units[toIdx].tempKey);
    }
    // 线性：value × 源因子 = 基准值；基准值 ÷ 目标因子 = 目标值。
    final double base = value * units[fromIdx].factor;
    return base / units[toIdx].factor;
  }

  /// 温度转摄氏度（基准）。
  double _toCelsius(double v, String? key) {
    switch (key) {
      case 'C':
        return v;
      case 'F':
        return (v - 32) * 5 / 9;
      case 'K':
        return v - 273.15;
      default:
        return v;
    }
  }

  /// 摄氏度转目标温度。
  double _fromCelsius(double v, String? key) {
    switch (key) {
      case 'C':
        return v;
      case 'F':
        return v * 9 / 5 + 32;
      case 'K':
        return v + 273.15;
      default:
        return v;
    }
  }

  /// 上方输入框变化 → 重算下方。
  ///
  /// 本方法是**全 App 最高频**的埋点触发点：每敲一个字符都会进来一次，
  /// 直接埋点的话输入 "12.75" 就是 5 条事件。故一律先过 [AppTrack.throttle]
  /// ——1.5 秒内的连续输入合并成一条，量级立刻降一个数量级，
  /// 且不丢失「用户确实做过这次换算」这个事实（我们要的是分布，不是逐次明细）。
  void _recomputeFromTop() {
    final double v = double.tryParse(_topCtrl.text) ?? 0;
    _bottomCtrl.text = _format(_convert(v, _topIdx, _bottomIdx));
    if (_ready && AppTrack.throttle.allow('conv_${widget.trackCategory}')) {
      _logConvert(swapped: false);
    }
  }

  /// 下方输入框变化 → 重算上方（节流逻辑同 [_recomputeFromTop]）。
  void _recomputeFromBottom() {
    final double v = double.tryParse(_bottomCtrl.text) ?? 0;
    _topCtrl.text = _format(_convert(v, _bottomIdx, _topIdx));
    if (_ready && AppTrack.throttle.allow('conv_${widget.trackCategory}')) {
      _logConvert(swapped: false);
    }
  }

  /// 交换两侧单位（并同步交换显示数值，使交互符合直觉）。
  ///
  /// 交换是**离散动作**（一次点击一次结果），不需要节流，
  /// 且用 `swapped: true` 单独标记 —— 交换占比高说明默认单位对选错了方向。
  void _swap() {
    setState(() {
      final int tmp = _topIdx;
      _topIdx = _bottomIdx;
      _bottomIdx = tmp;
      final String tmpText = _topCtrl.text;
      _topCtrl.text = _bottomCtrl.text;
      _bottomCtrl.text = tmpText;
    });
    _logConvert(swapped: true);
  }

  /// 上报一次换算。
  ///
  /// - [swapped]：本次是否由「交换」按钮触发。
  ///
  /// 上报的是**单位对**（from_unit → to_unit）而非换算数值：
  /// 找出最高频的单位对并设为默认选中项，才是这个埋点的决策价值；
  /// 具体数值属于用户输入，既无分析价值也不能上传（隐私红线）。
  void _logConvert({required bool swapped}) {
    final List<UcUnit> units = widget.category.units;
    final bool isForce = widget.trackCategory == 'force';
    AppTrack.log(
      isForce ? TrackEvents.convForceConvert : TrackEvents.convUnitConvert,
      params: <String, Object?>{
        // 力换算页独立成事件，不带 category（它只有一个分类，带上反而是冗余维度）。
        if (!isForce) 'category': widget.trackCategory,
        'from_unit': units[_topIdx].key,
        'to_unit': units[_bottomIdx].key,
        'swapped': swapped,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final _UcContentTheme theme = _UcContentTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<UcUnit> units = widget.category.units;

    return SingleChildScrollView(
      // 顶部避让 AppBar 由父页处理；此处仅做内容内边距。
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) 换算公式提示卡。
          _FormulaCard(
            theme: theme,
            text: '${l10n.ucFormula}${widget.category.formula}',
          ),
          SizedBox(height: 16.h),
          // 2) 主换算卡：上方输入 + 交换 + 下方输入。
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              children: [
                // 上方：源单位输入（标签色文字）。
                _InputRow(
                  theme: theme,
                  units: units,
                  selectedIdx: _topIdx,
                  controller: _topCtrl,
                  valueColor: theme.labelText,
                  onUnitChanged: (idx) {
                    setState(() => _topIdx = idx);
                    _recomputeFromTop();
                  },
                  onChanged: _recomputeFromTop,
                ),
                SizedBox(height: 8.h),
                // 交换分隔行：左右分隔线 + 居中交换按钮。
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.divider, thickness: 1),
                    ),
                    Container(
                      width: 36.w,
                      height: 36.h,
                      margin: EdgeInsets.symmetric(horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: theme.swapBg,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: IconButton(
                        onPressed: _swap,
                        icon: Icon(
                          Icons.swap_vert,
                          color: theme.swapIcon,
                          size: 18,
                        ),
                        // 去掉默认内边距，让图标填满 36 圆钮。
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.divider, thickness: 1),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // 下方：目标单位输入（结果强调色文字）。
                _InputRow(
                  theme: theme,
                  units: units,
                  selectedIdx: _bottomIdx,
                  controller: _bottomCtrl,
                  valueColor: theme.resultText,
                  onUnitChanged: (idx) {
                    setState(() => _bottomIdx = idx);
                    _recomputeFromBottom();
                  },
                  onChanged: _recomputeFromBottom,
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // 3) 常用换算区块。
          Text(
            l10n.ucCommon,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: theme.sectionTitle,
            ),
          ),
          SizedBox(height: 12.h),
          _CommonGrid(theme: theme, items: widget.category.common),
        ],
      ),
    );
  }
}

/// 单个输入行：左侧单位下拉 pill + 右侧数值输入框。
class _InputRow extends StatelessWidget {
  /// 创建输入行。
  const _InputRow({
    required this.theme,
    required this.units,
    required this.selectedIdx,
    required this.controller,
    required this.valueColor,
    required this.onChanged,
    required this.onUnitChanged,
  });

  /// 内容区主题色板。
  final _UcContentTheme theme;

  /// 可选单位列表。
  final List<UcUnit> units;

  /// 当前选中单位下标。
  final int selectedIdx;

  /// 数值输入框控制器。
  final TextEditingController controller;

  /// 数值文字颜色（上方标签色 / 下方结果强调色）。
  final Color valueColor;

  /// 数值变化回调（重算另一侧）。
  final VoidCallback onChanged;

  /// 单位切换回调。
  final ValueChanged<int> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧单位下拉选择器（pill 样式）。
        Container(
          height: 33.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: theme.dropdownBg,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: DropdownButton<UcUnit>(
            value: units[selectedIdx],
            // 去掉默认下划线。
            underline: const SizedBox.shrink(),
            isExpanded: false,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: theme.dropdownText,
            ),
            style: TextStyle(color: theme.dropdownText, fontSize: 13.sp),
            items: [
              for (int i = 0; i < units.length; i++)
                DropdownMenuItem<UcUnit>(
                  value: units[i],
                  child: Text(
                    units[i].label,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
            ],
            onChanged: (UcUnit? u) {
              if (u == null) return;
              onUnitChanged(units.indexOf(u));
            },
          ),
        ),
        SizedBox(width: 10.w),
        // 右侧数值输入框（右对齐，仅允许数字与小数点）。
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: valueColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              // 无边框无下划线，纯文本输入，贴合设计稿的裸数值样式。
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

/// 换算公式提示卡（顶部）。
class _FormulaCard extends StatelessWidget {
  /// 创建公式卡。
  const _FormulaCard({required this.theme, required this.text});

  /// 内容区主题色板。
  final _UcContentTheme theme;

  /// 公式文案（已含「换算公式：」前缀）。
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.formulaBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.formulaText),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.formulaText,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「常用换算」对照网格（2 列）。
class _CommonGrid extends StatelessWidget {
  /// 创建常用换算网格。
  const _CommonGrid({required this.theme, required this.items});

  /// 内容区主题色板。
  final _UcContentTheme theme;

  /// 对照文本列表（如 "1 公顷 (ha) = 2.471 英亩 (ac)"）。
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final String item in items)
          SizedBox(
            // 两列等宽：总宽减间距后除以 2。
            width: (1.sw - 48.w - 10.w) / 2,
            child: Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: theme.cardBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: theme.labelText,
                  fontSize: 13.sp,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
