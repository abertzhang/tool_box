// 文件职责：埋点事件批量调度器。
// 所属模块：common/track/batcher（埋点工具类 - 调度器子模块）。
// 关键依赖：
//   - queue/track_queue 持久化层；
//   - track_transport 上报通道。
//
// 触发策略：
//   1. 队列累计达到 [TrackConfig.flushThreshold] 条，立即 flush；
//   2. 定时器按 [TrackConfig.flushInterval] 周期 flush；
//   3. App 进入 paused 状态时，由 [TrackService.dispose] 显式触发 flush，
//      保证退出前已上传。
//
// 行格式：队列中存储的是"已填好公共字段的完整 row"——即 [TrackEvent.toSupabaseRow]
// 的产物，batcher 不再做字段补全，直接交给 transport。

import 'dart:async';

import '../queue/track_queue.dart';
import '../track_config.dart';
import '../track_transport.dart';

/// 批量上报调度器（与 [TrackService] 同生命周期）。
///
/// 内部维护一个 Timer，flush 流程为「取批量 → 上传 → 成功删 → 失败保留」。
/// 串行执行：flush 期间不会再触发第二次，避免重入。
class TrackBatcher {
  /// 队列引用。
  final TrackQueue queue;

  /// 上报通道。
  final TrackTransport transport;

  /// 运行时配置（init 时固定，运行期 [TrackService.updateConfig] 重新构造）。
  final TrackConfig config;

  /// 应用 id 的快照（避免每批都传整个 config）。
  final String _appId;

  /// 客户端令牌（Edge Function 模式下用于轻量身份校验，REST 直写模式忽略）。
  final String? _clientToken;

  /// 定时刷新 Timer。
  Timer? _timer;

  /// 当前是否正在 flush（互斥锁，防止重入）。
  bool _flushing = false;

  /// 构造一个调度器。构造时不会启动 Timer，[TrackService.init] 调用 [start]。
  ///
  /// 注意：参数命名 [appId] / [clientToken] 与字段 `_appId` / `_clientToken` 区分——
  /// 这是有意为之，让外部传参名不带下划线，干净；下方 ignore 关闭 linter 建议。
  TrackBatcher({
    required this.queue,
    required this.transport,
    required this.config,
    required String appId,
    String? clientToken,
    // ignore: prefer_initializing_formals
  })  : _appId = appId,
        // ignore: prefer_initializing_formals
        _clientToken = clientToken;

  /// 启动定时刷新。
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(config.flushInterval, (_) {
      // 周期 flush；fire-and-forget，由内部互斥锁防止重入。
      flush();
    });
  }

  /// 停止定时器。刷新流程继续进行，但不会再因定时器触发。
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 主动触发一次 flush。
  ///
  /// 返回的 Future 在 flush 完成（成功或失败）后 resolve。
  /// 失败不会 throw，而是把事件留在队列中下轮再试。
  Future<void> flush() async {
    if (_flushing) return;
    if (queue.length == 0) return;
    _flushing = true;
    try {
      await _flushOnce();
    } finally {
      _flushing = false;
    }
  }

  /// 内部：执行一次取批 → 上报 → 成功出队的完整流程。
  ///
  /// 步骤：
  ///  1. peek 一批 row（最多 [config.flushThreshold] 条）；
  ///  2. 按 [config.maxBatchBytes] 二次裁剪（避免 Edge Function 请求体超限）；
  ///  3. transport.send 上报；
  ///  4. 成功 → queue.removeAll；
  ///  5. 失败 → 保留 row，下轮 flush 再试。
  ///
  /// 注：失败保留期间不会反复重试 N 次，避免一次长断网导致事件被丢掉；
  /// 重试次数由调用方通过 [TrackConfig.maxRetries] 自实现（当前默认保留）。
  Future<void> _flushOnce() async {
    final List<Map<String, Object?>> rows =
        await queue.peekRows(count: config.flushThreshold);
    if (rows.isEmpty) return;

    // 字节预检：单批不能超过 maxBatchBytes；超出则裁剪到一半再发。
    final List<Map<String, Object?>> toSend = List.of(rows);
    final TrackBatch payload = TrackBatch(
      appId: _appId,
      clientToken: _clientToken,
      events: toSend,
    );
    if (payload.estimatedBytes() > config.maxBatchBytes) {
      final int half = (rows.length / 2).floor().clamp(1, rows.length);
      toSend.removeRange(half, toSend.length);
      payload.events.length = toSend.length;
    }

    final TrackTransportResult result = await transport.send(payload);
    if (result.success) {
      await queue.removeAll(toSend);
    } else {
      // 失败保留：让下次 flush 重试；正式产品可以接入 Sentry / 自建告警
      if (config.debug) {
        // ignore: avoid_print
        print('[TrackBatcher] flush failed: ${result.error}');
      }
    }
  }
}
