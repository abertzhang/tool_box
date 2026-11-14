// 文件职责：定义埋点事件 TrackEvent 的数据结构与序列化逻辑。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：无（仅 dart:convert / dart:core），可独立复用至任何 Flutter 工程。
//
// 设计要点：
//   - 不可变模型（_$TrackEventCopyWith 不可用，故 all final 字段 + copyWith）；
//   - params 字典自动丢弃 null 值（避免 `{"key": null}` 这种噪声）；
//   - 序列化输出与 app_events 表 schema 一一对应（见 scripts/sql/app_events.sql）。

/// 单条埋点事件的不可变模型。
///
/// 字段含义对应 `app_events` 表的列：
///   - [eventName]    → event_name
///   - [params]       → params（jsonb）
///   - [occurredAt]   → occurred_at
///   - [sessionId]    → session_id
///   - [userId]       → user_id（可空，未登录为 null）
///
/// `appId` / `platform` / `appVersion` / `device` 不在此处保存，它们由
/// [SessionContext] 在序列化阶段注入，避免每条事件重复填同样的字段。
class TrackEvent {
  /// 事件名（必填）。推荐 `snake_case`，按业务前缀聚合，例如：
  ///   `tool_entry_open` / `noise_measure_start` / `app_launch`。
  final String eventName;

  /// 事件参数，自由字典。
  /// null 值在 [toSupabaseRow] 中会被过滤，仅保留有效字段。
  final Map<String, Object?> params;

  /// 客户端发生时间。
  /// 传 null 时在 [TrackService.log] 入口自动填充 `DateTime.now().toUtc()`。
  final DateTime? occurredAt;

  /// 会话 ID（必填）。由 [TrackService.init] 生成并贯穿整个启动周期。
  final String sessionId;

  /// 关联用户 UUID（可空）。登录后由 [TrackService.setUserId] 注入。
  final String? userId;

  /// 创建一条埋点事件。
  ///
  /// 注意：通常 **不要** 在业务代码里直接 `TrackEvent(...)`，应使用
  /// [TrackService.log] / [TrackService.logNow]，本构造函数仅供队列反序列化使用。
  const TrackEvent({
    required this.eventName,
    required this.params,
    required this.sessionId,
    this.userId,
    this.occurredAt,
  });

  /// 浅拷贝并在指定字段上覆盖新值，便于队列内部加工。
  TrackEvent copyWith({
    String? eventName,
    Map<String, Object?>? params,
    DateTime? occurredAt,
    String? sessionId,
    String? userId,
  }) {
    return TrackEvent(
      eventName: eventName ?? this.eventName,
      params: params ?? this.params,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  /// 序列化为 Supabase 表行 JSON。
  ///
  /// 返回的 Map 与 `app_events` 表列一一对应：
  ///   - params 自动过滤 null 值；
  ///   - 空 userId 会转为 SQL NULL（jsonb null）；
  ///   - occurredAt 未设置时使用 `DateTime.now().toUtc()` 兜底。
  ///
  /// [appId] / [platform] / [appVersion] / [device] 由调用方注入（来自 [SessionContext]），
  /// 避免每条事件重复同样的字段。
  Map<String, Object?> toSupabaseRow({
    required String appId,
    required String platform,
    required String appVersion,
    required Map<String, Object?> device,
  }) {
    // 复制并过滤 params 中的 null 值，缩小 jsonb 体积
    final Map<String, Object?> filteredParams = <String, Object?>{};
    params.forEach((key, value) {
      if (value != null) {
        filteredParams[key] = value;
      }
    });

    return <String, Object?>{
      'app_id': appId,
      // SQL NULL：保持 nullable 字段语义干净
      'user_id': userId,
      'session_id': sessionId,
      'event_name': eventName,
      'params': filteredParams,
      'platform': platform,
      'app_version': appVersion,
      'device': device,
      'occurred_at': (occurredAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  /// 从 JSON 反序列化，用于 Hive Box 读盘恢复队列。
  ///
  /// 异常：
  ///   - [FormatException] 当必填字段缺失或类型错误时抛出。
  ///   - 调用方应捕获并丢弃该条事件，避免脏数据卡死队列。
  factory TrackEvent.fromJson(Map<String, Object?> json) {
    final dynamic sessionIdRaw = json['session_id'];
    final dynamic eventNameRaw = json['event_name'];
    if (sessionIdRaw is! String || sessionIdRaw.isEmpty) {
      throw const FormatException('TrackEvent.session_id 缺失或非字符串');
    }
    if (eventNameRaw is! String || eventNameRaw.isEmpty) {
      throw const FormatException('TrackEvent.event_name 缺失或非字符串');
    }
    final dynamic occurredRaw = json['occurred_at'];
    return TrackEvent(
      eventName: eventNameRaw,
      params: (json['params'] as Map?)?.cast<String, Object?>() ??
          <String, Object?>{},
      sessionId: sessionIdRaw,
      userId: json['user_id'] as String?,
      occurredAt: occurredRaw is String ? DateTime.tryParse(occurredRaw) : null,
    );
  }

  /// 序列化为 JSON Map（用于 Hive 持久化，不含公共字段）。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'event_name': eventName,
      'params': params,
      'session_id': sessionId,
      'user_id': userId,
      'occurred_at': occurredAt?.toUtc().toIso8601String(),
    };
  }
}
