// ============================================================================
// 文件：integration_test/app_test.dart
// 模块：tool_box / 端到端集成测试
//
// 职责：
//   在真实 iOS 模拟器（或真机）上跑 profile 页三态的端到端验证：
//   「未登录 → 登录 → 已登录 → 退出登录 → 未登录」完整闭环。
//   弥补 widget_test 跑在隔离 TestApp 里、无法覆盖 Supabase + Isar + go_router
//   三方集成的空白。
//
// 跑法（开发机）：
//   flutter test integration_test/app_test.dart \
//     -d <device_id> \
//     --dart-define-from-file=local/env/prd.json
//
// ★★★ 跑之前必须先清掉代理（见下方「环境依赖」），否则必然连不上 flutter_tester。
//
// 前置条件：
//   1. local/env/prd.json 已配置 SUPABASE_URL + SUPABASE_ANON_KEY
//      （service_role 等敏感密钥归 local/env/dev.json，不进 local/env/prd.json）。
//   2. 演示账号已由 admin 模式建立并 --keep 保留：
//      demouser@example.com / Demo@123456
//      （建法：python3 scripts/smoke_signup.py --mode admin --keep \
//        --email demouser@example.com --password 'Demo@123456'）
//   3. 无需关心模拟器系统语言 —— 本测试会自适应切到中文（见 _ensureChinese）。
//
// ── 环境依赖（2026-09-03 踩坑，极重要）──────────────────────────────────
//   开发机若设置了 HTTP_PROXY / HTTPS_PROXY 却**没有配 no_proxy**，
//   Dart 的 HttpClient 会把连本机 127.0.0.1 的 flutter_tester / VM service
//   请求也发给代理，代理处理不了 WebSocket 升级，报：
//       Unable to connect to flutter_tester process:
//       WebSocketException: Invalid WebSocket upgrade request
//   这个报错极具误导性 —— 看起来像 Xcode / Flutter / 模拟器的版本不兼容，
//   实际只是代理把本地回环吃掉了。跑之前必须：
//       export no_proxy="127.0.0.1,localhost,::1"
//       export NO_PROXY="127.0.0.1,localhost,::1"
//   （只排除回环地址，外网仍走代理，不影响访问 Supabase。）
// ──────────────────────────────────────────────────────────────────────
//
// 为什么用 Key 而不是 WidgetType 找 Tab：
//   main_bottom_nav.dart 在单项上挂了 `main-bottom-nav-item-${index}` Key，
//   0=Tools，1=Profile。find.byKey 不依赖 i18n，最稳。
//
// 为什么断言用中文而不是英文：
//   profile 页与 login 页文案均走 ARB（en/zh 齐平；login.dart 已于 2026-09-03
//   完成 i18n 化，新增 loginSubmit/loginSubtitle/loginSuccess/forgotPassword/
//   resetPasswordSent 五个 key）。两条路都会碰中文，所以统一先切到中文再断言，
//   避免半中半英对不上。
//
// 已知耗时：
//   - 启动期 Supabase init + Isar open 约 2~3 秒；
//   - 登录网络请求（password grant）约 1~2 秒；
//   - pumpAndSettle 在未登录时不会自动停，所以每步都给一个兜底 Duration。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tool_box/main.dart' as app;

// 演示账号（admin --keep 保留；触发器已补 public.users + user_profiles 行）
const String _demoEmail = 'demouser@example.com';
const String _demoPassword = 'Demo@123456';
// 演示账号昵称：由 handle_new_user 触发器取邮箱 @ 前缀自动填充。
const String _demoName = 'demouser';
// 演示账号 UUID 前 8 位（由 admin 建号时打印；若重建账号需同步修改这里）
const String _demoIdPrefix = '07f583e0';
// 「编辑资料」阶段写入的临时昵称。
//
// 为什么测试结束前要改回 _demoName：阶段 4 断言资料区显示的是 demouser。
// 若把昵称永久改成别的值，第二次跑测试就会在阶段 4 直接失败。
// 所以本测试采用「改 → 断言 → 改回」的写法，保证可重复执行。
const String _editedName = 'e2e-tester';

