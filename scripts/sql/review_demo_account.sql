-- ============================================================================
-- 文件：scripts/sql/review_demo_account.sql
-- 用途：给**已存在**的演示账号补上「邮箱密码登录」能力（审核用）。
--
-- ⚠️⚠️ 2026-10-01 弃用：本文件第 2 段的手写 bcrypt 方案**实测失败**——
--     SQL 执行成功、哈希也写进去了，但 GoTrue 校验仍返回 invalid_credentials
--     （项目实际密码算法与手写 bcrypt 不匹配，疑似 argon2id）。
--     ✅ 正确做法：改用 `scripts/set_demo_password.py`（Admin API，由 GoTrue
--     按项目自身算法生成哈希，已实测登录成功）。本文件仅保留第 1 段诊断 SQL 供参考。
--
-- 背景（2026-10-01 实测）：
--   - z_chunhua@126.com 在 auth.users 里**已存在**（用 public.check_email_exists
--     这个 anon 可用的 RPC 验证过，返回 true）。
--   - 但用密码登录返回 400 invalid_credentials —— 因为这个账号是**通过 OAuth
--     （Apple / Google）创建的**，OAuth 建号不设密码，encrypted_password 为空。
--   - public.users 里那行是**业务资料表**（昵称 / 头像 / 会员），它本来就不该
--     有密码字段，且已通过 id = auth.users.id 与登录账号关联好，无需重建。
--   - 结论：不用新建账号，只需给现有 auth.users 行**设置密码 + 确保邮箱已确认**。
--
-- ❓ 常见疑问：「这个邮箱同时也是 Apple 登录用的，要不要换一个？」
--    —— **不用换，共用同一个邮箱是最优解**。2026-10-01 用 Admin API 查证：
--       user_id = d5a295f9-886f-4a96-9773-8dcc2181f909
--       app_metadata.provider = 'apple'，identities 里是 apple identity。
--     即：Apple 登录与邮箱密码登录**指向同一个 user_id**，因此
--       ① 审核员用邮箱登录进来，看到的就是同一份业务数据（额度 / 会员齐全）；
--       ② 原有 Apple 登录完全不受影响，两种方式并存；
--       ③ 无需新建 public.users 行，业务数据零改动。
--     前提是该 Apple ID 走的是「共享我的电子邮件」——本账号 email 是真实
--     126.com 而非 @privaterelay.appleid.com，所以确实满足；若换成
--     「隐藏我的电子邮件」的 Apple ID 登录，会生成**另一个** relay 邮箱账号。
--
-- 执行位置：Supabase Dashboard → SQL Editor（postgres 角色）
-- 关联知识：doc/database.md（public.users.id = auth.users.id、新建用户触发器）
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. 诊断：先把这个账号的现状看清楚（只读，放心跑）
-- ----------------------------------------------------------------------------
-- 关注三列：
--   has_password = false → 说明是 OAuth 建的没密码，必须执行第 2 段；
--   email_confirmed_at 为空 → 邮箱未确认，第 2 段会一并补上；
--   signup_provider     → 建号来源（apple / google / email），用于确认判断。
select
  id,
  email,
  email_confirmed_at,
  (encrypted_password is not null and encrypted_password <> '') as has_password,
  raw_app_meta_data ->> 'provider'                              as signup_provider,
  created_at
from auth.users
where lower(email) = 'z_chunhua@126.com';


-- ----------------------------------------------------------------------------
-- 2. 修复：设置密码 —— ❌❌ 本段已于 2026-10-01 永久禁用，切勿再执行！
-- ----------------------------------------------------------------------------
-- ⚠️ 血泪教训（2026-10-01）：下面这段 UPDATE **曾经被误执行过**，它把
--    Admin API 设好的正确哈希**覆盖成手搓 bcrypt**，导致
--    「明明设过密码、复验也 OK，过一会儿又 invalid_credentials」——
--    排查了整整一轮才发现根因是这段 SQL 又被跑了一次。
--    表现极具迷惑性：SQL 执行成功、has_password 显示 true、但登录就是不认。
--
--    ✅ 唯一正确做法：改用 Admin API（GoTrue 按项目自身算法生成哈希）
--       python3 scripts/set_demo_password.py z_chunhua@126.com 123456789
--
-- 以下语句已全部注释，仅作历史留档，请勿取消注释：
--
-- create extension if not exists pgcrypto;
--
-- update auth.users
-- set
--   encrypted_password   = crypt('P_PASSWORD', gen_salt('bf')),
--   email_confirmed_at   = coalesce(email_confirmed_at, now()),
--   updated_at           = now()
-- where lower(email) = 'z_chunhua@126.com';


-- ----------------------------------------------------------------------------
-- 3. 校验：确认密码已写入、邮箱已确认（has_password 应为 true）
-- ----------------------------------------------------------------------------
select
  email,
  email_confirmed_at,
  (encrypted_password is not null and encrypted_password <> '') as has_password,
  left(encrypted_password, 7) as hash_prefix   -- 期望以 $2a$ / $2b$ / $2y$ 开头
from auth.users
where lower(email) = 'z_chunhua@126.com';


-- ============================================================================
-- 附：为什么不推荐「重新注册一个账号」
--   ① 本项目 mailer_autoconfirm = false，走注册流程会得到一个**未确认**的账号，
--      登录照样失败，还得再补一次确认；
--   ② 126 邮箱基本收不到 Supabase 的确认邮件（免费项目 SMTP 有限制）；
--   ③ 新账号在 public.users 没有对应行，还得再跑 users.sql 第 8 段补齐。
--   直接给现有账号补密码是路径最短、副作用最小的做法。
--
-- 备选方案（更规范，但需要 service_role key）：Admin API 改密码
--   PUT https://nfoishlluynelazgwduc.supabase.co/auth/v1/admin/users/<user_id>
--   Headers: Authorization: Bearer <SERVICE_ROLE>  /  apikey: <SERVICE_ROLE>
--   Body:    {"password":"...","email_confirm":true}
--   —— 本项目本地没有 service_role（scripts/.env.local 尚未落地），故走上面的 SQL。
-- ============================================================================
