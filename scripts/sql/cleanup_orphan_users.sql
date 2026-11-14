-- ============================================================================
-- 文件职责：清理 auth.users 已删除、但 public.users 仍残留的「孤儿行」，
--           并可选地把 public.users.id 加固为外键（on delete cascade），
--           让以后在控制台删用户时业务行自动跟着删，不再产生新的孤儿。
-- 所属模块：tool_box 账号体系（与 scripts/sql/users.sql 配套）。
-- 关键依赖：PostgreSQL 15+、Supabase Auth（auth.users）。
--
-- 为什么要这个脚本：
--   users.sql 里 public.users.id 只是 uuid 主键，并未建到 auth.users 的外键。
--   于是在 Dashboard → Authentication → Users 里删掉一个用户后，
--   auth.users 那行没了，public.users 那行还留着 —— 孤儿行。
--   影响：① 数据脏（按邮箱排查会看到不存在的账号）；
--         ② 加外键时会因为存在孤儿行而直接失败，必须先清再加。
--
-- 使用方法（Supabase SQL Editor 整段粘贴执行，全段幂等）：
--   1. 先跑第 1 段「只读盘点」，确认孤儿行确实是你要删的；
--   2. 再跑第 2 段「删除」；
--   3. 最后跑第 3 段「加外键」（可选但强烈建议）。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 只读盘点：列出所有孤儿行（只查不动，先确认再删）
-- ----------------------------------------------------------------------------
-- 期望：刚清完老账号时这里应该恰好列出你删掉的那个/那些邮箱。
--       若返回 0 行，说明没有孤儿，第 2 段可跳过。
select u.id,
       u.email,
       u.display_name,
       u.created_at,
       u.app_open_count,
       u.tool_usage_count
from public.users u
where not exists (select 1 from auth.users au where au.id = u.id)
order by u.created_at desc;

-- 顺手核对总数，删完再跑一次应减少对应行数
select count(*) as public_users_total,
       count(*) filter (where not exists (select 1 from auth.users au where au.id = u.id))
         as orphan_count
from public.users u;

-- ----------------------------------------------------------------------------
-- 2. 删除孤儿行（确认无误后单独执行这一段）
-- ----------------------------------------------------------------------------
-- 只删「auth.users 里已不存在」的行，绝不会误删正常账号。
delete from public.users u
where not exists (select 1 from auth.users au where au.id = u.id);

-- 删完复跑第 1 段的 count 查询，orphan_count 应为 0。

-- ----------------------------------------------------------------------------
-- 3. 加固外键：让以后删 auth 用户时 public.users 自动级联删除
-- ----------------------------------------------------------------------------
-- 说明：
--   · 这是 Supabase 官方 profiles 模板的标准写法（references auth.users on delete cascade）。
--   · 必须先执行完第 2 段 —— 有孤儿行时建外键会报
--     "violates foreign key constraint"。
--   · 用 do 块判断约束是否已存在，重复执行安全。
do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint c
    where c.conname = 'users_id_fkey'
      and c.conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_id_fkey
      foreign key (id) references auth.users (id)
      on delete cascade;
  end if;
end $$;

-- ⚠️ 若上面报 `permission denied for table users`（auth schema 权限不足），
--    说明当前项目没给 references 权限。两种处理：
--    a) 换 Supabase Dashboard → SQL Editor 里以 postgres 身份再跑一次（多数情况可解）；
--    b) 仍不行就跳过外键，改为**定期手工清理**：需要时只跑第 1、2 段即可，
--       或建个定时清理函数（pg_cron 需先在 Dashboard → Extensions 里启用）。
--
-- 外键建立后验收：
--   在 Dashboard → Authentication → Users 删一个测试账号，
--   再跑 `select count(*) from public.users where id = '<刚删的uuid>';` → 应为 0。

-- ----------------------------------------------------------------------------
-- 4. 刷新 PostgREST schema cache（表结构变更后必做）
-- ----------------------------------------------------------------------------
notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- 验证清单
-- ----------------------------------------------------------------------------
-- 外键是否生效（应看到 users_id_fkey，且 confdeltype = 'c'）：
--   select conname, confdeltype
--   from pg_catalog.pg_constraint
--   where conrelid = 'public.users'::regclass and contype = 'f';
--
-- 外键引用的是不是 auth.users：
--   select conname,
--          pg_get_constraintdef(oid) as definition
--   from pg_catalog.pg_constraint
--   where conrelid = 'public.users'::regclass and contype = 'f';
