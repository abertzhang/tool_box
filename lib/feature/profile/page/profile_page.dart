// ============================================================================
// 文件：feature/profile/page/profile_page.dart
// 模块：我的 / 个人中心（profile）
//
// 职责：
//   底部导航第 4 个 Tab「我的」的页面。整页按 Pixso 设计稿（深色节点 80:93）
//   实现，包含「个人资料区 / 会员卡 / 设置分组 / 关于分组」四块，
//   并基于全局主题（themeProvider）同时适配浅色与深色两套配色。
//
// 关键依赖：
//   - flutter_riverpod：ConsumerWidget，watch 主题与语言 Provider，
//     使「深色模式」开关与「语言设置」与全局状态联动。
//   - ThemeMode / localeProvider：深色开关直接 toggleLightDark()，
//     语言行直接 setLanguage() 在 zh / en 间切换。
//   - supabase_flutter + user_profile_provider：资料区接真实用户态——
//     读 `public.user_profiles` 视图展示头像 / 邮箱 / 会员状态；
//     未登录 / 未配置 Supabase 时自动回落到占位态，不会白屏。
//
// 设计还原要点（来自 Pixso 节点 80:93）：
//   背景 #1A1A1E，卡片 #2C2C2E，标题白 #FFF，次要文字灰 #A0A0A5，
//   金色强调 #E5C158；顶部分享式渐变棕 #4A3520 → 深 #1A1A1E。
//
// 备注：本页作为 MainTabPage 的 body 嵌入，不自带 AppBar；
//       无真实后端的行（清除缓存 / 评分 / 协议等）点击给出「功能开发中」提示，
//       仅主题与语言两行是真实可用的。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tool_box/common/ads/banner_ad_view.dart';
import 'package:tool_box/common/ads/consent_helper.dart';
import 'package:tool_box/common/ads/watch_ad_dialog.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/auth/member_bind_service.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../../../common/provider/app_settings/app_stats_provider.dart';
import '../../../common/provider/app_settings/free_usage_provider.dart';
import '../../../common/provider/app_settings/save_name_prompt_provider.dart';
import '../../../common/provider/locale/locale_provider.dart';
// app_palette：语义色板，本页通用色统一从它取，以跟随主题色方案切换。
import '../../../common/provider/theme/app_palette.dart';
import '../../../common/provider/theme/app_theme.dart';
import '../../../common/provider/theme/sky_theme.dart';
import '../../../common/provider/theme/theme_color_provider.dart';
import '../../../common/provider/theme/theme_notifier.dart';
import '../../../common/util/cache_util.dart';
import '../model/user_profile.dart';
import '../provider/membership_provider.dart';
import '../provider/user_profile_provider.dart';
import '../routes/route_profile.dart';
import '../util/app_review.dart';
import '../util/app_update.dart';
import '../util/avatar_catalog.dart';
import '../util/local_avatar.dart';

/// 「隐私政策」在线地址（供应用商店商品详情填写；App 内仍走本地页）。
///
/// 2026-09-17 更新：在线隐私政策现托管于 GitHub Pages，实测可达
/// （HTTP 200 / text/html / 0 次跳转）。旧的 aknot.uk 至今**无 A 记录**、
/// 全球 DNS 解析失败，已从本项目全部在线地址中弃用。
///
/// ⚠️ **该站点是静态页，`?type=` 查询参数不生效**：实测 type=1 / 2 / 3 与不带
/// 参数返回的都是同一份《Privacy Policy》（title 恒为 "Privacy Policy"）。
/// 因此这里不再带 ?type=1，避免造成「参数可切换文档类型」的误解。
///
/// ⚠️ 线上**只有隐私政策，没有用户协议**：旧注释称「type=1 = 用户协议」已不符合
/// 实际。App 内「用户协议」继续走本地页 [ProfileRoute.userAgreement]；两者并存——
/// 在线版满足商店合规要求，本地版保证任何时刻都可读、不依赖网络。
///
/// 保留为顶层常量集中一处，便于商店后台填写或将来换域名时不必满仓库找地址。
/// ignore 说明：本常量当前无引用（App 内入口走本地页），但刻意保留 ——
/// 填写商店「隐私政策网址」栏时可直接取这里的值。
/// ignore: unused_element
const String _privacyPolicyUrl =
    'https://aberciozhang.github.io/privacy/tool-box';

/// 个人中心配色板。
///
/// 集中管理 ProfilePage 需要的全部颜色。
///
/// 通用语义色（页面底 / 卡片 / 文字 / 分隔线 / 金色）统一取自 [AppPalette]，
/// 使其跟随「主题色方案（咖啡色 / 蓝色）× 明暗模式」两个维度变化；
/// 会员卡金渐变、头像渐变、宫格图标色等**品牌固定色**仍按 [isDark] 取原值，
/// 不随色卡变化（它们是品牌资产，不是主题语义色）。
/// 把全 App 工具使用总量压缩成社交数字缩写，避免 6 位以上的长数字撑爆统计卡：
/// - 不足 6 位：原样（如 99999）；
/// - 6 位及以上（含）：以 K（千）计，150000 → 150K；
/// - 9 位及以上（含）：以 M（百万）计，150000000 → 150M；
/// - 12 位及以上（含）：以 B（十亿）计，150000000000 → 150B。
/// 保留 1 位小数，去掉多余的 .0（150.0 → 150，123.5 → 123.5）。
String _formatAppTotalCompact(int value) {
  if (value < 100000) return value.toString(); // 5 位及以下原样显示
  if (value < 100000000) {
    // 6~8 位 → K（千）
    return '${_trimTailZero(value / 1000.0)}K';
  }
  if (value < 100000000000) {
    // 9~11 位 → M（百万）
    return '${_trimTailZero(value / 1000000.0)}M';
  }
  // 12 位及以上 → B（十亿）
  return '${_trimTailZero(value / 1000000000.0)}B';
}

