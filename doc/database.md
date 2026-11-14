# 埋点事件表app_events

> 归属：Supabase（PostgreSQL 15+）· 建表脚本 [`scripts/sql/app_events.sql`](../scripts/sql/app_events.sql)
> 客户端：[`lib/common/track/`](../lib/common/track/) 埋点工具类 · 上报网关：[`supabase/functions/track-event/`](../supabase/functions/track-event/)

通用埋点事件表，**多个 App 共用同一张表**，用 `app_id` 区分来源（`tool_box` / `knot_phone` / …），避免每个 App 建一张表导致 schema 膨胀。

## 一、字段说明

| 列名 | 类型 | 约束 | 来源 | 说明 |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | `primary key default gen_random_uuid()` | 服务端 | 主键，服务端生成。便于按主键去重、跨设备聚合。 |
| `app_id` | `text` | `not null` | 客户端 | App 标识，与 `dart-define` 的 `APP_ID` 对齐，建议 `snake_case`，如 `tool_box` / `knot_phone`。 |
| `user_id` | `uuid` | 可空 | 客户端 | 用户身份 UUID。**登录时** = Supabase `auth.users.id`；**未登录时** = 客户端设备级匿名 UUID（自 2026-09-06 起，不再为 `NULL`）。**禁止**写入 email / 手机号等 PII。 |
| `session_id` | `uuid` | `not null` | 客户端 | 会话 ID，App 每次启动生成一次并贯穿整个进程。用于漏斗 / 留存 / 单次使用时长分析。 |
| `event_name` | `text` | `not null` | 客户端 | 事件名，推荐 `snake_case` 并按业务前缀聚合，如 `app_launch` / `tool_entry_open` / `noise_measure_start`。 |
| `params` | `jsonb` | `not null default '{}'` | 客户端 | 事件自定义参数，自由字典。不固定列是为了兼容各 App 差异；已建 GIN 索引支持高效过滤。 |
| `platform` | `text` | `not null` | 客户端 | 客户端平台：`ios` / `android` / `macos` / `windows` / `linux` / `web`（统一小写）。 |
| `app_version` | `text` | `not null` | 客户端 | App 版本号（含 build 号），与 `PackageInfo` 一致，如 `1.0.0+1`。 |
| `device` | `jsonb` | `not null default '{}'` | 客户端 | 设备上下文快照（已脱敏）：`os` / `os_version` / `locale` 等，**不含** IMEI、IP、蓝牙地址等 PII。 |
| `occurred_at` | `timestamptz` | `not null` | 客户端 | 事件在客户端真实发生的时刻（UTC，含时区）。与 `received_at` 对比可判断上报延迟。 |
| `received_at` | `timestamptz` | `not null default now()` | 服务端 | Edge Function 落地时刻。用于判断队列堆积 / 网络延迟。 |
| `created_at` | `timestamptz` | `not null default now()` | 服务端 | 行创建时间，当前与 `received_at` 同步；保留独立语义以便后续拆分（如离线补传的真实写入时间）。 |

### 字段补充说明

- **`user_id` 的两级身份（2026-09-06 修正）**：
  - **登录用户**：Supabase `auth.users.id`，由 `TrackService.setUserId(uid)` 注入；
  - **未登录**：客户端设备级匿名 UUID（`TrackAnonymousId`，首次生成后存 Hive，清数据/重装后重生成）。
  - 早期版本未登录时该列为 `NULL`，导致未登录事件**无法参与任何按用户维度的聚合**，
    现由匿名 ID 兜底。存量 `NULL` 行可用 `session_id` 关联回填（见 `app_events.sql` 第 6 段）。
- **如何区分真实用户与匿名设备**：看 `params->>'is_anonymous'`（`true` = 未登录）。
  `params->>'anonymous_id'` 无论登录与否都有值，用于按设备维度聚合、
  以及把「登录前 → 登录后」的行为串成一条完整链路。
- **历史匿名事件不会被自动回填**：`user_id` 在**入队那一刻**就写进事件 row，
  登录只影响之后的事件；需要串联时靠 `anonymous_id` 关联。
