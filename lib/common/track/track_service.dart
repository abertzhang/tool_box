// 文件职责：埋点工具类主入口，全局单例。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：
//   - queue/track_queue：事件持久化；
//   - batcher/track_batcher：批量调度；
//   - session_context：会话 / 设备上下文；
//   - transport：上报通道（默认 EdgeFunctionTransport）。
//
// 典型生命周期：
//
//   main() {
//     WidgetsFlutterBinding.ensureInitialized();
//     await Hive.initFlutter();
//     final pkg = await PackageInfo.fromPlatform();
//     await TrackService.instance.init(
//       TrackConfig(
//         enabled: true,
//         appId: 'tool_box',
//         edgeFunctionUrl: 'https://<ref>.supabase.co/functions/v1/track-event',
//         debug: true,
//       ),
//       appVersion: '${pkg.version}+${pkg.buildNumber}',
//       supabaseUrl: AppEnv.supabaseUrl,
//       supabaseAnonKey: AppEnv.supabaseAnonKey,
//     );
//     runApp(...);
//   }

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'batcher/track_batcher.dart';
import 'queue/track_queue.dart';
import 'session_context.dart';
import 'track_config.dart';
import 'track_event.dart';
import 'track_transport.dart';
import 'transport/edge_function_transport.dart';
import 'transport/supabase_rest_transport.dart';

/// 埋点工具类全局门面。
///
/// 通过 [TrackService.instance] 获取单例；其它模块推荐 `TrackService.instance.log(...)`。
///
/// 线程模型：所有公开方法均 `async`，内部串行执行；不要并发调用 `flush()`，内部有互斥锁。
class TrackService {
  /// 单例。懒加载；调用 [init] 才真正生效。
  static final TrackService instance = TrackService._();

  /// 私有构造。
  TrackService._();

  /// 当前运行时配置。
  TrackConfig? _config;

  /// 队列。
  TrackQueue? _queue;

  /// 调度器。
  TrackBatcher? _batcher;

  /// 传输通道。
  TrackTransport? _transport;

  /// 会话上下文（含 sessionId / platform / appVersion / device）。
  SessionContext? _context;

  /// 当前用户 ID（可空，登录时设置）。
  String? _userId;

  /// 设备级匿名 ID（可空，由 [setAnonymousId] 注入）。
  ///
  /// 作用：未登录时用它兜底 `user_id` 列，避免该列出现 null ——
  /// null 无法参与 `count(distinct)`，会导致「未登录独立设备数」根本算不出来。
  String? _anonymousId;

  /// 全局公共参数：每条事件自动携带，业务方无需逐个传。
  ///
  /// 典型用途：匿名 ID、是否匿名、A/B 分组、渠道号这类**贯穿全 App** 的维度。
  /// 业务调用时传入的同名 params 会**覆盖**这里的值（业务侧更具体，优先级更高）。
  Map<String, Object?> _globalParams = const <String, Object?>{};

  /// 是否已经初始化。
  bool _initialized = false;

  /// 暴露内部 config 供调试（不可变）。
  TrackConfig? get config => _config;

  /// 当前 session id（调试用）。
  String? get sessionId => _context?.sessionId;

  /// 当前 user id。
  String? get userId => _userId;

  /// 当前设备匿名 id（未登录时作为 `user_id` 的兜底值）。
  String? get anonymousId => _anonymousId;

  /// 队列当前条数（调试用）。
  int get queueLength => _queue?.length ?? 0;

