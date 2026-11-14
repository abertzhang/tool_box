// ============================================================================
// 文件：feature/profile/util/avatar_catalog.dart
// 模块：个人中心（profile）/ 头像目录
//
// 职责：
//   集中管理「内置头像库」的 URL 拼接规则与随机抽取逻辑，供编辑资料页
//   （EditProfilePage）与资料页头像展示复用。把规则收在一处，将来图床换域名、
//   改编号位数、扩容量时只改本文件即可。
//
// 图床约定（与后端约定，改动前先确认）：
//   根路径  https://img-common.aknot.uk/avatar
//   文件名  avatar-<编号>.jpg，编号 4 位、不足补前导零
//   编号范围 0000 ~ 0499（共 500 张）
//
// 关键依赖：dart:math（随机抽取）。
//
// 历史问题与现状（2026-09-04 更新，**结论已变，别再按旧注释排查**）：
//   该域名由 Cloudflare 防护，曾对**非浏览器客户端**一律返回 403 的 JS 挑战页：
//     · 图片地址与内容本身都正确，浏览器（登录 Cloudflare 后）可正常看图；
//     · 但 curl / 本 App 一律 403，响应头带 `cf-mitigated: challenge`，
//       正文是 `Just a moment... Enable JavaScript and cookies to continue`；
//     · **连不存在的路径也返 403** —— 说明拦截发生在边缘层、在源站响应之前，
//       因此**当时不能用状态码判断某张图是否存在**；
//     · 加请求头无效：默认 UA / iPhone Safari UA / 全套 Sec-CH-UA + Sec-Fetch /
//       Googlebot UA 实测全部 403。根因是 dart:io 的 HttpClient 不执行 JS、
//       也不保存 cf_clearance cookie，永远过不了挑战。
//   ✅ **2026-09-04 晚已在平台侧解决**：给 `img-common.aknot.uk/avatar/*`
//   加了 WAF「Skip」规则后放行，复测 0000/0001/0042/0250/0499 全部
//   `200 image/jpeg`（约 10KB/张），App 与 curl 均可直取，无需改代码。
//   完整解法与排查步骤见 cloudflare-image-host/README.md §9.4。
//
// 保留的防御性设计（即便已放行也不要删）：
//   · 上述请求头 [avatarImageHeaders]，便于图床侧统计识别与内容协商；
//   · App 端所有 Image.network 仍挂 errorBuilder，加载失败时回落本地生成头像，
//     不会白屏或抛异常 —— 图床再次被拦 / 断网 / 用户用 Google 头像时依然可用。
// ============================================================================

import 'dart:math';

/// 头像图床根目录（不带结尾斜杠）。
const String avatarBaseUrl = 'https://img-common.aknot.uk/avatar';

/// 头像总数：编号 0 ~ 499。
const int avatarTotal = 500;

/// 一次随机展示的头像数量（需求：给用户 10 张可选）。
///
/// 数量经过两轮调整（2026-09-04）：
///   20 → 5：20 张占 5 行，把保存按钮顶到屏幕外；5 张又偏少，选择面太窄。
///   5  → 10：折中为 10 张（5 列 × 2 行），一屏内放得下，选择面也够。
/// 改这里即可：网格每行固定 5 列，行数随数量自动增加（10 张 = 5 列 × 2 行）。
/// 注意同步集成测试里锁数量的断言（avatat-option-9 存在 / -10 不存在）。
const int avatarBatchSize = 10;

/// 文件名中编号的位数（不足补前导零）：0000 ~ 0499。
const int avatarIndexWidth = 4;

/// 图片扩展名（小写）。
const String avatarExtension = 'jpg';

/// 供 Image.network 使用的请求头。
///
/// ⚠️ 2026-09-04 实测更正：**这些头并不能解除 Cloudflare 的拦截**。
/// 原先注释写「可显著降低被拦截的概率」是错误结论 —— 带上完整浏览器头
/// （含 Sec-CH-UA / Sec-Fetch-*）后依然 403，因为拦的是 JS 挑战而非 UA 判定，
/// 客户端不执行 JS 就拿不到 cf_clearance。
///
/// 保留它们的真实理由只有两个：
///   1. 图床侧做统计分析时能把 App 请求识别出来，而不是显示成 `Dart/x.y`；
///   2. 将来平台侧配好 WAF Skip 规则后，带正常的 Accept 头有助于内容协商。
/// 真正解决取图失败要靠平台侧放行，见 cloudflare-image-host/README.md §9.4。
const Map<String, String> avatarImageHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 '
      'Safari/604.1',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// 匹配头像文件名里的编号，如 `.../avatar-0042.jpg`。
///
/// 不区分大小写、允许常见图片扩展名，便于将来图床改格式时仍能反解。
final RegExp _avatarIndexPattern = RegExp(
  r'avatar-(\d+)\.(?:jpg|jpeg|png|webp)(?:$|[?#])',
  caseSensitive: false,
);

/// 按编号拼接头像完整 URL。
///
/// 参数：[index] 头像编号，必须在 [0, avatarTotal) 区间内。
/// 越界时不会抛异常——按取模折算到合法区间，保证 UI 永远拿得到一个可请求的地址
/// （真正的兜底由 Image.network 的 errorBuilder 负责）。
String avatarUrlOf(int index) {
  final safe = ((index % avatarTotal) + avatarTotal) % avatarTotal;
  final padded = safe.toString().padLeft(avatarIndexWidth, '0');
  return '$avatarBaseUrl/avatar-$padded.$avatarExtension';
}

/// 随机抽取 [count] 个不重复的头像编号。
///
/// 做法：先构造 0..total-1 的全量池再洗牌取前 N 个。
/// 500 个元素的洗牌是微秒级开销，比「随机取 + 去重重试」更简洁且无死循环风险。
///
/// 参数：
/// - [count] 需要的数量，默认 [avatarBatchSize]（当前 10）；超过总数时截断为总数；
/// - [random] 可选随机源，便于测试时注入固定种子复现结果。
List<int> randomAvatarIndices({int count = avatarBatchSize, Random? random}) {
  final int n = count < 0 ? 0 : (count > avatarTotal ? avatarTotal : count);
  if (n == 0) return const <int>[];
  final List<int> pool = List<int>.generate(avatarTotal, (i) => i)
    ..shuffle(random ?? Random());
  return pool.take(n).toList(growable: false);
}

/// 从头像 URL 反解编号。
///
/// 返回值：
/// - 命中本目录命名规则且在合法区间 → 对应编号；
/// - 不是本目录的头像（例如 Google 账号头像）或解析失败 → null。
///   调用方据此判断「当前头像属于内置库」还是「外部头像」，
///   后者在头像网格里没有高亮项，但仍可在预览区原样展示。
int? parseAvatarIndex(String? url) {
  if (url == null || url.isEmpty) return null;
  final match = _avatarIndexPattern.firstMatch(url);
  if (match == null) return null;
  final value = int.tryParse(match.group(1)!);
  if (value == null) return null;
  return (value >= 0 && value < avatarTotal) ? value : null;
}
