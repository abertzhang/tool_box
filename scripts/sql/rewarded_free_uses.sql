-- ============================================================================
-- 文件职责：新增「看激励广告获得的额外免费次数」字段与配套 RPC。
-- 所属模块：tool_box 免费使用次数额度（2026-09-16 定，奖励次数模型）。
--
-- 模型（与客户端 lib/common/provider/app_settings/free_usage_provider.dart 一致）：
--   剩余免费次数 = 基础额度 + 广告奖励(bonus) − 已用次数
--     · 基础额度：未登录 5 次、已登录 10 次（**客户端判定**，服务端不存基础额度）；
--     · 广告奖励：每完整看完一条激励广告 +5，累加进 bonus_free_uses 列；
--     · 已用次数：继续复用既有 users.tool_usage_count / anonymous_devices.free_tool_usage_count。
--
-- 为什么要单独加一列（不再沿用旧的「已用计数 −1」）：
--   旧模型把奖励表达成「已用次数减 1」，剩余次数被基础额度封顶——额度满时看广告
--   是 no-op，用户没有观看动机，奖励也无法累积。新列让奖励**独立累加、不封顶**，
--   「看一次得 5 次」才有实际意义（同时激励广告本身带来收益）。
--
-- 为什么走 SECURITY DEFINER RPC：
--   · anonymous_devices 对 anon/authenticated 收回了直接权限（见 anonymous_devices.sql），
--     只能走 RPC；
--   · public.users 虽允许本人 select 自己那行（bonus 直读没问题），但写入统一走 RPC
--     便于审计、也便于将来加「每日奖励上限」之类的限制。
--   SECURITY DEFINER 以 postgres（rolbypassrls）身份执行，is_privileged_caller() 返回
--   true，users_before_update 触发器放行（与 decrement_user_usage_count 同一机制）。
--
-- 使用方法（沙箱无法代跑，需用户本机执行）：
--   1. 前置：已执行 users.sql 与 anonymous_devices.sql（两张表已存在）；
--   2. Supabase SQL Editor 整段粘贴执行；或 supabase db push；
--   3. 幂等：列用 add column if not exists，函数用 create or replace，可重复执行；
--   4. 客户端调用：
--        supabase.rpc('grant_rewarded_free_uses',        params: {'p_amount': 5})   -- 已登录
--        supabase.rpc('grant_anon_rewarded_free_uses',   params: {'p_device_id': hash, 'p_amount': 5})
--        supabase.rpc('get_or_create_anon_device',       params: {'p_device_id': hash})  -- 返回值新增 bonus_free_uses 列
--
-- ⚠️ 破坏性说明：get_or_create_anon_device 的返回类型从 2 列扩到 3 列，
--   PostgreSQL 不允许 create or replace 修改返回类型，故先 drop 再 create。
--   函数不持有数据，drop 无数据风险；授权在下方第 5 节重新 grant。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 新列：public.users.bonus_free_uses（已登录用户的广告奖励次数）
-- ----------------------------------------------------------------------------
alter table public.users
  add column if not exists bonus_free_uses integer not null default 0;

comment on column public.users.bonus_free_uses is
  '看激励广告获得的额外免费次数（每次 +5，可累加、不封顶）；剩余次数 = 基础额度 + 本列 - tool_usage_count';

-- ----------------------------------------------------------------------------
-- 2. 新列：public.anonymous_devices.bonus_free_uses（游客按设备累计的奖励次数）
-- ----------------------------------------------------------------------------
alter table public.anonymous_devices
  add column if not exists bonus_free_uses integer not null default 0;

comment on column public.anonymous_devices.bonus_free_uses is
  '该设备看激励广告获得的额外免费次数（每次 +5，可累加、不封顶），语义同 users.bonus_free_uses';

-- ----------------------------------------------------------------------------
-- 3. 重建 get_or_create_anon_device：返回值补上 bonus_free_uses
-- ----------------------------------------------------------------------------
drop function if exists public.get_or_create_anon_device(text);

create function public.get_or_create_anon_device(p_device_id text)
returns table (device_id text, free_tool_usage_count integer, bonus_free_uses integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- 入参兜底：空 / 过短 / 过长（哈希串固定 64 字符，留余量）直接报错，避免脏数据。
  if p_device_id is null or length(p_device_id) < 8 or length(p_device_id) > 128 then
    raise exception 'invalid device_id';
  end if;

  -- upsert：首次插入 0，已存在则仅刷新活跃时间（两个计数都不动）。
  insert into public.anonymous_devices (device_id, free_tool_usage_count, bonus_free_uses, last_seen_at)
  values (p_device_id, 0, 0, now())
  on conflict (device_id) do update set last_seen_at = now();

  -- 返回该设备当前的两个计数（已用 + 广告奖励）。
  return query
    select a.device_id, a.free_tool_usage_count, a.bonus_free_uses
    from public.anonymous_devices a
    where a.device_id = p_device_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. 新 RPC：已登录用户 bonus_free_uses += p_amount，返回累加后的值
-- ----------------------------------------------------------------------------
create or replace function public.grant_rewarded_free_uses(p_amount integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- 入参兜底：只接受 1..100 的正整数。
  -- 上限不是为了限制用户攒额度，而是防止客户端异常 / 被篡改后一次写入荒谬的大数。
  if p_amount is null or p_amount < 1 or p_amount > 100 then
    raise exception 'invalid amount';
  end if;

  update public.users
     set bonus_free_uses = public.users.bonus_free_uses + p_amount
   where id = auth.uid()
  returning bonus_free_uses into v_new;

  -- 用户行尚未建好（触发器延迟建行）时 update 影响 0 行，返回 0 而不是报错，
  -- 避免把「还没建行」当成奖励发放失败去重试。
  return coalesce(v_new, 0);
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. 新 RPC：游客设备 bonus_free_uses += p_amount，返回累加后的值
-- ----------------------------------------------------------------------------
create or replace function public.grant_anon_rewarded_free_uses(
  p_device_id text,
  p_amount    integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new integer;
begin
  if p_device_id is null or length(p_device_id) < 8 or length(p_device_id) > 128 then
    raise exception 'invalid device_id';
  end if;

  if p_amount is null or p_amount < 1 or p_amount > 100 then
    raise exception 'invalid amount';
  end if;

  -- upsert：设备行不存在时顺带建行（奖励次数即初始值）。
  insert into public.anonymous_devices (device_id, free_tool_usage_count, bonus_free_uses, last_seen_at)
  values (p_device_id, 0, p_amount, now())
  on conflict (device_id) do update set
    bonus_free_uses = public.anonymous_devices.bonus_free_uses + p_amount,
    last_seen_at    = now()
  returning bonus_free_uses into v_new;

  return coalesce(v_new, 0);
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. 授权
-- ----------------------------------------------------------------------------
grant execute on function public.get_or_create_anon_device(text) to anon, authenticated;
grant execute on function public.grant_anon_rewarded_free_uses(text, integer) to anon, authenticated;

-- 登录用户专有的两个：显式收回 PUBLIC / anon，避免未登录调用。
grant execute on function public.grant_rewarded_free_uses(integer) to authenticated;
revoke execute on function public.grant_rewarded_free_uses(integer) from PUBLIC;
revoke execute on function public.grant_rewarded_free_uses(integer) from anon;

-- 刷新 PostgREST schema 缓存，使新列 / 新函数 / 改签名的函数立即对外可见。
notify pgrst, 'reload schema';
