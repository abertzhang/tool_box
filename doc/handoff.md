# tool_box 交接文档（handoff）

> 最后更新：2026-09-08　｜　分支：`feat`　｜　最近提交：`28e2996 fix:注册页面`
> 当前状态：`dart analyze lib` **零 issue**；`flutter build ios --simulator` 可编译通过；
> **51 项改动未提交**（见 §7）。邮件已切 Gmail 自定义 SMTP（见 §3.4）。

tool_box 是一个 Flutter 硬件工具箱 App（knot_phone 的子集项目），含工具集、会员内购、
Supabase 账号体系与全链路埋点。本文档是**唯一总交接入口**，专项细节指向下列文档，
不在本文重复：

| 专项 | 文档 |
| --- | --- |
| 埋点体系（35 个事件、表结构、SQL） | `doc/track.md`（10.2 节为事件速查） |
| 数据库（users / app_events / 触发器 / RLS） | `doc/database.md` |
| 会员内购（IAP、上架、审核） | `doc/purchase_handoff.md`、`doc/purchase_android.md` |
| 未完成事项清单 | `doc/todo.md` |
| 账号与密钥总账（Supabase / Google / AdMob / Apple） | `doc/account_info.md`（⚠️ 含 service_role key，已 gitignore） |

---

## 1. 环境与常用命令

**SDK**：Flutter **master** `/Users/zhangchunhua/sdk/flutter/master`（Dart 3.14 dev）。
⚠️ 工程根目录的 **flutter wrapper 脚本已损坏**，不要敲 `./flutter ...`（工程内的那个）。
日常一律用 `$FLUTTER_ROOT/bin/dart`；**仅「增删插件」时用 `$FLUTTER_ROOT/bin/flutter pub get`**
（SDK 自带的 flutter 命令本身是好的，见下方说明）。

```bash
export FLUTTER_ROOT=/Users/zhangchunhua/sdk/flutter/master

# 拉依赖（改 pubspec 后必跑；跑完 iOS 还需 pod install）
$FLUTTER_ROOT/bin/dart pub get

# 静态检查（完成标准：No issues found）
$FLUTTER_ROOT/bin/dart analyze lib

# 编译验证（模拟器，免签名）
$FLUTTER_ROOT/bin/flutter build ios --simulator --debug --no-codesign
```

**运行 / 打包**：用 `scripts/dev.sh`（开发）、`scripts/prd.sh`（生产），二者内部统一
`--dart-define-from-file=local/env/prd.json` 注入配置。

**新增 iOS 插件后（必走四步，否则 Xcode 报 `Module 'xxx' not found`）**：
```bash
# ⚠️ 插件「增删」时必须是 flutter pub get，不能用 dart pub get：
#    dart pub get 只解依赖，**不会**重写 .flutter-plugins-dependencies，
#    后面 pod install 会按旧清单执行 → 新插件的 Pod 静默缺失（Podfile.lock 里搜不到）。
#    平时（未增删插件）两者等价，用 dart 即可。
$FLUTTER_ROOT/bin/flutter pub get
cd ios && export LANG=en_US.UTF-8 && /usr/local/bin/pod install && rm -rf build/
```
然后 Xcode **打开 `Runner.xcworkspace`**（不是 `.xcodeproj`）→ Clean Build Folder。

**iOS Podfile 两条硬约束（改前先读，别踩）**：

1. `use_frameworks!` **不能删**。去掉后 `flutter_compass` / `audio_streamer` 这类
   ObjC+Swift 混合 pod 会报 `'xxx-Swift.h' file not found` —— 静态链接下自动生成的
   Swift 桥接头找不到。
