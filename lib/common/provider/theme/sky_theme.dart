// sky_theme.dart
//
// 职责：定义「晴空蓝（Sky）」备用主题（浅色/深色），并通过 [SkyThemeColors]
// 主题扩展补充 Material 3 未覆盖的业务状态色与装饰色；同时抽取品牌基础色常量供全局复用。
// 所属模块：tool_box / common/provider/theme（主题层）。
//
// 关键依赖：
//  - flutter/material：ColorScheme、ThemeData、ThemeExtension 等主题基建。
//  - flutter_screenutil_plus：.sp / .r / .w / .h 尺寸自适应，与 app_theme 保持一致。
//
// 与 app_theme / pixso_theme 的关系：
//  - **当前生效的是 AppTheme**（见 main.dart 的 theme / darkTheme），
//    本文件是**并存的备用主题**，不参与运行期装配，仅提供一套可直接切换的完整 ThemeData。
//  - 结构刻意与 [AppTheme] 对齐（品牌常量 → lightScheme/darkScheme → _build → 组件级样式 →
//    同名扩展 + Context getter），这样切换主题时只需在 main.dart 换一行：
//    `theme: SkyTheme.light, darkTheme: SkyTheme.dark`，业务层读法无需改动。
//
// 配色来源：
//  - 浅色沿用本文件原有的一套截图色（primary #4290E8 / 背景 #F0F7FD / 白卡片），
//    深色为按 M3 深色规范推导的配套色（深蓝夜空底 + 提亮的天空蓝主色），
//    on* 前景色按 M3 对比度推导，已在行内注释标注「推导」。

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'app_palette.dart';

/// 晴空蓝（Sky）主题装配中心。
///
/// 职责：持有品牌基础色常量，并提供浅色 [light] / 深色 [dark] 两套完整 [ThemeData]。
/// 两套主题均由私有 [_build] 基于对应 [ColorScheme] 与 [SkyThemeColors] 扩展统一生成，
/// 以保证组件级样式（按钮、输入框、导航栏等）在深浅模式下表现一致。
class SkyTheme {
  /// 私有构造，禁止实例化；本类仅暴露静态常量与静态主题。
  const SkyTheme._();

  // ==========================================================================
  // 品牌基础色值统一抽取，供业务层直接引用，避免散落硬编码。
  // 前七项为本文件原有的常量，保持原名原值以兼容既有引用。
  // ==========================================================================

  /// 品牌主色（晴空蓝 #4290E8）：核心品牌色，用于主按钮、选中态、强调图标。
  static const Color primary = Color(0xFF4290E8);

  /// 主色浅调（#E0EBF8）：主色的容器/底板色，用于浅底标签、Chip 背景。
  static const Color primaryLight = Color(0xFFE0EBF8);

  /// 页面底色（#F0F7FD）：浅色模式的 scaffold 背景，比纯白更「透气」。
  static const Color background = Color(0xFFF0F7FD);

  /// 卡片底色（#FFFFFF）：浅色模式卡片浮在 [background] 之上，靠白色形成层次。
  static const Color cardBg = Color(0xFFFFFFFF);

  /// 主文字色（#1A1A1A）。
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// 次文字色（#666666）：次要说明、辅助文案。
  static const Color textSecondary = Color(0xFF666666);

  /// 收藏/成功绿（#34A853）：独立于蓝色主色的业务强调色，避免与可点击蓝混淆。
  static const Color bookmarkGreen = Color(0xFF34A853);

  // —— 以下为完善主题时补充的常量，配合上面的基础色构成完整体系 ——

  /// 品牌行动色（深空蓝 #1F6FEB）：比 [primary] 更深，用于强调按钮等行动点，
  /// 与 app_theme 的 brandAction 语义对齐。
  static const Color brandAction = Color(0xFF1F6FEB);

  /// 主色深调（#225899）：浅色模式下用于 on-primary-container 等需要高对比的深蓝文字，
  /// 保证 [primaryLight] 底上的文字达到 M3 对比度要求（推导）。
  static const Color primaryDark = Color(0xFF225899);

  /// 链接蓝（#3E87E9）：可点击文本链接专用，与主色略有区分，便于一眼识别可点。
  static const Color linkBlue = Color(0xFF3E87E9);

