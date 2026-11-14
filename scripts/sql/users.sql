-- ============================================================================
-- 文件职责：Supabase 业务用户表 public.users 建表脚本（幂等，可重复执行）。
-- 所属模块：tool_box 账号体系（注册 / 登录 / 个人中心 / 会员）。
-- 关键依赖：PostgreSQL 15+、Supabase Auth（auth.users）、PostgREST。
--
-- 重要：本脚本**不动** auth.users —— 那是 Supabase 系统表（存密码哈希与第三方
--       身份），由 GoTrue 服务托管，业务侧只读、不可改写。业务字段一律放
--       public.users，与 auth.users 一对一（同 id）关联。
--
-- 幂等规则（老库升级也必须能跑）：
--   ① 建表用 create table if not exists；
--   ② 加列用 add column if not exists（if not exists 不会给已存在的表补字段）；
--   ③ 策略 / 触发器先 drop if exists 再 create；
--   ④ 视图先 drop view if exists 再 create。
--
-- 使用方法：
--   1. Supabase SQL Editor 整段粘贴执行；
--   2. 执行后确认 PostgREST schema cache 已刷新（脚本末尾自动 notify）；
--   3. 存量账号补齐看第 8 段（触发器只对新建行生效）。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 表结构
-- ----------------------------------------------------------------------------
create table if not exists public.users (
  -- 主键：与 auth.users.id 同值，一对一关联；Supabase Auth 注册时生成
  id              uuid        primary key,
  -- 邮箱：注册来源邮箱，Google 登录也有
  email           text        null,
  -- 昵称：Google 登录取 raw_user_meta_data->>'name'，邮箱注册取邮箱前缀
  display_name    text        null,
  -- 头像 URL：Google 登录由 Supabase 写入，邮箱注册通常为空（UI 用默认头像兜底）
  avatar_url      text        null,
  -- 是否买过会员（只表示「买过」，过期仍是 true；有效态看 user_profiles.is_member_active）
  is_member       boolean     not null default false,
  -- 会员到期时间：null 表示不限期（买断制）
  member_expire_at timestamptz null,
  -- 打开 App 次数（会话数）：由 app_events 触发器累计（event_name='app_open'，
  -- 冷启动 + 后台 30s 回前台均算一次），客户端不可改
  app_open_count  integer     not null default 0,
  -- 工具使用次数：由 app_events 触发器累计（event_name='tool_entry_open' 且
  -- params->>'implemented' 不为 false，即排除「开发中」占位点击），客户端不可改
  tool_usage_count integer    not null default 0,
  -- 当前设备版本：最近一次产生统计事件时的 os + 版本原文（如 'ios 26.0' /
  -- 'android 14'），取自 app_events.device jsonb 的 os 与 os_version 拼接；
  -- 展示层可自行加「苹果/安卓」等本地化前缀，客户端不可改
  current_device_version text null,
  -- 权限 token：HS256 JWT，自包含 sub(uid)/email/display_name/role 等，
  -- 有效期 30 天（含 exp），由 ensure_user_token() 懒生成 / 过期自动重签、
  -- reset_user_token() 作废；游客 token 不落库（见第 5b 段）。
  -- 签名 secret 存 Supabase Vault（tool_box_user_token_secret），客户端不可改
  token           text        null,
  -- 注册时间（业务表层面的创建时间）
  created_at      timestamptz not null default now(),
  -- 更新时间：仅「业务字段（资料/会员）」变化时由触发器刷新；
  -- 埋点计数 / 设备版本等派生字段更新不刷新（避免 updated_at 被埋点污染）
  updated_at      timestamptz not null default now()
);

-- ② 老库补齐：已存在的表不会被上面补字段，逐列显式加（安全重复执行）
alter table public.users add column if not exists email            text;
alter table public.users add column if not exists display_name     text;
alter table public.users add column if not exists avatar_url       text;
alter table public.users add column if not exists is_member        boolean not null default false;
alter table public.users add column if not exists member_expire_at timestamptz;
alter table public.users add column if not exists app_open_count   integer not null default 0;
alter table public.users add column if not exists tool_usage_count integer not null default 0;
alter table public.users add column if not exists current_device_version text;
alter table public.users add column if not exists token              text;
alter table public.users add column if not exists created_at       timestamptz not null default now();
alter table public.users add column if not exists updated_at       timestamptz not null default now();

