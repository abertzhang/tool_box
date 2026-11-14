// ============================================================================
// 文件：feature/profile/util/account_actions.dart
// 模块：我的 / 个人中心（profile）· 账号操作工具
//
// 职责：
//   把「退出登录」与「注销账号」两个需要二次确认的账号危险操作抽成顶层函数，
//   供 [ProfilePage]（原内联的退出逻辑）与 [AccountSecurityPage]（账号安全详情页）
//   复用，避免逻辑散落与重复实现。
//
// 设计要点：
//   - 两个函数都先捕获 [ScaffoldMessengerState]，再进入可能的异步等待，
//     规避 use_build_context_synchronously 与「页面已销毁后触碰 context」的崩溃；
//   - 每次 await 之后都判 `context.mounted` 再触碰 context；
//   - 退出登录：登出后 [authStateProvider] 会推送事件，资料/会员态自动回到未登录，
//     这里额外 invalidate 一次兜住「流事件晚于本方法返回」的时序差。
//   - 注销账号：走 [AccountDeleteService]（服务端删除），成功后强制本地登出并 pop
//     回上一个页面（账号安全页 → 个人中心），个人中心随之显示未登录态。
//
// 关键依赖：
//   - flutter_riverpod：WidgetRef；
//   - supabase_flutter：auth.signOut；
//   - common/auth/account_delete_service：注销调用；
//   - feature/profile/provider/user_profile_provider：refreshUserProfile；
//   - common/analytics：埋点。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/auth/account_delete_service.dart';
import 'package:tool_box/feature/profile/provider/user_profile_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 退出登录（先二次确认，避免误触）。
///
/// [context] 用于弹确认框；[ref] 用于登出后失效资料 Provider。
/// 登出成功后无需手动刷新 UI：[authStateProvider] 会推送事件，
/// [currentUserProvider] / [userProfileProvider] 随之重算。
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  // 在 await 前捕获 messenger，避免跨异步间隙后再用 BuildContext。
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.profileSignOut),
      content: Text(l10n.profileSignOutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.dialogCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.dialogConfirm),
        ),
      ],
    ),
  );
  if (ok != true) return;
  if (!context.mounted) return;
  try {
    // 登出前记录是否已有云端资料：集中式登出可能意味着体验问题
    // （如资料同步异常），需要结合「登出后是否回流」一起看。
    final bool hadProfile = ref.read(userProfileProvider).value != null;
    await Supabase.instance.client.auth.signOut();
    // 登出埋点：账号流失信号。
    AppTrack.log(
      TrackEvents.authLogout,
      params: <String, Object?>{'had_cloud_profile': hadProfile},
    );
    refreshUserProfile(ref);
  } catch (e) {
    debugPrint('[Profile] 退出登录失败: $e');
    AppTrack.error('auth', e);
    messenger.showSnackBar(
      SnackBar(content: Text('$e'), duration: const Duration(seconds: 2)),
    );
  }
}

/// 注销账号（删除账号，先二次确认，且明确告知不可逆）。
///
/// [context] 用于弹确认框；[ref] 用于注销成功后失效资料 Provider。
/// 走 [AccountDeleteService]（服务端以 service_role 调 Admin API 删除当前用户），
/// 客户端无「删除当前用户」API，必须借服务端能力。
/// 成功后：强制本地登出（best-effort）+ invalidate 资料 + pop 回个人中心。
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  // 在 await 前捕获 messenger：取「根导航器」上下文上的 ScaffoldMessenger，
  // 这样注销成功 pop 回个人中心后，成功提示仍能在目标页继续显示
  // （页面级 ScaffoldMessenger 会随本页卸载被清掉）。
  final BuildContext rootCtx =
      Navigator.of(context, rootNavigator: true).context;
  final messenger = ScaffoldMessenger.of(rootCtx);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteAccount),
      // 确认文案 + 不可逆警告合并展示，让用户充分知情。
      content: Text('${l10n.deleteAccountConfirm}\n\n${l10n.deleteAccountWarning}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.dialogCancel),
        ),
        // 危险操作按钮：用删除账号文案本身，颜色交给调用方页面控制（红色）。
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.deleteAccount),
        ),
      ],
    ),
  );
  if (ok != true) return;
  if (!context.mounted) return;

  try {
    final DeleteAccountResult result = await AccountDeleteService.delete();
    if (!context.mounted) return;
    switch (result) {
      case DeleteAccountResult.ok:
        // 注销成功：服务端已删账号，本地仍可能保留会话，强制登出以清掉本地态
        // （即便访问令牌已失效，signOut 失败也不影响后续 pop）。
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {
          // 账号已删，令牌大概率已失效，signOut 失败可忽略。
        }
        if (!context.mounted) return;
        ref.invalidate(userProfileProvider);
        // 先弹成功提示（root messenger，随 pop 回个人中心后仍可见），
        // 再返回上一个页面（账号安全页 → 个人中心）；个人中心会随鉴权事件切回未登录态。
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.deleteAccountDone),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
      case DeleteAccountResult.needLogin:
        // 登录态异常丢失：回到登录页。
        context.push('/login');
      case DeleteAccountResult.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.deleteAccountFailed),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  } catch (e) {
    debugPrint('[Account] 注销失败: $e');
    AppTrack.error('auth', e);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$e'), duration: const Duration(seconds: 2)),
    );
  }
}
