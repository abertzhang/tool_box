// 文件职责：设备级匿名标识（anonymous_id）的生成与持久化。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：
//   - hive_flutter：持久化到应用主 Box（[AppBox.boxName]），跨会话保持稳定；
//   - session_context：复用其 `SessionContext.uuidV4()`，避免 UUID 有两份实现。
//
// 设计动机：
//   `app_events.user_id` 在「未登录」时没有可填的值。若留 null，会带来两个问题：
//     1. 无法统计未登录用户的独立设备数（null 无法 count(distinct)）；
//     2. 无法把「同一台设备登录前 / 登录后」的行为串联成一条完整链路。
//   这里生成一个**只存在本机**的 UUID 作为兜底身份，与账号体系完全无关。
//
// 隐私边界：
//   - 该 ID 是纯随机数，不含 IMEI / IDFA / Mac 地址 / IP 等任何设备硬件标识；
//   - 用户清除 App 数据或卸载重装后会重新生成 —— 因此**不能**用于跨重装追踪，
//     这既是缺陷也是刻意保留的隐私护栏；
//   - 与 `user_id`（真实账号 UUID）严格区分：分析时靠 `params.is_anonymous` 判别。
//
// 生命周期：
//   通常在 `main()` 里于 `TrackService.init` 之后调用一次 `TrackAnonymousId.load()`，
//   结果交给 `TrackService.setAnonymousId(...)`；之后整个进程共用同一个值。

import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_box.dart';
import 'session_context.dart';

/// 设备级匿名 ID 的存取门面（静态工具类，不实例化）。
///
/// 之所以用静态而非实例：匿名 ID 是**进程级唯一**的全局状态，
/// 与 [TrackService] 单例同生命周期，用静态可避免多处持有不同实例导致取值漂移。
class TrackAnonymousId {
  const TrackAnonymousId._();

  /// 在主 Hive Box 中的存储键。
  ///
  /// 与业务配置（语言 / 主题）同 Box，避免为本工具类单独开一个 Box 增加管理成本。
  static const String _storageKey = 'track_anonymous_id';

  /// 进程内缓存：避免每次读 Hive（Box.get 虽快，但埋点是高频路径）。
  static String? _cached;

  /// 取当前设备的匿名 ID；首次调用时生成并落盘。
  ///
  /// 返回值一定是合法 UUID（RFC 4122 v4），可直接写入 `user_id` 这类 uuid 列。
  ///
  /// 异常处理：
  ///   Hive Box 未打开 / 写入失败时不会抛异常，而是退化成「仅内存有效」的随机 ID
  ///   —— 本次进程内仍能串联行为，只是重启后会变。埋点属于旁路能力，
  ///   绝不能因为拿不到持久化存储而阻断 App 启动。
  static Future<String> load() async {
    // 已缓存：直接返回，零 IO。
    final String? cached = _cached;
    if (cached != null) return cached;

    try {
      final Box<dynamic> box = Hive.box(AppBox.boxName);
      final dynamic stored = box.get(_storageKey);
      if (stored is String && stored.isNotEmpty) {
        // 存量值：校验形态后再用，避免历史脏数据（如早期手工塞的值）污染统计。
        if (_looksLikeUuid(stored)) {
          _cached = stored;
          return stored;
        }
      }
      // 首次运行（或存量值非法）：生成并写回。
      final String fresh = SessionContext.uuidV4();
      await box.put(_storageKey, fresh);
      _cached = fresh;
      return fresh;
    } catch (e) {
      // 兜底：内存态 ID。不向上抛，埋点不能拖垮主流程。
      final String fallback = SessionContext.uuidV4();
      _cached = fallback;
      return fallback;
    }
  }

  /// 清除本机匿名 ID（下次 [load] 会重新生成）。
  ///
  /// 适用场景：用户要求重置广告标识、或调试时想模拟"全新设备"。
  /// **一般业务不要调用** —— 清掉之后历史行为将无法与新行为串联。
  static Future<void> reset() async {
    _cached = null;
    try {
      await Hive.box(AppBox.boxName).delete(_storageKey);
    } catch (_) {
      // 删除失败无所谓：进程内缓存已清空，本次启动等同于新设备。
    }
  }

  /// 粗校验 UUID 形态（8-4-4-4-12 共 36 位）。
  ///
  /// 只做形态检查、不做版本位校验：存量值可能是早期版本写入的任意 UUID，
  /// 只要能存进 `uuid` 列就应当保留，避免无谓地重置导致用户身份断裂。
  static bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
