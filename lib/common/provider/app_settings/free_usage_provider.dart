// ============================================================================
// 文件：common/provider/app_settings/free_usage_provider.dart
// 模块：common/provider/app_settings（免费使用额度状态层）
//
// 职责：
//   维护「免费用户工具使用次数」这一计数，供工具页在免费用户超过上限时弹出「升级 Pro」引导。
//
// 设计（2026-09-13 定，游客设备识别方案）：
//   - 游客（未登录）是免费用户主体。我们用「设备唯一号」把免费次数绑定到设备，
//     防止卸载重装清零额度。设备号取自 IDFV/ANDROID_ID，跨重装稳定
//     （见 lib/common/util/device_id.dart）。
//   - 游客权威计数存在服务端 anonymous_devices 表（按设备号主键），
//     由 get_or_create_anon_device / bump_anon_device_usage 两个 SECURITY DEFINER RPC
//     读写（anon 无 auth.uid() 行所有权，故不走直表访问，与 check_email_exists 同模式）。
//   - 本地 SharedPreferences（free_tool_usage_count）作为离线缓存 + 网络失败兜底，
//     初始化与云端取 max 合并。
//   - 已登录用户：额外与 public.users.tool_usage_count 取 max（跨设备合并；
//     该列由 app_events 触发器按 tool_entry_open 埋点自动累计，客户端只读不写）。
//
// 看广告获得免费次数（2026-09-16 改版，采用「独立奖励字段」模型）：
//   用户可在购买页通过 **激励广告（Rewarded）** 一次获得 [rewardPerAd]（5）次免费额度，
//   累加进独立的 [bonus] 字段，**不封顶**——这是本字段存在的意义：
//   旧的「已用计数 -1」模型受基础额度封顶，额度满时看广告是 no-op，用户没有观看动机。
//   新公式：剩余 = 基础额度 + 广告奖励 - 已用 = (maxFree + bonus - count)。
//   - [maxFree] 基础额度随登录态变化：未登录 [maxFreeGuest]=10、已登录 [maxFreeUser]=20；
//   - [count] 已用次数：本地为准、已与云端取 max，单调递增（每用一次工具 +1）；
//   - [bonus] 广告奖励：本地 SharedPreferences + 云端两列同步（见下），同样取 max 合并。
//   云端存储（scripts/sql/rewarded_free_uses.sql）：
//   - public.users.bonus_free_uses（已登录，走 SECURITY DEFINER RPC grant_rewarded_free_uses）；
//   - public.anonymous_devices.bonus_free_uses（游客按设备，走 grant_anon_rewarded_free_uses）。
//   两表都走 SECURITY DEFINER：anon 对 anonymous_devices 无直写权限；
//   users 侧的写入经 SECURITY DEFINER 绕过 users_before_update 的 42501 拦截
//   （以 postgres 身份执行时 is_privileged_caller() 返回 true，与 ensure_user_token 同机制）。
//
// 为什么用 SharedPreferences 而非 Hive：
//   单个 int 计数，sp 读写零类型适配成本；与 save_name_prompt_provider 同一套写法。
//
// 用法：
//   final state = ref.watch(freeUsageProvider).value;
//   final int used      = state?.count ?? 0;        // 已用（默认 0）
//   final int remaining = state?.remaining ?? 5;    // 剩余 = 基础额度 + 奖励 - 已用
//   final int maxFree   = state?.maxFree ?? 10;     // 当前基础额度（未登录 10 / 已登录 20）
//   final bool blocked  = !isMember && remaining <= 0;   // 剩余耗尽即拦截
//   await ref.read(freeUsageProvider.notifier).increment();          // 放行后 +1（已用）
//   await ref.read(freeUsageProvider.notifier).grantRewardedUses();  // 看完激励广告 +5（奖励）
//   await ref.read(freeUsageProvider.notifier).syncFromCloud();      // 登录后对齐
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tool_box/common/util/device_id.dart';

/// 鉴权状态流订阅句柄（用于「页面无关」的二次云端对齐，见 [_subscribeAuthSync]）。
/// 冷启动静默恢复会话时不派发 signedIn，仅靠 build() 首轮 merge 兜底；
/// 但「先游客后登录」的时序需要再对齐一次，故在 Notifier 内常驻订阅。
StreamSubscription<AuthState>? _authSub;

