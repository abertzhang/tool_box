// tool_panel_palette.dart
//
// 工具箱（tool）模块共享的「面板」视觉与基础组件。
// 所属模块：feature/tool/shared（跨子工具复用）。
// 设计依据：Pixso 浅色 / 深色双主题色板（与 Compass/Noise/Level 同源），
//          逐项硬编码，避免深浅串色。
//
// 复用说明：
//   - [ToolPanelPalette]：卡片 / 按钮 / 文字统一色板，[ToolPanelPalette.of]
//     根据当前主题亮度返回对应版本。水平仪页、直尺页均直接 import 本文件复用，
//     不再各自维护私有 _PanelPalette，避免多份重复定义。
//   - [ReadingItem]：读数项（标签在上、数值在下），各工具读数卡 / 历史卡通用。
//   - [HistoryPlaceholder]：历史区占位（加载中 / 暂无记录）。

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';

/// 工具箱面板双主题色板（卡片 / 按钮 / 文字）。
///
/// 深浅两版逐项硬编码，确保明暗切换不串色。水平仪、直尺等子工具页
/// 通过 [ToolPanelPalette.of] 获取与当前主题匹配的实例。
class ToolPanelPalette {
  const ToolPanelPalette({
    required this.pageBg,
    required this.cardBg,
    required this.cardBorder,
    required this.titleText,
    required this.labelText,
    required this.valueText,
    required this.accent,
    required this.recordBtnText,
    required this.secondaryBtnBg,
    required this.divider,
    required this.muted,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 卡片背景色。
  final Color cardBg;

  /// 卡片描边色。
  final Color cardBorder;

  /// 标题文字色（AppBar / 区块标题）。
  final Color titleText;

  /// 次级标签文字色（时间 / 描述）。
  final Color labelText;

  /// 数值主文字色。
  final Color valueText;

  /// 强调色（主按钮底色 / 图标）。
  final Color accent;

  /// 主按钮文字色（在强调底色上的反白文字）。
  final Color recordBtnText;

  /// 次按钮底色（浅奶白）。
  final Color secondaryBtnBg;

  /// 分隔线色。
  final Color divider;

  /// 弱化文字 / 图标色（删除图标、空态）。
  final Color muted;

  /// 根据当前主题返回对应色板实例。
  ///
  /// 本页全部字段都是通用语义色（页面底 / 卡片 / 文字 / 强调 / 分隔线），
  /// 且咖啡色两套取值与 [AppPalette] 的 coffee 版逐项一致，
  /// 故统一取自 [AppPalette]：既响应「主题色方案（咖啡色 / 蓝色）」，
  /// 也响应「明暗模式」，切换色卡时本页随之变色。
  static ToolPanelPalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return ToolPanelPalette(
        pageBg: app.pageBg,
        cardBg: app.cardBg,
        cardBorder: app.cardBorder,
        titleText: app.titleText,
        labelText: app.labelText,
        valueText: app.valueText,
        accent: app.accent,
        // 主按钮文字为强调底色上的反白字，随 [AppPalette.accentText] 走：
        // 蓝色深色主题下强调色是亮蓝，此时需用深蓝字才够对比度。
        recordBtnText: app.accentText,
        // 设计稿深色态次按钮亦为浅奶白底（按钮组保持与当前色卡一致）。
        secondaryBtnBg: app.secondaryBtnBg,
        divider: app.divider,
        muted: app.muted,
      );
    }
    return ToolPanelPalette(
      pageBg: app.pageBg,
      cardBg: app.cardBg,
      cardBorder: app.cardBorder,
      titleText: app.titleText,
      labelText: app.labelText,
      valueText: app.valueText,
      accent: app.accent,
      recordBtnText: app.accentText,
      secondaryBtnBg: app.secondaryBtnBg,
      divider: app.divider,
      muted: app.muted,
    );
  }
}

/// 读数项（标签在上、数值在下）。
///
/// 各工具读数卡与历史卡通用：标签用弱化灰，数值用传入主色与字号/字重。
class ReadingItem extends StatelessWidget {
  const ReadingItem({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.valueSize,
    required this.valueWeight,
  });

  /// 标签文案（如「垂直角度」）。
  final String label;

  /// 数值文案（已格式化）。
  final String value;

  /// 数值颜色。
  final Color valueColor;

  /// 数值字号（逻辑像素，外部已乘 .sp）。
  final double valueSize;

  /// 数值字重。
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize.sp,
            fontWeight: valueWeight,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// 历史区占位（加载中 / 暂无记录）。
///
/// 通用于各工具的历史列表空态，文案由调用方传入。
class HistoryPlaceholder extends StatelessWidget {
  const HistoryPlaceholder({super.key, required this.text});

  /// 占位文案（如「暂无记录」）。
  final String text;

  @override
  Widget build(BuildContext context) {
    final ToolPanelPalette p = ToolPanelPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontSize: 13.sp, color: p.labelText)),
    );
  }
}
