// main.dart
//
// 职责：App 启动入口，负责应用级初始化（本地键值存储 / 本地数据库 / 远程配置 / 埋点）
// 并构建根组件 [ToolBoxApp]。
// 所属模块：tool_box（应用入口层）。
// 关键依赖：
//  - flutter_riverpod：以 [ProviderScope] 包裹根组件，提供全局 Provider 容器。
//  - hive_flutter：本地键值存储（语言 / 主题等轻量配置）+ 埋点事件队列。
//  - IsarService：本地结构化数据库（工具箱六张记录表）。
//  - supabase_flutter：注册 / 登录 / Google 一键注册 + 埋点上报通道。
//  - TrackService：行为埋点（默认关闭，上线前改 enabled: true）。
//  - go_router + app_router：声明式路由。
//  - l10n / flutter_localizations：多语言（中/英）支持。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome（全局屏幕朝向锁定）
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/ads/admob_init.dart';
import 'package:tool_box/common/analytics/app_lifecycle_tracker.dart';
import 'package:tool_box/common/auth/app_token_manager.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/common/track/track.dart';
import 'package:tool_box/common/utils/yaml_utl.dart';
import 'package:tool_box/feature/tool/provider/flashlight_provider.dart';
import 'package:tool_box/router/app_router.dart';
import 'package:yaml/yaml.dart';

import 'common/constants/app_box.dart';
import 'config/app_env.dart';
import 'config/base_url.dart';
import 'common/provider/app_settings/free_usage_provider.dart';
import 'common/provider/locale/locale_provider.dart';
import 'common/provider/theme/app_theme.dart';
import 'common/provider/theme/sky_theme.dart';
import 'common/provider/theme/theme_color_provider.dart';
import 'common/provider/theme/theme_notifier.dart';
import 'l10n/app_localizations.dart';

