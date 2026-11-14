// ============================================================================
// 文件：feature/profile/page/about_us_page.dart
// 模块：个人中心（profile）/ 关于我们（About Us）
//
// 职责：
//   展示《关于我们》全文的独立页面，路由 `/profile/about-us`，
//   由资料页「关于」分组的「关于我们」行 push 进入。
//
// 设计取舍：
//   1. **与账号状态解耦**：关于我们是公开内容，不读 Supabase、不判断登录态，
//      未登录用户同样可以正常打开（与隐私政策 / 第三方 SDK 清单页一致）。
//   2. **纯静态内容页**：无网络请求、无内部状态，用 [ConsumerWidget] 仅为了
//      读取 [localeProvider] 给埋点附上当前语言；正文渲染配色取 ColorScheme，
//      随浅色 / 深色主题自动适配。
//   3. **正文内容为英文**：本 App 面向海外英文用户，关于我们正文按需求直接以
//      英文撰写（不走 i18n、不拆 data 文件）—— 如需中英双语可参照
//      third_party_sdk_page 的 data 文件方案扩展，本页暂按英文落地。
//
// 关键依赖：
//   - AppLocalizations：仅 AppBar 标题（l10n.aboutUs）走 i18n，与资料页该行共用；
//   - localeProvider：决定埋点里的 locale 字段；
//   - go_router：由 route_profile.dart 登记路径；
//   - app_track：进入页面时记一次 page_doc_view 埋点（page=about_us）。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../../../common/provider/locale/locale_provider.dart';

/// 关于我们「版本号」。
///
/// 写死为常量而不是取运行信息：版本号属于对外披露口径，
/// 应与 App Store / 上架信息一致；升级版本时请在此同步修改。
const String _appVersion = '2.1.0';

/// 关于我们「更新时间」：正文若随版本调整，请同步更新此处。
const String _lastUpdated = '2026-09-06';

/// 关于我们页（英文正文）。
///
/// 结构：顶部 App 名称 + 版本 → 引言段落 → 若干「标题 + 正文」章节 → 版权页脚，
/// 整页放在 [SingleChildScrollView] 内，保证任意机型都能通读到底。
class AboutUsPage extends ConsumerStatefulWidget {
  /// 创建关于我们页。
  const AboutUsPage({super.key});

