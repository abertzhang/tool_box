-- ============================================================================
-- 文件职责：匿名设备免费额度表 public.anonymous_devices 及配套 RPC。
-- 所属模块：tool_box 免费使用次数限额（游客设备识别，跨重装持久化）。
-- 关键依赖：PostgreSQL 15+、Supabase Auth、PostgREST（RPC）。
--
-- 为什么需要这套表 + RPC：
--   免费用户多数未登录（本 App 登录只服务会员/同步），无法用 auth.uid() 做行级
--   所有权鉴权。若直接把表暴露给 anon，则任何人都可读写全部设备行（越权）。
--   因此遵循本工程既有 check_email_exists 的安全模式：
--     · 表本身对 anon/authenticated 收回直接权限（revoke），只开 RLS；
--     · 所有访问走 SECURITY DEFINER RPC，RPC 只操作「调用方传入的 device_id」
--       那一行，不存在越权读取其它设备数据；
--     · RPC 入参做长度校验，杜绝异常输入。
--   客户端上报的 device_id 是 SHA-256 哈希值（见 lib/common/util/device_id.dart），
--   服务端不存明文设备标识。
--
-- 使用方法（沙箱无法代跑，需用户本机执行）：
--   1. Supabase SQL Editor 整段粘贴执行；或
--   2. supabase db push（若走迁移工作流）；
--   3. 执行后确认 PostgREST schema cache 已刷新（脚本末尾自动 notify）；
--   4. 客户端调用：
--        supabase.rpc('get_or_create_anon_device', params: {'p_device_id': hash})
--        supabase.rpc('bump_anon_device_usage',   params: {'p_device_id': hash})
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 表：匿名设备免费额度
-- ----------------------------------------------------------------------------
create table if not exists public.anonymous_devices (
  device_id             text primary key,  -- 客户端上报的 SHA-256 设备号（64 字符）
  free_tool_usage_count integer not null default 0,  -- 该设备已用免费次数
  first_seen_at        timestamptz not null default now(),
  last_seen_at         timestamptz not null default now()
);

-- 按最后活跃时间清理僵尸设备的运维索引（可选）。
create index if not exists anonymous_devices_last_seen_idx
  on public.anonymous_devices (last_seen_at);

-- ----------------------------------------------------------------------------
-- 2. 安全：开 RLS + 收回 anon/authenticated 对表的直接权限
-- ----------------------------------------------------------------------------
alter table public.anonymous_devices enable row level security;

-- anon 不能直接碰表；所有访问必须走下面的 RPC。
revoke all on public.anonymous_devices from anon;
revoke all on public.anonymous_devices from authenticated;
grant usage on schema public to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. RPC：取或创建设备行，返回当前计数（首次返回 0）
-- ----------------------------------------------------------------------------
-- security definer 不可省：调用者是 anon，无权直读表；
-- 以 owner（postgres，具备 rolbypassrls）身份执行才查得到/写得了。
-- set search_path = '' 防同名对象劫持；函数内所有对象一律写全限定名。
create or replace function public.get_or_create_anon_device(p_device_id text)
returns table (device_id text, free_tool_usage_count integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- 入参兜底：空 / 过短 / 过长（哈希串固定 64 字符，留余量）直接报错，避免脏数据。
  if p_device_id is null or length(p_device_id) < 8 or length(p_device_id) > 128 then
    raise exception 'invalid device_id';
  end if;

  -- upsert：首次插入 0，已存在则仅刷新活跃时间（计数不动）。
  insert into public.anonymous_devices (device_id, free_tool_usage_count, last_seen_at)
  values (p_device_id, 0, now())
  on conflict (device_id) do update set last_seen_at = now();

  -- 返回该设备当前计数。
  return query
    select a.device_id, a.free_tool_usage_count
    from public.anonymous_devices a
    where a.device_id = p_device_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. RPC：计数 +1 并返回新值（upsert 语义，首次即 1）
-- ----------------------------------------------------------------------------
create or replace function public.bump_anon_device_usage(p_device_id text)
returns table (free_tool_usage_count integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_device_id is null or length(p_device_id) < 8 or length(p_device_id) > 128 then
    raise exception 'invalid device_id';
  end if;

  insert into public.anonymous_devices (device_id, free_tool_usage_count, last_seen_at)
  values (p_device_id, 1, now())
  on conflict (device_id) do update set
    free_tool_usage_count = public.anonymous_devices.free_tool_usage_count + 1,
    last_seen_at = now();

  return query
    select a.free_tool_usage_count
    from public.anonymous_devices a
    where a.device_id = p_device_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. 授权 anon/authenticated 调用这两个 RPC
--    （函数默认 EXECUTE 给 PUBLIC，这里显式声明便于审计；表本身不可直读）
-- ----------------------------------------------------------------------------
grant execute on function public.get_or_create_anon_device(text) to anon, authenticated;
grant execute on function public.bump_anon_device_usage(text) to anon, authenticated;

-- 刷新 PostgREST schema 缓存，使新函数/新表立即对外可见。
notify pgrst, 'reload schema';