  // ==========================================================================
  // 圆角与阴影规范（沿用本文件原有取值，供未接入 ThemeData 的散落组件复用）
  // ==========================================================================

  /// 小圆角（8）：Chip、小标签。
  static const double radiusSm = 8.0;

  /// 中圆角（12）：按钮、输入框、卡片。
  static const double radiusMd = 12.0;

  /// 大圆角（20）：底部弹层、大卡片。
  static const double radiusLg = 20.0;

  /// 卡片阴影：极轻的投影（约 6% 黑），配合白色卡片在浅蓝底上形成浮动感。
  static List<BoxShadow> cardShadow = const <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // ==========================================================================
  // 两套完整 ThemeData
  // ==========================================================================

  /// 浅色主题：组合浅色 [lightScheme] 与浅色 [SkyThemeColors] 扩展。
  static final ThemeData light = _build(
    lightScheme,
    const SkyThemeColors.light(),
  );

  /// 深色主题：组合深色 [darkScheme] 与深色 [SkyThemeColors] 扩展。
  static final ThemeData dark = _build(darkScheme, const SkyThemeColors.dark());

  /// 旧版单参入口，等价于 [light]。
  ///
  /// 早期本文件只提供一套浅色 `themeData`，完善主题后保留此 getter 以兼容既有引用，
  /// 新代码请直接用 [light] / [dark]。
  static ThemeData get themeData => light;

  // 浅色模式 ColorScheme（浅蓝底 #F0F7FD + 白卡片，主色晴空蓝 #4290E8）
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: primaryLight,
    onPrimaryContainer: primaryDark,

    secondary: brandAction,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE9FB),
    onSecondaryContainer: Color(0xFF0A3A6B),

    tertiary: Color(0xFF7CC0F5), // 浅天空蓝，作为点缀 / 第三层级
    onTertiary: Color(0xFF0A3450),

    surface: background,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    surfaceContainerLowest: cardBg,
    surfaceContainerLow: cardBg,
    surfaceContainer: Color(0xFFF7FAFE),
    surfaceContainerHigh: Color(0xFFEDF3FA),
    surfaceContainerHighest: Color(0xFFE3EBF5),

    outline: Color(0xFFC5D5E8), // 推导：主色降饱和 + 提亮，避免描边抢眼
    outlineVariant: Color(0xFFE1EAF4), // 分隔线

    error: Color(0xFFD93025),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE8E6),
    onErrorContainer: Color(0xFF5C100B),

    shadow: Color(0x1A000000),
    scrim: Color(0x66000000),
  );

  // 深色模式 ColorScheme（深蓝夜空底 #0F1620，主色提亮为 #79B8F3 以保证深底上的对比度）
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF79B8F3), // 推导：浅色主色 #4290E8 在深底上偏暗，提亮一档
    onPrimary: Color(0xFF0A2A45),
    primaryContainer: Color(0xFF164A73),
    onPrimaryContainer: Color(0xFFCBE4FB),

    secondary: Color(0xFF6BA8E8),
    onSecondary: Color(0xFF082840),
    secondaryContainer: Color(0xFF123A5C),
    onSecondaryContainer: Color(0xFFC7E2FA),

    tertiary: Color(0xFF8FC3EE),
    onTertiary: Color(0xFF062033),

    surface: Color(0xFF0F1620),
    onSurface: Color(0xFFE6EAF0),
    onSurfaceVariant: Color(0xFFA3AEBB),
    surfaceContainerLowest: Color(0xFF0B1119),
    surfaceContainerLow: Color(0xFF161E29),
    surfaceContainer: Color(0xFF1A232F),
    surfaceContainerHigh: Color(0xFF222C39),
    surfaceContainerHighest: Color(0xFF2A3644),

    outline: Color(0xFF3A4756),
    outlineVariant: Color(0xFF2A3542),

    error: Color(0xFFFF8A80),
    onError: Color(0xFF4A0F0A),
    errorContainer: Color(0xFF5C1A15),
    onErrorContainer: Color(0xFFFFDAD5),

    shadow: Color(0x33000000),
    scrim: Color(0x99000000),
  );

  // 私有构建器：基于 ColorScheme 生成基础主题，再 copyWith 覆盖组件级样式并注入主题扩展。
  // 集中统一组件样式（按钮/输入/导航/对话框等），确保深浅模式表现一致。
  //
  // 注入两个扩展：
  //   - [SkyThemeColors]：M3 未覆盖的业务状态色与装饰色；
  //   - [AppPalette]：语义色板，供各页面通过 `AppPalette.of(context)` 取色。
  //     本主题固定注入 **blue（晴空蓝）** 版，与 AppTheme 注入的 coffee 版形成切换。
  static ThemeData _build(ColorScheme scheme, SkyThemeColors extendedColors) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final TextTheme textTheme = _textTheme(base.textTheme, scheme);
    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd.r),
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
        // 晴空蓝语义色板：按当前 scheme 的明暗二选一。
        scheme.brightness == Brightness.dark
            ? AppPalette.blueDark
            : AppPalette.blueLight,
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
        color: scheme.surfaceContainerLowest,
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: 0.56),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg.r)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd.r),
        ),
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
          borderRadius: BorderRadius.circular(radiusSm.r),
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

  // 输入框边框工厂：统一 [radiusMd] 圆角的 OutlineInputBorder，
  // [width] 默认 1、聚焦/错误态传 2 加粗。
  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd.r),
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

