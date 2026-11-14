// ============================================================================
// 文件：common/provider/theme/app_palette.dart
// 模块：common/provider/theme（主题色板层）
//
// 职责：
//   定义一套**语义化**的应用色板，作为「主题色方案（咖啡色 / 蓝色）× 明暗模式」
//   两个正交维度的产物，供全工程页面取色。
//
// 为什么需要它：
//   工程里各页面原本各自维护私有色板（_TideTheme / _MemoTheme / ToolPanelPalette …），
//   内部按 `Theme.of(context).brightness` 返回深浅两版**硬编码**常量。
//   这套写法只能响应明暗切换，无法响应色卡切换——页面会永远停留在咖啡色。
//   改为统一从本类取色后：色卡切换 → MaterialApp 换 ThemeData →
//   注入的 AppPalette 实例变化 → 各页色板随之变化，页面本身无需改动。
//
// 关键约束（改值时务必遵守）：
//   - **coffee 两套取值必须与此前各页硬编码逐项一致**，否则切回咖啡色主题会
//     出现视觉回归。新增/修改值前先 grep 页面里的旧值核对。
//   - blue 两套按「同结构、同层级」推导：pageBg 与 cardBg 保持同样的明暗落差，
//     文字色保持同样的对比度级别，accent 取 SkyTheme 的主色（深色下提亮一档）。
//   - 语义固定色（如会员金 gold）**不随色卡变化**，两套共用同一组值。
//
// 用法：
//   final p = AppPalette.of(context);   // 已含色卡 + 明暗
//   color: p.pageBg
// ============================================================================

import 'package:flutter/material.dart';

/// 应用语义色板：主题色方案 × 明暗模式 的产物。
///
/// 通过 [ThemeData.extensions] 注入（由 AppTheme 注入 coffee 版、
/// SkyTheme 注入 blue 版），页面用 [AppPalette.of] 读取。
class AppPalette extends ThemeExtension<AppPalette> {
  /// 创建语义色板（各字段含义见对应 getter 注释）。
  const AppPalette({
    required this.pageBg,
    required this.cardBg,
    required this.cardElevated,
    required this.cardBorder,
    required this.titleText,
    required this.bodyText,
    required this.labelText,
    required this.valueText,
    required this.hintText,
    required this.accent,
    required this.accentText,
    required this.secondaryBtnBg,
    required this.fieldBg,
    required this.divider,
    required this.muted,
    required this.danger,
    required this.gold,
    required this.headerGrad,
    required this.featuredGrad,
  });

  // ==========================================================================
  // 四套预设：coffee / blue × light / dark
  // ==========================================================================

