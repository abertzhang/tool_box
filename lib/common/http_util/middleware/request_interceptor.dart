// 文件职责：Dio 请求拦截器，在请求发出前统一注入鉴权头，
// 并预留统一的请求日志打印入口。
//
// 所属模块：common/http_util/middleware（网络拦截器层）。
// 关键依赖：dio 的 Interceptor 体系，以及 Supabase 登录会话（真实 token 来源）。
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 在请求发出前注入 Authorization 头，并预留请求日志打印点。
class RequestInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 本 App 唯一的真实鉴权来源是 Supabase 登录会话：
    // 登录态下，会话（含 accessToken / refreshToken）由 Supabase 持久化在本地安全存储，
    // 等价于"真实 token 存储"，无需再额外引入 shared_preferences / secure storage。
    // 直接取 currentSession.accessToken 作为 Bearer 令牌注入即可。
    //
    // 兜底：若 Supabase 尚未初始化（理论上 http_util 不会在此之前被调用），
    // 静默跳过，不注入 Authorization，避免抛异常导致请求失败。
    String? token;
    try {
      token = Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      token = null;
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // 可在这里统一打印请求日志
    // print("请求url:${options.uri}");
    handler.next(options);
  }
}
