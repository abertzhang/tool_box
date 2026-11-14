// ============================================================================
// 文件：feature/profile/page/edit_profile_page.dart
// 模块：个人中心（profile）/ 编辑资料
//
// 职责：
//   提供「修改昵称 + 选择头像」的编辑页，由资料页点击头像 push 进入
//   （路由 `/profile/edit`）。保存时把昵称与头像写回 `public.users`，
//   成功后 invalidate 资料 Provider 并返回，资料页的头像 / 昵称随即更新。
//
// 交互约定：
//   1. 顶部大头像 = 实时预览，展示「当前选中的头像」，未选则展示账号现有头像；
//   2. 下方 10 张随机头像网格（5 列 × 2 行），点选即切换预览，选中项加主题色描边；
//   3. 「换一批」重新随机 10 张（保留当前选中项，避免选好的头像消失后无从找回）；
//   4. 昵称必填，最长 24 字；
//   5. 保存按钮**固定在页面底部**（不随内容滚动）：内容再长也永远点得到，
//      底部栏带分隔线与 SafeArea，避开圆角手势区。
//
// 关键依赖：
//   - flutter_riverpod：ConsumerStatefulWidget，watch 登录态与资料、invalidate 刷新。
//   - supabase_flutter + saveUserProfile：写回 `public.users`（RLS 限制只能改自己那行）。
//   - avatar_catalog：头像 URL 拼接与随机抽取（编号规则集中在该文件）。
//   - go_router：保存成功后 pop 返回资料页。
//   - AppLocalizations：页面文案全部走 i18n（中/英）。
//
// 配色说明：
//   本页统一取 Material 3 的 ColorScheme（surface / surfaceContainerLow /
//   primary / onSurface …），由 AppTheme 的浅色与深色两套方案自动适配，
//   不再像资料页那样自建调色板，避免同一模块两套色值各改各的。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../model/user_profile.dart';
import '../provider/user_profile_provider.dart';
import '../util/avatar_catalog.dart';
import '../util/local_avatar.dart';

/// 昵称最大长度。
///
/// 后端是 text 字段没有长度限制，这里只是 UI 层的合理约束：
/// 资料页昵称只显示一行，过长会被省略号截断，等于白填。
const int _maxNameLength = 24;

/// 「用户还没有任何头像」时，本地兜底头像使用的固定配色种子。
///
/// 必须是常量：兜底色要稳定，不能每次 rebuild 都换颜色。
const String _kNoAvatarSeed = 'no-avatar';

/// 顶部大头像预览的边长。
///
/// 2026-09-04 由 96 调到 84：候选格子缩小后，96 的预览显得过于突兀，
/// 收一点让整页重心回到「昵称输入」上，同时仍明显大于候选格子（约 60）。
const double _previewSize = 84;

/// 头像网格**每行**的列数：固定 5 列，不随每批数量变化。
///
/// 为什么固定而不是「等于 avatarBatchSize」：数量是 10 时若列数也跟着变 10，
/// 10 个格子挤一行只有 30px 出头，头像彻底看不清。固定 5 列后
/// 每行格子约 61px，10 张排成 5 列 × 2 行，行数由 Wrap 自动换行决定。
const int _gridColumns = 5;

/// 网格单元边长上限（逻辑像素）。
///
/// 大屏（平板 / 桌面 / 横屏）上若纯粹按列数等分，格子会被拉到 100+ px，
/// 一排大圆头喧宾夺主。给个上限，超出后整行居中留白，视觉更稳。
const double _gridCellMax = 68;

/// 网格单元间距（水平与垂直同值）。
const double _gridSpacing = 14;

/// 编辑资料页。
///
/// 入口：资料页点击头像（仅登录态）。未登录或未配置 Supabase 时
/// 由路由守卫式地在 [_buildGuard] 里给出提示，不渲染表单。
class EditProfilePage extends ConsumerStatefulWidget {
  /// 创建编辑资料页。
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  /// 昵称输入框控制器。
  late final TextEditingController _nameCtrl;

  /// 昵称表单校验器（与注册页一致，通过 GlobalKey 触发）。
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// 当前展示的 20 个候选头像编号。
  late List<int> _candidates;

  /// 当前选中的头像编号；null = 保持账号现有头像（例如 Google 头像）。
  int? _selected;

  /// 是否已用资料初始化过输入框（避免每次 rebuild 都覆盖用户正在输入的内容）。
  bool _inited = false;

