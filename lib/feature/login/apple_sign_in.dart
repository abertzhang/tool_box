// ============================================================================
// 文件：feature/login/apple_sign_in.dart
// 模块：登录（login）
//
// 职责：
//   封装「Apple 一键登录」的平台差异，向上暴露统一入口，供注册页与登录页共用。
//
// 为什么必须分两条路径：
//   Apple 只为 iOS / macOS 提供了原生 SDK（系统授权弹窗、Face ID、钥匙串凭据）。
//   Android 上没有原生 SDK —— sign_in_with_apple 插件在 Android 上实际是
//   Chrome Custom Tab 网页流程，并且要求自建服务端接收 Apple 回调再中转回 App，
//   成本远高于收益。所以策略是：
//     - Apple 平台 → 原生弹窗（体验最好）
//     - 其他平台  → 继续走 Supabase OAuth 浏览器流程
//
// 两条路径的语义完全不同，调用方必须能区分：
//   - 原生：await 返回时 session 已经就绪，可以立刻跳转首页；
//   - OAuth：只是拉起浏览器，结果要等 deep link 回来后由 onAuthStateChange 送达，
//     本函数返回时还没有 session，此时跳转是错的。
//   所以这里返回 [AppleSignInOutcome] 而不是 AuthResponse —— 用类型把差异说清楚，
//   避免调用方误以为拿到返回值就等于登录完成。
//
// nonce 机制（原生路径最容易出错的地方，弄反会登录失败且没有明确报错）：
//   1. generateRawNonce() 生成原始随机串 rawNonce；
//   2. sha256(rawNonce) 得到 hashedNonce，把这个哈希值传给 **Apple**；
//   3. 未哈希的 rawNonce 传给 **Supabase**，由它自行哈希后与 idToken 里的
//      nonce 声明比对。
//   两者传反会导致 Supabase 校验不通过，而错误信息不会指出是 nonce 的问题。
//
// Supabase 控制台配置要求（原生路径）：
//   Authentication → Providers → Apple → Client IDs 里必须包含 **App ID（bundle id）**。
//   注意原生路径不需要 Services ID / Team ID / .p8 —— 那些只服务于 OAuth 流程。
//   但本工程 Android 仍走 OAuth，所以那些配置依然要保留。
//
// 关键依赖：
//   - sign_in_with_apple：Apple 平台的原生授权弹窗
//   - supabase_flutter：signInWithIdToken / signInWithOAuth / generateRawNonce
//   - crypto：sha256（Apple 要求 nonce 以哈希形式传入）
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_env.dart';

/// Apple 登录的执行结果，用于区分「已完成」与「仍在进行中」。
enum AppleSignInOutcome {
  /// 原生登录已完成，session 立即可用，调用方可以直接跳转。
  completed,

  /// 已拉起 OAuth 浏览器流程，结果会通过 onAuthStateChange 异步送达；
  /// 调用方此时不应跳转，也不要弹出错误提示。
  pending,

  /// 用户主动取消了授权（不算错误，通常静默处理）。
  cancelled,
}

/// Apple 一键登录的平台适配层。
class AppleSignIn {
  AppleSignIn._();

  /// 当前平台是否支持 Apple 原生登录。
  ///
  /// 只有 iOS 与 macOS 能走原生；Android 与桌面其他平台一律回退 OAuth。
  static bool get isNativeSupported => Platform.isIOS || Platform.isMacOS;

