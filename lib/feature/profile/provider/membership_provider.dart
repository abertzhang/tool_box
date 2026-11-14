// ============================================================================
// 文件：feature/profile/provider/membership_provider.dart
// 模块：个人中心（profile）· 会员购买（买断制 IAP）
//
// 职责：
//   封装 in_app_purchase 插件，提供「1.99 美元买断制终身会员」的端侧购买能力：
//   - 查询商店商品（价格随商店币种本地化）；
//   - 拉起系统支付（iOS: StoreKit / Android: Google Play Billing）；
//   - 监听购买流，买断权益（non-consumable）到手后置 owned = true；
//   - 恢复购买（App Store 审核对 non-consumable 的硬要求）。
//
// 恢复购买的设计要点（2026-10-01 优化，见 MembershipController.restore）：
//   ★ 会弹「Apple ID 密码框」的是 AppStore.sync()，**不是** restorePurchases()。
//     所以恢复流程改为「先静默读本机权益，命中就不再联网」——绝大多数场景
//     （本机缓存仍在）从此**零弹框**；只有真·换机才动用 sync。
//   ★ 恢复命中后会把权益上云（见 _bindAfterRestore），此后用户换设备只要
//     Apple / Google **一键登录**即恢复会员，不必再点恢复。这才是「用登录
//     替代 Restore」的正确实现路径——它并不替代 Apple ID 弹框本身，
//     而是让用户根本走不到需要弹框的那一步。
//
// 方案定位（2026-09-04 与用户确认的「方案 A：纯端侧」）：
//   买断权益完全绑定系统账号（Apple ID / Google 账号），**不要求登录 App 账号**
//   即可购买；会员状态 = 云端 users 表（登录用户）|| 本机商店权益（未登录用户），
//   由 [isMemberProvider] 合并判定。
//   方案 B（权益上云、跨设备同步）Phase 1 **已落地**：由 MemberBindService
//   调 Edge Function `bind-member` 写 users.is_member，触发点为「新购后已登录」
//   与「主动恢复购买命中后已登录」（后者 2026-10-01 新增）。
//   Phase 2（服务端收据校验）尚未做，届时在 Edge Function 侧补，本文件无需改动。
//
// 平台差异（★ 基于 in_app_purchase 3.3.0 源码核实，非记忆）：
//   ★ iOS 默认走 **StoreKit 2**：`restorePurchases()` 内部是遍历
//     `Transaction.currentEntitlements` —— **本机读取、不联网、不弹任何系统 UI**，
//     因此可以在启动时静默调用，覆盖「重装后取回会员」这一高频场景。
//     会弹 Apple ID 登录框的是 `AppStore.sync()`（用 in_app_purchase_storekit 的
//     platform addition 调用），苹果要求它由用户显式发起 —— 只在用户点
//     「恢复购买」时使用。
//   ★ Android 用 Billing Library 8.0.0：BillingClient 建连后会把**活跃购买**
//     自动推入 purchaseStream，冷启动即可恢复 owned，无需主动调用；
//     `restorePurchases()` 是幂等重查（无 UI），用户点「恢复购买」时调用。
//   ★ 两端都必须 `completePurchase`：Android 3 天内不完成会**自动退款**，
//     iOS 不完成会导致交易反复重投、且再次购买同一商品立即失败（提示重复交易）。
//
// 上架前置条件（代码之外，商店后台）：
//   - App Store Connect 与 Google Play Console 的商品 ID 均为
//     `uk.aknot.toolbox.pro`（即 [kMemberProductId]）；Xcode 需开启
//     In-App Purchase capability。
//   沙盒/开发环境未配置时 queryProductDetails 会返回空列表，
//   [buy] 会以 productMissing 结果退出，UI 提示「商品未上架」，不会崩溃。
//
// 安全边界：
//   本方案不做服务端收据校验（1.99 买断工具类 App 的可接受取舍），
//   越狱设备伪造权益的风险已知；升级到方案 B 时由后端用
//   App Store Server API / Play Developer API 复核。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// iOS 专属：AppStore.sync()（用户主动恢复时从服务器刷新交易）。
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/auth/member_bind_service.dart';

import 'user_profile_provider.dart';

import '../model/user_profile.dart';