/// 应用主入口。
///
/// 职责：在 `runApp` 前完成所有阻塞式异步初始化（键值存储、结构化数据库、
/// 远程配置），再挂载 [ProviderScope] + [ToolBoxApp]。
/// 注意：
///  - 整个流程为 `async`，必须首先调用 [WidgetsFlutterBinding.ensureInitialized]
///    绑定 Flutter 框架与平台原生通道，否则后续异步 UI 初始化会崩溃。
///  - 顺序很重要：Hive 必须先于 [LocaleNotifier] / [ThemeNotifier] 使用，
///    因为两者在 build 时会直接同步读取已打开的 Box。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Hive 初始化：本地键值存储，用于缓存语言、主题等轻量配置。
  await Hive.initFlutter();
  await Hive.openBox(AppBox.boxName);

  // 2. Isar 初始化：打开工具箱六张记录表所在的本地数据库。
  //    各子工具（指南针 / 噪音 / 水平仪 / 直尺 / 潮汐 / 备忘录）的历史记录
  //    均依赖该实例，必须在首帧之前就绪。
  await IsarService.initialize();

  // 3. Supabase 初始化：注册 / 登录 / Google 一键注册都依赖它。
  //    url 优先取编译期注入的 SUPABASE_URL，回落到 base_url.dart 的 AppUrl.supabase；
  //    anonKey 必须非空才初始化——缺失时跳过并打印警告，
  //    避免「配置没填就启动崩溃」，登录/注册页会给出明确提示。
  final String supabaseUrl = AppEnv.supabaseUrl.isNotEmpty
      ? AppEnv.supabaseUrl
      : AppUrl().supabase;
  if (AppEnv.supabaseAnonKey.isNotEmpty) {
    // publishableKey 即 Supabase 控制台的 anon/publishable key（新版命名），
    // 参数名虽变，但填入的仍是控制台 API Settings 里的同一个 key。
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
    );
  } else {
    debugPrint(
      '[Supabase] 未配置 SUPABASE_ANON_KEY，跳过初始化，登录/注册暂不可用。'
      ' 运行时请追加： --dart-define=SUPABASE_URL=https://<ref>.supabase.co'
      ' --dart-define=SUPABASE_ANON_KEY=<anon-key>',
    );
  }

  // 4. 埋点工具初始化：Hive Box / 队列 / Batch / Transport 全部就绪。
  //    - enabled: true 已开启上报（开发期用于模拟器验证；上线前如无需上报改回 false）；
  //    - edgeFunctionUrl 取自 [AppEnv.trackEdgeUrl]：优先 `--dart-define=TRACK_EDGE_URL=...`，
  //      未注入时回落到 tool_box 项目线上函数地址（见 app_env.dart），不会留空；
  //    - useEdgeFunction: true 走 Edge Function 网关（推荐生产路径）；
  //    - Supabase anon key 与 URL 与上面 Supabase 初始化共用，便于统一从编译期注入。
  //    注意：当前为"零侵入接入"，main 内不引用已有 base_url.dart，避免循环依赖；
  //         真正上线时把 TRACK_EDGE_URL / TRACK_CLIENT_TOKEN 注入到 .env 或 CI 即可。
  await TrackService.instance.init(
    TrackConfig(
      enabled: true,
      appId: 'tool_box',
      edgeFunctionUrl: AppEnv.trackEdgeUrl,
      clientToken: AppEnv.trackClientToken,
      useEdgeFunction: true,
      debug: AppEnv.isDev,
    ),
    appVersion: await TrackService.currentAppVersion(),
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: AppEnv.supabaseAnonKey,
  );

  // 4.1 埋点身份绑定：先匿名、后登录态，两者缺一不可。
  //
  // 为什么必须显式做这一步：TrackService 只负责"记录"，它并不知道 App 用的是
  // 什么账号体系（本工程是 Supabase，别的工程可能是自建 JWT）。
  // 因此身份注入的职责留在调用方 —— 不注入的话 user_id 列会一直是 null。
  //
  // 两级身份：
  //   1) 设备匿名 ID —— 首次启动生成并存 Hive，未登录时兜底 user_id，
  //      同时能在"登录前 → 登录后"之间串联同一台设备的完整行为链；
  //   2) 登录用户 ID —— Supabase 的 auth user uuid，登录后覆盖匿名 ID。
  // 注意：setAnonymousId 是同步方法（只存引用），load() 才是异步的。
  TrackService.instance.setAnonymousId(await TrackAnonymousId.load());

  // 冷启动同步：Supabase 会把上次的 session 存本地并从存储恢复，
  // 所以这里往往已经能拿到用户；不先同步的话，启动后到首次 auth 事件推送
  // 之前的这段事件（含最早的 app_open）都会丢 user_id。
  TrackService.instance.setUserId(_readSupabaseUserId());

  // 登录 / 登出 / Token 续期都走这个流，据此让埋点身份与账号态保持同步。
  // 用 try/catch 兜住：未配置 key 时 Supabase 未初始化，访问 client 会抛异常。
  _subscribeAuthUserIdChanges();

  // 冷启动主动校验服务端登录态：
  // Supabase 默认「恢复本地持久化 session 即视为已登录」，启动时不主动联系服务端。
  // 若后端把 auth.users 清空（如开发期重置数据库），本地 JWT 仍在有效期内时，
  // App 重启仍会显示已登录，与「服务端已无此用户」状态不一致。这里发一次 getUser()
  // 让服务端确认用户是否还在；已删则清本地登录态，UI 经 onAuthStateChange 自动切未登录。
  // 注：该校验函数内联为 main 局部函数，确保调用点（下方）在任意 analyzer 视角下均可见，
  // 避免「顶层前向引用未被识别」这类误报导致编译失败。
  Future<void> validateSessionOnLaunch() async {
    try {
      // 未登录态无需校验，直接返回。
      if (Supabase.instance.client.auth.currentSession == null) return;
      // getUser 调 /auth/v1/user，用户已删时服务端返回 401，抛 AuthException。
      await Supabase.instance.client.auth.getUser();
    } on AuthException catch (e) {
      // 仅「鉴权失效」才清本地：用户被删或令牌作废、服务端明确拒绝。
      // 注意 statusCode 是 String?；401/403/404 表示用户不存在或令牌无效，
      // 400/422 覆盖部分请求结构错误，均按「服务端已不接受此会话」处理。
      final String? code = e.statusCode;
      final bool isAuthError = code == '401' ||
          code == '403' ||
          code == '404' ||
          code == '400' ||
          code == '422';
      if (isAuthError) {
        try {
          // 默认 scope=local：只清本地 session，不请求服务端（服务端已无此用户）。
          await Supabase.instance.client.auth.signOut();
        } catch (_) {
          // 清本地失败不影响后续，下次启动还会再次校验。
        }
      }
    } catch (_) {
      // 网络 / 超时等非鉴权异常：保留本地 session，保证离线可用。
    }
  }
  await validateSessionOnLaunch();

  // 说明：原先这里还注册了「密码恢复」监听（`_subscribePasswordRecovery`），
  // 随邮箱密码链路一并移除 —— 方案 B 只保留 Apple / Google 登录，无密码即无重置，
  // 相关的 `passwordRecoveryPending` 标记与 GoRouter redirect 分支也已删除
  // （见 doc/purchase_handoff.md §9）。

  // 4.1.1 权限 token 预取（静默、不 await）。
  //
  // token 由服务端签发（见 users.sql 第 5b 段），有效期 30 天：
  //   - 已登录 → 用户 token（落库 users.token）；
  //   - 未登录 → 游客 token（传设备匿名 UUID，无状态签发）。
  // 这里只做「提前备好」：真正要用时再调 AppTokenManager.ensureValidToken()，
  // 命中缓存就零网络返回。故意不 await —— 预取失败也不能拖慢启动，
  // 且失败已在快照里表达，业务侧会自行降级。
  unawaited(AppTokenManager.prewarm());

  // 4.2 回填"身份绑定之前"就已经入队的事件：user_id 在入队那一刻就写死了，
  //     上面三步之前产生的事件（含上次运行残留、离线积压的）身份都是 null，
  //     不补的话传到服务端也无法参与按用户的聚合。已有身份的行不会被改写。
  await TrackService.instance.backfillQueuedIdentity();

  // 4.3 埋点会话观察者 + 全局异常捕获。
  //
  // 二者都必须在 runApp **之前**装好：
  //   - 生命周期观察者：冷启动的第一个 resumed 事件可能早于 Widget 树建立，
  //     挂到 Widget 上会漏掉；
  //   - 异常捕获：Isar / Supabase 初始化期间若抛异常，此刻还没进 Flutter 的错误处理链，
  //     不提前装就一条也捞不到。
  _appLifecycleTracker.install();
  _installTrackErrorHandlers();

  // 4.4 AdMob SDK 初始化（横幅广告）。
  //
  // 必须在 runApp **之前**完成：原生 GMA SDK 需要在引擎起来前读走
  // AndroidManifest / Info.plist 里的 App ID；若拖到首帧之后，插件虽会补做一次
  // 初始化，但那次补做的异常无法被 catch，会直接冒泡成红屏。
  //
  // 放在这里而不是更早：广告依赖埋点之外的任何东西都没有，
  // 但刻意排在 Track 之后，是为了让「广告初始化失败」这类日志出现在埋点就绪之后，
  // 便于用 AppTrack.error 统一收集（当前 initAdMob 内部只 debugPrint，保持轻依赖）。
  //
  // 用 await 而非 unawaited：初始化通常几十毫秒，同步等完再进首页更稳，
  // 且它已经内部兜住了全部异常，不会拖慢或阻断启动。
  //
  // ⚠️ 最坏情况会在这里等约 3 秒：initAdMob 里的 UMP 同意信息拉取走 Google
  // 服务，国内网络下基本必超时，等待上限由 AdsConsent 的 _kStartupWait 控制。
  // 超时后不重试、直接放行，结果迟到时再异步通知广告组件补加载，
  // 因此冷启动最多多花这 3 秒，不会更久。
  await initAdMob();

  // 5. 读取 YAML 配置：加载 dev 环境远程参数，缺失时仅跳过打印，不阻断启动。
  final YamlMap? env = await YamlUtil.loadAssetsFile(
    'assets/config/dev_env.yaml',
  );
  if (env != null) {
    debugPrint('appEnv: $env');
  }

  // 6. 全局默认竖屏：除 ruler 页（直尺 / 量角器）刻意横屏外，其余所有页面锁定竖屏，
  //    不随设备传感器旋转。进入 ruler 时该页会 setPreferredOrientations(_landscape)
  //    临时切横屏、离开时恢复竖屏，互不干扰。
  //    注意：此处只约束 Dart 层朝向，iOS Info.plist 与 Android Manifest 仍保留横屏声明，
  //    供 ruler 横屏使用，故不要在系统层用 screenOrientation 锁死。
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 屏幕适配初始化（flutter_screenutil_plus）：
  // 以设计稿基准尺寸 393×852 dp 包裹根组件，使各页面中 `.w/.h/.sp/.r` 响应式扩展
  // 能据此换算为当前设备的实际像素，实现多机型自适应。
  // ProviderScope 仍需位于 ToolBoxApp（ConsumerWidget）之上，故置于其内部。
  runApp(
    ScreenUtilPlusInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      child: const ProviderScope(child: ToolBoxApp()),
    ),
  );
}