- **`session_id` 必须是合法 UUID**：客户端自造 ID 时需生成 RFC 4122 v4 格式（`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`），否则 `uuid` 列会报 `invalid input syntax for type uuid`。工具类已内置 `_generateUuidV4()`，`session_context.dart` 未引入 `package:uuid`。
- **`params` / `device` 用 jsonb**：不定义过多离散列，新增埋点字段无需 DDL 变更；`jsonb_path_ops` GIN 索引支持 `@>` 包含查询。
- **`occurred_at` 与 `received_at` 分离**：客户端时钟可能不准，分析时以 `received_at` 为主，排查时钟偏差时才用 `occurred_at`。

## 二、索引

| 索引名 | 定义 | 服务场景 |
| --- | --- | --- |
| `idx_app_events_app_time` | `(app_id, created_at desc)` | 按 App + 时间窗口查询（最常见 BI 查询） |
| `idx_app_events_user_time` | `(user_id, created_at desc)` | 用户漏斗 / 留存分析。原为 `where user_id is not null` 的 partial index，因客户端已保证该列非空，改为普通索引 |
| `idx_app_events_name_time` | `(event_name, created_at desc)` | 按事件名统计 PV/UV、监控漏斗首步 |
| `idx_app_events_anonymous` | `((params ->> 'is_anonymous'), created_at desc)` | 按「是否登录」筛选，区分真实账号用户与匿名设备 |
| `idx_app_events_params_gin` | `gin (params jsonb_path_ops)` | 参数属性过滤，如 `params @> '{"tool":"compass"}'` |

> 时间相关索引统一 `created_at desc` 排序，避免额外排序开销。

## 三、安全策略

- **RLS 已启用**（`alter table app_events enable row level security`），但**不创建任何 `anon` / `authenticated` 策略** —— 客户端无法直写、无法读取。
- **写入路径**：客户端 → Edge Function `track-event` → 用 `service_role` 写表（`service_role` 绕过 RLS，无需额外授权）。
- Edge Function 侧校验 `X-Client-Token` 与 `app_id` 白名单（`ALLOWED_APP_IDS`），防止任何人伪造上报。

### 可选：REST 直写方案

开发期若不想部署 Edge Function，可放开 `scripts/sql/app_events.sql` 第 4 段的注释（`grant insert ... to anon` + 白名单 RLS policy）。

> ⚠️ 暴露 `anon INSERT` 意味着任何拿到 URL 的人都能写入，必须配合网关限流 + `app_id` 白名单 + `X-Client-Token` 校验。**生产环境不推荐。**

## 四、写入链路

```
业务代码 Track.log(eventName, params)
   ↓  补齐 app_id / platform / app_version / device / session_id
Hive 队列持久化（Box: KnotBoxTrack，崩溃后下次启动续传）
   ↓  阈值触发 / 定时 flush / App 进入 paused 强刷
TrackTransport.send(TrackBatch)
   ↓  Edge Function（默认） 或 PostgREST 直写（备选）
app_events
```

- 单批上限：`TrackConfig.flushThreshold`（条数）+ `TrackConfig.maxBatchBytes`（字节，超限自动对半裁剪）。
- 上报失败**保留**队列，下轮重试，不丢事件。
- 默认 `enabled: false`，上线前在 `main.dart` 改为 `true` 才开始上报。

## 五、示例行

```json
{
  "app_id": "tool_box",
  "user_id": "3f1c9b2e-5a7d-4c81-9f0e-2b6d8a4c1e77",
  "session_id": "9b1e4c77-2d58-4f0a-8c31-6e7a5d2b9f04",
  "event_name": "tool_entry_open",
  "params": {
    "tool": "compass",
    "from": "home_grid",
    "anonymous_id": "a7e2c410-6b93-4d55-8f2a-1c9e7b3d5f08",
    "is_anonymous": false
  },
  "platform": "ios",
  "app_version": "1.0.0+1",
  "device": { "os": "ios", "os_version": "26.0", "locale": "zh_CN" },
  "occurred_at": "2026-09-05T12:04:31.512Z"
}
```

## 六、常用验证 SQL

