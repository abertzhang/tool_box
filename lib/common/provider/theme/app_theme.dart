// app_theme.dart
//
// 职责：定义 tool_box 应用的「蓝色品牌」默认主题（浅色/深色），并通过 [ToolBoxThemeColors]
// 主题扩展补充 Material 3 未覆盖的业务状态色与装饰色；同时抽取品牌基础色常量供全局复用。
// 所属模块：tool_box / common/provider/theme（主题层）。
// 关键依赖：
//  - flutter/material：ColorScheme、ThemeData、ThemeExtension 等主题基建。
//  - Pixso 色卡（设计文件 FYekMuIlOuSfICSf9bWWGw）：
//      浅色节点 15:1205 · Light Theme Color System
//      深色节点 15:1062 · Dark Theme · Apple 风格深色色彩系统
// 说明：与 `pixso_theme.dart` 并存，本文件侧重于品牌色与更完整的组件级样式
// （按钮/输入/导航栏/对话框等），颜色来源同样标注于对应行内注释。

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'app_palette.dart';

/// 应用主题装配中心。
///
/// 职责：持有品牌基础色常量，并提供浅色 [light] / 深色 [dark] 两套完整 [ThemeData]。
/// 两套主题均由私有 [_build] 基于对应 [ColorScheme] 与 [ToolBoxThemeColors] 扩展统一生成，
/// 以保证组件级样式（按钮、输入框、导航栏等）在深浅模式下表现一致。
class AppTheme {
  /// 私有构造，禁止实例化；本类仅暴露静态常量与静态主题。
  AppTheme._();

  // 品牌基础色值统一抽取，供业务层直接引用，避免散落硬编码。
  /// 品牌主色（暖棕 #6B5C44）。
  ///
  /// 取代原蓝色品牌 #4286D8，取自 Pixso 色卡 primary，作为应用核心品牌色。
  static const Color brandPrimary = Color(
    0xFF6B5C44,
  ); // 取代蓝品牌 #4286D8 → 色卡 primary

  /// 品牌行动色（暖棕次色 #8C7A63）。
  ///
  /// 取代原蓝色品牌 #4088F0，取自 Pixso 色卡 secondary，用于强调按钮等行动点。
  static const Color brandAction = Color(
    0xFF8C7A63,
  ); // 取代蓝品牌 #4088F0 → 色卡 secondary

  /// 链接蓝（#3E87E9）：用于可点击文本链接，独立于品牌暖棕，保留可读性。
  static const Color linkBlue = Color(0xFF3E87E9);

  /// 成功绿（#34A853）：业务通用成功状态色，不在 M3 ColorScheme 内，故单独抽取。
  static const Color successGreen = Color(0xFF34A853);

  /// 浅色主题：组合浅色 [lightScheme] 与浅色 [ToolBoxThemeColors] 扩展。
  static final ThemeData light = _build(
    lightScheme,
    const ToolBoxThemeColors.light(),
  );

  /// 深色主题：组合深色 [darkScheme] 与深色 [ToolBoxThemeColors] 扩展。
  static final ThemeData dark = _build(
    darkScheme,
    const ToolBoxThemeColors.dark(),
  );

