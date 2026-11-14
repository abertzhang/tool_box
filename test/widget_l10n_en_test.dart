// widget_l10n_en_test.dart
//
// 职责：英文宿主下的底部导航文案冒烟测试。
// 所属模块：test（测试层）。
//
// ★ 为什么单独一个文件：
//   flutter test 每个文件独立进程。实测（2026-09-03）同一进程内跨测试切换
//   locale（无论 zh→en 还是 en→zh），新 locale 宿主的 Localizations 加载会
//   被前一宿主污染——WidgetsApp 停在 SizedBox 占位分支，Navigator/Scaffold
//   都不会建，断言报 No element。文件级进程隔离是最干净的解法，
//   因此英文用例与中文用例（widget_test.dart）分文件存放。
//
// 关键依赖：
//   - test_utils.dart：视图尺寸对齐 + 本地化最小宿主；
//   - l10n/app_localizations.dart：验证 ARB 裁剪后 en key 完整。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/home/widget/main_bottom_nav.dart';

import 'test_utils.dart';

void main() {
  testWidgets('英文环境 Tab 文案为 Tools / Profile', (WidgetTester tester) async {
    // 视图尺寸必须先对齐设计基准（详见 test_utils.dart 中的说明）。
    await setDesignSurface(tester);
    await tester.pumpWidget(
      host(locale: const Locale('en'), child: const MainBottomNav()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
