# ⭐ 当前待办总览（2026-09-10 更新）

> 方案 B（购买即注册 + OAuth-only 登录）代码侧已全部完成并通过 `dart analyze lib`，
> Edge Function `bind-member` 已部署上线。下面按优先级列出**真正还剩下的事**，
> 下文其余章节多为历史留档（部分已随邮箱链路下线而废弃，已逐个标注）。

| # | 事项 | 状态 | 归属 |
|---|---|---|---|
| 1 | 补齐 Google 两个 Client ID（`kGoogleIosClientId` / `kGoogleWebClientId`） | 🔴 **未完成 · 唯一硬阻塞** | 下方「原生 Google 登录接入待办」 |
| 2 | 真机沙盒验收购买→注册→绑定全链路 | 🟡 未完成 | 见 `doc/purchase_handoff.md` §9.10 |
| 3 | 部署 `bind-member` Edge Function | ✅ 已完成（2026-09-10） | `doc/purchase_handoff.md` §9.12 |
| 4 | 代码改动提交 git | ⏸ 用户暂不需要 | 提交须限定 `tool_box/` 路径 |

**关键说明**

- **邮箱密码链路已从 App 端整体移除**（2026-09-10）：注册 / 忘记密码 / 重置密码 / 邮箱验证
  四个页面与路由已删除，`passwordRecoveryPending` 与 `reset-callback` 深链分支一并清理。
  登录页按平台**只显示一个**按钮（iOS/macOS → Apple，Android → Google），登录 = 注册合一。
  Supabase 控制台 **Email provider 保持开启**（老邮箱账号仍可登录），只是 App 端不再给入口。
- 因此本文件里 **SMTP / check_email_exists / 密码重置深链 / 6 位验证码** 等章节均为
  **历史留档**，描述的是「当初为什么这么设计」，实现已不在代码中，无需照做。
- **anon key 在 `local/env/prd.json`**（不是 `local/env/dev.json`；后者只有
  `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ACCESS_TOKEN` / `GMAIL_APP_PASSWORD`）。
  需要打 Auth API 时从前者现取，别去后者找。

---

# 原生 Google 登录（google_sign_in）接入待办

> 背景：登录页已收敛为按平台二选一（iOS/macOS → Apple，Android → Google），Google 走
> `google_sign_in` 原生插件（`lib/feature/login/google_sign_in_native.dart`）。
> Supabase 控制台 Authentication → Providers 的 Google **已启用** ✅。
>
> ⚠️ **这是目前唯一的硬阻塞**：两个 Client ID 未配齐 → Google 原生登录拿不到 accessToken，
> 「购买成功后同步会员」与「Google 登录」两条主路径都走不通。
> 以下为待完成项，每项一个一级标题。

# kGoogleIosClientId 未完成

- 在 **Google Cloud Console → APIs & Services → Credentials** 创建 **iOS 类型** OAuth 客户端 ID，
  Bundle ID 填 `uk.aknot.toolbox`。
- 把该 ID（形如 `xxxx.apps.googleusercontent.com`）填入
  `lib/feature/login/oauth_config.dart` 的 `kGoogleIosClientId`。