/// 免费用户工具使用次数状态。
///
/// 三个字段：
/// - [count]：已使用次数（本地为准，已与云端取过 max）。每用一次工具 +1。
/// - [bonus]：看激励广告获得的额外次数（本地为准，已与云端取过 max）。**不封顶**。
/// - [maxFree]：当前基础额度（未登录 10、已登录 20），随登录态变化。
///
/// 剩余可用次数 = [remaining]。所有字段不可空。
class FreeUsageState {
  /// 创建免费使用次数状态。
  ///
  /// - [count]：已使用的免费次数（本地为准，已与云端取过 max）；
  /// - [bonus]：看广告获得的额外次数（本地为准，已与云端取过 max）；
  /// - [maxFree]：当前基础额度，默认取游客额度 [FreeUsageController.maxFreeGuest]。
  const FreeUsageState({
    this.count = 0,
    this.bonus = 0,
    this.maxFree = FreeUsageController.maxFreeGuest,
  });

  /// 已使用的免费次数（本地为准，已与云端取过 max）。
  final int count;

  /// 看激励广告获得的额外免费次数（本地为准，已与云端取过 max），不封顶。
  final int bonus;

  /// 当前基础免费额度：未登录 [FreeUsageController.maxFreeGuest]、已登录 [maxFreeUser]。
  final int maxFree;

  /// 当前剩余可用免费次数。
  ///
  /// 公式：剩余 = clamp(基础额度 + 广告奖励 - 已用, 0, 基础额度 + 广告奖励)。
  /// - 未看广告、没用过：剩余 = maxFree（基础额度）；
  /// - 看过 n 次广告：上限抬到 maxFree + 5n，所以奖励「加得上」；
  /// - 已用超过总额度：剩余 = 0（耗尽，触发升级引导）。
  int get remaining => (maxFree + bonus - count).clamp(0, maxFree + bonus);

  /// 累计发放过的总额度（基础额度 + 广告奖励），用于文案里展示「N / M」。
  int get total => maxFree + bonus;

  /// 复制并覆盖部分字段。
  FreeUsageState copyWith({int? count, int? bonus, int? maxFree}) =>
      FreeUsageState(
        count: count ?? this.count,
        bonus: bonus ?? this.bonus,
        maxFree: maxFree ?? this.maxFree,
      );
}

/// 免费使用额度控制器。
///
/// 用 [AsyncNotifier]：sp 的 getInstance() 是异步的，且初始化时要做一次云端对齐
/// （取网络结果后再返回首态，避免首帧拿到错值）。
class FreeUsageController extends AsyncNotifier<FreeUsageState> {
  /// sp 键名：已用次数（与会员开关等其它偏好同库存储，作为离线缓存/兜底）。
  static const String _spKey = 'free_tool_usage_count';

  /// sp 键名：看广告获得的额外次数（与已用次数分开存，便于单独排查与清零）。
  static const String _spBonusKey = 'free_tool_bonus_uses';

  /// 未登录（游客）的基础免费额度：2026-09-16 由 10 下调为 5，2026-09-20 上调为 **10**。
  static const int maxFreeGuest = 10;

  /// 已登录用户的基础免费额度：**20** 次（比游客多 10 次，作为登录激励）。
  static const int maxFreeUser = 20;

  /// 每完整看完一条激励广告奖励的免费次数（**不封顶**，可累加）。
  static const int rewardPerAd = 5;

  /// 缓存本机设备唯一号（getDeviceId 可能走原生 channel，避免每次都重新取）。
  String? _deviceId;

  /// 当前应生效的基础免费额度：已登录 20、未登录 10。
  ///
  /// 直接问 Supabase 的当前会话（而不是让调用方传 user 进来），是为了让
  /// [build] / [syncFromCloud] / [grantRewardedUses] 三处口径一致、不会漏传。
  /// Supabase 未初始化（release 漏 dart-define 等极端情况）时抛异常，
  /// 这里兜住并按游客额度处理——宁可少给 10 次，也不能让限额逻辑崩掉。
  int get currentMaxFree {
    try {
      return Supabase.instance.client.auth.currentUser != null
          ? maxFreeUser
          : maxFreeGuest;
    } catch (_) {
      return maxFreeGuest;
    }
  }