2. 但 `use_frameworks!` 会让 `google_mobile_ads` 编译失败：其公开头
   `FLTAd_Internal.h` / `FLTAdPreloader.h` 引用了 AdMob XCFramework 的私有头
   `GoogleMobileAds_Beta.h`（在 `PrivateHeaders/`），clang 把它当 framework module 编译时报
   `Include of non-modular header inside framework module`。
   已在 `post_install` 里**单独**给该 pod 设 `DEFINES_MODULE = NO` 规避。
   ⚠️ `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES` 在 Xcode 26 下**无效**，
   实测设了照样报错，不要再用这个思路。

## 2. 目录结构

```
lib/
├── main.dart                 初始化序：Hive → Isar → Supabase → Track → 身份绑定 → YAML
├── config/                   AppEnv（String.fromEnvironment 读配置）、base_url
├── common/
│   ├── track/                通用埋点引擎（禁 import supabase_flutter，可整目录 cp 复用）
│   ├── analytics/            业务埋点（AppTrack / TrackEvents），单向依赖 track
│   ├── provider/             全局 Provider（theme / locale / app_settings）
│   ├── database/ http_util/ util/
├── feature/
│   ├── splash/               启动屏（两段式）
│   ├── home/                 Tab 壳层
│   ├── tool/                 工具页群 + 路由
│   ├── login/                登录页（按平台二选一：iOS/macOS→Apple，Android→Google）+ OAuth 封装
│   └── profile/              个人中心：购买页、About Us、编辑资料等
├── l10n/                     中英双语（arb + 生成类）
└── router/app_router.dart    GoRouter 集中定义
```

## 3. 关键模块

### 3.1 配置注入（`local/env/prd.json`）
```json
{ "SUPABASE_URL": "https://<ref>.supabase.co", "SUPABASE_ANON_KEY": "<anon-key>" }
```
经 `--dart-define-from-file` 注入，Dart 侧由 `AppEnv` 用 `String.fromEnvironment` 读取，
**新增配置项无需改 Dart**。`local/` 已被 `.gitignore` 整体忽略，密钥不会入库。

### 3.2 埋点
两层架构：`common/track`（通用引擎）+ `common/analytics`（业务事件）。业务代码**只调 `AppTrack`**。
- 身份注入：anonId → `setUserId` → 订阅 `onAuthStateChange` → `backfillQueuedIdentity()`。
- 高频三原则：1.5s throttle、首帧屏蔽、除 `vip_*`/`app_open(cold)` 外一律 `log`。
- page_view 走 GoRouter observer，**Tab 切换需手动补**。
- 默认 `TrackConfig(enabled: false)`，**上线前改 true**。

### 3.3 Supabase
- 项目 ref `nfoishlluynelazgwduc`；埋点 Edge `/functions/v1/track-event`。
- **客户端（anon key）查不了任何用户表**（`public.users` 对 anon revoke、`auth.users` 私有 schema）。
  需要查询时必须写 `SECURITY DEFINER` 函数经 RPC 暴露，先例：`scripts/sql/check_email_exists.sql`。
- `public.users` 三列统计**只由** `app_events` 触发器改，客户端直改会被拒 42501。
- ⚠️ **沙箱硬防护**：进程把 anon/service_role key 读进内存会被 SIGTERM（exit 137）。
  涉密钥的验证**只能在用户本机终端跑**（已提供 `scripts/check_email_exists.py` 等自检脚本）。

### 3.4 邮件发送（Gmail 自定义 SMTP）

- **已上线**（2026-09-07）：发送账号 `zhang13655179933@gmail.com`，`smtp.gmail.com:587`，
  发件名 `Tool Box`。自带 SMTP 的两条限制——只能发给组织成员、2 封/小时——均已解除。
- 复现方式：`scripts/setup_smtp_gmail.sh`，走 Management API `PATCH /v1/projects/<ref>/config/auth`；
  密钥读 `local/env/dev.json`（`SUPABASE_ACCESS_TOKEN` + `GMAIL_APP_PASSWORD`，已被 /local/ 忽略）。
- 前置：Google 账号须开**两步验证**并生成 **16 位应用专用密码**
  （Gmail 不接受登录密码做 SMTP 认证，错了报 `535 5.7.8`）。
