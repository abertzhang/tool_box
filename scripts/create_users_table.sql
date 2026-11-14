-- ============================================================================
-- tool_box · 业务用户表 public.users 建表 / 升级脚本
--
-- 执行位置：Supabase 控制台 → SQL Editor → New query → 整段粘贴 → Run
-- 幂等性  ：可重复执行（用了 if not exists / create or replace / drop ... if exists），
--           重复执行不会报错，也不会产生重复数据或重复策略。
--           已建过旧版表的库也能直接跑，缺的字段会自动补上（见第 2 段）。
--
-- 为什么要两张表：
--   auth.users   —— Supabase 系统表，存密码哈希、第三方身份等敏感信息，
--                   由 Supabase 托管，**不要直接改它**（2025-04-21 起平台已限制
--                   在 auth schema 里建/删对象）。
--   public.users —— 我们的业务表，存昵称、头像、会员等可公开字段，
--                   与 auth.users 通过 id 一对一关联。
--
-- 字段一览（public.users）：
--   id               uuid         主键，关联 auth.users(id)，用户删除时级联删除
--   email            text         邮箱（冗余一份，方便列表/查询，不用联表）
--   display_name     text         昵称
--   avatar_url       text         头像 URL。Google 登录自动取 Google 的 picture；
--                                 邮箱注册为空，App 端用本地默认头像兜底
--   is_member        boolean      是否会员，默认 false
--   member_expire_at timestamptz  会员到期时间，null = 不限制（如买断制）
--   payment_order_no text         支付订单号（渠道侧或我方生成的唯一单号），null = 从未发起支付
--   payment_amount   numeric(10,2) 支付金额。用 numeric 而不是 float/double：
--                                  浮点存金额会有二进制舍入误差（0.1+0.2≠0.3），
--                                  对账时必然出问题，钱一律用定点数
--   payment_paid_at  timestamptz  支付（成功）时间，null = 未支付成功
--   payment_success  boolean      支付是否成功。三态语义：
--                                   null  = 未发起 / 未知（默认）
--                                   true  = 成功
--                                   false = 失败 / 已关闭
--                                 特意不用 not null default false：
--                                 「没支付过」和「支付失败」是两回事，用 null 区分
--   payment_provider text         收款方 / 支付渠道，如 'stripe' / 'paypal' /
--                                 'wechat_pay' / 'alipay' / 'app_store' / 'google_play'
--                                 用 text 不加 check 约束：渠道会随业务增加，
--                                 加了 check 反而会让新渠道写入直接被拒
--   created_at       timestamptz  创建时间，默认 now()
--   updated_at       timestamptz  更新时间，由触发器自动维护，客户端不用传
--
-- 【安全设计】is_member / member_expire_at / payment_* 都是「钱相关」字段，
--   客户端只能读不能改。本脚本用三道防线保证
--   （详见第 3 段 GRANT、第 5 段 RLS、第 6 段触发器）：
--     ① 角色层：不给 anon 任何权限，authenticated 只能 select/insert/update
--     ② 行层  ：RLS 限制只能碰自己那一行（id = auth.uid()）
--     ③ 列层  ：触发器强制会员字段、支付字段不可被客户端改写（绕过者直接抛异常）
--
--   为什么支付字段要锁死：客户端一旦能自己写 payment_success = true，
--   就等于「免费开会员」——哪怕现在还没有「支付成功即开通会员」的自动逻辑，
--   这个口子也必须先堵上，否则将来接支付回调时极易漏掉。
--
-- ⚠️【2026-04-28 Supabase 破坏性变更 —— 本脚本第 3 段是必需的】
--   自 2026-05-30 起新建的项目，public schema 里的「新表不再自动暴露给 Data API」；
--   2026-10-30 起对所有存量项目生效。以前建表后 anon/authenticated/service_role
--   会自动拿到 select/insert/update/delete，现在必须显式 GRANT。
--   缺 GRANT 时 PostgREST 返回 42501 permission denied（在 RLS 之前就被拒），
--   表现为「注册时 _syncUserRow 写表失败」。
--   参考：https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically
--
-- 配套说明见：doc/tool_box_supabase_setup.md
--
-- 【复核依据】本脚本已按两个技能逐条核对：
--   ① supabase（Supabase 平台侧：Data API 暴露、RLS 陷阱、安全清单）
--   ② supabase-postgres-best-practices（Postgres 侧：8 类规则）
--   其中命中并已处理的两条：
--     · security-rls-performance：RLS 谓词里的列必须有索引
--       → 本表 RLS 只用 id（= 主键，自带唯一索引），无需额外索引，已在第 5 段注明。
--     · security-privileges：public schema 里的函数默认 EXECUTE 授给 PUBLIC，
--       等于自动变成一个 /rpc/<函数名> 的公开端点
--       → 原本的 public.is_privileged_caller() 已删除，判断逻辑内联进触发器，
--         见第 6 段。
--   明确不适用的规则：
--     · conn-*（连接池 / 预编译语句 / 空闲超时）——本工程走 PostgREST HTTP，
--       客户端不直连 Postgres，无需连接池配置。
--     · 分页 / N+1 / 批量插入——本表一人一行，App 侧单次读自己那行。
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) 建表（新库）
-- ----------------------------------------------------------------------------
create table if not exists public.users (
  -- 主键类型说明：通用规范建议用 bigint identity，但这里必须用 uuid——
  -- 它要一对一对齐 auth.users(id)（Supabase 的 auth.users 主键就是 uuid）。
  -- 引用别人的主键时类型必须一致，所以本条属于有意的例外。
  id               uuid primary key references auth.users(id) on delete cascade,
  email            text,                       -- text 而非 varchar(n)：PG 里两者性能一致，还免了长度限制
  display_name     text,
  avatar_url       text,
  is_member        boolean      not null default false,
  member_expire_at timestamptz,          -- null 表示不限制到期（买断制）
  -- ↓↓↓ 支付信息（最近一笔）。全部可空：新用户注册时还没有任何支付记录。
  --    只存「最近一笔」是刻意的取舍：本表一人一行，存不了多笔订单。
  --    真要做订单历史/退款/对账，请拆 public.orders 表（见文末【可选 D】）。
  payment_order_no text,
  payment_amount   numeric(10,2),       -- 定点数存金额，不用 float（会有舍入误差）
  payment_paid_at  timestamptz,
  payment_success  boolean,             -- null=未发起/未知，true=成功，false=失败
  payment_provider text,                -- 收款方/渠道：stripe / alipay / app_store ...
  created_at       timestamptz  not null default now(),   -- timestamptz 而非 timestamp，始终带时区
  updated_at       timestamptz  not null default now()
);