/// 应用根组件。
///
/// 职责：组合主题、语言、路由三大全局能力，构建 [MaterialApp.router]。
/// 通过监听 [themeProvider] / [localeProvider] / [appRouterProvider] 三个
/// Riverpod Provider，实现「主题切换 / 语言切换 / 路由配置」的响应式刷新。
class ToolBoxApp extends ConsumerWidget {
  /// 创建应用根组件。
  const ToolBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    // 主题色方案（咖啡色 / 蓝色）：与亮暗模式正交，决定取哪套色卡。
    // 加载中（value 为 null）时回落咖啡色，保证首帧不会因色卡缺失而报错。
    final themeColor = ref.watch(themeColorProvider).value;
    final useSky = themeColor == AppThemeColor.blue;
    final lang = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);
    // 预热免费额度 Provider：让其在 App 启动期即完成「本地 ← 云端」对齐。
    // 重装后仅凭恢复会话（Keychain / Keystore 持久化）即可把云端 tool_usage_count
    // 拉回本地，无需等用户打开工具页；配合 keepAlive 与登录页收尾调用，
    // 保证「重装必定会登录」的场景下额度在登录那一刻就已同步。
    unawaited(ref.read(freeUsageProvider.future));
    // FlashlightGuard 包裹根组件，监听应用生命周期，
    // 在 App 被关闭 / 进入后台时确保手电筒（相机闪光灯）熄灭，避免常亮。
    return FlashlightGuard(
      child: MaterialApp.router(
        title: 'Tool Box',
        debugShowCheckedModeBanner: false,
        //
        // 多语言：以 Provider 中的语言码构建设备 Locale。
        locale: Locale(lang),
        // 本地化委托：App 自有文案 + Flutter 内置 Material/Widget/Cupertino 文案。
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // 语言回退策略：设备语言未命中支持列表时，统一回退英文，避免崩溃。
        localeResolutionCallback: (deviceLocale, supported) {
          if (deviceLocale == null) return const Locale('en');
          for (final locale in supported) {
            if (locale.languageCode == deviceLocale.languageCode) {
              return locale;
            }
          }
          return const Locale('en');
        },
        //
        // 主题：由两套正交状态共同决定——
        //   1) themeColorProvider 选色卡（AppTheme 咖啡色 / SkyTheme 蓝色）；
        //   2) themeProvider 决定该色卡取浅色版还是深色版（或跟随系统）。
        theme: useSky ? SkyTheme.light : AppTheme.light,
        darkTheme: useSky ? SkyTheme.dark : AppTheme.dark,
        themeMode: themeMode.value ?? ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}

/// 持有鉴权流订阅，避免被 GC 回收导致监听中断。
///
/// 订阅的生命周期与 App 进程等长，因此不需要（也不应该）在页面里 cancel。
StreamSubscription<AuthState>? _authTrackSubscription;

/// 会话级埋点观察者（app_open 热启动 / app_session_end）。
///
/// 必须是顶层变量：它被 [WidgetsBinding] 持有（不需要额外引用），
/// 但写成局部变量会在 `main()` 返回后被 GC，届时回调即失效。
final AppLifecycleTracker _appLifecycleTracker = AppLifecycleTracker();

/// 安装全局异常捕获，把崩溃信号转成 [TrackEvents.appError] 事件。
///
/// 两条通道都要装，缺一不可：
///   - [FlutterError.onError]：Flutter 框架内的异常（build / layout / paint 抛错）；
///   - [PlatformDispatcher.instance.onError]：框架外的异步异常
///     （Future / Stream 里没被 catch 的、以及原生通道抛上来的）。
///
/// 两个回调都**不吞掉原有行为**：FlutterError 先 [FlutterError.presentError]
/// 保证控制台 / 崩溃收集链路照常工作；Dispatcher 回调返回 false 表示「未处理」，
/// 让后续 handler 与系统的崩溃上报继续生效。埋点只是旁路记录，不能喧宾夺主。
void _installTrackErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    // 先执行框架默认呈现（debug 打印红屏信息，release 走原上报链）。
    FlutterError.presentError(details);
    AppTrack.error('flutter', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppTrack.error('platform', error, stack);
    // 返回 false：本 handler 只做旁路记录，不宣称「已处理」，
    // 避免屏蔽掉其他错误上报（如 Sentry / Firebase Crashlytics）。
    return false;
  };
}

