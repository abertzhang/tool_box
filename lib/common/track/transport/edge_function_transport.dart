// 文件职责：通过 Supabase Edge Function 网关上报埋点。
// 所属模块：common/track/transport（埋点工具类 - 传输实现）。
// 关键依赖：dart:io（HttpClient），无第三方包依赖——保证跨工程零成本复用。
//
// 接口约定（与 supabase/functions/track-event/index.ts 对齐）：
//   URL：{edgeFunctionUrl}
//   Method：POST
//   Headers:
//     - Content-Type: application/json
//     - apikey: {supabase anon key}（PostgREST/Edge Function 标准要求）
//     - Authorization: Bearer {anon key}（同上）
//     - X-Client-Token: {clientToken}（可选，Edge Function 业务校验）
//   Body: { "app_id": "...", "events": [ ... ] }
//
// 返回值：
//   - HTTP 2xx → success
//   - HTTP 4xx → permanent（4xx 数据格式问题），不重试
//   - HTTP 5xx / 网络异常 → transient，可入队重试

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../track_transport.dart';

/// 默认上报通道：Supabase Edge Function 网关（推荐生产路径）。
///
/// 通过 [EdgeFunctionTransport] 发送事件到 [TrackConfig.edgeFunctionUrl]，
/// 由后端函数负责鉴权、限流、写入 `app_events` 表。
///
/// 鉴权机制：
///   - Edge Function 部署后默认需要 `apikey` 或 `Authorization` 头（即 anon key）；
///   - [clientToken] 作为业务层额外标识，Edge Function 可按需校验。
class EdgeFunctionTransport implements TrackTransport {
  /// Edge Function 完整 URL（如 `https://<ref>.supabase.co/functions/v1/track-event`）。
  final String url;

  /// Supabase anon/publishable key。
  final String anonKey;

  /// 业务层令牌（可选）。Edge Function 收到后会在白名单中校验。
  final String? clientToken;

  /// 单次 HTTP 请求超时（默认 15 秒）。
  final Duration timeout;

  /// 内部共享的 [HttpClient]，连接池复用。
  final HttpClient _httpClient;

  /// 创建一个 Edge Function 上报通道。
  EdgeFunctionTransport({
    required this.url,
    required this.anonKey,
    this.clientToken,
    this.timeout = const Duration(seconds: 15),
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);

  /// 释放底层 [HttpClient] 连接池。一般在 [TrackService.dispose] 时调用。
  void close() {
    _httpClient.close(force: false);
  }

  @override
  Future<TrackTransportResult> send(TrackBatch batch) async {
    // 边界检查：URL 为空直接视为配置错——避免启动期就把人卡住。
    if (url.isEmpty) {
      return TrackTransportResult.fail(
        'edgeFunctionUrl 未配置',
        failureKind: 'permanent',
      );
    }

    try {
      // 1. 序列化请求体
      final Map<String, Object?> body = <String, Object?>{
        'app_id': batch.appId,
        'events': batch.events,
      };
      final String payload = jsonEncode(body);

      // 2. 构造请求
      final Uri uri = Uri.parse(url);
      final HttpClientRequest request = await _httpClient.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('apikey', anonKey);
      request.headers.set('Authorization', 'Bearer $anonKey');
      if (clientToken != null && clientToken!.isNotEmpty) {
        request.headers.set('X-Client-Token', clientToken!);
      }
      request.contentLength = payload.length;
      request.headers.set(HttpHeaders.contentLengthHeader, payload.length);

      // 3. 写入并读取响应
      request.add(utf8.encode(payload));
      final HttpClientResponse response =
          await request.close().timeout(timeout);

      // 4. 读取响应体（即使非 2xx 也读，便于错误诊断）
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
        return TrackTransportResult.fail(
          '客户端错误 HTTP ${response.statusCode}: $responseBody',
          failureKind: 'permanent',
        );
      }
      // 5xx 一律按 transient 处理，可重试
      return TrackTransportResult.fail(
        '服务端错误 HTTP ${response.statusCode}: $responseBody',
      );
    } on SocketException catch (e) {
      // 网络层错误（无网 / DNS / 超时等）一律 transient
      return TrackTransportResult.fail('网络异常: ${e.message}');
    } on TimeoutException {
      return TrackTransportResult.fail('请求超时');
    } on HttpException catch (e) {
      return TrackTransportResult.fail('HTTP 异常: ${e.message}');
    } catch (e) {
      // 兜底：任何未预期的异常按 transient 处理（不丢事件）
      return TrackTransportResult.fail('未知异常: $e');
    }
  }
}