/// 会员商品 ID（买断型 non-consumable，1.99 美元）。
///
/// ★ 必须与 App Store Connect / Google Play Console 中配置的商品 ID 完全一致：
///   两端后台商品 ID 均为 `uk.aknot.toolbox.pro`（App Store Connect 创建后不可改；
///   旧代码写 `pro_unlock` 与后台不符，导致审核真机 queryProductDetails 返回空、
///   点购买报「商品未上架」被拒，2026-10-23 修正）。改动这里等于换商品，
///   两端商店都要同步改。
const String kMemberProductId = 'uk.aknot.toolbox.pro';

/// 拉起支付的结果。
enum IapBuyResult {
  /// 已成功把系统支付页拉起（成功与否由 purchaseStream 异步回送）。
  started,

  /// 应用商店不可用（断网 / 沙盒未配 / 设备未登录商店账号等）。
  storeUnavailable,

  /// 商品未上架：商店可用但查不到 [kMemberProductId]（多见于开发环境）。
  productMissing,
}

/// 会员权益状态。
///
/// [checking] 为 true 表示正在查询商店可用性 / 商品，UI 此刻不宜弹错误提示。
class MembershipState {
  /// 创建会员权益状态。
  const MembershipState({
    this.checking = true,
    this.storeAvailable = false,
    this.hasProduct = false,
    this.owned = false,
    // 是否需要「同步会员到账号」：本次**新购**且未登录时置 true，
    // 由购买页 ref.listen 捕捉后**直接自动拉起平台授权建号**（不再弹说明框，
    // 这是 2026-11-08「购买后强制自动建号」需求）；授权失败/取消则留本机会员。
    // restored（恢复购买）**不置位**，避免冷启动静默恢复时反复打扰。
    this.needsSyncPrompt = false,
    this.price,
    // 商品标题：商店本地化值（如 "Pro Unlock"）。未查询到商品时为 null，
    // 调用方需自行兜底本地化文案；可空类型在 this. 参数下默认值为 null。
    this.title,
  });

  /// 是否正在查询商店（初始化阶段）。
  final bool checking;

  /// 应用商店是否可用（isAvailable 探测结果）。
  final bool storeAvailable;

  /// 会员商品是否查到（false = 未上架或开发环境未配置）。
  final bool hasProduct;

  /// 本机是否持有买断权益（含本次购买成功与恢复购买命中）。
  final bool owned;

  /// 是否需要弹「同步会员到账号」引导（见 [MembershipState] 构造说明）。
  final bool needsSyncPrompt;

  /// 商品价格（商店本地化后的字符串，如 "$1.99" / "¥14.00"）。
  final String? price;

  /// 商品标题（商店本地化，如 "Pro Unlock"）。
  ///
  /// 供购买确认弹窗展示真实商品名；商店未配置（hasProduct=false）时为 null，
  /// 调用方需自行兜底本地化文案。
  final String? title;

  /// 复制并覆盖部分字段。
  MembershipState copyWith({
    bool? checking,
    bool? storeAvailable,
    bool? hasProduct,
    bool? owned,
    bool? needsSyncPrompt,
    String? price,
    String? title,
  }) {
    return MembershipState(
      checking: checking ?? this.checking,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      hasProduct: hasProduct ?? this.hasProduct,
      owned: owned ?? this.owned,
      needsSyncPrompt: needsSyncPrompt ?? this.needsSyncPrompt,
      price: price ?? this.price,
      title: title ?? this.title,
    );
  }
}

/// 会员权益控制器 Provider。
///
/// UI 用法：
/// - `ref.watch(membershipProvider)` 订阅状态（会员卡渲染 / 按钮可用性）；
/// - `ref.read(membershipProvider.notifier).buy()` 拉起支付；
/// - `ref.read(membershipProvider.notifier).restore()` 恢复购买。
final membershipProvider =
    NotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );

/// 有效会员判定：云端登录会员 || 本机商店权益，二者任一成立即为会员。
///
/// 云端侧读 `user_profiles` 视图算好的 `is_member_active`（含过期判断），
/// 本机侧读商店买断权益。未登录用户靠本机权益即可点亮 VIP。
final isMemberProvider = Provider<bool>((ref) {
  // 云端：未登录 / 资料未加载时为 false，不影响本机权益判定。
  final cloud =
      ref.watch(userProfileProvider).value?.isMemberActive ?? false;
  // 本机：商店买断权益（iOS 恢复购买后、Android 冷启动自动同步后为 true）。
  final local = ref.watch(membershipProvider).owned;
  return cloud || local;
});