/// 读取 Supabase 当前登录用户的 ID；未初始化或未登录时返回 null。
///
/// 为什么必须 try/catch：`Supabase.instance` 在未初始化时访问会抛
/// `LateInitializationError`。本工程的约定是「缺 key 就跳过初始化、App 照常启动」，
/// 所以这里必须把「不可用」表达成 null，而不是让启动链路崩掉。
String? _readSupabaseUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// 订阅 Supabase 鉴权状态变化，把用户 ID 实时同步给埋点工具。
///
/// 覆盖三种场景：
///   - **登录成功**（邮箱、Google、Apple 回调都走这里）→ `setUserId`；
///   - **退出登录 / Token 失效** → `clearUserId`，之后事件自动退回匿名 ID；
///   - **Token 自动续期** → 重复 `setUserId`（幂等，无副作用）。
///
/// 为什么不用 Riverpod 的 `authStateProvider`：埋点需要在 `runApp` **之前**就完成
/// 冷启动同步（最早的 app_open 事件必须带得上 user_id），而 Provider 树此时还没建立。
/// 这里直接订阅底层流，与 UI 层的 Provider 互不干扰（该流是 ReplaySubject 的
/// broadcast stream，支持多订阅者）。
void _subscribeAuthUserIdChanges() {
  try {
    _authTrackSubscription?.cancel();
    _authTrackSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((AuthState state) {
          // session 为空即未登录（登出 / Token 过期）；有 session 取其中的 user id。
          final String? uid = state.session?.user.id;
          if (uid == null) {
            TrackService.instance.clearUserId();
          } else {
            TrackService.instance.setUserId(uid);
          }

          // 登录 / 登出后本地 token 必须重签：
          //   登录 → 游客 token 换成用户 token；
          //   登出 → 旧用户 token 在服务端仍在 users.token 里，本地继续用就是
          //          拿已登出身份访问，必须丢弃并重新签游客 token。
          // 只在 signedIn / signedOut 时做：tokenRefreshed 等同身份事件很频繁，
          // 每次都清缓存重签会白白多打网络（token 本身 30 天才过期）。
          if (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.signedOut) {
            unawaited(AppTokenManager.refreshAfterAuthChange());
          }
        });
      } catch (_) {
    // Supabase 未初始化：跳过登录态同步，埋点退化为纯匿名统计，功能不受影响。
  }
}


