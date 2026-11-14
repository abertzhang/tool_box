// ============================================================================
// 文件：feature/profile/page/third_party_sdk_page.dart
// 模块：个人中心（profile）/ 第三方 SDK 清单
//
// 职责：
//   展示《第三方 SDK 清单》全文的独立页面，路由 `/profile/third-party-sdk`，
//   由资料页「关于」分组的「第三方 SDK 清单」行 push 进入。
//   每条披露：名称 / 版本 / 提供方 / 用途 / 涉及权限 / 数据收集 / 政策链接，
//   另附「系统平台框架」小节与说明章节，供上架审核与隐私披露使用。
//
// 设计取舍：
//   1. **清单正文不走 i18n**：整篇内容拆成 data/sdk_list_en.dart、
//      data/sdk_list_zh.dart、data/sdk_list_ja.dart 三份数据，
//      页面按当前语言整体取用。
//      原因：合规披露要求「整篇同语言」，中英混排会被认为披露不完整；
//      且条目说明是长句，塞进 arb 会让 key 翻倍、难以通读校对；
//      包名 / 版本 / 厂商 / 链接这些字段本就不需要翻译。
//      —— 页面标题仍走 l10n.thirdPartySdk，因为资料页那一行是双语的。
//   2. **与账号状态解耦**：与隐私政策页一致，不读 Supabase、不判登录态，
//      未登录用户同样可以打开（审核人员通常以未登录态检查）。
//   3. **不引入 url_launcher**：政策链接改为「点击复制到剪贴板」，
//      避免为了展示一个静态清单而新增依赖与额外权限声明。
//
// 关键依赖：
//   - AppLocalizations：仅用于标题（与资料页行文案共用同一个 key）；
//   - localeProvider：决定加载英文 / 中文 / 日文哪一份清单；
//   - go_router：由 route_profile.dart 登记路径。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../../../common/provider/locale/locale_provider.dart';
import '../data/sdk_list_de.dart';
import '../data/sdk_list_en.dart';
import '../data/sdk_list_fr.dart';
import '../data/sdk_list_ja.dart';
import '../data/sdk_list_zh.dart';
import '../model/sdk_list.dart';

/// 第三方 SDK 清单页。
///
/// 有内部状态（「仅看敏感项」过滤开关），故用 [ConsumerStatefulWidget]：
/// 既需要 watch [localeProvider] 决定整篇语言，又需要在切换过滤时保留状态。
class ThirdPartySdkPage extends ConsumerStatefulWidget {
  /// 创建第三方 SDK 清单页。
  const ThirdPartySdkPage({super.key});

  @override
  ConsumerState<ThirdPartySdkPage> createState() => _ThirdPartySdkPageState();
}

class _ThirdPartySdkPageState extends ConsumerState<ThirdPartySdkPage> {
  /// 是否只显示敏感项（涉及系统权限或存在数据外传的条目）。
  ///
  /// 审核与隐私自查时最关心的就是这一类，单独提供过滤可快速定位。
  bool _sensitiveOnly = false;

