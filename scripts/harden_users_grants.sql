-- ============================================================================
-- 文件：tool_box/scripts/harden_users_grants.sql
-- 职责：create_users_table.sql 跑完、verify_users_table.sql 全 PASS 之后的
--       **权限收紧补丁**（最小权限原则收尾）
--
-- 用法：整段复制到 Supabase Dashboard → SQL Editor → 全选 → Run
-- 特性：全段幂等，重复执行无副作用；可单独执行，不依赖其他脚本
--
-- 为什么要单独一个文件：
--   verify 脚本 12 项全 PASS ≠ 权限已经最小化。
--   Supabase 项目在 public schema 上预设了 ALTER DEFAULT PRIVILEGES，
--   新建的表会自动带上 INSERT/SELECT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER
--   **全七项**授权给 anon / authenticated / service_role。
--   create_users_table.sql 里我们只做了「加法」（grant select,insert,update）
--   和「减法」（revoke all from anon），所以 authenticated 身上残留了
--   DELETE / TRUNCATE / REFERENCES / TRIGGER 四项本不该有的权限。
--
-- 危害评估（说实话，别吓唬人）：
--   · DELETE    —— RLS 没有 delete 策略，REST 层删不掉，风险 ≈ 0
--   · TRUNCATE  —— ★ 唯一值得在意的：TRUNCATE **不受 RLS 约束**，
--                  有权限就能清空整表。所幸 PostgREST 不暴露 TRUNCATE 操作，
--                  走 REST API 打不出来；但万一以后接了别的网关/直连就是洞。
--   · REFERENCES / TRIGGER —— 影响面很小，属于噪声权限
--   结论：不是火警，是「顺手把门带上」。
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) 收回 authenticated 的越权项（保留 select / insert / update）
--    注意：revoke 是「减法」，不会动到我们显式 grant 过的那三项。
--    anon 在第 3 段已经 revoke all，这里再补一遍是幂等空操作，写着防环境差异。
-- ----------------------------------------------------------------------------
revoke delete, truncate, references, trigger on public.users from authenticated;
revoke all on public.users from anon;


-- ----------------------------------------------------------------------------
-- 2) 收回两个 before 触发器函数的公开执行权
--
--    Postgres 默认把函数的 EXECUTE 授给 PUBLIC → 等于 /rest/v1/rpc/<函数名>
--    多一个公开端点。这两个函数 returns trigger，
--    PostgREST 直接调用会报「trigger functions can only be called as triggers」，
--    打不出数据，但端点存在本身就该关掉（最小权限 + 少一个攻击面）。
--
--    安全性说明（重要）：
--      Postgres 对触发器函数的 EXECUTE 权限只在 **CREATE TRIGGER 时** 校验，
--      运行期不再校验。所以这里 revoke 不会影响已建好的触发器正常工作。
--    （handle_new_user 在 create_users_table.sql 第 8 段已经收过了，
--      这里再收一遍幂等；真要回滚见文末。）
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'users_before_insert') then
    execute 'revoke execute on function public.users_before_insert() from PUBLIC';
    execute 'revoke execute on function public.users_before_insert() from anon';
    execute 'revoke execute on function public.users_before_insert() from authenticated';
  end if;

  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'users_before_update') then
    execute 'revoke execute on function public.users_before_update() from PUBLIC';
    execute 'revoke execute on function public.users_before_update() from anon';
    execute 'revoke execute on function public.users_before_update() from authenticated';
  end if;
end $$;


-- ----------------------------------------------------------------------------
-- 3) 复核：跑完直接看结果表，两项都应是 PASS
-- ----------------------------------------------------------------------------
select
  '13 authenticated 越权项' as item,
  case when not exists (
         select 1 from information_schema.role_table_grants
         where table_schema = 'public' and table_name = 'users'
           and grantee = 'authenticated'
           and privilege_type in ('DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER')
       ) then 'PASS' else 'FAIL' end as result,
  (select coalesce(string_agg(privilege_type, ',' order by privilege_type), '无')
   from information_schema.role_table_grants
   where table_schema = 'public' and table_name = 'users'
     and grantee = 'authenticated') as detail

union all
select
  '14 触发器函数 RPC 面',
  case when not exists (
         select 1
         from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public'
           and p.prokind = 'f'
           and pg_get_function_result(p.oid) like '%trigger%'
           and has_function_privilege('anon', p.oid, 'EXECUTE')
       ) and not exists (
         select 1
         from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public'
           and p.prokind = 'f'
           and pg_get_function_result(p.oid) like '%trigger%'
           and has_function_privilege('authenticated', p.oid, 'EXECUTE')
       ) then 'PASS' else 'FAIL' end,
  (select coalesce(string_agg(p.proname, ' ; '), '无（无触发器函数）')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and pg_get_function_result(p.oid) like '%trigger%');


-- ----------------------------------------------------------------------------
-- 4) 刷新 PostgREST schema cache（权限变更后建议刷一次，避免旧缓存）
-- ----------------------------------------------------------------------------
notify pgrst, 'reload schema';


-- ============================================================================
-- 回滚预案（平时用不到，出事时再跑）
-- ----------------------------------------------------------------------------
-- 万一收紧之后出现「注册写表失败 / 触发器不生效」（按上面的原理分析不会发生，
-- 但不同 PG 版本/托管环境可能有差异），执行下面任一/全部即可恢复：
--
--   grant delete, truncate, references, trigger on public.users to authenticated;
--   grant execute on function public.users_before_insert() to PUBLIC;
--   grant execute on function public.users_before_update() to PUBLIC;
--
-- 判断依据：注册后跑
--   select id, email, is_member from public.users order by created_at desc limit 5;
-- 有新行 = 一切正常；没新行 = 回滚上面三句再试。
-- ============================================================================
