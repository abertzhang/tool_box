// ============================================================================
// 文件：common/auth/account_delete_service.dart
// 模块：账号 · 自助注销（删除账号）客户端服务（common/auth）
//
// 职责：
//   封装「注销当前登录账号」的调用 —— 走 Supabase Edge Function `delete-account`，
//   由服务端以 service_role 调 Admin API 删除用户（public.users 行 + auth.users），
//   实现彻底注销。客户端（supabase_flutter）没有「删除当前用户」的 API，
//   必须借服务端能力，故单独成服务。
//
// 为什么放 common/auth/：
//   与 [MemberBindService] 同属「账号 + 服务端网关」交叉能力，调用方不止一处
//   （账号安全页），抽成独立服务避免逻辑散落；且只依赖 supabase_flutter，不依赖 UI。
//
// 安全边界：
//   本服务不传任何目标 uid —— 服务端一律以「调用者本人 token」解析出的 uid 为准，
//   客户端无法指定删除他人。
//
// 关键依赖：
//   - supabase_flutter：functions.invoke（自动带 apikey + 当前 session 的
//     Authorization Bearer）。
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';

/// 注销调用的结果分类。
enum DeleteAccountResult {
  /// 已成功删除账号（服务端返回 ok=true）。
  ok,

  /// 当前未登录，无法注销（调用方应引导登录，而不是报错）。
  needLogin,

  /// 已发起但服务端返回失败（网络 / 服务端错误 / 鉴权失效等）。
  failed,
}

/// 账号注销服务。
///
/// 用法：
/// ```dart
/// final result = await AccountDeleteService.delete();
/// // result == DeleteAccountResult.ok        → 注销成功
/// // result == DeleteAccountResult.needLogin → 引导登录
/// // result == DeleteAccountResult.failed    → 提示失败（可重试）
/// ```
class AccountDeleteService {
  AccountDeleteService._();

  /// 注销当前登录用户。
  ///
  /// 返回 [DeleteAccountResult]，不抛异常——调用方按枚举分支给 UI 反馈。
  /// 埋点 [TrackEvents.authDeleteAccount] 在这里统一上报（成功/失败都记，
  /// 用于与登录量对照算账号流失率）。
  static Future<DeleteAccountResult> delete() async {
    final DeleteAccountResult result = await _doDelete();
    AppTrack.log(
      TrackEvents.authDeleteAccount,
      params: <String, Object?>{'result': result.name},
    );
    return result;
  }

  /// 实际执行注销（不含埋点），见 [delete]。
  static Future<DeleteAccountResult> _doDelete() async {
    try {
      // 前置：无 session 直接判 needLogin，不发请求。
      // functions.invoke 需要当前 session 的 access token 作为 Authorization，
      // 未登录时拿不到，服务端也会 401，这里提前短路更省一次网络往返。
      if (Supabase.instance.client.auth.currentUser == null) {
        return DeleteAccountResult.needLogin;
      }

      // functions.invoke 自动带 apikey 与 Authorization Bearer（用户 token）；
      // 显式传 `{}` 而不是留空，避免服务端把空串当非法 JSON 误判（见 Edge Function 容错约定）。
      final FunctionResponse resp = await Supabase.instance.client.functions
          .invoke('delete-account', body: <String, dynamic>{});

      // 服务端约定：200 且 body 含 ok=true 才算成功；其余状态码/结构视为失败。
      final dynamic data = resp.data;
      final bool ok = resp.status == 200 &&
          data is Map &&
          data['ok'] == true;
      return ok ? DeleteAccountResult.ok : DeleteAccountResult.failed;
    } catch (_) {
      // 网络异常 / Supabase 未初始化 / 服务端 5xx 都归为 failed，交由 UI 重试。
      return DeleteAccountResult.failed;
    }
  }
}