  @override
  void initState() {
    super.initState();
    // 页面到达埋点：SDK 披露清单的**可触达性**证据（审核关注点）。
    // 放在 initState 而不是入口行点击处：口径与隐私政策 / 关于我们页一致
    // （页面真实创建才计数），且切主题 / 切语言的 rebuild 不会重复上报。
    // ref.read 在 initState 中是允许的（watch 才不行）。
    AppTrack.log(
      TrackEvents.pageDocView,
      params: <String, Object?>{
        'page': 'sdk_list',
        'locale': ref.read(localeProvider),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // 整篇语言：zh 取中文版、ja 取日文版，其余一律回落英文
    // （与 App 支持的语言集合一致，见 AppLocalizations.supportedLocales）。
    final lang = ref.watch(localeProvider);
    final content = switch (lang) {
      'zh' => sdkListZh,
      'ja' => sdkListJa,
      'de' => sdkListDe,
      'fr' => sdkListFr,
      _ => sdkListEn,
    };

    // 过滤后的分组：空组直接剔除，避免出现「只剩标题」的空节。
    final groups = content.groups
        .map(
          (g) => SdkGroup(
            title: g.title,
            entries: _sensitiveOnly
                ? g.entries.where((e) => e.sensitive).toList()
                : g.entries,
          ),
        )
        .where((g) => g.entries.isNotEmpty)
        .toList();
    final platforms = _sensitiveOnly
        ? content.platforms.where((e) => e.sensitive).toList()
        : content.platforms;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(l10n.thirdPartySdk)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 顶部固定区：更新时间 + 引言 + 过滤开关。
          // 放在滚动区之外，滚动浏览长清单时过滤开关始终可点。
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // 前缀按语言取（见 _UpdatedAtPrefix 说明），日期取自数据文件。
                  '${_UpdatedAtPrefix.of(lang)}${content.updatedAt}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Text(
                  content.intro,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // 过滤：全部 / 仅看敏感项。
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _filterChip(
                      scheme: scheme,
                      label: content.filterAll,
                      selected: !_sensitiveOnly,
                      onTap: () => setState(() => _sensitiveOnly = false),
                    ),
                    _filterChip(
                      scheme: scheme,
                      label: content.filterSensitive,
                      selected: _sensitiveOnly,
                      onTap: () => setState(() => _sensitiveOnly = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 正文滚动区。
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                for (final g in groups) ...<Widget>[
                  _groupTitle(scheme, g.title, g.entries.length),
                  for (final e in g.entries) _entryCard(scheme, content, e),
                  const SizedBox(height: 8),
                ],
                if (platforms.isNotEmpty) ...<Widget>[
                  _groupTitle(scheme, content.platformTitle, platforms.length),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
                    child: Text(
                      content.platformNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final e in platforms) _entryCard(scheme, content, e),
                  const SizedBox(height: 8),
                ],
                _noteSection(scheme, content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部过滤胶囊。
  Widget _filterChip({
    required ColorScheme scheme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 分组标题（带该组条目数，便于快速核对总数）。
  Widget _groupTitle(ColorScheme scheme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10, left: 2),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// 单个条目卡片：名称 + 版本 + 四个披露字段 + 政策链接。
  ///
  /// [SdkEntry.sensitive] 为真时左侧加一条主色竖条，
  /// 让「涉及权限 / 有数据外传」的条目在长列表里一眼可辨。
  Widget _entryCard(ColorScheme scheme, SdkListContent c, SdkEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 敏感项左侧竖条；非敏感项用等宽透明占位，保证文本左对齐一致。
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: e.sensitive ? scheme.tertiary : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 名称 + 版本号。
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            e.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.version,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _field(scheme, c.labelVendor, e.vendor),
                    _field(scheme, c.labelPurpose, e.purpose),
                    _field(scheme, c.labelPermissions, e.permissions),
                    _field(scheme, c.labelData, e.data),
                    // 政策链接：点击复制（不引入 url_launcher，见文件头说明）。
                    if (e.privacyUrl != null) ...<Widget>[
                      const SizedBox(height: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _copyLink(
                          e.privacyUrl!,
                          c.copiedToast,
                          _sdkIdOf(e),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.link, size: 14, color: scheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                e.privacyUrl!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.tapCopyHint,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

  /// 单个披露字段：标签（次要色）+ 值（主色）。
  Widget _field(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, height: 1.5, color: scheme.onSurface),
          children: <TextSpan>[
            TextSpan(
              text: '$label：',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  /// 末章「说明」。
  Widget _noteSection(ColorScheme scheme, SdkListContent c) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            c.noteTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.noteBody,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 取条目的稳定埋点标识。
  ///
  /// [SdkEntry.name] 形如「Flutter SDK (flutter, flutter_localizations)」，
  /// 括号里的内容会随集成范围变化，不适合直接当维度；取首个词（包名部分）
  /// 既稳定又短，且**不含任何用户数据**，可安全上报。
  static String _sdkIdOf(SdkEntry e) => e.name.split(RegExp(r'[ (]')).first;

  /// 复制链接到剪贴板并提示。
  ///
  /// 先捕获 messenger：[Clipboard.setData] 是异步的，
  /// 跨 await 后再用 context 会触发 use_build_context_synchronously。
  ///
  /// - [sdkId]：被查看的 SDK 标识，用于埋点（哪些第三方被用户重点查看）。
  Future<void> _copyLink(String url, String toast, String sdkId) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    // 复制链接埋点：被重点查看的第三方，用于优化披露文案的详略
    // （没人看的条目可以写简略些，常看的写详细）。
    AppTrack.log(
      TrackEvents.sdkLinkCopied,
      params: <String, Object?>{'sdk_id': sdkId},
    );
    messenger.showSnackBar(
      SnackBar(content: Text(toast), duration: const Duration(seconds: 1)),
    );
  }
}

/// 「最后更新时间」前缀。
///
/// 这个前缀很短且只在标题行出现，若塞进数据文件会与正文混在一起，
/// 因此单独放在这里按语言取，保持数据文件只承载「整篇正文」。
class _UpdatedAtPrefix {
  const _UpdatedAtPrefix._();

  /// 按语言代码返回前缀。
  static String of(String lang) => switch (lang) {
    'zh' => '最后更新时间：',
    'ja' => '最終更新日: ',
    'de' => 'Zuletzt aktualisiert: ',
    'fr' => 'Dernière mise à jour : ',
    _ => 'Last updated: ',
  };
}