  /// 是否正在提交（按钮进入 loading 并禁用，防重复点击）。
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    // 候选头像在 initState 里就随机好：放在 build 里会每次重建都换一批，
    // 导致用户点选后列表「洗牌」，选中项乱跳。
    _candidates = randomAvatarIndices();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// 用已加载的资料初始化表单（只做一次）。
  ///
  /// 为什么不在 initState 里做：`userProfileProvider` 是异步的，
  /// initState 执行时很可能还是 loading，拿不到 display_name / avatar_url。
  /// 这里放在 build 开头做「惰性初始化」：资料一到位就填一次，之后 `_inited`
  /// 置 true，用户后续输入不会被覆盖。
  void _ensureInitialized(UserProfile? profile, User? user) {
    if (_inited) return;
    _inited = true;
    _nameCtrl.text = _initialName(profile, user);
    final current = parseAvatarIndex(profile?.avatarUrl);
    _selected = current;
    // 若当前头像属于内置库但没被随机到，把它塞进候选列表首位，
    // 让用户能看到「当前用的是哪一个」，而不是网格里一个都不高亮。
    if (current != null && !_candidates.contains(current)) {
      _candidates = <int>[current, ..._candidates.take(_candidates.length - 1)];
    }
  }

  /// 昵称初始值：资料昵称 → 邮箱前缀 → 空串。
  String _initialName(UserProfile? profile, User? user) {
    final name = profile?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = user?.email?.trim();
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return '';
  }

  /// 换一批候选头像。
  ///
  /// 保留当前选中项（放在新列表首位）：用户可能已经挑中一张，
  /// 换批只是为了看更多选择，不该把已选中的弄丢。
  /// 连续「换一换」的次数，进入本页后从 0 开始累计。
  ///
  /// 为什么关心这个：连续换很多次说明**内置头像库不够用**
  /// 或缺少「上传自定义头像」能力，是明确的改进信号。
  int _shuffleCount = 0;

  void _shuffle() {
    setState(() {
      final keep = _selected;
      final next = randomAvatarIndices();
      _candidates = keep == null
          ? next
          : <int>[keep, ...next.where((i) => i != keep).take(next.length - 1)];
    });
    _shuffleCount++;
    AppTrack.log(
      TrackEvents.profileAvatarShuffle,
      params: <String, Object?>{'count': _shuffleCount},
    );
  }

  /// 比对本次保存相对云端已有资料改了哪些字段。
  ///
  /// - [profile]：云端现有资料（可能为 null，未建过资料时）；
  /// - [finalAvatar]：本次将写入的头像 URL。
  ///
  /// 返回值如 `{'nickname', 'avatar'}`；没改动时返回空集合。
  /// 必须在写库**之前**调用 —— 保存后 [profile] 已是新值，比对将永远为空。
  Set<String> _diffChangedFields(UserProfile? profile, String? finalAvatar) {
    final Set<String> changed = <String>{};
    final String newName = _nameCtrl.text.trim();
    if (newName != (profile?.displayName ?? '')) {
      changed.add('nickname');
    }
    if (finalAvatar != profile?.avatarUrl) {
      changed.add('avatar');
    }
    return changed;
  }

