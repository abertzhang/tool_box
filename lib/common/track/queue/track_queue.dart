// 文件职责：埋点事件持久化队列。
// 所属模块：common/track/queue（埋点工具类 - 队列子模块）。
// 关键依赖：
//   - hive_flutter：本地持久化 Key-Value 存储；
//   - dart:convert：JSON 编解码（行序列化到 Box）。
//
// 设计要点：
//   - 使用独立 Hive Box 'KnotBoxTrack'（与现有 KnotBox 区分，避免 key 冲突）；
//   - key 用自增序号 + 时间戳，确保按入队顺序 flush；
//   - 持久化为"完整 Supabase row"——所有公共字段已在入队前填好，避免漏字段。

import 'dart:convert';
import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';

/// 埋点事件队列。
///
/// 队列存储的是"已填好公共字段的完整 row"（即 [TrackService] 在 enqueue 前
/// 已经注入 app_id / platform / app_version / device 等），便于重启时续传
/// 不丢失任何上下文。
///
/// 线程模型：所有操作必须 await 后再使用；不要并发调用 add / drainAll，
/// [TrackService] 内部串行调度。
class TrackQueue {
  /// Hive Box 名，独立于现有 `KnotBox`，便于清理 / 备份。
  static const String boxName = 'KnotBoxTrack';

  /// Hive Box 实例。
  final Box<String> _box;

  /// 私有构造。
  const TrackQueue._(this._box);

  /// 异步工厂：打开 Box 后返回队列实例。
  static Future<TrackQueue> open() async {
    final Box<String> box = await Hive.openBox<String>(boxName);
    return TrackQueue._(box);
  }

  /// 队列容量（当前条数）。
  int get length => _box.length;

  /// 把一条完整 row 追加到队列尾部。
  ///
  /// 该 row 应是 [TrackEvent.toSupabaseRow] 的产物，已含 app_id / platform / device 等公共字段。
  Future<void> enqueueRow(Map<String, Object?> row) async {
    // key 形如 "0133..._xxx"，按时间升序排列天然有序；
    // 后缀随机数避免同一毫秒的并发 put 互相覆盖（Hive Box key 唯一）。
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final int rand = math.Random().nextInt(9999);
    final String key =
        '${millis.toString().padLeft(13, '0')}_${rand.toString().padLeft(4, '0')}';
    await _box.put(key, jsonEncode(row));
  }

  /// 取最多 [count] 条队首 row（不出队）。
  ///
  /// 返回按入队时间升序；调用方收到后再调 [removeAll] 出队。
  /// 取/删分离避免「读到一半失败 → 事件丢失」。
  Future<List<Map<String, Object?>>> peekRows({int count = 50}) async {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    final List<String> keys = _box.keys.cast<String>().toList()..sort();
    final int n = math.min(count, keys.length);
    for (int i = 0; i < n; i++) {
      try {
        final String? raw = _box.get(keys[i]);
        if (raw == null) continue;
        final dynamic parsed = jsonDecode(raw);
        if (parsed is Map) {
          out.add(parsed.cast<String, Object?>());
        }
      } catch (e) {
        // 单条解码失败直接跳过，避免脏数据阻塞队列
        continue;
      }
    }
    return out;
  }

  /// 删除与 [rows] 内容完全匹配的若干 row。
  ///
  /// 由于 Hive Box 的 key 在并发修改下索引会变，按 contents 匹配更稳定。
  Future<void> removeAll(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final Set<String> targets = rows.map((r) => jsonEncode(r)).toSet();
    final List<String> toDelete = <String>[];
    for (final String key in _box.keys.cast<String>()) {
      final String? v = _box.get(key);
      if (v != null && targets.contains(v)) {
        toDelete.add(key);
      }
    }
    if (toDelete.isNotEmpty) {
      await _box.deleteAll(toDelete);
    }
  }

  /// 给队列里**缺身份**的历史 row 补上身份字段。
  ///
  /// 为什么需要它：`user_id` 在入队那一刻就写死进 row 了。而身份绑定发生在
  /// 启动稍晚（要等 Hive 读出匿名 ID、Supabase 恢复 session），这中间入队的事件
  /// 会带上 null。不补的话这些事件传到服务端后无法参与任何按用户的聚合。
  ///
  /// 处理规则：
  ///   - 只动 `user_id` 为 null 的行；**已有身份的行一律不动**（保留其原始归属，
  ///     否则会把「上个账号的事件」错误地改挂到当前账号名下）；
  ///   - params 里同步补 `anonymous_id` / `is_anonymous`，口径与新增事件保持一致；
  ///   - 用 `putIfAbsent`，已有该 key 时不覆盖。
  ///
  /// 参数：
  ///   - [userId] 最终写入 `user_id` 列的值（登录用户 ID，或匿名 ID 兜底）；
  ///   - [anonymousId] 设备匿名 ID，可为 null（未启用匿名身份时）；
  ///   - [isAnonymous] 当前是否处于未登录状态。
  ///
  /// 返回被补写的条数（调试用）。
  Future<int> patchMissingIdentity({
    required String userId,
    String? anonymousId,
    required bool isAnonymous,
  }) async {
    final Map<String, String> updates = <String, String>{};
    for (final String key in _box.keys.cast<String>()) {
      final String? raw = _box.get(key);
      if (raw == null) continue;
      try {
        final dynamic parsed = jsonDecode(raw);
        if (parsed is! Map) continue;
        final Map<String, Object?> row = parsed.cast<String, Object?>();
        // 已有身份 → 跳过，绝不改写历史归属。
        if (row['user_id'] != null) continue;

        row['user_id'] = userId;
        final dynamic params = row['params'];
        if (params is Map) {
          final Map<String, Object?> p = params.cast<String, Object?>();
          if (anonymousId != null) {
            p.putIfAbsent('anonymous_id', () => anonymousId);
          }
          p.putIfAbsent('is_anonymous', () => isAnonymous);
          row['params'] = p;
        }
        updates[key] = jsonEncode(row);
      } catch (_) {
        // 单条脏数据跳过，不阻断整体回填
        continue;
      }
    }
    if (updates.isNotEmpty) {
      await _box.putAll(updates);
    }
    return updates.length;
  }

  /// 清空队列（调试或换账号登出后避免脏数据残留）。
  Future<void> clear() async {
    await _box.clear();
  }
}
