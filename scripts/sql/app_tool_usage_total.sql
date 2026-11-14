-- ============================================================================
-- 文件职责：新增 SECURITY DEFINER 聚合函数 get_app_tool_usage_total()。
--
-- 返回「全 App 工具使用总量」= 所有登录用户的 tool_usage_count
--                        + 所有游客设备的 free_tool_usage_count 之和。
--
-- 为什么必须服务端聚合（不能客户端算）：
--   - 客户端（anon / authenticated 角色）受 RLS 限制，读不到其它用户 / 其它设备行，
--     本地无法做跨行 sum；
--   - 统计口径与「个人使用次数」正交：个人用 free_usage_provider 读自己的列，
--     全局总量必须由本函数统一聚合，避免客户端各自加总导致口径漂移。
--
-- 执行方式：在 Supabase SQL Editor 跑本文件即可（涉及服务端函数，沙箱无法自动执行）。
--   函数未部署时，客户端 rpc() 会抛 PGRST 错误，Dart 侧已 catch 回落 0，不会崩溃。
-- ============================================================================

create or replace function public.get_app_tool_usage_total()
returns integer
language sql
security definer
set search_path = public
as $$
  select coalesce((select sum(tool_usage_count)        from public.users),           0)
       + coalesce((select sum(free_tool_usage_count)  from public.anonymous_devices), 0);
$$;

-- 客户端用 anon key（游客态）与 authenticated（登录态）两种角色都会调用，故两者都授权执行。
grant execute on function public.get_app_tool_usage_total() to anon, authenticated;

comment on function public.get_app_tool_usage_total() is
  '全 App 工具使用总量：所有登录用户 tool_usage_count 与所有游客设备 free_tool_usage_count 之和。客户端只读，走 RPC 聚合，无法本地计算。';
