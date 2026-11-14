// privacy_policy_page_test.dart
//
// 职责：隐私政策页的渲染冒烟测试（**仅中文宿主**）。
// 所属模块：test（测试层）。
//
// ★ 为什么只测中文、且必须单独一个文件：
//   flutter test 每个文件独立进程。实测（2026-09-03）同一进程内跨测试切换
//   locale（无论 zh→en 还是 en→zh），后一个 locale 宿主的 Localizations 加载
//   会被前一宿主污染，WidgetsApp 永远停在 SizedBox 占位分支 → 断言报 No element。
//   因此本文件固定 zh 宿主；英文文案的完整性由 gen-l10n 生成结果保证
//   （app_localizations_en.dart 中对应方法不存在时编译即失败）。
//
// 覆盖范围：
//   1. AppBar 标题、首章与末章标题都能渲染出来；
//   2. 带占位符的「最后更新时间」文案插值正常；
//   3. 长正文放在 [SingleChildScrollView] 里不会溢出（有溢出时 pumpAndSettle 会抛错）。
//
// 关键依赖：
//   - feature/profile/page/privacy_policy_page.dart：被测页面（纯静态，无原生依赖）；
//   - test_utils.dart：视图尺寸对齐 + 本地化最小宿主。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/profile/page/privacy_policy_page.dart';

import 'test_utils.dart';

void main() {
  testWidgets('隐私政策页渲染标题 / 章节 / 最后更新时间', (WidgetTester tester) async {
    // 视图尺寸必须先对齐设计基准，否则 ScreenUtil 放大 → RenderFlex overflow 假阳性。
    await setDesignSurface(tester);
    await tester.pumpWidget(
      host(locale: const Locale('zh'), child: const PrivacyPolicyPage()),
    );
    await tester.pumpAndSettle();

    // AppBar 标题：注意 privacyIntro 正文里也含「隐私政策」四字，
    // 但 find.text 比对的是整个 Text 的完整文本，正文是一整段话、不会误命中。
    expect(find.text('隐私政策'), findsOneWidget);
    // 首章标题。
    expect(find.text('一、我们收集的信息'), findsOneWidget);
    // 末章标题：挂在滚动容器最底部，能找到即说明全文（非懒加载）都挂上了。
    expect(find.text('七、联系我们'), findsOneWidget);
    // 带参数的文案：验证 {date} 插值正常（写死期望值，
    // 与页面里的 _lastUpdated 常量对应；改常量时这里要同步改）。
    expect(find.text('最后更新时间：2026-09-05'), findsOneWidget);
  });
}