-- ----------------------------------------------------------------------------
-- 2. 显式 GRANT（2026-05-30 起必需，最容易漏）
-- ----------------------------------------------------------------------------
-- 2026-04-28 破坏性变更：public schema 的新表不再自动暴露给 Data API。
-- 缺 GRANT 时 PostgREST 在 RLS 之前就返回 42501 permission denied，
-- 极容易被误判成 RLS 配错。必须「GRANT + RLS + policy」三件套一起给。
grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.users to service_role;
revoke all on public.users from anon;   -- 未登录没必要碰用户表

-- ----------------------------------------------------------------------------
-- 3. 行级安全（RLS）
-- ----------------------------------------------------------------------------
alter table public.users enable row level security;

-- 读：只能读自己那行
drop policy if exists "read own row" on public.users;
create policy "read own row" on public.users
  for select to authenticated
  using ( (select auth.uid()) = id );   -- 包一层子查询：PG 提升为 InitPlan，性能更好

-- 写：using + with check 缺一不可——只有 using 时用户能把行改写成别人的 id（越权转移）
drop policy if exists "update own row" on public.users;
create policy "update own row" on public.users
  for update to authenticated
  using      ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

-- 插入：客户端注册后自行补行（注册页 _syncUserRow 走 upsert）
drop policy if exists "insert own row" on public.users;
create policy "insert own row" on public.users
  for insert to authenticated
  with check ( (select auth.uid()) = id );

-- ----------------------------------------------------------------------------
-- 4. 会员字段防客户端提权（钱相关 + 服务端统计字段，必须做）
-- ----------------------------------------------------------------------------
-- 背景：上面的 update policy 允许 authenticated 改自己那行的任意字段，
--       若不加控制，客户端就能把自己改成会员（白嫖），或把打开次数、
--       工具使用次数、当前设备改成任意值（破坏统计可信度）。
-- 方案：用触发器（不是策略里子查询本表——那会踩 RLS 递归检测报 infinite recursion）。

-- 服务端通道识别：service_role / postgres 具备 rolbypassrls，是合法管理通道
create or replace function public.is_privileged_caller()
returns boolean language sql stable as $$
  select coalesce((select r.rolbypassrls from pg_catalog.pg_roles r
                   where r.rolname = current_user), false);
$$;

-- insert 前：强制归零，杜绝「注册即会员 / 注册即高计数」
create or replace function public.users_before_insert()
returns trigger language plpgsql as $$
begin
  if public.is_privileged_caller() then return new; end if;
  new.is_member        := false;
  new.member_expire_at := null;
  new.app_open_count         := 0;
  new.tool_usage_count       := 0;
  new.current_device_version := null;
  -- token 只能由 ensure_user_token() 服务端签发，注册/插行时一律清空
  new.token            := null;
  return new;
end $$;

-- update 前：① 只有业务字段（资料/会员）变化才刷新 updated_at
--           —— 埋点联动更新只碰计数/设备列，不该把「最后修改资料时间」顶到最近一次埋点
--          ② 会员字段 / 服务端统计字段与旧值不一致就拒绝
create or replace function public.users_before_update()
returns trigger language plpgsql as $$
declare
  -- 业务字段是否真的变化（资料 / 会员 / 关联键）；
  -- 计数、设备列、token 都不算业务变更（token 由 RPC 签发，不该顶新 updated_at）
  _business_changed boolean;
