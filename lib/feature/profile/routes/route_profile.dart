// ============================================================================
// 文件：feature/profile/routes/route_profile.dart
// 模块：我的 / 个人中心（profile）
//
// 职责：
//   集中声明「个人中心」模块的独立子页面路由，由应用级路由（app_router）展开注册，
//   避免在根路由文件里堆砌所有页面路径。
//
// 已注册页面：
//   /profile/edit   —— 编辑资料页（昵称 + 头像），由资料页点击头像 push 进入。
//   /profile/privacy —— 隐私政策页，由资料页「关于」分组的「隐私政策」行 push 进入。
//     属于公开内容：不依赖登录态，未登录也能打开。
//   /profile/third-party-sdk —— 第三方 SDK 清单页，由资料页「关于」分组的
//     「第三方 SDK 清单」行 push 进入。供上架审核与隐私披露使用，
//     与隐私政策页同为公开内容，不依赖登录态。
//   /profile/about-us —— 关于我们页，由资料页「关于」分组的「关于我们」行
//     push 进入。正文为英文，供海外用户了解产品；同为公开内容，不依赖登录态。
//   /profile/purchase —— 会员购买页（独立页面，非弹窗），由资料页 VIP 卡
//     「Upgrade Now」与 tools 页顶部会员状态条（未购买时）push 进入。
//     承载买断制 IAP 的确认与支付拉起；公开内容，不依赖登录态。
//   /profile/user-agreement —— 用户协议页，由资料页「关于」分组的「用户协议」行
//     push 进入。**本地静态页**（不走 WebView）：原在线地址 www.aknot.uk
//     至今仍无 A 记录、DNS 解析失败；而协议属上架必须可读的合规内容，
//     不能依赖站点就绪情况，故落地为本地页。
//     ⚠️ 2026-09-17 现状：唯一的在线文档只有 GitHub Pages 上的隐私政策
//     （https://aberciozhang.github.io/privacy/tool-box，见 profile_page 的
//     [_privacyPolicyUrl]），**线上并没有用户协议页**，故本路由仍需保留本地实现。
//     同样不与账号状态耦合，未登录也能打开。
//   /profile/web-doc —— App 内在线文档页（WebView 容器），当前**暂无入口**。
//     通用容器：标题 / 地址 / 埋点标识经 extra 透传。原用于展示在线用户协议，
//     因域名未解析而改为本地页；日后若要展示在线隐私政策，直接复用本路由即可。
//     同样不与账号状态耦合，未登录也能打开。
//
// 说明：
//   ProfilePage 本身不是独立路由，它作为 MainTabPage 的一个 Tab 内嵌展示；
//   只有需要「推入新页面」的子功能才在这里登记路径。
//   因此本文件只导出 [ProfileRoute.routes]，不导出资料页自身。
//
// 关键依赖：
//   - go_router：GoRoute 声明；
//   - feature/profile/page/edit_profile_page.dart：编辑资料页。
//   - feature/profile/page/privacy_policy_page.dart：隐私政策页。
//   - feature/profile/page/third_party_sdk_page.dart：第三方 SDK 清单页。
//   - feature/profile/page/about_us_page.dart：关于我们页。
//   - feature/profile/page/user_agreement_page.dart：用户协议页。
//   - feature/profile/page/web_doc_page.dart：App 内在线文档页（WebView 容器）。
// ============================================================================

import 'package:go_router/go_router.dart';

import '../page/about_us_page.dart';
import '../page/edit_profile_page.dart';
import '../page/privacy_policy_page.dart';
import '../page/purchase_page.dart';
import '../page/third_party_sdk_page.dart';
import '../page/user_agreement_page.dart';
import '../page/account_security_page.dart';
import '../page/web_doc_page.dart';

/// 个人中心模块的路由表。
class ProfileRoute {
  const ProfileRoute._();

  /// 编辑资料页路径（昵称 + 头像）。
  static const String edit = '/profile/edit';

  /// 隐私政策页路径（公开内容，不要求登录）。
  static const String privacy = '/profile/privacy';