-- ----------------------------------------------------------------------------
-- 2) 增量加列（兼容「已经跑过旧版脚本」的库）
--    create table if not exists 对已存在的表不会补字段，所以这里显式补一次。
--    add column if not exists 对已存在的列是空操作，可安全重复执行。
--    注意：not null + default 的加列在 PG11+ 是元数据操作，不会重写整表，很快。
-- ----------------------------------------------------------------------------
alter table public.users add column if not exists avatar_url       text;
alter table public.users add column if not exists is_member        boolean not null default false;
alter table public.users add column if not exists member_expire_at timestamptz;
alter table public.users add column if not exists created_at       timestamptz not null default now();
alter table public.users add column if not exists updated_at       timestamptz not null default now();

-- 支付字段（本次新增）
alter table public.users add column if not exists payment_order_no text;
alter table public.users add column if not exists payment_amount   numeric(10,2);
alter table public.users add column if not exists payment_paid_at  timestamptz;
alter table public.users add column if not exists payment_success  boolean;
alter table public.users add column if not exists payment_provider text;

-- 2.1 订单号唯一索引（部分索引）
--     目的不是加速查询，而是**幂等**：支付渠道的回调可能重复投递
--     （网络重试、用户重复点击），有了这条唯一索引，重复写入同一订单号
--     会直接报错，而不是悄悄记两笔。
--     用 partial index（where ... is not null）是因为 Postgres 的唯一索引里
--     多个 null 互不冲突——新用户全是 null，不加这个条件第一行之后就插不进去了。
create unique index if not exists users_payment_order_no_uidx
  on public.users (payment_order_no)
  where payment_order_no is not null;