```sql
-- 确认索引已建齐
select indexname from pg_indexes where tablename = 'app_events' order by indexname;

-- 确认 RLS 已启用（relrowsecurity 应为 t）
select relname, relrowsecurity from pg_class where relname = 'app_events';

-- 最近 100 条事件
select created_at, app_id, event_name, params
from app_events
order by created_at desc
limit 100;

-- 各事件 PV / UV（近 7 天）
select event_name, count(*) as pv, count(distinct session_id) as uv
from app_events
where created_at > now() - interval '7 days'
  and app_id = 'tool_box'
group by event_name
order by pv desc;

-- 参数过滤（走 GIN 索引）
select count(*) from app_events where params @> '{"tool":"compass"}';

-- 身份完整性体检：user_id 为空的比例（客户端修复后新数据应接近 0）
select
  count(*) as total,
  count(*) filter (where user_id is null) as null_user_id,
  round(100.0 * count(*) filter (where user_id is null) / nullif(count(*), 0), 2) as null_pct
from app_events
where app_id = 'tool_box'
  and created_at > now() - interval '7 days';

-- 区分真实用户与匿名设备（走 idx_app_events_anonymous）
select
  params ->> 'is_anonymous' as is_anonymous,
  count(*) as events,
  count(distinct user_id) as distinct_users
from app_events
where app_id = 'tool_box'
  and created_at > now() - interval '7 days'
group by 1;

-- 单条事件的完整身份链路（排查"user_id 为什么是空的"用这一条）
select id, created_at, event_name, user_id,
       params ->> 'anonymous_id' as anonymous_id,
       params ->> 'is_anonymous' as is_anonymous,
       session_id, platform, app_version
from app_events
where app_id = 'tool_box'
order by created_at desc
limit 20;
```

# 用户表users

> 归属：Supabase（PostgreSQL 15+）· 建表脚本 [`scripts/sql/users.sql`](../scripts/sql/users.sql)
> 客户端：[`lib/feature/profile/`](../lib/feature/profile/) · 模型 [`user_profile.dart`](../lib/feature/profile/model/user_profile.dart)
>
> **线上状态（2026-09-05 建表，2026-09-06 加统计列）**：`public.users` 表与 `user_profiles` 视图已在 Supabase `tool_box` 项目（ref `nfoishlluynelazgwduc`）中建好。
> 2026-09-06 新增三列统计字段需**在线上执行 `users.sql` 相应段落 + `app_events.sql` 第 7 段触发器**（操作步骤见下「二、字段说明」补充说明）。
> 该脚本保留作为「结构快照 + 幂等重建」用途：全部 `if not exists` / 先 drop 再 create，
> 整段重跑安全，可用于新环境建库或字段漂移时对齐。

## 一、先分清三个对象（最容易混）

| 对象 | 类型 | 谁建的 | 能否改写 | 说明 |
| --- | --- | --- | --- | --- |
| `auth.users` | 系统表 | **Supabase 平台**（GoTrue 托管） | ❌ **不可改写** | 存密码哈希 / 第三方身份 / `raw_user_meta_data`。业务侧只读，SDK 不暴露写接口。 |
| `public.users` | 业务表 | **我们自建** | ✅ 建表 / 加列 / 读写 | 与 `auth.users` **一对一**（`public.users.id = auth.users.id`），所有业务字段放这里。 |
| `public.user_profiles` | 视图 | **我们自建** | 只读投影 | 基于 `public.users` 的只读投影，额外算出 `is_member_active`（见下一章）。 |

**为什么业务字段不直接塞进 `auth.users`**：它是 GoTrue 的私有地盘，DDL 不受你控制，Supabase 升级可能覆盖；且 RLS / Data API 暴露规则与 `public` schema 不同。标准做法是「系统表管身份，业务表管资料」，用同一个 `uuid` 主键一对一关联。

**关联关系**：

```
auth.users (系统表，Supabase 托管，不可改写)
     │  id (uuid) 一对一
     │  ── 触发器 on_auth_user_created 注册后自动补行 ──▶
     ▼
public.users (自建业务表：昵称 / 头像 / 会员)
     │  只读投影 + security_invoker
     ▼
public.user_profiles (自建视图：多算一个 is_member_active)
```

