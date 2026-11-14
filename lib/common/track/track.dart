// 文件职责：埋点工具类对外的公开 API 统一出口。
// 所属模块：common/track（埋点工具类）。
// 关键依赖：本目录下的全部子模块。
//
// 用法（main.dart 内）：
//   import 'package:tool_box/common/track/track.dart';
//   ...
//   await TrackService.instance.init(
//     TrackConfig(enabled: true, edgeFunctionUrl: 'https://...'),
//     appVersion: await TrackService.currentAppVersion(),
//     supabaseUrl: AppEnv.supabaseUrl,
//     supabaseAnonKey: AppEnv.supabaseAnonKey,
//   );
//
// 业务内调用：
//   TrackService.instance.log('compass_open', params: {'screen': 'home'});

/// 公开 API 集合；任何外部模块只需 `import 'package:tool_box/common/track/track.dart';`
/// 即可使用所有 Track 相关类型。
library;

// ===== 配置与数据模型 =====
export 'track_config.dart';
export 'track_event.dart';
export 'track_transport.dart';

// ===== 运行时上下文 =====
export 'session_context.dart';

// ===== 设备级匿名标识（未登录时兜底 user_id）=====
export 'anonymous_id.dart';

// ===== 主入口（业务调用方主要打交道的类）=====
export 'track_service.dart';

// ===== 传输实现（自定义 transport 时直接 import）=====
export 'transport/edge_function_transport.dart';
export 'transport/supabase_rest_transport.dart';

// ===== 内部模块（默认不暴露给业务方）=====
// 以下两个一般只在工具类自身或测试代码使用，不在 export 范围内：
// - queue/track_queue.dart
// - batcher/track_batcher.dart
