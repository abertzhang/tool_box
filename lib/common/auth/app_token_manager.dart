// ============================================================================
// 文件职责：App 端「权限 token」的本地缓存、过期判定与刷新门面。
// 所属模块：common/auth（认证与凭据）。
// 关键依赖：
//   - supabase_flutter：调用 RPC `ensure_user_token` 签发 / 重签 token；
//   - hive_flutter：把 token 与过期时间持久化到主 Box（[AppBox.boxName]）；
//   - common/track/anonymous_id：游客身份沿用同一份设备匿名 UUID；
//   - common/auth/token_expired_state：判定「需重新登录」时置位全局标记。
//
// 配套的服务端定义见 `scripts/sql/users.sql` 第 5b 段，约定如下：
//   · token 是 HS256 JWT，有效期 30 天，payload 含 sub / email / role / exp；
//   · 登录用户：token 落在 `users.token`，服务端判 exp，过期自动重签；
//   · 游客（未登录）：传设备匿名 UUID 无状态签发，**不落库**，客户端缓存到 exp；
//   · 客户端只**读 exp 判过期**，不做签名校验 —— 验签是验证方（自建后端）的职责，
//     把 secret 放进客户端等于把门禁钥匙挂在大门上。
//
// 调用方只需记住一个入口：
//   final AppTokenSnapshot r = await AppTokenManager.ensureValidToken();
//   r.status == AppTokenStatus.valid      → 用 r.token 发请求；
//   r.status == AppTokenStatus.needReLogin → 已置位 tokenExpiredPending，
//                                            GoRouter 会自动把用户带到登录页；
//   r.status == AppTokenStatus.unavailable → Supabase 未配置 / 网络异常，
//                                            业务侧自行降级（绝不能因此崩溃）。
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_box.dart';
import '../track/anonymous_id.dart';
import 'token_expired_state.dart';

/// token 获取结果的状态。
enum AppTokenStatus {
  /// 拿到了有效期内（含缓冲）的 token，可直接使用。
  valid,

  /// Supabase session 已失效：必须重新登录才能拿到新 token。
  ///
  /// 此时 [AppTokenSnapshot.token] 为 null，且全局标记 `tokenExpiredPending`
  /// 已被置位，路由层会自动跳登录页。
  needReLogin,

  /// 暂时拿不到 token（Supabase 未配置、网络异常、游客签发失败等）。
  ///
  /// 与 [needReLogin] 的区别：这不是用户的错，不该把人踢去登录页，
  /// 业务侧按「无 token」降级即可。
  unavailable,
}

/// 一次 token 获取的结果快照。
///
/// 用不可变小对象而非多返回值：便于业务侧直接判等、也便于后续加字段
/// （如 tokenType）而不破坏调用点。
class AppTokenSnapshot {
  const AppTokenSnapshot({required this.status, this.token, this.expiresAt});

  /// 本次结果状态。
  final AppTokenStatus status;

  /// 有效 token；仅在 [status] 为 [AppTokenStatus.valid] 时非空。
  final String? token;

  /// 过期时间（本地时区）。缓存命中与刚签发两种路径都会给出。
  final DateTime? expiresAt;

  /// 是否可直接使用。
  bool get isValid => status == AppTokenStatus.valid && token != null;
}

/// token 的本地管理门面（静态工具类，不实例化）。
///
/// 之所以用静态：token 是**进程级唯一**的凭据，与匿名 ID 同生命周期；
/// 用静态可避免多处持有不同实例导致缓存与请求状态漂移。
class AppTokenManager {
  const AppTokenManager._();

  /// 服务端签发 RPC 名（见 users.sql 第 5b 段）。
  static const String _rpcName = 'ensure_user_token';

  /// RPC 参数名：游客分支用的设备匿名 UUID。
  static const String _paramAnonymousId = 'p_anonymous_id';

