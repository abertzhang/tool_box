import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter/material.dart';

// pixso_theme.dart
//
// 职责：将 Pixso 设计稿（浅色 / 深色两套色卡）落地为 Flutter 的 [ThemeData]，
// 提供与 Material 3 对齐的 [ColorScheme] 以及覆盖设计稿自定义表面层级与状态色的
// [PixsoTokens] 主题扩展。
// 所属模块：tool_box / common/provider/theme（主题层）。
// 关键依赖：
//  - flutter/material：ColorScheme、ThemeData、ThemeExtension 等主题基建。
//  - Pixso 色卡（设计文件 FYekMuIlOuSfICSf9bWWGw）：
//      浅色节点 15:1205 · Light Theme Color System
//      深色节点 15:1062 · Dark Theme · Apple 风格深色色彩系统
// 约定：颜色值均取自上述 Pixso 色卡；success/warning/info 等状态前景色若色卡未提供，
// 为按 M3 对比度规范推导，已在对应行内注释标注「推导」。

/// Pixso 设计稿色板（浅色 `card-light` + 深色 `card-dark`）转 Flutter 主题。
///
/// 数据源（设计文件 FYekMuIlOuSfICSf9bWWGw）：
///  - 浅色 节点 15:1205 · Light Theme Color System
///  - 深色 节点 15:1062 · Dark Theme · Apple 风格深色色彩系统
///
/// 约定：
///  - 主色 / 次色 / 文字 / 轮廓 直接映射到 Material 3 [ColorScheme] 对应字段。
///  - `lightBg/lightCard/lightDivider`（浅）与 `darkBg/darkCard/darkElevated/darkDivider`（深）
///    是设计稿自定义的表面层级，M3 没有一一对应字段，统一通过 [PixsoTokens] 扩展提供。
///  - success / warning / info 及 *Container 来自设计稿；其 `on*` 前景色为按 M3 规范推导，
///    设计稿未提供，已在注释标注。
///
/// 与现有 `app_theme.dart`（蓝色品牌）互不冲突，可并存；接入方式见 doc/pixso_color_system.md。
final class PixsoTheme {
  /// 私有构造，禁止实例化；本类仅通过 [light] / [dark] 暴露静态主题。
  PixsoTheme._();

  /// 浅色主题：组合浅色 [ColorScheme] 与浅色 [PixsoTokens] 扩展。
  static final ThemeData light = _build(pixsoLightScheme, const PixsoTokens.light());

  /// 深色主题：组合深色 [ColorScheme] 与深色 [PixsoTokens] 扩展。
  static final ThemeData dark = _build(pixsoDarkScheme, const PixsoTokens.dark());

  // 私有构建器：将 ColorScheme 与 PixsoTokens 装配为完整 ThemeData。
  // 复用同一套组装逻辑，保证两套主题在卡片圆角(16)、分隔线、表面色等细节上保持一致；
  // 设计稿自定义的表面/分隔色取自 tokens，其余走 M3 ColorScheme 标准字段。
  static ThemeData _build(ColorScheme scheme, PixsoTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.bg,
      canvasColor: tokens.bg,
      dividerColor: tokens.divider,
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}

/// 浅色模式 ColorScheme（暖米白基底 #F5F3EF）。
///
/// 颜色来源：Pixso 色卡 节点 15:1205 · Light Theme Color System。
/// 字段映射说明：
///  - `primary`(0xFF6B5C44) 暖棕主色、`secondary`(0xFF8C7A63) 暖棕次色，取自色卡 primary/secondary；
///  - `surface`(0xFFF5F3EF) 即 lightBg 页面背景，`surfaceContainerLow`(0xFFEBE7E0) 即 lightCard 卡片背景；
///  - `outlineVariant`(0xFFD1CDC4) 即 lightDivider 分隔线色；
///  - error 系列取自色卡，其 `onError` / `onErrorContainer` 为推导前景色（色卡未给）。
const ColorScheme pixsoLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6B5C44),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE8D9C4),
  onPrimaryContainer: Color(0xFF3A2E1F),

  secondary: Color(0xFF8C7A63),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF0E6D6),
  onSecondaryContainer: Color(0xFF2C1F0E),

  surface: Color(0xFFF5F3EF), // lightBg：页面/脚手架背景
  onSurface: Color(0xFF2C2924),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFEBE7E0), // lightCard：卡片/低层级容器背景
  surfaceContainer: Color(0xFFEBE7E0), // lightCard
  onSurfaceVariant: Color(0xFF7A746B),

  outline: Color(0xFFB5AFA7), // 描边/边框主色
  outlineVariant: Color(0xFFD1CDC4), // lightDivider：分隔线色

  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF), // 推导：色卡未给 error 前景，按 M3 白字对比度推导
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B), // 推导

  shadow: Color(0x1A000000),
  scrim: Color(0x66000000),
);