/// 异步版会员判定：等「云端会员 + 本机商店权益」两个来源都落定后再给结论。
///
/// ★ 为什么不能用 `ref.read(isMemberProvider)` 直接问：
///   [isMemberProvider] 是**同步** Provider，它的 cloud 分支读的是异步的
///   [userProfileProvider]。登录成功后的头几百毫秒这个 FutureProvider 还在
///   loading（`.value == null` → cloud=false），本机权益也刚被 Billing/StoreKit
///   探测重置过。此时同步读到的 false 是**中间态**而非结论。
///
///   后果可复现（2026-10-01 Android 真机）：云端 `users.is_member=true` 的账号，
///   点「恢复购买」却收到「未找到可恢复的购买记录」——短路判定没命中，白跑一次
///   商店查询，还把用户误导成「我根本没买过」。
///
/// 本函数把两个来源都等到位再返回：
/// ① 云端资料（查询失败则跳过、绝不阻断路，失败不等于非会员）；
/// ② 本机权益探测结束（[MembershipState.checking] 落 false，或等满 [limit] 兜底）。
///
/// 返回值：云端会员 **或** 本机权益，任一成立即 true。
Future<bool> settledIsMember(WidgetRef ref) async {
  // ① 云端会员资料（后台开通 / 跨设备同步 / 演示账号都走这条）。
  try {
    final UserProfile? profile = await ref.read(userProfileProvider.future);
    if (profile?.isMemberActive == true) return true;
  } catch (e) {
    // 只降级不抛：查不到云端资料时仍有机会靠本机权益成立，不能一刀切成非会员。
    debugPrint('[Member] 云端会员资料查询失败，转本机判定: $e');
  }

  // ② 本机商店权益：等探测跑完（checking 落 false）再读 owned，
  //    避免读到探测完成前的初始 false。
  const Duration limit = Duration(milliseconds: 1500);
  final Stopwatch sw = Stopwatch()..start();
  while (ref.read(membershipProvider).checking && sw.elapsed < limit) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return ref.read(membershipProvider).owned;
}

/// 会员权益控制器。
///
/// 生命周期：[build] 时订阅 purchaseStream 并异步探测商店，
/// Provider 销毁时自动取消订阅，不泄漏监听器。
class MembershipController extends Notifier<MembershipState> {
  /// 购买流订阅句柄，dispose 时取消。
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 鉴权态订阅句柄（登录即上云绑定），dispose 时取消。
  StreamSubscription<AuthState>? _authSub;

  /// 启动兜底建号是否已尝试（防止 build 重复触发重复拉起授权）。
  bool _relinkLaunched = false;

  /// 查到的会员商品详情（价格、标题），buy 时作为购买参数。
  ProductDetails? _product;