  @override
  ConsumerState<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends ConsumerState<AboutUsPage> {
  @override
  void initState() {
    super.initState();
    // 进入页面埋点：可触达性证据 + 用户对「关于我们」的关注度。
    // 复用 page_doc_view（与隐私政策 / 第三方 SDK 清单一致），page 用稳定标识 about_us。
    //
    // 放在 initState 而不是 build：build 每次重建（切主题 / 切语言）都会执行，
    // 原先写在这里会让一次浏览上报多条；initState 只在页面创建时跑一次。
    // ref.read 在 initState 中是允许的（watch 才不行）。
    AppTrack.log(
      TrackEvents.pageDocView,
      params: <String, Object?>{
        'page': 'about_us',
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
      appBar: AppBar(title: Text(l10n.aboutUs)),
      body: SingleChildScrollView(
        // 左右 20、底部 32：长正文可读性优先，底部多留一点避免末行贴边。
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // App 名称 + 版本：作为关于我们页的视觉头，比纯文字更聚焦。
            _buildHeader(scheme),
            const SizedBox(height: 18),
            // 引言：开场段落，说明这个 App 是什么、为谁而做。
            Text(
              _intro,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            // 正文章节：顺序即阅读顺序。
            _buildSection(scheme: scheme, title: _whatTitle, body: _whatBody),
            _buildSection(
              scheme: scheme,
              title: _featuresTitle,
              body: _featuresBody,
            ),
            _buildSection(
              scheme: scheme,
              title: _approachTitle,
              body: _approachBody,
            ),
            _buildSection(scheme: scheme, title: _ackTitle, body: _ackBody),
            _buildSection(
              scheme: scheme,
              title: _contactTitle,
              body: _contactBody,
            ),
            // 末章（版权）：不再额外加底部间距，外层 padding 已留 32。
            _buildSection(
              scheme: scheme,
              title: _legalTitle,
              body: _legalBody,
              addBottomSpace: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 页头：App 名称 + 版本号 + 更新时间。
  Widget _buildHeader(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _appName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$_versionLabel $_appVersion · $_updatedLabel $_lastUpdated',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 单个章节：加粗小标题 + 正文段落。
  ///
  /// 参数：
  /// - [scheme] 当前主题配色；
  /// - [title] 章节标题；
  /// - [body] 章节正文；
  /// - [addBottomSpace] 章节下方是否留间距，默认 true；末章传 false 避免尾部过空。
  ///
  /// 正文行高固定 1.6：长文本阅读耐力优先于紧凑排版。
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

  // —— 静态英文正文（按需求以英文撰写，不进 i18n） ——
  /// App 显示名。
  String get _appName => 'Toolbox';

  /// 「版本」标签。
  String get _versionLabel => 'Version';

  /// 「更新于」标签。
  String get _updatedLabel => 'Updated';

  /// 引言段落。
  String get _intro =>
      'Toolbox is a pocket companion for anyone who ties, learns, or relies on '
      'knots — from sailors and climbers to campers, anglers, and everyday makers. '
      'We turn a centuries-old craft into clear, animated, and trustworthy guidance '
      'you can carry in your phone.';

  /// 章节标题：我们做什么。
  String get _whatTitle => 'What We Do';

  /// 章节正文：我们做什么。
  String get _whatBody =>
      'We build step-by-step knot tutorials you can actually follow. Every knot is '
      'reconstructed from its real tying path and animated frame by frame, so the '
      'result looks the way a properly tied knot should — not a simplified cartoon. '
      'Our goal is simple: help you tie the right knot, the right way, the first time.';

  /// 章节标题：核心功能。
  String get _featuresTitle => 'What You Can Do';

  /// 章节正文：核心功能（要点式长段落）。
  String get _featuresBody =>
      '• Learn by animation — browse a growing library of knots, each with a '
      'smooth growth animation and a clear final shape.\n'
      '• Identify knots with your camera — point your phone at a knot and let '
      'on-device recognition suggest what it is.\n'
      '• Carry field tools — a compass, a sound-level meter, and a ruler, ready '
      'when you are out on the water or on the trail.\n'
      '• Go offline — download the knots and materials you need so learning never '
      'stops when the signal does.';

  /// 章节标题：我们的方法。
  String get _approachTitle => 'How We Work';

  /// 章节正文：我们的方法。
  String get _approachBody =>
      'Accuracy comes first. Knot shapes are generated from verified tying paths '
      'rather than freehand drawing, and reference numbers follow the well-known '
      'Ashley Book of Knots (ABoK) system so you can cross-check what you learn. '
      'Content is kept bilingual (English / Chinese) and the interface respects '
      'both light and dark modes.';

  /// 章节标题：致谢。
  String get _ackTitle => 'Acknowledgments';

  /// 章节正文：致谢。
  String get _ackBody =>
      'Knot reference numbers and many traditional names are derived from the '
      'public-domain Ashley Book of Knots. We are also grateful to the open-source '
      'Flutter, Supabase, and Blender communities whose tools make this app possible. '
      'Any errors in interpretation are entirely our own.';

  /// 章节标题：联系我们。
  String get _contactTitle => 'Contact & Feedback';

  /// 章节正文：联系我们。
  String get _contactBody =>
      'We love hearing how you use Toolbox. Found a knot that looks off, want a '
      'specific knot added, or just want to say hello? Email us at '
      'support@toolbox.app and we will get back to you.';

  /// 章节标题：版权与法律。
  String get _legalTitle => 'Version & Legal';

  /// 章节正文：版权与法律。
  String get _legalBody =>
      'Toolbox is provided as-is, without warranty of any kind. Knot-tying can be '
      'safety-critical: always verify a knot against a trusted reference and test '
      'it under load before relying on it. Copyright © 2026 Toolbox. All rights '
      'reserved.';
}