  /// 过期缓冲：距 exp 不足这个时长就当作已过期，提前重签。
  ///
  /// 为什么留 5 分钟：客户端与服务端存在时钟偏差，且 token 从签发到被验证方
  /// 校验之间还有网络耗时。不提前刷新的话，很容易出现「刚拿到就过期」的边界事故。
  static const Duration _expirySkew = Duration(minutes: 5);

  // ---- Hive 存储键：与业务配置同 Box（见 AppBox 说明），不单独开 Box ----
  static const String _keyValue = 'app_token_value';
  static const String _keyExpiresAt = 'app_token_expires_at_ms';
  static const String _keyIsVisitor = 'app_token_is_visitor';

  /// 进程内正在进行的刷新请求；用于并发去重（见 [_ensureFresh] 说明）。
  static Future<AppTokenSnapshot>? _inFlight;

  /// 内存缓存：避免高频调用反复读 Hive。
  static String? _cachedToken;
  static DateTime? _cachedExpiresAt;
  static bool _cachedIsVisitor = false;

  /// 取一个「当前可用」的 token：命中缓存且未过期就直接返回，否则重新签发。
  ///
  /// [forceRefresh] 为 true 时跳过缓存判定，强制向服务端重签一次 ——
  /// 适用于「怀疑本地 token 已被服务端作废」的场景（如用户在别处登出）。
  ///
  /// 永远不会抛异常：所有异常都被翻译成 [AppTokenStatus.unavailable] 或
  /// [AppTokenStatus.needReLogin]。凭据模块绝不能成为崩溃源。
  static Future<AppTokenSnapshot> ensureValidToken({
    bool forceRefresh = false,
  }) {
    // 并发去重：多处同时调用时共用同一个 Future，只发一次 RPC。
    // 典型的重复来源：启动预取 + 首个页面加载几乎同时发起。
    final Future<AppTokenSnapshot>? running = _inFlight;
    if (running != null) return running;

    final Future<AppTokenSnapshot> task = _ensureFresh(
      forceRefresh: forceRefresh,
    );
    _inFlight = task;
    // 无论成功失败都要清掉 _inFlight，否则一次失败会让后续调用永远复用旧结果。
    return task.whenComplete(() => _inFlight = null);
  }

  /// 启动预取：静默拉一次 token，失败完全静默（仅供加速，不承担业务语义）。
  ///
  /// 放在 main() 里「不 await」地调用即可 —— 首个真正需要 token 的业务
  /// 会再走一次 [ensureValidToken]，命中缓存就直接返回。
  static Future<void> prewarm() async {
    try {
      await ensureValidToken();
    } catch (_) {
      // 预取失败无需处理：业务调用会再试一次，且失败原因已在快照里表达。
    }
  }

  /// 登录态变化后刷新 token（登录成功 / 退出登录都调用）。
  ///
  /// 为什么必须清缓存重签：
  ///   登录前是游客 token（sub = 匿名 UUID），登录后要换成用户 token；
  ///   登出后旧的用户 token 在服务端仍在 users.token 里没被清，
  ///   若本地继续用，等于用已登出身份访问 —— 必须丢弃并重新签游客 token。
  static Future<void> refreshAfterAuthChange() async {
    await clear();
    await ensureValidToken(forceRefresh: true);
  }

  /// 清空本地 token 缓存（内存 + 磁盘）。
  ///
  /// 业务侧一般不用直接调：登出 / 重新登录请走 [refreshAfterAuthChange]。
  static Future<void> clear() async {
    _cachedToken = null;
    _cachedExpiresAt = null;
    _cachedIsVisitor = false;
    try {
      final Box<dynamic> box = Hive.box(AppBox.boxName);
      await Future.wait(<Future<void>>[
        box.delete(_keyValue),
        box.delete(_keyExpiresAt),
        box.delete(_keyIsVisitor),
      ]);
    } catch (_) {
      // Hive 未打开 / 删除失败：内存态已清，本次进程等同于「无缓存」，不影响正确性。
    }
  }

