// ============================================================================
// 文件：common/auth/member_bind_service.dart
// 模块：会员 · 权益上云绑定服务（common/auth）
//
// 职责：
//   封装「把买断会员权益同步到云端账号」的调用 —— 走 Supabase Edge Function
//   `bind-member`，由服务端以 service_role 写 `public.users.is_member`，
//   实现换设备 / 重装后凭账号恢复会员（方案 B · Phase 1，见
//   doc/purchase_handoff.md §9）。
//
// 为什么放 common/auth/：
//   这是「会员 + 鉴权」的交叉能力，调用方不止一处（购买页弹框、profile 手动同步），
//   抽成独立服务避免逻辑散落；且它只依赖 supabase_flutter，不依赖 UI，
//   便于测试与复用。
//
// 安全边界（Phase 1，已拍板接受）：
//   本服务**不传收据**，信任服务端对用户身份的校验（Edge Function 用调用者
//   access token 解析 uid，拒绝匿名）。伪造风险与「方案 A 纯端侧」等价，
//   不是提权。真正防伪造的收据校验属 Phase 2，届时在 Edge Function 侧加，
//   本服务只需在 body 里补收据字段。
//
// 关键依赖：
//   - supabase_flutter：functions.invoke（自动带 apikey + 当前 session 的
//     Authorization Bearer）。
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/feature/login/apple_sign_in.dart';
import 'package:tool_box/feature/login/google_sign_in_native.dart';

/// bind 调用的结果分类。
enum MemberBindResult {
  /// 已成功把权益写入云端（users.is_member = true）。
  ok,

  /// 当前未登录，无法绑定（调用方应引导登录，而不是报错）。
  needLogin,

  /// 已发起但服务端返回失败（网络 / 服务端错误 / 鉴权失效等）。
  failed,
}

/// 会员权益上云绑定服务。
///
/// 用法：
/// ```dart
/// final result = await MemberBindService.bind();
/// // result == MemberBindResult.ok        → 绑定成功，invalidate 资料即可
/// // result == MemberBindResult.needLogin → 引导登录
/// // result == MemberBindResult.failed    → 提示失败（可重试）
/// ```
class MemberBindService {
  MemberBindService._();

  /// 把当前登录用户的会员权益同步到云端。
  ///
  /// [source] 只用于埋点区分触发来源（auto / purchase_prompt / profile /
  /// login_after_buy / restore），不影响业务分支。
  /// 其中 `restore` 是 2026-10-01 新增：用户主动「恢复购买」命中后上云，
  /// 绑过一次之后换设备一键登录即会员，不必再点恢复。
  ///
  /// 返回 [MemberBindResult]，不抛异常——调用方按枚举分支给 UI 反馈。
  /// 埋点 [TrackEvents.vipBind] 在这里统一上报：三个调用点都走本方法，
  /// 收口在一处才不会漏记某一路。
  static Future<MemberBindResult> bind({String source = 'auto'}) async {
    final MemberBindResult result = await _doBind();
    AppTrack.log(
      TrackEvents.vipBind,
      params: <String, Object?>{'source': source, 'result': result.name},
    );
    return result;
  }

  /// 实际执行绑定（不含埋点），见 [bind]。
  static Future<MemberBindResult> _doBind() async {
    try {
      // 前置：无 session 直接判 needLogin，不发请求。
      // functions.invoke 需要当前 session 的 access token 作为 Authorization，
      // 未登录时拿不到，服务端也会 401，这里提前短路更省一次网络往返。
      if (Supabase.instance.client.auth.currentUser == null) {
        return MemberBindResult.needLogin;
      }

      // functions.invoke 会自动带上 apikey 与 Authorization Bearer；
      // Phase 1 body 为空对象（Phase 2 在此补 transactionId / purchaseToken）。
      // 显式传 `{}` 而不是留空：留空时请求体为空串，服务端解析行为依赖实现，
      // 传空对象更明确（服务端也已兼容空 body，双保险）。
      final FunctionResponse resp = await Supabase.instance.client.functions
          .invoke('bind-member', body: <String, dynamic>{});

      // 服务端约定：200 且 body 含 ok=true 才算成功；其余状态码/结构视为失败。
      // FunctionResponse.data 在 2xx 时是解析后的 Map（若 body 非 JSON 则为 null）。
      final dynamic data = resp.data;
      final bool ok = resp.status == 200 &&
          data is Map &&
          data['ok'] == true;
      return ok ? MemberBindResult.ok : MemberBindResult.failed;
    } catch (_) {
      // 网络异常 / Supabase 未初始化 / 服务端 5xx 都归为 failed，交由 UI 重试。
      // 不吞掉 rethrow 是为了让调用方统一收口，这里只需给出确定分类。
      return MemberBindResult.failed;
    }
  }

  /// 当前平台一键登录 + 权益上云绑定（「未登录购买后强制建号」统一收口）。
  ///
  /// 按平台二选一（与登录页 / 同步对话框同一口径：苹果设备只给 Apple，
  /// 其余只给 Google），授权完成后立刻把买断权益写到 `users.is_member`，
  /// 实现"买完即建号、换设备凭账号恢复"。
  ///
  /// 返回值语义与 [bind] 一致：
  /// - [MemberBindResult.ok]：授权成功且已上云；
  /// - [MemberBindResult.needLogin]：用户取消授权 / OAuth 回退未同步完成（调用方
  ///   应保留本机权益、下次再提示，而非报错）；
  /// - [MemberBindResult.failed]：授权或上云抛异常（网络 / 配置问题）。
  ///
  /// 注意：Apple 在**模拟器**走原生 `getAppleIDCredential` 不稳，[AppleSignIn.signIn]
  /// 会自动回退 OAuth 浏览器流程并返回 [AppleSignInOutcome.pending]——此情形下
  /// session 尚未就绪，本方法返回 needLogin，真正的建号由 `onAuthStateChange`
  /// 命中后（[MembershipController] 的登录监听）另行绑定，不会漏。
  static Future<MemberBindResult> signInAndBind({
    String source = 'purchase_prompt',
  }) async {
    try {
      final bool authorized;
      if (AppleSignIn.isNativeSupported) {
        // iOS / macOS：原生 Apple 授权（completed = session 已就绪）；
        // cancelled / pending（OAuth 回退）一律视作 needLogin，交由登录监听兜底。
        final AppleSignInOutcome outcome = await AppleSignIn.signIn();
        authorized = outcome == AppleSignInOutcome.completed;
      } else {
        // Android / 其他：原生 Google 授权，true = 已建 session。
        authorized = await NativeGoogleSignIn.signInAndExchange();
      }
      if (!authorized) return MemberBindResult.needLogin;
      // 授权成功 → 复用统一上云逻辑（内部已校验登录态）。
      return await _doBind();
    } catch (_) {
      return MemberBindResult.failed;
    }
  }
}
