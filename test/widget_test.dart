// widget_test.dart
//
// 职责：tool_box 的基础冒烟测试（中文宿主）。
// 所属模块：test（测试层）。
//
// 测试范围说明：
//   完整启动 ToolBoxApp 需要先初始化 Hive 与 Isar（原生依赖），在纯 Dart 测试
//   环境中不可用，因此这里不测 main()，而是聚焦两件不依赖原生插件的事：
//     1. 底部导航能正确渲染「工具 / 我的」两个 Tab，且点击后下标状态随之变化；
//     2. 中文本地化文案能被正确加载（英文见 widget_l10n_en_test.dart）。
//
// ★ 为什么英文测试不放在本文件：
//   flutter test 每个文件独立进程。实测（2026-09-03）同一进程内跨测试切换
//   locale（无论 zh→en 还是 en→zh），新 locale 宿主的 Localizations 加载会
//   被前一宿主污染，WidgetsApp 永远停在 SizedBox 占位分支（Navigator 都不建），
//   断言报 No element。文件级进程隔离是最干净的解法。
//
// 关键依赖：
//   - flutter_riverpod：ProviderScope 提供 tabIdxProvider 容器；
//   - flutter_screenutil_plus：MainBottomNav 内部使用 .w/.h/.sp，必须包一层初始化；
//   - l10n/app_localizations.dart：多语言文案；
//   - test_utils.dart：视图尺寸对齐 + 本地化最小宿主。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/home/widget/main_bottom_nav.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import 'test_utils.dart';

void main() {
  testWidgets('底部导航渲染「工具 / 我的」两个 Tab（中文）', (WidgetTester tester) async {
    // 视图尺寸必须先对齐设计基准，否则 ScreenUtil 放大 → RenderFlex overflow 假阳性。
    await setDesignSurface(tester);
    await tester.pumpWidget(
      host(locale: const Locale('zh'), child: const MainBottomNav()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('main-bottom-nav-item-0')), findsOneWidget);
    expect(find.byKey(const Key('main-bottom-nav-item-1')), findsOneWidget);
    expect(find.byKey(const Key('main-bottom-nav-item-2')), findsNothing);
  });

  testWidgets('中文环境 Tab 文案为 工具 / 我的', (WidgetTester tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      host(locale: const Locale('zh'), child: const MainBottomNav()),
    );
    await tester.pumpAndSettle();

    expect(find.text('工具'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('点击第二个 Tab 后 tabIdxProvider 下标变为 1', (WidgetTester tester) async {
    await setDesignSurface(tester);
    // 单独持有容器，便于在点击后直接读取 Provider 状态。
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilPlusInit(
          // ★ 与 main.dart 完全一致：缺 minTextAdapt/splitScreenMode 时
          //   缩放比会偏离真机，_MainBottomNavItem 的 Column 会假性溢出。
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(bottomNavigationBar: MainBottomNav()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始应落在「工具」Tab。
    expect(container.read(tabIdxProvider), 0);

    await tester.tap(find.byKey(const Key('main-bottom-nav-item-1')));
    await tester.pumpAndSettle();

    expect(container.read(tabIdxProvider), 1);
  });
}