- 同步 `ios/Runner/Info.plist` 的「反转 client id」URL scheme：
  在 `CFBundleURLTypes` 的 Google 条目下，把占位
  `com.googleusercontent.apps.000000000000-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
  替换为 `com.googleusercontent.apps.` + 把真实 iOS 客户端 ID 里的 `.` 全部换成 `_`。

# kGoogleWebClientId 未完成

- 在 Google Cloud Console 创建 **Web 类型** OAuth 客户端 ID（**必须是 Web 类型，不是 Android 类型**）。
- 把该 ID 填入 `lib/feature/login/oauth_config.dart` 的 `kGoogleWebClientId`
  （作为 `serverClientId` 用于换取可被 Supabase 校验的 accessToken）。
- 同步 `android/app/src/main/res/values/strings.xml` 的 `default_web_client_id`
  （Android 端 `google_sign_in` 读取 `R.string.default_web_client_id` 取 serverClientId），
  占位值 `000000000000-xxxx…apps.googleusercontent.com` 换成同一个 Web 客户端 ID。

# Google Cloud Android 客户端绑定包名与 SHA-1 未完成

- 在 Google Cloud Console 找到（或新建）**Android 类型** OAuth 客户端，
  绑定包名 `uk.aknot.toolbox`，并上传签名证书 **SHA-1**（debug / release 各一份）。
- 未绑定或 SHA-1 不匹配会导致真机 Google 登录被 Google 直接拒绝。

# dart analyze + pod install 收尾 未完成

- 两个 client ID 填好后，运行校验：
  - `export FLUTTER_ROOT=/Users/zhangchunhua/sdk/flutter/master && $FLUTTER_ROOT/bin/dart analyze`
  - `cd ios && export LANG=en_US.UTF-8 && /usr/local/bin/pod install && rm -rf build/`
- Xcode 用 `Runner.xcworkspace` 打开 → Product → Clean Build Folder → 重新 Build。
- 完成后在真机（Android + iOS）各验证一次 Google 登录能拿到 session。

# 备注

- 所有改动（含此前登录页改造、占位配置文件）**均未提交**，确认无误后按批量粒度 commit；
  提交必须限定 `tool_box/` 路径（共用父仓库 `.../knot/.git`，切勿在仓库根 `git add -A`）。
- `android/app/google-services.json` 与 `ios/Runner/GoogleService-Info.plist` 已生成占位结构，
  本工程在 Dart 侧直接传 clientId，故二者非运行期必需，仅作结构参考。

---

# 🗄 自定义 SMTP（Gmail）接入待办【历史留档】

> ⛔ **2026-09-10：本整节已随邮箱密码链路下线，属历史留档，无需照做。**
> App 端已无邮箱注册 / 找回密码入口，SMTP 处于「配着但用不上」的休眠状态；
> 之所以不拆，是因为控制台 Email provider 按决策**保持开启**（老邮箱账号仍可登录）。
>
> 状态：**配置已上线**（2026-09-07）。发送账号 `zhang13655179933@gmail.com`，项目 ref
> `nfoishlluynelazgwduc`，云端回读确认 `smtp.gmail.com:587` + `external_email_enabled=true`。

# 🗄 用非团队成员邮箱实测收发【历史留档 · 邮箱注册入口已下线】

- 找一个**不在 Supabase 组织团队里**的邮箱（自带 SMTP 时代只发得给团队成员，测不出真实链路）。
- 不想开 App 的话，直接在终端打 Auth API（anon key 从本地配置里现取，不用手抄）：

  ```bash
  cd /Users/zhangchunhua/project_knot/repo/knot/tool_box
  URL=$(grep -o '"SUPABASE_URL":"[^"]*"' local/env/prd.json | sed 's/.*:"//;s/"//')
  ANON=$(grep -o '"SUPABASE_ANON_KEY":"[^"]*"' local/env/prd.json | sed 's/.*:"//;s/"//')
  curl -sS -w '\nHTTP=%{http_code}\n' -X POST "$URL/auth/v1/signup" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d '{"email":"换成你的测试邮箱","password":"Test@123456"}'
  ```

- 判定：返回 **200** 且带回 user 对象即触发成功（`email_confirmed_at` 为 null 是正常的，说明在等你确认）。
  此前若仍用自带 SMTP 会报 `Email address not authorized`，现在不该再出现。
- ✅ **邮件正文应是 6 位数字验证码**，不是「Confirm email address」链接。
  若仍是链接 → 说明 `mailer_templates_confirmation_content` 没改成功，见下方备注里的 API 改法。
- ⚠️ 同一邮箱 **60 秒**内只允许发一次，连点会 429，别误判成故障。
- 收不到就查两处：Supabase Dashboard → Logs → Auth Logs；以及 Gmail 的「已发送」文件夹（收件箱也要翻垃圾箱）。
- 验证通过后，建议到 https://myaccount.google.com/apppasswords 吊销并重新生成一条应用专用密码
  （原密码曾在对话中明文出现），覆盖 `local/env/dev.json` 的 `GMAIL_APP_PASSWORD` 即可，无需重跑脚本。

# 备注（SMTP）

- 后续要改 SMTP 或限流，直接 PATCH `/v1/projects/nfoishlluynelazgwduc/config/auth` 即可，
  不必手动点 Dashboard（改限流只传 `rate_limit_*`，不影响 smtp 字段）。
- **当前限流值**：`email_sent=20`（按项目汇总，受 Gmail 约 500 封/天 约束）、
  `sms_sent=5`（未开短信登录，永不触发）、`token_refresh=300`（按 IP）、`verify=30`、`otp=30`。
  换专业邮件服务（Resend / SES）后 `email_sent` 可大幅上调；若开手机号登录，`sms_sent` 要调高。
- ⚠️ 配完自定义 SMTP 后 `rate_limit_email_sent` **不会自动放开**，仍停留在自带 SMTP 的 2/小时，
  必须手动改 —— 最容易漏的一步。
- 端口与主机：`smtp.gmail.com` 用 587(STARTTLS) 或 465(SSL) 均可；
  `smtp-relay.gmail.com` **只有 465 能用**（个人 Gmail 用前一个）。
- 发件人地址必须与 SMTP 登录账号一致，改成别的会被 Gmail 拒。
- 两个 API 坑（已踩过，留档）：
  ① 令牌前缀 `sbp_fc` = scoped token，可能只有读权限 → 改用 classic 全访问令牌（创建时不勾任何权限）；
  ② `smtp_port` 必须传**字符串** `"587"`，传数字会 400 `expected string, received number`
  （官方文档示例写的是数字，与实际 API 不一致）。
- 应用专用密码只存于 `local/env/dev.json`，**不要写进 `doc/` 下任何文档**（会被 git 提交）。
- 若遇到机器人刷注册拖垮发信信誉，优先配 CAPTCHA，而不是关掉邮箱确认。

## 邮件模板已改为 6 位验证码（2026-09-09，已完成，此段为留档）

- **改法（API，无需点控制台）**：PATCH `/v1/projects/nfoishlluynelazgwduc/config/auth` 传三个字段：
  - `mailer_templates_confirmation_content`：正文用 `{{ .Token }}` 输出验证码（**不要**再用 `{{ .ConfirmationURL }}`）。
  - `mailer_subjects_confirmation`：标题同步改成验证码口吻。
  - ⚠️ `mailer_otp_length` **必须设为 6**：默认是 **8**，而 App 端 `verify_email_page.dart` 的
    `_kCodeLength` 写死 6 —— 不改会出现「邮件 8 位码、输入框只收 6 位」必然校验失败。
    这个字段是全局 email OTP 长度，改 6 不影响找回密码（那条走 deep link + `TokenHash`，与 OTP 长度无关）。
  - ⛔ **最小只能是 6**：2026-09-09 试过设 4，API 直接 400
    `mailer_otp_length: Too small: expected number to be >=6`。想要 4 位只能自建验证码链路。
- **找回密码（Reset Password）模板刻意不改**：它仍用 `{{ .ConfirmationURL }}`，靠深链唤起 App，
  `{{ .RedirectTo }}` 已由代码显式传 `uk.aknot.toolbox://reset-callback`。别顺手一起改成 Token。