begin
  _business_changed :=
      new.id               is distinct from old.id
   or new.email            is distinct from old.email
   or new.display_name     is distinct from old.display_name
   or new.avatar_url       is distinct from old.avatar_url
   or new.is_member        is distinct from old.is_member
   or new.member_expire_at is distinct from old.member_expire_at;
  -- 业务变了才动 updated_at；否则保持原值（触发器联动更新不会污染它）
  if _business_changed then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;

  if public.is_privileged_caller() then return new; end if;

  -- is distinct from 是 null-safe 比较，= / != 处理不了 null
  if new.is_member is distinct from old.is_member then
    raise exception 'is_member 不允许自行修改' using errcode = '42501';
  end if;
  if new.member_expire_at is distinct from old.member_expire_at then
    raise exception 'member_expire_at 不允许自行修改' using errcode = '42501';
  end if;
  if new.app_open_count is distinct from old.app_open_count then
    raise exception 'app_open_count 不允许自行修改' using errcode = '42501';
  end if;
  if new.tool_usage_count is distinct from old.tool_usage_count then
    raise exception 'tool_usage_count 不允许自行修改' using errcode = '42501';
  end if;
  if new.current_device_version is distinct from old.current_device_version then
    raise exception 'current_device_version 不允许自行修改' using errcode = '42501';
  end if;
  -- token 是权限凭据：客户端只能经 RPC 读取/生成，绝不能直接改写
  if new.token is distinct from old.token then
    raise exception 'token 不允许自行修改' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists users_before_insert on public.users;
create trigger users_before_insert before insert on public.users
  for each row execute function public.users_before_insert();

drop trigger if exists users_before_update on public.users;
create trigger users_before_update before update on public.users
  for each row execute function public.users_before_update();

-- ----------------------------------------------------------------------------
-- 5. 新用户自动补行（auth.users → public.users）
-- ----------------------------------------------------------------------------
-- security definer 不可省：新用户还没有 session，auth.uid() 为空，普通权限写不进去。
-- set search_path = '' 防同名对象劫持；函数内所有对象写全限定名。
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.users (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name',
             new.raw_user_meta_data->>'full_name',
             new.raw_user_meta_data->>'name',
             split_part(new.email, '@', 1)),        -- 兜底：邮箱前缀当昵称
    coalesce(new.raw_user_meta_data->>'avatar_url',
             new.raw_user_meta_data->>'picture')    -- Google 头像
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- security definer 必须配套加固：Postgres 默认把函数 EXECUTE 授给 PUBLIC，
-- 等于 public schema 里的 definer 函数是一个公开 API。
-- 顺序关键：先给真正需要的角色显式授权，再撤销 PUBLIC，避免把触发器执行者也挡掉。
do $$
begin
  -- GoTrue（Supabase Auth 服务）以 supabase_auth_admin 身份写 auth.users
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant execute on function public.handle_new_user() to supabase_auth_admin';
  end if;
  if exists (select 1 from pg_catalog.pg_roles where rolname = 'postgres') then
    execute 'grant execute on function public.handle_new_user() to postgres';
  end if;
end $$;

revoke execute on function public.handle_new_user() from PUBLIC;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.handle_new_user() from authenticated;