  /// 当前缓存的 token 是否游客 token（true = 未登录身份）。
  ///
  /// 用途：埋点标注身份类别、以及调试时确认「登录前后 token 是否真的换了」。
  /// 无缓存时为 false（[cachedToken] 同样为 null，两者应一起判）。
  static bool get cachedIsVisitor => _cachedIsVisitor;

  /// 同步读取本地缓存的 token（不触发网络）。
  ///
  /// 仅供「有就用、没有就算了」的旁路场景（如给请求头附加可选凭据）。
  /// 需要保证有效性的场景一律用 [ensureValidToken]。
  static String? cachedToken() {
    if (_cachedToken != null) return _cachedToken;
    _loadFromBox();
    final String? token = _cachedToken;
    final DateTime? expiresAt = _cachedExpiresAt;
    if (token == null || expiresAt == null) return null;
    // 缓存已过期：不返回（宁可没有，也不能给业务一个必然被拒的 token）。
    if (_isExpiringSoon(expiresAt)) return null;
    return token;
  }

  // --------------------------------------------------------------------------
  // 内部实现
  // --------------------------------------------------------------------------

  /// 核心流程：缓存判定 → 分支签发 → 落盘。
  static Future<AppTokenSnapshot> _ensureFresh({
    required bool forceRefresh,
  }) async {
    // ① 缓存命中且未过期 → 直接返回（最常见路径，零网络）。
    if (!forceRefresh) {
      _loadFromBox();
      final String? token = _cachedToken;
      final DateTime? expiresAt = _cachedExpiresAt;
      if (token != null && expiresAt != null && !_isExpiringSoon(expiresAt)) {
        return AppTokenSnapshot(
          status: AppTokenStatus.valid,
          token: token,
          expiresAt: expiresAt,
        );
      }
    }

    // ② 未登录（游客分支）：用设备匿名 UUID 无状态签发。
    final bool loggedIn = _hasSession();
    if (!loggedIn) {
      final AppTokenSnapshot visitor = await _issueVisitorToken();
      // 游客签发失败只降级，绝不置 needReLogin —— 游客本来就没登录可「重新」。
      return visitor;
    }

    // ③ 登录分支：session 还在才调 RPC；session 丢了直接判定需重新登录。
    try {
      final dynamic raw = await Supabase.instance.client.rpc(
        _rpcName,
        params: <String, dynamic>{},
      );
      final String? token = raw is String ? raw : raw?.toString();
      if (token == null || token.isEmpty) {
        return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
      }
      final DateTime? expiresAt = _parseExpiry(token);
      if (expiresAt == null) {
        // 拿不到 exp 说明返回的不是预期 JWT：当作不可用，别把脏数据写进缓存。
        return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
      }
      await _save(token: token, expiresAt: expiresAt, isVisitor: false);
      // 拿到新 token 说明登录态是好的：清掉可能残留的跳转标记。
      resetTokenExpiredPending();
      return AppTokenSnapshot(
        status: AppTokenStatus.valid,
        token: token,
        expiresAt: expiresAt,
      );
    } on AuthException catch (_) {
      // Supabase 明确说凭据不可用（401 / JWT expired / session 已失效）。
      return _markNeedReLogin();
    } on PostgrestException catch (e) {
      // 42501 = 服务端拒绝（未登录 / 用户行不存在），本质是「身份不可用」。
      if (e.code == '42501' || e.code == '401' || '${e.code}' == 'PGRST301') {
        return _markNeedReLogin();
      }
      return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
    } catch (_) {
      // 网络异常 / Hive 未初始化等：一律降级，不惊动用户。
      return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
    }
  }

