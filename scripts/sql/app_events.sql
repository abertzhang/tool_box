-- ============================================================================
-- 文件职责：Supabase 埋点表 app_events 建表脚本。
-- 所属模块：tool_box 埋点工具类（lib/common/track/）。
-- 关键依赖：PostgreSQL 15+（gen_random_uuid 默认已包含）、Supabase。
--
-- 使用方法：
--   1. 在 Supabase SQL Editor 整段粘贴并执行；
--   2. 默认走 Edge Function 网关写入（service_role 绕过 RLS），无需 anon GRANT；
--   3. 若临时改用 REST 直写（开发场景），取消下方 REST 直写 GRANT/RLS 段的注释。
--
-- 安全约束（对齐 supabase 技能 2026-05-30 变更）：
--   新建表默认不暴露给 Data API，写入必须显式 GRANT；
--   本脚本默认不暴露给 anon/authenticated，仅供 Edge Function（service_role）写入。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 表结构
-- ----------------------------------------------------------------------------
-- 说明：使用复数单数中性名 `app_events`，便于多个 App 共享同一张表
--       （每条 row 的 app_id 区分来源，避免每 App 一张表造成 schema 膨胀）。
create table if not exists app_events (
  -- 主键：服务端生成的 UUID，便于去重 / 跨设备聚合
  id          uuid        primary key default gen_random_uuid(),
  app_id      text        not null,
  -- 用户身份 UUID。**登录时** = `auth.users.id`；**未登录时** = 客户端设备级匿名 UUID。
  -- 为什么未登录也要填值而不是留 null：
  --   1. null 无法参与 `count(distinct user_id)`，未登录用户的独立设备数算不出来；
  --   2. 匿名 ID 稳定存于客户端本地，可把"登录前 → 登录后"的行为串成一条链路。
  -- 怎么区分二者：看 `params->>'is_anonymous'`（true = 未登录的匿名 ID）。
  --   params 里另有 `anonymous_id`，无论登录与否都有值，用于按设备维度聚合。
  -- 注意：不要在该列放 email/phone 等 PII；若确需关联，用 Supabase auth.uid()
  user_id     uuid        null,
  -- 会话 ID：客户端一次启动生成同一个 UUID，可用于"漏斗 / 留存"分析
  session_id  uuid        not null,
  -- 事件名：推荐 snake_case，按业务聚合，如 `tool_entry_open` / `noise_measure_start`
  event_name  text        not null,
  -- 事件参数：自由 jsonb，避免定义过多离散列；GIN 索引支持高效过滤
  params      jsonb       not null default '{}'::jsonb,
  -- 客户端平台：`ios` / `android` / `macos` / `windows` / `linux` / `web`
  platform    text        not null,
  -- App 版本号（含 build 号），与 PackageInfo 保持一致，如 `1.0.0+1`
  app_version text        not null,
  -- 设备上下文：型号、OS 版本、locale、时区等（已脱敏处理）
  device      jsonb       not null default '{}'::jsonb,
  -- 客户端发生时间（含时区信息）；后续按设备时区显示与按服务器时区分析都要兼容
  occurred_at timestamptz not null,
  -- 服务端接收时间（Edge Function 落地时间），用于判断延迟 / 队列堆积
  received_at timestamptz not null default now(),
  -- 创建时间（与 received_at 同步，但语义保留以便后续拆分）
  created_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 2. 索引：覆盖 4 类典型查询
-- ----------------------------------------------------------------------------
-- 注意：所有索引都先把 `created_at desc` 排序好，避免额外排序开销。
-- 高频查询 1：按 App + 时间窗口查询（最常见 BI 查询）
create index if not exists idx_app_events_app_time
  on app_events (app_id, created_at desc);

-- 高频查询 2：按用户 + 时间窗口（用户行为漏斗 / 留存）
-- 客户端自 2026-09-06 起保证 user_id 非空（未登录时填设备匿名 UUID，见字段注释），
-- 因此用普通索引即可覆盖全表，不再需要 `where user_id is not null` 的 partial 形式。
-- ⚠️ 存量库早期建过 partial 版本的，需按文末「6. 存量库迁移」手工重建。
create index if not exists idx_app_events_user_time
  on app_events (user_id, created_at desc);

-- 高频查询 2b：按「是否登录」筛选（区分真实账号用户与匿名设备）
-- 表达式索引：直接对 jsonb 里的文本字段建索引，避免每次全表解析 params。
create index if not exists idx_app_events_anonymous
  on app_events ((params ->> 'is_anonymous'), created_at desc);

-- 高频查询 3：按事件名统计（PV/UV、漏斗首步监控）
create index if not exists idx_app_events_name_time
  on app_events (event_name, created_at desc);

-- 高频查询 4：参数属性过滤（params @> '{"tool":"compass"}' 这种）
-- jsonb_path_ops 是 GIN 专属变体，仅支持 @> 但体积更小、性能更好
create index if not exists idx_app_events_params_gin
  on app_events using gin (params jsonb_path_ops);

-- ----------------------------------------------------------------------------
-- 3. 行级安全（RLS）：默认禁止客户端直写
-- ----------------------------------------------------------------------------
-- 推荐生产路径：Edge Function 用 service_role 写表，自动绕过 RLS。
-- 因此：打开 RLS，但不创建任何 anon/authenticated 策略，客户端无法直写。
alter table app_events enable row level security;

-- 仅允许通过 service_role（被 Edge Function 使用）写入；客户端 anon/authenticated 无权。
-- 注意：service_role 本身绕过 RLS，不需要再额外授权。

-- ----------------------------------------------------------------------------
-- 4. （可选）REST 直写方案：如果你不想部署 Edge Function，可放开以下 GRANT 与策略
-- ----------------------------------------------------------------------------
-- 警告：暴露 anon INSERT 意味着任何拿到 URL 的人都能写入，务必：
--   a) 在 PostgREST 前加网关限流（如 Cloudflare / Vercel Bot Protection）；
--   b) app_id 用合法白名单约束（见下方 policy）；
--   c) 配合 IP / token 限流。
--
-- -- 4.1 显式 GRANT：新表默认不暴露给 Data API，必须授权
-- grant insert on app_events to anon, authenticated;
--
-- -- 4.2 RLS 策略：仅允许白名单 app_id 写入
-- alter table app_events enable row level security;
-- create policy "track_insert_whitelist" on app_events
--   for insert to anon, authenticated
-- -- 默认拒绝 select，避免 anon 拉取所有事件数据
-- -- 若需要 select，按 RLS 规则精确按 user_id 限定。