-- ----------------------------------------------------------------------------
-- 5b. 用户权限 token（HS256 JWT，30 天有效，懒生成；游客也发）
-- ----------------------------------------------------------------------------
-- 设计：
--   ① token = HS256 JWT，payload 自包含：
--      登录用户：sub(uid) / email / display_name / role='authenticated' / aud
--      游客（未登录）：sub(设备匿名 UUID) / is_anonymous / role='anonymous'
--      两种都带 iat + exp，【有效期 30 天】，到期必须重新签发。
--      payload 只是 base64 明文编码（防篡改、不加密），别放密码类敏感信息。
--   ② 签名 secret 存 Supabase Vault（2024-11-22 起 app.settings.jwt_secret 已
--      从数据库移除，任何 secret 都必须走 vault）。secret 在数据库端用
--      gen_random_bytes 随机生成，明文不经过客户端 / 日志。
--   ③ 懒生成（注册时不算）：登录后首次调 ensure_user_token() 生成，之后幂等
--      返回同一个；**已过期则自动重签**（不再无条件幂等）。为什么不放
--      handle_new_user 里自动生成？—— vault secret 若未配置会抛错，
--      不能让它炸掉注册链路。
--   ④ 客户端不可改：users_before_insert 强制置 null + before_update 抛 42501，
--      生成 / 作废只能走本段两个 RPC（security definer 以 postgres 身份写）。
--   ⑤ 一旦泄露需作废：调 reset_user_token() 清空，下次 ensure 重新生成。
--      有效期 30 天意味着泄露窗口最长 30 天，仍建议尽快 reset。
--   ⑥ 游客 token **不落库**：users 表没有匿名行，硬插会污染账号与统计体系
--      （bump_user_stats 按 user_id 更新，匿名 UUID 无对应行本就不计）。
--      所以游客 token 纯签名签发、客户端自己缓存到 exp。sub 是客户端设备
--      匿名 UUID，游客权限最低，伪造 sub 也只是「另一个游客」，无越权风险。
--   ⑦ App 侧拦截（关键）：token 到期后 ensure_user_token() 会自动重签，但
--      前提是 Supabase session 仍有效；若 session 也过期（RPC 返回 401 /
--      JWT expired），App 必须跳登录页重新登录，不能带过期 token 继续请求。
--      游客过期则直接重新调用即可（传 anonymous_id），无需登录。
--
-- 验证方怎么验这个 token（回答「Supabase 能验证吗」）：
--   · 所有验证方都必须检查 exp——30 天到期后 token 不再有效。
--     （游客 token 同理，只是重新签发不需要登录。）
--   · 任意自建后端 / 脚本：拿 vault 里的 secret 做 HS256 验签即可（任何 JWT 库）。
--     查 secret：select decrypted_secret from vault.decrypted_secrets
--                where name = 'tool_box_user_token_secret';
--   · 若想让 Supabase Data API（PostgREST）直接认它：把 vault 里的 secret
--     换成项目 legacy JWT secret（Dashboard → Settings → API Keys，需处于
--     启用状态），payload 已带 role/aud='authenticated'，PostgREST 验签通过
--     后 auth.uid() 即取 sub。默认独立随机 secret 时 Supabase 不认它——
--     这是有意的隔离：token 只服务 Supabase 之外的验证方。
--   · App 自己对 Supabase 的请求照常走登录 session（access_token + refresh），
--     本 token 与它互不影响。

-- ① 签名 secret：不存在才创建（幂等）。查看/轮换见上方注释
select vault.create_secret(
         encode(extensions.gen_random_bytes(32), 'hex'),   -- 数据库端生成 256 位随机 hex
         'tool_box_user_token_secret')
where not exists (
  select 1 from vault.decrypted_secrets where name = 'tool_box_user_token_secret');

-- ② base64url 小工具：JWT 规范要求 '+'→'-'、'/'→'_'、去 padding '='。
--    仅给 ensure_user_token 内部用，对外收回 EXECUTE。
create or replace function public.b64url(data bytea)
returns text language sql immutable as $$
  -- base64 → base64url 四步：先去 encode() 默认的 76 字符换行（chr(10)，
  -- 不去掉 token 里会混入 \n 导致任何 JWT 库解析失败），再 '+'→'-'、
  -- '/'→'_'、去 padding '='（JWT 规范要求 URL-safe 无 padding）
  select replace(replace(replace(replace(
           encode(data, 'base64'), chr(10), ''), '+', '-'), '/', '_'), '=', '');
$$;

-- ③ JWT payload 解析：取第二段 → base64url 补 padding → decode → jsonb。
--    只给 ensure_user_token 判过期用（不验签，签名由验证方在外部校验）；
--    对外收回 EXECUTE，避免被当成任意 token 解析入口。
create or replace function public.jwt_payload(p_token text)
returns jsonb language sql immutable as $$
  select nullif(convert_from(
           decode(
             replace(replace(split_part(p_token, '.', 2), '-', '+'), '_', '/')
             -- base64url 去掉的 padding '=' 要补回来，否则 decode 报错
             || repeat('=', (4 - length(split_part(p_token, '.', 2)) % 4) % 4),
             'base64'), 'utf8'), '')::jsonb;
$$;

-- ④ 获取（或首次生成 / 过期重签）当前身份的 token。
--    登录用户：落库 users.token，幂等且过期自动重签；
--    游客：传 p_anonymous_id（设备匿名 UUID），无状态签发，不落库。
create or replace function public.ensure_user_token(p_anonymous_id uuid default null)
returns text
language plpgsql
security definer                          -- 要写 users.token 行 + 读 vault，需提权
set search_path = ''                      -- 防同名对象劫持，函数体内全限定名
as $$
declare
  _uid   uuid := auth.uid();              -- 未登录为 null，走游客分支
  _token text;
  _email text;
  _name  text;
  _secret text;
  _header  text := '{"alg":"HS256","typ":"JWT"}';
  _payload text;
  _h64 text;
  _p64 text;
  _exp bigint;                            -- 库里 token 的 exp（Unix 秒）
  _now bigint := extract(epoch from now())::bigint;
  _ttl constant interval := interval '30 days';   -- 有效期：30 天，改这里即可