  /// 执行 Apple 登录，自动选择原生或 OAuth 路径。
  ///
  /// 策略（2026-11-07 修正）：
  ///   Apple 平台**先试原生**（系统级授权面板，真机体验最佳、不跳出 App）。
  ///   但原生 `getAppleIDCredential` 在 iOS 模拟器上极不稳定——模拟器没有真正的
  ///   Secure Enclave / 钥匙串，即便已在 Simulator「设置」里登录了 Apple ID，
  ///   授权请求也常直接返回 failed / unknown，表现为「点了没反应 / 转圈」。
  ///   因此一旦原生路径失败（授权面板失败，或拿到的 token 被 Supabase 拒），
  ///   **自动回退到 Supabase OAuth**（底层 ASWebAuthenticationSession，
  ///   模拟器与真机都可用），保证能在模拟器上验证完整登录流程。
  ///
  ///   用户主动取消（canceled）不会触发回退——那是正常操作，直接返回 cancelled。
  ///
  /// 抛出的是 [_AppleSignInException] / Supabase 原始异常，由调用方转译提示。
  static Future<AppleSignInOutcome> signIn() async {
    if (!isNativeSupported) {
      // 非苹果平台（Android 等）无原生 SDK，直接走 OAuth。
      return _signInOAuth();
    }
    try {
      return await _signInNative();
    } on _AppleSignInException {
      // 原生授权失败（模拟器未登录 / 不支持 / 超时）→ 回退 OAuth 网页流程。
      return await _signInOAuth();
    } on AuthException {
      // 原生拿到 token 但 Supabase 校验失败（如 bundle id 未加入 Apple provider
      // 的 Client IDs）→ 同样回退 OAuth（OAuth 用 Services ID，绕开该限制）。
      return await _signInOAuth();
    }
  }