-- 跨渠道收款时注意：不同渠道的订单号理论上可能撞号。
-- 真出现这种情况，把上面这条换成复合唯一即可：
--   create unique index if not exists users_payment_order_no_uidx
--     on public.users (payment_provider, payment_order_no)
--     where payment_provider is not null and payment_order_no is not null;


-- ----------------------------------------------------------------------------
-- 3) 显式授权（★ 2026-05-30 起新表必须显式 GRANT，否则 Data API 看不到这张表）
--
--    授权与 RLS 是两个独立层：
--      GRANT —— 决定「某个角色能不能碰这张表」（在 RLS 之前生效）
--      RLS   —— 决定「能碰的情况下看得到哪些行」
--    两层都配好，表才既可用又安全。
--
--    权限分配原则：
--      anon          —— 不给。未登录状态没有任何理由访问用户表。
--      authenticated —— select / insert / update 三项。
--                       不给 delete：用户行随 auth.users 级联删除，
--                       客户端没有理由自己删业务档案（也可防误删）。
--      service_role  —— 全给。后端/支付回调要用它开通会员（具备 bypassrls，
--                       会绕过 RLS，这是预期的管理通道）。
-- ----------------------------------------------------------------------------
grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.users to service_role;

-- 保险起见把 anon 的残留权限收掉（若项目是旧版默认授权，这里会显式撤销）
revoke all on public.users from anon;


-- ----------------------------------------------------------------------------
-- 4) 开启行级安全（RLS）
--    不开的话，任何人拿到 anon key 都能读/改全表数据，等于裸奔。
-- ----------------------------------------------------------------------------
alter table public.users enable row level security;

-- 下面这句【暂时不启用】，想开就去掉注释再跑一次（可重复执行，无副作用）：
--
--   alter table public.users force row level security;
--
--   force 的作用：连「表的所有者」也一起受 RLS 约束（普通 enable 对所有者无效）。
--
--   为什么默认不开：
--     在 Supabase 里，表所有者和你在 SQL Editor 里的身份都是 postgres，
--     该角色带 BYPASSRLS 属性，所以开不开 force，效果完全一样——
--     也就是说开了没有额外收益，但万一某个环境的 postgres 没有 BYPASSRLS，
--     你手工执行的「开通会员」「存量用户补齐」就会静默变成影响 0 行。
--     收益≈0、出事成本很高，所以保持关闭，把选择权留给你。
--
--   什么时候该开：如果你另外建了一个「不带 bypassrls 的业务角色」来跑后端服务，
--   那就应该开 force，防止它绕开 RLS。


-- ----------------------------------------------------------------------------
-- 5) 访问策略
--    所有策略都先 drop 再 create，保证重复执行时用的是最新定义
--    （直接 create policy 在策略已存在时会报 already exists）。
--
--    写法要点：
--    · to authenticated —— 直接指定目标角色。不用 auth.role() = 'authenticated'
--      这种旧写法（已废弃，且开了匿名登录时会误放行）。
--    · (select auth.uid()) —— 把函数调用包一层子查询，Postgres 会把它提升为
--      InitPlan，每行不用重算一遍，是 Supabase 官方推荐的性能写法。
--    · update 必须同时有 using 和 with check：
--      只有 using 的话，用户能把自己的行改写成别人的 id（越权转移）。
--    · update 能生效的前提是存在 select 策略（Postgres 更新前要先选出该行），
--      下面 5.1 就是它，缺了会导致 update 静默影响 0 行且不报错。
--
--    · 索引核对（RLS 性能规则要求：策略谓词用到的列必须有索引）：
--      三条策略的谓词都只用到 id 这一列，而 id 是主键，
--      Postgres 会自动为它建唯一索引，所以这里【不需要额外建任何索引】。
--      将来若加了按 email 查询的策略，记得补 create index on public.users (email)。
-- ----------------------------------------------------------------------------

-- 5.1 读：只能读自己那一行
drop policy if exists "read own row" on public.users;
create policy "read own row" on public.users
  for select to authenticated
  using ( (select auth.uid()) = id );

