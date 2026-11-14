-- ============================================================================
-- 文件：scripts/sql/truncate_public.sql
-- 项目：tool_box（Supabase ref: nfoishlluynelazgwduc）
-- 用途：清空 public schema 下【所有真实表】的数据，保留表结构 / 函数 /
--       视图 / 索引 / 触发器。结构完全不动，只删数据。
--
-- ⚠️ 破坏性操作 —— 执行前必读：
--   1. 本脚本【不可回滚】。正式环境执行前请先备份：
--        - 控制台 Database → Backups → 开 PITR（项目级），或
--        - 本地 `pg_dump "$DATABASE_URL" -n public --data-only > public_data.sql`
--   2. 本脚本【只清 public schema】，不碰 auth.users —— 现有账号仍能登录，
--      下次登录由 `handle_new_user` 触发器重建 public.users 行。
--   3. 视图（如 user_profiles）删不了数据，清空 users 后它自然变空，无需处理。
--   4. 建议在 Supabase 控制台 → SQL Editor 里按「第 0 步 → 第 1 步 → 第 2 步」
--      顺序执行，先确认清单再动手，避免误清。
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 第 0 步（可选但强烈建议）：确认当前有哪些表、各有多少行，做到心里有数。
--   先跑这条，看看即将被清的目标清单是否与预期一致。
-- ---------------------------------------------------------------------------
select
    t.tablename,
    (xpath('/row/c/text()',
        query_to_xml(format('select count(*) as c from %I.%I', 'public', t.tablename), false, true, '')))[1]::text::int as row_count
from pg_tables t
where t.schemaname = 'public'
order by t.tablename;

-- ---------------------------------------------------------------------------
-- 第 1 步：执行清空。
--   用 DO 块动态生成 TRUNCATE 语句，自动覆盖 public 下所有真实表
--   （含未来新增的表），不会漏、也不会误伤视图/FDW。
--   RESTART IDENTITY：把 serial/identity 计数器归零（本工程多为 uuid 主键，无害）。
--   CASCADE：连带截断被外键依赖的子表（整 schema 都清， cascade 安全）。
-- ---------------------------------------------------------------------------
do $$
declare
    r record;
    v_cleared text := '';
begin
    for r in
        select schemaname, tablename
        from pg_tables
        where schemaname = 'public'
        order by tablename
    loop
        execute format('truncate table %I.%I restart identity cascade;',
                       r.schemaname, r.tablename);
        v_cleared := v_cleared || r.tablename || ', ';
    end loop;

    if v_cleared = '' then
        raise notice 'public schema 下没有找到任何真实表，未做任何修改。';
    else
        raise notice '已清空（结构保留）：%', rtrim(v_cleared, ', ');
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- 第 2 步：复核。再跑一次第 0 步的查询，确认所有表 row_count 都为 0（或视图为空）。
--   如果某业务表本应有种子数据（本工程目前没有），清完后是空的属正常。
-- ---------------------------------------------------------------------------