- 模板支持 `{{ .Token }}` / `{{ .TokenHash }}` / `{{ .ConfirmationURL }}` / `{{ .SiteURL }}` / `{{ .Email }}` 等变量，
  官方文档里「Email prefetching」一节明确推荐：邮件客户端预取链接会导致链接被提前消费，改用 `{{ .Token }}` 可规避。
- `mailer_templates_custom_contents` / `mailer_subjects_custom_contents` 是「哪些模板被自定义过」的布尔标记集合，不是模板内容本身。

# 🗄 邮箱存在性校验函数 check_email_exists【历史留档 · 已随邮箱链路下线】

- **背景**：Supabase 的 `resetPasswordForEmail` 出于防账号枚举设计，邮箱不存在时也返回成功，
  客户端无法区分 → 忘记密码页「随便填邮箱也发信」。客户端又查不了用户表
  （`public.users` 对 anon revoke、`auth.users` 在私有 schema），故由服务端
  `SECURITY DEFINER` 函数代查。
- **已执行**：`scripts/sql/check_email_exists.sql` 已在 Supabase SQL Editor 执行（函数 +
  grant 给 anon/authenticated/service_role + revoke PUBLIC + `notify pgrst` 刷新缓存）。
- **客户端**：`forgot_password_page.dart` 流程 = 格式校验 → `rpc('check_email_exists')`
  → 已注册才发信；未注册提示 `emailNotRegistered`、校验链路异常提示 `emailCheckFailed`，
  **两者都不降级发信**（否则又回到原问题）。