  /// Apple 平台原生登录：系统弹窗 → 拿 identityToken → 交给 Supabase 校验。
  static Future<AppleSignInOutcome> _signInNative() async {
    final SupabaseClient client = Supabase.instance.client;

    // nonce 一分为二：哈希值给 Apple，原始值留给 Supabase 校验。
    final String rawNonce = _generateRawNonce();
    final String hashedNonce =
        sha256.convert(utf8.encode(rawNonce)).toString();

    // —— 第一步：向 Apple 索取 identityToken（系统级授权弹窗） ——
    // 这一步只要失败，几乎一定是「设备 / 模拟器层面的 Apple ID 问题」，与 Supabase 无关，
    // 因此单独捕获并翻译成用户可读、可操作的提示，避免把底层英文 PlatformException
    // 原话直接丢给用户（表现为「点了没反应 / 看不懂」）。
    //
    // ⚠️ 模拟器特别坑：iOS 模拟器默认没有登录 Apple ID，原生 Apple 授权要么弹不出面板、
    // 要么直接失败，且在某些场景下 getAppleIDCredential 会一直不返回（按钮卡死转圈）。
    // 这里加 60s 超时 + 明确提示，把「卡死」变成「可理解的失败」。
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      ).timeout(const Duration(seconds: 60));
    } on SignInWithAppleAuthorizationException catch (e) {
      // 用户主动取消：这是正常操作，不该当成错误上报或弹红条。
      if (e.code == AuthorizationErrorCode.canceled) {
        return AppleSignInOutcome.cancelled;
      }
      // 其余授权错误（unknown / failed / invalidResponse 等）：设备未登录 Apple ID、
      // 网络不通、Apple 服务暂不可用等。统一翻译成可操作提示。
      throw _AppleSignInException(
        'Apple 登录失败（${e.code.name}）。请确认已在设备的「设置」中登录 Apple ID，'
        '并允许本 App 使用；模拟器需在 Simulator 的「设置」里登录 Apple ID 后才能使用 Apple 登录。'
        '若仍无法使用，可改用下方的「邮箱登录」入口。',
      );
    } on TimeoutException {
      // 原生调用迟迟不返回（典型为模拟器未登录 Apple ID / Apple 服务无响应）。
      throw const _AppleSignInException(
        'Apple 登录超时：请确认设备已联网，且已在「设置」中登录 Apple ID 后重试。'
        '（模拟器必须在 Simulator 的「设置」里登录 Apple ID，否则 Apple 登录无法使用。）',
      );
    } on PlatformException catch (e) {
      // sign_in_with_apple 在部分失败路径（尤其模拟器未登录）抛的是 PlatformException，
      // 而非 SignInWithAppleAuthorizationException，这里一并兜住。
      throw _AppleSignInException(
        'Apple 登录失败：${e.message ?? "设备未登录 Apple ID 或 Apple 服务暂不可用"}。'
        '请在「设置」中登录 Apple ID 后重试，或改用「邮箱登录」入口。',
      );
    } catch (e) {
      throw _AppleSignInException('Apple 登录失败：$e');
    }

    // —— 第二步：把 identityToken 交给 Supabase 校验 ——
    // 这一步的错误（如 Apple provider 未配置 / bundle id 不匹配）由 Supabase 给出，
    // 信息对排查有意义，保留原样抛出，不再二次翻译。
    final String? idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Apple 未返回 identityToken，无法完成登录。',
      );
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // 姓名只在首次授权返回，后续登录均为 null，所以拿到就要立刻存下来。
    await _persistNameIfPresent(credential);

    return AppleSignInOutcome.completed;
  }

  /// 非 Apple 平台 / 原生失败回退：走 Supabase 托管的 OAuth 浏览器流程。
  ///
  /// 底层是 ASWebAuthenticationSession（iOS）/ 系统浏览器（Android），
  /// **不依赖模拟器的原生 Apple 授权框架**，因此模拟器也能正常完成 Apple 登录。
  /// 这里只负责拉起授权，成败由 deep link 回调决定，故返回
  /// [AppleSignInOutcome.pending]，真正的收尾交给登录页的 onAuthStateChange 监听。
  static Future<AppleSignInOutcome> _signInOAuth() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: AppEnv.oauthRedirectUrl,
      );
    } on AuthException catch (e) {
      // OAuth 路径的错误几乎都指向 Supabase 后台配置：Apple provider 未启用、
      // Services ID / Team ID / .p8 未填、或 Redirect URLs 未加入本 App 的回跳地址。
      // 这些信息对排查有意义，翻译成可读提示并附上回跳地址，原样抛出。
      throw _AppleSignInException(
        'Apple 网页登录启动失败：${e.message}。'
        '请检查 Supabase 控制台 Authentication → Providers → Apple 是否已启用，'
        '且 Redirect URLs 包含「${AppEnv.oauthRedirectUrl}」'
        '（Apple provider 需配 Services ID + Key ID + .p8 私钥，而非仅原生 bundle id）。',
      );
    }
    return AppleSignInOutcome.pending;
  }

  /// 生成原始 nonce（未哈希）。
  ///
  /// 这里不能照抄官方示例的 `supabase.auth.generateRawNonce()` ——
  /// 在 supabase_flutter 2.17.2 里 `SupabaseAuth` 被 `export ... hide SupabaseAuth`
  /// 隐藏了，外部根本访问不到，那行代码会直接编译失败（官方示例尚未同步更新）。
  /// 因此按包内源码的算法原样实现：16 字节安全随机数 → base64url 编码。
  static String _generateRawNonce() {
    final Random random = Random.secure();
    final List<int> bytes =
        List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// 把 Apple 首次授权返回的姓名写入用户元数据。
  ///
  /// 失败不影响登录结果 —— 姓名只是锦上添花，不该拖垮主流程，所以吞掉异常。
  static Future<void> _persistNameIfPresent(
    AuthorizationCredentialAppleID credential,
  ) async {
    final String? givenName = credential.givenName;
    final String? familyName = credential.familyName;
    if (givenName == null && familyName == null) {
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: <String, String?>{
            'full_name': <String>[
              ?givenName,
              ?familyName,
            ].join(' '),
            'given_name': givenName,
            'family_name': familyName,
          },
        ),
      );
    } catch (_) {
      // 姓名写入失败不阻断登录，静默忽略。
    }
  }
}

/// Apple 原生授权失败的可读异常。
///
/// [toString] 直接返回中文提示，供登录页 SnackBar 原样展示，
/// 避免出现 "Exception: ..." 前缀或底层英文 PlatformException 原话，
/// 让「Apple 登录用不了」转化为「明确知道为什么、该怎么做」。
class _AppleSignInException implements Exception {
  const _AppleSignInException(this.message);

  final String message;

  @override
  String toString() => message;
}
