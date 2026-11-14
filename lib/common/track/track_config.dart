// 文件职责：埋点工具类的运行时配置。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：无第三方依赖，可独立复用至任何 Flutter 工程。

/// 埋点工具类的总开关与运行参数。
///
/// 构造示例：
/// ```dart
/// final config = TrackConfig(
///   enabled: true,
///   appId: 'tool_box',
///   edgeFunctionUrl: 'https://<ref>.supabase.co/functions/v1/track-event',
///   clientToken: '...',
///   flushThreshold: 20,
///   flushInterval: const Duration(seconds: 30),
/// );
/// ```
///
/// 通过 [TrackService.init] 单点注入；运行期通过 [TrackService.updateConfig] 热更新。
class TrackConfig {
  /// 是否启用上报。默认 false，开发期调用方手动改为 true。
  ///
  /// 关闭状态下 [TrackService.log] 立即返回不入队，但仍会经过 [TrackService.onEvent]
  /// 监听器回调，便于开发期本地调试。
  final bool enabled;

  /// App 标识（与 `app_events.app_id` 对齐）。
  ///
  /// 推荐通过 `--dart-define=APP_ID=tool_box` 注入，未注入时默认 `unknown_app`。
  final String appId;

  /// 端点：决定使用 Edge Function 还是 REST 直写。
  /// 若 [useEdgeFunction] 为 true，使用 [edgeFunctionUrl]；
  /// 否则使用 [supabaseTable]（默认 `app_events`）通过 PostgREST insert。
  final String edgeFunctionUrl;
  final String supabaseTable;

  /// 客户端令牌：发送给 Edge Function 作轻量身份识别（与服务端 app 白名单校验配合）。
  /// 留空则 Edge Function 仅校验 app_id 白名单。
  final String? clientToken;

  /// 是否走 Edge Function 网关。默认 true（推荐生产路径）。
  final bool useEdgeFunction;

  /// 单次上传最多打包多少条事件。达到阈值立刻 flush。
  final int flushThreshold;

  /// 定时 flush 间隔。即使队列未满，也按此间隔批量发送。
  final Duration flushInterval;

  /// 采样率 0.0~1.0。0.0 = 全丢弃，1.0 = 不采样。
  /// 注意：采样在客户端进行，未命中样本的事件不会进入队列、不会保留。
  final double sampleRate;

  /// 上报失败时的最大重试次数。超过后入队等待下次启动 / 下次 flush。
  final int maxRetries;

  /// 单批事件最大总字节数。超过会被拆分，避免 Edge Function 请求体超限。
  final int maxBatchBytes;

  /// 是否启用调试日志。开启后会在 Flutter 控制台输出每次上报的概要。
  final bool debug;

  /// 创建一个埋点配置。
  ///
  /// 大多数参数都有合理默认值，最小使用形式：
  /// ```dart
  /// const TrackConfig(enabled: true, edgeFunctionUrl: '...');
  /// ```
  const TrackConfig({
    this.enabled = false,
    this.appId = 'unknown_app',
    this.edgeFunctionUrl = '',
    this.supabaseTable = 'app_events',
    this.clientToken,
    this.useEdgeFunction = true,
    this.flushThreshold = 20,
    this.flushInterval = const Duration(seconds: 30),
    this.sampleRate = 1.0,
    this.maxRetries = 3,
    this.maxBatchBytes = 256 * 1024, // 256 KiB
    this.debug = false,
  });

  /// 浅拷贝并覆盖指定字段。
  TrackConfig copyWith({
    bool? enabled,
    String? appId,
    String? edgeFunctionUrl,
    String? supabaseTable,
    String? clientToken,
    bool? useEdgeFunction,
    int? flushThreshold,
    Duration? flushInterval,
    double? sampleRate,
    int? maxRetries,
    int? maxBatchBytes,
    bool? debug,
  }) {
    return TrackConfig(
      enabled: enabled ?? this.enabled,
      appId: appId ?? this.appId,
      edgeFunctionUrl: edgeFunctionUrl ?? this.edgeFunctionUrl,
      supabaseTable: supabaseTable ?? this.supabaseTable,
      clientToken: clientToken ?? this.clientToken,
      useEdgeFunction: useEdgeFunction ?? this.useEdgeFunction,
      flushThreshold: flushThreshold ?? this.flushThreshold,
      flushInterval: flushInterval ?? this.flushInterval,
      sampleRate: sampleRate ?? this.sampleRate,
      maxRetries: maxRetries ?? this.maxRetries,
      maxBatchBytes: maxBatchBytes ?? this.maxBatchBytes,
      debug: debug ?? this.debug,
    );
  }
}