/// 晴空蓝主题的业务状态色与装饰色扩展。
///
/// 与 [ToolBoxThemeColors] 一一对应（success / warning / info 三套状态色 + 装饰色 + Banner 渐变），
/// 便于两套主题互相切换时业务层读法保持一致。
@immutable
final class SkyThemeColors extends ThemeExtension<SkyThemeColors> {
  /// 全参私有构造：业务状态色与装饰色一次性确定，外部经命名构造获取成套配色。
  const SkyThemeColors({
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
  /// success 沿用 [SkyTheme.bookmarkGreen] 同系的收藏绿，info 取深青蓝以贴合晴空主题，
  /// accentDecorative / bannerStart / bannerEnd 为蓝天渐变点缀。
  const SkyThemeColors.light()
    : success = const Color(0xFF2E7D32),
      onSuccess = const Color(0xFFFFFFFF),
      successContainer = const Color(0xFFDCF0DE),
      onSuccessContainer = const Color(0xFF123A16),
      warning = const Color(0xFF8A5700),
      onWarning = const Color(0xFFFFFFFF),
      warningContainer = const Color(0xFFFFF0CF),
      onWarningContainer = const Color(0xFF3D2600),
      info = const Color(0xFF285F7A),
      onInfo = const Color(0xFFFFFFFF),
      infoContainer = const Color(0xFFDDEEF6),
      onInfoContainer = const Color(0xFF123647),
      accentDecorative = const Color(0xFF58C4F0),
      bannerStart = const Color(0xFF2C6FB5),
      bannerEnd = const Color(0xFF4E9FE0);

  /// 深色业务状态/装饰配色工厂，与浅色保持一致语义、各自适配对比度（均为推导值）。
  const SkyThemeColors.dark()
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
      accentDecorative = const Color(0xFF6FD0F5),
      bannerStart = const Color(0xFF123A5C),
      bannerEnd = const Color(0xFF2C6FB5);

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
  SkyThemeColors copyWith({
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
    return SkyThemeColors(
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
  SkyThemeColors lerp(SkyThemeColors? other, double t) {
    if (other == null) return this;
    return SkyThemeColors(
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

/// 在 [BuildContext] 上扩展 `skyThemeColors` getter，便捷获取已注入的 [SkyThemeColors]。
extension SkyThemeContext on BuildContext {
  /// 读取当前主题注入的 [SkyThemeColors]。
  ///
  /// 未注入时触发断言失败，便于开发期定位「忘记装配 SkyThemeColors 扩展」的问题
  /// （即 main.dart 未使用 [SkyTheme.light] / [SkyTheme.dark]）。
  SkyThemeColors get skyThemeColors {
    final SkyThemeColors? colors = Theme.of(this).extension<SkyThemeColors>();
    assert(colors != null, 'SkyThemeColors is missing from ThemeData.');
    return colors!;
  }
}