-- ----------------------------------------------------------------------------
-- 5. 验证
-- ----------------------------------------------------------------------------
-- 执行以下查询，确认表已建好且索引齐全：
--   select indexname from pg_indexes where tablename = 'app_events' order by indexname;
-- 执行以下查询，确认 RLS 已启用：
--   select relname, relrowsecurity from pg_class where relname = 'app_events';

-- ----------------------------------------------------------------------------
-- 6. 存量库迁移（2026-09-06：user_id 不再为 null）
-- ----------------------------------------------------------------------------
-- 背景：早期客户端未绑定身份，`user_id` 全为 null，且索引是 partial 形式。
-- 客户端修复后新数据已带值，存量数据需要两步收尾。
--
-- 6.1 重建索引：partial index（`where user_id is not null`）在新语义下
--     等价于普通索引却多一个过滤条件，直接换成普通版。
--     ⚠️ `create index if not exists` 对同名但定义不同的索引**不会**重建，必须手工 drop。
--
-- drop index if exists idx_app_events_user_time;
-- create index idx_app_events_user_time
--   on app_events (user_id, created_at desc);
-- create index if not exists idx_app_events_anonymous
--   on app_events ((params ->> 'is_anonymous'), created_at desc);
--
-- 6.2 回填历史行（可选）：把同一 session 内「后来登录了」的事件 user_id，
--     回填给该 session 早期 user_id 为 null 的行。
--     只回填能明确归属的会话，猜不出归属的保持 null（不要瞎填）。
--
-- update app_events t
--    set user_id = s.user_id
--   from (
--     select session_id,
--            min(user_id) as user_id      -- 同一 session 内任一条真实用户 ID
--       from app_events
--      where user_id is not null
--      group by session_id
--   ) s
--  where t.session_id = s.session_id
--    and t.user_id is null;
--
-- 6.3 校验：确认回填后仍有 null 的行数（应显著下降，跨会话未登录的会保留 null）
--   select count(*) from app_events where user_id is null;

