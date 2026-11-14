// test_utils.dart
//
// 职责：widget 测试的公共宿主工具（视图尺寸对齐 + 本地化最小宿主）。
// 所属模块：test（测试层）。
//
// 为什么单独抽文件：
//   en 与 zh 的 widget 测试必须放在**不同的测试文件**里——flutter test
//   以文件为单位的独立进程跑测试，可彻底隔离「同一进程内跨测试切换
//   locale 导致 Localizations 加载卡死」的框架级污染（2026-09-03 实测）。
//   两个文件都需要同一套宿主构造，因此抽成公共工具。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 把测试视图对齐到 App 的设计基准（393×852，与 main.dart 的 ScreenUtilPlusInit 一致）。
///
/// 为什么必须做这一步（2026-09-03 修复）：
///   flutter test 的默认视图是 800×600，比设计基准宽一倍、矮三成。
///   ScreenUtilPlus 会按「实际宽 / 设计宽」放大所有 .w/.sp 尺寸，
///   于是底部导航被撑到装不下，报 RenderFlex overflow（假阳性）。
///
/// ★ 为什么用 tester.view.physicalSize 而不是 binding.setSurfaceSize：
///   实测（探针测试）Flutter master 的 TestFlutterView 体系下，
///   `binding.setSurfaceSize(Size(393, 852))` **不会传导到默认视图的 MediaQuery**
///   （MediaQuery.sizeOf 仍返回 800×600，缩放比错成 2.03）；
///   而 `tester.view.physicalSize + devicePixelRatio` 是官方推荐做法，
///   MediaQuery 与 ScreenUtilPlus 均能拿到正确的 393×852。
///   这里取 dpr=3.0（与 iOS 真机一致），物理尺寸 = 逻辑尺寸 × 3。
///
/// 用完必须 reset（addTearDown），否则会污染同一进程里的其它测试。
Future<void> setDesignSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(393, 852) * 3.0;
  addTearDown(tester.view.reset);
}

/// 构造一个包含本地化与屏幕适配的最小可测宿主。
///
/// 参数：[locale] 目标语言；[child] 被测组件。
/// 返回：可直接交给 `tester.pumpWidget` 的 Widget 树。
Widget host({required Locale locale, required Widget child}) {
  return ProviderScope(
    child: ScreenUtilPlusInit(
      // ★ 这三个参数必须与 main.dart 第 98~101 行**完全一致**：
      //   少了 minTextAdapt / splitScreenMode 会得到与真机不同的缩放比，
      //   真机上不溢出的布局在测试里会报 RenderFlex overflow 假阳性。
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Scaffold 提供 Material 祖先，避免 Text/InkWell 缺少 Material 报错。
        home: Scaffold(bottomNavigationBar: child),
      ),
    ),
  );
}