-- 5.2 插：只能插自己那行
--     会员字段由第 6 段的 before insert 触发器强制归零，这里不重复判断，
--     免得策略里出现同表子查询（有触发无限递归检测的风险）。
drop policy if exists "insert own row" on public.users;
create policy "insert own row" on public.users
  for insert to authenticated
  with check ( (select auth.uid()) = id );

-- 5.3 改：只能改自己那行，且改完的 id 仍是自己
--     会员字段的不可变性交给第 6 段的 before update 触发器把关。
drop policy if exists "update own row" on public.users;
create policy "update own row" on public.users
  for update to authenticated
  using      ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );


-- ----------------------------------------------------------------------------
-- 6) 会员字段防篡改 + updated_at 自动维护（触发器层）
--
--    为什么用触发器而不是 RLS 策略里的同表子查询：
--      · 策略里写 `is_member = (select ... from public.users where id = auth.uid())`
--        需要子查询本表，Postgres 的 RLS 递归检测有可能把它判成无限递归；
--      · 触发器是行级、确定性的，读的是 old/new 伪记录，零歧义；
--      · 报错信息也能自定义，比冷冰冰的 "new row violates row-level security" 清楚。
--
--    ⚠️ 服务端（管理通道）的识别：直接在触发器里查 pg_roles.rolbypassrls。
--       service_role / postgres 这类角色带该属性，是合法的管理通道；
--       authenticated / anon 没有该属性，一律走严格校验。
--
--       为什么【不】把这个判断抽成 public 下的 helper 函数：
--         Postgres 默认把新建函数的 EXECUTE 授给 PUBLIC，而 PostgREST 会把
--         「暴露 schema 里、且当前角色有执行权的函数」一律挂成 RPC 端点
--         （POST /rest/v1/rpc/<函数名>，官方文档原文：every function in the
--          exposed schema and accessible by the active database role）。
--         也就是说 public 下的函数 ≈ 公开 API，还会被 API 自动发现扫进去。
--         它不是 security definer，严格说不算是漏洞，但白白多一个可匿名调用
--         的端点，没必要。
--         内联进触发器后：触发器函数 returns trigger，PostgREST 不暴露；
--         同时也绕开了「撤销 EXECUTE 会不会把触发器一起挡掉」这个说不清的问题。
-- ----------------------------------------------------------------------------

-- 6.1 插入时强制会员字段取默认值，杜绝「注册即会员」
create or replace function public.users_before_insert()
returns trigger
language plpgsql
as $$
declare
  -- 当前调用者是否属于服务端管理通道（具备 bypassrls 属性）
  v_privileged boolean;
begin
  select coalesce(r.rolbypassrls, false)
    into v_privileged
    from pg_catalog.pg_roles r
   where r.rolname = current_user;   -- 非 definer 函数里 current_user 就是真正的调用者

  -- 服务端调用（service_role / postgres）允许直接带会员状态写入
  if v_privileged then
    return new;
  end if;

  new.is_member        := false;
  new.member_expire_at := null;

  -- 支付字段同样强制清空：注册时不可能已经有支付记录，
  -- 顺手堵掉「注册即伪造已付款」这条路。
  new.payment_order_no := null;
  new.payment_amount   := null;
  new.payment_paid_at  := null;
  new.payment_success  := null;
  new.payment_provider := null;

  return new;
end;
$$;

drop trigger if exists users_before_insert on public.users;
create trigger users_before_insert
  before insert on public.users
  for each row execute function public.users_before_insert();

-- 6.2 更新时：① 自动维护 updated_at  ② 会员字段不许改
create or replace function public.users_before_update()
returns trigger
language plpgsql
as $$
declare
  v_privileged boolean;
