-- ============================================================================
-- 文件职责：为「看广告返还免费次数」提供两个减计数 RPC（不新增字段）。
-- 所属模块：tool_box 免费使用次数限额（看广告返还的云端同步，2026-09-13 定稿）。
--
-- 模型（与客户端 free_usage_provider 的 grantAdRefund 一致）：
--   看广告 = 已用次数减 1（等价于剩余免费次数 +1），封顶 10 次（count 不会变负）。
--   不新增任何字段——直接复用既有的 anonymous_devices.free_tool_usage_count
--   与 users.tool_usage_count 两列。
--
-- 为什么必须走 RPC（不能客户端直写）：
--   · anonymous_devices 对 anon/authenticated 收回直读直写权限，只能走 SECURITY DEFINER RPC
--     （与 get_or_create_anon_device / bump_anon_device_usage 同模式）；
--   · users.tool_usage_count 由 app_events 触发器按 tool_entry_open 累计，且被
--     users_before_update 触发器禁止客户端直改（报 42501）。但 SECURITY DEFINER 函数
--     以 postgres（rolbypassrls=true）身份执行，is_privileged_caller() 返回 true，
--     触发器放行——与 ensure_user_token() 更新 users.token 是同一机制。
--
-- 使用方法（沙箱无法代跑，需用户本机执行）：
--   1. 前置：已执行 scripts/sql/anonymous_devices.sql 与 users.sql（表/触发器已就位）；
--   2. Supabase SQL Editor 整段粘贴执行；或 supabase db push；
--   3. 末尾已 notify pgrst 刷新 schema cache；
--   4. 客户端调用：
--        supabase.rpc('decrement_anon_device_usage', params: {'p_device_id': hash})
--        supabase.rpc('decrement_user_usage_count')
--   幂等：函数用 create or replace，可重复执行。
--
-- 迁移说明：若此前执行过旧版 ad_refunds.sql（给两表加了 ad_refunds 列），本脚本不影响它，
--   该列会作为未被引用的「遗留列」存在——无害，可选择保留或手动 drop。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 新 RPC：匿名设备表 free_tool_usage_count -1（不低于 0）
-- ----------------------------------------------------------------------------
create or replace function public.decrement_anon_device_usage(p_device_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_device_id is null or length(p_device_id) < 8 or length(p_device_id) > 128 then
    raise exception 'invalid device_id';
  end if;

  update public.anonymous_devices
     set free_tool_usage_count = greatest(free_tool_usage_count - 1, 0),
         last_seen_at = now()
   where device_id = p_device_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 2. 新 RPC：已登录用户表 tool_usage_count -1（不低于 0，以 auth.uid() 定位本行）
-- ----------------------------------------------------------------------------
-- security definer 不可省：以 postgres 身份执行，绕过 users_before_update 的 42501 拦截。
create or replace function public.decrement_user_usage_count()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.users
     set tool_usage_count = greatest(tool_usage_count - 1, 0)
   where id = auth.uid();
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. 授权
-- ----------------------------------------------------------------------------
grant execute on function public.decrement_anon_device_usage(text) to anon, authenticated;
grant execute on function public.decrement_user_usage_count() to authenticated;
revoke execute on function public.decrement_user_usage_count() from PUBLIC;
revoke execute on function public.decrement_user_usage_count() from anon;

-- 刷新 PostgREST schema 缓存，使新函数立即对外可见。
notify pgrst, 'reload schema';
