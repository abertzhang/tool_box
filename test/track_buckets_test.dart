// ============================================================================
// 文件：test/track_buckets_test.dart
// 模块：埋点 · 参数桶化与节流 单元测试
//
// 为什么单独测这两块：
//   它们是**数据正确性**的最后一道防线，且逻辑不依赖 Flutter ——
//   桶名写错（如 '10-100' 写成 '100-10'）或节流失效，
//   表现都不是崩溃而是「数据悄悄变成垃圾」，只能靠测试发现。
//
//   其中 UUID 格式必须严格正确：app_events.user_id / session_id 列是 Postgres
//   的 uuid 类型，格式不对会被整批拒绝插入（历史上 session_id 就栽过一次）。
//
// 运行方式（两种都行，推荐前者）：
//   dart test test/track_buckets_test.dart          —— 不需要 flutter_tester
//   flutter test test/track_buckets_test.dart       —— 走 Flutter 测试环境
//
// 本文件刻意**不** import flutter_test：[TrackBuckets] 与 [TrackThrottle] 是纯
// Dart 逻辑，用 package:test 就能覆盖，从而绕开 flutter_tester 在受限环境下
// 无法建立本地 WebSocket 的问题（见 .workbuddy/memory/MEMORY.md）。
// ============================================================================

import 'package:test/test.dart';
import 'package:tool_box/common/analytics/track_events.dart';

void main() {
  group('TrackBuckets.magnitude —— 量级桶', () {
    test('按默认边界分档', () {
      expect(TrackBuckets.magnitude(5), '0-10');
      expect(TrackBuckets.magnitude(10), '10-100');
      expect(TrackBuckets.magnitude(99.9), '10-100');
      expect(TrackBuckets.magnitude(100), '100-1000');
      expect(TrackBuckets.magnitude(1000), '1000-10000');
      // 10000 是最后一档的下界，应归入 '10000+' 而非 '1000-10000'。
      expect(TrackBuckets.magnitude(9999), '1000-10000');
      expect(TrackBuckets.magnitude(10000), '10000+');
      expect(TrackBuckets.magnitude(100000), '10000+');
    });

    test('边界值落在高档而非低档（左闭右开）', () {
      // 10 必须归入 '10-100' 而不是 '0-10'，否则相邻两档会重复计数。
      expect(TrackBuckets.magnitude(10), isNot('0-10'));
    });

    test('自定义边界生效', () {
      expect(TrackBuckets.magnitude(30, edges: const <double>[50, 200]), '0-50');
      expect(
        TrackBuckets.magnitude(300, edges: const <double>[50, 200]),
        '200+',
      );
    });

    test('异常数值归入 invalid 而不是产出脏桶名', () {
      expect(TrackBuckets.magnitude(double.nan), 'invalid');
      expect(TrackBuckets.magnitude(double.infinity), 'invalid');
    });

    test('负数按绝对值分档，不产出空桶名', () {
      // 力值 / 绳长等业务量不会为负，但异常输入不能把桶名搞成 '--10'。
      expect(TrackBuckets.magnitude(-50), '10-100');
    });
  });

  group('TrackBuckets.cardinal —— 方位桶', () {
    test('八个正方向各自落位', () {
      expect(TrackBuckets.cardinal(0), 'N');
      expect(TrackBuckets.cardinal(45), 'NE');
      expect(TrackBuckets.cardinal(90), 'E');
      expect(TrackBuckets.cardinal(135), 'SE');
      expect(TrackBuckets.cardinal(180), 'S');
      expect(TrackBuckets.cardinal(225), 'SW');
      expect(TrackBuckets.cardinal(270), 'W');
      expect(TrackBuckets.cardinal(315), 'NW');
    });

    test('正北不被劈成两半（扇区中心偏移 22.5°）', () {
      expect(TrackBuckets.cardinal(359), 'N');
      expect(TrackBuckets.cardinal(1), 'N');
    });

    test('超出一圈与负角度都能归一', () {
      expect(TrackBuckets.cardinal(360 + 90), 'E');
      expect(TrackBuckets.cardinal(-90), 'W');
      expect(TrackBuckets.cardinal(-720 + 45), 'NE');
    });
  });

  group('TrackBuckets.decibel —— 分贝桶', () {
    test('四档阈值', () {
      expect(TrackBuckets.decibel(30), 'quiet');
      expect(TrackBuckets.decibel(45), 'moderate');
      expect(TrackBuckets.decibel(70), 'loud');
      expect(TrackBuckets.decibel(95), 'very_loud');
    });
  });

  group('TrackBuckets.textLength —— 文本长度桶', () {
    test('三段阈值', () {
      expect(TrackBuckets.textLength(0), '0-50');
      expect(TrackBuckets.textLength(49), '0-50');
      expect(TrackBuckets.textLength(50), '50-200');
      expect(TrackBuckets.textLength(200), '200+');
    });
  });

  group('TrackThrottle —— 高频事件节流', () {
    test('窗口内首次放行、后续拦截', () {
      final TrackThrottle t = TrackThrottle(
        window: const Duration(milliseconds: 500),
      );
      expect(t.allow('conv_area'), isTrue);
      expect(t.allow('conv_area'), isFalse);
      expect(t.allow('conv_area'), isFalse);
    });

    test('不同 key 互不干扰', () {
      final TrackThrottle t = TrackThrottle();
      expect(t.allow('conv_area'), isTrue);
      // 换一个分类必须放行：否则在面积页的输入会挡住长度页的上报。
      expect(t.allow('conv_length'), isTrue);
    });

    test('窗口过后重新放行', () async {
      final TrackThrottle t = TrackThrottle(
        window: const Duration(milliseconds: 10),
      );
      expect(t.allow('k'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(t.allow('k'), isTrue);
    });

    test('模拟连续输入只放行一次', () {
      final TrackThrottle t = TrackThrottle();
      // 用户输入 "12.5" 会触发 4 次 onChanged。
      int passed = 0;
      for (final String _ in <String>['1', '12', '12.', '12.5']) {
        if (t.allow('conv_weight')) passed++;
      }
      expect(passed, 1);
    });

    test('clear 后重新计数', () {
      final TrackThrottle t = TrackThrottle();
      expect(t.allow('k'), isTrue);
      t.clear();
      expect(t.allow('k'), isTrue);
    });
  });
}
