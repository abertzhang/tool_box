// ============================================================================
// 文件：feature/login/google_sign_in_native.dart
// 模块：登录（login）
//
// 职责：
//   把「Google 一键登录 / 注册」从旧版「Supabase OAuth 浏览器跳转」改为原生
//   [google_sign_in] 插件流程，统一封装、供登录页与注册页共用。
//
// 为什么改成原生：
//   旧流程调 Supabase.auth.signInWithOAuth 会拉起系统浏览器 / Chrome Custom Tab，
//   授权完再经 deep link 跳回 App，体验割裂（App 被切到后台、回来还要等回调）。
//   原生 google_sign_in 在 Android 上弹系统账号选择器、iOS 上弹系统 Google 面板，
//   全程不离开 App，授权完在本地直接拿到 idToken + accessToken。
//
// 与 Supabase 的衔接：
//   原生 Google 只给「Google 侧」的令牌，真正建号 / 登录仍是 Supabase 负责 ——
//   我们拿着 idToken + accessToken 调 Supabase.auth.signInWithIdToken，
//   由 Supabase 校验并落 session。首次用同一 Google 账号即自动建号（注册=登录合一）。
//
// 关键依赖：
//   - google_sign_in：原生授权，拿 Google 令牌。
//   - supabase_flutter：signInWithIdToken 用 Google 令牌换 Supabase session。
//   - app_env：Google 客户端 ID 常量（见 AppEnv.googleIosClientId / AppEnv.googleWebClientId）。
// ============================================================================

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_env.dart';

/// 原生 Google 登录封装。
///
/// 单例持有 [GoogleSignIn] 实例，避免每次点击都重建导致授权状态错乱。
/// 登录页与注册页都调 [signInAndExchange]，收尾（跳转 / 埋点）仍由各自的
/// `onAuthStateChange` 监听统一处理，与密码 / Apple 路径保持一致。
class NativeGoogleSignIn {
  /// 私有构造，禁止实例化。
  NativeGoogleSignIn._();

  /// 单例的 GoogleSignIn 实例。
  ///
  /// - iOS：传 [AppEnv.googleIosClientId]（iOS 客户端 ID）；留空则回退读取
  ///   `ios/Runner/GoogleService-Info.plist` 的 `CLIENT_ID`。
  /// - serverClientId：传 [AppEnv.googleWebClientId]（Web 客户端 ID），用于换取
  ///   Supabase 可校验的 accessToken；Android 端同样依赖它拿到服务端令牌。
  ///   两者均留空时，[signInAndExchange] 会因缺 accessToken 而抛错（见下）。
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AppEnv.googleIosClientId.isNotEmpty ? AppEnv.googleIosClientId : null,
    serverClientId:
        AppEnv.googleWebClientId.isNotEmpty ? AppEnv.googleWebClientId : null,
  );

  /// 拉起原生 Google 授权并用 Supabase 交换 session。
  ///
  /// 返回 `true` 表示授权成功且已建立 Supabase session；
  /// 返回 `false` 表示用户主动取消（不算失败，调用方应静默恢复按钮）。
  ///
  /// 其余情况会直接抛出：
  /// - 配置缺失 / 网络错误（google_sign_in 抛 [PlatformException]）；
  /// - Google 未返回 idToken / accessToken（如 AppEnv.googleWebClientId 未配）；
  /// - Supabase 校验失败（抛 [AuthException]）。
  /// 调用方负责捕获并对真实错误上报埋点 + 红条提示。
  static Future<bool> signInAndExchange() async {
    // 拉起系统级授权面板；用户点「取消」时返回 null，视为放弃、不算失败。
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return false;

    // 取 Google 侧令牌：idToken 用于 Supabase 身份校验，accessToken 用于服务端校验。
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final String? idToken = googleAuth.idToken;
    final String? accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('Google 授权未返回 idToken（请检查 Google Cloud 客户端配置）');
    }
    if (accessToken == null) {
      throw Exception(
        'Google 授权未返回 accessToken（请在 AppEnv 配置 googleWebClientId）',
      );
    }

    // 用 Google 令牌换 Supabase session。成功后 Supabase 会派发 onAuthStateChange，
    // 由页面监听统一收尾跳转，这里不主动导航，避免重复触发。
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return true;
  }
}
