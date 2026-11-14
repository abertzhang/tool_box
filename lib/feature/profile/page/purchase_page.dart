// ============================================================================
// 文件：feature/profile/page/purchase_page.dart
// 模块：个人中心（profile）· 会员购买（独立页面，非弹窗）
//
// 职责：
//   把「拉起会员购买」从原先的 iOS 系统购买确认弹窗（底部 sheet）改为一个
//   **独立、可导航的页面**。用户从 profile 页 VIP 卡「Upgrade Now」或
//   tools 页顶部会员状态条（未购买时）点击后 push 进入本页，而非弹窗。
//
// 设计要点（沿用原 openMembershipPurchase 的既有结论）：
//   - 不检查登录态：买断权益绑定 Apple ID / Google 账号，未登录 App 账号也能买
//     （方案 A：纯端侧，2026-09-04 确认）。
//   - 页面本身就是「确认步骤」：商品名 / 价格优先取商店返回的本地化值，
//     商店未配置（开发环境常态）时兜底「Pro Unlock」/「$1.99」，保证配置阶段
//     也能预览完整页面。用户点「Upgrade Now」即直接调起真实系统支付，
//     不再有额外的二次确认弹窗层。
//   - 购买结果由 purchaseStream 异步回送并更新 membershipProvider.owned，
//     本页通过 ref.listen 监听 owned 由 false→true 的跃迁，弹「会员已生效」并自动返回。
//
// 配色：统一用 [Theme.of] 的 [ColorScheme]，与 profile 页 / 其他页面一致，
//   明暗主题由 Material 自动切换，无需手动传 dark 标志。
//
// 埋点（漏斗三段，source 区分来源便于分区观察）：
//   1. vipSheetShown      —— 页面曝光（转化率分母，initState 里记录**一次**）；
//   2. vipSheetConfirmed  —— 用户点了购买按钮（曝光 → 确认）；
//   3. vipPurchaseResult  —— 拉起系统支付的结果（started / store_unavailable /
//      product_missing 三种必须区分）。
//   注：事件名沿用旧 sheet 时期的命名（vip_sheet_*），以保持漏斗数据连续，
//   语义上等价于「页面曝光 / 按钮点击 / 拉起结果」。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/ads/rewarded_ad_helper.dart';
import 'package:tool_box/common/provider/app_settings/free_usage_provider.dart';
import 'package:tool_box/common/auth/member_bind_service.dart';
import 'package:tool_box/feature/profile/provider/membership_provider.dart';
import 'package:tool_box/feature/profile/provider/user_profile_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 会员购买独立页面（买断制 IAP）。
///
/// 由 profile 页 VIP 卡「Upgrade Now」与 tools 页会员状态条（未购买时）push 进入。
///
/// 参数：
/// - [source]：埋点来源标识（'profile' / 'tool_page'），默认 'profile'，
///   用于在漏斗事件里区分入口，不影响购买逻辑本身。
class PurchasePage extends ConsumerStatefulWidget {
  /// 创建会员购买页面。
  ///
  /// [source] 透传到埋点，表明用户从哪个入口进来。
  const PurchasePage({super.key, this.source = 'profile'});

  /// 埋点来源标识。
  final String source;