begin
  -- 身份二选一：登录用 auth.uid()；游客必须传设备匿名 UUID
  if _uid is null and p_anonymous_id is null then
    raise exception '未登录且未提供 p_anonymous_id，无法签发 token' using errcode = '42501';
  end if;

  -- 读签名 secret；缺配置时报出明确指引而不是静默失败
  select s.decrypted_secret into _secret
    from vault.decrypted_secrets s
   where s.name = 'tool_box_user_token_secret';
  if _secret is null then
    raise exception '缺少 vault secret tool_box_user_token_secret，请先执行 users.sql 第 5b 段';
  end if;

  -- ============ 分支 A：游客（未登录）============
  -- 纯签名、不落库：无 email / 无 display_name，role 标 anonymous 便于验证方降级授权
  if _uid is null then
    _payload := jsonb_build_object(
                  'sub',          p_anonymous_id,
                  'is_anonymous', true,
                  'role',         'anonymous',
                  'aud',          'visitor',
                  'iat',          _now,
                  'exp',          extract(epoch from now() + _ttl)::bigint
                )::text;
    _h64 := public.b64url(convert_to(_header,  'utf8'));
    _p64 := public.b64url(convert_to(_payload, 'utf8'));
    return _h64 || '.' || _p64 || '.'
        || public.b64url(extensions.hmac(_h64 || '.' || _p64, _secret, 'sha256'));
  end if;

  -- ============ 分支 B：登录用户 ============
  select u.token, u.email, u.display_name
    into _token, _email, _name
    from public.users u
   where u.id = _uid;
  if not found then
    raise exception '用户行不存在：%', _uid using errcode = '42501';
  end if;

  -- 幂等快路径：库里 token 仍在有效期内直接返回；过期（或无）则往下重签
  if _token is not null then
    _exp := nullif(public.jwt_payload(_token) ->> 'exp', '')::bigint;
    if _exp is not null and _exp > _now then
      return _token;
    end if;
  end if;

  _payload := jsonb_build_object(
                'sub',          _uid,
                'email',        _email,
                'display_name', _name,
                'role',         'authenticated',
                'aud',          'authenticated',
                'iat',          _now,
                'exp',          extract(epoch from now() + _ttl)::bigint
              )::text;
  _h64 := public.b64url(convert_to(_header,  'utf8'));
  _p64 := public.b64url(convert_to(_payload, 'utf8'));

  -- HMAC-SHA256 签名（pgcrypto 在 extensions schema）
  _token := _h64 || '.' || _p64 || '.'
         || public.b64url(extensions.hmac(_h64 || '.' || _p64, _secret, 'sha256'));

  -- 落库（definer 以 postgres 身份执行，before_update 触发器放行）
  update public.users
     set token = _token
   where id = _uid;

  return _token;
end $$;

-- 首版无参签名已废弃：参数化后不 drop 会留下同名函数，无参调用仍走旧逻辑
drop function if exists public.ensure_user_token();

-- ⑤ 作废当前 token：清空后下次 ensure_user_token() 会重新生成（新签名时间）。
--    只对登录用户有意义（游客 token 无状态、不落库，过期即失效）。
--    换 secret 也等于全体作废——验证方与签发方用同一个 secret。
create or replace function public.reset_user_token()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
begin
  if _uid is null then
    raise exception '未登录' using errcode = '42501';
  end if;
  update public.users set token = null where id = _uid;
end $$;

-- ⑤ token 唯一性（部分唯一索引：null 不参与，行数少体积可忽略）
create index if not exists users_token_uidx
  on public.users (token)
  where token is not null;