## 二、字段说明

| 列名 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `uuid` | `primary key` | 与 `auth.users.id` 同值，一对一关联。由 Supabase Auth 注册时生成，业务表不设默认值。 |
| `email` | `text` | 可空 | 注册邮箱。Google 登录也有值。 |
| `display_name` | `text` | 可空 | 昵称。Google 登录取 `raw_user_meta_data->>'name'`，邮箱注册取邮箱前缀。未设置时 UI 回落到邮箱前缀。 |
| `avatar_url` | `text` | 可空 | 头像 URL。Google 登录由触发器从 `raw_user_meta_data->>'picture'` 写入，邮箱注册通常为空（UI 用默认头像兜底）。 |
| `is_member` | `boolean` | `not null default false` | **是否买过会员**，只表示「买过」，**过期仍然是 `true`**。判断当前是否有效请用视图的 `is_member_active`。 |
| `member_expire_at` | `timestamptz` | 可空 | 会员到期时间。`NULL` 表示不限期（买断制）。 |
| `app_open_count` | `integer` | `not null default 0` | **打开 App 次数**（会话数）。由 `app_events` 触发器 `trg_app_events_bump_user_stats` 累计：`event_name='app_open'`（冷启动 + 30s 回前台 warm 均算一次）。客户端不可改。 |
| `tool_usage_count` | `integer` | `not null default 0` | **工具使用次数**。同上触发器累计：`event_name='tool_entry_open'` **且** `params->>'implemented' != 'false'`（排除「开发中」占位工具点击）。客户端不可改。 |
| `current_device_version` | `text` | 可空 | **当前设备版本**（最近一次产生上述统计事件时的 `os + os_version` 原文，如 `ios 26.0` / `android 14`）。取自 `app_events.device`，展示层可自行加「苹果/安卓」等本地化前缀。客户端不可改。 |
| `token` | `text` | 可空，部分唯一索引 | **权限 token**（2026-09-08 新增）。HS256 JWT，payload 自包含 `sub`(uid) / `email` / `display_name` / `role` / `aud` / `iat` / `exp`，**有效期 30 天**。由 `ensure_user_token()` 懒生成（已过期则自动重签），`reset_user_token()` 作废重发。**只存登录用户**——游客 token 无状态、不落库。签名 secret 在 Vault（`tool_box_user_token_secret`，数据库端随机生成）。客户端直改被触发器拒绝（`42501`）。详见「六、权限 token」。 |
| `created_at` | `timestamptz` | `not null default now()` | 业务表层面的创建时间（注册时间）。 |
| `updated_at` | `timestamptz` | `not null default now()` | 资料/会员等**业务字段**的更新时间，由 `users_before_update` 触发器自动维护。**埋点联动更新（计数/设备列）不刷新它**，客户端不要传。 |

### 字段补充说明

- **会员字段一律由服务端改**：`is_member` / `member_expire_at` 是「钱相关」字段，客户端写入会被触发器直接拒绝（抛 `42501`）。开通会员只能由 `service_role` / 支付回调执行：
  ```sql
  update public.users
  set is_member = true,
      member_expire_at = greatest(coalesce(member_expire_at, now()), now()) + interval '30 days'
  where id = '<uuid>';
  ```
- **统计字段（2026-09-06 新增）同样只由服务端改**：`app_open_count` / `tool_usage_count` / `current_device_version`
  由 `app_events` 上的触发器 `trg_app_events_bump_user_stats` 在事件落库时联动更新，
  客户端直改会被 `users_before_update` 拒绝。目的：`users` 表即「用户档案汇总」，
  运营侧展示次数无需 count 事件表；且防客户端自行刷数。
  - 新增/回填步骤见 `app_events.sql` 第 7、8 段；**务必先跑 `users.sql` 再加第 7 段触发器**。
  - 匿名事件（未登录）的 `user_id` 是设备匿名 UUID，`public.users` 没有对应行 → UPDATE 影响 0 行，天然不计入。