  @override
  ConsumerState<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends ConsumerState<PurchasePage> {
  /// 是否正在调起系统支付（用于按钮 loading 态，避免重复点击）。
  bool _buying = false;

  /// 是否正在恢复购买（按钮 loading 态）。
  bool _restoring = false;

  /// 是否正在加载/展示插页广告（按钮 loading 态，防重复点击）。
  bool _watchingAd = false;

  @override
  void initState() {
    super.initState();

    // 漏斗第 1 层：页面曝光（转化率分母）。必须在 initState 里只记**一次** ——
    // 放在 build 里会因多次重建重复计数。购买链路是唯一必须立刻落库的分支，
    // 用 logNow 而非 log，等批量窗口可能丢事件。
    final membership = ref.read(membershipProvider);
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipSheetShown,
        params: <String, Object?>{
          'product': kMemberProductId,
          // 价格是商店返回的本地化字符串（'$1.99' / '¥15.00'），不含用户标识，
          // 可安全上报；用于按地区观察价格对转化的影响。
          'price': membership.price ?? r'$1.99',
          // 商品是否已从商店取到：开发环境常态为 false，
          // 用它过滤掉「商品未配置」时期的脏数据，别拿去算转化率。
          'product_ready': membership.hasProduct,
          'source': widget.source,
        },
      ),
    );

  }

  /// 点击「Upgrade Now」：拉起系统支付（买断型 non-consumable）。
  ///
  /// 商店不可用 / 商品未上架时给出可预期降级提示，不调起支付。
  Future<void> _onBuy() async {
    final l10n = AppLocalizations.of(context)!;
    final membership = ref.read(membershipProvider);

    // 商店不可用（断网 / 沙盒未配 / 未登录商店账号）：直接提示，不拉起支付。
    if (!membership.storeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.vipPayStoreUnavailable),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    // 商品未上架（开发环境常见）：明确提示，不抛异常。
    if (!membership.hasProduct) {
      // ★ debug 包自解释：debug/侧载 APK 在 Android 上**查不到** Google Play 商品
      //   （Play Billing 只对从 Play 安装的应用返回商品，这是 Google 的硬性规定），
      //   用户很容易误以为代码/商品 ID 出错。这里在 debug 模式给出明确指引，
      //   release 模式（从 Play 安装）仍走原本地化文案。
      final message = kDebugMode
          ? l10n.vipPayDebugProductMissing
          : l10n.vipPayProductMissing;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // 漏斗第 2 层：曝光 → 确认。衡量页面文案与价格的说服力，是 A/B 定价核心指标。
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipSheetConfirmed,
        params: <String, Object?>{
          'product': kMemberProductId,
          'price': membership.price ?? r'$1.99',
          'source': widget.source,
        },
      ),
    );

    // 进入支付前捕获 messenger，规避 use_build_context_synchronously（buy 是异步）。
    final messenger = ScaffoldMessenger.of(context);
    // 按钮进入 loading 态，防止重复点击调起多个支付页。
    setState(() => _buying = true);
    final IapBuyResult result = await ref.read(membershipProvider.notifier).buy();
    if (mounted) setState(() => _buying = false);

    // 漏斗第 3 层：拉起系统支付的结果。三个值处置不同，必须区分。
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipPurchaseResult,
        params: <String, Object?>{
          'result': switch (result) {
            IapBuyResult.started => 'started',
            IapBuyResult.storeUnavailable => 'store_unavailable',
            IapBuyResult.productMissing => 'product_missing',
          },
          'source': widget.source,
        },
      ),
    );

    if (!mounted) return;
    switch (result) {
      case IapBuyResult.started:
        // 支付页已拉起：成败由购买流异步驱动，会员状态会自动刷新
        // （owned 跃迁后由 initState 的监听器弹「会员已生效」并自动返回）。
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.vipPaySheetOpened),
            duration: const Duration(seconds: 2),
          ),
        );
      case IapBuyResult.storeUnavailable:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.vipPayStoreUnavailable),
            duration: const Duration(seconds: 1),
          ),
        );
      case IapBuyResult.productMissing:
        // 与上方 _onBuy 的 hasProduct=false 分支保持一致：debug 包给出明确指引。
        final message = kDebugMode
            ? l10n.vipPayDebugProductMissing
            : l10n.vipPayProductMissing;
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  /// 点击「恢复购买」：触发系统恢复，结束后按是否命中权益提示。
  ///
  /// App Store 对买断型商品的审核硬要求：必须提供恢复入口。
  /// iOS 重装后靠这里拿回权益；Android 为幂等重查活跃购买。
  Future<void> _onRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // ★ 与 profile 页同一条规则（见 settledIsMember）：已是会员就不必查商店。
    //   此前这里缺短路，云端会员点恢复会收到「未找到可恢复的购买记录」。
    if (await settledIsMember(ref)) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.vipRestoreAlready),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _restoring = true);
    // 恢复是异步（iOS 会弹 Apple ID 登录框）；await 后读 owned 区分命中与否。
    await ref.read(membershipProvider.notifier).restore();
    if (mounted) setState(() => _restoring = false);

    // 恢复结果事件：owned 是否因此翻 true，区分「已恢复」与「无可恢复记录」。
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipRestoreResult,
        params: <String, Object?>{
          'owned': ref.read(membershipProvider).owned,
          'source': widget.source,
        },
      ),
    );

    if (!mounted) return;
    final owned = ref.read(membershipProvider).owned;
    if (!mounted) return;
    // Android 空结果要提示「换 Google Play 账号」（见 settledIsMember 处说明）。
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          owned
              ? l10n.vipRestoreDone
              : (isAndroid ? l10n.vipRestoreCheckAccount : l10n.vipRestoreEmpty),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 点击「观看一次获得 5 次免费使用」：拉起**激励广告**，看完后发放 5 次并退回上上页。
  ///
  /// 流程：loading 态防重复点击 → [showRewardedAd] 全屏播放 →
  /// - 拿到奖励（[RewardedAdResult.earned]=true）：发放 [FreeUsageController.rewardPerAd]
  ///   次免费额度（独立奖励字段累加，**不封顶**），随后返回上上页；
  /// - 广告不可用（未展示）：提示稍后再试，停留本页；
  /// - 展示了但没走到奖励回调（用户中途退出）：提示未看完，同样不发奖——
  ///   中途退出也发奖等于白送，且会拖累激励广告的转化数据。
  /// 跨 await 前先捕获 [Navigator]，规避 use_build_context_synchronously。
  Future<void> _onWatchAd() async {
    if (_watchingAd) return;
    final l10n = AppLocalizations.of(context)!;
    // 先捕获 Navigator：广告流程含多次 await，跨 gap 用 context 会触发 lint。
    final navigator = Navigator.of(context);
    setState(() => _watchingAd = true);
    final RewardedAdResult result = await showRewardedAd(
      slot: 'purchase_ad_for_free',
    );
    if (!mounted) return;

    // 未获得奖励：复位按钮、仅提示，停留本页，不发放、不返回。
    if (!result.earned) {
      setState(() => _watchingAd = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // 区分两种失败：「广告压根没出来」与「出来了但没看完」，
          // 后者若提示「广告不可用」会让用户以为是 App 的锅。
          content: Text(result.shown ? l10n.adNotFinished : l10n.adUnavailable),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 广告看完并发奖：本地 + 云端同步累加奖励次数（不封顶）。
    await ref
        .read(freeUsageProvider.notifier)
        .grantRewardedUses(FreeUsageController.rewardPerAd);
    if (!mounted) return;

    // 反馈：明确告诉用户「已获得几次」，避免误以为没加（发奖后即返回上上页，
    // 若不做提示用户看不到额度变化）。
    final String msg = l10n.adRewardSuccess(FreeUsageController.rewardPerAd);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );

    // 短暂展示反馈后再返回「上上页」（需求明确要求：广告结束返回上上页）。
    // 两次 pop 各带 canPop 保护：若路由栈已到底（只剩首页根）则不再 pop，避免误退出 App。
    // 典型流程（tools/profile → 购买页）两次 pop 正好回到来源页 / 首页根；
    // 若来源弹框已在跳转前关闭、栈更浅，canPop 也会兜底只 pop 必要的层数。
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _watchingAd = false);
    if (navigator.canPop()) navigator.pop();
    if (navigator.canPop()) navigator.pop();
  }

  /// 「观看一次获得 5 次免费使用」按钮（位于「恢复购买」下方）。
  ///
  /// 文案直接写清「一次 5 次」，比旧的「最多 10 次」更可预期；下方显示剩余 / 总额度。
  /// 奖励次数**不封顶**，因此只有 loading 态禁用按钮，不存在「已满不能再看」。
  Widget _buildAdWatchButton(AppLocalizations l10n, ColorScheme scheme) {
    // 当前剩余 / 总额度（总额度 = 基础额度 + 广告奖励，会随看广告增长）。
    final FreeUsageState? usage = ref.watch(freeUsageProvider).value;
    final int remaining =
        usage?.remaining ?? FreeUsageController.maxFreeGuest;
    final int total = usage?.total ?? FreeUsageController.maxFreeGuest;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            // 仅 loading 中禁用（防重复点击调起多条广告）；奖励不封顶，故无「已满」态。
            onPressed: _watchingAd ? null : _onWatchAd,
            style: OutlinedButton.styleFrom(
              // 与上方购买按钮同款最小高度 56，内容超高自动长高、不裁字。
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _watchingAd
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.adWatchForFreeUses(FreeUsageController.rewardPerAd),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // 进度提示：当前剩余免费次数 / 总额度（总额度随看广告增长）。
        Text(
          l10n.adRewardProgress(remaining, total),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 会员到手后的「提示 + 自动返回」收尾（已登录自动绑定 / 恢复购买命中）。
  ///
  /// 与未登录新购的 [_autoLinkAfterPurchase] 二选一：后者会直接自动拉起平台
  /// 授权建号（强制自动建号），本方法用于已登录 / 恢复命中这类"无需再建号"的
  /// 场景。跨 build 间隙操作 UI 用 [SchedulerBinding.addPostFrameCallback]
  /// 兜住，并检查 mounted。
  void _showOwnedAndPop(AppLocalizations l10n) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.vipBecomeMember),
          duration: const Duration(seconds: 2),
        ),
      );
      // 购买成功后自动返回上一页（profile / tools），那里会即时显示 VIP 生效态。
      // 1.8s 后 pop；若用户已手动返回则 mounted 为 false，不会二次 pop。
      // 先在本同步帧捕获 Navigator，避免在延时闭包里跨 async gap 使用 context
      // （否则触发 use_build_context_synchronously lint）。
      final navigator = Navigator.of(context);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) navigator.pop();
      });
    });
  }

  /// 未登录新购后的强制收尾：直接自动拉起平台授权建号（不弹说明框）。
  ///
  /// 先给「会员已生效」的确定性反馈（本机权益已点亮），随后调用
  /// [MemberBindService.signInAndBind] 按平台拉起 Apple / Google 授权：
  /// - 授权成功 → 建号 + 写云端 is_member，刷新资料；
  /// - 用户取消 / 失败 → 留本机会员，不做报错，下次启动 App 会再提示（见
  ///   [MembershipController._autoRelinkOnLaunch]）。
  /// 不论结果，稍后返回上一页。
  Future<void> _autoLinkAfterPurchase() async {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      // 会员本机已生效的确定性反馈（复用既有文案）。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.vipBecomeMember),
          duration: const Duration(seconds: 2),
        ),
      );
      // await 前捕获 Navigator，规避跨 async gap 使用 context 的 lint。
      final navigator = Navigator.of(context);
      final MemberBindResult result = await MemberBindService.signInAndBind(
        source: 'purchase_prompt',
      );
      if (!mounted) return;
      if (result == MemberBindResult.ok) {
        // 绑定成功：失效资料 Provider，让云端 isMemberActive 立即生效。
        ref.invalidate(userProfileProvider);
      }
      // 无论绑定与否，稍后返回上一页（profile / tools 显示 VIP 生效态）。
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) navigator.pop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MembershipState membership = ref.watch(membershipProvider);

    // ★ 监听 owned 的 false→true 跃迁：购买成功（或恢复购买命中）时触发。
    //   注意：ref.listen 必须在 build 里调用 —— Riverpod 3.x 明确禁止在 initState
    //   同步调用 listen，否则会在 ConsumerStatefulElement.listen 抛 AssertionError 红屏。
    //   挂在 build 是 Riverpod 规范的写法，重建时重复注册是幂等的（只会保留一份监听）。
    //   不在此处记 vipActivated —— 该事件由 membershipProvider 在 purchaseStream
    //   回送时统一上报，避免把「拉起支付页」算成「成交」。
    ref.listen<MembershipState>(membershipProvider, (prev, next) {
      final wasOwned = prev?.owned ?? false;
      if (!wasOwned && next.owned) {
        // 会员从未持有 → 持有。按是否触发同步引导分两条收尾：
        if (next.needsSyncPrompt) {
          // 未登录新购：直接自动拉起平台授权建号（2026-11-08「强制自动建号」），
          // 不弹说明框；授权成功即建号 + 上云，取消则留本机会员、下次启动再提示。
          unawaited(_autoLinkAfterPurchase());
        } else {
          // 已登录自动绑定 / 恢复购买命中：沿用原「提示 + 自动返回」流程。
          _showOwnedAndPop(l10n);
        }
      }
    });

    return Scaffold(
      // 底色取 surface，与全局主题一致；明暗自动适配。
      backgroundColor: scheme.surface,
      appBar: AppBar(
        // 标题用购买页专用的「Tool Box Pro Unlock」。
        // 刻意不复用 vipTitle —— 那是会员区通用标题（'Pro Unlock'，无品牌前缀），
        // 被 profile 页 VIP 卡与 tools 页会员状态条共用，改它会连带影响那两处。
        // 返回箭头由 AppBar 默认提供（页面是 push 进来的）。
        title: Text(l10n.vipPurchaseAppBarTitle),
        centerTitle: true,
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 内容居中、留白舒适；窄屏也不溢出。
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // —— App 图标：真实资源，加载失败兜底为主题色占位（不崩） ——
                _AppIcon(scheme: scheme),
                const SizedBox(height: 20),
                // —— 商品名：商店本地化 title 优先，未配置兜底 l10n ——
                Text(
                  membership.title ?? l10n.vipSheetProductName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                // —— 商品描述（卖点）：购买页专用文案，不复用 vipDesc ——
                //    后者被 profile 页 VIP 卡与 tools 页会员状态条共用，文案不同。
                Text(
                  l10n.vipPurchaseSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // —— 价格：商店本地化字符串，未配置兜底 $1.99 ——
                Text(
                  membership.price ?? r'$1.99',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                // —— 买断型说明：与系统弹窗对 non-consumable 的展示一致 ——
                Text(
                  l10n.vipSheetOneTime,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // —— 终身有效补充文案 ——
                Text(
                  l10n.vipLifetime,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // —— 三种形态：探测中 / 已购买 / 未购买 ——
                if (membership.checking)
                  // 商店还在探测（冷启动极短窗口）：转圈，不渲染按钮。
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else if (membership.owned)
                  // 已持有（恢复购买命中 / 本就已是会员）：成功态 + 返回按钮。
                  _OwnedPanel(scheme: scheme)
                else
                  // 未购买：购买按钮（loading 态禁用）+ 恢复购买。
                  Column(
                    children: [
                      // ★ 高度写法：用 minimumSize 给「最小 56」，而不是 SizedBox 写死 height。
                      //   写死 height 时，一旦系统字号放大或文案变长（其他语言），
                      //   按钮不会长高，文字会被上下裁掉一截（用户报的现象）。
                      //   minimumSize 是下限，内容超高时按钮自动长高，永远不裁字。
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          // 探测中 / 正在支付时禁用，避免重复拉起。
                          onPressed: _buying ? null : _onBuy,
                          style: FilledButton.styleFrom(
                            // 最小高度 56（原写死 50）：拇指点击区更舒适，
                            // 同时给 17 号字留出足够上下留白。
                            minimumSize: const Size.fromHeight(56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _buying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  l10n.vipOpen,
                                  // 显式给行高，保证中英文混排时基线一致、不被裁切。
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 恢复购买：买断型审核硬要求；TextButton 视觉与取消/次级一致。
                      TextButton(
                        onPressed: _restoring ? null : _onRestore,
                        child: _restoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.vipRestore),
                      ),
                      const SizedBox(height: 12),
                      // 看广告得免费次数：位于恢复购买下方，看完插页广告返还 1 次免费额度（剩余 +1，封顶 10）。
                      _buildAdWatchButton(l10n, scheme),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 页面顶部 App 图标。
///
/// 真实资源 [assets/images/app.png]，加载失败兜底为主题色占位（避免资源缺失崩页面）。
class _AppIcon extends StatelessWidget {
  /// 创建 App 图标。
  const _AppIcon({required this.scheme});

  /// 主题色板（用于占位兜底）。
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.4 : 0.12,
            ),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/app.png',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          // 下划线参数一律只写单个 `_`：写 `__` / `___` 会被
          // unnecessary_underscores 规则判为信息级问题。
          errorBuilder: (_, _, _) => Container(
            color: scheme.primary,
            alignment: Alignment.center,
            child: Icon(Icons.explore, color: scheme.onPrimary, size: 36),
          ),
        ),
      ),
    );
  }
}

/// 已购买成功态面板。
///
/// 购买 / 恢复命中后展示对勾 + 「会员已生效」文案 + 返回按钮；
/// 同时页面会在 initState 的监听器里自动 pop 回上一页。
class _OwnedPanel extends StatelessWidget {
  /// 创建已购买面板。
  const _OwnedPanel({required this.scheme});

  /// 主题色板。
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Icon(
          Icons.verified,
          color: const Color(0xFF4CAF50),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.vipBecomeMember,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        // 与上方购买按钮同一套写法：最小高度 56，内容超高时自动长高，不裁字。
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.dialogConfirm,
              style: const TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
