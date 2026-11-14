// ============================================================================
// 文件：feature/profile/widget/sync_member_dialog.dart
// 模块：个人中心（profile）· 会员同步对话框
//
// 职责：
//   购买成功后（或 profile 页手动触发）弹出的「同步会员到新设备」对话框。
//   用户点 Apple / Google 授权即完成「一键注册 + 权益上云绑定」——
//   OAuth 首次授权自动建号（注册=登录合一），随后调 [MemberBindService.bind]
//   把买断权益写到 `public.users.is_member`，换设备 / 重装后凭账号恢复会员。
//
// 与登录页的关系：
//   复用同一套 [AppleSignIn] / [NativeGoogleSignIn] 封装，但**收尾逻辑内聚在本
//   对话框内**：原生登录 await 返回时 session 已就绪，直接判 currentUser 并 bind，
//   不依赖全局 onAuthStateChange（同步框是临时组件，不值得挂全局监听）。
//
// 平台差异（2026-09-10 用户口径：每平台只给最顺的那条路）：
//   - iOS / macOS → 只显示「Sign in with Apple」（系统级原生弹窗 + Face ID）。
//     只提供 Apple 时不触发 App Store 4.8（该条只在给了其他第三方登录时才强制）。
//   - Android / 其他 → 只显示「Sign in with Google」；Apple 在 Android 上无原生
//     SDK、走 OAuth 还需自建服务端中转，体验差故不提供。
//
// 关键依赖：
//   - MemberBindService：bind 调用的统一封装；
//   - AppleSignIn / NativeGoogleSignIn：OAuth 平台适配层；
//   - AppLocalizations：文案 i18n。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:tool_box/common/auth/member_bind_service.dart';
import 'package:tool_box/feature/login/apple_sign_in.dart';
import 'package:tool_box/feature/login/google_sign_in_native.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 弹出「同步会员到新设备」对话框。
///
/// [source] 透传给 [MemberBindService.bind] 的埋点维度（purchase_prompt / profile）。
///
/// 返回 [SyncMemberDialogResult] 表明最终结果：
/// - [SyncMemberDialogResult.bound]：已完成注册 + 权益绑定（云端会员生效）；
/// - [SyncMemberDialogResult.dismissed]：用户点「暂不」或取消授权，未绑定。
///
/// 不抛异常：登录 / 绑定过程中的失败统一以 SnackBar 提示，返回值只区分
/// 「绑上了」与「没绑上」两种稳态，调用方据此决定是否刷新资料。
Future<SyncMemberDialogResult> showSyncMemberDialog(
  BuildContext context, {
  String source = 'purchase_prompt',
}) {
  return showDialog<SyncMemberDialogResult>(
    context: context,
    builder: (_) => _SyncMemberDialog(source: source),
  ).then((r) => r ?? SyncMemberDialogResult.dismissed);
}

/// 同步对话框的最终结果。
enum SyncMemberDialogResult {
  /// 已完成绑定（云端会员生效）。
  bound,

  /// 未绑定（暂不 / 取消）。
  dismissed,
}

/// 同步会员对话框的内部实现。
class _SyncMemberDialog extends StatefulWidget {
  const _SyncMemberDialog({required this.source});

  /// 触发来源，透传给 bind 的埋点维度。
  final String source;

  @override
  State<_SyncMemberDialog> createState() => _SyncMemberDialogState();
}

class _SyncMemberDialogState extends State<_SyncMemberDialog> {
  /// 是否正在执行「授权 + 绑定」（防连点，按钮进入 loading 态）。
  bool _busy = false;

  /// 是否显示 Apple 按钮：仅 iOS / macOS 有原生 SDK；其余平台显示 Google。
  ///
  /// 二选一而非并列：与登录页保持同一口径，每平台只给一个按钮。
  bool get _showApple => AppleSignIn.isNativeSupported;

  /// 登录并绑定统一收尾：拿到 session 后调 [MemberBindService.bind]，
  /// 结果决定是关闭对话框还是提示失败。
  Future<void> _bindAfterAuth() async {
    final result = await MemberBindService.bind(source: widget.source);
    if (!mounted) return;
    switch (result) {
      case MemberBindResult.ok:
        // 绑定成功：关闭对话框并把「已绑定」结果回传给调用方。
        Navigator.of(context).pop(SyncMemberDialogResult.bound);
      case MemberBindResult.needLogin:
        // 授权成功但未拿到 session（异常场景）：提示重试。
        _showError();
      case MemberBindResult.failed:
        _showError();
    }
  }

  /// 登录 / 绑定失败时的兜底提示。
  void _showError() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.syncMemberFailed),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Apple 一键登录 + 绑定。
  ///
  /// 原生路径 await 返回时 session 已就绪（cancelled 为主动取消，静默恢复）。
  Future<void> _appleSignIn() async {
    setState(() => _busy = true);
    try {
      final outcome = await AppleSignIn.signIn();
      if (outcome == AppleSignInOutcome.cancelled) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // completed → session 就绪，直接绑定；
      // pending  → 仅出现在非原生 OAuth 回退，本对话框只在 iOS/macOS 显示
      //            Apple 按钮，不会走到 pending；真走到时也尝试绑定（多半 needLogin）。
      await _bindAfterAuth();
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google 一键登录 + 绑定。
  ///
  /// [NativeGoogleSignIn.signInAndExchange] 返回 false 为用户主动取消，静默恢复；
  /// 返回 true 时 session 已就绪，直接绑定。
  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    try {
      final ok = await NativeGoogleSignIn.signInAndExchange();
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _bindAfterAuth();
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n.syncMemberTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.syncMemberBody,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          // 按平台二选一（与登录页保持同一口径：苹果设备只给 Apple，其余只给 Google）。
          if (_showApple)
            _buildOAuthButton(
              icon: Icons.apple,
              label: l10n.syncMemberApple,
              onPressed: _busy ? null : _appleSignIn,
            )
          else
            _buildOAuthButton(
              icon: Icons.g_mobiledata,
              iconSize: 26,
              label: l10n.syncMemberGoogle,
              onPressed: _busy ? null : _googleSignIn,
            ),
        ],
      ),
      actions: [
        // 「暂不」：用户可选择先不同步，本机权益照常生效，稍后可在 profile 手动同步。
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pop(SyncMemberDialogResult.dismissed),
          child: Text(l10n.syncMemberLater),
        ),
      ],
    );
  }

  /// 构建一枚 OAuth 登录按钮（描边样式，与登录页第三方按钮观感一致）。
  ///
  /// 高度用 [minimumSize] 给下限而非写死 height：字号放大 / 文案变长时按钮自动
  /// 长高，不裁字（沿用购买页按钮的既有约定）。
  Widget _buildOAuthButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    double iconSize = 24,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: iconSize),
        label: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
