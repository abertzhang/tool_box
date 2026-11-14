// ============================================================================
// 文件：common/ads/watch_ad_dialog.dart
// 模块：广告（ads）· 「观看激励广告换取免费次数」确认弹框
//
// 职责：
//   把「确认弹框 → 播放激励广告 → 发放免费次数 → 结果提示」这一串流程封装成一个
//   顶层函数，供任意页面（profile 统计栏 / 购买页 / 将来的限额弹框）直接调用，
//   不必各自复制一份 showRewardedAd + grantRewardedUses 的样板代码。
//
// 交互约定（按需求）：
//   1. 弹出确认框，标题写明「观看一次获得 N 次免费使用」，正文展示当前剩余 / 总额度，
//      让用户先知道看一次能拿多少、现在还剩多少；
//   2. 点「取消」→ 仅关闭弹框，什么都不做；
//   3. 点「确定」→ **先关闭弹框**，再播放激励广告（弹框不能盖在广告上）；
//   4. 看完并发奖 → 底部 SnackBar 提示「已获得 N 次免费使用」；
//      没看完 / 没广告 → 提示对应原因，**不发奖**（中途退出也发奖等于白送）。
//
// 为什么做成顶层函数而不是 Widget：
//   调用方 ProfilePage 是 ConsumerWidget（无 State 字段），无法持有 loading 态；
//   而本流程里弹框在广告开始前就已关闭，不需要页面级 loading UI，
//   故用「模块级 _busy 防重入 + 顶层函数」最省事，也避免为它改造页面基类。
//
// 关键依赖：
//   - rewarded_ad_helper.dart：播放激励广告并返回 [RewardedAdResult]。
//   - free_usage_provider.dart：发放奖励（[grantRewardedUses]）与读取剩余额度。
//   - l10n：文案全部复用既有词条（adWatchForFreeUses / adRewardProgress /
//     adRewardSuccess / adNotFinished / adUnavailable / dialogCancel /
//     dialogConfirm），**不新增 i18n key**（gen-l10n 已损坏，新增需手工同步 5 处）。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../provider/app_settings/free_usage_provider.dart';
import 'rewarded_ad_helper.dart';

/// 广告是否正在播放中（模块级防重入）。
///
/// 广告播放期间弹框已关闭，按钮/入口仍可再次点击；若不挡住，会叠加多条
/// 全屏广告（AdMob 第二次 show 会直接失败，用户看到「广告不可用」的假故障）。
/// 播放结束（成功或失败）后复位。
bool _busy = false;

/// 弹出「观看一次获得 N 次免费使用」确认框，确认后播放激励广告并发放奖励。
///
/// 参数：
/// - [context]：调用点上下文（须为可弹出对话框的上下文）。
/// - [ref]：用于读取剩余额度与发放奖励；传入页面持有的 ref。
/// - [slot]：埋点用广告位标识（snake_case），用于区分不同入口，
///   例如 `profile_free_left` / `purchase_ad_for_free`。
/// - [reward]：本次发放的次数，默认 [FreeUsageController.rewardPerAd]（5）。
///
/// 说明：
/// - 弹框文案与按钮全部走 i18n，跟随系统语言。
/// - 发奖唯一依据是 [RewardedAdResult.earned]（走到 onUserEarnedReward 回调），
///   不是 shown —— 用户中途退出不能发奖。
/// - 全流程不抛异常：广告不可用时给用户提示后静默结束。
Future<void> showWatchAdForFreeUsesDialog(
  BuildContext context,
  WidgetRef ref, {
  String slot = 'watch_ad_for_free_uses',
  int? reward,
}) async {
  // 防重入：上一次广告还没播完就不再拉新的。
  if (_busy) return;

  // 跨 await 前先把 context 派生的对象全部捕获到本地：
  // ① l10n 文案（await 后取会因 context 失活触发 lint）；
  // ② ScaffoldMessenger 用于播完广告后给结果提示。
  // 之后只用 context.mounted 做活性判断（lint 对该访问有豁免）。
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final int amount = reward ?? FreeUsageController.rewardPerAd;

  // —— 第一步：确认弹框 ——
  // 返回 true=确定（去看广告），false/null=取消或点击遮罩关闭。
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      // 弹框内重新取一次 l10n：builder 的 context 在弹框子树下，
      // 用它取本地化最稳妥（与外层 context 同语言，但避免跨树引用）。
      final d = AppLocalizations.of(dialogContext)!;
      // 当前剩余 / 总额度：让用户在决定前看到「还剩几次」。
      // 用 read 而非 watch：弹框生命周期极短，额度在此期间变化的概率可忽略，
      // 且 AlertDialog 内再包 Consumer 会让结构变复杂，收益不成比例。
      final FreeUsageState? usage = ref.read(freeUsageProvider).value;
      final int remaining = usage?.remaining ?? FreeUsageController.maxFreeGuest;
      final int total = usage?.total ?? FreeUsageController.maxFreeGuest;
      return AlertDialog(
        // 标题直接点明收益：看一次得 N 次。
        title: Text(d.adWatchForFreeUses(amount)),
        // 正文展示当前额度进度（剩余 / 总额度），复用购买页同款文案。
        content: Text(d.adRewardProgress(remaining, total)),
        actions: <Widget>[
          // 取消：仅关闭弹框，不播放广告、不发奖。
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(d.dialogCancel),
          ),
          // 确定：关闭弹框后播放广告（返回值 true 触发后续流程）。
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(d.dialogConfirm),
          ),
        ],
      );
    },
  );

  // 取消 / 点遮罩关闭：到此结束，什么都不做（弹框已由 pop 关闭）。
  if (confirmed != true) return;
  // 弹框关闭后页面可能已被用户退出（如同时点了返回），此时直接放弃。
  if (!context.mounted) return;

  // —— 第二步：播放激励广告 ——
  // 弹框此时已关闭，广告可正常全屏展示（不会被对话框遮挡或打断）。
  _busy = true;
  final RewardedAdResult result = await showRewardedAd(slot: slot);
  _busy = false;
  if (!context.mounted) return;

  // —— 第三步：按结果发奖或提示 ——
  if (result.earned) {
    // 看完并发奖：本地 + 云端同步累加（不封顶），详见 grantRewardedUses。
    await ref.read(freeUsageProvider.notifier).grantRewardedUses(amount);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.adRewardSuccess(amount)),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }

  // 未获得奖励：区分「广告压根没出来」与「出来了但没看完」——
  // 后者提示「广告不可用」会让用户误以为是 App 的锅。
  messenger.showSnackBar(
    SnackBar(
      content: Text(result.shown ? l10n.adNotFinished : l10n.adUnavailable),
      duration: const Duration(seconds: 2),
    ),
  );
}