- **客户端写入原则**：注册 / 编辑资料时 `upsert` 只传 `id / email / display_name / avatar_url` 四个字段，会员与统计字段一个都不传（走数据库默认值）。PostgREST 的 upsert 默认 merge（只更新提供的列），未提供的列不变，因此安全。
- **token 同样客户端不可写**：`users_before_insert` 强制置空、`users_before_update` 拒绝变更（`42501`）。获取 / 作废只能走 `ensure_user_token()` / `reset_user_token()` 两个 RPC。
- **会员状态绝不进 `raw_user_meta_data` / JWT**：`user_metadata` 用户自己可改，拿它判权限等于把门禁交给用户。
- **`updated_at` 语义（2026-09-06 收窄）**：只有**业务字段**（资料/会员）变化才由 `users_before_update` 刷新；
  埋点联动只动计数/设备列时保留旧值——否则每次打开 App 都会把「最后修改资料时间」顶到当前。若旧版触发器无条件刷新的行为需保留，删掉 `_business_changed` 判断即可。

## 三、安全策略

### GRANT（2026-05-30 起必需）

```sql
grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.users to service_role;
revoke all on public.users from anon;
```

> ⚠️ 2026-04-28 起 `public` schema 的新表**不再自动暴露给 Data API**，缺 GRANT 时 PostgREST 会在 RLS 之前就返回 `42501 permission denied`，极容易误判成 RLS 配错。必须「GRANT + RLS + policy」三件套一起给。

### RLS 策略

| 策略 | 操作 | 谓词 |
| --- | --- | --- |
| `read own row` | `select` | `(select auth.uid()) = id` |
| `insert own row` | `insert` | `with check ((select auth.uid()) = id)` |
| `update own row` | `update` | `using + with check` **都要有**（只有 `using` 时用户能把行改写成别人的 id，越权转移） |

`to authenticated` 单独用只是「认证」不是「授权」，必须配合 `using` 里的所有权判断。

### 会员字段防提权（触发器）

`update own row` 允许 authenticated 改自己那行的**任意字段**，不加控制就能把自己改成会员（白嫖）。用两个 `before` 触发器堵住：

| 触发器 | 时机 | 行为 |
| --- | --- | --- |
| `users_before_insert` | insert 前 | 非特权调用者强制 `is_member = false` / `member_expire_at = null`，杜绝「注册即会员」 |
| `users_before_update` | update 前 | ① 维护 `updated_at`；② 会员字段与旧值 `is distinct from` 就 `raise exception`（`42501`） |

> 为什么不用「策略里子查询本表旧值」：策略表达式里子查询**本表**会踩 Postgres 的 RLS 递归检测，可能报 `infinite recursion detected in policy`。触发器读 `old` / `new` 伪记录，零歧义。

## 四、新用户补行

- **新建用户**：`auth.users` 上的 `after insert` 触发器 `on_auth_user_created` → `handle_new_user()`（`security definer`）自动往 `public.users` 补一行。`security definer` 不可省——新用户还没有 session，`auth.uid()` 为空。
- **存量账号**：触发器只对新增行生效，「先注册后建表」的老账号不会自动进 `public.users`。执行 `scripts/sql/users.sql` 第 8 段的补齐语句即可（会员字段走默认值，不会被误开通）。

## 五、常用验证 SQL

```sql
-- 授权核对：期望 authenticated = INSERT,SELECT,UPDATE；service_role 全项；没有 anon
select grantee, string_agg(privilege_type, ',' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'users'
group by grantee;

-- 确认 RLS 已启用（relrowsecurity 应为 t）
select relname, relrowsecurity from pg_class where relname = 'users';

-- 会员到期提醒（未来 7 天内到期）
select id, email, member_expire_at
from public.users
where is_member and member_expire_at between now() and now() + interval '7 days';

-- 刷新 PostgREST schema cache（表已建好但 REST 仍报 PGRST205 时执行）
notify pgrst, 'reload schema';
```

## 六、权限 token（2026-09-08 新增，30 天有效）

定义见 [`scripts/sql/users.sql`](../scripts/sql/users.sql) 第 5b 段。

### 形态与生成