-- ⑦ 收权：先给需要调用的角色显式授权，再撤 PUBLIC / 无关角色。
--    注意：ensure_user_token(uuid) 必须给 anon —— 游客未登录时用的就是 anon key。
grant execute on function public.ensure_user_token(uuid) to authenticated;
grant execute on function public.ensure_user_token(uuid) to anon;
grant execute on function public.reset_user_token()      to authenticated;
revoke execute on function public.ensure_user_token(uuid) from PUBLIC;
revoke execute on function public.reset_user_token() from PUBLIC;
revoke execute on function public.reset_user_token() from anon;
-- 俩内部工具只对 definer 内部开放，一律不对外
revoke execute on function public.b64url(bytea) from PUBLIC;
revoke execute on function public.b64url(bytea) from anon;
revoke execute on function public.b64url(bytea) from authenticated;
revoke execute on function public.jwt_payload(text) from PUBLIC;
revoke execute on function public.jwt_payload(text) from anon;
revoke execute on function public.jwt_payload(text) from authenticated;

-- ----------------------------------------------------------------------------
-- 6. 会员状态视图（必须加 security_invoker）
-- ----------------------------------------------------------------------------
-- is_member 只表示「买过」，过期仍是 true。视图负责算出「当前是否有效」。
-- PG15 起视图默认以 owner 权限运行，会绕过基表 RLS（全表可见）；
-- security_invoker = true 让视图继承调用者身份，RLS 才生效。
drop view if exists public.user_profiles;
create view public.user_profiles with (security_invoker = true) as
select u.*,
       (u.is_member and (u.member_expire_at is null or u.member_expire_at > now())) as is_member_active
from public.users u;

-- 视图同样需要显式 GRANT（2026 破坏性变更对视图一样适用）
grant select on public.user_profiles to authenticated;
grant select on public.user_profiles to service_role;
revoke all on public.user_profiles from anon;

-- ----------------------------------------------------------------------------
-- 7. 索引核对
-- ----------------------------------------------------------------------------
-- RLS 策略只用 id（= 主键，Postgres 自动建唯一索引）→ 无需额外索引。
-- 反向提醒：别过度建索引。用户表一人一行，给 member_expire_at 建索引属于过早优化。
-- 等用户量上万、Cron 清理变慢了再补部分索引：
--   create index if not exists users_member_expire_idx
--     on public.users (member_expire_at)
--     where is_member and member_expire_at is not null;   -- 只索引会员行，体积很小

-- 若后续出现按 email 过滤的策略，必须补：
--   create index if not exists users_email_idx on public.users (email);

-- ----------------------------------------------------------------------------
-- 8. 存量账号补齐（触发器只对新增行生效）
-- ----------------------------------------------------------------------------
-- 「先注册后建表」的老账号不会自动进 public.users，执行一次补齐即可。
-- 会员字段走默认值，不会被误开通。
insert into public.users (id, email, display_name, avatar_url)
select au.id,
       au.email,
       coalesce(au.raw_user_meta_data->>'display_name',
                au.raw_user_meta_data->>'full_name',
                au.raw_user_meta_data->>'name',
                split_part(au.email, '@', 1)),
       coalesce(au.raw_user_meta_data->>'avatar_url',
                au.raw_user_meta_data->>'picture')
from auth.users au
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 9. 刷新 PostgREST schema cache（避免「表已建好但 REST 仍报 PGRST205」）
-- ----------------------------------------------------------------------------
notify pgrst, 'reload schema';   -- PostgREST 官方写法，幂等空操作

-- ----------------------------------------------------------------------------
-- 10. 验证
-- ----------------------------------------------------------------------------
-- 授权核对（期望：authenticated = INSERT,SELECT,UPDATE；service_role 全项；无 anon）：
--   select grantee, string_agg(privilege_type, ',' order by privilege_type)
--   from information_schema.role_table_grants
--   where table_schema = 'public' and table_name = 'users' group by grantee;
--
-- RLS 状态（relrowsecurity 应为 t）：
--   select relname, relrowsecurity from pg_class where relname = 'users';
--
-- 视图是否带 security_invoker：
--   select c.relname, c.reloptions from pg_class c where relname = 'user_profiles';
--
-- token 三个 RPC 就位 + secret 已建（应返回 1 行）：
--   select proname from pg_proc where pronamespace = 'public'::regnamespace
--     and proname in ('ensure_user_token','reset_user_token','b64url');
--   select name from vault.decrypted_secrets where name = 'tool_box_user_token_secret';
