// 文件职责：读取编译期注入的环境变量，提供运行环境标识与调试开关。
//
// 所属模块：config（应用配置层）。
// 关键依赖：Dart 编译期常量 String.fromEnvironment / bool.fromEnvironment，
// 对应 flutter run/build 时通过 --dart-define=KEY=VALUE 传入的参数。
//
// 注意：这些值是编译期常量，运行时不可更改；默认值用于本地未传参时的兜底。

// 读取运行或打包命令行中的指定参数
class AppEnv {
  /// 当前运行环境：dev / uat / prd，默认 dev。
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');
  /// Supabase 项目地址（形如 `https://项目ref.supabase.co`）。
  ///
  /// 由 `--dart-define=SUPABASE_URL=...` 注入；为空时交由 base_url.dart 的
  /// AppUrl.supabase 兜底，保证「没配也能启动，用到时再提示」。
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Supabase 匿名公钥（anon key），由 `--dart-define=SUPABASE_ANON_KEY=...` 注入。
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  /// 埋点 Edge Function 网关地址。
  ///
  /// 由 `--dart-define=TRACK_EDGE_URL=...` 注入；未注入时回落到默认的
  /// `tool_box` 项目线上函数地址（该地址本身不是机密，安全性由 clientToken 保障），
  /// 避免"忘了传参 → URL 为空 → 上报直接失败"这类静默故障。
  static const String trackEdgeUrl = String.fromEnvironment(
    'TRACK_EDGE_URL',
    defaultValue: 'https://nfoishlluynelazgwduc.supabase.co'
        '/functions/v1/track-event',
  );

  /// 埋点业务令牌，与 Edge Function 的 `CLIENT_TOKEN` secret 一致。
  ///
  /// 由 `--dart-define=TRACK_CLIENT_TOKEN=...` 注入。
  /// 这里保留一个**开发期兜底值**：与 tool_box 项目 Edge Function 的 `CLIENT_TOKEN` 一致，
  /// 目的是让「直接在模拟器运行」即可验证埋点上报，无需每次手动传参。
  /// ⚠️ 该令牌仅为次级防护（真正安全边界是 `ALLOWED_APP_IDS` 白名单 + 表级 RLS），
  /// 生产构建务必通过 `--dart-define=TRACK_CLIENT_TOKEN=<生产令牌>` 覆盖本值。
  static const String trackClientToken = String.fromEnvironment(
    'TRACK_CLIENT_TOKEN',
    defaultValue: '6b0ec6adb84d32819107549a20d24f813cbeeebd',
  );

  // --------------------------------------------------------------------------
  // 第三方登录（OAuth）配置
  // --------------------------------------------------------------------------
  /// OAuth 回调地址（deep link）。
  ///
  /// 系统浏览器 / ASWebAuthenticationSession 完成第三方授权后，由 Supabase 携带 token
  /// 跳回本 App 的地址。scheme 须与两端原生配置逐字符一致（AndroidManifest 的
  /// intent-filter、Info.plist 的 CFBundleURLSchemes、Supabase 控制台 Redirect URLs
  /// 共四处）。目前仅服务于 Apple 在「非 iOS / macOS」平台上的 OAuth 回退分支
  /// （Google 已改用 google_sign_in 原生流程，不经过此回调）。
  ///
  /// 由 `--dart-define=OAUTH_REDIRECT_URL=...` 覆盖；默认即包名 `uk.aknot.toolbox` 对应 scheme。
  static const String oauthRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: 'uk.aknot.toolbox://login-callback',
  );

  /// Google 原生登录（google_sign_in 插件）所需的 iOS 类型 OAuth 客户端 ID。
  ///
  /// 形如 `xxx.apps.googleusercontent.com`，在 Google Cloud Console → APIs & Services
  /// → Credentials 创建（应用类型 = iOS，并绑定 Bundle ID `uk.aknot.toolbox`）。
  /// 留空则 iOS 端回退读取 `ios/Runner/GoogleService-Info.plist` 的 `CLIENT_ID`。
  /// 当前 iOS 走 Apple 登录，此值非必需；仅在 iOS 也提供 Google 按钮时才须填。
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Google 原生登录的 Web 类型客户端 ID，作为 `serverClientId` 用于换取
  /// Supabase 可校验的 accessToken；Android 端同样依赖它拿到服务端令牌。
  ///
  /// 值来自 Google Cloud Console → APIs & Services → Credentials 的
  /// 「OAuth 2.0 客户端 ID（类型 = Web 应用）」，对应 Firebase 项目 `toolbox-9453d`。
  /// Supabase 控制台 Authentication → Providers → Google 须填**同一个** Client ID +
  /// Secret，否则服务端校验不过。Android 登录链路成功的前提。
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1057559698452-5l4ak28d9t0hsq4kv7hljhjr6t92s5tr.apps.googleusercontent.com',
  );

  // static const String apiBase = String.fromEnvironment('API_BASE');
  /// 是否开启调试日志，由 `--dart-define=ENABLE_DEBUG_LOG=true` 控制。
  static const bool isDebug = bool.fromEnvironment('ENABLE_DEBUG_LOG');

  /// 是否为开发环境。
  static bool get isDev => env == 'dev';

  /// 是否为测试（UAT）环境。
  static bool get isUat => env == 'uat';

  /// 是否为生产环境。
  static bool get isPrd => env == 'prd';
}