- **HS256 JWT**，**有效期 30 天**（`iat` + 30 天写入 `exp`），到期必须重新签发。
- **两类身份**：

  | 身份 | `ensure_user_token()` 参数 | payload 关键项 | 落库 |
  | --- | --- | --- | --- |
  | 登录用户 | 不传（服务端取 `auth.uid()`） | `sub`(uid) / `email` / `display_name` / `role='authenticated'` | ✅ `users.token`，过期自动重签 |
  | 游客（未登录） | `p_anonymous_id` = 设备匿名 UUID | `sub`(匿名 UUID) / `is_anonymous=true` / `role='anonymous'` / `aud='visitor'` | ❌ 无状态签发，客户端缓存到 `exp` |

- **懒生成**：注册时不签发（vault secret 未配置时不能炸注册链路），首次调用才生成；**已过期则自动重签**（不是无条件幂等）。
- **签名 secret** 存 Supabase Vault（`tool_box_user_token_secret`），由脚本在数据库端用 `gen_random_bytes(32)` 随机生成——`app.settings.jwt_secret` 已于 2024-11-22 从数据库移除，secret 只能走 Vault。
- 游客 token **不落库**：`users` 表没有匿名行，硬插会污染账号与统计体系；游客权限最低，伪造 `sub` 也只是「另一个游客」，无横向越权。
- payload 是 base64 **明文编码**（防篡改、不加密），token 里永远别放密码类敏感信息。

### 客户端用法（Flutter）

统一走 [`AppTokenManager`](../lib/common/auth/app_token_manager.dart)，业务不要直接调 RPC：

```dart
final AppTokenSnapshot r = await AppTokenManager.ensureValidToken();
switch (r.status) {
  case AppTokenStatus.valid:       // 用 r.token 发请求（本地缓存，未过期零网络）
  case AppTokenStatus.needReLogin: // 已置位 tokenExpiredPending，路由自动跳登录页
  case AppTokenStatus.unavailable: // Supabase 未配置 / 网络异常，业务自己降级
}
```

**过期拦截链路**：`AppTokenManager` 判定需重新登录 → 置位 `tokenExpiredPending` →
GoRouter 的 `refreshListenable`（合并了「密码恢复」与「token 失效」两个来源）触发
`redirect` → 跳 `/login`（一次性消费标记，不会反复弹）。游客 token 过期不会触发重新登录，直接重签。

后端 / 脚本直接调 RPC：

```sql
select public.ensure_user_token();                                        -- 登录用户（带 session）
select public.ensure_user_token('11111111-2222-3333-4444-555555555555');   -- 游客
```

### 验证方怎么验（回答「Supabase 能验证吗」）

| 验证方 | 怎么验 |
| --- | --- |
| 自建后端 / 脚本 | 从 Vault 取 secret 后用任意 JWT 库做 HS256 验签，**并校验 exp**：`select decrypted_secret from vault.decrypted_secrets where name = 'tool_box_user_token_secret';` |
| Supabase Data API（PostgREST） | 默认**不认**这个 token（隔离设计，token 只服务 Supabase 之外的验证方）。若需要它也认：把 Vault 里的 secret 换成项目 legacy JWT secret（Dashboard → Settings → API Keys，需处于启用状态），payload 已带 `role/aud='authenticated'`，验签通过后 `auth.uid()` 即取 `sub` |
| App 自己 | 照常走登录 session（access_token + refresh 自动续期），与本 token 互不影响 |

### 防护与作废

- 客户端直改 `token` 列 → `users_before_insert` 强制置空 / `users_before_update` 抛 `42501`；部分唯一索引 `users_token_uidx`（`where token is not null`）。
- **泄露后手动作废**：调 `reset_user_token()` 清空重发（只对登录用户有效，游客 token 无状态、过期即失效），或直接轮换 Vault secret（全体 token 一起作废）。30 天有效期把泄露窗口压到最长 30 天。
- 邮箱是签发时快照：用户改邮箱后 token 里仍是旧值（App 目前不支持改邮箱，暂无影响；支持后需在改邮箱处 reset token）。