  /// 初始化。
  ///
  /// 参数：
  ///   - [config] 运行时配置；
  ///   - [appVersion] App 版本号（含 build），通常来自 `PackageInfo.fromPlatform()`；
  ///   - [supabaseUrl] Supabase 工程 URL（来自 `AppEnv`），REST 模式下必填；
  ///   - [supabaseAnonKey] Supabase anon key（来自 `AppEnv`），必填；
  ///   - [transport] 自定义传输通道，覆盖默认值。
  ///
  /// 注意：
  ///   - 必须先 `Hive.initFlutter()` 再调用本方法；
  ///   - 调用前确保 dart:io `Platform` 已可用（即 `WidgetsFlutterBinding.ensureInitialized()`）。
  Future<void> init(
    TrackConfig config, {
    required String appVersion,
    required String supabaseUrl,
    required String supabaseAnonKey,
    TrackTransport? transport,
  }) async {
    if (_initialized) {
      // 已经初始化：走更新分支（保留队列与上下文，避免数据丢失）
      _config = config;
      _batcher?.stop();
      _rebuildBatcher();
      return;
    }

    _config = config;

    // 1. 打开 Hive Box（持久化队列）
    _queue = await TrackQueue.open();

    // 2. 构造 SessionContext
    _context = SessionContext.build(appVersion: appVersion);

    // 3. 构造 Transport（默认 Edge Function，可被 custom 覆盖）
    _transport = transport ?? _buildDefaultTransport(
      config: config,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );

    // 4. 构造 Batcher 并启动
    _batcher = TrackBatcher(
      queue: _queue!,
      transport: _transport!,
      config: config,
      appId: config.appId,
      clientToken: config.clientToken,
    );
    _batcher!.start();

    _initialized = true;

    // 5. 调试日志
    if (config.debug) {
      debugPrint(
        '[TrackService] init appId=${config.appId} '
        'platform=${_context!.platform} appVersion=${_context!.appVersion} '
        'useEdgeFunction=${config.useEdgeFunction} enabled=${config.enabled}',
      );
    }

    // 6. 启动时试 flush 一次（断网期间堆积的事件借此补传）
    if (config.enabled) {
      // 不阻塞 init 完成，丢到后台
      unawaited(_batcher!.flush());
    }
  }

