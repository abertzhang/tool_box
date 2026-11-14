// ============================================================================
// 文件：feature/login/page/login.dart
// 模块：登录（login）
//
// 职责：
//   提供「第三方账号一键登录」（登录 = 注册合一），底层统一走 Supabase Auth。
//   邮箱密码链路已按方案 B 隐藏（见 doc/purchase_handoff.md §9），本页不再提供
//   邮箱登录 / 注册 / 忘记密码入口。
//   登录成功后自动返回：优先返回来源页（本页通常由 Profile 未登录态 push 进入），
//   无法返回（如深链直达登录页）时退回首页。
//
//   第三方登录：**按平台只给一个按钮**（每平台只留最顺的那条路）。
//   - iOS / macOS → 只显示「Sign in with Apple」（系统级原生弹窗 + Face ID，体验最佳；
//     且只提供 Apple 时根本不触发 App Store 审核指南 4.8 —— 那条只在「同时提供
//     其他第三方登录」时才强制要求给 Apple）。
//   - Android / 其他 → 只显示「Sign in with Google」；Android 上 Apple 无原生
//     SDK、走 OAuth 还需自建服务端中转，成本过高故不提供。
//   ⚠️ 这里是登录也是注册：OAuth 首次授权即自动建号（注册 = 登录合一），
//      所以没有独立的注册页。用户口径（2026-09-10）：苹果设备只给 Apple 一键注册。
//   Apple 平台差异封装在 apple_sign_in.dart；Google 走原生 google_sign_in 插件
//   （见 google_sign_in_native.dart），不再使用浏览器 OAuth 跳转。
//
// i18n（2026-09-03 修复）：
//   本页文案全部走 AppLocalizations（中/英），此前硬编码中文导致
//   英文环境下登录页仍是中文，与注册页（已走 i18n）不一致。
//
//   表单已整体移除（方案 B）：页面只剩一个第三方按钮，不再有 TextField /
//   校验 / 提交按钮，也不需要 isLoading 之外的表单状态。
//
// 关键依赖：
//   - supabase_flutter：Supabase Auth（session 监听）。
//   - go_router：返回来源页（context.pop）或回首页（context.go('/home')）。
//   - apple_sign_in：Apple 登录的平台适配层（iOS / macOS 原生，其余走 OAuth）。
//   - AppLocalizations：页面文案 i18n。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/provider/app_settings/free_usage_provider.dart';
import 'package:tool_box/feature/login/apple_sign_in.dart';
import 'package:tool_box/feature/login/google_sign_in_native.dart';
import 'package:tool_box/feature/login/page/email_login_page.dart';
import 'package:tool_box/l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// 是否有第三方登录正在进行中。
  ///
  /// 用于禁用按钮、避免连点重复拉起授权面板（原生面板叠两层会很难收场）。
  bool isLoading = false;

  /// 是否展示「Sign in with Apple」（iOS / macOS），否则展示「Sign in with Google」。
  ///
  /// **每平台只给一个按钮**（用户口径 2026-09-10）：苹果设备只给 Apple 一键登录，
  /// Android 只给 Google。理由：两条都是各平台的原生系统面板，体验最好；
  /// 混着给反而让用户在两个按钮间犹豫，且 Apple 在 Android 上没有原生 SDK
  /// （要走 OAuth + 自建服务端中转），Google 在 iOS 上虽可用但苹果生态里 Apple 更顺。
  ///
  /// 合规：只提供 Apple 时不触发 App Store 审核指南 4.8（该条仅在提供了其他
  /// 第三方登录时才强制要求「必须同时提供 Apple」），所以不存在审核风险。
  ///
  /// 用 [defaultTargetPlatform]（来自 foundation）而非 dart:io 的 Platform，
  /// 避免与 Flutter 测试 / 多平台框架产生不必要的平台耦合。
  bool get _showApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// 鉴权状态订阅：Apple 等第三方 OAuth 在外部浏览器完成授权后，
  /// 结果通过 deep link 回到 App 并由 Supabase 自动落 session，
  /// 这里一旦监听到 session 就走与密码登录完全一致的收尾跳转。
  StreamSubscription<AuthState>? _authSub;

  /// 本次登录尝试的渠道（password / apple），未发起登录时为 null。
  ///
  /// Apple / OAuth 的成功结果只出现在鉴权流里（本页拿不到返回值），
  /// 而鉴权流事件本身不携带渠道信息 —— 所以渠道只能由发起方先记在这里，
  /// 收尾时再用它补上埋点的 method 维度。成功上报后立即清空，
  /// 避免后续 Token 续期事件被误记成一次新的登录成功。
  String? _pendingMethod;

  @override
  void initState() {
    super.initState();
    // 用 try/catch 包裹：未初始化 Supabase 时访问 instance 会抛
    // LateInitializationError，配置缺失不应导致页面崩溃。
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (mounted && state.session != null) {
          _goAfterLogin();
        }
      });
    } catch (e) {
      debugPrint('[LoginPage] 监听鉴权状态失败（Supabase 可能未初始化）: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// 登录成功后的收尾：轻提示 + 返回来源页（无法返回则回首页）。
  ///
  /// 密码登录与 OAuth 回调共用这段逻辑，保证两条路径行为完全一致，
  /// 避免以后改了其中一条、另一条忘记跟着改（这是最容易漏的地方）。
  void _goAfterLogin() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // 登录成功埋点：成功率的分子。
    // 只在 [_pendingMethod] 非空时上报 —— 它为空说明这次 session 变化来自
    // Token 续期或别处触发，不是本页发起的登录，计入会虚增登录次数。
    final String? method = _pendingMethod;
    if (method != null) {
      _pendingMethod = null;
      AppTrack.authResult(method: method, success: true);
    }

    // SnackBar 挂在根级 ScaffoldMessenger 上，页面返回后仍会正常展示。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.loginSuccess),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 登录成功：立刻把云端 tool_usage_count 同步回本地，确保重装 / 跨设备后
    // 免费额度立即生效（即使后续没立刻打开工具页）。失败不阻断登录收尾，
    // 下次打开工具页会再由 Provider 自动对齐。
    try {
      unawaited(
        ProviderScope.containerOf(context)
            .read(freeUsageProvider.notifier)
            .syncFromCloud(),
      );
    } catch (_) {
      // 同步异常静默忽略，不影响登录流程。
    }
    // ★ 登录成功自动返回（2026-09-03 UX 修复）：
    //   能 pop（被 push 进入，如 Profile 未登录跳转）→ 返回来源页，
    //   鉴权流会自动刷新 Profile UI；
    //   不能 pop（深链直达登录页）→ 兜底回首页。
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Apple 账号一键登录。
  ///
  /// iOS / macOS 走**原生**系统授权弹窗（Face ID，不跳出 App），
  /// 其余平台回退到 Supabase OAuth 浏览器流程；平台差异由 [AppleSignIn] 内部屏蔽。
  ///
  /// 与注册页的 Apple 一键注册是同一条链路：账号不存在时 Supabase 会自动建号，
  /// 已存在则直接登录——Sign in with Apple 本身就是「注册与登录合一」的流程，
  /// 所以这里不需要、也无法区分本次究竟是注册还是登录。
  ///
  /// 两条路径的收尾统一交给 [initState] 里的 onAuthStateChange 监听：
  /// 原生登录后 Supabase 会落 session 并派发事件，与 OAuth 的 deep link 回调
  /// 殊途同归。因此这里**不再主动调用** [_goAfterLogin] —— 否则会与监听重复触发，
  /// 表现为连弹两次提示或连退两层页面。
  Future<void> _appleSignIn() async {
    setState(() => isLoading = true);
    // Apple 的成功结果走鉴权流（不在本方法的返回值里），
    // 因此「本次是 Apple 渠道」这件事必须先记下来，等收尾时再带上。
    _pendingMethod = 'apple';
    try {
      // 返回值这里刻意忽略：无论 completed 还是 pending，收尾都由监听负责；
      // cancelled 也只是静默恢复按钮，不需要额外分支。
      await AppleSignIn.signIn();
    } catch (e) {
      // 不用 `on AuthException`：原生路径还可能抛出 Apple 插件自己的异常类型，
      // 只捕获 Supabase 异常会让原生登录的错误静默消失（按钮转圈后无反应）。
      AppTrack.authResult(
        method: 'apple',
        success: false,
        // 异常类型即错误码：Apple 原生路径的错误不走 Supabase，没有 code 字段。
        errorCode: e.runtimeType.toString(),
      );
      _pendingMethod = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Google 账号一键登录（仅非 iOS 平台展示，见 [_isIOS]）。
  ///
  /// 走原生 [NativeGoogleSignIn] 流程：弹出系统级 Google 授权面板（Android 账号选择器 /
  /// iOS 系统 Google 弹窗），授权后在本地用 idToken + accessToken 与 Supabase 交换
  /// session，全程不跳出 App，体验优于旧版浏览器 OAuth 跳转。
  /// 授权成功由 [initState] 里的 onAuthStateChange 监听收尾（与密码登录共用 [_goAfterLogin]）；
  /// 这里不主动跳转，避免与监听重复触发。
  ///
  /// 失败分支：原生授权拉起失败 / 令牌缺失 / Supabase 校验失败才就地上报与提示；
  /// 用户主动取消（返回 false）只静默恢复按钮，不计入登录失败。
  Future<void> _googleSignIn() async {
    setState(() => isLoading = true);
    // Google 的成功结果走鉴权流（不在本方法返回值里），
    // 因此「本次是 Google 渠道」必须先记账，等收尾时再带上 method 维度。
    _pendingMethod = 'google';
    try {
      final bool ok = await NativeGoogleSignIn.signInAndExchange();
      if (!ok) {
        // 用户主动取消：不算失败，恢复待定渠道、静默返回。
        _pendingMethod = null;
      }
    } on AuthException catch (e) {
      AppTrack.authResult(
        method: 'google',
        success: false,
        errorCode: e.code ?? e.statusCode,
      );
      _pendingMethod = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      AppTrack.authResult(
        method: 'google',
        success: false,
        errorCode: e.runtimeType.toString(),
      );
      _pendingMethod = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// 跳转独立的邮箱密码登录页（[EmailLoginPage.route]）。
  ///
  /// 该页只负责「邮箱 + 密码」这一种登录方式；登录成功后它自行返回本页，
  /// 由本页 [initState] 里统一的鉴权监听收尾（[_goAfterLogin]），
  /// 因此这里不处理返回值、也不重复跳转。
  Future<void> _goEmailLogin() async {
    await context.push(EmailLoginPage.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 顶部返回按钮：从首页 push 进入，提供明确返回入口，避免只能依赖系统手势返回。
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        // 内边距上下分开设置：原先 vertical: 100 会让顶部图标上方空出一大片，
        // 现在顶部只留 8（紧贴透明 AppBar 下沿，不再有大块留白），
        // 底部仍保留 100 作为软键盘弹起时的滚动余量，
        // 避免输入框被键盘顶住后底部内容被裁切（溢出）。
        padding: const EdgeInsets.only(left: 28, right: 28, top: 8, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo / 标题区域
            //
            // 图标统一取资源文件 assets/images/app.png（已在 pubspec 的 flutter.assets 中声明），
            // 不再使用 Icon(Icons.link) 占位，保证与 App 启动图标视觉一致。
            // ClipRRect 只做圆角裁剪：源图自带圆角与透明通道，这里再裁一次是为了
            // 在不同倍率下边缘不会出现直角毛边。
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                "Tool Box",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                // 品牌名 Tool Box 保持原文，副标题走 i18n。
                l10n.loginSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // 登录入口卡片：只有第三方一键登录。
            //
            // 邮箱密码表单已按方案 B 移除（见 doc/purchase_handoff.md §9），
            // 所以这里不再有 TextField / 提交按钮 / 「注册」「忘记密码」入口，
            // 也不需要「OR」分隔线 —— 页面上只剩两条登录路径，分隔线只会制造噪音。
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 第三方一键登录：**按平台二选一**（[_showApple]）。
                    //
                    // 每平台只给一个按钮，避免用户在选择上犹豫；两个平台走的都是
                    // 各自的系统级原生授权面板，体验最佳。
                    // 合规：iOS 只提供 Apple 完全满足审核指南 4.8（该条只在提供了
                    // 其他第三方登录时才强制要求同时给 Apple）。
                    //
                    // 按钮高度用 minimumSize 而非外层 SizedBox(height: N)：
                    // 写死高度时 Material 3 的进度指示器会被压成椭圆（详见项目约定）。
                    if (_showApple)
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _appleSignIn,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.apple, size: 24),
                        label: Text(
                          l10n.appleSignIn,
                          style: const TextStyle(fontSize: 15),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // 说明：Material Icons 无官方 Google 品牌图标，这里用形近的
                        // g_mobiledata 占位；如需品牌规范可替换为 assets 内彩色 SVG。
                        icon: const Icon(Icons.g_mobiledata, size: 26),
                        label: Text(
                          l10n.googleSignIn,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    // 邮箱密码登录入口：跳到独立的 /login/email 页面。
                    //
                    // 主要面向应用商店审核：审核员没有可用 Apple ID 时，可用
                    // 邮箱 + 密码登录以验证登录态相关功能（云同步额度、会员等），
                    // 规避「无法提供演示账号」触发的 Guideline 2.1。
                    // 邮箱密码链路此前按方案 B 从本页隐藏（doc/purchase_handoff.md §9），
                    // 现改为由独立页面承载，不再挤占本页的主登录流程。
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _goEmailLogin,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.mail_outline, size: 22),
                      label: Text(
                        l10n.emailSignIn,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    // 授权进行中的统一提示：两个按钮共用一个 loading 态，
                    // 用户能明确知道「正在等系统面板」，而不是以为按钮点了没反应。
                    if (isLoading) ...[
                      const SizedBox(height: 18),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