  @override
  MembershipState build() {
    // 订阅购买事件流：购买成功 / 恢复购买 / 退款等都会从这里推送。
    _sub?.cancel(); // 防御：build 被 invalidate 重跑时避免重复订阅。
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e) {
        // 流级别错误（连接商店失败等）：只降级不崩溃，UI 仍显示未持有权益。
        debugPrint('[Membership] purchaseStream 错误: $e');
      },
    );
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _authSub?.cancel();
      _authSub = null;
    });
    // 登录态监听：用户一旦登录（含 Apple / Google 授权回调、强制建号），
    // 若本机持有买断权益且云端尚未会员，立即把权益上云——
    // 覆盖「先买后登」「Apple OAuth 回退 pending」「购买后强制建号」全部路径。
    // 用 try/catch 兜住 Supabase 未初始化（缺 key）的访问。
    try {
      _authSub?.cancel();
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        AuthState state,
      ) {
        if (state.event == AuthChangeEvent.signedIn) {
          unawaited(_bindOnSignIn());
        }
      });
    } catch (_) {
      // Supabase 未初始化：跳过监听，不影响购买主流程。
    }
    // 异步探测商店，不阻塞 build 首帧（先以 checking=true 渲染）。
    unawaited(_probeStore());
    return const MembershipState();
  }

  /// 探测商店可用性并查询会员商品。
  Future<void> _probeStore() async {
    try {
      // 商店插件是否就绪（iOS 沙盒 / 未登录商店账号 / 断网都会返回 false）。
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        state = state.copyWith(checking: false, storeAvailable: false);
        return;
      }
      // 查询会员商品：开发环境未在商店配置时 notFoundIDs 会包含本商品 ID。
      final resp = await InAppPurchase.instance.queryProductDetails({
        kMemberProductId,
      });
      if (resp.error != null) {
        debugPrint('[Membership] 查询商品失败: ${resp.error}');
      }
      final product = resp.productDetails.isNotEmpty
          ? resp.productDetails.first
          : null;
      _product = product;
      state = state.copyWith(
        checking: false,
        storeAvailable: true,
        hasProduct: product != null,
        // 价格直接用商店本地化字符串，避免 App 内自算汇率。
        price: product?.price,
        // 商品标题同样取商店本地化值，供购买确认弹窗展示真实商品名。
        title: product?.title,
      );
      // 探测完立刻同步一次本机已有权益：iOS 重装后靠这里把会员点亮，
      // 整个过程静默（StoreKit 2 的 currentEntitlements 不弹任何框）。
      await _syncOwnedOnStart();

      // ★ 启动兜底建号（强制自动建号需求）：
      //   若本机已持有买断权益但未登录 App 账号（历史未同步的购买 /
      //   上次取消授权），直接自动拉起平台授权建号；用户取消则留本机会员，
      //   下次启动 App 此处会再次触发（_relinkLaunched 随进程重置）。
      if (state.owned && ref.read(currentUserProvider) == null) {
        unawaited(_autoRelinkOnLaunch());
      }
    } catch (e) {
      // 任何探测异常都降级为「商店不可用」，绝不让会员模块拖垮页面。
      debugPrint('[Membership] 商店探测异常: $e');
      state = state.copyWith(checking: false, storeAvailable: false);
    }
  }

  /// 启动时静默同步本机已有买断权益（不弹任何系统 UI）。
  ///
  /// - **iOS**：StoreKit 2 的 `restorePurchases()` 读 `Transaction.currentEntitlements`，
  ///   纯本机、不弹框 → 重装后无需用户操作即可点亮会员（事件走 purchaseStream → owned）。
  ///   注意它读的是**本机缓存**的交易；换机/历史较久的场景仍需用户点「恢复购买」
  ///   走 `AppStore.sync()` 从服务器刷新（见 [restore]）。
  /// - **Android**：BillingClient 建连后会自动把活跃购买推入 purchaseStream，
  ///   这里不做额外调用，避免多余的 Billing 查询。
  Future<void> _syncOwnedOnStart() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      // 恢复失败不影响主流程：最坏结果是会员未点亮，用户可手动点恢复。
      debugPrint('[Membership] 启动同步权益失败: $e');
    }
  }

  /// 拉起系统支付页（买断型 non-consumable）。
  ///
  /// 返回 [IapBuyResult] 供 UI 提示；真正的购买结果由 purchaseStream
  /// 异步回送并更新 [MembershipState.owned]，本方法不做成功判定。
  Future<IapBuyResult> buy() async {
    // 商店不可用直接拒绝，不拉起支付。
    if (!state.storeAvailable) return IapBuyResult.storeUnavailable;
    final product = _product;
    // 商品未上架（开发环境常见）：给出明确结果而非抛异常。
    if (product == null) return IapBuyResult.productMissing;
    // 买断型走 buyNonConsumable；插件内部会处理收据 / 确认等平台细节。
    //
    // ★ 必须 try/catch：真机沙盒 / 未登录商店账号 / 家长控制受限等场景下，
    //   buyNonConsumable 会**同步抛 PlatformException**（如 SKErrorDomain /
    //   SKPaymentNotAllowed）。若不接住，异常会穿过 _onBuy 的 await 冒泡到
    //   Flutter 框架 → 整个购买页红屏。这里降级为 storeUnavailable，由 UI 给提示。
    try {
      final ok = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return ok ? IapBuyResult.started : IapBuyResult.storeUnavailable;
    } catch (e) {
      debugPrint('[Membership] 拉起支付异常: $e');
      return IapBuyResult.storeUnavailable;
    }
  }

  /// 恢复购买（用户**主动**触发；iOS 重装 / 换机取回权益的唯一可靠途径）。
  ///
  /// ★ 2026-10-01 关键优化：**能不弹 Apple ID 框就不弹**。
  ///   会弹框的是 `AppStore.sync()`（连服务器刷新交易），而 iOS 本机其实
  ///   缓存着买断权益（StoreKit 2 的 currentEntitlements），读它**不弹任何 UI**。
  ///   旧实现无条件先 sync，导致**每次点恢复都弹 Apple ID 密码框**——
  ///   哪怕本机缓存里明明有这笔交易，用户也被迫输一次密码，体验很差。
  ///
  ///   新顺序（iOS）：
  ///   ① 先静默读本机权益 → 命中就**直接结束，永不弹框**；
  ///   ② 只有本机没有记录（真·换机 / 缓存失效）才 sync 弹框向服务器刷新。
  ///   这一步仍必须保留：苹果规定 sync 只能由用户显式发起，且审核要求
  ///   买断型商品必须提供恢复入口，不能删。
  ///
  /// - **Android**：直接 `restorePurchases()`，幂等重查活跃购买，全程无系统 UI。
  ///
  /// 命中历史购买时 purchaseStream 会推 restored 事件并自动置 owned = true，
  /// UI 在 await 结束后读 state.owned 区分「已恢复」与「无可恢复记录」。
  /// 命中后还会走 [_bindAfterRestore] 把权益上云（见该方法说明）。
  Future<void> restore() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // ① 静默读本机权益（不弹框的重头戏）。
      await _silentRestore();

      // ② 本机已命中 → 权益已点亮，无需联网刷新，直接收尾。
      //    这是用户「明明买过，只是重装/清了缓存」的高频场景，从此不再弹框。
      if (state.owned) {
        await _bindAfterRestore();
        return;
      }

      // ③ 本机确实没有记录 → 才动用会弹 Apple ID 框的 sync 向服务器刷新。
      //    用户取消登录框 / 网络失败都不阻断，继续读本机兜底。
      try {
        await InAppPurchaseStoreKitPlatformAddition().sync();
      } catch (e) {
        debugPrint('[Membership] AppStore.sync 失败: $e');
      }
      await _silentRestore();
    } else {
      // ★ Android：首次查询常常撞上 BillingClient 建连超时，判空后必须复查一次，
      //   否则「真实买过」会被误报成「未找到购买记录」（2026-10-01 修复）。
      final bool hit = await _silentRestore();
      if (!hit) {
        await _recheckRestore();
      }
    }

    // 恢复结论落定后统一上报一次：owned / 商店可用性 / 商品是否查得到。
    // 三者组合能直接定位「查不到」是账号问题、商品未上架问题，还是网络问题。
    debugPrint(
      '[Member] 恢复流程收尾: owned=${state.owned}, '
      'store=${state.storeAvailable}, hasProduct=${state.hasProduct}',
    );
    unawaited(
      AppTrack.logNow(
        TrackEvents.vipRestoreResult,
        params: <String, Object?>{
          'hit': state.owned ? '1' : '0',
          'store': state.storeAvailable ? '1' : '0',
          'product': state.hasProduct ? '1' : '0',
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      ),
    );
    await _bindAfterRestore();
  }

  /// 静默读取本机已有权益（不弹任何系统 UI），最多等 [timeout] 让流回送结果。
  ///
  /// ★ 为什么 await 之后还要额外等一小段：
  ///   `restorePurchases()` 本身不返回结果，交易是**异步**经 purchaseStream
  ///   推送、由 [_onPurchaseUpdated] 置 owned=true 的。直接 await 完就读
  ///   state.owned 存在竞态（可能流还没到就被判成「无可恢复记录」）。
  ///   这里轮询等待，命中即提前返回，不命中才等到超时——代价最多几百毫秒，
  ///   换来的是判定准确，避免误提示「未找到购买记录」。
  ///
  /// ★ Android 超时为什么必须给到 2.5s（2026-10-01 真机踩坑）：
  ///   `restorePurchases()` 背后是 `BillingClient.queryPurchasesAsync`，**首次调用
  ///   要先建连 BillingClient**（冷启动首次约 1~2s，弱网更久）。旧默认 800ms
  ///   太短：Google 其实已经查到这笔购买、只是还没推送到 purchaseStream，
  ///   App 就抢先判成「未找到可恢复的购买记录」，把真实购买硬生生说成没买过。
  ///
  /// 返回值：本次是否**确认命中**权益。false 不代表一定没有购买，
  ///           只代表「在这段时间内商店没回话」。
  Future<bool> _silentRestore({
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    // ★ 必须 try/catch：restorePurchases 在沙盒 / 未登录商店账号 / iCloud 受限时
    //   可能抛 PlatformException，若不接住会冒泡红屏。异常时静默降级，
    //   由调用方根据 state.owned 提示「无可恢复记录」。
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('[Member] 恢复购买异常(商店未响应): $e');
      return false;
    }
    final Stopwatch sw = Stopwatch()..start();
    while (!state.owned && sw.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final bool hit = state.owned;
    debugPrint(
      '[Member] 恢复查询结束: owned=$hit, '
      'store=${state.storeAvailable}, hasProduct=${state.hasProduct}, '
      '耗时=${sw.elapsed.inMilliseconds}ms',
    );
    return hit;
  }

  /// 兜底复查：主查询超时未命中时，再向商店要一次（并延长观察窗口）。
  ///
  /// ★ 存在它的理由：BillingClient 可能在第一次查询时掉线/超时，
  ///   但第二次（连接已建立）通常毫秒级返回。用户明明买过、第一次被判空，
  ///   如果就此放弃就太亏——多问一次几乎零成本。
  Future<bool> _recheckRestore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('[Member] 复查购买异常: $e');
      return state.owned;
    }
    final Stopwatch sw = Stopwatch()..start();
    while (!state.owned && sw.elapsed < const Duration(milliseconds: 1200)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('[Member] 复查结束: owned=${state.owned}');
    return state.owned;
  }

  /// 恢复命中后：已登录用户把买断权益**静默上云**。
  ///
  /// ★ 这是「用一键登录替代反复 Restore」的治本之策：
  ///   绑定一次之后，云端 users.is_member = true，此后换设备 / 重装
  ///   **只要 Apple / Google 一键登录就是会员**（[isMemberProvider] 的云端分支
  ///   直接成立），完全不必再点「恢复购买」，也再不会弹 Apple ID 框。
  ///
  ///   为什么放在这里而不是 purchaseStream 的 restored 分支：
  ///   冷启动的静默恢复每台设备每次启动都会触发，在那儿 bind 会造成
  ///   无谓的网络请求与打扰；只有用户**主动**点恢复时才值得上云一次。
  ///
  /// 三种短路（都不报错，静默跳过）：
  ///   - 未命中权益 → 没东西可绑；
  ///   - 未登录 → 绑不了（引导登录是购买页的事，这里不打扰）；
  ///   - 云端已是会员 → 重复绑定无意义。
  Future<void> _bindAfterRestore() async {
    if (!state.owned) return;
    if (ref.read(currentUserProvider) == null) return;
    final bool cloudAlreadyMember =
        ref.read(userProfileProvider).value?.isMemberActive ?? false;
    if (cloudAlreadyMember) return;

    final MemberBindResult result = await MemberBindService.bind(
      source: 'restore',
    );
    if (result == MemberBindResult.ok) {
      // 绑定成功 → 刷新云端资料，让 isMemberProvider 立刻读到新状态。
      ref.invalidate(userProfileProvider);
    }
  }

  /// 登录成功后：本机持有买断权益且云端尚未会员时，自动把权益上云。
  ///
  /// 触发源统一为 `onAuthStateChange` 的 `signedIn` 事件 —— 不论用户是
  /// 购买页强制建号、登录页正常登录、还是 Apple OAuth 回退（pending）回调，
  /// 只要"已登录 + 本机有权益 + 云端未会员"就补绑一次，且幂等（重复调用无害）。
  ///
  /// 与 `_bindAfterRestore` 互斥互补：restore 是**用户主动**点恢复时上云；
  /// 本方法是**任意登录**时上云，覆盖面更广，是"强制自动建号"的真正兜底。
  Future<void> _bindOnSignIn() async {
    if (!state.owned) return;
    final bool cloudAlreadyMember =
        ref.read(userProfileProvider).value?.isMemberActive ?? false;
    if (cloudAlreadyMember) return;
    if (ref.read(currentUserProvider) == null) return;

    final MemberBindResult result = await MemberBindService.bind(
      source: 'login_after_buy',
    );
    if (result == MemberBindResult.ok) {
      ref.invalidate(userProfileProvider);
    }
  }

  /// 启动兜底：本机已购但未登录时，自动拉起平台授权建号。
  ///
  /// 仅由 [_probeStore] 在启动探测结束后调用一次（受 [_relinkLaunched] 守护，
  /// 防 build 重入重复拉起）。用户取消授权则本次不建号，进程不重启就不会再弹；
  /// 下次启动 App 时本方法会再次触发，直到建号为止（强制自动建号的"再提示"）。
  Future<void> _autoRelinkOnLaunch() async {
    if (_relinkLaunched) return;
    _relinkLaunched = true;
    // 已登录则无需建号（登录监听会负责上云）。
    if (ref.read(currentUserProvider) != null) return;

    // 未初始化 Supabase（缺 key）时 signInAndBind 内部会捕获并返回 failed，
    // 这里不必额外守卫；失败只意味着本次不建号，本地会员照常。
    final MemberBindResult result = await MemberBindService.signInAndBind(
      source: 'launch_relink',
    );
    if (result == MemberBindResult.ok) {
      ref.invalidate(userProfileProvider);
    }
  }

  /// 购买流回调：逐笔处理购买状态变化。
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    // ★ 逐笔日志：排查「买过却提示没记录」时，这一行就是唯一的现场证据——
    //   能直接看出商店到底推了什么（productID 对不对、status 是 purchased 还是
    //   restored、Google 侧给的 verificationData 状态是什么）。线上出问题只能靠它，
    //   否则只能听用户口述「我明明买过」而无从验证。
    for (final pd in purchases) {
      debugPrint(
        '[Member] 商店事件: sku=${pd.productID}, status=${pd.status.name}, '
        'pendingComplete=${pd.pendingCompletePurchase}, '
        'verifySource=${pd.verificationData.source}',
      );

      switch (pd.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 只认会员商品这一笔：到手（或恢复）即点亮本机权益。
          // Android 冷启动的活跃购买、iOS 恢复购买都走这两个分支。
          if (pd.productID == kMemberProductId && !state.owned) {
            // 漏斗终点：会员从未持有变为持有 —— 真实付费率与买断收益的口径。
            //
            // 为什么在这里而不是在 profile_page 的 buy() 之后上报：
            // 购买是**异步**的，`buy()` 返回 started 只代表支付页拉起了，
            // 用户是否真的付钱要等这个流回送。在这里上报才不会把
            // 「拉起支付页」算成「成交」。
            //
            // source 区分三种来源，避免把恢复购买 / 云端同步算成新增付费：
            //   - purchased → 本次新购；
            //   - restored  → 恢复购买（含冷启动时 StoreKit 的静默同步）。
            unawaited(
              AppTrack.logNow(
                TrackEvents.vipActivated,
                params: <String, Object?>{
                  'source': pd.status == PurchaseStatus.purchased
                      ? 'purchase'
                      : 'restore',
                },
              ),
            );

            // —— 方案 B：权益上云绑定 ——
            // purchased（新购）与 restored（恢复）分别处置：
            //   - purchased + 已登录 → 点亮权益 + 静默 bind（把买断写云端，无弹框）；
            //   - purchased + 未登录 → 点亮权益 + needsSyncPrompt=true（**同帧**更新，
            //     购买页据此弹「同步会员」对话框，引导 Apple/Google 一键注册+绑定）；
            //   - restored → 只点亮权益，不弹框：冷启动 StoreKit 静默恢复每台设备
            //     都会触发，弹框会反复打扰。已登录且云端无会员走 profile 手动入口兜底。
            if (pd.status == PurchaseStatus.purchased) {
              final bool loggedIn = ref.read(currentUserProvider) != null;
              if (loggedIn) {
                state = state.copyWith(owned: true);
                // source=auto：已登录用户的静默绑定，无弹框、无感知。
                unawaited(MemberBindService.bind(source: 'auto'));
              } else {
                state = state.copyWith(owned: true, needsSyncPrompt: true);
              }
            } else {
              state = state.copyWith(owned: true);
            }
          }
          break;
        case PurchaseStatus.pending:
          // 待支付（如家庭共享审批 / 便利店支付）：保持现状，等后续事件。
          break;
        case PurchaseStatus.error:
          // 用户取消（*) 或支付失败：只打日志，owned 维持 false。
          debugPrint('[Membership] 购买失败: ${pd.error}');
          break;
        case PurchaseStatus.canceled:
          // 用户主动取消支付弹窗：静默即可。
          break;
      }
      // iOS 必须 finish 交易、Android 必须 acknowledge，
      // 否则该笔交易会反复重发（iOS 每 24h 弹一次确认框）。失败仅重试意义不大，
      // 打日志即可——插件会在下次事件中再次标记待完成。
      if (pd.pendingCompletePurchase) {
        unawaited(
          InAppPurchase.instance.completePurchase(pd).catchError((Object e) {
            debugPrint('[Membership] completePurchase 失败: $e');
          }),
        );
      }
    }
  }
}
