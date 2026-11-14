// ============================================================================
// 文件：feature/profile/page/account_security_page.dart
// 模块：我的 / 个人中心（profile）· 账号安全详情页
//
// 职责：
//   承载「账号安全」独立页面，集中放两类账号危险操作：
//   - 退出登录（[confirmSignOut]）
//   - 注销账号（[confirmDeleteAccount]，服务端删除用户，不可逆）
//   个人中心「设置」分组只保留一个「账号安全」入口跳到这里，
//   避免把两个危险操作直接堆在首页设置里。
//
// 设计：复用个人中心通用色板（[AppPalette]），与 profile_page 视觉一致；
//   「注销账号」用红色危险样式（图标 + 文字 + 箭头）与「退出登录」区分，
//   提示用户这是不可逆操作。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/feature/profile/provider/user_profile_provider.dart';
import 'package:tool_box/feature/profile/util/account_actions.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 账号安全详情页（退出登录 + 注销账号）。
///
/// 列表项均带二次确认，注销账号额外强调「不可逆」。
class AccountSecurityPage extends ConsumerWidget {
  /// 创建账号安全页。无参数：操作均依赖当前登录态，由 Provider 实时判定。
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final app = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 危险操作色：深色用浅红、浅色用深红，保证在两种主题下都清晰可读。
    final dangerColor =
        isDark ? const Color(0xFFFF9B9B) : const Color(0xFFB3261E);

    final bool loggedIn = ref.watch(currentUserProvider) != null;

    return Scaffold(
      backgroundColor: app.pageBg,
      appBar: AppBar(
        // 跟随主题的标题与背景：不与 profile_page 的沉浸式头部冲突，本页用标准 AppBar。
        backgroundColor: app.pageBg,
        foregroundColor: app.titleText,
        elevation: 0,
        title: Text(l10n.accountSecurity),
      ),
      body: loggedIn
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: app.cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      context: context,
                      icon: Icons.logout,
                      title: l10n.profileSignOut,
                      color: app.titleText,
                      onTap: () async {
                        // 退出成功后（已登录态变为未登录）自动返回个人中心，
                        // 避免在「账号安全」页残留「请先登录」占位。
                        await confirmSignOut(context, ref);
                        if (context.mounted &&
                            ref.read(currentUserProvider) == null) {
                          context.pop();
                        }
                      },
                    ),
                    Divider(height: 1, thickness: 1, color: app.divider),
                    _buildRow(
                      context: context,
                      icon: Icons.delete_forever_outlined,
                      title: l10n.deleteAccount,
                      // 危险操作：统一红色，提示不可逆。
                      color: dangerColor,
                      onTap: () => confirmDeleteAccount(context, ref),
                    ),
                  ],
                ),
              ),
            )
          // 兜底：未登录时引导去登录（正常不会到这一页，入口仅在登录态可见）。
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.profileTapLogin,
                  style: TextStyle(fontSize: 14, color: app.labelText),
                ),
              ),
            ),
    );
  }

  /// 构建单行：图标 + 标题 + 箭头，整行可点。
  ///
  /// [color] 控制图标与文字颜色（退出登录用常规色、注销账号用危险红）。
  Widget _buildRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: color),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