/// 保留 1 位小数并去掉尾随的 .0，用于紧凑数字缩写显示。
String _trimTailZero(double v) {
  final String s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

class _ProfilePalette {
  /// 创建配色板。
  ///
  /// 参数：
  /// - [isDark] 是否深色模式，由 [ThemeMode] 推导后传入，仅品牌固定色使用；
  /// - [app] 当前语义色板（已含色卡与明暗），通用色一律从它取。
  const _ProfilePalette({required this.isDark, required this.app});

  /// 是否深色模式，仅用于取品牌固定色的深浅分支。
  final bool isDark;

  /// 当前语义色板，随主题色方案与明暗模式变化。
  final AppPalette app;

  // —— 页面与卡片（跟随主题色方案）——
  /// 页面背景：取自语义色板，切到蓝色主题后随之变为浅蓝 / 深蓝。
  Color get pageBg => app.pageBg;

  /// 顶部分享式渐变起止色，营造资料区纵深；取自语义色板。
  List<Color> get headerGrad => app.headerGrad;

  /// 通用卡片（会员卡除外）背景。
  Color get cardBg => app.cardBg;

  /// 标题 / 主文字色。
  Color get titleText => app.titleText;

  /// 次要文字 / 数值说明色。
  Color get subText => app.labelText;

  /// 行内主文字（设置/关于行左侧标题）。随 titleText。
  Color get rowText => titleText;

  /// 行内右侧辅助值（如「23.5 MB」「v2.1.0」）。随 subText。
  Color get rowValue => subText;

  /// 分隔线色。
  Color get divider => app.divider;

  // —— 金色品牌强调 ——
  /// 金色强调（徽章 / 高亮文字）。会员金是品牌固定色，两套主题共用同一组值。
  Color get gold => app.gold;

  // —— 以下为品牌固定色：不随主题色方案变化，仅按 [isDark] 取深浅 ——
  // 会员金渐变属于品牌资产（金色 = 会员等级的象征），
  // 换成蓝色系会削弱其语义，故两套主题共用。

  /// 会员卡渐变起止色。深色亮金；浅色柔和金。
  List<Color> get vipGrad => isDark
      ? const [Color(0xFFF4D98B), Color(0xFFE5C158)]
      : const [Color(0xFFF0D58A), Color(0xFFE0B94E)];

  /// 会员卡金边色。深色 #E5C158；浅色 #E0B94E。
  Color get goldBorder =>
      isDark ? const Color(0xFFE5C158) : const Color(0xFFE0B94E);

  /// 开关激活色（thumb / track）：随主题色方案变化（咖啡主题=棕、晴空蓝=蓝），
  /// 不再固定用会员金，避免切到蓝色主题后开关仍是咖啡/金色、造成视觉割裂。
  Color get switchActive => app.accent;

  /// 头像渐变（无真人图时用渐变 + 人形图标占位）。
  List<Color> get avatarGrad => isDark
      ? const [Color(0xFF6B5C44), Color(0xFF3A2E1F)]
      : const [Color(0xFF8C7A63), Color(0xFF6B5C44)];

  /// 头像白色描边。
  Color get avatarRing => const Color(0xFFFFFFFF);
}

/// 个人中心页（完整实现）。
///
/// 采用 [ConsumerWidget]：watch [themeProvider] 与 [localeProvider]，
/// 让深色开关与语言行与全局状态联动；其余无后端的行点击仅给出占位提示。
// —— 检查更新相关英文 UI 文案 ——
// 说明：本模块其余 UI 走 i18n，但检查更新对话框/提示按需求以英文撰写
// （与 About Us 页面一致），避免触碰本机已损坏的 flutter gen-l10n 生成链。
// 后续若要中英双语，把下列常量迁到 app_en.arb / app_zh.arb 即可。
const String _kUpdateTitle = 'Update available';
const String _kUpdateBodyPrefix = 'A new version';
const String _kUpdateNow = 'Update';
const String _kUpdateLater = 'Later';
const String _kUpToDatePrefix = "You're up to date";

class ProfilePage extends ConsumerWidget {
  /// 创建个人中心页。
  ///
  /// 无业务参数：页面数据后续可统一由 Riverpod Provider 提供，
  /// 不通过构造函数从 [MainTabPage] 逐层透传。
  const ProfilePage({super.key});

  /// 会员卡「立即开通」按钮的右侧/顶部定位偏移（逻辑像素）。
  ///
  /// 卡片内容用 [Stack] 承载，按钮以 [Positioned] 自由定位；
  /// 改这两个值即可把按钮挪到卡片内任意位置（默认吸附右上角）。
  static const double _upgradeBtnRight = 0;
  // 按钮相对会员条右上角的纵向偏移：正值往下挪，0 即吸附顶部。
  static const double _upgradeBtnTop = 12;

  /// 文案区为右上角按钮预留的宽度（逻辑像素）。
  ///
  /// 按钮是 [Positioned] 脱离流布局、不占空间，若文案不预留就会被按钮盖住。
  /// 取值需 ≥ 按钮实际宽度（左右 padding 16×2 + 「Upgrade Now」文字约 90px ≈ 122px），
  /// 故留到 130px 兼容中英文；若调整按钮 padding 或字号需同步复核该值。
  static const double _upgradeBtnReserve = 130;

  /// 由 [ThemeMode] 推导当前是否处于深色。
  ///
  /// 仅 [ThemeMode.dark] 视为深色；[ThemeMode.system] 时按平台亮度判断，
  /// 保证开关状态与系统设置一致。
  bool _isDark(ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return false;
  }

  /// 语言代码 → 本地化展示名。
  ///
  /// 注意：这里显示的是 App **当前语言**下的语种名（英文界面里就是 English /
  /// Simplified Chinese / Japanese），而不是各语言的自称；`default` 分支回落英文，
  /// 新增语种时记得同步下面的 [supported] 列表。
  String _languageName(String code, AppLocalizations l10n) => switch (code) {
    'zh' => l10n.langChinese,
    'ja' => l10n.langJapanese,
    'de' => l10n.langGerman,
    'fr' => l10n.langFrench,
    _ => l10n.langEnglish,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题模式（异步加载，未就绪时回落 system）。
    final themeMode = ref.watch(themeProvider).value ?? ThemeMode.system;
    final isDark = _isDark(themeMode);
    // 当前语言代码。
    final lang = ref.watch(localeProvider);
    // 传当前语义色板：使本页通用色跟随「主题色方案 + 明暗」两个维度，
    // 切到蓝色主题后整页（背景 / 卡片 / 文字 / 分隔线）随之变蓝。
    final palette = _ProfilePalette(
      isDark: isDark,
      app: AppPalette.of(context),
    );
    // 会员资料：只取成功分支的值，loading / error 的具体表现交给资料区内部处理，
    // 会员卡拿到 null 就按「未开通」渲染（加载完成后会自动刷新）。
    // 用 .value 而非 .valueOrNull：本工程 riverpod 版本的 AsyncValue 尚无后者。
    final profile = ref.watch(userProfileProvider).value;
    // 页面级 l10n 文案（广告「Ad / 广告」小标等处使用）。
    final l10n = AppLocalizations.of(context)!;
    // 会员状态：**会员免广告**的判定来源。
    //
    // 为什么必须在这里 watch 而不是让 AdBannerSlot 自己读：
    // 会员购买成功后，本页需要「立刻把广告从树上摘掉」—— 只隐藏还不够，
    // 摘掉才会触发 AdBannerSlot.dispose() 释放原生广告实例。
    // 由页面统一持有这个状态，广告组件就能保持通用（不感知会员体系）。
    // 本页已在 ref.listen 里订阅过 isMemberProvider（会员生效 toast），
    // 再 watch 一次不会产生额外开销（同一 provider 的订阅是共享的）。
    final bool isMember = ref.watch(isMemberProvider);

    // 本机商店权益从未持有 → 持有 的瞬间弹一次「会员已生效」。
    // 购买成功与恢复购买命中都会触发，作为异步支付结果的全局可见反馈
    //（支付页拉起后用户可能停在别的页面，仅靠会员卡重渲染不够醒目）。
    ref.listen<bool>(isMemberProvider, (prev, next) {
      if (prev == false && next == true) {
        _toast(context, AppLocalizations.of(context)!.vipBecomeMember);
      }
    });

    return Scaffold(
      // 背景跟随全局主题，浅/深切换时自动变化而非写死颜色。
      backgroundColor: palette.pageBg,
      // top:false 让顶部渐变延伸到状态栏之下，形成资料区沉浸式头部。
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) 个人资料区（渐变头部）：头像 / 昵称 / 邮箱 / 会员徽章 / ID。
              _buildHeader(context, ref, palette),
              const SizedBox(height: 12),
              // 2) 会员卡：会员生效时改为展示到期时间，隐藏「立即开通」。
              _buildVipCard(context, ref, palette, profile),
              const SizedBox(height: 24),
              // 3) 设置分组。
              _buildSettingsGroup(context, ref, palette, lang, isDark),
              // 横幅广告：位于「关于」分组之上、设置分组之下。
              //
              // 位置理由：Profile 页底部（关于分组之后）就是页面终点，
              // 广告放在 About 上方首屏滚动 1~2 屏即达，曝光远高于页尾；
              // 又不至于打断顶部（资料 / 会员卡 / 数据宫格）的核心区。
              //
              // 为什么不用「钉在底部导航栏上方」：
              //   1) 广告紧贴底部 Tab（高频点击区）容易误触，是 AdMob 明确的违规风险点；
              //   2) 不改动 Tab 壳层结构，Tab 切换时不会重建广告（省一次请求）。
              //
              // 会员（已买断）时整块不放进 widget 树 —— 既不请求也不展示，
              // 且移除动作会触发 AdBannerSlot.dispose()，立即释放原生广告对象。
              // 本页 Column 是 crossAxisAlignment.stretch，广告会自动铺满全宽，
              // 故用 Padding(16) 与上下的分组卡片横向对齐（分组内部 padding 同值）。
              if (!isMember) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // ⚠️ 必须显式传 slot：AdBannerSlot 的默认值是 tools 页的
                  // `tool_compass_after`，漏传会让本页广告在埋点里被记成
                  // tools 页那条，两个位置的曝光数据混在一起、无法分开统计。
                  child: AdBannerSlot(
                    labelText: l10n.adLabel,
                    slot: 'profile_about_top',
                    position: BannerPosition.profile,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // 5) 关于分组。
              //
              // 外面包一层 FutureBuilder：是否展示「广告隐私设置」行取决于 UMP 的
              // 平台判定（要读一次平台通道，因此是异步的）。
              // future 取自 [AdsConsent.privacyOptionsRequired]（内部已缓存同一实例），
              // 页面重建不会重复发起通道调用。
              FutureBuilder<bool>(
                future: AdsConsent.privacyOptionsRequired(),
                builder: (BuildContext _, AsyncSnapshot<bool> snap) {
                  // 未拿到结果时按「不展示」渲染，避免分组在加载瞬间抖动；
                  // 查询通常在一帧内完成，用户几乎感知不到。
                  return _buildAboutGroup(
                    context,
                    ref,
                    palette,
                    showAdPrivacy: snap.data ?? false,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // —— 1. 个人资料区 ——
  /// 构建顶部渐变资料区：头像 + 昵称 + 会员徽章 + 邮箱 + ID + 学习统计条。
  ///
  /// 三种展示态（按优先级判定）：
  /// 1. **未配置 Supabase** → 展示「未登录」占位，点按提示账号服务未初始化。
  ///    此时跳登录页也没用（登录页同样依赖 Supabase），直接给可操作提示更清楚；
  /// 2. **已登录** → 头像取 `avatar_url`（无则渐变占位），昵称取
  ///    `display_name` → 邮箱前缀 → 兜底文案，下方展示真实邮箱与用户 ID；
  ///    此时整块资料区不响应点击，但**头像单独可点** → 进编辑资料页改昵称 / 换头像；
  /// 3. **未登录** → 渐变占位头像 + 「点击登录 / 注册」引导，点按跳 `/login`。
  ///
  /// 资料读取失败时（[userProfileProvider] 抛错）在昵称下方补一行「重试」，
  /// 不让整块区域变成空白。
  Widget _buildHeader(BuildContext context, WidgetRef ref, _ProfilePalette p) {
    final l10n = AppLocalizations.of(context)!;
    // 顶部留出状态栏高度，避免内容被刘海/状态栏遮挡。
    final topPad = MediaQuery.of(context).padding.top;
    // Supabase 是否可用（未配置 key 时为 false，main.dart 会跳过初始化）。
    final ready = ref.watch(supabaseReadyProvider);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    // 只有「Supabase 已初始化 且 已拿到用户」才算登录。
    final loggedIn = ready && user != null;

    // 免费剩余次数（替换原「学习天数」统计项）：剩余 = 基础额度 + 广告奖励 - 已用，
    // 与会员卡「免费 N 次」徽标口径一致（每次用工具 -1、看完激励广告 +5、随登录态变基础额度）。
    // 会员（已开通）无限，徽标显示 ∞；未开通显示真实剩余可用次数。
    final int freeRemaining =
        ref.watch(freeUsageProvider).value?.remaining ??
        FreeUsageController.maxFreeGuest;
    // 当前用户累计使用工具的次数（替换原「学会绳结」统计项）：
    // 直接取自 freeUsageProvider 的 count 字段——游客取本机/匿名设备表计数，
    // 已登录用户与 public.users.tool_usage_count 取 max 合并，口径与云端一致。
    // 该计数是「累计已用次数」，与是否会员无关（会员也会累计，仅不限额）。
    final int toolsUsed = ref.watch(freeUsageProvider).value?.count ?? 0;
    // 全 App 工具使用总量（第 3 栏）：所有用户 + 游客设备的累计之和，必须服务端聚合，
    // 见 app_stats_provider.dart。未部署 RPC / 加载中先显示 0，拿到真值后自动刷新。
    final int appTotal = ref.watch(appToolUsageTotalProvider).value ?? 0;
    final String appTotalText = _formatAppTotalCompact(appTotal);
    final bool isMember = ref.watch(isMemberProvider);

    // 资料区整块的点击行为：未配置 → 提示；未登录 → 跳登录页；已登录 → 不响应。
    // 已登录时改由头像自身响应点击（跳编辑资料页），见 _buildAvatarEntry。
    VoidCallback? onTap;
    if (!ready) {
      onTap = () => _toast(context, l10n.errSupabaseNotReady);
    } else if (user == null) {
      onTap = () => context.push('/login');
    }

    // 昵称三级回落：视图昵称 → 邮箱前缀 → 未登录引导文案。
    // 视图还没补行时（触发器延迟）profile 为 null，用 Auth 邮箱兜底，不留空白。
    final name =
        profile?.bestDisplayName ??
        _nameFromEmail(user?.email) ??
        (loggedIn ? l10n.profileGuest : l10n.profileNotLogin);

    // 兜底本地头像用的显示名：视图昵称 → 邮箱前缀。
    //
    // 与上面的 [name] 分开算：[name] 未登录时会回落成「未登录 / 点击登录」这类
    // 引导文案，拿它去做头像首字符会显示成一个「未」字，很怪。
    // 这里未登录时为 null，本地头像会自动退化成人形图标。
    final avatarLabel = profile?.bestDisplayName ?? _nameFromEmail(user?.email);

    // 第二行：已登录显示邮箱，未登录显示登录引导。
    final email = user?.email ?? profile?.email;
    final subtitle = loggedIn
        ? (email ?? l10n.profileNoEmail)
        : l10n.profileTapLogin;

    return Container(
      // 渐变由棕过渡到页面背景，与列表背景自然衔接。
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.headerGrad,
        ),
      ),
      padding: EdgeInsets.only(
        top: topPad + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 昵称/会员徽章 同一行；整块可点（仅未登录或未配置时）。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                // 头像：有 avatar_url 走网络图，否则（或加载失败时）回落本地头像。
                // 已登录时整块可点 → 进入编辑资料页（改昵称 / 换头像）。
                _buildAvatarEntry(
                  context,
                  p,
                  profile?.avatarUrl,
                  loggedIn,
                  avatarLabel,
                ),
                const SizedBox(width: 14),
                // 昵称与会员徽章。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: p.titleText,
                              ),
                              // 昵称可能很长（邮箱前缀），超长省略避免挤压徽章。
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 会员徽章：仅在「已登录且资料加载成功」时显示，
                          // 加载中/失败时不显示，避免闪一下错误状态。
                          if (loggedIn && profile != null) ...[
                            const SizedBox(width: 8),
                            _buildMemberBadge(
                              context,
                              p,
                              active: profile.isMemberActive,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 邮箱（登录态）或登录引导（未登录态）。
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: p.subText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 用户 ID：展示 uuid 前 8 位，完整 uuid 太长影响排版。
                      if (loggedIn) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_shortId(user.id)}',
                          style: TextStyle(fontSize: 12, color: p.subText),
                        ),
                      ],
                      // 资料读取失败：给一个就地重试入口，而不是整块空白。
                      if (profileAsync.hasError) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => refreshUserProfile(ref),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 13,
                                color: _errorColor(p),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${l10n.profileLoadFailed} · ${l10n.profileRetry}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _errorColor(p),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 未登录时右侧补一个箭头，暗示这一块可点。
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 20, color: p.subText),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 学习统计条：半透明卡片承托三列数据，竖线分隔。
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              // 深色半透明白、浅色半透明黑，保证在渐变上可读。
              color: p.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _statItem(
                  label: l10n.statFreeRemaining,
                  value: isMember ? '∞' : freeRemaining.toString(),
                  p: p,
                  // 点击弹出「观看一次获得 5 次免费使用」确认框，确认即关闭弹框并播放
                  // 激励广告，看完自动到账（弹框与发奖流程见 watch_ad_dialog.dart）。
                  // 会员已无限（显示 ∞），再弹「换次数」没有意义，故保持纯展示。
                  onTap: isMember
                      ? null
                      : () => showWatchAdForFreeUsesDialog(
                          context,
                          ref,
                          slot: 'profile_free_left',
                        ),
                ),
                _verticalDivider(p),
                _statItem(
                  label: l10n.statToolsUsed,
                  value: toolsUsed.toString(),
                  p: p,
                ),
                _verticalDivider(p),
                _statItem(
                  label: l10n.statAppToolUsage,
                  value: appTotalText,
                  p: p,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 资料区头像（含「点击进入编辑」的入口行为）。
  ///
  /// 为什么只在登录态可点：编辑页要写 `public.users`，
  /// 未登录时写不进去，跳过去只会看到一个提示，不如直接引导登录。
  /// 未登录态头像保持纯展示，点击落到外层整块的「去登录」手势上。
  ///
  /// 右下角叠一支铅笔徽标，明确告诉用户「头像可编辑」——
  /// 没有视觉提示的话，很少有人会去点自己的头像。
  Widget _buildAvatarEntry(
    BuildContext context,
    _ProfilePalette p,
    String? avatarUrl,
    bool loggedIn,
    String? displayName,
  ) {
    final avatar = _buildAvatar(p, avatarUrl, displayName);
    if (!loggedIn) return avatar;
    return GestureDetector(
      // 挂 Key 是为了集成测试能稳定命中（不依赖 i18n 文案、不依赖图标），
      // 见 integration_test/app_test.dart 的「编辑资料」阶段。
      key: const Key('profile-avatar-edit'),
      behavior: HitTestBehavior.opaque,
      // 保存成功后编辑页会 pop 回来，并 invalidate 资料 Provider，
      // 这里的昵称与头像由 watch 自动刷新，无需额外回调传值。
      onTap: () => context.push('/profile/edit'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.gold,
                // 与头像白描边同色的外圈，避免徽标和头像糊在一起。
                border: Border.all(color: p.avatarRing, width: 2),
              ),
              child: const Icon(Icons.edit, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 头像：有 [avatarUrl] 时加载网络图，否则（或加载失败时）回落本地生成头像。
  ///
  /// 为什么必须写 errorBuilder：Google 头像 URL 可能失效或断网，
  /// 默认行为是抛异常并渲染破图占位，视觉上是「头像裂了」。
  /// 2026-09-04 起内置图床还多一层风险：Cloudflare 对非浏览器客户端返回 403
  /// 挑战页（HTML 而不是图片），解码必然失败 —— 没有兜底的话头像会直接裂开。
  ///
  /// [displayName] 供本地头像取首字符（取首个 Unicode 码点转大写）。
  Widget _buildAvatar(
    _ProfilePalette p,
    String? avatarUrl,
    String? displayName,
  ) {
    // ★ 兜底配色种子必须与编辑资料页保持一致（见 edit_profile_page.dart）：
    //   有头像 URL 时用 URL、没有时用显示名。用 URL 作种子意味着
    //   「同一张头像在资料页与编辑页是同一个颜色」，来回切页不会跳色。
    final String? seed = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : displayName;

    // 本地兜底头像：由 seed 稳定生成的彩色渐变圆形 + 首字符。
    // 尺寸 60 = 外层 64 减去两侧各 2px 的描边，避免内容压到外圈上。
    final Widget placeholder = LocalAvatar(
      seed: seed,
      label: displayName,
      size: 60,
    );

    // 完全没有头像：外面套白描边圆环，与「有头像」时的外框保持一致。
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.avatarRing, width: 2),
        ),
        child: Center(child: placeholder),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.avatarRing, width: 2),
        // 图片下载完成前先垫一层渐变底色，避免出现白色闪块。
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.avatarGrad,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          // 内置头像图床走 Cloudflare，默认 Dart UA 可能被拦成 403，
          // 统一带上类浏览器请求头（对 Google 头像等外链也无害）。
          headers: avatarImageHeaders,
          // 三个形参都不使用，统一用通配符 _（Dart 3 起可重复）。
          // ★ 兜底用 LocalAvatar 而不是人形图标：图床被 Cloudflare 挑战
          //   拦截时，用户看到的是带自己首字符的彩色头像，
          //   而不是「头像加载失败」的破图感。
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }

  /// 会员徽章。
  ///
  /// [active] 为真 → 金色实心「VIP」药丸；否则 → 描边「免费用户」药丸。
  /// 会员状态直接读视图算好的 `is_member_active`，App 端不重复判断过期。
  Widget _buildMemberBadge(
    BuildContext context,
    _ProfilePalette p, {
    required bool active,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? p.gold : Colors.transparent,
        // 非会员用描边药丸，与金色实心形成主次区分。
        border: active
            ? null
            : Border.all(color: p.subText.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        active ? l10n.profileMemberVip : l10n.profileMemberFree,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : p.subText,
        ),
      ),
    );
  }

  /// 从邮箱提取前缀作为昵称兜底；邮箱为空或格式不合法时返回 null。
  String? _nameFromEmail(String? email) {
    final mail = email?.trim();
    if (mail == null || !mail.contains('@')) return null;
    final prefix = mail.split('@').first;
    return prefix.isEmpty ? null : prefix;
  }

  /// 把 uuid 缩成「前 8 位 + 省略号」，避免完整 uuid 撑破昵称区布局。
  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

  /// 错误提示色：深色用浅红、浅色用深红，保证在渐变头部上都清晰可读。
  Color _errorColor(_ProfilePalette p) =>
      p.isDark ? const Color(0xFFFF9B9B) : const Color(0xFFB3261E);

  /// 统计条中的单列（标签在上、数值在下）。
  Widget _statItem({
    required String label,
    required String value,
    required _ProfilePalette p,
    VoidCallback? onTap,
  }) {
    return Expanded(
      // 用手势层包装整列。behavior 按有无回调切换，避免影响纯展示的两栏：
      //  - 有 onTap → opaque：数字与标签之间的空隙也能命中，不留盲区；
      //  - 无 onTap → deferToChild：等同没有这层包装，点击照常穿透，
      //    （若一律用 opaque，即便没回调也会吞掉命中事件）。
      child: GestureDetector(
        behavior: onTap == null
            ? HitTestBehavior.deferToChild
            : HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: p.titleText,
              ),
            ),
            const SizedBox(height: 4),
            // 可点栏位（目前只有 Free Left）在标签右侧补一个「+」小图标：
            // 统计栏本质是只读数字，没有任何可点暗示的话，用户不会知道这里能
            // 领免费次数。图标取 subText 同色、11px，不抢视觉也不撑高布局。
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: TextStyle(fontSize: 12, color: p.subText)),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: 2),
                  Icon(Icons.add_circle_outline, size: 11, color: p.subText),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 统计条内的 1px 竖向分隔线。
  Widget _verticalDivider(_ProfilePalette p) {
    return Container(
      width: 1,
      height: 28,
      color: p.isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1),
    );
  }

  // —— 2. 会员卡 ——
  /// 构建金色会员卡：标题 + 描述 + 「立即开通」按钮，金边金渐变。
  ///
  /// 会员已生效时（[profile.isMemberActive]）改为展示「生效中 + 到期时间」，
  /// 并隐藏开通按钮 —— 不是换个文案，而是避免已付费用户再看到一个购买入口。
  /// 会员状态取自视图的 `is_member_active`（已含过期判断），App 端不重复计算。
  Widget _buildVipCard(
    BuildContext context,
    WidgetRef ref,
    _ProfilePalette p,
    UserProfile? profile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // 会员是否生效：云端登录会员 || 本机商店买断权益（未登录购买同样点亮）。
    // 判定收敛在 isMemberProvider 里合并两个来源，页面不关心权益来自哪边。
    // 资料 / 商店查询未完成时按未开通渲染，完成后 watch 自动刷新。
    final active = ref.watch(isMemberProvider);
    // 免费剩余次数：剩余 = 基础额度 + 广告奖励 - 已用。订阅 freeUsageProvider，
    // 与 tools 页会员条逻辑一致——每次工具使用（increment 使 count +1）后此处自动 -1，
    // 看完激励广告（bonus +5）后自动 +5；基础额度随登录态变化（未登录 5 / 已登录 10）。
    // 真实反映跨设备 / 重装登录后从云端合并回来的剩余可用次数。会员（active）无限，徽标不显示。
    final int remaining =
        ref.watch(freeUsageProvider).value?.remaining ??
        FreeUsageController.maxFreeGuest;
    // —— 方案 B：同步入口显示条件 ——
    // 已登录 && 本机有买断权益 && 云端还没生效（is_member_active=false）时，
    // 在会员卡下方亮出「同步会员到账号」入口，把本机权益写云端，
    // 换设备 / 重装后凭账号即可恢复。云端已生效或未购买 / 未登录都不显示。
    final user = ref.watch(currentUserProvider);
    final ownedLocal = ref.watch(membershipProvider).owned;
    final cloudActive = profile?.isMemberActive ?? false;
    final shouldShowSync = user != null && ownedLocal && !cloudActive;
    return Padding(
      padding: .symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: .symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: p.vipGrad,
              ),
              // 金边：1pt 实线，与卡片同色系呼应。
              border: Border.all(color: p.goldBorder, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            // 卡片内容用 Stack 承载（2026-09-15 改）：
            //   1) 文案区（图标 + 标题/徽标 + 描述）是**普通 child**，负责撑起卡片高度；
            //   2) 「立即开通」按钮改用 [Positioned] **脱离流布局**，可自由定位到卡片内
            //      任意位置（默认 right:0 / top:0 吸附右上角；改 _upgradeBtnRight /
            //      _upgradeBtnTop 两个常量即可整体挪位，不再受文案行数与间距牵连）。
            //   ⚠️ 因为 Positioned 不占布局空间，文案区必须按 _upgradeBtnReserve
            //      预留右侧宽度，否则按钮会盖住标题与「Free N uses left」徽标
            //      （此前 Row/Column 线性布局下按钮被挤到徽标上的问题即源于此）。
            child: Stack(
              children: [
                Row(
                  // 顶部对齐：解锁图标与标题首行基线大致齐平，避免图标被挤到卡片中部。
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 已生效时左侧显示「解锁」图标（开放锁），直观表达「会员权益已解锁」；
                    // 未生效时不渲染，此时开通按钮浮在右上角（见下方 `if (!active)`）。
                    if (active)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Icon(
                          Icons.lock_open,
                          size: 22,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    // 左侧文案：深色字（金底上白字反而不够清晰）。
                    Expanded(
                      child: Padding(
                        // 未生效时右侧让出按钮占位（按钮为 Positioned，不占空间）：
                        // 避免标题/徽标/描述被右上角按钮覆盖。
                        padding: EdgeInsets.only(
                          right: active ? 0 : _upgradeBtnReserve,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题行：会员标题（生效→vipActiveTitle / 未购→vipTitle「Pro Unlock」）
                            // + 「免费 N 次」剩余次数徽标（仅未购买态显示，与 tools 页会员条逻辑一致）。
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 标题用 Flexible：窄屏 / 长语言文案下让标题先省略，
                                // 保证徽标完整显示，整行不会 RenderFlex overflow。
                                Flexible(
                                  child: Text(
                                    active
                                        ? l10n.vipActiveTitle
                                        : l10n.vipTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3A2E1F),
                                    ),
                                  ),
                                ),
                                // 仅未购买（Pro Unlock）态显示剩余次数：会员已无限，无需展示。
                                // 徽标在金底卡片上用半透明深色胶囊，文字取副标题同色（深棕），保证可读。
                                if (!active) ...[
                                  const SizedBox(width: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      l10n.freeRemainingCount(remaining),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF5A4A33),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              // 生效中 → 到期时间（未设到期则显示「永久会员」）；
                              // 未生效 → 原来的卖点文案。
                              active
                                  ? _memberExpireText(context, profile)
                                  : l10n.vipDesc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5A4A33),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // 已生效时不再展示开通入口；未生效（或未登录）才浮出按钮。
                // 开通按钮：深棕底 + 白字，点击拉起买断支付。
                // ★ 不要求登录 App 账号：IAP 权益绑定系统账号
                //  （Apple ID / Google 账号），未登录也能直接购买。
                if (!active)
                  Positioned(
                    right: _upgradeBtnRight,
                    top: _upgradeBtnTop,
                    child: GestureDetector(
                      onTap: () => _onUpgrade(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A2E1F),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          l10n.vipOpen,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // —— 同步入口（方案 B）：条件显示，见方法开头 shouldShowSync ——
          // 放在会员卡**外部**、Column 里作为兄弟节点：卡片自身是渐变 Container，
          // 把入口塞进它的 child 会破坏 Container 的单子布局。
          if (shouldShowSync) ...[
            const SizedBox(height: 10),
            _buildSyncEntry(context, ref, p),
          ],
        ],
      ),
    );
  }

  /// 会员到期文案：未设到期时间显示「永久会员」，否则显示「有效期至 yyyy-MM-dd」。
  ///
  /// 收可空 [UserProfile]：会员可能来自**本机商店权益**（未登录买断），
  /// 此时没有云端资料行，也无到期时间 → 显示「永久会员」（买断本就无限期）；
  /// 云端会员（登录用户）读 `member_expire_at`：null 同样是买断不限期，
  /// 有值则转本地时间展示，避免 UTC 差 8 小时。
  String _memberExpireText(BuildContext context, UserProfile? profile) {
    final l10n = AppLocalizations.of(context)!;
    final expire = profile?.memberExpireAt;
    // member_expire_at 为 null（或无云端资料）= 买断制，不限制到期。
    if (expire == null) return l10n.vipLifetime;
    // 数据库存的是 UTC 时间戳，展示前转成本地时间，避免差 8 小时。
    final date = DateFormat('yyyy-MM-dd').format(expire.toLocal());
    return l10n.vipExpireAt(date);
  }

  // —— 会员同步（方案 B）——
  /// 构建「同步会员到账号」入口行（会员卡下方，条件显示）。
  ///
  /// 出现条件：已登录 && 本机有买断权益 && 云端尚未生效（见 _buildVipCard 的
  /// [shouldShowSync]）。点击把本机权益写云端，换设备 / 重装后凭账号恢复。
  Widget _buildSyncEntry(
    BuildContext context,
    WidgetRef ref,
    _ProfilePalette p,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onSyncMember(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.cloud_sync_outlined, size: 20, color: p.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.syncMemberAction,
                  style: TextStyle(fontSize: 13, color: p.subText),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.subText),
            ],
          ),
        ),
      ),
    );
  }

  /// 点击「同步会员到账号」：调 bind 写云端，成功后刷新资料。
  ///
  /// 三种结局：ok → 刷新资料 + 成功提示；needLogin → 登录态丢失，引导重新登录
  /// （本入口理论上仅已登录显示，走到这里是异常兜底）；failed → 失败提示可重试。
  Future<void> _onSyncMember(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    // await 前捕获 messenger，避免跨 async gap 使用 context 的 lint。
    final messenger = ScaffoldMessenger.of(context);
    final result = await MemberBindService.bind(source: 'profile');
    if (!context.mounted) return;
    switch (result) {
      case MemberBindResult.ok:
        // 失效资料 Provider，让云端 is_member_active 立即生效（会员卡 / 徽章刷新）。
        ref.invalidate(userProfileProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.syncMemberDone),
            duration: const Duration(seconds: 2),
          ),
        );
      case MemberBindResult.needLogin:
        // 登录态异常丢失：引导重新登录（登录成功后此入口会因 cloudActive 而消失）。
        context.push('/login');
      case MemberBindResult.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.syncMemberFailed),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  // —— 会员购买 ——
  /// 「立即开通」点击流：跳转到独立购买页面（非弹窗）。
  ///
  /// ★ 不检查登录态：买断权益绑定 Apple ID / Google 账号，
  ///   未登录 App 账号也能直接购买（方案 A：纯端侧，2026-09-04 确认）。
  /// ★ 2026-09-06：从 iOS 系统购买确认弹窗（底部 sheet）改为**独立页面**
  ///   [PurchasePage]（路由 /profile/purchase）。页面本身就是确认步骤，
  ///   点「Upgrade Now」即直接调起真实系统支付，不再有额外弹窗层。
  ///   页面内的支付结果、会员成功态、埋点漏斗由 PurchasePage 自己处理。
  Future<void> _onUpgrade(BuildContext context, WidgetRef ref) async {
    // 跳购买页；source 标 'profile' 区分入口，经 extra 透传到埋点。
    await context.push(
      ProfileRoute.purchase,
      extra: <String, Object?>{'source': 'profile'},
    );
  }

  /// 「恢复购买」点击流：触发系统恢复，结束后按是否命中权益提示。
  ///
  /// App Store 对买断型商品的审核硬要求：必须提供恢复入口。
  /// iOS 重装后靠这里拿回权益；Android 为幂等重查活跃购买。
  Future<void> _onRestorePurchases(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    // await 前捕获 messenger：恢复期间用户可能已离开本页。
    final messenger = ScaffoldMessenger.of(context);

    // ★ 已是会员（云端权益 **或** 本机商店权益任一成立）→ 无需恢复，直接提示。
    //   这一短路很关键：恢复查的是**真实商店交易记录**；而云端会员
    //   （后台开通 / 跨设备同步 / 演示账号）本就没有商店购买记录，调了必然
    //   返回「未找到可恢复的购买记录」，还可能弹出 Apple ID 密码框——
    //   明明是会员却提示「没买过」，既误导又打扰。
    //
    //   ★ 2026-10-01 修正：这里必须用异步版 [settledIsMember] 而不是
    //   `ref.read(isMemberProvider)`。后者是同步读，登录成功后资料异步加载的
    //   那几百毫秒里 cloud 分支仍为 false，会把云端已是会员的用户误判成非会员，
    //   于是真去查商店 → 查不到 → 弹出「未找到可恢复的购买记录」。
    if (await settledIsMember(ref)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.vipRestoreAlready),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 恢复前记录原本是否已持有：只有「从未持有 → 持有」才算恢复命中。
    // 已经是会员的人点恢复，hit 记为 true 会虚增恢复成功率。
    final bool alreadyOwned = ref.read(membershipProvider).owned;
    await ref.read(membershipProvider.notifier).restore();
    final owned = ref.read(membershipProvider).owned;

    // 恢复购买结果：长期偏低意味着用户换机后拿不回权益，
    // 既是退款与差评来源，也是 App Store 审核风险点，必须单独盯着。
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipRestoreResult,
        params: <String, Object?>{'hit': owned, 'already_owned': alreadyOwned},
      ),
    );

    // 命中历史购买 → 已生效提示；没命中 → 明确告知无可恢复记录。
    //
    // ★ Android 要换文案：Google Play 的恢复只查**当前设备登录的 Google 账号**
    //   （与 App 内登录的邮箱无关），且系统**不会**弹出账号选择器让用户切换。
    //   空结果时必须把「换账号登录」这个唯一解法讲清楚，否则用户只会以为
    //   App 坏了、甚至怀疑自己没买过。
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final String emptyTip =
        isAndroid ? l10n.vipRestoreCheckAccount : l10n.vipRestoreEmpty;

    messenger.showSnackBar(
      SnackBar(
        content: Text(owned ? l10n.vipRestoreDone : emptyTip),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // —— 3. 设置分组 ——
  /// 构建「设置」分组：语言 / 清除缓存 / 深色模式(开关) / 通知 / 账号安全。
  Widget _buildSettingsGroup(
    BuildContext context,
    WidgetRef ref,
    _ProfilePalette p,
    String lang,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return _buildGroup(
      context: context,
      p: p,
      title: l10n.settings,
      rows: [
        // 主题色：右侧为咖啡色 / 蓝色二选一选项卡，直接驱动全局色卡切换。
        _RowSpec(
          icon: Icons.palette_outlined,
          title: l10n.themeColorSetting,
          trailing: _buildThemeColorTabs(context, p, ref, l10n),
        ),
        // 语言设置：右侧下拉框直接选择语言（替代原来的点按切换）。
        _RowSpec(
          icon: Icons.language_outlined,
          title: l10n.langSetting,
          trailing: _buildLanguageDropdown(context, p, ref, l10n, lang),
        ),
        // 清除缓存：右侧显示实时占用（MB/KB），点击即清理。
        // value 取自 cacheSizeProvider，未就绪时显示「计算中…」；
        // onTap 触发清理并 invalidate 该 Provider 刷新右侧数字。
        _RowSpec(
          icon: Icons.cleaning_services_outlined,
          title: l10n.clearCache,
          value: ref.watch(cacheSizeProvider).value ?? l10n.calculating,
          onTap: () {
            // 触发清理（异步，不阻塞点击）；清理后刷新占用显示。
            _onClearCache(context, ref);
          },
        ),
        // 保存弹框：右侧为真开关，默认关闭。
        // 关 → 各工具页保存记录时直接以「毫秒时间戳」命名、不打断；
        // 开 → 恢复原来的命名弹窗。开关值存 SharedPreferences（键 save_name_prompt）。
        _RowSpec(
          icon: Icons.drive_file_rename_outline,
          title: l10n.saveNamePromptSetting,
          // 右侧开关整体缩放到 0.8，使其比默认（59×39）明显小一圈，
          // 与「深色模式」行开关保持一致，视觉更精致。
          trailing: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: ref.watch(saveNamePromptProvider).value ?? false,
              activeThumbColor: p.switchActive,
              activeTrackColor: p.switchActive.withValues(alpha: 0.4),
              onChanged: (bool v) {
                // 命名弹窗偏好：开启率反映「用户有多在意记录命名」，
                // 若绝大多数人保持关闭，后续可考虑把命名做成事后可编辑而非保存前拦截。
                AppTrack.log(
                  TrackEvents.settingsSaveNamePromptToggle,
                  params: <String, Object?>{'enabled': v},
                );
                ref.read(saveNamePromptProvider.notifier).setEnabled(v);
              },
            ),
          ),
        ),
        // 深色模式：右侧为真开关，直接驱动全局主题。
        _RowSpec(
          icon: Icons.dark_mode_outlined,
          title: l10n.darkModeLabel,
          // 右侧开关整体缩放到 0.8，与「保存弹框」行开关保持一致。
          trailing: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isDark,
              activeThumbColor: p.switchActive,
              // 轨道用金色半透明，与 thumb 呼应。
              activeTrackColor: p.switchActive.withValues(alpha: 0.4),
              onChanged: (_) {
                // 深色使用占比：占比高则新页面的设计稿必须同时产出深浅两版，
                // 否则会有大量用户看到未适配界面。
                AppTrack.log(
                  TrackEvents.settingsThemeToggle,
                  params: <String, Object?>{'dark': !isDark},
                );
                ref.read(themeProvider.notifier).toggleLightDark();
              },
            ),
          ),
        ),
        // 账号安全：仅登录态出现。点按跳「账号安全」详情页，
        // 集中承载「退出登录」与「注销账号」两类危险操作（均带二次确认），
        // 避免在首页设置里直接堆两个危险入口。
        if (ref.watch(currentUserProvider) != null)
          _RowSpec(
            icon: Icons.shield_outlined,
            title: l10n.accountSecurity,
            onTap: () => context.push(ProfileRoute.accountSecurity),
          ),
      ],
    );
  }

  /// 构建「主题」行右侧的主题色选项卡：咖啡色 / 蓝色二选一。
  ///
  /// 选中态底色取自 [ColorScheme.primary] —— 它会随当前主题色方案变化，
  /// 切到蓝色主题后选中色同步变蓝，避免硬编码金色造成的视觉割裂。
  /// 每个选项左侧带一枚该方案的主色圆点，做到所见即所得。
  Widget _buildThemeColorTabs(
    BuildContext context,
    _ProfilePalette p,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    // 加载中（value 为 null）时按默认咖啡色渲染，保证首帧有确定态。
    final current = ref.watch(themeColorProvider).value ?? AppThemeColor.coffee;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeColorChip(
          label: l10n.themeCoffee,
          swatch: AppTheme.brandPrimary,
          selected: current == AppThemeColor.coffee,
          primary: Theme.of(context).colorScheme.primary,
          unselectedColor: p.subText,
          onTap: () => _onThemeColorChanged(ref, AppThemeColor.coffee),
        ),
        const SizedBox(width: 8),
        _ThemeColorChip(
          label: l10n.themeBlue,
          swatch: SkyTheme.primary,
          selected: current == AppThemeColor.blue,
          primary: Theme.of(context).colorScheme.primary,
          unselectedColor: p.subText,
          onTap: () => _onThemeColorChanged(ref, AppThemeColor.blue),
        ),
      ],
    );
  }

  /// 语言选择下拉框：profile 设置页「Language」行右侧控件，替代原「点按切换」。
  ///
  /// 参数：
  /// - [current] 当前语言代码（来自 [localeProvider]）；
  /// - [supported] 候选语言代码，与 [_languageName] 保持一致（现为 en / zh / ja）。
  /// 选择变更时上报 [TrackEvents.settingsLanguageChange] 并写入 [localeProvider]，
  /// 弹层背景取卡片色、文字取辅助值色，浅/深主题均可读。
  Widget _buildLanguageDropdown(
    BuildContext context,
    _ProfilePalette p,
    WidgetRef ref,
    AppLocalizations l10n,
    String current,
  ) {
    // 五门语言的顺序即下拉列表顺序；新增语种时同步改 [_languageName]。
    const supported = ['en', 'zh', 'ja', 'de', 'fr'];
    return SizedBox(
      width: 150,
      child: DropdownButton<String>(
        value: current,
        isExpanded: true,
        isDense: true,
        // 去掉原生下划线，贴合设置行视觉；右侧箭头用辅助文字色。
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.arrow_drop_down, size: 20, color: p.subText),
        style: TextStyle(fontSize: 14, color: p.rowValue),
        dropdownColor: p.cardBg,
        items: supported
            .map(
              (code) => DropdownMenuItem<String>(
                value: code,
                child: Text(_languageName(code, l10n)),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next == null || next == current) return;
          // 语种实际分布（而非按系统地区推测）：决定翻译与新内容优先做哪种语言。
          AppTrack.log(
            TrackEvents.settingsLanguageChange,
            params: <String, Object?>{'from': current, 'to': next},
          );
          ref.read(localeProvider.notifier).setLanguage(next);
        },
      ),
    );
  }

  /// 切换主题色方案并上报埋点。
  ///
  /// 参数：[color] 目标方案；重复点击当前方案时 [ThemeColorNotifier.setColor]
  /// 内部会短路，不产生无谓的磁盘写入与整树重建。
  void _onThemeColorChanged(WidgetRef ref, AppThemeColor color) {
    final from = ref.read(themeColorProvider).value ?? AppThemeColor.coffee;
    // 主题色偏好分布：若蓝色占比可观，新页面的设计稿需同时产出两套色卡版本。
    AppTrack.log(
      TrackEvents.settingsThemeColorChange,
      params: <String, Object?>{'from': from.name, 'to': color.name},
    );
    // 写 Hive 是异步的，此处不 await（不阻塞 UI），用 unawaited 显式声明意图。
    unawaited(ref.read(themeColorProvider.notifier).setColor(color));
  }

  // —— 5. 关于分组 ——
  /// 构建「关于」分组：更新 / 评分 / 关于 / 协议 / 隐私。
  ///
  /// 不再接收 lang：原先传进来是为了给三个文档入口行拼 `locale` 参数，
  /// 现在到达埋点统一由各文档页自己在 initState 上报，这里用不到了。
  Widget _buildAboutGroup(
    BuildContext context,
    WidgetRef ref,
    _ProfilePalette p, {

    /// 是否插入「广告隐私设置」行（UMP 合规要求，见下方说明）。
    required bool showAdPrivacy,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return _buildGroup(
      context: context,
      p: p,
      title: l10n.aboutGroup,
      rows: [
        _RowSpec(
          icon: Icons.system_update_alt_outlined,
          title: l10n.checkUpdate,
          // 右侧动态显示已安装版本（vX.X.X），用 FutureBuilder 异步取 PackageInfo，
          // 同时保留箭头（本行可点击）。详见 [_versionTrailing]。
          trailing: _versionTrailing(p),
          onTap: () => _onCheckUpdate(context, ref),
        ),
        // 恢复购买：买断型 IAP 的审核硬要求入口。
        // iOS 重装 / 换机（同 Apple ID）后在此取回会员权益，无需登录 App 账号。
        _RowSpec(
          icon: Icons.restore,
          title: l10n.vipRestore,
          onTap: () => _onRestorePurchases(context, ref),
        ),
        // 评分：优先系统应用内评分弹窗（不跳出 App），
        // 弹不出来才回落到商店详情页，具体实现见 util/app_review.dart。
        _RowSpec(
          icon: Icons.star_outline,
          title: l10n.rateUs,
          onTap: () => _onRateUs(context),
        ),
        _RowSpec(
          icon: Icons.info_outline,
          title: l10n.aboutUs,
          onTap: () {
            // 关于我们：已实现独立页面，走本行自带的 onTap 跳 /profile/about-us。
            // 属于公开内容，不判断登录态 —— 未登录用户同样要能读到。
            // 到达埋点（page_doc_view）由 AboutUsPage 自己在 initState 上报，
            // 与隐私政策 / SDK 清单口径一致，这里不再重复记录。
            context.push(ProfileRoute.aboutUs);
          },
        ),
        // 用户协议：在线文档，走通用 App 内 WebView（/profile/web-doc），
        // 标题 / 地址 / 埋点标识经 extra 透传，不把整串 URL 拼进路由地址栏。
        // 属于公开内容，不判断登录态 —— 未登录用户同样要能读到协议全文。
        // 到达埋点（page_doc_view）由 WebDocPage 自己在 initState 上报，
        // 与隐私政策 / SDK 清单口径一致；这里保留行点击埋点（settingsRowTap）。
        _RowSpec(
          icon: Icons.description_outlined,
          title: l10n.userAgreement,
          onTap: () {
            AppTrack.log(
              TrackEvents.settingsRowTap,
              params: <String, Object?>{'row': 'agreement'},
            );
            context.push(ProfileRoute.userAgreement);
          },
        ),
        // 隐私政策：已实现独立页面，走本行自带的 onTap 跳 /profile/privacy。
        // 属于公开内容，不判断登录态 —— 未登录用户同样要能读到政策全文。
        // 到达埋点（page_doc_view）由 PrivacyPolicyPage 自己在 initState 上报。
        _RowSpec(
          icon: Icons.privacy_tip_outlined,
          title: l10n.privacyPolicy,
          onTap: () => context.push(ProfileRoute.privacy),
        ),
        // 第三方 SDK 清单：上架审核与隐私披露用，同样是不要求登录的公开页面。
        // 内容含权限与数据收集说明，与隐私政策并列放在「关于」分组末尾。
        // 到达埋点（page_doc_view）由 ThirdPartySdkPage 自己在 initState 上报。
        _RowSpec(
          icon: Icons.extension_outlined,
          title: l10n.thirdPartySdk,
          onTap: () => context.push(ProfileRoute.thirdPartySdk),
        ),
        // 广告隐私设置（UMP 合规）：地区（EEA / UK / 部分美国州）判定
        // 「必须提供隐私选项入口」时，用户要能随时修改广告同意选择，否则属违规。
        // 因此这一行**按平台判定结果动态显示**（[showAdPrivacy]），不是所有用户都能看到；
        // 点击后由 UMP 弹出官方隐私选项表单，修改完会广播同意状态变化，
        // 各广告位随即按新状态重新加载（见 consent_helper.dart）。
        if (showAdPrivacy)
          _RowSpec(
            icon: Icons.ads_click_outlined,
            title: l10n.adPrivacySettings,
            onTap: () {
              AppTrack.log(
                TrackEvents.settingsRowTap,
                params: <String, Object?>{'row': 'ad_privacy'},
              );
              AdsConsent.showPrivacyOptionsForm();
            },
          ),
      ],
      // 关于分组兜底：上面各行已各自带 onTap，本兜底仅防未来新增行漏配。
      // 它拿不到稳定行标识（只有本地化标题），故不再单独埋点。
      onRowTap: (title) => _toast(context, l10n.devToast(title)),
    );
  }

  /// 通用分组容器：标题 + 卡片（内含多行，行间用分隔线）。
  ///
  /// 参数：
  /// - [title] 分组标题；
  /// - [rows] 行定义列表；
  /// - [onRowTap] 可选，未在各行单独指定 onTap 时使用的兜底点击回调。
  Widget _buildGroup({
    required BuildContext context,
    required _ProfilePalette p,
    required String title,
    required List<_RowSpec> rows,
    void Function(String title)? onRowTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题。
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.rowText,
              ),
            ),
          ),
          // 行卡片。
          Container(
            decoration: BoxDecoration(
              color: p.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    // 行间分隔线（首行上方不加）。
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Divider(height: 1, thickness: 1, color: p.divider),
                    ),
                  _buildRow(context, p, rows[i], onRowTap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单行：图标 + 标题 +（值/开关/箭头）。
  Widget _buildRow(
    BuildContext context,
    _ProfilePalette p,
    _RowSpec spec,
    void Function(String title)? onRowTap,
  ) {
    // 点击优先级：行自带 onTap > 分组兜底 onRowTap > 无操作。
    final onTap =
        spec.onTap ?? (onRowTap != null ? () => onRowTap(spec.title) : null);
    return InkWell(
      onTap: onTap,
      // 仅在有点击行为时高亮，纯展示行保持静态。
      highlightColor: onTap == null
          ? Colors.transparent
          : p.gold.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(spec.icon, size: 22, color: p.rowText),
            const SizedBox(width: 14),
            Expanded(
              // 单行标题，行高与既有行一致。
              child: Text(
                spec.title,
                style: TextStyle(fontSize: 15, color: p.rowText),
              ),
            ),
            // 右侧：优先用自定义 trailing（如开关），否则显示值 + 箭头。
            if (spec.trailing != null)
              spec.trailing!
            else ...[
              if (spec.value != null)
                Text(
                  spec.value!,
                  style: TextStyle(fontSize: 14, color: p.rowValue),
                ),
              if (onTap != null) ...[
                if (spec.value != null) const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 20, color: p.subText),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 轻量占位提示（无真实后端的行点击时给出反馈）。
  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  /// 「给我们评分」：优先系统应用内评分弹窗，不可用则回落商店详情页。
  ///
  /// 只在**两条路都走不通**时才提示用户 —— 弹窗和跳转本身就是明确反馈，
  /// 这时候再叠一个 toast 只会变成噪音（详见 `util/app_review.dart`）。
  Future<void> _onRateUs(BuildContext context) async {
    final result = await requestAppReview();
    // 评分入口埋点：`unavailable` 占比高说明应用内评分 API 在该区域不可用
    // （如国行 iOS 的部分场景），需要改成跳转商店详情页的兜底方案。
    AppTrack.log(
      TrackEvents.profileRateRequest,
      params: <String, Object?>{'result': result.name},
    );
    // await 期间页面可能已被销毁（用户切了 Tab / 退出登录），
    // 此时拿 ScaffoldMessenger 会抛异常，必须先判 mounted。
    if (!context.mounted) return;
    if (result == AppReviewResult.unavailable) {
      _toast(context, AppLocalizations.of(context)!.rateUsUnavailable);
    }
  }

  /// 检查更新。
  ///
  /// 行为（见 `util/app_update.dart`）：
  /// - 未配置远端地址（[kAppUpdateInfoUrl] 空）→ 直接打开商店详情页，
  ///   由 App Store / Play Store / Microsoft Store 告知是否有更新可装；
  /// - 配置了远端地址 → 拉取版本 JSON 比较：有更新弹「发现新版本」对话框
  ///   （Update 打开商店 / Later 关闭），已最新提示「已是最新 (vx.x.x)」，
  ///   拉取失败回落打开商店（商店仍是更新入口）。
  ///
  /// 配置了远端地址时先弹 loading，网络返回后再关闭，避免结果闪现过快。
  Future<void> _onCheckUpdate(BuildContext context, WidgetRef ref) async {
    final hasRemote = kAppUpdateInfoUrl.isNotEmpty;
    if (hasRemote) _showUpdateLoading(context);
    // 先取本地版本用于文案；getCurrentVersion 内部已记忆化，不会重复读平台。
    final current = await getCurrentVersion();
    final (result, info) = await checkForUpdate();
    // 关掉 loading：用 rootNavigator 确保关的是最上层那个 loading 对话框。
    if (hasRemote && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;

    switch (result) {
      case UpdateCheckResult.updateAvailable:
        // 有更新：弹对话框让用户决定升级还是稍后。
        await _showUpdateDialog(context, info);
        break;
      case UpdateCheckResult.openStore:
      case UpdateCheckResult.error:
        // 没后端或拉取失败：以商店为更新入口（商店会显示是否有更新可装）。
        await openStoreForUpdate();
        break;
      case UpdateCheckResult.upToDate:
        _toast(context, '$_kUpToDatePrefix (v$current)');
        break;
    }
    // 检查结局埋点：up_to_date / updateAvailable / openStore / error 既能反映
    // 远端配置是否就绪，也能看出用户是否真的有更新可升。
    AppTrack.log(
      TrackEvents.settingsRowTap,
      params: <String, Object?>{'row': 'check_update', 'status': result.name},
    );
  }

  /// 右侧版本尾标：异步取已安装版本并显示版本标签，末尾带箭头。
  ///
  /// 标签由 [buildVersionLabel] 生成：Release 模式显示 `vX.X.X`，
  /// 非 Release（Debug / Profile）显示 `debug vX.X.X`，用于区分开发包与正式版。
  /// 用懒加载记忆化的 [getCurrentVersion]，多次 build 不会重复读平台信息。
  /// 版本加载完成前先渲染空（只留箭头），加载完补上版本号。
  Widget _versionTrailing(_ProfilePalette p) {
    return FutureBuilder<String>(
      future: getCurrentVersion(),
      builder: (ctx, snap) {
        final label = snap.hasData ? buildVersionLabel(snap.data!) : '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (label.isNotEmpty)
              Text(label, style: TextStyle(fontSize: 14, color: p.rowValue)),
            if (label.isNotEmpty) const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 20, color: p.subText),
          ],
        );
      },
    );
  }

  /// 检查中 loading（仅在配置了远端地址时展示，避免无网络时闪一下）。
  void _showUpdateLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  /// 「发现新版本」对话框：Update 打开商店，Later 关闭。
  ///
  /// [info] 远端版本信息，其 [UpdateInfo.releaseNotes] 有内容时追加到正文。
  Future<void> _showUpdateDialog(BuildContext context, UpdateInfo? info) async {
    final latest = info?.latestVersion ?? '';
    final notes = info?.releaseNotes;
    final body = notes != null && notes.isNotEmpty
        ? '$_kUpdateBodyPrefix $latest.\n\n$notes'
        : '$_kUpdateBodyPrefix $latest.';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_kUpdateTitle),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_kUpdateLater),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 跳转商店由平台负责拉起更新页（iOS 需 kAppStoreId 已配置）。
              openStoreForUpdate();
            },
            child: Text(_kUpdateNow),
          ),
        ],
      ),
    );
  }

  /// 清除缓存并刷新占用显示。
  ///
  /// 删除临时目录与应用缓存目录内容、清空内存图片缓存（见 [clearAppCache]），
  /// 完成后 invalidate [cacheSizeProvider] 让右侧数字重新统计为清理后的占用。
  ///
  /// 注意：先在本方法开头同步取出 [ScaffoldMessengerState]，避免 [clearAppCache]
  /// 的 await 之后再用 [BuildContext]，规避 use_build_context_synchronously 警告。
  Future<void> _onClearCache(BuildContext context, WidgetRef ref) async {
    // 在 await 前捕获 messenger，使其跨异步间隙安全可用。
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    // 清理前先取占用：观察缓存增长速度 —— 若短期内反复涨到很大，
    // 应加自动清理策略，而不是让用户手动点。
    // 取 [cacheBytesProvider] 的数值（与展示文案共用同一份遍历结果，不额外扫盘）。
    final int? bytes = ref.read(cacheBytesProvider).value;
    await clearAppCache();
    AppTrack.log(
      TrackEvents.settingsCacheCleared,
      params: <String, Object?>{
        // 只上传量级桶，精确字节数对分析无意义。
        'size_mb': bytes == null
            ? null
            : TrackBuckets.megabytes(bytes / (1024 * 1024)),
      },
    );
    // 关键：必须让底层字节数 Provider（[cacheBytesProvider]）也失效，
    // 否则 [cacheSizeProvider] 通过 ref.watch 读到的仍是旧的缓存占用，
    // 右侧数字会停在清理前的原值不刷新。
    ref.invalidate(cacheBytesProvider);
    ref.invalidate(cacheSizeProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.cacheCleared),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// 分组内单行的轻量描述。
///
/// 用数据对象描述一行，配合 [_buildRow] 渲染，避免为每行写一个方法。
class _RowSpec {
  /// 创建单行描述。
  const _RowSpec({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  /// 左侧图标。
  final IconData icon;

  /// 左侧标题。
  final String title;

  /// 右侧辅助值（如「23.5 MB」）。与 [trailing] 互斥，优先 [trailing]。
  final String? value;

  /// 右侧自定义控件（如深色模式开关）。存在时覆盖默认箭头。
  final Widget? trailing;

  /// 点击回调；为空则该行不可点击。
  final VoidCallback? onTap;
}

/// 主题色选项卡的单枚「胶囊」：色点 + 文案，二选一。
///
/// 选中态为 [primary] 实心底 + 白色文字；未选中态为描边 + 灰字，
/// 两种状态尺寸一致，切换时不会引起行高跳动。
class _ThemeColorChip extends StatelessWidget {
  /// 创建主题色胶囊。
  const _ThemeColorChip({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.primary,
    required this.unselectedColor,
    required this.onTap,
  });

  /// 胶囊文案（如「咖啡色」）。
  final String label;

  /// 左侧色点颜色：该主题方案的品牌主色，用于直观预览。
  final Color swatch;

  /// 是否为当前选中的方案。
  final bool selected;

  /// 选中态底色，取自当前 [ColorScheme.primary]，随主题色方案联动。
  final Color primary;

  /// 未选中态的文字与描边色。
  final Color unselectedColor;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // 去掉水波纹的圆角外溢，使高亮与胶囊形状一致。
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          // 未选中时用细描边维持可点击感，选中时描边与底色同色避免边界发虚。
          border: Border.all(
            color: selected ? primary : unselectedColor.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 色点：始终显示方案真实主色，选中态下加白边以在实底上保持可见。
            Container(
              width: 12,
              height: 10,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: Colors.white, width: 1.5)
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