begin
  -- ① 时间戳统一在这里维护：客户端 upsert 完全不用传 updated_at，也不会漏更新
  new.updated_at := now();

  select coalesce(r.rolbypassrls, false)
    into v_privileged
    from pg_catalog.pg_roles r
   where r.rolname = current_user;

  -- ② 服务端调用放行（开通/续费/取消会员走的就是这条路）
  if v_privileged then
    return new;
  end if;

  -- ③ 客户端调用：会员字段必须与旧值完全一致，否则拒绝整次更新。
  --    is distinct from 能正确处理 null（null 与 null 视为相同），
  --    这是 null-safe 比较，不能写成 = 或 !=。
  if new.is_member is distinct from old.is_member then
    raise exception 'is_member 不允许自行修改，需通过服务端或支付回调开通'
      using errcode = '42501';
  end if;

  if new.member_expire_at is distinct from old.member_expire_at then
    raise exception 'member_expire_at 不允许自行修改，需通过服务端或支付回调开通'
      using errcode = '42501';
  end if;

  -- ④ 支付字段（payment_*）同样不许客户端改，理由同会员字段：
  --    能自己写 payment_success = true 就等于能白嫖会员。
  --
  --    ⚠️ 但要注意一个容易踩的点：App 端 _syncUserRow 用的是 upsert，
  --    只带 id / email / display_name / avatar_url 四个字段。
  --    PostgREST 生成 UPDATE 时**只包含 payload 里的列**，
  --    其余列在触发器看到的 new 记录里保持原值，所以不会误触发这里的异常。
  --    反过来：如果客户端 payload 里**显式带了** payment_xxx（哪怕传 null），
  --    就会被判定为「想把支付信息清空」而直接拒绝。
  --    结论：客户端 upsert 时不要碰任何 payment_* 字段，一行都别带。
  if new.payment_order_no is distinct from old.payment_order_no
     or new.payment_amount   is distinct from old.payment_amount
     or new.payment_paid_at  is distinct from old.payment_paid_at
     or new.payment_success  is distinct from old.payment_success
     or new.payment_provider is distinct from old.payment_provider then
    raise exception '支付字段（payment_*）不允许自行修改，只能由服务端或支付回调写入'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists users_before_update on public.users;
create trigger users_before_update
  before update on public.users
  for each row execute function public.users_before_update();

-- 6.3 清理早期草稿可能残留的 helper 函数
--    本版本已把判断内联，不再需要 public.is_privileged_caller()；
--    它若还留在库里就会一直是个可匿名调用的 RPC 端点，所以这里顺手删掉。
--    函数不存在时是空操作，可安全重复执行。
drop function if exists public.is_privileged_caller();


-- ----------------------------------------------------------------------------
-- 7) 新用户注册自动补一行
--    覆盖邮箱注册与 Google 首次登录两条路径，客户端不用操心写表。
--
--    为什么必须 security definer：
--      触发器在 auth.users 插入时触发，此刻还没有任何用户会话，
--      auth.uid() 返回 null，第 5 段的 RLS 策略必然拒绝写入。
--      所以这里需要以函数所有者（postgres，具备 bypassrls）身份执行。
--      这是 auth 触发器的标准用法，不是为了绕开权限报错而加的。
--
--    加固两点（应对 security definer 的固有问题）：
--      · set search_path = '' —— 防止 search_path 被劫持导致同名对象被误调用；
--        设为 '' 后函数内所有对象必须写全限定名（下面 public.users 已写全），
--        pg_catalog 始终隐式可用，所以 coalesce / split_part / ->> 这些内置函数照常工作。
--      · 第 8 段会 revoke 掉 PUBLIC 的执行权限 —— Postgres 默认把函数的 EXECUTE
--        授给 PUBLIC，等于任何角色都能调用 public 下的 security definer 函数。
--
--    注意：display_name / avatar_url 取自 raw_user_meta_data，只是「填档案」用途，
--    不参与任何鉴权判断。user_metadata 用户自己可改，绝不能拿来判权限
--    （会员状态存在 public.users 里，不放 metadata、不进 JWT）。
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    -- 邮箱注册取表单里的 display_name；Google 登录取 Google 返回的 full_name
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    ),
    -- Google 的头像在 picture 字段；Supabase 有时也放在 avatar_url
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ----------------------------------------------------------------------------
-- 8) 收紧 security definer 函数的执行权限
--    Postgres 默认 EXECUTE 授给 PUBLIC，而 security definer 函数会以
--    所有者权限运行，所以 public schema 里的这类函数等于一个公开 API。
--    本函数 returns trigger（直接调用会报 "trigger functions can only be
--    called as triggers"），风险有限，但仍然显式收回，符合最小权限原则。
--
--    顺序很关键：先给真正需要的角色显式授权，再撤销 PUBLIC，
--    这样即使 Postgres 在触发器执行时校验 EXECUTE 权限也不会误伤。
-- ----------------------------------------------------------------------------
do $$
begin
  -- GoTrue（Supabase 的 Auth 服务）以 supabase_auth_admin 身份写 auth.users，
  -- 触发器就是在这个身份下被执行的。
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant execute on function public.handle_new_user() to supabase_auth_admin';
  end if;
  -- postgres 通常是函数所有者，显式授权是幂等的空操作，写上以防环境差异
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'postgres') then
    execute 'grant execute on function public.handle_new_user() to postgres';
  end if;