- 当前限流：`email_sent=20`（**按项目汇总**，受 Gmail 约 500 封/天 约束）、`sms_sent=5`、
  `token_refresh=300`（**按 IP**）、`verify=30`、`otp=30`。
- ✅ **注册确认链路已闭合**（2026-09-09）：Confirm signup 模板已由链接改为 **6 位验证码**
  （`mailer_templates_confirmation_content` 用 `{{ .Token }}`），不再依赖 `site_url`，可以放量。
  ⚠️ 同时把 `mailer_otp_length` 从默认 **8** 改为 **6** —— App 端 `verify_email_page.dart`
  的 `_kCodeLength` 写死 6，不改会出现「邮件 8 位、输入框只收 6 位」必然校验失败。
- ⛔ **`mailer_otp_length` 不能小于 6**（2026-09-09 实测）：PATCH 成 4 被拒
  `{"message":"mailer_otp_length: Too small: expected number to be >=6"}`，控制台 UI 也是 6 起。
  → 「4 位验证码」在 Supabase 原生邮箱 OTP 链路上**做不到**；真要 4 位只能自建
  （Edge Function 自己发码 + 自己的表校验 + admin 确认账号），成本明显更高。
  改位数的脚本：`scripts/set_otp_length.sh`（默认 6，内置 >=6 校验）。
- ℹ️ `site_url` 仍为 `http://localhost:3000`（未改，不影响验证码流程）：
  仅当某个模板仍用 `{{ .ConfirmationURL }}` / `{{ .SiteURL }}` 时才会发出 localhost 链接，
  目前只剩 Reset Password 用它，而那条靠代码显式传的 `redirectTo` 覆盖，见 §3.5。

### 3.5 登录体系

> ⚠️ **2026-09-10 重大变更（方案 B，见 `doc/purchase_handoff.md` §9）**：
> 邮箱密码链路已从 App 端**整体移除** —— 登录页只剩第三方按钮，注册 / 忘记密码 /
> 重置密码 / 邮箱验证四个页面与路由已删除，`passwordRecoveryPending` 与
> `reset-callback` 深链分支一并清理。下面 §3.5 若干条目属**历史留档**（说明当初
> 为什么那么设计），实现已不在代码中。Supabase 控制台 Email provider **保持开启**
> （老邮箱账号仍可登录），只是 App 端不再提供入口。

- **登录 = 注册合一**：OAuth 首次授权自动建号，无独立的「注册」步骤。
- **平台口径（每平台只给一个按钮）**：iOS / macOS **只显示 Apple**，Android **只显示 Google**。
  合规上没问题：App Store 4.8 只在「同时提供了其他第三方登录」时才强制要求给 Apple，
  我们按平台二选一，两边都不触发。
- Google 走**原生** `google_sign_in` + `signInWithIdToken`（非浏览器 OAuth），
  封装在 `feature/login/google_sign_in_native.dart`。
  ⚠️ `oauth_config.dart` 的两个 Client ID **仍为空**，未补齐前 Google 登录不可用。
- 购买成功后引导「同步会员到账号」（Apple / Google 授权 → Edge `bind-member`
  把权益写云端），实现细节与验证清单见 `doc/purchase_handoff.md` §9。

**历史留档（已移除的邮箱链路）**：
  `forgot_password_page` 发信传 `redirectTo = uk.aknot.toolbox://reset-callback`
  → `supabase_flutter` 内部自动用 code 换 session（**禁止**自己再调 `getSessionFromUrl`）
  → 抛 `AuthChangeEvent.passwordRecovery` → `main.dart` 置位全局标记
  → GoRouter `refreshListenable/redirect` 跳 `/reset-password`（`reset_password_page.dart`）。
  用「全局标记 + redirect」而非 `context.push`，是因为冷启动时该事件可能早于页面树建立。
