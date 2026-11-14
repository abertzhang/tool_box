-- ============================================================================
-- 文件：tool_box/scripts/verify_users_table.sql
-- 职责：create_users_table.sql 执行后的**只读体检**脚本
-- 用法：整段复制到 Supabase Dashboard → SQL Editor → 全选 → Run
-- 特性：
--   · 纯 select，不写任何数据，可无限次重复执行
--   · 只返回一个结果表（12 行），一眼看出哪几项没生效
--   · 每项输出 [检查项 / 结果 / 实际情况]，FAIL 项照着「实际情况」补跑即可
--
-- 为什么需要它：
--   SQL Editor 遇到报错会停在当前语句，后面的段落就不执行了。
--   只看到「表建好了」不代表 GRANT / RLS / 触发器 / 视图都在位，
--   而缺任何一项都会让 App 在运行时才炸（42501 / 写表失败 / 会员被自提权）。
-- ============================================================================

with chk as (
  -- --------------------------------------------------------------------------
  -- ① 表是否存在
  -- --------------------------------------------------------------------------
  select 1 as ord,
         '1  表 public.users' as item,
         case when exists (
                select 1 from information_schema.tables
                where table_schema = 'public' and table_name = 'users'
              ) then 'PASS' else 'FAIL' end as result,
         '不存在 → 补跑脚本第 1 段' as detail

  union all
  -- --------------------------------------------------------------------------
  -- ② 字段数（当前设计 13 列：8 个基础 + 5 个支付）
  --    列出实际列清单，方便肉眼核对拼写
  -- --------------------------------------------------------------------------
  select 2,
         '2  字段数（期望 13）',
         case when (select count(*) from information_schema.columns
                    where table_schema = 'public' and table_name = 'users') = 13
              then 'PASS' else 'FAIL' end,
         (select '实际 ' || count(*)::text || ' 列：' ||
                 string_agg(column_name, ',' order by ordinal_position)
          from information_schema.columns
          where table_schema = 'public' and table_name = 'users')

  union all
  -- --------------------------------------------------------------------------
  -- ③★ 角色授权（2026-04-28 破坏性变更的重灾区）
  --    期望：authenticated=SELECT,INSERT,UPDATE / service_role=全项 / 无 anon
  --    缺 authenticated → 注册时 upsert 直接 42501
  --    anon 还在 → 没跑第 3 段的 revoke（RLS 能兜住行数据，但仍应清掉）
  -- --------------------------------------------------------------------------
  select 3,
         '3  表授权 GRANT',
         -- 三个权限要分别 exists 判断：写成 like '%A%' || '%B%' 会被拼成一个
         -- 乱七八糟的模式串 '%A%%B%'，永远匹配不上（踩过的坑）
         case when exists (
                select 1 from information_schema.role_table_grants
                where table_schema='public' and table_name='users'
                  and grantee='authenticated' and privilege_type='INSERT')
              and exists (
                select 1 from information_schema.role_table_grants
                where table_schema='public' and table_name='users'
                  and grantee='authenticated' and privilege_type='SELECT')
              and exists (
                select 1 from information_schema.role_table_grants
                where table_schema='public' and table_name='users'
                  and grantee='authenticated' and privilege_type='UPDATE')
              and not exists (
                select 1 from information_schema.role_table_grants
                where table_schema = 'public' and table_name = 'users'
                  and grantee = 'anon'
              )
              then 'PASS' else 'FAIL' end,
         (select 'anon=' || coalesce(
                  (select string_agg(privilege_type, ',') from information_schema.role_table_grants
                   where table_schema='public' and table_name='users' and grantee='anon'), '无（正确）')
              || ' | authenticated=' || coalesce(
                  (select string_agg(privilege_type, ',' order by privilege_type) from information_schema.role_table_grants
                   where table_schema='public' and table_name='users' and grantee='authenticated'), '缺（危险）')
              || ' | service_role=' || coalesce(
                  (select string_agg(privilege_type, ',' order by privilege_type) from information_schema.role_table_grants
                   where table_schema='public' and table_name='users' and grantee='service_role'), '缺'))

  union all
  -- --------------------------------------------------------------------------
  -- ④ RLS 是否启用（关着 = 任何人能读全表，最严重的一项）
  -- --------------------------------------------------------------------------
  select 4,
         '4  RLS 已启用',
         case when (select relrowsecurity from pg_class
                    where oid = 'public.users'::regclass)
              then 'PASS' else 'FAIL' end,
         case when (select relrowsecurity from pg_class where oid = 'public.users'::regclass)
              then 'on'
              else 'off → 补跑脚本第 4 段 alter table ... enable row level security' end

  union all
  -- --------------------------------------------------------------------------
  -- ⑤ 策略条数（期望 3 条：select / insert / update，全部 to authenticated）
  -- --------------------------------------------------------------------------
  select 5,
         '5  RLS 策略（期望 3）',
         case when (select count(*) from pg_policies
                    where schemaname = 'public' and tablename = 'users') = 3
              then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(policyname || '(' || cmd || ')', ', '), '无')
          from pg_policies where schemaname = 'public' and tablename = 'users')

  union all
  -- --------------------------------------------------------------------------
  -- ⑥ 触发器（期望 3 个）
  --    users_before_insert  会员/支付字段强制归零
  --    users_before_update  维护 updated_at + 拦截会员/支付字段被改
  --    on_auth_user_created 注册时自动往 public.users 插一行
  -- --------------------------------------------------------------------------
  select 6,
         '6  触发器（期望 3）',
         case when (select count(*) from pg_trigger
                    where not tgisinternal
                      and tgname in ('users_before_insert','users_before_update','on_auth_user_created')) = 3
              then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(tgname, ', '), '无')
          from pg_trigger
          where not tgisinternal
            and tgname in ('users_before_insert','users_before_update','on_auth_user_created'))

  union all
  -- --------------------------------------------------------------------------
  -- ⑦ 视图 user_profiles（App 读会员状态用，它已算好 is_member_active）
  -- --------------------------------------------------------------------------
  select 7,
         '7  视图 user_profiles',
         case when exists (
                select 1 from pg_class c
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relname = 'user_profiles'
                  and c.relkind = 'v'
              ) then 'PASS' else 'FAIL' end,
         '不存在 → 补跑脚本第 9 段；不建也能跑，只是 App 要自己判断会员是否过期'

  union all
  -- --------------------------------------------------------------------------
  -- ⑧ 视图的 security_invoker（PG15+ 关键）
  --    默认视图以「创建者」权限跑，会绕过 RLS；必须为 true
  -- --------------------------------------------------------------------------
  select 8,
         '8  视图 security_invoker',
         case when coalesce(
                (select array_to_string(c.reloptions, ',')
                 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'public' and c.relname = 'user_profiles'), ''
              ) like '%security_invoker=true%'
              then 'PASS' else 'FAIL' end,
         coalesce((select array_to_string(c.reloptions, ',')
                   from pg_class c join pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relname = 'user_profiles'),
                  'null → 视图绕过 RLS，必须重建')

  union all
  -- --------------------------------------------------------------------------
  -- ⑨ 视图授权（期望 authenticated/service_role 有 SELECT，无 anon）
  -- --------------------------------------------------------------------------
  select 9,
         '9  视图授权',
         case when exists (
                select 1 from information_schema.role_table_grants
                where table_schema = 'public' and table_name = 'user_profiles'
                  and grantee = 'authenticated' and privilege_type = 'SELECT'
              ) then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(grantee || ':' || privilege_type, ', '), '无')
          from information_schema.role_table_grants
          where table_schema = 'public' and table_name = 'user_profiles')

  union all
  -- --------------------------------------------------------------------------
  -- ⑩★ 公开 RPC 面自查（本表最关键的安全目标）
  --    public schema 下的函数 = PostgREST 的 /rest/v1/rpc/<函数名> 公开端点
  --    期望：只有 3 个 returns trigger 的函数（PostgREST 不暴露触发器函数）
  --    若出现 is_privileged_caller 之类标量函数 → 立即 drop
  -- --------------------------------------------------------------------------
  select 10,
         '10 public 函数（RPC 面）',
         case when not exists (
                select 1 from pg_proc p
                join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public'
                  and pg_get_function_result(p.oid) not like '%trigger%'
              ) then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(p.proname || ' → ' || pg_get_function_result(p.oid), ' ; '), '无')
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public')

  union all
  -- --------------------------------------------------------------------------
  -- ⑪ 订单号部分唯一索引（防止同一订单号落到两个用户身上）
  -- --------------------------------------------------------------------------
  select 11,
         '11 订单号唯一索引',
         case when exists (
                select 1 from pg_indexes
                where schemaname = 'public' and indexname = 'users_payment_order_no_uidx'
              ) then 'PASS' else 'FAIL' end,
         'users_payment_order_no_uidx（payment_order_no 非空时才生效）'

  union all
  -- --------------------------------------------------------------------------
  -- ⑫ 行数（顺带看有没有同步到用户；0 行是正常的，注册后才会出现）
  -- --------------------------------------------------------------------------
  select 12,
         '12 当前行数',
         'INFO',
         (select 'public.users = ' || (select count(*)::text from public.users)
                 || ' 行 | auth.users = '
                 || coalesce((select count(*)::text from auth.users), '无权限读'))
  union all
  -- --------------------------------------------------------------------------
  -- ⑬★ authenticated 的越权项（Supabase 默认权限带来的残留）
  --    新建表会被自动授予 7 项权限，本表只需要 SELECT/INSERT/UPDATE。
  --    DELETE / TRUNCATE / REFERENCES / TRIGGER 出现了 → 补跑
  --    scripts/harden_users_grants.sql 第 1 段。
  --    ★ TRUNCATE 不受 RLS 约束，是四项里唯一值得在意的（REST 层打不出，
  --      但属于「顺手关门」级别的最小权限问题）。
  -- --------------------------------------------------------------------------
  select 13,
         '13 authenticated 越权项',
         case when not exists (
                select 1 from information_schema.role_table_grants
                where table_schema = 'public' and table_name = 'users'
                  and grantee = 'authenticated'
                  and privilege_type in ('DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER')
              ) then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(privilege_type, ',' order by privilege_type), '无')
          from information_schema.role_table_grants
          where table_schema = 'public' and table_name = 'users'
            and grantee = 'authenticated')

  union all
  -- --------------------------------------------------------------------------
  -- ⑭ 触发器函数的公开 EXECUTE（PUBLIC 默认有 → 等于多一个 /rest/v1/rpc 端点）
  --    期望：anon / authenticated 都没有 EXECUTE
  --    有 → 补跑 scripts/harden_users_grants.sql 第 2 段
  -- --------------------------------------------------------------------------
  select 14,
         '14 触发器函数 RPC 面',
         case when not exists (
                select 1 from pg_proc p
                join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public'
                  and pg_get_function_result(p.oid) like '%trigger%'
                  and (has_function_privilege('anon', p.oid, 'EXECUTE')
                       or has_function_privilege('authenticated', p.oid, 'EXECUTE'))
              ) then 'PASS' else 'FAIL' end,
         (select coalesce(string_agg(
                   p.proname || '(anon=' || has_function_privilege('anon', p.oid, 'EXECUTE')::text
                            || ',auth=' || has_function_privilege('authenticated', p.oid, 'EXECUTE')::text
                            || ')', ' ; '), '无（无触发器函数）')
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public'
            and pg_get_function_result(p.oid) like '%trigger%')
)
select item, result, detail
from chk
order by ord;

-- ============================================================================
-- 补跑指引
-- ----------------------------------------------------------------------------
-- 全部 PASS → 直接进 App 注册冒烟（见 doc/tool_box_supabase_setup.md §5）
-- 有 FAIL  → create_users_table.sql 全段幂等，把 FAIL 对应的段落单独选中执行即可，
--            不必重跑全文。顺序建议：3 → 4 → 5 → 6 → 9（后面的依赖前面的）。
-- 一直报错 → 把 SQL Editor 的红色报错原文贴出来，多半是某句 PG 版本不支持。
-- ============================================================================
