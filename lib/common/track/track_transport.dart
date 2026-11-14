// 文件职责：定义埋点传输层抽象，使工具类与具体后端解耦。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：无第三方依赖；具体实现见 transport/ 子目录。

/// 单批事件上报的请求体。
///
/// 字段含义：
///   - [appId]     → app_id
///   - [events]    → 待写入表的事件列表，每条已包含 device/platform/appVersion
///   - [clientToken] → Edge Function 鉴权用（REST 直写模式忽略）
class TrackBatch {
  /// App 标识。
  final String appId;

  /// 待上报的事件行（已是 Supabase insert 行形态，含公共字段）。
  final List<Map<String, Object?>> events;

  /// 客户端令牌，Edge Function 模式下用于轻量身份校验。
  final String? clientToken;

  /// 构造一个上报批次。
  const TrackBatch({
    required this.appId,
    required this.events,
    this.clientToken,
  });

  /// 该批次的近似字节数（用于客户端预分批，避免请求体超限）。
  ///
  /// 实现：估算每行字段的 toString 长度之和，再加 16 字节分隔开销。
  /// 注：这是粗估，Edge Function 端的 hard limit 才是最终约束。
  int estimatedBytes() {
    int total = 16; // json brace / array overhead
    for (final row in events) {
      for (final entry in row.entries) {
        total += entry.key.length + entry.value.toString().length + 8;
      }
    }
    return total;
  }
}

/// 单次上报的结果。
///
/// 失败时支持错误分类，调用方决定是否入队等下次重试。
class TrackTransportResult {
  /// 上报是否成功。
  final bool success;

  /// 错误描述（仅失败时有值），便于上层日志。
  final String? error;

  /// 失败模式分类：
  ///   - `transient` 短暂错误（5xx / 网络），应入队等下次重试；
  ///   - `permanent` 永久错误（4xx 数据格式），不应继续重试，直接丢弃/降级；
  ///   - `auth`      鉴权失败（401/403），需告警 + 不再重试。
  final String? failureKind;

  /// 构造一个上报结果。
  const TrackTransportResult({
    required this.success,
    this.error,
    this.failureKind,
  });

  /// 成功快捷工厂。
  static const TrackTransportResult ok = TrackTransportResult(success: true);

  /// 失败快捷工厂：[failureKind] 默认 `transient`。
  factory TrackTransportResult.fail(String message,
      {String failureKind = 'transient'}) {
    return TrackTransportResult(
      success: false,
      error: message,
      failureKind: failureKind,
    );
  }
}

/// 埋点传输层抽象。
///
/// 实现策略：
///   - 默认实现：[EdgeFunctionTransport]（生产推荐，service_role 写表）
///   - 备选实现：[SupabaseRestTransport]（开发便利，但需正确配置 GRANT/RLS）
///
/// 自定义实现：业务方可在 init 时注入自己的 transport（如 Kafka / 友盟 / 神策），
/// 而无需修改本工具类的业务逻辑。
abstract class TrackTransport {
  /// 把一批事件发送到后端。
  ///
  /// [batch] 必填且非空；[batch.events] 必须为非空 List。
  /// 返回：
  ///   - 成功返回 `TrackTransportResult.ok`；
  ///   - 失败返回具体错误信息；
  ///   - 注意：transport 内部不应抛出异常，所有错误应捕获并返回失败结果。
  Future<TrackTransportResult> send(TrackBatch batch);
}