  // 浅色模式 ColorScheme（暖米白基底 #F5F3EF，取自 Pixso 色卡 card-light 节点 15:1205）
  static ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6B5C44), // 取代蓝品牌 #4286D8 → 暖棕 #6B5C44
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE8D9C4),
    onPrimaryContainer: Color(0xFF3A2E1F),

    secondary: Color(0xFF8C7A63), // 取代蓝品牌 #4088F0 → 暖棕次色 #8C7A63
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF0E6D6),
    onSecondaryContainer: Color(0xFF2C1F0E),

    tertiary: Color(0xFFD9C8B4),
    onTertiary: Color(0xFF4A3F32),

    surface: Color(0xFFF5F3EF),
    onSurface: Color(0xFF2C2924),
    onSurfaceVariant: Color(0xFF7A746B), // 取自色卡
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEBE7E0),
    surfaceContainer: Color(0xFFEBE7E0),
    surfaceContainerHigh: Color(0xFFE0DBCD),
    surfaceContainerHighest: Color(0xFFD1CDC4),

    outline: Color(0xFFB5AFA7), // 取自色卡 outline
    outlineVariant: Color(0xFFD1CDC4), // 取自色卡 lightDivider

    error: Color(0xFFB3261E), // 取代红 #D32F2F → 色卡 error
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),

    // success: successGreen,
    // onSuccess: Colors.white,

    // 阴影、遮罩
    shadow: Color(0x1A000000),
    scrim: Color(0x66000000),
  );

  // 深色模式 ColorScheme（近黑基底 #1C1C1E，Apple 风格语义色，取自 Pixso 色卡 card-dark 节点 15:1062）
  static ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC8A97E),
    onPrimary: Color(0xFF1C1C1E),
    primaryContainer: Color(0xFF4A3C2A),
    onPrimaryContainer: Color(0xFFE8D2B2),

    secondary: Color(0xFFA89070),
    onSecondary: Color(0xFF1C1C1E),
    secondaryContainer: Color(0xFF3D3025),
    onSecondaryContainer: Color(0xFFD9C4A8),

    tertiary: Color(0xFF8C7D6A),
    onTertiary: Color(0xFFF1E9DD),

    surface: Color(0xFF1C1C1E),
    onSurface: Color(0xFFF2F2F7),
    onSurfaceVariant: Color(0xFFAEAEB2), // 取自色卡
    surfaceContainerLowest: Color(0xFF161618),
    surfaceContainerLow: Color(0xFF2C2C2E),
    surfaceContainer: Color(0xFF2C2C2E),
    surfaceContainerHigh: Color(0xFF3A3A3C),
    surfaceContainerHighest: Color(0xFF3A3A3C),

    outline: Color(0xFF636366),
    outlineVariant: Color(0xFF48484A),

    error: Color(0xFFFF453A),
    onError: Color(0xFF1C1C1E),
    errorContainer: Color(0xFF4D1E1B),
    onErrorContainer: Color(0xFFFFDAD6),

    // success: Color(0xFF42B962),
    // onSuccess: Color(0xFF003912),
    shadow: Color(0x33000000),
    scrim: Color(0x99000000),
  );

  // 私有构建器：基于 ColorScheme 生成基础主题，再 copyWith 覆盖组件级样式并注入 ToolBoxThemeColors 扩展。
  // 集中统一组件样式（按钮/输入/导航/对话框等），确保深浅模式表现一致。
  /// 私有构建器：基于 ColorScheme 生成基础主题，再 copyWith 覆盖组件级样式并注入主题扩展。
  ///
  /// 注入两个扩展：
  ///   - [ToolBoxThemeColors]：M3 未覆盖的业务状态色与装饰色；
  ///   - [AppPalette]：语义色板，供各页面通过 `AppPalette.of(context)` 取色，
  ///     使页面私有色板能跟随主题色方案变化。本主题固定注入 **coffee（咖啡色）** 版。
  static ThemeData _build(ColorScheme scheme, ToolBoxThemeColors extendedColors) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final TextTheme textTheme = _textTheme(base.textTheme, scheme);
    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14.r),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[
        extendedColors,
        // 咖啡色语义色板：按当前 scheme 的明暗二选一。
        scheme.brightness == Brightness.dark
            ? AppPalette.coffeeDark
            : AppPalette.coffeeLight,
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          scheme: scheme,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          outlined: false,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          scheme: scheme,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          outlined: true,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48.w, 48.h)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: 0.10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48.w, 48.h)),
          iconSize: const WidgetStatePropertyAll(24),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: 0.10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 14.h,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2.w),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2.w),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.onSurface.withValues(alpha: 0.12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: 0.56),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.primaryContainer,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8.r),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
    );
  }

  // 统一按钮样式工厂：同时服务 Filled / Outlined 两种按钮，由 [outlined] 切换描边与否。
  // 通过 WidgetStateProperty.resolveWith 区分禁用/按下/悬浮态，保证交互态颜色与 M3 规范一致。
  static ButtonStyle _buttonStyle({
    required ColorScheme scheme,
    required OutlinedBorder shape,
    required TextStyle? textStyle,
    required bool outlined,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64.w, 48.h)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(textStyle),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (outlined) return Colors.transparent;
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        return scheme.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return outlined ? scheme.primary : scheme.onPrimary;
      }),
      side: outlined
          ? WidgetStateProperty.resolveWith((states) {
              final Color color = states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.12)
                  : scheme.outline;
              return BorderSide(color: color);
            })
          : null,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        final Color color = outlined ? scheme.primary : scheme.onPrimary;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.10);
        }
        return null;
      }),
    );
  }

  // 输入框边框工厂：统一 12 圆角的 OutlineInputBorder，[width] 默认 1、聚焦/错误态传 2 加粗。
  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // 文本样式工厂：在基础文本主题上按设计稿字号/行高/字重统一覆盖（如标题 w700、正文 w400），
  // 文字色统一绑定 onSurface / onSurfaceVariant，保证深浅模式下可读性与对比度。
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28.sp,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24.sp,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20.sp,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16.sp,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16.sp,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14.sp,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.sp,
        height: 18 / 12,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14.sp,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12.sp,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

@immutable
final class ToolBoxThemeColors extends ThemeExtension<ToolBoxThemeColors> {
  /// 全参私有构造：业务状态色与装饰色一次性确定，外部经命名构造获取成套配色。
  const ToolBoxThemeColors({
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
    required this.accentDecorative,
    required this.bannerStart,
    required this.bannerEnd,
  });