  /// 第三方 SDK 清单页路径（公开内容，不要求登录）。
  static const String thirdPartySdk = '/profile/third-party-sdk';

  /// 关于我们页路径（英文正文，公开内容，不要求登录）。
  static const String aboutUs = '/profile/about-us';

  /// 会员购买页路径（独立页面，非弹窗；公开内容，不要求登录）。
  static const String purchase = '/profile/purchase';

  /// 用户协议页路径（**本地**静态页，公开内容，不要求登录）。
  ///
  /// 由资料页「关于」分组的「用户协议」行 push 进入。
  static const String userAgreement = '/profile/user-agreement';

  /// App 内在线文档页路径（WebView 容器；公开内容，不要求登录）。
  ///
  /// 路径里不带内容参数 —— 标题 / 地址 / 埋点标识经 extra 透传，
  /// 避免把整串 URL 拼进地址栏（编码与可读性都不好）。
  /// 首个使用者是资料页「关于」分组的「用户协议」行。
  static const String webDoc = '/profile/web-doc';

  /// 账号安全页路径（登录态可见；公开内容兜底，未登录也能打开但只显示引导）。
  ///
  /// 由资料页「设置」分组新增的「账号安全」行 push 进入，集中承载
  /// 「退出登录」与「注销账号」两类账号危险操作（均带二次确认）。
  static const String accountSecurity = '/profile/account-security';

  /// 本模块对外暴露的路由列表，由 app_router 展开合入主表。
  static List<GoRoute> get routes => <GoRoute>[
    GoRoute(
      path: edit,
      builder: (context, state) => const EditProfilePage(),
    ),
    GoRoute(
      path: privacy,
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: thirdPartySdk,
      builder: (context, state) => const ThirdPartySdkPage(),
    ),
    GoRoute(
      path: aboutUs,
      builder: (context, state) => const AboutUsPage(),
    ),
    GoRoute(
      path: purchase,
      // 购买来源（'profile' / 'tool_page'）经 extra 透传，便于漏斗分区观察；
      // extra 缺失时兜底 'profile'。
      builder: (context, state) {
        // extra 经 go_router 传递时类型可能被擦除成 Map<dynamic, dynamic>
        // （尤其从平台通道 / 深度链接回灌时），直接 `as Map<String, Object?>`
        // 会抛 TypeError 红屏。这里按 Map 宽进、按 key 窄取，缺省兜底 'profile'。
        final extra = state.extra;
        String source = 'profile';
        if (extra is Map) {
          final s = extra['source'];
          if (s is String) source = s;
        }
        return PurchasePage(source: source);
      },
    ),
    GoRoute(
      path: userAgreement,
      builder: (context, state) => const UserAgreementPage(),
    ),
    GoRoute(
      path: webDoc,
      // 标题 / 地址 / 埋点标识经 extra 透传。
      // ⚠️ 与 purchase 同理：extra 从平台通道 / 深链回灌时可能被擦除成
      // Map<dynamic, dynamic>，直接强转会抛 TypeError 红屏；
      // 这里统一按「Map 宽进 → 按 key 窄取 → 缺失兜底」处理。
      //   title   兜底空串（缺失时 AppBar 留空，不至于崩）；
      //   url     兜底空串（页面内部会判定空地址并落到错误态）；
      //   trackPage 兜底 'web_doc'（缺失时仍落到通用统计桶）。
      builder: (context, state) {
        final extra = state.extra;
        String title = '';
        String url = '';
        String trackPage = 'web_doc';
        if (extra is Map) {
          final t = extra['title'];
          final u = extra['url'];
          final p = extra['trackPage'];
          if (t is String) title = t;
          if (u is String) url = u;
          if (p is String) trackPage = p;
        }
        return WebDocPage(title: title, url: url, trackPage: trackPage);
      },
    ),
    GoRoute(
      path: accountSecurity,
      builder: (context, state) => const AccountSecurityPage(),
    ),
  ];
}