-- ----------------------------------------------------------------------------
-- 7. 用户统计联动（users 表：打开次数 / 工具使用次数 / 当前设备版本）
-- ----------------------------------------------------------------------------
-- 背景：public.users 自 2026-09-06 起带三个统计字段，由本段触发器在事件落库时
--       自动累计，客户端**不可自行修改**（users.sql 第 4 段已挡住）。
--       这样「users 表即用户档案汇总」，运营侧无需每次都 count 事件表。
--
-- 依赖：
--   - public.users 表与 user_profiles 视图已建（先执行 scripts/sql/users.sql）；
--   - 事件由 Edge Function（service_role）写入 → 触发器以 service_role 执行，
--     对 users 的 UPDATE 走特权通道放行（users_before_update 只挡客户端）。
--
-- 计数口径（务必与业务事件保持一致，改了事件名要同步这里）：
--   app_open_count          ← event_name = 'app_open'（冷启动 + 30s 回前台 warm 均算一次打开）
--   tool_usage_count        ← event_name = 'tool_entry_open' 且 params->>'implemented' != 'false'
--                             （排除「开发中」占位工具的点击，那不算真使用）
--   current_device_version  ← 任意一条上述事件带上 device 的 os + os_version 原文拼接
--                             （如 'ios 26.0' / 'android 14'，不含 PII）

create or replace function public.bump_user_stats_on_event()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  -- 本次事件命中的计数增量：默认 0，下面按事件名分派
  _app_increment  integer := 0;
  _tool_increment integer := 0;
begin
  -- 匿名事件（user_id 是设备匿名 UUID，public.users 里没有对应行）：
  -- update 影响 0 行，无需专门判断，直接返回。
  -- 注意不要在这里 join users 判断 —— 每事件多一次查询是浪费。

  if new.event_name = 'app_open' then
    _app_increment := 1;
  elsif new.event_name = 'tool_entry_open'
    -- implemented 参数缺失时按 true 处理（老客户端 / 未来扩展的兜底）
    and coalesce(new.params ->> 'implemented', 'true') <> 'false' then
    _tool_increment := 1;
  else
    -- 非统计事件：不更新 users，直接放行（高频事件别拖累写入路径）
    return new;
  end if;

  update public.users
     set app_open_count          = app_open_count + _app_increment,
         tool_usage_count        = tool_usage_count + _tool_increment,
         current_device_version  = (new.device ->> 'os') || ' ' || (new.device ->> 'os_version')
   where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_app_events_bump_user_stats on public.app_events;
create trigger trg_app_events_bump_user_stats
  after insert on public.app_events
  for each row execute function public.bump_user_stats_on_event();

-- 收尾：触发器执行体只碰 users 表，而 users 表只允许特权通道 UPDATE；
-- 触发器是 service_role 触发的，天然具备权限，无需额外 GRANT。
-- 若未来改为 anon 直写 app_events（REST 方案），本触发器会因 RLS 拒绝而整体回滚 ——
-- 这正是期望行为：匿名直写不该绕过用户统计的防篡改边界。

-- ----------------------------------------------------------------------------
-- 8. 存量统计回填（可选：为老用户一次性算好三个字段）
-- ----------------------------------------------------------------------------
-- 本段只对「触发器建立之后」的新事件生效；想要老账号也有数，执行一次聚合回填：
--
-- update public.users u
--    set app_open_count          = coalesce((
--          select count(*) from public.app_events e
--           where e.user_id = u.id and e.event_name = 'app_open'
--        ), 0),
--        tool_usage_count        = coalesce((
--          select count(*) from public.app_events e
--           where e.user_id = u.id
--             and e.event_name = 'tool_entry_open'
--             and coalesce(e.params ->> 'implemented', 'true') <> 'false'
--        ), 0),
--        current_device_version  = (
--          select (e.device ->> 'os') || ' ' || (e.device ->> 'os_version')
--           from public.app_events e
--          where e.user_id = u.id
--            and e.event_name in ('app_open', 'tool_entry_open')
--          order by e.created_at desc
--          limit 1
--        )
--  where exists (
--    select 1 from public.app_events e where e.user_id = u.id
--  );
--
-- 校验：
--   select id, email, app_open_count, tool_usage_count, current_device_version
--   from public.users where app_open_count > 0 or tool_usage_count > 0;