- **邮箱确认走 6 位验证码**（不走确认链接）：
  注册后 `session == null` → push `/verify-email`（`verify_email_page.dart`）
  → 用户填邮件里的 6 位码 → `verifyOTP(type: signup)` → 成功进首页。
  之所以避开链接：确认邮件的 `{{ .ConfirmationURL }}` 默认指向 `site_url`（localhost），
  真机打不开，用户会永远激活不了。验证码方案不依赖 `site_url`、也不跳出 App。
  ✅ 服务端模板已同步（2026-09-09，走 Management API 改，非控制台）：
  `mailer_templates_confirmation_content` = `{{ .Token }}`，`mailer_otp_length` = 6。
  Reset Password 模板**刻意保留** `{{ .ConfirmationURL }}`（走深链唤起 App），不要一起改成 Token。

### 3.6 会员内购
购买页已独立为 `feature/profile/page/purchase_page.dart`（路由 `/profile/purchase`，
非弹窗）；tools 页顶部有会员状态条（已购显示 VIP，未购点 Upgrade 跳转）。
详见 `doc/purchase_handoff.md`。

### 3.6.1 广告（AdMob，2026-09-09 接入）

- 插件 `google_mobile_ads`（**仅 Android / iOS**，桌面与 Web 无实现）。
- 代码在 `lib/common/ads/`：`admob_config.dart`（ID 中心）、`admob_init.dart`（SDK 初始化）、
  `banner_ad_view.dart`（自适应横幅位）。
- 展示位（`AdBannerSlot`，同一单元 ID 多处展示，各自持有独立 BannerAd 实例）：
  - `tool_compass_after`：**tools 页「通用工具」双列网格第一行（Compass + Noise）之下**
    （原名 `tool_page_bottom` 在页尾，2026-09-10 上移后更名；tools 页工具区已从
    单列列表恢复为双列网格，网格切成「前 2 张 / 其余」两段渲染、广告插中间）；
  - `noise_history_top`：**噪音检测器页「历史记录」标题上方**（2026-09-09 新增）；
  - `level_measurements_top`：**水平仪页「Measurements」标题上方**（2026-09-09 新增）；
  - `compass_history_top`：**指南针页「历史记录」标题上方**（2026-09-10 新增）。
    二级页都不放页面最底部——表盘 / 水平仪 / 罗盘 + 读数卡是核心区，广告插在
    中间会打断操作流；二级页没有底部 Tab，不存在「紧贴高频点击区误触」的违规风险。
  - `profile_about_top`：**Profile 页「关于」分组之上、设置分组之下**（2026-09-10 新增）。
    首个 Tab 常驻页广告位（切 Tab 即 dispose / 切回重新请求）；本页 Column 为
    `crossAxisAlignment.stretch`，广告外包 `Padding(horizontal:16)` 与分组卡片对齐。
  - 新增广告位只需三步：页面 `ref.watch(isMemberProvider)` → 非会员插入 `AdBannerSlot`
    （带唯一 `slot`）→ 在 `doc/track.md` §8.1 登记 slot。
- **会员（Pro Unlock）不加载、不展示**：由各页面 `ref.watch(isMemberProvider)`
  决定整块**不入树**（只隐藏不够，摘出树才会触发 `dispose()` 释放原生实例）
  ——VIP 卖点文案写着 `No ads.`，会员看到广告属功能缺陷。
- ⚠️ 广告位宽度：组件用 `LayoutBuilder` 取**父容器实际可用宽度**请求自适应尺寸，
  不用屏宽——页面普遍带左右 padding（tools 20.w / noise 16.w），按屏宽请求会横向溢出。
- ⚠️ **换广告 ID 必须改三处**，缺一即崩或一直无填充：
  `common/ads/admob_config.dart` + `AndroidManifest` 的 `com.google.android.gms.ads.APPLICATION_ID`
  + `Info.plist` 的 `GADApplicationIdentifier`。