  /// 咖啡色 · 浅色：暖米白底 + 米色卡片，主色暖棕 #8B5C44。
  ///
  /// 取值与各页原有硬编码逐项一致，保证改造后咖啡色主题视觉零变化。
  static const AppPalette coffeeLight = AppPalette(
    pageBg: Color(0xFFF5F3EF),
    cardBg: Color(0xFFEBE7E0),
    cardElevated: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE4E0D9),
    titleText: Color(0xFF2C2924),
    bodyText: Color(0xFF5A544C),
    labelText: Color(0xFF7A746B),
    valueText: Color(0xFF2C2924),
    hintText: Color(0xFF9A928A),
    accent: Color(0xFF8B5C44),
    accentText: Color(0xFFFFFFFF),
    secondaryBtnBg: Color(0xFFF5F0E9),
    fieldBg: Color(0xFFEBE7E0),
    divider: Color(0xFFE4E0D9),
    muted: Color(0xFFB5AFA7),
    danger: Color(0xFFC0392B),
    // 会员金：品牌固定色，不随色卡变化。
    gold: Color(0xFFC9971E),
    headerGrad: <Color>[Color(0xFFB89B72), Color(0xFFF5F3EF)],
    // 特色卡（tools 页顶部 Travel Memo 整行卡）渐变：暖金 → 深金棕。
    // 取值与原 _ToolPalette 硬编码一致，保证咖啡色主题视觉零变化。
    featuredGrad: <Color>[Color(0xFFC8A97E), Color(0xFFA8845A)],
  );

  /// 咖啡色 · 深色：近黑底 + 深灰卡片。
  ///
  /// ⚠️ [accent] 沿用浅色同值 #8B5C44：工程内多数页面（潮汐、水平仪、工具面板）
  /// 深色态强调色本就与浅色一致，此处若改成提亮色会造成视觉回归。
  static const AppPalette coffeeDark = AppPalette(
    pageBg: Color(0xFF1C1C1E),
    cardBg: Color(0xFF2C2C2E),
    cardElevated: Color(0xFF2C2C2E),
    cardBorder: Color(0xFF3A3A3C),
    titleText: Color(0xFFFFFFFF),
    bodyText: Color(0xFFD0D0D2),
    labelText: Color(0xFFA1A1AA),
    valueText: Color(0xFFFFFFFF),
    hintText: Color(0xFF8E8E93),
    accent: Color(0xFF8B5C44),
    accentText: Color(0xFFFFFFFF),
    secondaryBtnBg: Color(0xFFF5F0E9),
    fieldBg: Color(0xFF3A3A3C),
    divider: Color(0xFF3A3A3C),
    muted: Color(0xFF8A8A8E),
    danger: Color(0xFFE57373),
    gold: Color(0xFFE5C158),
    headerGrad: <Color>[Color(0xFF4A3520), Color(0xFF1A1A1E)],
    // 特色卡渐变（深色咖啡）：与浅色同为暖金系、整体压暗一档。
    featuredGrad: <Color>[Color(0xFFB8935E), Color(0xFF8A6840)],
  );

  /// 蓝色 · 浅色：浅蓝底 #F0F7FD + 白卡片（靠白色形成层次，与 SkyTheme 设计一致），
  /// 主色晴空蓝 #4290E8。
  static const AppPalette blueLight = AppPalette(
    pageBg: Color(0xFFF0F7FD),
    cardBg: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE1EAF4),
    titleText: Color(0xFF1A1A1A),
    bodyText: Color(0xFF3C3C3C),
    labelText: Color(0xFF666666),
    valueText: Color(0xFF1A1A1A),
    hintText: Color(0xFF9AA5B1),
    accent: Color(0xFF4290E8),
    accentText: Color(0xFFFFFFFF),
    secondaryBtnBg: Color(0xFFE8F1FC),
    fieldBg: Color(0xFFF7FAFE),
    divider: Color(0xFFE1EAF4),
    muted: Color(0xFFA9B6C4),
    danger: Color(0xFFD93025),
    // 会员金保持品牌金色：蓝色主题下金色徽章仍是最高等级的视觉锚点。
    gold: Color(0xFFC9971E),
    headerGrad: <Color>[Color(0xFF9CC8F0), Color(0xFFF0F7FD)],
    // 特色卡渐变（浅色蓝）：亮蓝 → 中蓝，与咖啡浅色保持同样的明暗落差。
    featuredGrad: <Color>[Color(0xFF79B8F3), Color(0xFF3D7CC4)],
  );

  /// 蓝色 · 深色：深蓝夜空底 #0F1620，主色提亮为 #79B8F3 保证深底对比度。
  ///
  /// ⚠️ [accentText] 用深蓝而非白色：深底主色已是亮蓝，白字对比度不足，
  /// 与 SkyTheme.darkScheme 的 onPrimary 取值保持一致。
  static const AppPalette blueDark = AppPalette(
    pageBg: Color(0xFF0F1620),
    cardBg: Color(0xFF161E29),
    cardElevated: Color(0xFF1A232F),
    cardBorder: Color(0xFF2A3542),
    titleText: Color(0xFFFFFFFF),
    bodyText: Color(0xFFC7D3E0),
    labelText: Color(0xFFA3AEBB),
    valueText: Color(0xFFFFFFFF),
    hintText: Color(0xFF6E8296),
    accent: Color(0xFF79B8F3),
    accentText: Color(0xFF0A2A45),
    secondaryBtnBg: Color(0xFF1B2A3A),
    fieldBg: Color(0xFF1B2A3A),
    divider: Color(0xFF2A3542),
    muted: Color(0xFF5A6B7D),
    danger: Color(0xFFFF8A80),
    gold: Color(0xFFE5C158),
    headerGrad: <Color>[Color(0xFF123A5C), Color(0xFF0F1620)],
    // 特色卡渐变（深色蓝）：与深色咖啡同结构——整体压暗一档的蓝系渐变，
    // 深底上仍保持足够白字对比度。
    featuredGrad: <Color>[Color(0xFF5F9FE6), Color(0xFF2C5A93)],
  );

  // ==========================================================================
  // 语义色字段
  // ==========================================================================

  /// 页面背景色（scaffold 底）。
  final Color pageBg;

  /// 常规卡片底色（与页面底同色系、略深或略浅，形成层次）。
  final Color cardBg;

  /// 抬升卡片底色（需要「浮起」时用，如白卡）。
  final Color cardElevated;

  /// 卡片描边色。
  final Color cardBorder;

  /// 主文字色（标题、卡片主文案）。
  final Color titleText;

  /// 正文文字色（比 [titleText] 略弱一档）。
  final Color bodyText;

  /// 次级标签文字色（时间、描述、单位）。
  final Color labelText;

  /// 数值主文字色（读数、金额等强调数字）。
  final Color valueText;

  /// 占位 / 提示文字色（输入框 hint、空态说明）。
  final Color hintText;

  /// 强调色（主按钮底色、选中态、强调图标）—— 主题色方案的**核心体现**。
  final Color accent;

  /// 强调色底上的文字色（保证对比度，深色蓝主题下为深蓝而非白色）。
  final Color accentText;

  /// 次按钮底色（浅奶白 / 浅蓝白）。
  final Color secondaryBtnBg;

  /// 输入框 / 次级填充底色。
  final Color fieldBg;

  /// 分隔线色。
  final Color divider;

  /// 弱化色（禁用态、次要图标、低潮圆点）。
  final Color muted;

  /// 危险操作色（删除、错误）。
  final Color danger;

  /// 会员金：品牌固定色，两套主题共用，不随色卡变化。
  final Color gold;

  /// 顶部区域渐变（起色 → 止色，止色通常为 [pageBg]）。
  final List<Color> headerGrad;

  /// 特色卡（tools 页顶部 Travel Memo 整行卡）渐变起止色。
  ///
  /// 与 [headerGrad] 的区别：headerGrad 止色是页面底色（用于页面顶部纵深感），
  /// featuredGrad 两端都是**主色系**（整卡铺满的视觉焦点），随色卡切换。
  final List<Color> featuredGrad;

  // ==========================================================================
  // 读取入口
  // ==========================================================================

  /// 从当前主题读取已注入的色板。
  ///
  /// 主题切换时 [ThemeData.extensions] 会整体替换，故本方法自动返回
  /// 「当前色卡 + 当前明暗」对应的那一套。
  static AppPalette of(BuildContext context) {
    // 兜底：极端情况下（如页面在 MaterialApp 之外构建）回落咖啡色浅色版，
    // 保证不会因取不到扩展而崩溃。
    return Theme.of(context).extension<AppPalette>() ?? coffeeLight;
  }

  @override
  AppPalette copyWith({
    Color? pageBg,
    Color? cardBg,
    Color? cardElevated,
    Color? cardBorder,
    Color? titleText,
    Color? bodyText,
    Color? labelText,
    Color? valueText,
    Color? hintText,
    Color? accent,
    Color? accentText,
    Color? secondaryBtnBg,
    Color? fieldBg,
    Color? divider,
    Color? muted,
    Color? danger,
    Color? gold,
    List<Color>? headerGrad,
    List<Color>? featuredGrad,
  }) {
    return AppPalette(
      pageBg: pageBg ?? this.pageBg,
      cardBg: cardBg ?? this.cardBg,
      cardElevated: cardElevated ?? this.cardElevated,
      cardBorder: cardBorder ?? this.cardBorder,
      titleText: titleText ?? this.titleText,
      bodyText: bodyText ?? this.bodyText,
      labelText: labelText ?? this.labelText,
      valueText: valueText ?? this.valueText,
      hintText: hintText ?? this.hintText,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      secondaryBtnBg: secondaryBtnBg ?? this.secondaryBtnBg,
      fieldBg: fieldBg ?? this.fieldBg,
      divider: divider ?? this.divider,
      muted: muted ?? this.muted,
      danger: danger ?? this.danger,
      gold: gold ?? this.gold,
      headerGrad: headerGrad ?? this.headerGrad,
      featuredGrad: featuredGrad ?? this.featuredGrad,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      titleText: Color.lerp(titleText, other.titleText, t)!,
      bodyText: Color.lerp(bodyText, other.bodyText, t)!,
      labelText: Color.lerp(labelText, other.labelText, t)!,
      valueText: Color.lerp(valueText, other.valueText, t)!,
      hintText: Color.lerp(hintText, other.hintText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      secondaryBtnBg: Color.lerp(secondaryBtnBg, other.secondaryBtnBg, t)!,
      fieldBg: Color.lerp(fieldBg, other.fieldBg, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      headerGrad: <Color>[
        for (int i = 0; i < headerGrad.length; i++)
          Color.lerp(headerGrad[i], other.headerGrad[i], t)!,
      ],
      featuredGrad: <Color>[
        for (int i = 0; i < featuredGrad.length; i++)
          Color.lerp(featuredGrad[i], other.featuredGrad[i], t)!,
      ],
    );
  }
}
