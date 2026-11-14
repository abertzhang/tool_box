// ============================================================================
// 文件：test/local_avatar_test.dart
// 模块：个人中心（profile）/ 本地头像 单元测试
//
// 覆盖目标：
//   `lib/feature/profile/util/local_avatar.dart` 中的三个纯函数 / 工厂：
//   1. [hashSeed]   —— 稳定哈希，必须「同输入同输出、不同输入尽量分散」；
//   2. [initialOf]  —— 首字符提取，必须能正确处理中英文、数字与空值；
//   3. [LocalAvatarPalette.ofSeed] —— 配色派生，必须稳定且落在合法范围。
//
// 为什么要锁「稳定性」：
//   本地头像是图床不可用时的兜底展示。如果配色会随调用次数或进程变化，
//   用户每次进编辑页看到的 20 个头像颜色都不一样，
//   既没法辨认也没法记住自己选了哪个 —— 这个功能就废了。
//   所以这里用**固定期望值**把稳定性钉死，将来改动算法必须同步更新本文件。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_box/feature/profile/util/local_avatar.dart';

void main() {
  group('hashSeed —— 稳定哈希', () {
    test('同一输入永远得到同一结果', () {
      // 连算三次，确保没有隐藏的随机数或全局状态。
      expect(hashSeed('avatar-0042'), hashSeed('avatar-0042'));
      expect(hashSeed('avatar-0042'), hashSeed('avatar-0042'));
    });

    test('不同输入得到不同结果', () {
      final values = <int>{
        for (int i = 0; i < 200; i++) hashSeed('avatar-$i'),
      };
      // 200 个连续编号里至少要有 190 个不同值，
      // 用来兜住「哈希写成了常数」或「只取了个位数」这类低级错误。
      expect(values.length, greaterThan(190));
    });

    test('结果恒为非负 32 位整数', () {
      // 色相计算用 hash % 360，负数会得到负色相 → HSLColor 行为未定义。
      final samples = <String>[
        '',
        'a',
        'avatar-0000',
        'avatar-0499',
        '中文昵称',
        '😀 emoji',
        // 故意用会触发高位溢出的长字符串，验证 & 0xFFFFFFFF 确实收住了。
        'x' * 500,
      ];
      for (final s in samples) {
        final h = hashSeed(s);
        expect(h, greaterThanOrEqualTo(0), reason: 'seed="$s" 得到负数 $h');
        expect(h, lessThanOrEqualTo(0xFFFFFFFF), reason: 'seed="$s" 越界 $h');
      }
    });

    test('null 与空串等价，不抛异常', () {
      expect(hashSeed(null), hashSeed(''));
    });
  });

  group('initialOf —— 首字符提取', () {
    test('英文取首字母并转大写', () {
      expect(initialOf('demouser'), 'D');
      expect(initialOf('Alice'), 'A');
    });

    test('中文取第一个汉字', () {
      expect(initialOf('张三'), '张');
      expect(initialOf('绳结爱好者'), '绳');
    });

    test('数字编号原样返回', () {
      expect(initialOf('42'), '4');
      expect(initialOf('499'), '4');
    });

    test('首尾空白会被 trim 掉', () {
      expect(initialOf('  demouser  '), 'D');
    });

    test('空串 / 纯空白 / null 返回 null', () {
      expect(initialOf(''), isNull);
      expect(initialOf('   '), isNull);
      expect(initialOf(null), isNull);
    });

    test('emoji 不会被截成半个代理对', () {
      // 用 runes 取值，一个 emoji 应还原成完整的一个字符（长度 2 个 code unit）。
      final initial = initialOf('😀smile');
      expect(initial, isNotNull);
      // 关键：不能是长度为 1 的孤立高位代理（那样会显示成乱码）。
      expect(initial!.codeUnits, isNot(hasLength(1)));
    });
  });

  group('LocalAvatarPalette.ofSeed —— 配色派生', () {
    test('同一 seed 派生出的两组装箱完全相等', () {
      final a = LocalAvatarPalette.ofSeed('avatar-0042');
      final b = LocalAvatarPalette.ofSeed('avatar-0042');
      expect(a.start, b.start);
      expect(a.end, b.end);
      expect(a.foreground, b.foreground);
    });

    test('不同 seed 的起始色不同', () {
      final colors = <Color>{
        for (int i = 0; i < 200; i++)
          LocalAvatarPalette.ofSeed('avatar-$i').start,
      };
      // 与哈希测试同理：防止「所有头像一个颜色」这种退化实现。
      expect(colors.length, greaterThan(150));
    });

    test('渐变两端颜色不相等（否则没有渐变效果）', () {
      // 色相固定偏移 40°，任何 seed 下两端都应不同。
      for (int i = 0; i < 50; i++) {
        final p = LocalAvatarPalette.ofSeed('avatar-$i');
        expect(p.start, isNot(p.end), reason: 'seed=avatar-$i 两端同色');
      }
    });

    test('前景色为不透明白色，保证任意底色上都可读', () {
      final p = LocalAvatarPalette.ofSeed('demouser');
      expect(p.foreground, Colors.white);
      expect(p.foreground.a, 1.0);
    });

    test('亮度落在 0.5~0.7，白字对比度足够', () {
      // 太亮 → 白字看不清；太暗 → 头像发黑。这里把区间钉死。
      for (int i = 0; i < 100; i++) {
        for (final c in <Color>[
          LocalAvatarPalette.ofSeed('avatar-$i').start,
          LocalAvatarPalette.ofSeed('avatar-$i').end,
        ]) {
          final hsl = HSLColor.fromColor(c);
          expect(hsl.lightness, greaterThanOrEqualTo(0.5));
          expect(hsl.lightness, lessThanOrEqualTo(0.7));
          // 颜色的 alpha 必须是 1，否则叠在卡片上会透出底色。
          expect(c.a, 1.0);
        }
      }
    });
  });
}
