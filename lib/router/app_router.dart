// app_router.dart
//
// 职责：基于 go_router 定义 App 的全局路由表，作为路由模块的唯一装配入口。
// 所属模块：tool_box / router（应用导航层）。
// 关键依赖：
//  - flutter_riverpod：通过 Provider 暴露 [GoRouter] 实例，供 [ToolBoxApp] 监听使用。
//  - go_router：声明式路由，统一管理初始页面与各功能模块路由。
//  - ToolRoute：由工具箱模块自带的路由片段，通过展开运算符合入主表，
//    实现「模块自治 + 统一入口」的路由组织方式（新增模块只需在此展开对应 routes）。
//  - MainTabPage：应用壳层（底部 Tab 容器），作为启动屏轮播结束后的落地页。
//  - SplashPage：启动屏第二段（Flutter 层轮播页），作为 App 的初始路由，
//    播放 compass → level → noise → ruler 四图淡入淡出共 3 秒后跳转 '/home'。
//  - ProfileRoute：个人中心模块路由片段（目前含 /profile/edit 编辑资料页），
//    与 ToolRoute 同样通过展开运算符合入主表。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_box/common/analytics/track_page_observer.dart';
import 'package:tool_box/common/auth/token_expired_state.dart';
import 'package:tool_box/feature/profile/routes/route_profile.dart';
import 'package:tool_box/feature/splash/page/splash_page.dart';
import 'package:tool_box/feature/tool/route/tool_route.dart';

import '../feature/home/page/main_tab_page.dart';
import '../feature/login/page/email_login_page.dart';
import '../feature/login/page/login.dart';

/// 全局路由观察者。
///
/// 供需要感知「自己被 push 覆盖 / 重新可见 / 被 pop 移除」的页面使用
/// （如直尺页强制横屏：被覆盖或移除时恢复竖屏）。通过
/// [GoRouter.navigatorObservers] 挂载到全局导航器，页面以 [RouteAware]
/// 订阅 [routeObserver] 即可收到 [RouteAware.didPushNext] /
/// [RouteAware.didPopNext] 等回调。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// 合并多个 [Listenable] 成一个，供 [GoRouter.refreshListenable] 使用。
///
/// 为什么需要它：GoRouter 只接受**一个** refreshListenable。本工程目前只有一个
/// 「状态驱动跳转」来源 —— token 失效（tokenExpiredPending），但保留这个聚合层，
/// 以后新增第二个来源（如推送深链、强制升级）时直接往 children 里加即可，
/// 不必改 GoRouter 的构造。
class _CompositeListenable extends ChangeNotifier {
  _CompositeListenable(List<Listenable> children) {
    for (final Listenable child in children) {
      child.addListener(notifyListeners);
    }
  }
}

/// 全局页面浏览埋点观察者。
///
/// 声明为顶层 final：GoRouter 只构建一次（Provider 缓存），但观察者内部持有
/// 「页面 → 上次记录时间」的去重状态，必须是同一个实例才能生效跨跳转去重。
final TrackPageObserver _trackPageObserver = TrackPageObserver();

/// 全局路由 [GoRouter] 的 Provider。
///
/// 职责：构建并返回应用唯一的路由配置实例。
///  - `initPath = '/home'`：应用启动后的初始落地页面固定为 Tab 壳层。
///  - 路由来源采用「聚合式」组装：以壳层 route 为基准，再展开各业务模块
///    （[ToolRoute] 工具箱、[ProfileRoute] 个人中心）导出的路由列表，
///    保持模块间路由解耦。
///  - profile 模块的页面大多作为 Tab 内嵌展示，只有需要推入新页面的子功能
///    （如编辑资料页 /profile/edit）才在 ProfileRoute 里登记路径。
///  - 返回值通过 [GoRouter] 暴露给 [ToolBoxApp.routerConfig]，使主题/语言切换
///    与导航共享同一套 Provider 树。
final appRouterProvider = Provider<GoRouter>((ref) {
  final initPath = '/home';
  // 启动屏：App 的初始路由。原生启动屏（flutter_native_splash）负责引擎加载前的
  // 静态首帧，本页负责引擎就绪后的四图轮播，两者视觉首尾相接，合计停留 3 秒。
  final splash = '/splash';
  // 壳层：作为底部 Tab 容器，固定路径 '/home'，由启动屏轮播结束后跳转抵达。
  final login = '/login';
  //
  // 邮箱密码登录页：2026-09-30 新增，路径常量定义在 EmailLoginPage.route。
  //
  // ⚠️ 注册 / 重置密码 / 邮箱验证等路由仍随**邮箱密码链路**保持移除
  // （方案 B：注册 = 登录合一，无密码注册流程）；本路由只补回「登录」这一条，
  // 主要为应用商店审核准备（审核员无 Apple ID 时可用邮箱登录验证功能）。
  // 详见 doc/purchase_handoff.md §9 与 email_login_page.dart 类注释。
  final emailLogin = EmailLoginPage.route;
  final GoRoute splashRoute = GoRoute(
    path: splash,
    builder: (ctx, s) => const SplashPage(),
  );
  final GoRoute homeRoute = GoRoute(
    path: initPath,
    builder: (ctx, s) => const MainTabPage(),
  );
  final GoRoute loginRoute = GoRoute(
    path: login,
    builder: (ctx, s) => const LoginPage(),
  );
  // 邮箱密码登录页：从登录页 push 进入，登录成功后自行返回登录页。
  final GoRoute emailLoginRoute = GoRoute(
    path: emailLogin,
    builder: (ctx, s) => const EmailLoginPage(),
  );
  // 组装各模块路由列表：将壳层与工具箱、个人中心模块路由合并为完整路由表。
  final List<GoRoute> routes = [
    splashRoute,
    homeRoute,
    loginRoute,
    emailLoginRoute,
    ...ToolRoute.routes,
    ...ProfileRoute.routes,
  ];
  // 初始路由指向启动屏：启动先进 /splash 播放轮播，再由该页 go('/home') 进入壳层。
  return GoRouter(
    initialLocation: splash,
    routes: routes,
    // 「状态驱动跳转」：token 失效可能发生在任意异步回调里，那里拿不到可靠
    // context。统一改成置位 → 这里重算 redirect，由路由层在任意时机翻译成一次导航。
    refreshListenable: _CompositeListenable(<Listenable>[
      tokenExpiredPending,
    ]),
    redirect: (BuildContext ctx, GoRouterState state) {
      // token 失效：带用户去登录页重新登录。
      // 与上面不同，这里是**一次性**的：置回 false 后立即跳转，避免用户
      // 登录成功后（或手动返回后）被残留标记反复弹回登录页。
      if (tokenExpiredPending.value && state.matchedLocation != login) {
        tokenExpiredPending.value = false;
        return login;
      }
      // 其余情况一律不干预（返回 null = 按原计划导航）。
      return null;
    },
    // 挂载两个全局观察者，职责互不重叠：
    //   - routeObserver：给页面自己用（如直尺页强制横屏，需感知被覆盖/移除）；
    //   - _trackPageObserver：统一采集 page_view，新增路由自动获得 PV 统计，
    //     任何页面都不必手写一次页面埋点（详见 common/analytics/track_page_observer.dart）。
    observers: [routeObserver, _trackPageObserver],
  );
});
