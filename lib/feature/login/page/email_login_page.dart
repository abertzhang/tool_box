// ============================================================================
// 文件：feature/login/page/email_login_page.dart
// 模块：登录（login）
//
// 职责：
//   提供「邮箱 + 密码」这一条独立的登录链路，底层走 Supabase Auth 的
//   signInWithPassword。与 login.dart 的第三方一键登录（Apple / Google）并列，
//   但拆成独立页面承载，不挤占登录页的主流程。
//
// 为什么要有这个页面（2026-09-30 新增）：
//   App 在 iOS 端只提供 Sign in with Apple，若商店审核员没有可用的 Apple ID，
//   就完全无法登录，进而无法验证「登录后才可见」的功能（云同步免费额度、
//   会员权益等），容易被判 Guideline 2.1（App Completeness）。
//   本页提供一个与 Apple 无关的邮箱登录入口，配合 ASC 备注里给出的演示账号，
//   即可满足审核员的验证需要。
//
//   邮箱密码链路此前按方案 B 整体隐藏（见 doc/purchase_handoff.md §9），
//   本页是它的**独立复活**：不动 login.dart 原有的 OAuth 主流程，
//   只在登录页多出一个通向本页的入口按钮。
//
// 收尾约定（重要）：
//   登录成功后本页**只返回上一页**（context.pop 回到登录页），跳转收尾
//   交给登录页 initState 里统一的 onAuthStateChange 监听（_goAfterLogin）。
//   这样「能 pop 就回来源页、不能 pop 就回首页」的行为与 Apple / Google
//   登录完全一致，本页不自己决定跳到哪里，也避免了两层页面各自 pop 的混乱。
//
// 关键依赖：
//   - supabase_flutter：signInWithPassword / resetPasswordForEmail。
//   - go_router：登录成功后 context.pop() 返回登录页。
//   - AppLocalizations：页面文案 i18n（emailHint / passwordHint / loginSubmit ...）。
// ============================================================================

// 网络异常类型来自 dart:io（SocketException 等）与 dart:async（超时 exception），
// 需要在 catch 里区分「网络层问题」和「账号问题」，别把原始栈抛给用户看。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 邮箱密码登录页。
///
/// 由登录页的「使用邮箱登录」按钮 push 进入（见 login.dart 的 [_goEmailLogin]）。
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  /// 本页路由路径。
  ///
  /// 集中定义在这里：登录页用 context.push(EmailLoginPage.route) 引用，
  /// app_router.dart 注册同一常量，避免路径字符串散落各处后改漏。
  static const String route = '/login/email';

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  /// 邮箱输入框控制器。
  final TextEditingController _emailCtrl = TextEditingController();

  /// 密码输入框控制器。
  final TextEditingController _pwdCtrl = TextEditingController();

  /// 是否正在请求登录 / 发送重置邮件（禁用按钮 + 展示转圈）。
  bool _loading = false;

  /// 密码是否密文显示（眼睛图标切换）。
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  /// 邮箱 + 密码登录。
  ///
  /// 成功：直接返回登录页，由登录页的鉴权监听统一收尾跳转（见类注释）。
  /// 失败：Supabase 的 [AuthException] 直接展示服务端语义化消息
  ///       （如「邮箱未确认」「邮箱或密码错误」），其余异常兜底展示原始信息。
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final String email = _emailCtrl.text.trim();
    final String password = _pwdCtrl.text;

    // 前端先做基本校验：格式明显不对时不必发请求，省一次网络往返。
    // 这里只粗校验「含 @」，真正的格式校验交给服务端（避免正则过度严格）。
    if (email.isEmpty || !email.contains('@')) {
      _toast(l10n.errEmailInvalid);
      return;
    }
    // 空密码同样不满足最短长度，复用「密码至少 6 位」这条提示文案。
    if (password.length < 6) {
      _toast(l10n.errPasswordShort);
      return;
    }

    setState(() => _loading = true);
    try {
      await _signInWithRetry(email, password);
      // 成功：返回登录页，收尾跳转由登录页的监听负责。
      if (mounted) context.pop();
    } on AuthException catch (e) {
      // 服务端语义化错误（邮箱未确认 / 邮箱或密码错误）：直接展示服务端文案。
      if (mounted) _toast(e.message);
    } catch (e) {
      // 兜底：不能把 dio 原始报文抛给用户看。
      // 典型场景——真机连不上服务端时透出的是
      //   `ClientException with SocketException: Connection reset by peer (errno = 54)`
      // 这一串既看不懂、用户也无从处理，必须换成可操作的中文提示。
      debugPrint('[EmailLogin] 登录失败: $e');
      if (mounted) {
        _toast(_isNetworkError(e) ? l10n.errNetworkReset : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 判断异常是否属于**网络层**（连接被重置 / TLS 握手失败 / 超时 / 不可达）。
  ///
  /// 除标准的 [SocketException] / [HandshakeException] / [TimeoutException] 外，
  /// 还要用字符串兜底：Supabase Auth 底层走的是 dio，网络层异常会以
  /// `ClientException with SocketException ...` 的形式透出，且被包过一层，
  /// 仅靠类型判断不一定命中。这里只关心「是不是网络问题」，故用内容嗅探。
  bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is HandshakeException ||
      e is TimeoutException ||
      e.toString().contains('ClientException') ||
      e.toString().contains('DioException');

  /// 带**一次重试**的登录请求（仅网络层异常才重试）。
  ///
  /// 为什么值得重试：真机上 `Connection reset by peer`（errno=54 ECONNRESET）
  /// 大多发生在 **TLS 握手阶段**，由链路中间的设备（家用路由器、公司防火墙、
  /// 加速器规则）主动掐断——此时请求还没真正送达服务端，换个连接重试通常
  /// 就能建连成功。AuthException（账号或密码错）不在此列，重试纯属浪费。
  Future<void> _signInWithRetry(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (!_isNetworkError(e) || !mounted) rethrow;
      debugPrint('[EmailLogin] 首次请求网络失败（$e），重试一次');
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    }
  }

  /// 忘记密码：向邮箱发送重置链接。
  ///
  /// 走 Supabase 的 resetPasswordForEmail，邮件模板与发送域名在 Supabase
  /// 后台配置；这里只负责把用户填的邮箱提交上去并给出结果提示。
  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast(l10n.errEmailInvalid);
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) _toast(l10n.resetPasswordSent);
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 统一的轻提示（红色底表示出错，成功提示也复用同一通道）。
  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.login)),
      body: SafeArea(
        // 单列滚动 + 底部留余量：软键盘弹起时输入框不会被顶住后裁切。
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 邮箱
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                // 禁用自动纠错：邮箱地址被自动改正会直接导致登录失败。
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.emailHint,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 16),
              // 密码（可切换明文）
              TextField(
                controller: _pwdCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                // 回车即提交，与登录按钮等价。
                onSubmitted: (_) => _loading ? null : _submit(),
                decoration: InputDecoration(
                  labelText: l10n.passwordHint,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 忘记密码：右对齐的小按钮，不抢主按钮的视觉重心。
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: 12),
              // 主操作按钮。
              //
              // 高度用 minimumSize 而非外层 SizedBox(height: N)：
              // 写死高度时 Material 3 的进度指示器会被压成椭圆（详见项目约定）。
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(l10n.loginSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