  /// 浅色业务状态/装饰配色工厂。
  ///
  /// success/warning/info 为主色与容器色，on* 为对应前景色；
  /// accentDecorative / bannerStart / bannerEnd 用于装饰渐变与 Banner 背景，
  /// 其色值不取自 M3 标准字段，作为品牌点缀集中在此扩展管理。
  const ToolBoxThemeColors.light()
    : success = const Color(0xFF2E6B45),
      onSuccess = const Color(0xFFFFFFFF),
      successContainer = const Color(0xFFDCEFE2),
      onSuccessContainer = const Color(0xFF123921),
      warning = const Color(0xFF8A5700),
      onWarning = const Color(0xFFFFFFFF),
      warningContainer = const Color(0xFFFFF0CF),
      onWarningContainer = const Color(0xFF3D2600),
      info = const Color(0xFF285F7A),
      onInfo = const Color(0xFFFFFFFF),
      infoContainer = const Color(0xFFDDEEF6),
      onInfoContainer = const Color(0xFF123647),
      accentDecorative = const Color(0xFFC47A5A),
      bannerStart = const Color(0xFF6B4E3D),
      bannerEnd = const Color(0xFF8B6F5E);

  /// 深色业务状态/装饰配色工厂，与浅色保持一致语义、各自适配对比度。
  const ToolBoxThemeColors.dark()
    : success = const Color(0xFF8FD5A5),
      onSuccess = const Color(0xFF143A23),
      successContainer = const Color(0xFF143A23),
      onSuccessContainer = const Color(0xFFB5F2C6),
      warning = const Color(0xFFF1C66B),
      onWarning = const Color(0xFF4A2F00),
      warningContainer = const Color(0xFF4A2F00),
      onWarningContainer = const Color(0xFFFFDFA0),
      info = const Color(0xFF9ACBE3),
      onInfo = const Color(0xFF123647),
      infoContainer = const Color(0xFF123647),
      onInfoContainer = const Color(0xFFC5E8F7),
      accentDecorative = const Color(0xFFE7A58B),
      bannerStart = const Color(0xFF3D2B23),
      bannerEnd = const Color(0xFF6B4E3D);

  /// 成功态主色。
  final Color success;

  /// 成功态前景色（容器上的文字/图标色）。
  final Color onSuccess;

  /// 成功态容器底色（浅底承载成功信息）。
  final Color successContainer;

  /// 成功态容器前景色。
  final Color onSuccessContainer;

  /// 警告态主色。
  final Color warning;

  /// 警告态前景色。
  final Color onWarning;

  /// 警告态容器底色。
  final Color warningContainer;

  /// 警告态容器前景色。
  final Color onWarningContainer;

  /// 信息态主色。
  final Color info;

  /// 信息态前景色。
  final Color onInfo;

  /// 信息态容器底色。
  final Color infoContainer;

  /// 信息态容器前景色。
  final Color onInfoContainer;

  /// 装饰强调色（如点缀图标、强调标签）。
  final Color accentDecorative;

  /// Banner 渐变起始色（左上）。
  final Color bannerStart;

  /// Banner 渐变结束色（右下）。
  final Color bannerEnd;

  /// 由 [bannerStart] → [bannerEnd] 组成的左上至右下线性渐变，供 Banner/卡片头图复用。
  LinearGradient get bannerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[bannerStart, bannerEnd],
  );

  /// 主题扩展拷贝方法：仅替换非 null 字段，其余沿用当前实例（主题过渡场景使用）。
  @override
  ToolBoxThemeColors copyWith({
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
    Color? accentDecorative,
    Color? bannerStart,
    Color? bannerEnd,
  }) {
    return ToolBoxThemeColors(
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
      accentDecorative: accentDecorative ?? this.accentDecorative,
      bannerStart: bannerStart ?? this.bannerStart,
      bannerEnd: bannerEnd ?? this.bannerEnd,
    );
  }

  /// 主题扩展插值方法：按进度 [t] 逐色在 [this] 与 [other] 间插值，用于深浅主题过渡。
  ///
  /// [other] 为 null 时直接返回自身。
  @override
  ToolBoxThemeColors lerp(ToolBoxThemeColors? other, double t) {
    if (other == null) return this;
    return ToolBoxThemeColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      accentDecorative: Color.lerp(
        accentDecorative,
        other.accentDecorative,
        t,
      )!,
      bannerStart: Color.lerp(bannerStart, other.bannerStart, t)!,
      bannerEnd: Color.lerp(bannerEnd, other.bannerEnd, t)!,
    );
  }
}

/// 在 [BuildContext] 上扩展 `toolBoxThemeColors` getter，便捷获取已注入的 [ToolBoxThemeColors]。
extension ToolBoxThemeContext on BuildContext {
  /// 读取当前主题注入的 [ToolBoxThemeColors]。
  ///
  /// 未注入时触发断言失败，便于开发期定位「忘记装配 ToolBoxThemeColors 扩展」的问题。
  ToolBoxThemeColors get toolBoxThemeColors {
    final ToolBoxThemeColors? colors = Theme.of(this).extension<ToolBoxThemeColors>();
    assert(colors != null, 'ToolBoxThemeColors is missing from ThemeData.');
    return colors!;
  }
}
