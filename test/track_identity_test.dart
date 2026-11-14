// ============================================================================
// 文件：test/track_identity_test.dart
// 模块：埋点（common/track）单元测试
//
// 职责：
//   守住「埋点身份」这条链路上最容易出、且一旦出错只能靠线上数据发现的两件事：
//     1. UUID 必须是 RFC 4122 v4 格式 —— 否则 `user_id` / `session_id`
//        这两个 `uuid` 列会被 Postgres 直接拒绝写入（历史上踩过一次）；
//     2. `user_id` 的兜底与 params 身份字段的注入规则。
//
// 为什么单独一个文件：
//   本文件只用 `package:flutter_test`，不碰 Widget / locale / Isar，
//   独立进程跑不会与 widget_test 系列互相干扰（见 avatar_catalog_test.dart 的说明）。
//
// 覆盖范围：
//   - SessionContext.uuidV4()：格式、版本位、variant 位、唯一性；
//   - TrackEvent.toSupabaseRow()：user_id 透传、params null 过滤。
// ============================================================================

// 运行方式：`dart test test/track_identity_test.dart`（依赖均已为纯 Dart，
// 刻意用 package:test 而非 flutter_test，绕开 flutter_tester 在受限环境无法
// 建立本地 WebSocket 的问题，与 track_buckets_test.dart 同理）。
// ============================================================================

import 'package:test/test.dart';
import 'package:tool_box/common/track/session_context.dart';
import 'package:tool_box/common/track/track_event.dart';

void main() {
  group('SessionContext.uuidV4', () {
    // 这个正则是 app_events 表里 uuid 列能否写入的**唯一**判据：
    // 格式不对 Postgres 会报 `invalid input syntax for type uuid`，整批事件全丢。
    final RegExp uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('生成标准 v4 UUID（全小写、36 位、版本位与 variant 位正确）', () {
      for (int i = 0; i < 200; i++) {
        final String id = SessionContext.uuidV4();
        expect(id, matches(uuidPattern), reason: '第 $i 次生成的 UUID 不合规: $id');
      }
    });

    test('定长 36 位（补零正确，不会因高位字节小于 0x10 而变短）', () {
      // 单字节转 hex 时若忘了 padLeft(2,'0')，长度会在 31~36 之间浮动。
      for (int i = 0; i < 200; i++) {
        expect(SessionContext.uuidV4().length, 36);
      }
    });

    test('连续生成不重复（随机源有效）', () {
      final Set<String> ids = <String>{
        for (int i = 0; i < 1000; i++) SessionContext.uuidV4(),
      };
      // 1000 次全唯一；v4 有 122 bit 随机位，碰撞概率可忽略。
      expect(ids.length, 1000);
    });
  });

  group('TrackEvent.toSupabaseRow', () {
    test('user_id 原样透传（匿名 ID 兜底后也应是合法 UUID 字符串）', () {
      final String uid = SessionContext.uuidV4();
      final TrackEvent event = TrackEvent(
        eventName: 'tool_entry_open',
        params: const <String, Object?>{'tool': 'compass'},
        sessionId: SessionContext.uuidV4(),
        userId: uid,
      );

      final Map<String, Object?> row = event.toSupabaseRow(
        appId: 'tool_box',
        platform: 'ios',
        appVersion: '1.0.0+1',
        device: const <String, Object?>{'os': 'ios'},
      );

      expect(row['user_id'], uid);
      expect(row['event_name'], 'tool_entry_open');
      expect(row['app_id'], 'tool_box');
    });

    test('未登录（userId 为 null）时 user_id 保持 SQL NULL 语义', () {
      // 注意：运行期的兜底发生在 TrackService._resolveUserId，
      // 这里验证的是「TrackEvent 层不擅自造假身份」—— 兜底值必须由上层显式注入。
      final TrackEvent event = TrackEvent(
        eventName: 'tool_entry_open',
        params: const <String, Object?>{},
        sessionId: SessionContext.uuidV4(),
      );

      final Map<String, Object?> row = event.toSupabaseRow(
        appId: 'tool_box',
        platform: 'ios',
        appVersion: '1.0.0+1',
        device: const <String, Object?>{},
      );

      expect(row['user_id'], isNull);
    });

    test('params 中的 null 值被过滤，不写入 jsonb', () {
      final TrackEvent event = TrackEvent(
        eventName: 'e',
        params: const <String, Object?>{'a': 1, 'b': null, 'c': 'x'},
        sessionId: SessionContext.uuidV4(),
      );

      final Map<String, Object?> row = event.toSupabaseRow(
        appId: 'tool_box',
        platform: 'ios',
        appVersion: '1.0.0+1',
        device: const <String, Object?>{},
      );

      expect(row['params'], <String, Object?>{'a': 1, 'c': 'x'});
      expect((row['params'] as Map).containsKey('b'), isFalse);
    });

    test('身份字段进入 params 后能原样序列化（anonymous_id / is_anonymous）', () {
      final String anonId = SessionContext.uuidV4();
      final TrackEvent event = TrackEvent(
        eventName: 'tool_entry_open',
        params: <String, Object?>{
          'anonymous_id': anonId,
          'is_anonymous': true,
          'source': 'tool_page',
        },
        sessionId: SessionContext.uuidV4(),
        userId: anonId,
      );

      final Map<String, Object?> row = event.toSupabaseRow(
        appId: 'tool_box',
        platform: 'ios',
        appVersion: '1.0.0+1',
        device: const <String, Object?>{},
      );

      final Map<dynamic, dynamic> params = row['params'] as Map;
      expect(params['anonymous_id'], anonId);
      expect(params['is_anonymous'], true);
      expect(params['source'], 'tool_page');
    });
  });
}
