# Supabase Edge Function — track-event

埋点收集入口：Flutter 客户端把所有事件 POST 到这里，函数用 service_role 批量写入 `app_events` 表。

## 0. 当前部署状态（2026-09-05）

| 项目             | 值                                                                          |
| ---------------- | --------------------------------------------------------------------------- |
| Supabase 工程    | `tool_box` · ref `nfoishlluynelazgwduc` · 区域 West EU (Ireland)            |
| 函数 URL         | `https://nfoishlluynelazgwduc.supabase.co/functions/v1/track-event`         |
| 部署方式         | `supabase functions deploy track-event --no-verify-jwt`                     |
| `ALLOWED_APP_IDS`| `tool_box`（已设；如需接入第二款 App，追加 `,knot_phone` 后重新 `secrets set`）|
| `CLIENT_TOKEN`   | 已设 40 位十六进制随机串，**只保存在 Supabase secrets 与 `--dart-define` 中** |
| 数据表           | `app_events` 已建（含 4 索引 + RLS 开启、无 anon policy）                     |
| 鉴权自检         | GET → `405`；无 apikey → `401 missing_apikey`；无/错 token → `403 invalid_client_token` |

> ⚠️ 上表「鉴权自检」只覆盖到函数入口的校验逻辑；**service_role 真正落库的写入验证需在
> 本机终端手工跑一次第 1.4 节的命令**（沙箱环境会拦截携带 anon key 的出网进程，代理侧无法代跑）。

## 1. 部署

```bash
# 1) 链接工程（如未链接）
supabase link --project-ref <your-project-ref>

# 2) 部署函数（不要走 JWT 校验，因为客户端拿的是 anon key，Edge Function 默认要 apikey）
supabase functions deploy track-event --no-verify-jwt

# 3)（推荐）配置白名单 + 业务令牌
supabase secrets set \
  ALLOWED_APP_IDS=tool_box,knot_phone \
  CLIENT_TOKEN=<32+ 字符随机串>

# 4) 在 SQL Editor 跑一遍 scripts/sql/app_events.sql 建表
psql "$DATABASE_URL" -f scripts/sql/app_events.sql
```

部署成功后，控制台会打印类似：

```
https://<your-project-ref>.supabase.co/functions/v1/track-event
```

把这个 URL 配到客户端 `TrackConfig.edgeFunctionUrl`。

### 1.4 上线后冒烟验证（写入链路）

在本机终端执行（**不要**在 CI / 日志里留下 key 与 token）：

```bash
REF=nfoishlluynelazgwduc
ANON=<local/env/prd.json 里的 SUPABASE_ANON_KEY>
TOKEN=<CLIENT_TOKEN>

curl -i -X POST "https://$REF.supabase.co/functions/v1/track-event" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON" \
  -H "Authorization: Bearer $ANON" \
  -H "X-Client-Token: $TOKEN" \
  -d '{
    "app_id": "tool_box",
    "events": [{
      "event_name":  "track_smoke_test",
      "params":      {"tool":"cli","src":"deploy_verify"},
      "session_id":  "'"$(uuidgen)"'",
      "platform":    "macos",
      "app_version": "0.0.0+verify",
      "device":      {"os":"macos"},
      "occurred_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }]
  }'
```

预期 `HTTP/1.1 200 OK` + `{"inserted":1}`。随后在 SQL Editor 确认落库：

```sql
select id, event_name, params, platform, occurred_at, received_at
from app_events
where event_name = 'track_smoke_test'
order by received_at desc
limit 5;
```

> 💡 `CLIENT_TOKEN` 只存在于 Supabase secrets 里（控制台只显示摘要，取不回明文）。
> 若遗失，重新生成并覆盖即可：`supabase secrets set CLIENT_TOKEN=$(openssl rand -hex 20)`，
> 同步更新所有端的 `--dart-define=TRACK_CLIENT_TOKEN=...`。

## 2. 接口契约

### 2.1 请求

```
POST /functions/v1/track-event
Headers:
  Content-Type:        application/json
  apikey:              <anon 或 publishable key>           ← 必填
  Authorization:       Bearer <同上>                       ← 二选一
  X-Client-Token:      <可选，业务校验>                      ← 与 CLIENT_TOKEN 一致

Body:
{
  "app_id": "tool_box",
  "events": [
    {
      "event_name":  "compass_open",
      "params":      { "tool": "compass", "from": "home" },
      "user_id":     "<uuid 或 null>",
      "session_id":  "<uuid>",
      "platform":    "ios",
      "app_version": "1.0.0+1",
      "device":      { "os": "ios", "os_version": "...", "locale": "zh_CN" },
      "occurred_at": "2026-09-05T12:00:00.000Z"
    },
    ...
  ]
}
```

### 2.2 响应

| 状态码 | 含义                                | Body 示例                                       |
| ------ | ----------------------------------- | ----------------------------------------------- |
| 200    | 全部写入成功                         | `{"inserted": 42}`                              |
| 400    | 参数缺失 / 批次超限 / 全无效事件      | `{"error":"empty_events"}`                      |
| 401    | 缺少 apikey                         | `{"error":"missing_apikey"}`                    |
| 403    | app_id 不在白名单 / 业务令牌错误     | `{"error":"app_id_not_allowed","app_id":"..."}` |
| 405    | 非 POST                              | `{"error":"method_not_allowed"}`                |
| 500    | 数据库写入失败                       | `{"error":"insert_failed","detail":"..."}`      |

## 3. 安全要点

- **不要**用 anon/publishable key 写数据库 —— 此函数必须用 `SUPABASE_SERVICE_ROLE_KEY`（Deno 函数运行时会自动注入到 `Deno.env`）。
- 表上 `enable row level security` + 不创建任何 anon / authenticated policy，强制所有写入都经过本函数。
- `ALLOWED_APP_IDS` 是最关键的白名单，未列出的 app_id 一律 403。
- `CLIENT_TOKEN` 是次级防护（防止合法的 App 误用 / 被他人拼接请求），建议用 32+ 字符随机串。

## 4. 本地调试

```bash
supabase functions serve track-event --no-verify-jwt --env-file ./supabase/.env.local
# 跑 dart client 时把 edgeFunctionUrl 指向 http://localhost:54321/functions/v1/track-event
```

## 5. 切回 REST 直写（不推荐）

如果不想用 Edge Function：

1. 在 `scripts/sql/app_events.sql` 末尾取消注释 `grant insert ...` 和 `track_insert_whitelist` 策略；
2. 客户端 `TrackConfig(useEdgeFunction: false)` 即可走 PostgREST 直写。