- **验证脚本**（本机终端跑，会读 `local/env/prd.json`）：
  ```bash
  cd tool_box
  python3 scripts/check_email_exists.py                  # 只验 false 分支
  python3 scripts/check_email_exists.py 你的已注册邮箱    # 同时验 true 分支
  ```
  期望：随机未注册邮箱 → `false`；已注册邮箱 → `true`。
  若报 `PGRST202`，等 10 秒重跑（schema cache 刷新有延迟）。
- **安全权衡（留档）**：该函数等于把「某邮箱是否注册」暴露给未登录者 = 账号枚举面。
  缓解：① 前端连点节流；② Dashboard 配接口限流；③ 不需要精确提示时
  `revoke execute on function public.check_email_exists(text) from anon;` 即可关闭，无需删函数
  （关掉后客户端会全部落到 `emailCheckFailed` 提示，届时需把代码改回「直接发信」）。
- **可复用**：同一函数可直接用于**注册页邮箱查重**（注册时提示「该邮箱已注册」），无需再建函数。

# 🗄 密码重置深链：Supabase 控制台登记 reset-callback【已废弃 · 代码已删除】

> ⛔ **2026-09-10 废弃**：`forgot_password_page` / `reset_password_page` /
> `password_recovery_state.dart` / `/reset-password` 路由与 `reset-callback` 深链分支
> 已全部删除，`passwordResetRedirectUrl` 常量也已移除。本节仅作设计留档。

- **背景**：重置邮件里的链接默认取控制台的 **Site URL**（初始值 `http://localhost:3000`），
  真机上就是个打不开的本地地址。代码侧已修：发信时显式传
  `redirectTo = uk.aknot.toolbox://reset-callback`（`oauth_config.dart`）。
- **待做（控制台，唯一剩余步骤）**：
  1. Authentication → URL Configuration → **Redirect URLs** 增加
     `uk.aknot.toolbox://reset-callback`（不在白名单时服务端会拒绝跳转，表现为点了链接没反应）。
  2. （可选）**Site URL** 从 `http://localhost:3000` 改掉——它是「没传 redirectTo 时的兜底地址」。
     纯 App 项目**不需要买域名**，官方支持直接填深链（文档示例 `com.supabase://login-callback/`），
     本工程填 `uk.aknot.toolbox://login-callback/` 即可；有域名（如 `https://aknot.uk`）则填域名更通用。
     不改也能跑：重置密码已显式传 redirectTo、确认邮件已改用 `{{ .Token }}` 验证码，
     都不再依赖 Site URL，只是控制台看着别扭、且任何仍用 `{{ .SiteURL }}` 的模板会发出 localhost 链接。
  3. （可选）Authentication → Emails → Reset Password 模板确认链接变量是
     `{{ .ConfirmationURL }}`，不要写死 localhost。**它不用改**：
     `ConfirmationURL` 是 Supabase 拼好的成品链接，形如
     `https://<ref>.supabase.co/auth/v1/verify?token={{ .TokenHash }}&type=recovery&redirect_to={{ .RedirectTo }}`，
     已经把我们传的 `redirectTo` 编进去了 —— 服务端校验后 302 到深链，App 被唤起。
     `{{ .RedirectTo }}` 只有在**自己拼链接**时才需要（如 SSR 自建 `/auth/confirm` 端点、
     或想先把用户送到自己的服务器再回 App），本项目不走这条路。
     ⚠️ 真机点上没反应的排查顺序：先看 `redirect_to` 是否在 Redirect URLs 白名单（不在会被拒/
     退回 Site URL），再确认浏览器对「302 到自定义 scheme」是否放行（Android Chrome 偶有拦截，
     可在手机浏览器里直接打开链接观察是否跳转来判定）。