/// 深色模式 ColorScheme（近黑基底 #1C1C1E，Apple 风格语义色）。
///
/// 颜色来源：Pixso 色卡 节点 15:1062 · Dark Theme · Apple 风格深色色彩系统。
/// 字段映射说明：
///  - `primary`(0xFFC8A97E) 暖棕高亮主色、`secondary`(0xFFA89070) 次色，取自色卡；
///  - `surface`(0xFF1C1C1E) 即 darkBg 背景，`surfaceContainerLow`(0xFF2C2C2E) 即 darkCard；
///  - `surfaceContainerLowest`(0xFF161618) 比 darkBg 更深的层级（如导航栏/对话框底）；
///  - `outlineVariant`(0xFF48484A) 即 darkDivider 分隔线色；
///  - error(0xFFFF453A) 采用 Apple 系统红，其 `onError` / `onErrorContainer` 为推导前景色。
const ColorScheme pixsoDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFC8A97E),
  onPrimary: Color(0xFF1C1C1E),
  primaryContainer: Color(0xFF4A3C2A),
  onPrimaryContainer: Color(0xFFE8D2B2),

  secondary: Color(0xFFA89070),
  onSecondary: Color(0xFF1C1C1E),
  secondaryContainer: Color(0xFF3D3025),
  onSecondaryContainer: Color(0xFFD9C4A8),

  surface: Color(0xFF1C1C1E), // darkBg：页面/脚手架背景
  onSurface: Color(0xFFF2F2F7),
  surfaceContainerLowest: Color(0xFF161618), // 最深层级（导航栏/底部弹窗底）
  surfaceContainerLow: Color(0xFF2C2C2E), // darkCard：卡片/低层级容器背景
  surfaceContainer: Color(0xFF2C2C2E), // darkCard
  onSurfaceVariant: Color(0xFFAEAEB2),

  outline: Color(0xFF636366), // 描边/边框主色
  outlineVariant: Color(0xFF48484A), // darkDivider：分隔线色

  error: Color(0xFFFF453A),
  onError: Color(0xFF1C1C1E), // 推导：Apple 红配近黑前景
  errorContainer: Color(0xFF4D1E1B),
  onErrorContainer: Color(0xFFFFDAD6), // 推导

  shadow: Color(0x33000000),
  scrim: Color(0x99000000),
);

