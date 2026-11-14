# Track —— Flutter 通用埋点工具类

> 行为埋点 + 队列持久化 + 批量上报 + 多通道传输，开箱即可用于任何 Flutter 工程。

## 1. 特性

| 能力 | 说明 |
| --- | --- |
| **传输层抽象** | `TrackTransport` 接口，默认实现 `EdgeFunctionTransport`（推荐生产），备选 `SupabaseRestTransport`（开发便利） |
| **持久化队列** | Hive Box `KnotBoxTrack`，断网期事件不会丢，重启自动补传 |
| **批量调度** | 阈值触发 + 定时 flush + AppLifecycle.paused 强刷 |
| **采样** | `sampleRate` 控制入队前抽样，命中事件才落盘 |
| **采样随机** | `dart:math` 的 `Random.secure`，熵来自系统 |
| **多 App 隔离** | `app_events.app_id` 列做多 App 共享表的逻辑隔离 |
| **跨工程复用** | `lib/common/track/` 自包含子模块，`cp -r` 即走 |

## 2. 目录结构

```
lib/common/track/
├── track.dart                          # 公共入口（全部 export）
├── track_config.dart                   # 配置
├── track_event.dart                    # 事件模型
├── track_transport.dart                # 传输接口 + 结果模型
├── track_service.dart                  # 主入口（TrackService.instance）
├── session_context.dart                # 会话 / 设备上下文
├── queue/
│   └── track_queue.dart                # Hive Box 持久化队列
├── batcher/
│   └── track_batcher.dart              # 批量调度器
└── transport/
    ├── edge_function_transport.dart    # 默认：Edge Function 网关
    └── supabase_rest_transport.dart    # 备选：PostgREST 直写
```

## 3. 一键接入

### 3.1 在当前 `tool_box` 工程

`main.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tool_box/common/track/track.dart';
import 'package:tool_box/config/app_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ... 其它既有初始化（Hive Box / Isar / Supabase） ...

  // 接入埋点：
  //   enabled 默认 false；上线前改成 true。
  await TrackService.instance.init(
    TrackConfig(
      enabled: true, // ← 上线前开
      appId: 'tool_box',
      edgeFunctionUrl:
          'https://<ref>.supabase.co/functions/v1/track-event',
      clientToken: '<与 Edge Function 配置一致>',
      useEdgeFunction: true,
      debug: kDebugMode,
    ),
    appVersion: await TrackService.currentAppVersion(),
    supabaseUrl: AppEnv.supabaseUrl,
    supabaseAnonKey: AppEnv.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ToolBoxApp()));
}
```

业务内上报：

```dart
// 关键节点
TrackService.instance.log('app_launch', params: {'cold': true});
TrackService.instance.log('compass_open', params: {'screen': 'home'});

// 关键事件立即刷盘
await TrackService.instance.logNow('purchase_success',
    params: {'sku': 'vip_year', 'price_cny': 199});

// 用户登录后关联行
TrackService.instance.setUserId(supabase.auth.currentUser!.id);
TrackService.instance.log('login_success', params: {'method': 'google'});

// 用户登出后清理关联
TrackService.instance.clearUserId();
```

### 3.2 Supabase 侧

```bash
# 1) 建表（仅一次）
psql "$DATABASE_URL" -f scripts/sql/app_events.sql

# 2) 部署 Edge Function（仅一次）
supabase link --project-ref <your-project-ref>
supabase functions deploy track-event --no-verify-jwt
supabase secrets set \
  ALLOWED_APP_IDS=tool_box \
  CLIENT_TOKEN=$(openssl rand -hex 20)

# 3) 把地址与令牌注入客户端（URL 已在 AppEnv 内设好兜底，通常只需传令牌）
flutter run \
  --dart-define=TRACK_EDGE_URL=https://<ref>.supabase.co/functions/v1/track-event \
  --dart-define=TRACK_CLIENT_TOKEN=<上一步生成的令牌>
```

> **tool_box 工程现状（2026-09-05）**：表与函数均已部署到 ref `nfoishlluynelazgwduc`，
> `ALLOWED_APP_IDS=tool_box`。`AppEnv.trackEdgeUrl` 已内置该地址作为兜底，
> 运行时只需注入 `--dart-define=TRACK_CLIENT_TOKEN=...`；上线把 `main.dart` 的
> `enabled: false` 改成 `true` 即可。