end $$;

revoke execute on function public.handle_new_user() from PUBLIC;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.handle_new_user() from authenticated;


-- ----------------------------------------------------------------------------
-- 9) 会员状态视图（推荐 App 端读这个，而不是直接读 users 表）
--
--    为什么需要：is_member 只表示「买过」，过期了它仍是 true。
--    视图额外算出 is_member_active = 在有效期内，App 判断权限时用它最省心。
--
--    security_invoker = true 是关键：
--      PG15 起视图默认以「视图所有者」权限运行，会**绕过基表的 RLS**
--      （等于全表可见）；加了这个选项，视图继承调用者身份，基表 RLS 正常生效。
--      Supabase 新建项目均为 PG15+，可放心使用。
--
--    视图同样需要显式 GRANT（2026 破坏性变更对视图一样适用）。
-- ----------------------------------------------------------------------------
drop view if exists public.user_profiles;
create view public.user_profiles
with (security_invoker = true)
as
select
  u.id,
  u.email,
  u.display_name,
  u.avatar_url,
  u.is_member,
  u.member_expire_at,
  -- 支付信息：RLS 保证每个人只看得到自己那一行，
  -- 所以把自己的订单信息放进视图是安全的。
  -- App 端目前还没用到这几列（只用了 is_member_active），
  -- 先摆在这里给「购买记录/会员详情」页备用；不需要的话删掉即可。
  u.payment_order_no,
  u.payment_amount,
  u.payment_paid_at,
  u.payment_success,
  u.payment_provider,
  u.created_at,
  u.updated_at,
  -- 会员有效 = 买过 且（未设到期 或 未过期）
  (u.is_member and (u.member_expire_at is null or u.member_expire_at > now()))
    as is_member_active
from public.users u;

grant select on public.user_profiles to authenticated;
grant select on public.user_profiles to service_role;
revoke all on public.user_profiles from anon;


-- ----------------------------------------------------------------------------
-- 10) 刷新 PostgREST 的 schema cache
--     Supabase 通常会自动重载，但新建表/视图后偶发「表已建好但 REST 还报
--     PGRST205 找不到」。NOTIFY 是幂等的空操作，放在这里兜底。
-- ----------------------------------------------------------------------------
notify pgrst, 'reload schema';


-- ============================================================================
-- 验证（建表后单独执行，确认结果符合预期）
-- ============================================================================

-- ① 表与字段（确认 is_member / member_expire_at / payment_* 已就位，应有 13 行）
-- select column_name, data_type, column_default, is_nullable
-- from information_schema.columns
-- where table_schema = 'public' and table_name = 'users'
-- order by ordinal_position;

-- ② 授权（★ 必须有 authenticated 的 SELECT/INSERT/UPDATE，否则 App 读写会 42501）
-- select grantee, string_agg(privilege_type, ',' order by privilege_type) as privileges
-- from information_schema.role_table_grants
-- where table_schema = 'public' and table_name = 'users'
-- group by grantee;

-- ③ 策略（应看到 read / insert / update own row 三条，roles = {authenticated}）
-- select policyname, cmd, roles from pg_policies where tablename = 'users';

-- ④ 触发器（应有 users_before_insert / users_before_update / on_auth_user_created）
-- select tgname, tgrelid::regclass as on_table
-- from pg_trigger where not tgisinternal
--   and tgname in ('users_before_insert','users_before_update','on_auth_user_created');

-- ⑤ 视图与它的授权
-- select grantee, privilege_type
-- from information_schema.role_table_grants
-- where table_schema = 'public' and table_name = 'user_profiles';

