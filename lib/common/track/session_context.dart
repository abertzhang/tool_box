// 文件职责：维护埋点工具类运行时所需的"一次性"上下文——会话 ID / 用户 ID /
// 客户端平台 / App 版本 / 设备快照——避免在每条事件里重复填这些字段。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：
//   - dart:io（Platform）：获取 OS 名称 / 版本 / locale；
//   - dart:math：会话 ID 的随机数部分；
//   - App 版本号由调用方注入（通常在 main 里读取 PackageInfo 后传入）。
//
// 注意：未引入 `package:uuid`，避免在跨工程复用时强制要求父工程已装该包；

import 'dart:io' show Platform;
import 'dart:math' as math;

/// 埋点用的运行时上下文（单例在 [TrackService] 内）。
///
/// 注意：此类不存储 "userId"，用户身份由 [TrackService.setUserId] 直接写到
/// 每个 [TrackEvent]，避免出现"上下文版本不一致"导致的脏数据。
class SessionContext {
  /// 会话 ID：每次 [TrackService.init] 生成一次，贯穿整个进程。
  final String sessionId;

  /// 客户端平台字符串（`ios` / `android` / `macos` / `windows` / `linux` / `web` 等）。
  /// 注意：web 由外部覆盖，flutter 一律小写以匹配 Supabase 列约束。
  final String platform;

  /// App 版本号（含 build 号），与 [PackageInfo.version + buildNumber 一致）。
  final String appVersion;

  /// 设备信息快照（已脱敏，仅含 OS / 型号 / locale / tz 等无 PII 字段）。
  final Map<String, Object?> device;

  /// 私有构造。
  const SessionContext._({
    required this.sessionId,
    required this.platform,
    required this.appVersion,
    required this.device,
  });

  /// 自动构造：[sessionId] 由时间戳 + 安全随机数组成（单 App 单次启动内唯一）。
  ///
  /// 通常 [TrackService.init] 时一次性调用，结果在整个 App 生命周期内复用。
  factory SessionContext.build({
    required String appVersion,
  }) {
    // 会话 ID：RFC 4122 v4 标准 UUID（36 位，8-4-4-4-12）。
    // 必须是合法 UUID —— app_events.session_id 列定义为 `uuid not null`，
    // 早期版本用「毫秒 hex + 随机 hex」自造的格式会被 Postgres 拒绝写入。
    final String sessionId = uuidV4();

    // 平台探测：调用 dart:io，输出统一小写字符串与 Supabase 列约束一致。
    final String platform = _detectPlatform();

    // 设备上下文：去除 IMEI / IP / 蓝牙地址等 PII 字段，仅留分析所需。
    final Map<String, Object?> device = <String, Object?>{
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      // 后续可补充：屏幕分辨率、时区、是否低功耗模式等
    };

    return SessionContext._(
      sessionId: sessionId,
      platform: platform,
      appVersion: appVersion,
      device: device,
    );
  }

  /// 生成一个 RFC 4122 v4 UUID 字符串（`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`）。
  ///
  /// 不依赖 `package:uuid`：跨工程复制本目录时，父工程无需新增依赖。
  /// 随机数取自 [math.Random.secure]（系统熵源），碰撞概率可忽略。
  ///
  /// 设为 public 的原因：设备级匿名 ID（见 `anonymous_id.dart`）同样需要 UUID，
  /// 与其在各处各写一份生成器，不如统一复用这一个，避免格式漂移。
  ///
  /// 位运算说明：
  ///   - `bytes[6] & 0x0F | 0x40`：高 4 位置为 `0100`，即版本号 4；
  ///   - `bytes[8] & 0x3F | 0x80`：高 2 位置为 `10`，即 RFC 4122 variant。
  static String uuidV4() {
    final math.Random random = math.Random.secure();
    // 16 字节随机数：UUID 的 128 bit
    final List<int> bytes =
        List<int>.generate(16, (_) => random.nextInt(256), growable: false);
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    // 单字节 → 两位定长 hex（不足补 0），否则 UUID 长度会不固定
    String hex(int index) => bytes[index].toRadixString(16).padLeft(2, '0');

    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  /// 平台探测（与 dart:io Platform 保持一致；Web 由 WidgetsBinding 覆盖）。
  static String _detectPlatform() {
    // 这里用 dart:io 检测原生平台；Web 后端覆盖时使用 PlatformDispatcher。
    // 因为工具类不强依赖 WidgetsBinding.navigator.context，可以直接走 Platform.localeName
    // 与 Platform.operatingSystem 即可。
    final String os = Platform.operatingSystem.toLowerCase();
    if (os.isEmpty) return 'unknown';
    return os;
  }
}
