-- ============================================================================
-- 文件职责：把测试环境的数据库「全清」—— public schema 下所有业务表
--           + auth.users（及其全部关联子表），达到彻底重置的目的。
-- 所属模块：tool_box 账号体系（与 scripts/sql/truncate_public.sql、
--           cleanup_orphan_users.sql 配套；本脚本是「最彻底」版）。
-- 关键依赖：PostgreSQL 15+、Supabase Auth（auth schema）。
--
-- ⚠️ 适用范围：仅用于「全是测试账号」的测试/预发环境。
--   · 本脚本会注销所有注册用户（auth.users 全删），下次必须重新注册才能登录。
--   · 表结构 / 函数 / 视图 / 索引 / 触发器 / RLS 策略全部保留，只删数据。
--   · 执行前建议先备份（Dashboard → Backups 开 PITR，或
--     pg_dump --data-only -n public -n auth > backup.sql）。
--
-- 使用方法：Supabase 控制台 → SQL Editor，按 0 → 1 → 2 三段分步粘贴执行。
--   第 0 段：只查不动，先确认要清的清单与行数；
--   第 1 段：真正删除；
--   第 2 段：复跑第 0 段查询，确认行数全为空。
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 第 0 步：只读盘点（先确认再删）
-- ----------------------------------------------------------------------------

-- public 下所有真实表的清单（视图 user_profiles 不是表，自然不在这里）
-- ⚠️ pg_tables 的表名字段是 tablename（不是 pg_class 里的 relname）
select tablename as table_name
from pg_catalog.pg_tables
where schemaname = 'public'
order by tablename;

-- 直接用各表实测行数（更直观，视图 user_profiles 会随 users 空而空）
select
  'public.users'      as tbl, count(*) from public.users
union all
select 'public.app_events', count(*) from public.app_events;

-- auth 侧现有账号与关联数据规模（确认要注销的范围）
select
  (select count(*) from auth.users)         as auth_users,
  (select count(*) from auth.identities)    as auth_identities,
  (select count(*) from auth.sessions)      as auth_sessions,
  (select count(*) from auth.mfa_factors)   as auth_mfa_factors,
  (select count(*) from auth.flow_state)    as auth_flow_state;


-- ----------------------------------------------------------------------------
-- 第 1 步：真正清数据
-- ----------------------------------------------------------------------------

-- (A) public schema 下所有真实表逐个 TRUNCATE ... RESTART IDENTITY CASCADE
--     · 动态拼出表名，自动覆盖 users / app_events 及以后新增的任何表；
--     · CASCADE 处理表间外键；RESTART IDENTITY 把自增序列归零；
--     · 跳过视图（user_profiles 是视图，不在 pg_tables 里）。
do $$
declare
  r record;
begin
  for r in
    select quote_ident(t.schemaname) || '.' || quote_ident(t.tablename) as full_name
    from pg_catalog.pg_tables t
    where t.schemaname = 'public'
  loop
    execute format('truncate table %s restart identity cascade;', r.full_name);
    raise notice 'truncated -> %', r.full_name;
  end loop;
end $$;

-- (B) 注销所有 auth 账号：先删 auth 内部关联子表，再删 auth.users
--     用 do 块逐表 delete 并吞掉「表不存在」异常，兼容不同 Supabase 版本的
--     auth schema（老版本有 refresh_tokens，新版本并入 sessions 等）。
--     删除顺序必须是从子到父，否则外键约束会挡住 delete。
do $$
declare
  v_stmt text;
begin
  -- 关联子表清单（存在才删，不存在忽略）。
  -- ⚠️ 用数组 + foreach（不用 for...in values）：后者循环变量是匿名 record，
  --    在 execute 里引用 v_sql.column1 会被当成 SQL 表引用报 42P01，
  --    foreach 用标量 text 变量最稳。
  foreach v_stmt in array array[
    'delete from auth.identities',
    'delete from auth.sessions',
    'delete from auth.refresh_tokens',
    'delete from auth.mfa_challenges',
    'delete from auth.mfa_factors',
    'delete from auth.flow_state',
    'delete from auth.audit_log_entries',
    'delete from auth.one_time_tokens'
  ] loop
    begin
      execute v_stmt;
      raise notice 'cleared -> %', v_stmt;
    exception
      when undefined_table then
        raise notice 'skip (no such table) -> %', v_stmt;
      when others then
        raise notice 'ERROR on %: %', v_stmt, sqlerrm;
    end;
  end loop;

  -- 最后清 auth.users 本体（此时子表已空，不再有外键约束）
  delete from auth.users;
  raise notice 'cleared -> auth.users';
end $$;

-- (C) 刷新 PostgREST schema cache（清库后表结构未变，可省略；保险起见保留）
notify pgrst, 'reload schema';


-- ----------------------------------------------------------------------------
-- 第 2 步：复核（应全部为 0）
-- ----------------------------------------------------------------------------
select
  (select count(*) from public.users)      as public_users,
  (select count(*) from public.app_events) as public_app_events,
  (select count(*) from auth.users)        as auth_users,
  (select count(*) from auth.identities)   as auth_identities,
  (select count(*) from auth.sessions)     as auth_sessions;

-- 验收标准：public_users / public_app_events / auth_users 全为 0 即重置成功。
-- 之后在 App 用任意测试邮箱重新注册，handle_new_user 触发器会自动重建
-- public.users 行，回到干净的初始状态。
