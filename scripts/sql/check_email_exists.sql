-- ============================================================================
-- 文件职责：邮箱存在性校验函数 public.check_email_exists（幂等，可重复执行）。
-- 所属模块：tool_box 账号体系（忘记密码 / 后续可用于注册查重）。
-- 关键依赖：PostgreSQL 15+、Supabase Auth（auth.users）、PostgREST（RPC）。
--
-- 为什么需要这个函数：
--   Supabase 的 resetPasswordForEmail 出于「防账号枚举」设计，无论邮箱是否注册
--   都返回成功，客户端拿不到任何区分信息，表现为「随便填个邮箱也发信」；
--   而校验又不能由客户端直接查表：
--     - public.users 在 users.sql 第 75 行对 anon 是 revoke 的（未登录读不到）；
--     - auth.users 在私有 schema，客户端（anon key）根本无权限。
--   因此必须由服务端 SECURITY DEFINER 函数代查，再经 PostgREST 以 RPC 暴露。
--
-- ⚠️ 安全权衡（务必知悉后再上线）：
--   本函数把「某邮箱是否注册」暴露给未登录调用者，本质是一个**账号枚举**接口：
--   攻击者可批量探测哪些邮箱在本站注册过。这是产品上主动选择「未注册要明确提示」
--   所付出的代价（Supabase 默认行为刻意不给这个能力，正是为了防枚举）。
--   缓解建议：
--     ① 前端限制同一会话的尝试频率（连点节流）；
--     ② Supabase Dashboard 侧配置接口限流；
--     ③ 若后续不再需要精确提示，直接 `revoke execute ... from anon` 即可让本函数
--        对未登录调用者失效，无需删函数。
--   函数本身只返回 boolean，不返回任何用户字段，把泄露面压到最小。
--
-- 使用方法：
--   1. Supabase SQL Editor 整段粘贴执行；
--   2. 执行后确认 PostgREST schema cache 已刷新（脚本末尾自动 notify）；
--   3. 客户端调用：supabase.rpc('check_email_exists', params: {'p_email': email})。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 函数本体
-- ----------------------------------------------------------------------------
-- security definer 不可省：调用者是 anon，无权读 auth.users；
-- 以 owner（postgres，具备 rolbypassrls）身份执行才查得到。
-- set search_path = '' 防同名对象劫持；函数内所有对象一律写全限定名。
create or replace function public.check_email_exists(p_email text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- 入参兜底：空串 / 超长（RFC 5321 邮箱上限 320 字符）直接判否，
  -- 既省掉一次扫描，也避免被当成探针打超长串。
  if p_email is null or length(p_email) > 320 then
    return false;
  end if;
  if length(trim(p_email)) = 0 then
    return false;
  end if;

  -- 大小写不敏感比较：邮箱本地部分理论上区分大小写，但主流站点（含 Supabase
  -- 默认行为）都按不敏感处理，这里对齐，避免 Abc@x.com 与 abc@x.com 判定不一致。
  --
  -- 性能说明：lower() 包裹列会让普通 B-tree 索引失效，理论上会走顺序扫描。
  -- 这里刻意不去给 auth.users 建函数索引 —— auth schema 由 Supabase 托管，
  -- 改动会在平台升级时被覆盖或残留。账号量级下（万级以内）顺序扫描开销可忽略；
  -- 真到需要优化时，更合适的做法是把邮箱镜像到 public 侧自建索引，而非动 auth。
  return exists (
    select 1
    from auth.users au
    where lower(au.email) = lower(trim(p_email))
  );
end $$;

-- ----------------------------------------------------------------------------
-- 2. 授权（顺序关键：先显式授予真正需要的角色，再撤销 PUBLIC）
-- ----------------------------------------------------------------------------
-- Postgres 默认把新函数的 EXECUTE 授给 PUBLIC，等于 public schema 里的
-- definer 函数天然是个公开 API；这里收口到具体角色。
--
-- anon 必须保留：忘记密码场景下用户处于「未登录」状态，只有 anon 能调。
grant execute on function public.check_email_exists(text) to anon;
grant execute on function public.check_email_exists(text) to authenticated;
grant execute on function public.check_email_exists(text) to service_role;

revoke execute on function public.check_email_exists(text) from PUBLIC;

-- ----------------------------------------------------------------------------
-- 3. 刷新 PostgREST schema cache（避免「函数已建好但 RPC 仍报 PGRST202」）
-- ----------------------------------------------------------------------------
notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- 4. 验证
-- ----------------------------------------------------------------------------
-- 函数存在性与 definer 属性（prosecdef 应为 t；proconfig 应含 search_path=''）：
--   select p.proname, p.prosecdef, p.proconfig
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'check_email_exists';
--
-- 授权核对（期望：anon / authenticated / service_role 有 EXECUTE，不应有 PUBLIC）：
--   select grantee, privilege_type
--   from information_schema.routine_privileges
--   where routine_schema = 'public' and routine_name = 'check_email_exists';
--
-- 联调（已注册邮箱应返回 t，瞎填的应返回 f）：
--   select public.check_email_exists('someone@example.com');