- **2026-09-10 已切到生产 ID**（AdMob 账号 `ca-app-pub-4627610691741188`，iOS / Android
  两个应用各一个横幅单元；具体取值见 `admob_config.dart` 的 `_appIdAndroid` 等四个常量）。
  谷歌测试 ID 常量仍保留在同一文件，供 `--dart-define=ADMOB_*` 临时注入切回测试广告。
  ⚠️ **开发期别用真 ID 反复刷**：会算无效流量，点自家广告是封号常见原因。
  在 AdMob 控制台「设置 → 测试设备」加设备最省事（用真 ID 也只下发测试广告）。
- 埋点：`ad_banner_result`（`slot` / `success` / `code`），见 `doc/track.md` 8.1。
- 合规：已同步更新《第三方 SDK 清单》（新增「广告变现」分组）与《隐私政策》（新增「五、广告」章节）。

### 3.7 主题体系（双色卡）

主题是**两个正交维度**：

| 维度 | Provider | Hive 键 | 取值 |
|---|---|---|---|
| 明暗模式 | `themeProvider` | `theme_mode` | light / dark / system |
| 色卡方案 | `themeColorProvider` | `theme_color` | `AppThemeColor.coffee` / `.blue` |

二者在 `main.dart` 合成为 `theme` / `darkTheme`；加载中（`.value == null`）回落 coffee。
切换入口在 profile 页「设置」分组首行（两枚胶囊选项卡，`_ThemeColorChip`）。

**色板架构**：页面不得各自硬编码配色，统一走 `common/provider/theme/app_palette.dart`
的 `AppPalette`（ThemeExtension）—— 由 AppTheme 注入 coffee 版、SkyTheme 注入 blue 版，
页面用 `AppPalette.of(context)` 取语义色（pageBg / cardBg / cardElevated / cardBorder /
titleText / bodyText / labelText / valueText / hintText / accent / accentText /
secondaryBtnBg / fieldBg / divider / muted / danger / gold / headerGrad）。

改色值时**三条硬规则**：

1. `AppPalette` 的 **coffee 两套取值必须与各页旧硬编码逐项一致**，否则切回咖啡色会视觉回归。
2. 语义固定色**不随色卡变化**：分贝绿黄橙、罗盘刻度、会员金渐变、启动屏品牌色、
   手电筒光效、成功绿——这些保留在各页私有色板里，勿接入 AppPalette。
3. 只改私有色板的 `of()` 工厂，不要顺带重构页面逻辑。
   深色分支**必须一并接入**，否则「深色 + 蓝色」组合下该页不生效（踩过）。

已接入 13 个文件；`pixso_theme.dart` 为死代码（零引用），暂保留未删。

### 3.x 保存命名开关（全局，2026-09-09）

`saveNamePromptProvider`（`common/provider/app_settings/save_name_prompt_provider.dart`）：
控制「保存记录时是否弹命名框」，**默认 false（不弹）**。关 → 直接用
`defaultRecordName()`（毫秒时间戳）命名；开 → 走原命名弹窗。
持久化在 **SharedPreferences** 键 `save_name_prompt`（不是 Hive —— 单个 bool 开关
走 sp 更轻，Hive 仍负责语言/主题等结构化设置）。
入口：profile 页「设置」分组「保存时询问名称」行（Switch）。
已接入 **level / compass / noise** 三页，接法一致（读开关 → 弹窗 or 时间戳直存，
埋点带 `prompt`）。区别在于各页弹窗的可填项：noise 的「环境类型」只在弹窗路径下
能填，不弹框时留空。

## 4. 硬约束 / 踩坑（交接重点，按踩坑频率排序）

1. **i18n(arb) 禁止未配对单引号 `'`**：`'` 在 ICU 里是特殊字符，未配对会触发
   `ICU Lexing Error` → build 期 `Target gen_localizations failed`（整包编不出来）。
   本机 `gen-l10n` 损坏、只能手改 arb（5 个文件：2 个 arb + 3 个生成类），
   英文缩写（`don't`/`we'll`）必须改写或成对转义。
