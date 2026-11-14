-- ============================================================================
-- 文件职责：给 public.users 补齐 tool_usage_count 列（免费工具使用次数上限功能所需）。
-- 所属模块：tool_box 账号体系（免费额度限制，2026-09-13）。
--
-- 背景：
--   public.users.tool_usage_count 在 scripts/sql/users.sql 规范中已定义，并由
--   scripts/sql/app_events.sql 的 trg_app_events_bump_user_stats 触发器在服务端
--   根据 tool_entry_open 埋点事件自动累计（登录用户生效，匿名用户影响 0 行）。
--   客户端禁止直写该列（users.sql 第 4 段 users_before_update 会拦截，报 42501）。
--
--   本文件用于给「早于该规范」的线上库补齐该列。幂等，可重复执行。
--
-- 使用方法（二选一）：
--   1. Supabase Dashboard → SQL Editor 整段粘贴执行；
--   2. supabase db query 执行（CLI v2.79.0+，否则用 MCP execute_sql / psql）。
-- 执行后无需额外 GRANT / RLS：新列继承 public.users 既有策略，且 Data API
-- 暴露已由 users.sql 第 2 段统一授予 authenticated。
-- ============================================================================

-- ① 补齐列（IF NOT EXISTS 保证重复执行安全；默认 0，NOT NULL 不破坏既有行）
alter table public.users
  add column if not exists tool_usage_count integer not null default 0;

-- ② 若线上库的 app_events 触发器还是旧版（不含 tool_usage_count 累加逻辑），
--    请重新执行 scripts/sql/app_events.sql 第 7 段的 trg_app_events_bump_user_stats，
--    否则云端计数不会随工具使用自增（本地限额仍正常工作，仅云端同步失效）。
--
-- 校验：
--   select id, tool_usage_count from public.users
--   where id = '<当前登录用户 uuid>' order by tool_usage_count desc limit 5;
--   多打开几次工具（已登录态）后，该值应随 app_events 触发器自增。