```sql
-- 验证：四个 RPC 就位 + secret 已建
select proname from pg_proc where pronamespace = 'public'::regnamespace
  and proname in ('ensure_user_token','reset_user_token','b64url','jwt_payload');
select name from vault.decrypted_secrets where name = 'tool_box_user_token_secret';

-- 看某个用户 token 的过期时间
select id, public.jwt_payload(token) ->> 'exp' as exp_unix,
       to_timestamp((public.jwt_payload(token) ->> 'exp')::bigint) as expires_at
from public.users where token is not null;
```

# 用户资料视图user_profiles

> 定义见 [`scripts/sql/users.sql`](../scripts/sql/users.sql) 第 6 段 · 客户端读取：[`user_profile_provider.dart`](../lib/feature/profile/provider/user_profile_provider.dart)

基于 `public.users` 的**只读投影**，唯一职责是多算一个 `is_member_active`（会员当前是否有效），避免「过期判断」逻辑同时散落在 SQL 与 Dart 两处。

```sql
drop view if exists public.user_profiles;
create view public.user_profiles with (security_invoker = true) as
select u.*,
       (u.is_member and (u.member_expire_at is null or u.member_expire_at > now())) as is_member_active
from public.users u;

grant select on public.user_profiles to authenticated;
grant select on public.user_profiles to service_role;
revoke all on public.user_profiles from anon;
```

## 一、字段说明

| 列名 | 类型 | 说明 |
| --- | --- | --- |
| `id` / `email` / `display_name` / `avatar_url` | 同 `public.users` | 原样投影（`u.*`）。 |
| `is_member` | `boolean` | 原样投影。**只表示「买过」**，过期仍是 `true`。 |
| `member_expire_at` | `timestamptz` | 原样投影。`NULL` = 不限期。 |
| `app_open_count` / `tool_usage_count` | `integer` | 原样投影。打开 App 次数 / 工具使用次数（见 users 章）。 |
| `current_device_version` | `text` | 原样投影。如 `ios 26.0` / `android 14`。 |
| `created_at` / `updated_at` | `timestamptz` | 原样投影。 |
| **`is_member_active`** | `boolean` | **视图新增列**，唯一存在的理由。`is_member = true` **且**（`member_expire_at is null` 或 `> now()`）时才为 `true`。App 端判断会员权益一律用这一列。 |

### `is_member` vs `is_member_active`

| 场景 | `is_member` | `is_member_active` |
| --- | --- | --- |
| 从未购买 | `false` | `false` |
| 买断制（无到期时间） | `true` | `true` |
| 订阅中，未到期 | `true` | `true` |
| **订阅已过期** | `true` | **`false`** ← 差别在这里 |

## 二、为什么必须 `security_invoker = true`

Postgres 15 起视图**默认以 owner 权限运行，会绕过基表 RLS（全表可见）**——这是极其危险的默认行为。加上 `with (security_invoker = true)` 后视图继承调用者身份，底层 `public.users` 的 RLS（`id = auth.uid()`）依旧生效，读视图不会绕过行级安全。需 PG15+。

## 三、使用约定

- **读用视图，写用表**：`profile` 页展示走 `user_profiles`（已算好有效态），编辑资料写入走 `public.users`。
- **为什么写表不写视图**：视图只授了 `SELECT`，写不进去；且视图是只读投影，通过它改数据属于绕路。写表时 PostgREST 会走 `public.users` 自己的 RLS 与触发器，安全边界不变。
- **查不到行不算错误**：触发器还没来得及补行时视图会返回空，客户端 `UserProfile.fromRow` 全部字段可空，UI 用 Auth 侧的 `User` 信息兜底（头像 → 默认头像，昵称 → 邮箱前缀）。

## 四、常用验证 SQL

```sql
-- 确认视图带 security_invoker（reloptions 应含 security_invoker=true）
select c.relname, c.reloptions from pg_class c where relname = 'user_profiles';

-- 当前有效会员数
select count(*) from public.user_profiles where is_member_active;

-- 已过期但标记仍为会员的行（用于核对数据一致性）
select id, email, member_expire_at
from public.user_profiles
where is_member and not is_member_active;
```