  /// 默认 Transport 工厂。
  ///
  /// 根据 [TrackConfig.useEdgeFunction] 选择 Edge Function 或 REST 直写。
  /// 调用方也可传 [transport] 参数整体覆盖。
  TrackTransport _buildDefaultTransport({
    required TrackConfig config,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    if (config.useEdgeFunction) {
      return EdgeFunctionTransport(
        url: config.edgeFunctionUrl,
        anonKey: supabaseAnonKey,
        clientToken: config.clientToken,
      );
    }
    return SupabaseRestTransport(
      supabaseUrl: supabaseUrl,
      anonKey: supabaseAnonKey,
      table: config.supabaseTable,
    );
  }

  /// 热更新 config（如登录后改 sampleRate / 切 staging 环境）。
  ///
  /// 注意：仅替换 config 与 batcher，不会重建 transport（避免拖出连接池）。
  void updateConfig(TrackConfig newConfig) {
    if (!_initialized) return;
    _config = newConfig;
    _batcher?.stop();
    _rebuildBatcher();
  }

  /// 重建 batcher 以应用新的 flushInterval / flushThreshold。
  void _rebuildBatcher() {
    final TrackConfig? cfg = _config;
    final TrackQueue? q = _queue;
    final TrackTransport? t = _transport;
    if (cfg == null || q == null || t == null) return;
    _batcher = TrackBatcher(
      queue: q,
      transport: t,
      config: cfg,
      appId: cfg.appId,
      clientToken: cfg.clientToken,
    );
    _batcher!.start();
  }

  /// 绑定用户 ID（如登录成功后）。
  ///
  /// 之后所有事件都会带这个 user_id；登出时调用 [clearUserId]。
  /// 该方法仅保存引用，不主动写"登录"事件——由业务方决定要不要单独发。
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// 清空用户 ID（如登出后）。注意不主动写"登出"事件。
  void clearUserId() {
    _userId = null;
  }

  /// 绑定设备级匿名 ID（通常在 `main()` 里调用一次）。
  ///
  /// 取值来自 `TrackAnonymousId.load()`：首次生成后持久化到 Hive，
  /// 跨会话稳定；清数据 / 重装后重新生成。
  ///
  /// 注入后带来的三项行为变化：
  ///   1. `user_id` 列在未登录时用该值兜底（不再是 null）；
  ///   2. 所有事件的 params 自动带 `anonymous_id`；
  ///   3. 所有事件的 params 自动带 `is_anonymous`（true = 未登录）。
  void setAnonymousId(String? anonymousId) {
    _anonymousId = anonymousId;
  }

  /// 设置全局公共参数（整体替换，不是增量合并）。
  ///
  /// 用于注入贯穿全 App 的维度（如 A/B 分组 `variant: 'b'`、渠道 `channel: 'app_store'`）。
  /// 传空 Map 可清空。
  ///
  /// 注意：本工具类自动管理的 `anonymous_id` / `is_anonymous` 不通过这里设置，
  /// 它们在 [log] / [logNow] 内部注入，且**业务传入的同名 key 覆盖不了这两个**——
  /// 身份字段必须保持可信，不能让业务方随手改写。
  void setGlobalParams(Map<String, Object?> params) {
    _globalParams = Map<String, Object?>.unmodifiable(params);
  }

  /// 组装一条事件的完整 params：全局参数 → 身份参数 → 业务参数（后者优先级高）。
  ///
  /// 合并顺序即优先级：业务显式传入的最具体，应能覆盖全局默认值；
  /// 但 `anonymous_id` / `is_anonymous` 属于身份字段，放在业务参数**之后**写入，
  /// 保证其可信、不被业务误覆盖。
  ///
  /// - [params]：业务调用方传入的参数；
  /// - [effectiveUserId]：最终生效的用户 ID（已考虑匿名兜底）。
  Map<String, Object?> _mergeParams(
    Map<String, Object?> params,
    String? effectiveUserId,
  ) {
    final Map<String, Object?> merged = <String, Object?>{}
      // 1) 全局公共参数（业务可覆盖）
      ..addAll(_globalParams)
      // 2) 业务参数（覆盖全局）
      ..addAll(params)
      // 3) 身份字段（覆盖一切，保证可信）
      ..addAll(<String, Object?>{
        // 始终带上匿名 ID：登录前后可借此串联同一台设备的完整行为链。
        if (_anonymousId != null) 'anonymous_id': _anonymousId,
        // 是否匿名 = 是否有真实登录用户。分析时 `is_anonymous = false` 即真实用户。
        'is_anonymous': effectiveUserId == null || effectiveUserId == _anonymousId,
      });
    return merged;
  }

  /// 给队列中**已存在**但缺身份的历史事件补写身份字段。
  ///
  /// 典型调用时机：`main()` 里完成身份绑定之后立刻调一次——此时 Hive / Supabase
  /// 都已就绪，可以把「绑定之前那几十毫秒内入队的事件」救回来。
  ///
  /// 只补 `user_id` 为 null 的行，已有身份的行保持原样（避免把上个账号的事件
  /// 错误改挂到当前账号）。返回被补写的条数。
  Future<int> backfillQueuedIdentity() async {
    final TrackQueue? q = _queue;
    if (q == null) return 0;
    final String? uid = _resolveUserId(null);
    if (uid == null) return 0;

    // 是否匿名 = 「生效的 user_id」就是「匿名 ID」本身，说明没有真实登录用户。
    final bool isAnonymous = _userId == null || uid == _anonymousId;
    return q.patchMissingIdentity(
      userId: uid,
      anonymousId: _anonymousId,
      isAnonymous: isAnonymous,
    );
  }

  /// 计算最终写入 `user_id` 列的值：登录用户优先，否则退回设备匿名 ID。
  ///
  /// 兜底的意义：`user_id` 为 null 时该行无法参与任何按用户维度的聚合，
  /// 等于这批"未登录用户"的数据全部沉没。
  String? _resolveUserId(String? overrideUserId) {
    final String? uid = overrideUserId ?? _userId;
    return (uid != null && uid.isNotEmpty) ? uid : _anonymousId;
  }

  /// 记录一条事件。
  ///
  /// 参数：
  ///   - [eventName] 事件名（snake_case）；
  ///   - [params] 事件参数（自动过滤 null）；
  ///   - [userId] 可选覆盖当前用户 ID；
  ///   - [occurredAt] 可选指定事件发生时间（默认 now）。
  ///
  /// 行为：
  ///   - config.enabled = false 时直接返回（不开销）；
  ///   - 否则按 sampleRate 抽样、未命中样本的事件丢弃；
  ///   - 命中事件入队，超过 batcher 阈值会自动 flush。
  void log(
    String eventName, {
    Map<String, Object?> params = const <String, Object?>{},
    String? userId,
    DateTime? occurredAt,
  }) {
    final TrackConfig? cfg = _config;
    if (cfg == null || !cfg.enabled) return;

    // 采样：随机 [0,1) < sampleRate 视为命中
    if (cfg.sampleRate < 1.0) {
      final double rand = _sampleRandom();
      if (rand >= cfg.sampleRate) return;
    }

    final SessionContext? ctx = _context;
    final TrackQueue? q = _queue;
    if (ctx == null || q == null) return;

    // 未登录时用设备匿名 ID 兜底，保证 user_id 列不为 null（否则无法按用户聚合）。
    final String? effectiveUserId = _resolveUserId(userId);

    final TrackEvent event = TrackEvent(
      eventName: eventName,
      // 合并全局参数与身份字段，业务方无需手工带上 anonymous_id / is_anonymous。
      params: _mergeParams(params, effectiveUserId),
      sessionId: ctx.sessionId,
      userId: effectiveUserId,
      occurredAt: occurredAt,
    );

    // 转为完整 row 再入队：所有公共字段一次性注入，batcher/transport 不再补。
    final Map<String, Object?> row = event.toSupabaseRow(
      appId: cfg.appId,
      platform: ctx.platform,
      appVersion: ctx.appVersion,
      device: ctx.device,
    );
    unawaited(q.enqueueRow(row));

    // 触发批量上传：超过阈值立刻 flush
    if (q.length >= cfg.flushThreshold) {
      unawaited(_batcher?.flush() ?? Future<void>.value());
    }

    if (cfg.debug) {
      debugPrint(
        '[TrackService] log $eventName params=${event.params} '
        'queueLength=${q.length}',
      );
    }
  }

  /// 立即记录一条事件（绕过队列，直接 flush）。
  ///
  /// 用于关键节点（如购买成功 / 错误上报）希望尽快落库的场景。
  /// 仍受 enabled / sampleRate 控制。
  Future<void> logNow(
    String eventName, {
    Map<String, Object?> params = const <String, Object?>{},
    String? userId,
    DateTime? occurredAt,
  }) async {
    final TrackConfig? cfg = _config;
    if (cfg == null || !cfg.enabled) return;
    final SessionContext? ctx = _context;
    final TrackQueue? q = _queue;
    final TrackBatcher? b = _batcher;
    if (ctx == null || q == null || b == null) return;

    if (cfg.sampleRate < 1.0) {
      final double rand = _sampleRandom();
      if (rand >= cfg.sampleRate) return;
    }

    // 与 log() 保持同一套身份解析逻辑：登录用户优先，否则匿名 ID 兜底。
    final String? effectiveUserId = _resolveUserId(userId);

    final TrackEvent event = TrackEvent(
      eventName: eventName,
      params: _mergeParams(params, effectiveUserId),
      sessionId: ctx.sessionId,
      userId: effectiveUserId,
      occurredAt: occurredAt,
    );

    final Map<String, Object?> row = event.toSupabaseRow(
      appId: cfg.appId,
      platform: ctx.platform,
      appVersion: ctx.appVersion,
      device: ctx.device,
    );
    await q.enqueueRow(row);

    // 触发一次立即上传（不阻塞当前业务）
    unawaited(b.flush());
  }

  /// 主动触发一次 flush。
  ///
  /// 一般在 `AppLifecycleState.paused` 之前调用，保证事件及时落库。
  Future<void> flush() async {
    await _batcher?.flush();
  }

  /// 释放资源（一般在退出应用前调用）。
  ///
  /// 流程：
  ///   1. 停定时器；
  ///   2. 强制 flush 一次（即便网络异常也走 transient 流程，事件留队列等下次启动）。
  Future<void> dispose() async {
    _batcher?.stop();
    await _batcher?.flush();
    final TrackTransport? t = _transport;
    if (t is EdgeFunctionTransport) {
      t.close();
    } else if (t is SupabaseRestTransport) {
      t.close();
    }
    _initialized = false;
  }

  /// 当前 PackageInfo 便捷包装，用于 main 接入。
  ///
  /// 提供静态方法避免 import 时机问题（init 时直接 await 即可拿到版本）。
  static Future<String> currentAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// 采样伪随机（便于测试时 mock）。
  double _sampleRandom() => _defaultRandom();
}

// 顶层默认随机数（与 _sampleRandom 解耦，便于以后替换为可注入的随机源）。
double _defaultRandom() {
  // 这里借助 dart:math 即可，无状态。
  // 重要：保留为函数引用以便未来做 mock。
  // ignore: prefer_function_declarations_over_variables
  return (DateTime.now().microsecondsSinceEpoch % 10000) / 10000.0;
}