/// 设计稿自定义表面层级 + 状态色（success/warning/info）。
///
/// 因 Material 3 [ColorScheme] 未直接覆盖 `bg/card/elevated/divider` 与业务状态色，
/// 统一在此扩展，便于 Widget 通过 `context.pixsoTokens` 获取。
@immutable
final class PixsoTokens extends ThemeExtension<PixsoTokens> {
  /// 全参私有构造：所有颜色均需在构造时确定，外部通过命名构造 [PixsoTokens.light] /
  /// [PixsoTokens.dark] 获取成套配色，避免遗漏字段。
  const PixsoTokens({
    required this.bg,
    required this.card,
    required this.elevated,
    required this.divider,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  /// 浅色配色工厂：取浅色色卡的 bg/card/状态色。
  ///
  /// 注意：`elevated` 浅色稿未单独定义层级，回退复用 `card`(0xFFEBE7E0)，
  /// 避免浅色下出现无对应语义的悬浮色；状态前景色（on*）多为推导值，详见行内标注。
  const PixsoTokens.light()
    : bg = const Color(0xFFF5F3EF), // lightBg：页面背景
      card = const Color(0xFFEBE7E0), // lightCard：卡片背景
      elevated = const Color(0xFFEBE7E0), // 浅色稿无 elevated 层级，回退到 card
      divider = const Color(0xFFD1CDC4), // lightDivider：分隔线
      success = const Color(0xFF386A20),
      onSuccess = const Color(0xFFFFFFFF), // 推导
      successContainer = const Color(0xFFC8EFAA),
      onSuccessContainer = const Color(0xFF123921), // 推导
      warning = const Color(0xFFC97B1B),
      onWarning = const Color(0xFFFFFFFF), // 推导（白字对比度 3.32，仅建议作强调/图标）
      warningContainer = const Color(0xFFFDECD1),
      onWarningContainer = const Color(0xFF3D2600), // 推导
      info = const Color(0xFF1565C0),
      onInfo = const Color(0xFFFFFFFF), // 推导
      infoContainer = const Color(0xFFBBDEFB),
      onInfoContainer = const Color(0xFF123647); // 推导

  /// 深色配色工厂：取深色色卡的 bg/card/elevated/状态色。
  ///
  /// 注意：深色多定义了独立的 `elevated`(0xFF3A3A3C) 悬浮层级（浅色无对应），
  /// 状态前景色大多为按深色对比度推导，详见行内标注。
  const PixsoTokens.dark()
    : bg = const Color(0xFF1C1C1E), // darkBg：页面背景
      card = const Color(0xFF2C2C2E), // darkCard：卡片背景
      elevated = const Color(0xFF3A3A3C), // darkElevated：悬浮/抬升层级背景
      divider = const Color(0xFF48484A), // darkDivider：分隔线
      success = const Color(0xFF30D158),
      onSuccess = const Color(0xFF1C1C1E), // 推导
      successContainer = const Color(0xFF1A3D22),
      onSuccessContainer = const Color(0xFFB5F2C6), // 推导
      warning = const Color(0xFFFF9F0A),
      onWarning = const Color(0xFF1C1C1E), // 推导
      warningContainer = const Color(0xFF4A3200),
      onWarningContainer = const Color(0xFFFFDFA0), // 推导
      info = const Color(0xFF0A84FF),
      onInfo = const Color(0xFFFFFFFF), // 推导（白字对比度 3.65，仅建议作强调）
      infoContainer = const Color(0xFF0A2E4D),
      onInfoContainer = const Color(0xFFC5E8F7); // 推导

  /// 页面背景色（对应设计稿 lightBg / darkBg）。
  final Color bg;

  /// 卡片/低层级容器背景色（对应 lightCard / darkCard）。
  final Color card;

  /// 悬浮/抬升层级背景色（深色独立定义，浅色回退 card）。
  final Color elevated;

  /// 分隔线颜色（对应 lightDivider / darkDivider）。
  final Color divider;

  /// 成功态主色。
  final Color success;

  /// 成功态前景色（推导）。
  final Color onSuccess;

  /// 成功态容器底色。
  final Color successContainer;

  /// 成功态容器前景色（推导）。
  final Color onSuccessContainer;

  /// 警告态主色。
  final Color warning;

  /// 警告态前景色（推导）。
  final Color onWarning;

  /// 警告态容器底色。
  final Color warningContainer;

  /// 警告态容器前景色（推导）。
  final Color onWarningContainer;

  /// 信息态主色。
  final Color info;

  /// 信息态前景色（推导）。
  final Color onInfo;

  /// 信息态容器底色。
  final Color infoContainer;

  /// 信息态容器前景色（推导）。
  final Color onInfoContainer;

  /// 主题扩展必须实现的拷贝方法：仅替换非 null 的字段，其余沿用当前实例。
  ///
  /// [BuildContext] 在主题过渡等场景会调用本方法生成中间态配色。
  @override
  PixsoTokens copyWith({
    Color? bg,
    Color? card,
    Color? elevated,
    Color? divider,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return PixsoTokens(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  /// 主题扩展必须实现的插值方法：按动画进度 [t] 在 [this] 与 [other] 间逐色插值。
  ///
  /// 用于浅/深色主题切换时生成平滑过渡的中间配色；[other] 为 null 时直接返回自身。
  @override
  PixsoTokens lerp(PixsoTokens? other, double t) {
    if (other == null) return this;
    return PixsoTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// 在 [BuildContext] 上扩展 `pixsoTokens` getter，便捷获取已注入的 [PixsoTokens]。
extension PixsoTokensContext on BuildContext {
  /// 读取当前主题注入的 [PixsoTokens]。
  ///
  /// 若主题未通过 [PixsoTheme.light/dark] 注入扩展，会触发断言失败，
  /// 便于开发期快速定位「忘记装配 PixsoTokens」的问题。
  PixsoTokens get pixsoTokens {
    final PixsoTokens? tokens = Theme.of(this).extension<PixsoTokens>();
    assert(tokens != null, 'PixsoTokens 未注入 ThemeData，请检查 PixsoTheme.light/dark。');
    return tokens!;
  }
}