- **代码侧已完成**（无需再动）：
  - `forgot_password_page.dart`：`resetPasswordForEmail(email, redirectTo: ...)`。
  - `reset_password_page.dart`（新）：设置新密码页，路由 `/reset-password`。
  - `password_recovery_state.dart`（新）：全局标记，深链事件 → 路由跳转的桥梁。
  - `main.dart`：订阅 `AuthChangeEvent.passwordRecovery` 置位标记（runApp 之前注册，覆盖冷启动）。
  - `app_router.dart`：`refreshListenable` + `redirect`，标记一置位即跳设置新密码页。
  - `AndroidManifest.xml`：新增 `uk.aknot.toolbox` + host `reset-callback` 的 intent-filter
    （Android 按 host 精确匹配，不能复用 login-callback）；iOS 只认 scheme，无需改。
- **验收**：真机点邮件链接 → App 被唤起并直达「设置新密码」页 → 改密成功 → 跳登录页用新密码登录。
- **注意**：深链换取 session 由 `supabase_flutter` 内部自动完成（PKCE，链接里是 `?code=`），
  **不要**再自己调 `getSessionFromUrl`，重复调用会因 code 已用而失败。

---

# 方案 B 真机沙盒验收 未完成

> 代码侧与服务端均已就绪（`dart analyze lib` 零 issue、`bind-member` 已部署），
> 剩下的是**真机跑一遍确认链路真的通**。完整 7 条见 `doc/purchase_handoff.md` §9.10，
> 这里只列最容易出问题、必须人工确认的三条。

- **① 未登录购买 → 弹同步框 → Apple 授权 → 云端生效**
  沙盒账号购买 → 应弹出「同步会员到账号」→ 点 Apple → 授权完成 →
  Supabase SQL Editor 查 `select is_member, member_expire_at from public.users where id = '<uid>';`
  期望 `is_member = true`、`member_expire_at = null`（买断不限期）。
- **② 已登录购买 → 无弹框**，`users.is_member` 直接变 true（静默 bind）。
- **③ 换设备 / 重装登录（不恢复购买）→ 会员点亮**
  这是方案 B 的核心价值，验证 `user_profiles.is_member_active` 是否生效。

**排查手法**

- 客户端看 bind 结果：`vip_bind` 埋点的 `result` 维度（`ok` / `need_login` / `failed`）。
- `failed` 优先查 Edge Function 日志：Dashboard → Edge Functions → `bind-member` → Logs。
- 401 `invalid_user_token` → 说明客户端传的 Bearer 不是用户 access token（登录态没建立）。
- 500 `update_failed` → 多半是 `public.users` 触发器拦了写（只有 service_role 能写会员字段）。

---

# bind-member Edge Function 部署 已完成（2026-09-10）

- 已部署到 ref `nfoishlluynelazgwduc`，函数位于 `supabase/functions/bind-member/index.ts`。
- 命令与冒烟验证结果见 `doc/purchase_handoff.md` §9.12（重新发布时照抄即可）。
- 关键点留档：`export HOME=/tmp/supabase_home`（CLI 要写 `$HOME/.supabase/telemetry.json`，
  用真实 HOME 在受限环境会 EPERM 直接崩）；`--no-verify-jwt`（自行用 `getUser()` 校验身份，
  便于区分「没带 token」与「token 无效」）。
- 冒烟：只带 apikey → 401 `missing_user_token`；伪造 Bearer → 401 `invalid_user_token`。
  两者都是**函数自己返回的码**，证明代码在跑而非被网关挡掉。