## 4. 跨工程复用（拷到别的 App）

整套 `lib/common/track/` 是自包含的，依赖只用到：

| 包 | 是否已在 `tool_box` | 备注 |
| --- | --- | --- |
| `flutter` | ✅ | 全工程都有 |
| `package_info_plus` | ✅ | 用于读取版本号 |
| `hive_flutter` | ✅ | 用于持久化队列 |
| `dio` / `http` | — | 没用到（dart:io 自带 HttpClient） |
| `supabase_flutter` | — | 没用到（仅在 main 注入 anon key） |

### 复用步骤

1. 把 `lib/common/track/` 整个文件夹复制到目标工程的 `lib/common/`（或任意路径）；
2. 在目标工程的 `pubspec.yaml` 确保 `hive_flutter` 和 `package_info_plus` 已在依赖列表；
3. `main.dart` 接入方式参考 3.1；
4. 跑 `flutter analyze` 校验零 error。

如果你要彻底封装成独立 package：

```bash
mkdir track_kit && cd track_kit
cp -R /path/to/tool_box/lib/common/track ./lib/src
# 套一层 package 骨架：
# track_kit/
# ├── pubspec.yaml
# ├── lib/
# │   ├── track_kit.dart              # export 'src/track.dart';
# │   └── src/                        # 拷过来的全部文件
# └── README.md
```

## 5. 配置项速查

| 字段 | 默认 | 说明 |
| --- | --- | --- |
| `enabled` | `false` | 总开关。建议默认关闭，上线前开 |
| `appId` | `'unknown_app'` | 注入 `--dart-define=APP_ID=...` 时透传 |
| `edgeFunctionUrl` | `''` | Edge Function 部署后的 URL |
| `supabaseTable` | `'app_events'` | REST 直写模式下的表名 |
| `clientToken` | `null` | Edge Function 业务令牌 |
| `useEdgeFunction` | `true` | `true` → Edge 网关；`false` → REST 直写 |
| `flushThreshold` | `20` | 入队达到阈值立刻 flush |
| `flushInterval` | `30s` | 定时 flush 周期 |
| `sampleRate` | `1.0` | 0~1，未命中样本丢弃 |
| `maxRetries` | `3` | 失败重试次数（备用，当前实现为保留入队） |
| `maxBatchBytes` | `256 KiB` | 单批字节上限，超出裁半再发 |
| `debug` | `false` | 打开后控制台输出每次上报概要 |

## 6. 存储安全建议

- **不要**在 `params` 里直接塞 `email` / `phone` / `IDFA` 等 PII；
  如确有关联用户需求，请用 `userId`（uuid）字段关联。
- `device` 字段已经在 [session_context.dart] 做了脱敏（仅 OS / locale），
  不要再往里塞 IMEI / IP / Mac 地址。
- 生产路径必须走 Edge Function，不走 REST 直写：见
  `supabase/functions/track-event/README.md`。

## 7. 自定义 Transport

如果不想用 Supabase，把它换成自己的上报通道：

```dart
class MyKafkaTransport implements TrackTransport {
  @override
  Future<TrackTransportResult> send(TrackBatch batch) async {
    // 你的实现……比如推到 Kafka / 友盟 / 神策
    return TrackTransportResult.ok;
  }
}

await TrackService.instance.init(
  TrackConfig(enabled: true, appId: 'my_app', useEdgeFunction: false),
  appVersion: '1.0.0+1',
  supabaseUrl: '',
  supabaseAnonKey: '',
  transport: MyKafkaTransport(), // ← 整体覆盖默认 transport
);
```

## 8. 排查清单

- **不上报**：先看 `enabled` 是否为 true；再看 `samples` 是否被采样掉；
  然后检查 `queueLength` 与 `debug` 日志。
- **401/403 居多**：Edge Function 的 `apikey` 与 `X-Client-Token` 没配对。
- **重启后事件全部重发**：Hive Box 没清理，旧事件还在。
- **dto 字段丢失**：检查 `event_name` 是否 snake_case 且非空；`params` 里的 null 值会自动过滤。