-- ⑥ 端到端冒烟：建表后注册一个账号，然后查（应看到该用户一行，is_member = false，
--    5 个 payment_* 全为 null）
-- select id, email, display_name, avatar_url, is_member, member_expire_at,
--        payment_order_no, payment_amount, payment_paid_at, payment_success, payment_provider
-- from public.users order by created_at desc limit 5;

-- ⑦ 公开 RPC 面自查（本脚本的关键安全目标之一：public 下不留多余的可调用函数）
--    期望结果：只剩 3 个 returns trigger 的函数（PostgREST 不暴露这类），
--    不应出现 is_privileged_caller 之类的标量函数。
-- select p.proname, pg_get_function_result(p.oid) as returns
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
-- order by p.proname;


-- ============================================================================
-- 【可选 A】存量用户补齐
--
-- 触发器只在 auth.users「新增行」时触发。如果你是先注册了账号、
-- 之后才来建表，那批老账号不会出现在 public.users 里。
-- （App 端同步失败只打日志不报错，很容易被忽略。）
--
-- 出现这种情况时，去掉下面的注释执行即可；重复执行无副作用。
-- 会员字段走默认值，不会被误开。
-- ============================================================================

-- insert into public.users (id, email, display_name, avatar_url, created_at)
-- select
--   id,
--   email,
--   coalesce(
--     raw_user_meta_data ->> 'display_name',
--     raw_user_meta_data ->> 'full_name',
--     raw_user_meta_data ->> 'name',
--     split_part(email, '@', 1)
--   ),
--   coalesce(
--     raw_user_meta_data ->> 'avatar_url',
--     raw_user_meta_data ->> 'picture'
--   ),
--   created_at
-- from auth.users
-- on conflict (id) do nothing;


-- ============================================================================
-- 【可选 B】开通 / 续费 / 取消会员
--
-- 在 SQL Editor 执行时你是 postgres 角色（具备 bypassrls），
-- 会命中第 6 段触发器里「当前角色带 bypassrls」的放行分支，可以正常改会员字段。
-- 若改由后端服务调用，请使用 service_role key（同样具备 bypassrls）。
-- 客户端用 anon key 改会被触发器直接抛异常。
-- ============================================================================

-- 开通包月会员（30 天，已有时长会往后顺延而不是重置）
-- update public.users
-- set is_member        = true,
--     member_expire_at = greatest(coalesce(member_expire_at, now()), now()) + interval '30 days'
-- where id = '<用户 uuid>';

-- 开通买断制会员（不限制到期）
-- update public.users
-- set is_member        = true,
--     member_expire_at = null
-- where id = '<用户 uuid>';

-- 取消会员
-- update public.users set is_member = false, member_expire_at = null where id = '<用户 uuid>';

-- 批量清理已过期会员（可配合 Supabase Cron 定期跑）
-- update public.users
-- set is_member = false, member_expire_at = null
-- where is_member = true and member_expire_at is not null and member_expire_at <= now();

-- 上面这条清理语句现在走全表扫描——本表一人一行，用户量小的时候完全无所谓。
-- 等用户量上万、Cron 跑起来变慢了，再补一条**部分索引**（只索引会员行，体积很小）：
--   create index if not exists users_member_expire_idx
--     on public.users (member_expire_at)
--     where is_member and member_expire_at is not null;
-- 现在就建的话属于过早优化：白占写入开销（每次 update 都要维护它），收益为零。


-- ============================================================================
-- 【可选 B2】登记一笔支付（支付回调 / 后端服务用）
--
-- 执行身份要求：postgres（SQL Editor）或 service_role（带 bypassrls），
-- 会命中第 6 段触发器的放行分支。客户端用 anon key 写会被直接抛异常——
-- 这正是我们要的：支付结果只能由「渠道回调 / 你的后端」说了算。
--
-- 注意本表只存「最近一笔」，同一用户再次支付会覆盖旧的单号。
-- 需要完整流水就拆 public.orders 表（见【可选 D】）。
-- ============================================================================

