// ============================================================================
// 文件：feature/profile/page/privacy_policy_page.dart
// 模块：个人中心（profile）/ 隐私政策
//
// 职责：
//   展示应用《隐私政策》全文的独立页面，路由 `/profile/privacy`，
//   由资料页「关于」分组的「隐私政策」行 push 进入。
//
// 设计取舍：
//   1. **与账号状态解耦**：隐私政策属于「任何时候都能看」的公开内容，
//      因此本页不读 Supabase、不判断登录态 —— 未登录用户同样可以正常打开。
//   2. **纯静态内容页**：无网络请求、无状态，用 [StatelessWidget] 实现即可；
//      正文按「章节标题 + 段落」渲染，全部文案走 i18n（中/英）。
//   3. **配色取 ColorScheme**：与编辑资料页保持一致，由 AppTheme 的浅色 / 深色
//      两套方案自动适配，不再自建调色板（避免同模块两套色值各改各的）。
//
// 关键依赖：
//   - AppLocalizations：全部文案走 i18n（中/英）；
//   - go_router：由 route_profile.dart 登记路径。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/provider/locale/locale_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 隐私政策「最后更新时间」。
///
/// 写死为常量而不是取运行时间：政策内容没变就不该因为用户打开时间不同而
/// 显示不同日期，否则会被理解为政策一直在改。
/// ★ 每次修订政策正文时，请同步更新这里。
const String _lastUpdated = '2026-09-09';

/// 隐私政策页。
///
/// 结构：顶部一行「最后更新时间」→ 引言段落 → 若干「标题 + 正文」章节，
/// 整页放在 [SingleChildScrollView] 里，保证任何机型都能通读到底。
class PrivacyPolicyPage extends ConsumerStatefulWidget {
  /// 创建隐私政策页。
  const PrivacyPolicyPage({super.key});

  @override
  ConsumerState<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends ConsumerState<PrivacyPolicyPage> {
  @override
  void initState() {
    super.initState();
    // 页面到达埋点：合规披露的**可触达性**证据（审核关注点），
    // 同时反映用户对隐私的关注程度。
    //
    // 放在 initState 而不是入口行点击处（资料页「隐私政策」行）：
    //   1. initState 只在页面真实创建时执行一次，切主题 / 切语言触发的
    //      rebuild 不会重复上报；入口行点击处上报则与其它文档页口径不一，
    //      还容易在「点开又立刻返回」时把没看到内容的人算成已读。
    //   2. init 只在 State 创建时跑，天然去重。
    // ref.read 在 initState 中是允许的（watch 才不行）。
    AppTrack.log(
      TrackEvents.pageDocView,
      params: <String, Object?>{
        'page': 'privacy',
        'locale': ref.read(localeProvider),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: SingleChildScrollView(
        // 左右 20、底部留 32：正文是可读性优先的长文本，
        // 底部多留一点避免最后一行贴着屏幕边缘。
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 最后更新时间：放在最顶部，让用户一眼知道内容的时效性。
            Text(
              l10n.privacyLastUpdated(_lastUpdated),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // 引言：不用章节标题，单独成段，作为全文的 opener。
            Text(
              l10n.privacyIntro,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // 正文章节：顺序即政策条款顺序。
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecCollect,
              body: l10n.privacySecCollectBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecUse,
              body: l10n.privacySecUseBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecStore,
              body: l10n.privacySecStoreBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecShare,
              body: l10n.privacySecShareBody,
            ),
            // 广告章节（接入 AdMob 横幅后新增）：
            // 商店审核会核对「隐私政策是否披露了广告与标识符使用」，
            // SDK 清单页的披露不能替代政策正文，故两处都要有。
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecAds,
              body: l10n.privacySecAdsBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecRights,
              body: l10n.privacySecRightsBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecUpdate,
              body: l10n.privacySecUpdateBody,
            ),
            // 末章（联系我们）不再额外加底部间距：
            // 外层 padding 已留 32，再加会显得尾部过空。
            _buildSection(
              scheme: scheme,
              title: l10n.privacySecContact,
              body: l10n.privacySecContactBody,
              addBottomSpace: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 单个政策章节：加粗小标题 + 正文段落。
  ///
  /// 参数：
  /// - [scheme] 当前主题配色；
  /// - [title] 章节标题（如「一、我们收集的信息」）；
  /// - [body] 章节正文；
  /// - [addBottomSpace] 章节下方是否留间距，默认 true。
  ///   **最后一章传 false**：外层滚动容器底部已有 32 的内边距，
  ///   再叠一层章节间距会让尾部显得空旷。
  ///
  /// 正文行高固定 1.6：政策类长文本行距太挤会显著影响阅读耐力，
  /// 这是可读性优先于紧凑排版的取舍。
  Widget _buildSection({
    required ColorScheme scheme,
    required String title,
    required String body,
    bool addBottomSpace = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: addBottomSpace ? 20 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