2. **按钮内 `CircularProgressIndicator` 必须套 1:1 正方形**
   `SizedBox(width: 24, height: 24)` + `strokeWidth: 3`。Material 3 默认约束 48×48，
   按钮内容区高度不足会把圆压成椭圆。登录/注册/找回密码三处已统一。
3. **Riverpod 3.x：`ref.listen` 禁止写在 `initState`**（元素未挂载，断言红屏），写 `build`。
4. **跨异步用 context**：先在同步帧捕获 `final navigator = Navigator.of(context);`。
5. **go_router `extra` 会被擦成 `Map<dynamic,dynamic>`**：先 `is Map` 宽进再窄取，不要强转。
6. **IAP 平台调用必须 try/catch**：`buy`/`restore` 的 PlatformException 冒泡会整页红屏。
7. **iOS 内购不需要 entitlement**（写了反致签名失败），只需显式 App ID + 付费协议 Active。
   entitlements 分 Debug/Release 两个文件。
8. **Android `<data>` 按 host 精确匹配**：新增深链 host 必须新增一个 intent-filter，
   不能复用；iOS 只认 scheme，无需改。
9. **测试**：`flutter test` 沙箱跑不了；纯逻辑改用 `package:test` + `dart test`
   （测试目标不 import Flutter 包）。
10. **启动屏**：`flutter_native_splash` 用 `background_image` 才铺满（不是 `image`）。
11. **Supabase Management API 两个坑**：① 令牌前缀 `sbp_fc` = scoped token，可能**只有读权限**
    （与账号角色无关，本组织是 Owner 也照样 403），写操作要换 classic 全访问令牌
    （创建时不勾任何权限）；② `smtp_port` 必须传**字符串** `"587"`，传数字会 400
    `expected string, received number`（官方文档示例写的是数字，与实际 API 不一致）。
12. **配完自定义 SMTP 后 `rate_limit_email_sent` 不会自动放开**，仍停在自带 SMTP 的 2/小时，
    必须手动改 —— 最容易漏的一步，漏了等于没配。

### Git / 仓库（易踩）
- tool_box **无独立 `.git`**，共用父仓库 `/Users/zhangchunhua/project_knot/repo/knot/.git`。
  提交必须限定 `tool_box/` 路径，**切勿在仓库根 `git add -A`**（会卷入 knot_phone 等兄弟项目）。
- `scripts/prd.sh` 被 `.gitignore:50` 忽略 → 对它的改动**不会入库**，需另行同步。
- `android/build/` 未被忽略 → 提交前需排除或补 `.gitignore`。
- 遇 `index.lock: File exists`：**先 `lsof .git/index.lock` 确认无进程持有**（勿盲删），再 `rm -f`。

## 5. 包名与标识符（改包名时四处必须同步）

包名全端 `uk.aknot.toolbox`，OAuth scheme `uk.aknot.toolbox://login-callback`：
1. Dart 常量 `feature/login/oauth_config.dart`
2. iOS `Info.plist` → `CFBundleURLTypes`
3. Android `AndroidManifest.xml` → intent-filter
4. Supabase 控制台 → Authentication → URL Configuration → Redirect URLs

## 6. 待办（详见 `doc/todo.md`）

**阻塞上架的**：
- `oauth_config.dart` 的 `kGoogleIosClientId` / `kGoogleWebClientId` **仍为空字符串**，
  需从 Google Cloud Console 创建 iOS + Web 类型客户端 ID 填入，并同步
  `Info.plist` 反转 scheme 与 `strings.xml` 的 `default_web_client_id`；
  Android 还需绑定包名 + SHA-1。
- **密码重置深链**：Supabase 控制台 Redirect URLs 加
  `uk.aknot.toolbox://reset-callback`，并把 Site URL 从 `http://localhost:3000` 改成真实地址。
