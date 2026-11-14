// 文件职责：通过 Supabase PostgREST 直写 app_events 表（开发期备选方案）。
// 所属模块：common/track/transport（埋点工具类 - 传输实现）。
// 关键依赖：dart:io（HttpClient），不依赖 supabase_flutter 的 RPC 抽象。
//
// 适用场景：
//   - 你还没部署 Edge Function；
//   - 工程里不打算引入 Edge Function 这个层级；
//   - 仅做内部 demo / 调试。
//
// 注意：
//   - 必须在 Supabase 后台执行 `grant insert on app_events to anon, authenticated;`
//     并启用 RLS policy，否则 anon 无法写入；
//   - 暴露 anon INSERT 等同于"公开 API"——务必配合 CF/Vercel 等网关限流。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../track_transport.dart';

/// PostgREST 直写传输层（备选方案）。
///
/// 行为：把每行事件 JSON 直接 POST 到 `${supabaseUrl}/rest/v1/app_events`，
/// 让 Postgres 触发插入逻辑。
///
/// 安全提示：默认建议改用 [EdgeFunctionTransport] 通过 server-side service_role
/// 写入，避免对客户端直接开放 INSERT。
class SupabaseRestTransport implements TrackTransport {
  /// Supabase 项目 URL（如 `https://<ref>.supabase.co`）。
  final String supabaseUrl;

  /// anon / publishable key。
  final String anonKey;

  /// 表名，默认 `app_events`。
  final String table;

  /// 单次 HTTP 请求超时。
  final Duration timeout;

  /// 内部共享 [HttpClient]。
  final HttpClient _httpClient;

  /// 构造一个 REST 直写传输通道。
  SupabaseRestTransport({
    required this.supabaseUrl,
    required this.anonKey,
    this.table = 'app_events',
    this.timeout = const Duration(seconds: 15),
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);

  /// 释放 HttpClient 连接池。
  void close() {
    _httpClient.close(force: false);
  }

  @override
  Future<TrackTransportResult> send(TrackBatch batch) async {
    if (supabaseUrl.isEmpty) {
      return TrackTransportResult.fail(
        'supabaseUrl 未配置',
        failureKind: 'permanent',
      );
    }

    try {
      // 这里用 regex 去尾部斜杠，避免依赖 `String.trimRight` 在不同 Dart SDK
      // 下签名变化（3.5+ 与 3.0 行为不同）。
      final String cleanBase =
          supabaseUrl.replaceAll(RegExp(r'/+$'), '');
      final String endpoint = '$cleanBase/rest/v1/$table';
      final Uri uri = Uri.parse(endpoint);

      // PostgREST 要求：传入数组形式的资源列表才能批量写入；
      // 字段名直接对应表列，所以这里 row 形态必须与表 schema 一一对应。
      // 由于 [TrackBatch.events] 内部仅含 event 字段子集，需要补足公共字段。
      // 但 [TrackBatch] 当前不包含 device / platform / appVersion，
      // 因此 REST 直写模式目前仅支持"事件原始字段"，由上层 [TrackService]
      // 在 enqueue 前调用 [TrackEvent.toSupabaseRow] 注入完整字段。
      //
      // 这里采用最简方式：直接把 batch.events 作为 rows 提交到 PostgREST。
      final List<Map<String, Object?>> rows = batch.events
          .map((e) => e.cast<String, Object?>())
          .toList();
      final String payload = jsonEncode(rows);

      final HttpClientRequest request = await _httpClient.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('apikey', anonKey);
      request.headers.set('Authorization', 'Bearer $anonKey');
      // Prefer 表示"如果冲突就替换"，正常情况下使用默认即可；
      // 关键：让 PostgREST 返回最小化响应体，避免带宽浪费。
      request.headers.set('Prefer', 'return=minimal');
      request.contentLength = payload.length;

      request.add(utf8.encode(payload));
      final HttpClientResponse response =
          await request.close().timeout(timeout);
      final String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return TrackTransportResult.ok;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return TrackTransportResult.fail(
          '鉴权失败 HTTP ${response.statusCode}: $responseBody',
          failureKind: 'auth',
        );
      }
      if (response.statusCode >= 400 && response.statusCode < 500) {
        // 4xx：可能是 RLS 拒绝、字段不匹配等，permanent 不重试
        return TrackTransportResult.fail(
          '客户端错误 HTTP ${response.statusCode}: $responseBody',
          failureKind: 'permanent',
        );
      }
      return TrackTransportResult.fail(
        '服务端错误 HTTP ${response.statusCode}: $responseBody',
      );
    } on SocketException catch (e) {
      return TrackTransportResult.fail('网络异常: ${e.message}');
    } on TimeoutException {
      return TrackTransportResult.fail('请求超时');
    } on HttpException catch (e) {
      return TrackTransportResult.fail('HTTP 异常: ${e.message}');
    } catch (e) {
      return TrackTransportResult.fail('未知异常: $e');
    }
  }
}