  @override
  Future<FreeUsageState> build() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    // 本地落盘值；首次使用（无记录）为 0。
    final int local = sp.getInt(_spKey) ?? 0;
    final int localBonus = sp.getInt(_spBonusKey) ?? 0;
    // 1) 游客权威计数：与匿名设备表对齐（取/创建设备行，返回云端「已用 + 奖励」）。
    final ({int count, int bonus}) anon =
        await _syncAnonDevice(local, localBonus);
    // 2) 已登录用户：与 users 的两列取 max（跨设备合并）。
    final ({int count, int bonus}) merged =
        await _mergeWithUser(anon.count, anon.bonus);
    // 取本地与云端较大者：其它安装/设备累计更高的要同步上来；本机更高的保持本机。
    final int finalCount = merged.count > local ? merged.count : local;
    final int finalBonus = merged.bonus > localBonus ? merged.bonus : localBonus;
    if (finalCount != local) {
      await _persistLocal(finalCount);
    }
    if (finalBonus != localBonus) {
      await _persistLocalBonus(finalBonus);
    }
    // 订阅鉴权流做「页面无关」的二次对齐：新登录（signedIn）时再次同步，
    // 把云端额度合并回本地，避免「登录后本地仍从 0 起算」导致跨端额度失效。
    _subscribeAuthSync();
    // keepAlive：保证订阅与合并逻辑全程存活（即便工具页从未打开也能在启动期对齐）。
    ref.keepAlive();
    return FreeUsageState(
      count: finalCount,
      bonus: finalBonus,
      maxFree: currentMaxFree,
    );
  }

  /// 取（并缓存）本机设备唯一号；取不到返回 null（调用方回落本地）。
  Future<String?> _ensureDeviceId() async {
    _deviceId ??= await getDeviceId();
    return _deviceId;
  }

  /// 与匿名设备表对齐：取/创建设备行，返回云端已用次数。
  ///
  /// 与本地 [FreeUsageState.count] 对应：取本地与云端 max（其它安装累计更高的要同步上来）。
  /// 任何异常（未配置 Supabase / 网络错 / RLS 拒绝）都回落本地值，
  /// 绝不让限额判定因网络问题而崩溃或卡死。
  Future<({int count, int bonus})> _syncAnonDevice(
    int local,
    int localBonus,
  ) async {
    try {
      final String? dev = await _ensureDeviceId();
      if (dev == null || dev.isEmpty) {
        return (count: local, bonus: localBonus);
      }
      // RPC 返回单行（device_id, free_tool_usage_count, bonus_free_uses）。
      // 第三个字段是 2026-09-16 由 rewarded_free_uses.sql 扩出来的，
      // 若线上还没执行该脚本，这里取到 null → ?? 0，功能降级为「无奖励」，不会崩。
      final Map<String, dynamic> row = await Supabase.instance.client
          .rpc('get_or_create_anon_device', params: <String, dynamic>{
        'p_device_id': dev,
      })
          .single();
      final int cloud = (row['free_tool_usage_count'] as int?) ?? 0;
      final int cloudBonus = (row['bonus_free_uses'] as int?) ?? 0;
      // 两个计数各自取较大值：其它安装累计更高的同步上来，本机更高的保持本机。
      final int merged = local > cloud ? local : cloud;
      final int mergedBonus =
          localBonus > cloudBonus ? localBonus : cloudBonus;
      if (merged != local) {
        await _persistLocal(merged);
      }
      if (mergedBonus != localBonus) {
        await _persistLocalBonus(mergedBonus);
      }
      return (count: merged, bonus: mergedBonus);
    } catch (e) {
      debugPrint('[FreeUsage] 匿名设备对齐失败，回退本地: $e');
      return (count: local, bonus: localBonus);
    }
  }

  /// 已登录用户：与 public.users.tool_usage_count 取 max（跨设备合并）。
  ///
  /// 该列由服务端维护（app_events 触发器按 tool_entry_open 累计），
  /// 客户端禁止直写（users_before_update 触发器拦截，报 42501），故只「读」。
  Future<({int count, int bonus})> _mergeWithUser(
    int local,
    int localBonus,
  ) async {
    try {
      final User? user = Supabase.instance.client.auth.currentUser;
      // 未登录：没有用户行，云端无计数可对齐。
      if (user == null) return (count: local, bonus: localBonus);
      // 一次查询取两列：已用次数 + 广告奖励次数。
      // bonus_free_uses 由 rewarded_free_uses.sql 新增，未执行脚本时该列不存在，
      // PostgREST 会报错 → 被 catch 兜住，功能降级为「无奖励」，不会崩。
      final Map<String, dynamic>? row = await Supabase.instance.client
          .from('users')
          .select('tool_usage_count, bonus_free_uses')
          .eq('id', user.id)
          .maybeSingle();
      final int cloud = (row?['tool_usage_count'] as int?) ?? 0;
      final int cloudBonus = (row?['bonus_free_uses'] as int?) ?? 0;
      final int merged = local > cloud ? local : cloud;
      final int mergedBonus =
          localBonus > cloudBonus ? localBonus : cloudBonus;
      if (merged != local) {
        await _persistLocal(merged);
      }
      if (mergedBonus != localBonus) {
        await _persistLocalBonus(mergedBonus);
      }
      return (count: merged, bonus: mergedBonus);
    } catch (e) {
      debugPrint('[FreeUsage] 用户云端对齐失败，回退本地: $e');
      return (count: local, bonus: localBonus);
    }
  }

  /// 把本地「已用次数」落盘。
  Future<void> _persistLocal(int value) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt(_spKey, value);
  }

  /// 把本地「广告奖励次数」落盘（与已用次数分开存，便于单独排查与清零）。
  Future<void> _persistLocalBonus(int value) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt(_spBonusKey, value);
  }

  /// 放行一次工具点击：本地 +1 并落盘，同时异步把匿名设备表计数 +1。
  ///
  /// 云端 +1 走 RPC（不阻塞 UI）；失败不影响本地判定，下次启动会重新对齐。
  /// 注意：登录用户（会员）不受限，调用方在拦截处已 return，不会走到这里。
  Future<void> increment() async {
    final int next = (state.value?.count ?? 0) + 1;
    await _persistLocal(next);
    // 用 copyWith 更新，避免整树重建。
    state = AsyncData(
      (state.value ?? const FreeUsageState()).copyWith(count: next),
    );
    // 异步上报设备计数 +1（不 await，避免拖慢点击响应）。
    unawaited(_bumpAnonDevice());
  }

  /// 匿名设备表计数 +1（失败仅记日志，下次启动 _syncAnonDevice 会重新对齐）。
  Future<void> _bumpAnonDevice() async {
    try {
      final String? dev = await _ensureDeviceId();
      if (dev == null || dev.isEmpty) return;
      await Supabase.instance.client.rpc('bump_anon_device_usage',
          params: <String, dynamic>{'p_device_id': dev});
    } catch (e) {
      debugPrint('[FreeUsage] 匿名设备计数+1失败（下次启动对齐）: $e');
    }
  }

  /// 看完一条**激励广告**后发放 [amount] 次免费额度（默认 [rewardPerAd]=5）。
  ///
  /// 与旧的「已用计数 -1」模型不同：这里是**独立的奖励字段 [bonus] 直接累加**，
  /// 不受基础额度封顶，所以看多少次广告就加多少次，剩余次数可以超过基础额度。
  ///
  /// 两处写入：
  /// - 本地：SharedPreferences 的 [bonus] +amount（即时、离线可用）；
  /// - 云端：游客匿名设备表 + 已登录用户表各自 +amount（走 SECURITY DEFINER RPC，
  ///   失败仅记日志、不阻塞 UI）。两块数据在 [build]/[syncFromCloud] 里取 max 合并，
  ///   因此「本地已发放」不会被云端的旧值覆盖，跨设备也一致。
  ///
  /// 参数 [amount] 必须为正，非正直接返回 false（防御调用方传错）。
  /// 返回值表示是否真的发放了，调用方据此决定要不要提示用户。
  Future<bool> grantRewardedUses([int amount = rewardPerAd]) async {
    // 防御：奖励数量必须为正，否则等于白送或写坏数据。
    if (amount <= 0) return false;
    final SharedPreferences sp = await SharedPreferences.getInstance();
    // state.value 为 null（极端：provider 尚在加载/已被重建）时回落到 SP 读取，
    // 保证「刚看完广告但 provider 重建过」的场景也能正确累加。
    final int current =
        state.value?.bonus ?? (sp.getInt(_spBonusKey) ?? 0);
    final int next = current + amount;
    await sp.setInt(_spBonusKey, next);
    // 只更新 bonus：已用次数不动，剩余 = 基础额度 + bonus - count 随之 +amount。
    state = AsyncData(
      (state.value ?? const FreeUsageState()).copyWith(
        bonus: next,
        // 顺带刷新基础额度：万一在观看广告期间发生了登录/登出。
        maxFree: currentMaxFree,
      ),
    );
    // 云端同步（游客设备表 + 登录用户表，任一可用即写；失败静默忽略，
    // 下次 build/syncFromCloud 取 max 时会把本地较大的值重新推回云端语义）。
    unawaited(_grantAnonBonus(amount));
    unawaited(_grantUserBonus(amount));
    return true;
  }

  /// 登录态变化时由页面调用：重新与匿名设备表 + 用户表对齐。
  ///
  /// 跨设备场景：在设备 A 用满部分额度 / 看过广告后到设备 B 登录，应看到合并后的较大值，
  /// 而不是从 0 重新开始。登录 → 登出 也触发，逻辑幂等。
  Future<void> syncFromCloud() async {
    final int localCount = state.value?.count ?? 0;
    final int localBonus = state.value?.bonus ?? 0;
    final ({int count, int bonus}) anon =
        await _syncAnonDevice(localCount, localBonus);
    final ({int count, int bonus}) merged =
        await _mergeWithUser(anon.count, anon.bonus);
    final int finalCount = merged.count > localCount ? merged.count : localCount;
    final int finalBonus = merged.bonus > localBonus ? merged.bonus : localBonus;
    // 基础额度随登录态变化，必须在这里重算并写回 state，
    // 否则「登录后仍是游客的 5 次」——UI 读的是 state.maxFree。
    state = AsyncData(
      FreeUsageState(
        count: finalCount,
        bonus: finalBonus,
        maxFree: currentMaxFree,
      ),
    );
  }

  /// 云端奖励 +amount：匿名设备表的 bonus_free_uses（游客 / 未登录路径；
  /// 登录用户也有该设备行，无害）。
  ///
  /// 失败仅记日志：下次 [build]/[syncFromCloud] 重新取 max 合并即可补偿，不阻塞 UI。
  Future<void> _grantAnonBonus(int amount) async {
    try {
      final String? dev = await _ensureDeviceId();
      if (dev == null || dev.isEmpty) return;
      await Supabase.instance.client.rpc(
        'grant_anon_rewarded_free_uses',
        params: <String, dynamic>{'p_device_id': dev, 'p_amount': amount},
      );
    } catch (e) {
      debugPrint('[FreeUsage] 匿名设备奖励+$amount 失败（下次同步）: $e');
    }
  }

  /// 云端奖励 +amount：已登录用户表的 bonus_free_uses（以 auth.uid() 定位本行，
  /// SECURITY DEFINER 绕过 users_before_update 的 42501 拦截）。
  ///
  /// 未登录（currentUser 为空）时直接返回；失败仅记日志，不阻塞 UI。
  Future<void> _grantUserBonus(int amount) async {
    try {
      final User? user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.rpc(
        'grant_rewarded_free_uses',
        params: <String, dynamic>{'p_amount': amount},
      );
    } catch (e) {
      debugPrint('[FreeUsage] 用户奖励+$amount 失败（下次同步）: $e');
    }
  }

  /// 订阅 Supabase 鉴权流，登录态确立后把云端额度合并回本地。
  ///
  /// 与 [tool_page] 里 `ref.listen(currentUserProvider)` 互为冗余但**页面无关**：
  /// 即便工具页从未被打开，只要账号会话可用，也能在启动期把云端额度拉回本地，
  /// 避免「启动后趁 provider 加载窗口把首页工具全点开」绕过限额。
  /// 登录与登出**都要**同步：基础额度随登录态变化（已登录 10 / 未登录 5），
  /// 只在登录时同步的话，登出后 state.maxFree 会一直停在 10，等于白送 5 次。
  /// [syncFromCloud] 幂等且会按当前会话重算 [currentMaxFree]，故任何鉴权事件都可安全调用
  /// （tokenRefreshed 也会触发，代价是两次 RPC，可接受）。
  void _subscribeAuthSync() {
    try {
      _authSub?.cancel();
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        unawaited(syncFromCloud());
      });
      // Notifier 销毁时回收订阅，避免泄漏。
      ref.onDispose(() => _authSub?.cancel());
    } catch (_) {
      // Supabase 未初始化：跳过，本地计数仍能覆盖匿名用户。
    }
  }
}

/// 免费使用次数 Provider（本地为主 + 匿名设备表权威 + 登录合并云端 + 激励广告累加奖励）。
///
/// 状态为 [FreeUsageState]：未就绪（首帧异步加载中）时调用方用 `?? 0` 回落默认，
/// 不影响限额判定（首帧读不到就先放行，代价极小）。
final freeUsageProvider =
    AsyncNotifierProvider<FreeUsageController, FreeUsageState>(
  FreeUsageController.new,
);