- **邮箱确认**：已定「6 位验证码」方案，**代码侧已完成**（`verify_email_page.dart`
  + `/verify-email` 路由 + 注册页改跳转 + i18n 10 key × 5 文件，构建已验证）。
  仅剩控制台一步：Authentication → Emails → Confirm signup 模板把
  `{{ .ConfirmationURL }}` 换成 `{{ .Token }}`。
  改完前新注册用户激活不了；此前卡住的旧账号需在 Users 里手动 Confirm（详见 `doc/todo.md`）。

**可优化**：
- `check_email_exists` 可复用到**注册页邮箱查重**（提示「该邮箱已注册」）。
- 埋点上线前把 `TrackConfig(enabled:)` 改 `true`。

**安全留档**：`check_email_exists` 把「邮箱是否注册」暴露给未登录者 = 账号枚举面。
缓解：① 前端连点节流 ② Dashboard 配接口限流 ③ 不需要时
`revoke execute on function public.check_email_exists(text) from anon;`
（关掉后客户端会全落到 `emailCheckFailed` 提示，届时代码需改回「直接发信」）。

## 7. 未提交改动（26 项，待确认后按批量粒度 commit）

- **全平台应用图标**（新图标，约 30 个文件）：Android mipmap ×5、iOS AppIcon ×14、
  macOS ×7、web ×4、windows ×1；相关脚本 `scripts/generate_icons.py`（新增）。
- **密码重置深链闭环**：`oauth_config.dart`、`forgot_password_page.dart`、`login.dart`、
  `main.dart`、`app_router.dart`、`AndroidManifest.xml`、l10n ×5
  （`resetPasswordTitle/Desc`、`newPasswordHint`、`resetPasswordSubmit/Success`、`resetLinkInvalid`）；
  新增 `reset_password_page.dart`、`password_recovery_state.dart`。
- **邮箱存在性校验**：新增 `scripts/sql/check_email_exists.sql`（**已在 Supabase 执行**）、
  `scripts/check_email_exists.py`（自检脚本）、`doc/todo.md` 更新。
- **邮箱确认改走 6 位验证码**：新增 `verify_email_page.dart`；`register_page.dart`
  （注册后不再 pop，改 push 验证码页）、`app_router.dart`（`/verify-email`）、
  l10n ×5（复用上一条已改的文件）。
- **孤儿用户清理脚本**：新增 `scripts/sql/cleanup_orphan_users.sql`
  （清 `public.users` 里 auth 已删的残留行 + 加 `users_id_fkey` 级联外键）、`doc/todo.md` 更新。

建议切分 3 笔：`feat(login)` 密码重置深链 + 邮箱校验 + 验证码激活 / `chore` 全平台图标 / `docs` todo 更新。

## 8. 验收路径（交接后自测）

1. `dart analyze lib` → No issues found
2. `flutter build ios --simulator --debug --no-codesign` → Built Runner.app
3. 忘记密码：填未注册邮箱 → 提示未注册且**不发信**；填已注册邮箱 → 收到重置邮件
4. 点邮件链接 → App 唤起直达「设置新密码」→ 改密成功 → 回登录页用新密码登录
4b. 注册新邮箱 → 进验证码页 → 收到 **6 位数字**（不是链接）→ 填码成功进首页
    （前提：控制台 Confirm signup 模板已改成 `{{ .Token }}`；老测试账号已删，
     删完记得跑 `scripts/sql/cleanup_orphan_users.sql` 清 `public.users` 孤儿行）
5. Google 登录（填完 client ID 后）：Android / iOS 各验一次能拿到 session
6. 内购：tools 页 Upgrade → 购买页 → 沙盒购买 / 恢复购买
7. **邮件**：用**非团队成员**邮箱注册 → 收到来自 `zhang13655179933@gmail.com` 的确认邮件；
   Dashboard → Logs → Auth Logs 无报错（同一邮箱 60 秒内只能发一次，别连点误判成故障）
