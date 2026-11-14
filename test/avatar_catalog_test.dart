// ============================================================================
// 文件：test/avatar_catalog_test.dart
// 模块：个人中心（profile）/ 头像目录 单元测试
//
// 职责：
//   覆盖 avatar_catalog.dart 的纯逻辑：URL 拼接、随机抽取、URL 反解编号。
//   这些都是无网络、无 Widget 的纯函数，单测成本极低但能挡住最易出的错
//   （前导零位数写错、编号越界、把 Google 头像误判成内置头像）。
//
// 为什么单独一个文件：
//   widget_test.dart 跑的是 zh 宿主、widget_l10n_en_test.dart 跑 en 宿主
//   ——同一进程内跨测试切 locale 会卡死 Localizations 加载（2026-09-03 踩坑）。
//   本文件不涉及 locale，独立进程跑互不影响。
// ============================================================================

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/profile/util/avatar_catalog.dart';

void main() {
  group('avatarUrlOf —— URL 拼接', () {
    test('编号 0 补前导零为 4 位', () {
      expect(
        avatarUrlOf(0),
        'https://img-common.aknot.uk/avatar/avatar-0000.jpg',
      );
    });

    test('两位数编号补到 4 位（0042 而非 42）', () {
      expect(
        avatarUrlOf(42),
        'https://img-common.aknot.uk/avatar/avatar-0042.jpg',
      );
    });

    test('最大编号 499 拼接正确', () {
      expect(
        avatarUrlOf(499),
        'https://img-common.aknot.uk/avatar/avatar-0499.jpg',
      );
    });

    test('越界与负数按取模折算到合法区间，不抛异常', () {
      // UI 层永远拿得到一个可请求地址，真正的兜底交给 Image.network 的
      // errorBuilder，所以这里不允许抛异常把页面搞崩。
      expect(avatarUrlOf(500), avatarUrlOf(0));
      expect(avatarUrlOf(-1), avatarUrlOf(499));
    });
  });

  group('randomAvatarIndices —— 随机抽取', () {
    test('默认抽 avatarBatchSize 张（当前 10）且不重复', () {
      final list = randomAvatarIndices();
      // 不写死 10 而是断言「等于常量」：将来调批量只需改常量，测试不用跟着改。
      // 同时锁住它确实是 10 —— 防止有人改了常量而页面/集成测试没跟上。
      expect(avatarBatchSize, 10);
      expect(list.length, avatarBatchSize);
      expect(list.toSet().length, avatarBatchSize, reason: '不应出现重复编号');
    });

    test('所有编号都落在 [0, 500) 区间', () {
      final list = randomAvatarIndices();
      for (final i in list) {
        expect(i >= 0 && i < avatarTotal, isTrue, reason: '$i 越界');
      }
    });

    test('数量超过总数时截断为总数，不报错', () {
      final list = randomAvatarIndices(count: 9999);
      expect(list.length, avatarTotal);
    });

    test('数量传 0 或负数返回空列表', () {
      expect(randomAvatarIndices(count: 0), isEmpty);
      expect(randomAvatarIndices(count: -5), isEmpty);
    });

    test('注入固定随机源可复现（便于定位偶发问题）', () {
      final a = randomAvatarIndices(random: Random(2026));
      final b = randomAvatarIndices(random: Random(2026));
      expect(a, equals(b));
    });
  });

  group('parseAvatarIndex —— URL 反解编号', () {
    test('能从完整 URL 反解出编号（含前导零）', () {
      expect(parseAvatarIndex(avatarUrlOf(7)), 7);
      expect(parseAvatarIndex(avatarUrlOf(499)), 499);
    });

    test('带查询串 / 大写扩展名也能解析', () {
      expect(
        parseAvatarIndex('https://img-common.aknot.uk/avatar/avatar-0012.JPG?v=2'),
        12,
      );
    });

    test('非内置头像（如 Google 头像）返回 null', () {
      expect(
        parseAvatarIndex('https://lh3.googleusercontent.com/a/ACg8ocKxyz'),
        isNull,
      );
    });

    test('空值返回 null', () {
      expect(parseAvatarIndex(null), isNull);
      expect(parseAvatarIndex(''), isNull);
    });

    test('超出编号范围返回 null（不是本目录资源）', () {
      expect(
        parseAvatarIndex('https://img-common.aknot.uk/avatar/avatar-9999.jpg'),
        isNull,
      );
    });

    test('拼接 → 反解 往返一致', () {
      for (final i in <int>[0, 1, 99, 256, 499]) {
        expect(parseAvatarIndex(avatarUrlOf(i)), i);
      }
    });
  });
}