/// 确保 App 当前处于中文，便于后续统一用中文断言。
///
/// App 的 locale 来自 [localeProvider]（Hive 持久化，默认 'en'），
/// 而模拟器每次跑测试都是全新的沙盒 → 首跑必然是英文。
/// 所以这里先探测：若看到英文文案，就点「语言设置」行切到中文。
///
/// 为什么点 Icon 而不是点文字：语言行的标题是 `l10n.langSetting`，
/// 文案随语言变化（"Language" / "语言设置"），但图标
/// `Icons.language_outlined` 恒定，不依赖 i18n，最稳。
///
/// 幂等：已经是中文时什么都不做，重复跑不会来回切。
///
/// ⚠️ 副作用：本函数内部会滚动页面去够语言行，返回时页面**不在顶部**。
///    调用方必须紧跟一次 [_scrollToTop]，否则资料区被滚到屏幕外，
///    后续 tap 会命中不到（报 "derived an Offset ... that would not hit test"）。
Future<void> _ensureChinese(WidgetTester tester) async {
  const englishMarker = 'Not signed in'; // en.arb profileNotLogin
  if (find.text(englishMarker).evaluate().isEmpty) {
    // 没找到英文文案 → 已经是中文，直接返回。
    return;
  }

  // 语言行在设置分组，页面较长，先滚动到可见再点。
  await tester.scrollUntilVisible(
    find.byIcon(Icons.language_outlined),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await tester.tap(find.byIcon(Icons.language_outlined));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // 切完立刻自检，失败时给出可操作的提示，而不是让后续断言莫名其妙地红。
  expect(
    find.text('未登录'),
    findsOneWidget,
    reason: '点「语言设置」后应切到中文（zh.arb profileNotLogin = 未登录）',
  );
}

/// 把页面滚回顶部。
///
/// 为什么不用 drag/fling：滚动距离取决于页面长度，写死像素容易过头或不够，
/// 且惯性动画要 pumpAndSettle 很久。直接跳 position 到 0 一步到位、可重复。
///
/// 页面没有可滚动容器时（理论上不会发生）直接返回，不抛异常。
Future<void> _scrollToTop(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  if (scrollable.evaluate().isEmpty) return;
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(0);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

void main() {
  // integration_test 必备：替换默认 binding，把测试跑在真 App 进程里。
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profile 三态：未登录 → 登录 → 已登录 → 退出登录',
    (tester) async {
      // ============================================================
      // 阶段 0：启动 App
      // ============================================================
      // 启动 App（等 main() 完成：WidgetsFlutterBinding.ensureInitialized →
      // Supabase.initialize → IsarService.open → runApp）。
      //
      // 冷启动（Xcode 刚构建完、模拟器首次加载 dylib）实测可达 10 秒以上，
      // 5 秒兜底会在慢机器上漏掉首帧，表现为「阶段 1 找不到未登录文案」这种
      // 极具误导性的失败。这里提到 15 秒，并在 tap 之前再补一次 settle。
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 15));
      // 等底部导航真正建好再继续：后续所有 tap 都依赖它。
      // 单靠 pumpAndSettle 的超时兜底不够稳（超时后它会直接返回、不报错）。
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ============================================================
      // 阶段 1：未登录态
      // ============================================================
      // 初始落在 Tool Tab（MainTabPage 默认 currentTab=0）；切到 Profile Tab。
      expect(
        find.byKey(const Key('main-bottom-nav-item-1')),
        findsOneWidget,
        reason: 'App 启动后应能看到底部导航（启动太慢则加大阶段 0 的等待）',
      );
      await tester.tap(find.byKey(const Key('main-bottom-nav-item-1')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 自适应切到中文（首跑是英文，见 _ensureChinese 注释）。
      await _ensureChinese(tester);
      // _ensureChinese 滚动过页面，必须滚回顶部，否则资料区在屏幕外点不到。
      await _scrollToTop(tester);

      // 未登录态资料区昵称应展示「未登录」（zh.arb profileNotLogin）。
      // 副标题显示「点击登录 / 注册」。
      expect(
        find.text('未登录'),
        findsOneWidget,
        reason: '未登录态资料区昵称应展示「未登录」（zh.arb profileNotLogin）',
      );
      expect(
        find.text('点击登录 / 注册'),
        findsOneWidget,
        reason: '未登录态副标题应引导登录（zh.arb profileTapLogin）',
      );

      // 会员卡「立即开通」按钮：未登录态按未生效处理，仍显示。
      expect(
        find.text('立即开通'),
        findsOneWidget,
        reason: '未登录态会员卡应展示「立即开通」（zh.arb vipOpen）',
      );

      // 设置分组的「退出登录」行：仅登录态出现，未登录态不应存在。
      expect(find.text('退出登录'), findsNothing, reason: '未登录态设置分组不应展示「退出登录」');

      // ============================================================
      // 阶段 2：触发跳转 LoginPage
      // ============================================================
      // 点资料区任意位置 → context.push('/login')。
      // 资料区整块包在 GestureDetector 里，但 GestureDetector 没挂 Key，
      // 所以点它内部的「点击登录 / 注册」文字（hit-test 冒泡到 GestureDetector）。
      await tester.tap(find.text('点击登录 / 注册'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // LoginPage 渲染：登录按钮 + 邮箱/密码输入框。
      // 注意这三条是 login.dart 的**硬编码中文**，不走 ARB。
      expect(
        find.text('立即登录'),
        findsOneWidget,
        reason: 'LoginPage 应展示「立即登录」按钮（login.dart 硬编码）',
      );
      expect(
        find.text('邮箱地址'),
        findsOneWidget,
        reason: 'LoginPage 应展示邮箱输入框 label（login.dart 硬编码）',
      );
      expect(
        find.text('登录密码'),
        findsOneWidget,
        reason: 'LoginPage 应展示密码输入框 label（login.dart 硬编码）',
      );

      // ============================================================
      // 阶段 3：填表 + 登录
      // ============================================================
      // 用 byType+at 取两个 TextField（login.dart 里 email 是第一个、password 是第二个）。
      await tester.enterText(find.byType(TextField).at(0), _demoEmail);
      await tester.enterText(find.byType(TextField).at(1), _demoPassword);
      // 让控制器把值写回 widget tree。
      await tester.pumpAndSettle();

      // 点登录按钮触发 signInWithPassword（真实网络请求）。
      await tester.tap(find.text('立即登录'));
      // 等待登录完成：网络往返 + Supabase 落 session + authStateProvider 推事件。
      await tester.pumpAndSettle(const Duration(seconds: 6));

      // ============================================================
      // 阶段 4：已登录态
      // ============================================================
      // LoginPage 登录成功后会自动返回（2026-09-03 UX 修复：能 pop 就返回
      // 来源页，否则回 /home），正常情况下这里已能看到底部导航；
      // 保留条件分支作为兼容兜底（若将来路由结构再变，测试不至于脆断）。
      if (find.byKey(const Key('main-bottom-nav-item-1')).evaluate().isEmpty) {
        // ⚠️ 不能用 tester.pageBack()：它找的是标准 Material/Cupertino 返回按钮，
        //    而 login.dart 的返回键是自定义 IconButton(Icons.arrow_back)，
        //    pageBack 会报 "Found 0 widgets with type CupertinoNavigationBarBackButton"。
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
      await tester.tap(find.byKey(const Key('main-bottom-nav-item-1')));
      // 等视图查询 + Provider 重算 + 渲染。
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 资料区应展示真实用户数据（来自 user_profiles 视图）。
      expect(
        find.text(_demoEmail),
        findsOneWidget,
        reason: '已登录态应展示真实邮箱（user_profiles.email）',
      );
      expect(
        find.text(_demoName),
        findsOneWidget,
        reason:
            '已登录态应展示昵称（触发器填的邮箱前缀 demouser）。'
            '\n若这里红了：演示账号的 display_name 被上一次中断的测试或手工探针改脏了。'
            '触发器只在建号时填一次昵称，覆盖后不会自动回来。'
            '先复位再重跑：'
            'python3 scripts/smoke_signup.py --mode reset --email $_demoEmail',
      );
      // UUID 前 8 位：profile 页用 `_shortId` 截断。
      expect(
        find.textContaining(_demoIdPrefix),
        findsOneWidget,
        reason: '应展示 UUID 前 8 位（user_profiles.id 截断）',
      );

      // 会员徽章：demo 账号 is_member=false → 描边「免费用户」。
      expect(
        find.text('免费用户'),
        findsOneWidget,
        reason: '非付费会员徽章应展示「免费用户」（zh.arb profileMemberFree）',
      );
      expect(find.text('VIP'), findsNothing, reason: '非付费用户不应展示 VIP 实心徽章');

      // 会员卡标题：未生效时仍是「绳结会员」（zh.arb vipTitle）。
      expect(find.text('绳结会员'), findsOneWidget, reason: '未生效会员卡应展示「绳结会员」标题');
      expect(find.text('结绳会员 · 生效中'), findsNothing, reason: '非付费用户不应展示「生效中」标题');

      // 设置分组应新增「退出登录」行（仅登录态出现）。
      expect(find.text('退出登录'), findsOneWidget, reason: '已登录态设置分组应展示「退出登录」');

      // ============================================================
      // 阶段 4.5：编辑资料（点头像 → 改昵称 + 选头像 → 保存 → 资料页刷新）
      // ============================================================
      // 头像入口在资料区顶部，此时页面处于顶部（刚切过 Tab），可直接点。
      await tester.tap(find.byKey(const Key('profile-avatar-edit')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 编辑页渲染：AppBar 标题 + 换一批 + 保存。
      expect(
        find.text('编辑资料'),
        findsOneWidget,
        reason: '应进入编辑资料页（zh.arb profileEditTitle）',
      );
      expect(
        find.text('换一批'),
        findsOneWidget,
        reason: '编辑页应有「换一批」（zh.arb profileEditShuffle）',
      );
      expect(
        find.text('保存'),
        findsOneWidget,
        reason: '编辑页应有「保存」按钮（zh.arb profileEditSave）',
      );

      // 保存按钮应撑满内容区宽度（屏宽 - 左右各 16 的内边距）。
      //
      // 这里锁的是个真实踩过的坑：外层 Padding 传下来的宽度约束是 **loose** 的，
      // 只给上限、不给下限，所以只钉 height 的 SizedBox 会让 FilledButton
      // shrink-wrap 到「文字 + 内边距」的宽度 —— 实测「保存」只有 76px，
      // 看上去就是个窄窄的小按钮。必须显式写 width: double.infinity。
      // 断言用 MediaQuery 现算屏宽，不写死 361，换设备也不会误报。
      final screenW = MediaQuery.of(tester.element(find.text('保存'))).size.width;
      final saveBtnW = tester.getSize(find.byType(FilledButton)).width;
      expect(
        saveBtnW,
        closeTo(screenW - 32, 1),
        reason: '保存按钮应撑满内容区宽度（屏宽 - 左右各 16 内边距）',
      );

      // 改昵称：编辑页只有一个输入框（昵称）。
      await tester.enterText(find.byType(TextFormField).first, _editedName);
      await tester.pumpAndSettle();

      // 选一张内置头像：网格第 1 项（Key 由位置生成，不依赖图片是否加载成功）。
      //
      // 顺带锁住「每批 10 张」这个约定：断言第 10 项存在、第 11 项不存在。
      // 这样将来有人改了 avatarBatchSize，测试会立刻红，
      // 而不是等到 UI 挤成一团 / 少了一排才被发现。
      expect(
        find.byKey(const Key('avatar-option-9')),
        findsOneWidget,
        reason: '每批应展示 10 张候选头像（avatarBatchSize = 10）',
      );
      expect(
        find.byKey(const Key('avatar-option-10')),
        findsNothing,
        reason: '不应出现第 11 张候选头像',
      );
      await tester.tap(find.byKey(const Key('avatar-option-0')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsWidgets, reason: '选中头像后应出现对勾标记');

      // 保存 → 写回 public.users → invalidate 资料 Provider → pop 返回。
      //
      // 保存按钮已改为**固定在页面底部**（Column 里的固定栏，不随内容滚动），
      // 正常情况下直接可见。这里仍保留 scrollUntilVisible，是防小屏 / 键盘弹起等
      // 边界情形把按钮挤出可视区 —— tester.tap **不会自动滚动**，
      // 点到屏幕外会「什么都没发生、也不报错」，表现成
      // 「保存后没跳回资料页」这种极难定位的假失败。
      // （元素本就可见时 scrollUntilVisible 直接返回，无副作用。）
      await tester.scrollUntilVisible(
        find.text('保存'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('保存'));
      // 写库 + 重新查视图 + 路由返回，给足 8 秒（真实网络往返）。
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 先确认确实回到了资料页（编辑页已销毁）。
      // 这条断言不能省：昵称 `e2e-tester` 在编辑页的输入框里同样存在，
      // 只断言它的话，「页面根本没返回」这种失败会被漏过去。
      expect(find.text('编辑资料'), findsNothing, reason: '保存成功后应返回资料页，编辑页不应还在');
      // 昵称应已更新为新值。
      expect(
        find.text(_editedName),
        findsOneWidget,
        reason: '保存后资料区昵称应更新为 $_editedName',
      );
      // 头像改成了内置库图片，来源视图 avatar_url 已变化 —— 这里只验证
      // 页面仍在已登录态（邮箱与 ID 仍在），头像本身由 CDN 加载，
      // 是否被 Cloudflare 拦截不影响本断言。
      expect(find.text(_demoEmail), findsOneWidget, reason: '编辑后仍应展示真实邮箱');
      expect(
        find.textContaining(_demoIdPrefix),
        findsOneWidget,
        reason: '编辑后仍应展示 UUID 前 8 位',
      );

      // —— 复原：把昵称改回 demouser，保证本测试可重复执行 ——
      await tester.tap(find.byKey(const Key('profile-avatar-edit')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextFormField).first, _demoName);
      await tester.pumpAndSettle();
      // 同样要滚到底部再点保存（原因见上一步）。
      await tester.scrollUntilVisible(
        find.text('保存'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 8));
      expect(find.text('编辑资料'), findsNothing, reason: '复原保存后也应返回资料页');
      expect(
        find.text(_demoName),
        findsOneWidget,
        reason: '复原后资料区昵称应回到 $_demoName',
      );

      // ============================================================
      // 阶段 4.6：给我们评分（Rate Us）
      // ============================================================
      // 验证三件事：① 该行已接真实实现、不再走「功能开发中」占位兜底；
      // ② 未配置 App Store ID 时给出明确提示，而不是点了没反应；
      // ③ 整条链路不抛异常、页面不崩。
      //
      // iOS 模拟器上 in_app_review 的 isAvailable() 恒为 false
      //（SKStoreReviewController 在模拟器不工作），而 iOS 侧又要求
      // App Store ID 才能跳商店页 —— 所以当前必然回落到「不可用」。
      // 这正是我们要锁住的行为：**降级要明确告知，不能静默**。
      await tester.scrollUntilVisible(
        find.text('给我们评分'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // ★ 实测发现（重要，别再按旧假设写断言）：
      //   iOS 模拟器上 in_app_review 的 `isAvailable()` 返回 **true** ——
      //   它的 iOS 实现只判断系统版本 ≥ 10.3，模拟器同样满足；
      //   `requestReview()` 在模拟器上是 no-op：不弹窗，但也不报错。
      //   所以这里拿到的是最优结果 `inAppDialog`，**不会出现任何 toast**。
      //   （真机未上架时 SKStoreReviewController 同样不弹，行为一致。）
      //
      // 因此本阶段只锁三件事：① 该行走真实实现、不再退化成占位兜底；
      // ② 整条链路不抛异常（有异常 Flutter 测试框架会直接判失败）；
      // ③ 页面不崩、仍停在 profile。
      // 至于「弹窗 / 跳商店 / 不可用」各级回落分支，由
      // test/app_review_test.dart 的 10 个单测完整覆盖 —— 那边能精确注入
      // 平台与假实现，比集成测试更适合验证分支逻辑。
      await tester.tap(find.text('给我们评分'));
      // 评分请求走 method channel，给异步调用留出完成时间。
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ① 绝不该退化回「功能开发中」的占位兜底 ——
      //    出现它就说明这一行的 onTap 又丢了，评分功能又变回摆设。
      expect(
        find.textContaining('给我们评分功能开发中'),
        findsNothing,
        reason: '「给我们评分」应接真实实现，不再走占位兜底',
      );
      // ② 页面没崩，仍在 profile 页。
      expect(find.text('退出登录'), findsOneWidget, reason: '评分交互后应仍在资料页');

      // ============================================================
      // 阶段 5：退出登录
      // ============================================================
      // 「退出登录」在设置分组底部，需要滚动才能看到。
      await tester.scrollUntilVisible(
        find.text('退出登录'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 点击「退出登录」 → 弹出二次确认对话框。
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 二次确认对话框：标题与按钮文案。
      expect(find.text('退出登录'), findsWidgets, reason: '对话框标题应为「退出登录」');
      expect(
        find.text('确定退出当前账号？'),
        findsOneWidget,
        reason: '对话框内容应为「确定退出当前账号？」（zh.arb profileSignOutConfirm）',
      );
      expect(
        find.text('确定'),
        findsOneWidget,
        reason: '对话框应有「确定」按钮（zh.arb dialogConfirm）',
      );

      // 点「确定」 → signOut → authStateProvider 推 signedOut 事件 →
      // currentUserProvider / userProfileProvider 重算 → Profile 页回到未登录态。
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ============================================================
      // 阶段 6：回到未登录态
      // ============================================================
      expect(find.text('未登录'), findsOneWidget, reason: '登出后资料区应回到「未登录」');
      expect(find.text('点击登录 / 注册'), findsOneWidget, reason: '登出后副标题应回到登录引导');
      expect(find.text('退出登录'), findsNothing, reason: '登出后「退出登录」应再次消失');
    },
    // 整个测试串较长（启动+切语言+登录+登出+多次断言），给 5 分钟兜底。
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