  /// 游客分支：取设备匿名 UUID 换一张无状态 token。
  static Future<AppTokenSnapshot> _issueVisitorToken() async {
    try {
      final String anonymousId = await TrackAnonymousId.load();
      final dynamic raw = await Supabase.instance.client.rpc(
        _rpcName,
        params: <String, dynamic>{_paramAnonymousId: anonymousId},
      );
      final String? token = raw is String ? raw : raw?.toString();
      if (token == null || token.isEmpty) {
        return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
      }
      final DateTime? expiresAt = _parseExpiry(token);
      if (expiresAt == null) {
        return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
      }
      await _save(token: token, expiresAt: expiresAt, isVisitor: true);
      return AppTokenSnapshot(
        status: AppTokenStatus.valid,
        token: token,
        expiresAt: expiresAt,
      );
    } catch (_) {
      // 游客 token 拿不到不影响 App 主功能：权限最低的那类请求本就可降级。
      return const AppTokenSnapshot(status: AppTokenStatus.unavailable);
    }
  }

  /// 置位「需重新登录」并清空本地缓存。
  ///
  /// 清缓存是必须的：留在本地的过期 token 会被后续旁路调用（[cachedToken]）
  /// 继续用，而它已经不可能通过验证方的校验。
  static AppTokenSnapshot _markNeedReLogin() {
    tokenExpiredPending.value = true;
    // 清缓存是异步的，这里刻意不 await：置位与返回必须同步完成，
    // 否则调用方拿到 needReLogin 的时机会被 IO 拖慢。
    unawaited(clear());
    return const AppTokenSnapshot(status: AppTokenStatus.needReLogin);
  }

  /// 当前是否有可用的 Supabase session（未初始化 / 未登录都算 false）。
  static bool _hasSession() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      // Supabase 未初始化：本工程约定「缺 key 也能启动」，这里退化成未登录。
      return false;
    }
  }

  /// 是否「即将过期」（把 [_expirySkew] 缓冲算进去）。
  static bool _isExpiringSoon(DateTime expiresAt) {
    return DateTime.now().isAfter(expiresAt.subtract(_expirySkew));
  }

  /// 解析 JWT 里的 exp（Unix 秒）为本地时间；解析失败返回 null。
  ///
  /// 只读第二段 payload，**不校验签名**（签名由验证方负责）。
  /// 客户端这么做是安全的：即使有人伪造了 exp，服务端签发链路与验证方验签
  /// 都不会认账，伪造者最多让自己提前多刷一次。
  static DateTime? _parseExpiry(String token) {
    final List<String> parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      // base64url → base64：补回被去掉的 '=' padding，否则 decode 可能失败。
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final String json = utf8.decode(base64Url.decode(payload));
      final Object? decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      final Object? exp = decoded['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }
      return null;
    } catch (_) {
      // 非法 JWT：返回 null，交给调用方判不可用。
      return null;
    }
  }

  /// 从 Hive 载入缓存（只补内存缓存，重复调用无副作用）。
  static void _loadFromBox() {
    if (_cachedToken != null) return;
    try {
      final Box<dynamic> box = Hive.box(AppBox.boxName);
      final Object? value = box.get(_keyValue);
      final Object? expMs = box.get(_keyExpiresAt);
      if (value is! String || value.isEmpty || expMs is! int) return;
      _cachedToken = value;
      _cachedExpiresAt = DateTime.fromMillisecondsSinceEpoch(expMs);
      _cachedIsVisitor = box.get(_keyIsVisitor) == true;
    } catch (_) {
      // Box 未打开：保持「无缓存」，后续走网络签发。
    }
  }

  /// 写入缓存（内存 + 磁盘）。
  static Future<void> _save({
    required String token,
    required DateTime expiresAt,
    required bool isVisitor,
  }) async {
    _cachedToken = token;
    _cachedExpiresAt = expiresAt;
    _cachedIsVisitor = isVisitor;
    try {
      final Box<dynamic> box = Hive.box(AppBox.boxName);
      await Future.wait(<Future<void>>[
        box.put(_keyValue, token),
        box.put(_keyExpiresAt, expiresAt.millisecondsSinceEpoch),
        box.put(_keyIsVisitor, isVisitor),
      ]);
    } catch (_) {
      // 落盘失败不影响本次使用：内存里已经有了，只是下次启动要重新签。
    }
  }
}