  /// 提交保存。
  ///
  /// 流程：校验 → 写库 → 刷新资料 Provider → 提示 → 返回。
  /// 失败时不 pop：保留页面与已编辑内容，让用户可以直接重试。
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast(l10n.profileEditNeedLogin);
      return;
    }
    // 在 await 之前取 messenger，避免跨异步间隙后再用 BuildContext。
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      // 头像取值优先级：网格里新选的 → 账号现有头像（Google 头像等）。
      // 两者都为空时传 null，saveUserProfile 会省略该字段而不是写空，
      // 从而不会把已有头像清掉。
      final profile = ref.read(userProfileProvider).value;
      final String? finalAvatar = _selected != null
          ? avatarUrlOf(_selected!)
          : profile?.avatarUrl;
      // 保存**前**先算好改了什么：成功后 profile 已被覆盖，届时再比对永远是「没变」。
      final Set<String> changed = _diffChangedFields(profile, finalAvatar);

      await saveUserProfile(
        userId: user.id,
        displayName: _nameCtrl.text.trim(),
        avatarUrl: finalAvatar,
        email: user.email,
      );
      // 让资料页重新拉取视图，头像与昵称立即更新。
      refreshUserProfile(ref);

      // 资料完善率埋点：完善率高的用户往往留存更好，
      // 可用来验证「引导完善资料」这件事是否值得做。
      AppTrack.log(
        TrackEvents.profileEditSaved,
        params: <String, Object?>{
          // 只上传「改了哪些字段」，不上传昵称 / 头像 URL 原值（隐私红线）。
          'changed': changed.toList()..sort(),
          'avatar_source': _selected == null ? 'unchanged' : 'preset',
        },
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditSaved),
          duration: const Duration(seconds: 1),
        ),
      );
      context.pop();
    } catch (e, st) {
      debugPrint('[EditProfile] 保存资料失败: $e');
      debugPrint('$st');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          // 带上原始错误，便于定位是 RLS 拒绝（42501）、
          // 表缺 GRANT 还是网络问题，而不是只给一句「保存失败」。
          content: Text('${l10n.profileEditFailed}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Supabase 是否可用 + 当前用户（决定渲染表单还是提示态）。
    final ready = ref.watch(supabaseReadyProvider);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider).value;
    if (ready && user != null) {
      // 只在登录态下初始化，避免未登录时用空值污染一次表单。
      _ensureInitialized(profile, user);
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: ready && user != null
          ? _buildForm(context, scheme, l10n, profile, user)
          : _buildGuard(context, scheme, l10n),
    );
  }

  /// 未登录 / Supabase 未配置时的提示态。
  ///
  /// 正常流程进不到这里（资料页未登录时点头像是跳登录），
  /// 保留它是为了兜住「深链直达 /profile/edit」这类入口。
  Widget _buildGuard(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.profileEditNeedLogin,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 表单主体：头像预览 + 昵称输入 + 头像网格 + 保存按钮。
  Widget _buildForm(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n,
    UserProfile? profile,
    User user,
  ) {
    // 预览区展示的 URL：优先网格里新选的，否则账号现有头像（可为 null → 占位）。
    final String? previewUrl = _selected != null
        ? avatarUrlOf(_selected!)
        : profile?.avatarUrl;
    // 网格单元边长：屏宽减去左右内边距(16×2)与列间距后按列数等分，
    // 再用 _gridCellMax 封顶 —— 大屏上格子不会被拉成一排过大的圆。
    final double gridW = MediaQuery.of(context).size.width - 32;
    final double cell =
        ((gridW - _gridSpacing * (_gridColumns - 1)) / _gridColumns).clamp(
          0.0,
          _gridCellMax,
        );

    // 布局：上「可滚动内容区」+ 下「固定保存栏」。
    //
    // 为什么要把保存按钮钉在底部：候选头像一多（10 张 = 2 行），
    // 小屏上按钮就会被顶到屏幕外，用户得先滚到底才能保存，
    // 甚至怀疑「点了没反应」。钉住之后，内容再长按钮也永远可点。
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // 1) 大头像预览。
                //
                // 兜底配色种子：有头像 URL 时用 URL（同一张图永远同色）；
                // 没有头像时退回到邮箱（用户维度稳定，不会随输入跳色）。
                Center(
                  child: _AvatarImage(
                    url: previewUrl,
                    size: _previewSize,
                    borderWidth: 3,
                    borderColor: scheme.surfaceContainerHighest,
                    localSeed: previewUrl ?? (profile?.email ?? _kNoAvatarSeed),
                    localLabel: _nameCtrl.text,
                  ),
                ),
                const SizedBox(height: 6),
                // 预览下方说明：区分「内置头像 / 当前头像」两种来源。
                Center(
                  child: Text(
                    l10n.profileEditCurrent,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2) 昵称输入。
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _nameCtrl,
                    maxLength: _maxNameLength,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.profileEditName,
                      hintText: l10n.profileEditNameHint,
                      prefixIcon: const Icon(Icons.person_outline),
                      // 有了 maxLength 自带的计数器，这里不再叠加 helperText，
                      // 避免输入框下方挤两行。
                      counterText: '',
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return l10n.profileEditNameEmpty;
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // 3) 头像选择区：标题 + 换一批。
                Row(
                  children: [
                    Text(
                      l10n.profileEditAvatarTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _saving ? null : _shuffle,
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: Text(l10n.profileEditShuffle),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 10 张候选头像，每行 5 列（自动换行成 2 行）；
                // 大屏被 _gridCellMax 封顶后整行居中留白。
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: _gridSpacing,
                  runSpacing: _gridSpacing,
                  // 用位置索引（0 起）而不是头像编号作为 Key 的组成部分：
                  // 编号是随机的，测试无法预判；位置是稳定的，便于集成测试命中。
                  children: List<Widget>.generate(_candidates.length, (
                    position,
                  ) {
                    final index = _candidates[position];
                    final selected = _selected == index;
                    return GestureDetector(
                      // Key 供集成测试稳定命中某个候选头像（不依赖图片是否加载成功）。
                      key: Key('avatar-option-$position'),
                      onTap: _saving
                          ? null
                          : () => setState(() => _selected = index),
                      child: _AvatarImage(
                        url: avatarUrlOf(index),
                        size: cell,
                        borderWidth: selected ? 3 : 0,
                        borderColor: selected
                            ? scheme.primary
                            : Colors.transparent,
                        // 按 3 倍像素比解码：格子只有 60 出头，
                        // 按原图（几百 px）解码纯属浪费内存。
                        cacheWidth: (cell * 3).round(),
                        showCheck: selected,
                        // 兜底：种子用编号（同一编号永远同色，换一批后仍能认出来），
                        // 中间显示编号数字（去掉前导零，如 42），
                        // 这样即便图床全挂，用户依然能挑一个并正常保存。
                        localSeed: 'avatar-$index',
                        localLabel: '$index',
                        // 编号最多 3 位数字，字号按比例缩小一点才放得下。
                        localFontScale: 0.30,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        // ── 固定底栏：保存按钮不随内容滚动 ──
        _buildFooter(context, scheme, l10n),
      ],
    );
  }

  /// 固定在页面底部的保存栏。
  ///
  /// 组成：顶部一道分隔线 + 内边距 + 50px 高的保存按钮 + `SafeArea`（只避下边）。
  /// 用 `DecoratedBox` 画分隔线而不是 `Divider` Widget，避免多一层无用节点。
  ///
  /// `SafeArea(top: false)`：只避让底部（手势条 / 圆角区），
  /// 顶部由 AppBar 与系统状态栏负责，再避一次反而多出空白。
  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            // width 必须显式写 infinity：外层 Padding 传下来的宽度约束是
            // **loose** 的（只给上限、不给下限），只钉 height 的话
            // FilledButton 会 shrink-wrap 到「文字 + 内边距」的宽度
            // （实测「保存」只有 76px），看起来就是个窄窄的小按钮。
            // 写了 infinity 才会撑满内容区宽度（= 屏宽 - 左右各 16 的
            // 内边距），与上方昵称输入框左右边缘对齐。
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      l10n.profileEditSave,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 轻量提示。
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 圆形头像图片（带边框 / 选中打勾 / 加载与失败兜底）。
///
/// 单独抽成 Widget 是为了让「96px 预览」与「网格缩略图」共用同一套
/// 加载失败兜底逻辑，避免两处各写一遍 errorBuilder。
///
/// ★ 兜底策略（2026-09-04 改）：加载失败时不再显示灰色人形图标，
/// 而是显示 [LocalAvatar] —— 由 seed 稳定生成的彩色渐变圆形头像。
/// 理由：图床不可用时（曾被 Cloudflare 挑战拦截、断网、图床迁移等），
/// 所有候选格子会退化成一模一样的灰色人形，用户既看不出区别、也没法选。改用本地头像后，每个格子根据编号
/// 得到不同配色并显示编号，**用户仍能正常挑选与保存**，
/// 存进 avatar_url 的值不变，将来图床放行后自动显示真图。
class _AvatarImage extends StatelessWidget {
  /// 创建圆形头像。
  const _AvatarImage({
    required this.url,
    required this.size,
    this.borderWidth = 0,
    this.borderColor = Colors.transparent,
    this.cacheWidth,
    this.showCheck = false,
    this.localSeed,
    this.localLabel,
    this.localFontScale,
  });

  /// 图片地址；为 null 或空串时直接渲染本地头像。
  final String? url;

  /// 边长（正方形内含圆形）。
  final double size;

  /// 描边宽度（选中态用 3，普通态 0）。
  final double borderWidth;

  /// 描边颜色（选中态用主题主色）。
  final Color borderColor;

  /// 解码宽度提示；缩略图传小值可显著降低内存占用。
  final int? cacheWidth;

  /// 是否在右下角叠加「已选中」对勾。
  final bool showCheck;

  /// 本地兜底头像的配色种子。
  ///
  /// 必须传**稳定值**（头像编号 / 用户邮箱 / 用户 ID），
  /// 否则每次 rebuild 颜色都会跳变。为 null 时退化成人形图标。
  final String? localSeed;

  /// 本地兜底头像中间显示的文本（自动取首字符并转大写）。
  final String? localLabel;

  /// 本地兜底头像的首字符字号比例；不传则用 [kLocalAvatarFontScale]。
  final double? localFontScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 兜底：由 seed 稳定生成的彩色头像。
    // 图床不可达 / 断网 / 用户本来就没头像时都会走到这里，
    // 保证网格里每个格子各自可辨识、不会糊成一片灰色。
    final Widget placeholder = LocalAvatar(
      seed: localSeed,
      label: localLabel,
      size: size - borderWidth * 2,
      fontScale: localFontScale ?? kLocalAvatarFontScale,
      backgroundColor: scheme.surfaceContainerHighest,
    );

    final String? src = (url == null || url!.isEmpty) ? null : url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: src == null
                ? placeholder
                : Image.network(
                    src,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    // 类浏览器请求头：图床有 Cloudflare 防护，
                    // 默认 Dart UA 可能被判为机器人而拿到 403 挑战页。
                    headers: avatarImageHeaders,
                    // 加载中先垫占位，避免格子空白闪烁。
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return placeholder;
                    },
                    // 加载失败（含 403 挑战页、网络异常）一律回落占位头像。
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
          // 选中对勾：贴在右下角，用主色实心圆 + 白色勾，辨识度高。
          if (showCheck)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  Icons.check,
                  size: size * 0.18,
                  color: scheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
