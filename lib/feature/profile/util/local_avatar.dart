// ============================================================================
// 文件：feature/profile/util/local_avatar.dart
// 模块：个人中心（profile）/ 本地生成头像
//
// 职责：
//   在**不依赖任何网络**的前提下，根据一个稳定的 seed 字符串生成一张可辨识的
//   圆形头像（渐变底色 + 首字符）。用于「头像图床不可用」时的兜底展示。
//
// 为什么需要它（2026-09-04）：
//   内置头像图床 `img-common.aknot.uk` 由 Cloudflare 防护，当时对非浏览器客户端
//   （curl / 本 App 的 Image.network）一律返回 403 的 JS 挑战页，
//   导致编辑资料页的候选头像全部加载失败、退化成一排灰色人形占位图标 ——
//   用户看起来就像「功能坏了」，而且完全没法选。
//   挑战后来靠平台侧加 WAF Skip 规则根治了（见 cloudflare-image-host/README.md §9.4，
//   2026-09-04 晚复测已全部 200）。但**App 不该把自己的可用性抵押在一个外部图床上**：
//   本文件的兜底依然保留，图床再挂 / 断网 / 用户用 Google 头像时都能选、能存、能显示。
//
// 设计要点：
//   1. **稳定**：同一个 seed 永远得到同一组配色（纯函数 + 整数哈希，无随机数），
//      用户刷新页面、重启 App、换设备登录，头像颜色都不会跳变；
//   2. **可区分**：seed 不同则色相不同，候选格子不会糊成一片；
//   3. **无额外依赖**：只用 Flutter 自带的 Material 组件与 dart:math，
//      不引入任何三方包，也不会因为网络失败而抛异常。
//
// 关键依赖：package:flutter/material.dart。
// ============================================================================

import 'package:flutter/material.dart';

/// 本地生成头像的默认尺寸（逻辑像素）。
const double kLocalAvatarDefaultSize = 48;

/// 首字符占头像边长的比例。
const double kLocalAvatarFontScale = 0.42;

/// 对 seed 做 32 位 FNV-1a 哈希，返回**非负**整数。
///
/// 选 FNV-1a 的理由：实现只有几行、无需额外依赖、对短字符串（昵称、编号）
/// 的分布足够均匀，能避免「相近的 seed 得到相近的颜色」。
///
/// 参数：[seed] 任意字符串；为空时按固定值处理，保证不抛异常。
int hashSeed(String? seed) {
  final String s = seed ?? '';
  // FNV-1a 的 32 位偏移基（offset basis）。
  const int fnvOffset = 0x811c9dc5;
  // FNV-1a 的 32 位质数（每轮乘它）。
  const int fnvPrime = 0x01000193;
  int h = fnvOffset;
  for (final int unit in s.codeUnits) {
    h ^= unit;
    // Dart 的 int 是 64 位，这里 & 0xFFFFFFFF 把结果约束回 32 位无符号范围，
    // 同时保证结果恒为非负数（避免后续取模出现负数色相）。
    h = (h * fnvPrime) & 0xFFFFFFFF;
  }
  return h;
}

/// 取用于显示的首字符（大写）。
///
/// 规则：
/// - 去首尾空白后为空 → 返回 null（调用方据此改画人形图标）；
/// - 否则取**第一个 Unicode 码点**（用 runes 而非下标，避免把 emoji / 生僻字
///   按 UTF-16 拆成半个代理对而显示成乱码）；
/// - 中文昵称返回单个汉字，英文昵称返回大写字母，数字编号返回原数字。
String? initialOf(String? label) {
  final String text = (label ?? '').trim();
  if (text.isEmpty) return null;
  return String.fromCharCode(text.runes.first).toUpperCase();
}

