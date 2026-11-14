// ============================================================================
// 文件：feature/profile/page/user_agreement_page.dart
// 模块：个人中心（profile）/ 用户协议
//
// 职责：
//   展示应用《用户协议》全文的独立页面，路由 `/profile/user-agreement`，
//   由资料页「关于」分组的「用户协议」行 push 进入。
//
// 设计取舍：
//   1. **为什么是本地页面而不是 WebView**：原本走 WebDocPage 展示在线地址
//      https://www.aknot.uk/app/tool-box?type=1，但该域名在 Cloudflare 上
//      **始终未配置 A 记录**（www 与根域均解析失败），任何平台打开都是加载失败。
//      协议属于「上架前必须可读」的合规内容，不能依赖站点就绪情况，
//      故改为与隐私政策一致的**本地静态页**，保证任何时刻都能打开。
//      ⚠️ 2026-09-17 现状：在线文档已迁移到 GitHub Pages，但那里**只托管了隐私
//      政策**（https://aberciozhang.github.io/privacy/tool-box），并没有用户协议页，
//      因此本页继续作为唯一来源保留。
//      ⚠️ 另注：该站点是静态页，`?type=` 查询参数不生效——实测 type=1/2/3 与不带
//      参数都返回同一份《Privacy Policy》，不要误以为能靠参数切换文档类型。
//   2. **与账号状态解耦**：协议是公开内容，不读 Supabase、不判登录态，
//      未登录用户同样可以正常打开。
//   3. **纯静态内容页**：无网络请求、无状态，正文按「章节标题 + 段落」渲染，
//      全部文案走 i18n（中/英），结构与 PrivacyPolicyPage 保持一致。
//   4. **配色取 ColorScheme**：由 AppTheme 的浅色 / 深色方案自动适配，
//      不再自建调色板（避免同模块两套色值各改各的）。
//   5. 「最后更新时间」复用 [AppLocalizations.privacyLastUpdated]：该词条语义
//      是通用的「最后更新时间：{date}」，与具体文档无关；gen-l10n 当前不可用，
//      复用可避免为带占位符的新词条手工同步 5 处文件。
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

/// 用户协议「最后更新时间」。
///
/// 写死为常量而不是取运行时间：协议内容没变就不该因为用户打开时间不同而
/// 显示不同日期，否则会被理解为条款一直在改。
/// ★ 每次修订协议正文时，请同步更新这里。
const String _lastUpdated = '2026-09-15';

/// 用户协议页。
///
/// 结构：顶部一行「最后更新时间」→ 引言段落 → 若干「标题 + 正文」章节，
/// 整页放在 [SingleChildScrollView] 里，保证任何机型都能通读到底。
class UserAgreementPage extends ConsumerStatefulWidget {
  /// 创建用户协议页。
  const UserAgreementPage({super.key});

  @override
  ConsumerState<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends ConsumerState<UserAgreementPage> {
  @override
  void initState() {
    super.initState();
    // 页面到达埋点：与隐私政策同口径（page_doc_view + page 标识），
    // 证明协议对用户真实可触达 —— 这也是商店审核的关注点。
    //
    // 放在 initState 而非入口行点击处：initState 只在页面真实创建时执行一次，
    // 切主题 / 切语言触发的 rebuild 不会重复上报，也不会把「点开立刻返回」
    // 的人算成已读。
    // ref.read 在 initState 中是允许的（watch 才不行）。
    AppTrack.log(
      TrackEvents.pageDocView,
      params: <String, Object?>{
        'page': 'user_agreement',
        'locale': ref.read(localeProvider),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(l10n.userAgreement)),
      body: SingleChildScrollView(
        // 左右 20、底部留 32：正文是可读性优先的长文本，
        // 底部多留一点避免最后一行贴着屏幕边缘。与隐私政策页保持一致。
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 最后更新时间：放在最顶部，让用户一眼知道内容的时效性。
            Text(
              l10n.privacyLastUpdated(_lastUpdated),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // 引言：不用章节标题，单独成段，作为全文的 opener。
            Text(
              l10n.agreementIntro,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // 正文章节：顺序即协议条款顺序。
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecAccept,
              body: l10n.agreementSecAcceptBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecService,
              body: l10n.agreementSecServiceBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecAccount,
              body: l10n.agreementSecAccountBody,
            ),
            // 免费额度与广告：与 App 内实际机制一致（免费次数上限 + 看广告返还），
            // 写清楚可避免用户对「为什么突然要收费」产生争议。
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecFree,
              body: l10n.agreementSecFreeBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecPurchase,
              body: l10n.agreementSecPurchaseBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecConduct,
              body: l10n.agreementSecConductBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecIp,
              body: l10n.agreementSecIpBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecDisclaimer,
              body: l10n.agreementSecDisclaimerBody,
            ),
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecUpdate,
              body: l10n.agreementSecUpdateBody,
            ),
            // 末章（联系我们）不再额外加底部间距：
            // 外层 padding 已留 32，再加会显得尾部过空。
            _buildSection(
              scheme: scheme,
              title: l10n.agreementSecContact,
              body: l10n.agreementSecContactBody,
              addBottomSpace: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 单个协议章节：加粗小标题 + 正文段落。
  ///
  /// 参数：
  /// - [scheme] 当前主题配色；
  /// - [title] 章节标题（如「一、协议的接受」）；
  /// - [body] 章节正文；
  /// - [addBottomSpace] 章节下方是否留间距，默认 true。
  ///   **最后一章传 false**：外层滚动容器底部已有 32 的内边距，
  ///   再叠一层章节间距会让尾部显得空旷。
  ///
  /// 正文行高固定 1.6：协议类长文本行距太挤会显著影响阅读耐力，
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
        children: <Widget>[
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