-- ① 只登记支付结果（不动会员状态）
-- update public.users
-- set payment_order_no = '<渠道订单号>',
--     payment_amount   = 68.00,                 -- numeric 字面量，别写成 float
--     payment_paid_at  = now(),
--     payment_success  = true,
--     payment_provider = 'alipay'               -- 收款方 / 渠道
-- where id = '<用户 uuid>';

-- ② 支付成功 + 同时开通 30 天会员（最常见的一条龙）
-- update public.users
-- set payment_order_no = '<渠道订单号>',
--     payment_amount   = 68.00,
--     payment_paid_at  = now(),
--     payment_success  = true,
--     payment_provider = 'alipay',
--     is_member        = true,
--     member_expire_at = greatest(coalesce(member_expire_at, now()), now()) + interval '30 days'
-- where id = '<用户 uuid>';

-- ③ 支付失败 / 订单关闭（保留单号方便排查，但不给会员）
-- update public.users
-- set payment_success = false,
--     payment_paid_at = null
-- where id = '<用户 uuid>' and payment_order_no = '<渠道订单号>';

-- ④ 重复回调怎么办：第 2.1 段的订单号唯一索引会挡住「同一订单号写到两个用户身上」。
--    真正的幂等要在业务侧做——先查再写：
-- select payment_order_no, payment_success
-- from public.users
-- where id = '<用户 uuid>' and payment_order_no = '<渠道订单号>';
--     查到且 payment_success = true → 直接返回成功，别再更新一次。


-- ============================================================================
-- 【可选 C】回滚 / 应急
-- ============================================================================

-- C.1 万一 revoke 之后注册时「public.users 没自动补行」（极端环境差异），
--     把执行权还回去即可：
--     grant execute on function public.handle_new_user() to PUBLIC;

-- C.2 彻底删除本脚本创建的所有对象（重来时用，注意会丢数据）：
--     drop trigger if exists on_auth_user_created on auth.users;
--     drop view if exists public.user_profiles;
--     drop trigger if exists users_before_update on public.users;
--     drop trigger if exists users_before_insert on public.users;
--     drop function if exists public.handle_new_user();
--     drop function if exists public.users_before_update();
--     drop function if exists public.users_before_insert();
--     drop function if exists public.is_privileged_caller();
--     drop table if exists public.users;

-- C.3 若你的项目是 2026-05-30 之前创建的老项目（新表仍会自动暴露），
--     第 3 段的 GRANT 是幂等的空操作，不会有任何副作用，可以放心保留。


-- ============================================================================
-- 【可选 D】后续扩展提示（现在不用做，先记在这里）
--
-- · 会员等级：加 member_level text not null default 'free'（如 free/pro/team），
--   记得同步把它加进第 6 段触发器的「不可自改」字段。
-- · 自传头像：建一个 Supabase Storage bucket（如 avatars），
--   上传后把公开 URL 写回 avatar_url。注意 Storage 的 upsert 需要
--   INSERT + SELECT + UPDATE 三项权限，只给 INSERT 会导致覆盖上传静默失败。
-- · 更严格的方案：若会员体系变复杂（订单、套餐、退款），
--   建议把会员拆到独立表 public.memberships（只给 select 策略，
--   写入一律走服务端），主表只留 is_member 作为冗余快查字段。
-- · 支付流水同理：本表 5 个 payment_* 只能存「最近一笔」，
--   一旦要做订单历史 / 退款 / 对账 / 多渠道并存，就拆 public.orders：
--     id bigint generated always as identity primary key,
--     user_id uuid not null references public.users(id) on delete cascade,
--     order_no text not null unique,
--     amount numeric(10,2) not null,
--     paid_at timestamptz, success boolean, provider text,
--     raw_payload jsonb                       -- 渠道回调原文，对账用
--   再配 index on (user_id)（RLS 谓词列必须有索引，这是一对多查询的硬要求），
--   RLS 用 using ((select auth.uid()) = user_id)，写入只给 service_role。
--   拆完之后本表的 payment_* 可以保留作「最近一笔」冗余，也可以删掉。
-- · 会话安全提示：删除用户不会让已签发的 access token 立即失效。
--   若将来做敏感操作，记得先 signOut 或校验 session_id。
-- ============================================================================