/// 由 seed 派生的一组稳定配色。
///
/// 用 HSL 而不是 HSV：HSL 的 lightness 单独控制明暗，
/// 能保证任意色相下白字前景都有足够对比度。
class LocalAvatarPalette {
  /// 构造一组配色（通常不直接调用，走 [LocalAvatarPalette.ofSeed]）。
  const LocalAvatarPalette({
    required this.start,
    required this.end,
    required this.foreground,
  });

  /// 渐变起始色（左上）。
  final Color start;

  /// 渐变结束色（右下）；与起始色相差约 40° 色相，让圆形有立体感。
  final Color end;

  /// 前景色（首字符用）。当前固定为白色：底色亮度被限制在 0.5~0.68，
  /// 白字在任何色相下都清晰可读。
  final Color foreground;

  /// 由 seed 稳定派生配色。
  ///
  /// 参数：[seed] 决定色相与饱和度；同一个 seed 永远得到同一结果。
  factory LocalAvatarPalette.ofSeed(String? seed) {
    final int hash = hashSeed(seed);

    // 色相：取哈希低 9 位映射到 0~359。
    final double hue = (hash % 360).toDouble();
    // 饱和度：取哈希的另一个位段，在 0.52~0.71 间浮动，避免所有头像一个调。
    final double sat = 0.52 + ((hash >> 9) % 20) / 100.0;
    // 亮度：起始 0.52 / 结束 0.66，保证配白字不刺眼也不发灰。
    const double lightStart = 0.52;
    const double lightEnd = 0.66;

    return LocalAvatarPalette(
      start: HSLColor.fromAHSL(1.0, hue, sat, lightStart).toColor(),
      end: HSLColor.fromAHSL(1.0, (hue + 40) % 360, sat, lightEnd).toColor(),
      foreground: Colors.white,
    );
  }
}

/// 本地生成的圆形头像：渐变底色 + 首字符（无网络、无外部依赖）。
///
/// 用途：作为 `Image.network` 的 `errorBuilder` 兜底，或在没有头像 URL 时
/// 直接作为默认头像展示。
///
/// 参数：
/// - [seed] 决定配色，必须是**稳定值**（用户 ID / 邮箱 / 头像编号），
///   不要传会变化的内容，否则每次 rebuild 颜色都会跳；
/// - [label] 决定中间显示的字符，取首字符转大写；为空则退化成人形图标；
/// - [size] 边长（正方形内含圆形）；
/// - [fontScale] 首字符字号占边长的比例，网格缩略图可传小一点；
/// - [backgroundColor] 需要与外部容器同色时才传，一般保持 null。
class LocalAvatar extends StatelessWidget {
  /// 创建一个本地生成的圆形头像。
  const LocalAvatar({
    super.key,
    required this.seed,
    this.label,
    this.size = kLocalAvatarDefaultSize,
    this.fontScale = kLocalAvatarFontScale,
    this.backgroundColor,
  });

  /// 决定配色的稳定种子（同一 seed 永远同色）。
  final String? seed;

  /// 决定中间显示字符的文本（取首字符）。
  final String? label;

  /// 边长（逻辑像素）。
  final double size;

  /// 首字符字号占 [size] 的比例。
  final double fontScale;

  /// 背景色；null 时用主题的中性表面色（无 seed 的兜底态使用）。
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? initial = initialOf(label);
    final bool hasSeed = (seed ?? '').trim().isNotEmpty;

    // 无 seed 时没有可派生的配色，退化成中性底 + 人形图标，
    // 保证「完全没有用户信息」的场景下也不会出现空白色块。
    if (!hasSeed) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final LocalAvatarPalette palette = LocalAvatarPalette.ofSeed(seed);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[palette.start, palette.end],
          ),
        ),
        child: initial == null
            ? null
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: size * fontScale,
                    fontWeight: FontWeight.w600,
                    // 略微拉开字距，单字符居中时视觉上更稳。
                    letterSpacing: size * 0.01,
                    // 加一层极淡的描边，避免浅色底上白字发虚。
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
