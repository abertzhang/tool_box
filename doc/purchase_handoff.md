# 内购（Apple IAP + Google Play Billing）实现交接文档

> 工程：`tool_box`（knot_phone 的精简自洽子集，户外工具箱）
> 功能：1.99 美元**买断制终身会员**（non-consumable / managed product）
> 创建：2026-09-04 ~ 2026-09-06
> 状态：**代码链路完成 + 模拟器本地购买验证通过（无报错）；真机沙盒待验**

---

## 1. 概述与目标

买断制会员，商品 ID 硬约定为 `pro_unlock`，价格档 **$1.99**，类型 **Non-Consumable**（Android 侧对应 managed product）。

方案定位（2026-09-04 与用户确认「方案 A：纯端侧」）：
- 买断权益**完全绑定系统账号**（Apple ID / Google 账号），**不要求登录 App 账号**即可购买；
- 会员状态 = 云端 `user_profiles.is_member_active` **||** 本机商店权益，由 `isMemberProvider` 合并判定；
- 不做法服务端收据校验（1.99 工具类 App 的可接受取舍），越狱伪造风险已知；升级到方案 B（跨端同步）时由后端用 App Store Server API / Play Developer API 复核，本模块无需改动。

---

## 2. 实现文件清单（按职责）

| 文件 | 行数 | 职责 |
|---|---|---|
| `lib/feature/profile/provider/membership_provider.dart` | 338 | **核心**。封装 `in_app_purchase`：`kMemberProductId`、探测商店、拉起支付、监听流、恢复购买、双端 `completePurchase`。 |
| `lib/feature/profile/page/purchase_page.dart` | 487 | **独立购买页**（取代旧的 ios_purchase_sheet 底部弹窗）：App 图标 + 商品名(Pro Unlock) + 价格($1.99) + 「Upgrade Now」+「恢复购买」；确认步骤即本页，点按钮直接 `membershipProvider.buy()` 调起系统支付（iOS StoreKit / Android Play Billing）。 |
| `lib/feature/profile/routes/route_profile.dart` | 99 | 注册 `/profile/purchase` 路由，`extra` 透传 `source`('profile'/'tool_page') 供漏斗分区观察。 |
| `lib/feature/profile/page/profile_page.dart` | — | `_onUpgrade`：`context.push(ProfileRoute.purchase, extra:{'source':'profile'})` 跳独立购买页；`_onRestorePurchases`；会员卡 UI 由 `isMemberProvider`/`owned` 驱动。 |
| `lib/l10n/app_en.arb` / `app_zh.arb` | — | 词条：`vipTitle` / `vipOpen` / `vipSheetProductName`(Pro Unlock/Pro 解锁) / `vipSheetProductDesc` / `vipSheetOneTime` / `vipSheetConfirm` / `vipPayConfirmTitle`(legacy) / `vipRestore*` / `vipLifetime`。 |
| `pubspec.yaml` | — | 依赖 `in_app_purchase 3.3.0` + `in_app_purchase_storekit`；注册 `assets/images/app.png`。 |
| `android/app/src/main/AndroidManifest.xml` | — | 声明 `<uses-permission android:name="com.android.vending.BILLING" />`。 |
| `ios/Runner/RunnerDebug.entitlements` | — | **仅 Sign in with Apple**；**不含、也不应含任何 IAP entitlement**（见 §6）。 |
| `assets/images/app.png` | — | 弹窗内 App 图标（蓝色指南针工具图标）。 |
| `ios/StoreKitConfig.storekit` | — | 模拟器离线联调用的本地 non-consumable 商品（仅 Xcode ⌘R 生效，见 §5-B）。 |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | — | `<LaunchAction>` 注入 `StoreKitConfigurationFileReference`，打开即用。 |
| `scripts/smoke_iap.dart` | — | 独立 IAP 烟雾入口（`flutter run -t`），`SMOKE_BUY` 开关控制是否真购买。 |
| `scripts/iapsmoke.sh` | — | 包装：`--check-config` / `--devices` / `--device <id>` / `--buy --device <id>`。 |

### 2.1 核心 Provider 关键位置（`membership_provider.dart`）

- L60：`const String kMemberProductId = 'pro_unlock';` —— **全工程唯一商品 ID 常量，改它等于换商品，两端商店须同步**。
- L77-129：`MembershipState`（`checking` / `storeAvailable` / `hasProduct` / `owned` / `price` / `title`）。
- L187-223：`_probeStore()` 探测商店 + 查询商品，存 `price`/`title`，完成后静默 `_syncOwnedOnStart()`。
- L233-241：`_syncOwnedOnStart()` 启动静默同步（iOS 仅调 `restorePurchases()` 读本机 `currentEntitlements`，无 UI）。
- L247-258：`buy()` → `buyNonConsumable`，返回 `IapBuyResult`（started/storeUnavailable/productMissing）。
- L270-280：`restore()` —— iOS 先 `AppStore.sync()`（弹登录框、须用户触发）再 `restorePurchases()`；Android 直接 `restorePurchases()`。
- L283-336：`_onPurchaseUpdated()` 处理 purchased/restored/pending/error/canceled，命中即 `owned=true` 并上报 `vipActivated`，对所有 `pendingCompletePurchase` 调 `completePurchase`。

---

## 3. 商店后台配置（代码之外，必须做）

### 3.1 Apple（App Store Connect）
- 创建 **Non-Consumable** 内购项目：
  - **Product ID = `pro_unlock`**（必须与代码完全一致，差一字 `queryProductDetails` 返回空）；
  - 显示名 **Pro Unlock**（中文本地化 **Pro 解锁**）；
  - 价格档 **$1.99**；
  - 状态 **Cleared for Sale**（否则开发环境查不到）；
  - 本地化（en/zh 等）齐全。
- **无需在 Xcode 加 IAP entitlement**（见 §6）。但要求 App ID 为**显式 App ID**（非通配符）。
- **《Paid Apps 协议》必须已签署** —— 未签会导致 `queryProductDetails` 返回空，最容易被漏。
- 沙盒测试账号（已建）：`zhang13655179933@gmail.com` / `Toolbox2026Sandbox`（**仅联调用，不落任何提交文件**）。

### 3.2 Google（Play Console）

> ⚠️ **Google Play Billing 的硬性前置**：Android 设备要能 `queryProductDetails` 查到商品并调起支付，
> App **必须已上传到 Play Console（至少 Internal testing 内部测试轨道）** 且包名 `uk.aknot.toolbox` 一致。
> 仅 `flutter run` 装的 debug APK（未上传 Play）在真机上 `queryProductDetails` 会返回空 —— 这是 Play 的机制，不是代码 bug。

- **创建商品**：Play Console → 你的应用 → **Monetize** → **Products → In-app products** → 创建 **managed product**：
  - **Product ID = `pro_unlock`**（与代码完全一致，差一字查不到）；
  - 标题 **Pro Unlock**（中文 `Pro 解锁`）；
  - 价格 **$1.99**（USD 档，区域自动换算）；
  - 状态 **Active**（激活）。
- **上传内部测试轨道**：Monetize → Releases → **Internal testing** 上传至少一次 AAB/APK（debug 签名即可，包名须一致），并把测试账号加进该轨道的测试人员名单。
- **License testing**：Play Console → **Setup → License testing** 加入你的 Gmail（否则沙盒购买走不通；license tester 购买**不真实扣费**）。
- **《Paid apps / 商家协议》必须已签**（未签 → `queryProductDetails` 返回空）。
- 设备：Android **模拟器多数返回 `notFound`**（Play 商店服务不可用 / 未登录 Google 账号），**Android 必须真机测**（或装有 Play Store 且登录了 license tester 的模拟器）。

> 验收口径与 iOS 一致：`hasProduct=true`、显示 `$1.99`、ID 一致 → 点 Upgrade Now → Google Play 支付对话框 → 完成 → 会员卡点亮。

---

## 4. 验证状态（截至 2026-09-06）

> **代码层面对 iOS / Android 双端均已具备**：`purchase_page.dart` 调 `membershipProvider.buy()`，
> 内部走跨平台 `InAppPurchase.instance` —— iOS 自动 StoreKit 2、Android 自动 Play Billing。
> 差别只在商店后台配置与测试方式（见 §5）。

| 路径 | 内容 | 状态 |
|---|---|---|
| **A. 本机静态** | `flutter pub get` / `flutter gen-l10n` / `flutter analyze` / `bash scripts/iapsmoke.sh --check-config` | ✅ `--check-config` 4 项全 OK（脚本误报已修，见 §7）；其余待用户本机 `flutter analyze` |
| **B. 模拟器离线（Xcode + 本地 StoreKit）** | `⌘R` → Profile → Upgrade Now → 系统支付 sheet → 完成 | ✅ 用户反馈**无 `SKError` 报错**；会员卡点亮待最终确认 |
| **C. 真机沙盒（真实 App Store Connect 商品）** | 真机登 `zhang13655179933@gmail.com` 沙盒账号 → `./scripts/iapsmoke.sh --buy --device <id>` | ⏳ 待真机就绪 |
| **D. 真机沙盒（真实 Play Console 商品）** | 真机装内部测试轨道包 + license tester → 同款 smoke/buy 链路 | ⏳ 待 Play Console 建商品 + 内部测试轨道（见 §3.2） |

- 控制台那条 `flutterSemanticsScrollView implements focusItemsInRect:` 是 **Flutter iOS 无障碍框架的无害信息日志，与 IAP 无关**，忽略即可。
- 实现已从旧版「底部 sheet（`ios_purchase_sheet.dart` + `showIosPurchaseSheet`）」演进为**独立购买页 `purchase_page.dart` + `ProfileRoute.purchase`**（`_onUpgrade` 改为 `context.push`）。本 handoff 已同步更新。

---

## 5. 联调操作步骤（三条路径）

### A. 本机立即可做（无需设备）
```bash
cd /Users/zhangchunhua/project_knot/repo/knot/tool_box
flutter pub get
flutter gen-l10n                 # 生成 vipSheet* 等新增词条 getter
flutter analyze                 # 全量零 issue 才过关
flutter analyze scripts/smoke_iap.dart   # 单独验 IAP 烟雾脚本 API 签名
```

### B. 模拟器离线（Xcode 本地 StoreKit，不真扣费、不需沙盒账号）
限制：只在**从 Xcode 直接 ⌘R** 时生效，`flutter run` 不吃 scheme 配置；验证的是本地商品，**不连真实 App Store Connect 商品**。
1. `open ios/Runner.xcworkspace`（注意是 workspace 不是 xcodeproj）。
2. 设备栏选 iOS 模拟器。
3. `⌘R` 运行 → Profile → Upgrade Now → 确认 → 系统支付 sheet（本地 Pro Unlock）→ 完成（离线）。
4. 重测：`Debug → StoreKit → Manage Transactions` 删交易，或重置 App。
- 配置文件已生成：`ios/StoreKitConfig.storekit`（Non-Consumable / `pro_unlock` / Pro Unlock / 1.99 / en+zh），scheme 已注入引用。

### C. 真机沙盒（最贴近生产，用已建账号）
前提：一台真机 + Mac，USB/网络连上，真机开**开发者模式**。
1. 真机设置 → App Store → 沙盒账户 → 登录 `zhang13655179933@gmail.com`（**主 Apple ID 别退**）。
2. `flutter devices` 拿真机 id。
3. 先 smoke 验商品：`bash scripts/iapsmoke.sh --device <id>` → 确认 `hasProduct=true`、价格 `$1.99`、ID 一致。
4. 再真购买：`bash scripts/iapsmoke.sh --buy --device <id>` → 120 秒内用沙盒账号在系统支付页点完成，脚本自动 `completePurchase`。
5. 成功：会员卡点亮（`owned=true`），不会反复弹。

### D. 真机沙盒（Android / Google Play，最贴近生产）
前提：一台 Android 真机（或装了 Play Store 且登录 license tester 的模拟器）+ Mac/PC 已 `flutter devices` 识别。
1. **Play Console 建商品 + 内部测试轨道**（见 §3.2）：上传包名 `uk.aknot.toolbox` 的 AAB 到 Internal testing，并把测试账号加入该轨道 + License testing。
2. 真机从**内部测试轨道链接**安装 App（或用同一包名 `flutter run` 装的 debug 包；关键是包名一致且已在 Play 登记）。
3. 真机登录 **license tester 的 Google 账号**（设置 → Google → 支付资料 / 沙盒）。
4. `flutter devices` 拿 Android 设备 id。
5. 先 smoke 验商品：`bash scripts/iapsmoke.sh --device <id>` → 确认 `hasProduct=true`、价格 `$1.99`、ID 一致（否则多因未上传内部轨道 / 未加 license tester）。
6. 再真购买：`bash scripts/iapsmoke.sh --buy --device <id>` → 在 Google Play 支付对话框点完成，**license tester 不真实扣费**，脚本自动 `completePurchase`（acknowledge）。
7. 成功：会员卡点亮（`owned=true`）；重装后 BillingClient 建连自动恢复，无需手动恢复。

> **模拟器不能登录沙盒、不能完成真实沙盒购买**（Apple 沙盒服务器需物理设备）。模拟器只能走 B 路径的本地 StoreKit。
> **Android 模拟器**多因无 Play 商店服务返回 `notFound`；Play Billing 也要求 `minSdk ≥ 24`（本工程 `flutter.minSdkVersion` 默认即 24，已满足 Play Billing Library 8）。

---

## 6. 关键约定与踩坑（★抽取技能时必须固化）

1. **★ IAP 不是 entitlement（Apple TN3186 / DTS 官方口径）**
   - `com.apple.developer.in-app-purchase(s)` 是 Apple 官方「**常见幻觉键**」之一；写在 entitlements 里会让 Xcode 自动签名失败（profile 查不到该 key）。
   - 内购是 **App Service**，只要 App ID 是**显式 App ID**（非通配符）就自动具备，服务端开通即可。
   - 因此 `ios/Runner/RunnerDebug.entitlements` **只保留 `com.apple.developer.applesignin`**，不要加任何 IAP key。
   - ⚠️ **`scripts/iapsmoke.sh` 的 `--check-config` 第 3 项仍在 grep `in-app-purchases`**，这是**已知 false-positive**：正确配置下该 key 本就不该存在，脚本会误报 WARN。抽取技能前**必须删除该断言**（见 §7）。

2. **`completePurchase` 双端都必须调**
   - Android 3 天内不 `acknowledge` 会**自动退款**；
   - iOS 不 `finish` 会导致交易反复重投、再次购买同商品立即失败（重复交易）。
   - 代码已在 `_onPurchaseUpdated` 对 `pd.pendingCompletePurchase` 统一处理。

3. **iOS 恢复购买的双重语义**
   - `restorePurchases()`（StoreKit 2）= 读 `Transaction.currentEntitlements`，**本机、不弹框、不联网** → 启动静默调用安全，覆盖「重装后取回会员」。
   - `AppStore.sync()`（需 `in_app_purchase_storekit`）= **弹 Apple ID 登录框、从服务器刷新** → 必须由用户显式发起（点「恢复购买」），绝不在启动时调。

4. **模拟器 vs 真机**
   - 模拟器只能走 Xcode 本地 StoreKit（路径 B），无法真实沙盒购买；
   - `flutter run` 不吃 Xcode scheme 的 StoreKit 配置，离线测试必须 Xcode ⌘R。

5. **商品 ID 是死约定**：`kMemberProductId` 改动需同步改两端商店后台；查不到商品时 `buy()` 返回 `productMissing`，UI 提示「商品未上架」，不崩溃。

6. **价格/名称优先取商店本地化值**：`price`/`title` 直接来自 `ProductDetails`，App 不自算汇率；商店未配置时弹窗兜底显示 `Pro Unlock`/`$1.99`（由 l10n 提供）。

7. **购买是异步的**：`buy()` 返回 `started` 只代表支付页拉起，成交与否等 `purchaseStream` 回送；`vipActivated` 埋点放在流回调里而非 `buy()` 之后，避免把「拉起支付页」算成「成交」。

---

## 7. 已知问题 / 待办（抽取技能前需处理）

- [x] **`scripts/iapsmoke.sh --check-config` 第 3 项误报已修复**：原断言「grep 幻觉键 `in-app-purchases` 应存在」是基于已被否定的「加 IAP key」旧认知，对正确配置永远误报。已改为**反向断言**——命中该幻觉键才 FAIL（提示删掉），正确配置下通过。
- [x] **实现已从 `ios_purchase_sheet.dart` 演进为 `purchase_page.dart`**：本 handoff 已同步更新（§2 / §2.1 / §4 / §5）。
- [x] **Android 代码路径已具备**：`purchase_page` + 跨平台 `InAppPurchase.instance`，Play Billing 走 `buyNonConsumable`/`completePurchase`(=acknowledge)。`minSdk=24` 满足 Play Billing 8。
- [ ] 用户最终确认**模拟器购买后会员卡是否点亮**（B 路径收尾证据）。
- [ ] 路径 C 真机沙盒实测（`zhang13655179933@gmail.com`），验证真实 App Store Connect 商品 ID/名称/价格一致。
- [x] **路径 D 之「Play Console 建商品」**（2026-09-12 已完成）：用户已在 Play Console 建好 managed product，ID = `pro_unlock`，**与 iOS 完全一致** → 代码侧 `kMemberProductId` 零改动（两端共用同一常量，`AndroidManifest` 的 BILLING 权限、`minSdk=24`、applicationId 均已就位）。
- [ ] 路径 D 之「联调前置 + 真机实测」：内部测试轨道上传 + License tester 加 Gmail + 商家协议已签，再走真机 smoke/buy（Android 模拟器多 notFound）。
- [ ] Release 配置核查：`RunnerRelease.entitlements` 仅含 applesignin 即可，无需 IAP key；上架前确认《Paid Apps 协议》已签。

---

## 8. 后续计划：抽取为可复用技能（Skill）

**用户意图（2026-09-06 提出）**：将「Apple IAP + Google Play Billing 买断制会员」整套实现沉淀为一个可复用 **Skill**，供其他 Flutter 工程（如 knot_phone）直接套用。

技能建议命名：`flutter-iap-lifetime`（或归入现有 `flutter-dev` 体系）。

技能应封装：
1. **Provider 骨架**：`membership_provider.dart` 模板（含 `kProductId`、StoreKit 2 静默恢复、`AppStore.sync()` 用户触发、`completePurchase` 双端兜底、`isMemberProvider` 合并判定）。
2. **购买确认 sheet 组件**：`ios_purchase_sheet.dart`（主题配色、SingleChildScrollView 防溢出、返回 bool）。
3. **l10n 词条清单**：en/zh 双语 key 集合。
4. **pubspec 依赖**：`in_app_purchase` + `in_app_purchase_storekit`；AndroidManifest BILLING 权限。
5. **★ 平台配置真相**：**IAP 不是 entitlement**，显式 App ID 即具备；不写幻觉键（写入反而签名失败）—— 这是最易踩坑、最该写进 skill 的硬约束。
6. **模拟器联调方案**：生成 `StoreKitConfig.storekit` + 注入 scheme，Xcode ⌘R 离线测试（不含真账户）。
7. **烟雾脚本**：`smoke_iap.dart` + `iapsmoke.sh`（`--check-config` 须修正 §7 的 false-positive）。
8. **验证清单**：本机 analyze → 模拟器 UI → 真机沙盒三步；踩坑速查表。

> 抽取前务必先解决 §7 的脚本 false-positive 与「会员卡点亮」确认，避免把错误认知固化进技能。

---

## 9. 方案 B 设计稿：购买即注册 + OAuth-only 登录（2026-09-10）

> 状态：**实施中（Phase 1）**。本节是 §1 所述「方案 A → 方案 B」的落地设计，依据 2026-09-10
> 与用户确认的口径：**购买 Pro 的同时引导注册账号；登录入口只保留 Apple / Google**。
> 四个决策点已拍板（见 §9.9 末尾「拍板结论」）。

### 9.1 目标口径（三条硬约束）

1. **购买零门槛不变**：不登录也能买（权益绑商店账号，方案 A 语义保留）——转化率与审核安全。
2. **购买成功 → 引导一键注册**：弹「同步会员到新设备」对话框，用户点 Apple / Google 授权即完成
   注册（OAuth 首次授权自动建号，注册=登录合一），随后把买断权益**上云绑定**到该账号。
3. **登录入口收敛为 Apple + Google**：邮箱密码链路（注册/登录/忘记密码/重置/邮箱验证）退役。

### 9.2 现状资产盘点（本方案的三个地基，均已就绪）

| 资产 | 位置 | 状态 |
|---|---|---|
| Apple 登录 | `lib/feature/login/apple_sign_in.dart` | ✅ iOS/macOS 原生弹窗（nonce 机制完整）；其他平台 OAuth 浏览器回退 |
| Google 登录 | `lib/feature/login/google_sign_in_native.dart` | ✅ 原生流程（Android 账号选择器 / iOS 系统面板）；⚠️ `oauth_config.dart` 两个 Client ID 常量**仍为空**，上架硬前置 |
| 会员判定 | `membership_provider.dart` 的 `isMemberProvider` | ✅ 已是 `云端 user_profiles.is_member_active \|\| 本机 owned` 的合并结构，上云绑定后**无需改动**即生效 |
| 数据库写保护 | `users_before_insert/update` 触发器 | ✅ `is_member / member_expire_at` 客户端写入直接 `42501`；**service_role 可写**（doc/database.md §会员字段一律由服务端改） |
| OAuth 自动建行 | `auth.users` → `on_auth_user_created` → `handle_new_user()` | ✅ OAuth 建号后 `public.users` 自动补行，bind 无需处理「行不存在」 |
| Edge Function 先例 | `supabase/functions/track-event` | ✅ 已有部署模式（service_role 只在服务端 env，不落客户端） |

**结论：本方案是「接线」工作，不是从零造轮子。**

### 9.3 总体流程（四条路径）

```
路径① 未登录购买（主路径）
  purchase_page → buy() → purchaseStream=purchased → owned=true（本机权益立即点亮）
  → currentUserProvider==null → 弹「同步会员」对话框 [Sign in with Apple] [Sign in with Google] [暂不]
  → 用户授权 → OAuth 建号 → onAuthStateChange 登录成功
  → 调 Edge Function bind-member → users.is_member=true, member_expire_at=null
  → user_profiles.is_member_active=true → isMemberProvider 双通道成立

路径② 已登录购买
  purchased → owned=true → 静默直接调 bind-member（无弹框）

路径③ 换设备 / 重装（双通道恢复，互为兜底）
  a. 登录账号 → is_member_active=true → 会员点亮（不依赖商店恢复）
  b. 不登录 → iOS 启动静默读 currentEntitlements / Android 冷启动自动推送 → owned=true

路径④ 进页拒绝同步 / 事后想同步
  profile 页常驻入口：「同步会员到账号」（仅 已登录 && is_member_active=false && owned=true 时显示）
```

### 9.4 客户端改动清单（具体到文件）

| # | 文件 | 改动 |
|---|---|---|
| 1 | `lib/common/auth/member_bind_service.dart`（**新建**） | 封装 bind 调用：`Supabase.instance.client.functions.invoke('bind-member')`（自动携带当前 session JWT）；返回 `MemberBindResult{ok, reason}`；匿名态直接拒绝并返回 needLogin，不发起请求 |
| 2 | `membership_provider.dart` | `MembershipState` 增加 `needsSyncPrompt` 字段；`_onPurchaseUpdated` 的 purchased 分支：已登录→`unawaited(MemberBindService.bind())`；未登录→置 `needsSyncPrompt=true`。restored 分支**不弹**（避免每次冷启动打扰），只在 profile 手动入口覆盖 |
| 3 | `purchase_page.dart` | `ref.listen(membershipProvider)` 捕捉 `needsSyncPrompt` → 弹同步对话框（见 #4）；bind 成功 SnackBar + `ref.invalidate(userProfileProvider)` |
| 4 | `lib/feature/profile/widget/sync_member_dialog.dart`（**新建**） | 「同步会员到新设备」对话框：文案 + Apple / Google 两按钮（直接复用 `AppleSignIn.signIn()` / `NativeGoogleSignIn.signInAndExchange()`，取消不算错误）+「暂不」；登录成功的收尾由全局 `onAuthStateChange` 链路统一处理（与登录页同构），回调里触发 bind |
| 5 | `profile_page.dart` | 会员卡区加「同步会员到账号」行（条件：已登录 && !isMemberActive && owned）；点击→调 bind → 成功刷新资料 |
| 6 | `login.dart` | 删邮箱表单 + `signInWithPassword` + 「注册 / 忘记密码」跳转；页面按平台**只显示一个**按钮：iOS/macOS → Apple，Android → Google（合规说明见 9.7） |
| 7 | 路由表（`route_login` 等） | 移除 `/register` `/forgot-password` `/reset-password` `/verify-email` 四条路由及对应页面文件；`passwordRecoveryPending` 全局标记与 `reset-callback` 深链分支一并删除 |
| 8 | `login/page/` 下 4 个邮箱页面 | 删除（register/forgot/reset/verify）；`password_recovery_state.dart` 一并清理 |
| 9 | i18n（**5 处**手动同步） | 新增 key：`syncMemberTitle` / `syncMemberBody` / `syncMemberApple` / `syncMemberGoogle` / `syncMemberLater` / `syncMemberDone` / `syncMemberFailed` / `syncMemberAction`（profile 入口名）；删除邮箱类 key 可暂留（无害，减少 arb 改动面） |
| 10 | 埋点 | 新事件 `vip_bind`：`source=purchase_prompt\|auto\|profile\|login_after_buy`，`platform`，结果 `ok/fail/need_login`；登记 `doc/track.md`。购买引导弹框曝光单独记 `vip_sync_prompt_show`（漏斗：曝光→授权→bind 成功） |

### 9.5 服务端改动（Supabase）

#### Edge Function `supabase/functions/bind-member/index.ts`（新建，参照 track-event 部署模式）

```ts
// 伪代码骨架（实施时按 track-event 的鉴权/日志模式补全）
export default async (req: Request) => {
  // 1) 取调用者 JWT → Supabase.auth.getUser() → 拒绝匿名（401）
  // 2) 幂等写库（service_role client，触发器放行 service_role）：
  //    update users set is_member = true, member_expire_at = null
  //    where id = <uid>          -- 买断制：expire 置 null（不限期）
  //    行不存在时（handle_new_user 理论上保证存在）→ 先 insert 兜底再 update
  // 3) Phase 2 扩展点：在第 2 步前先校验商店收据（见 9.8），校验失败拒绝写库
  // 4) 返回 { ok: true } / 错误码；日志结构与 track-event 一致
}
```

要点：
- **幂等**：重复调用无副作用（`set is_member=true` 二次执行结果不变）；防刷不设限流（写操作本身无收益）。
- `SUPABASE_SERVICE_ROLE_KEY` 只存在于 Edge Function 环境变量（沙箱内验证密钥相关操作按既有约定由用户本机跑）。
- 退款撤销**不在 Phase 1**：买断 + 1.99 定价下，退款用户云端会员残留属可接受损耗（用户主动申请退款本就少见；Phase 2 收据校验可一并覆盖撤销）。

#### 数据库：零改动

`is_member / member_expire_at` 列、触发器、`user_profiles` 视图、`handle_new_user` 全部沿用现状——
设计上刻意**复用**这套已验证的写保护链路，不新增表。理由：
- bind 写入路径与 database.md §「开通会员只能由 service_role / 支付回调执行」的既有约定完全一致；
- `isMemberProvider` 读 `user_profiles.is_member_active`，上云后自动生效，客户端判定层零改动。

#### 控制台配置

- Authentication → Providers → **Email 关闭**（建议先「UI 隐藏 + provider 保留」观察一个版本，再正式关闭；见 9.9 决策点）。
- SMTP / OTP 模板 / `mailer_otp_length` 等整套邮件设施随邮箱链路一并退役（不再有发信场景）。

### 9.6 安全边界（诚实声明）

- **Phase 1 的 bind 信任客户端声明**：已登录用户伪造一次 `bind-member` 调用即可点亮「云会员」。
  风险评估：与方案 A 等价——伪造者不登录也有本机权益（owned），上云绑定**不是提权**，只是
  把同一权益多了一条恢复通道；1.99 买断工具类 App 的既定取舍不变。真正防线在 Phase 2 收据校验。
- `bind-member` 要求登录态 JWT（匿名 401）；service_role key 不落客户端。
- 不用 `raw_user_meta_data` 做任何授权判定（会员判定只读 `public.users` 业务列）。

### 9.7 合规与前置条件（控制台/商店侧，代码之外）

1. **Google Client ID（硬前置，当前为空）**：Google Cloud Console 建 iOS 类型 + Web 类型两个
   OAuth client（绑定包名 `uk.aknot.toolbox`）→ 填 `oauth_config.dart` 的
   `kGoogleIosClientId` / `kGoogleWebClientId`，iOS 侧确认 `GoogleService-Info.plist` 的 CLIENT_ID。
   两个 ID 不配齐，Google 原生登录拿不到 accessToken，本方案主路径直接不可用。
2. **Supabase Apple provider**：Client IDs 含 App ID（bundle id）——原生路径要求（现状已按此配置）。
3. **App Store Guideline 4.8**：只有在**同时**提供了 Google 等其他第三方登录时，
   才强制要求一并提供 Sign in with Apple。本方案按平台二选一（iOS 只给 Apple、
   Android 只给 Google），两边都不存在「给了第三方却不给 Apple」的情形，天然合规。
   ⚠️ 若哪天要在 iOS 上同时放上 Google 按钮，Apple 按钮必须保留且视觉权重不低于 Google。
4. **Edge Function 部署**：`bind-member` 推到 ref `nfoishlluynelazgwduc`，secrets 配置沿用 track-event 模式。

### 9.8 分期实施

- **Phase 1（本方案，一次落地）**：9.4 全部客户端改动 + `bind-member` Edge Function +
  埋点/文档（track.md / database.md / 本节标「已实施」）。
- **Phase 2（可选后置，防伪造升级）**：
  - iOS：客户端传 `transactionId`，Edge 用 App Store Server API
    （`GET /inApps/v1/transactions/{transactionId}`，In-App Purchase 私钥签 ES256 JWT）核验；
  - Android：客户端传 `purchaseToken`，Edge 用 Play Developer API
    （`purchases.products.get(packageName, productId, token)`）核验；
  - 核验通过才写库；顺带可处理退款撤销（定期拉 revoked 交易）与 `member_source` 列（store|manual）。
  - 触发条件：出现异常伪造流量 / 上量后再做；`bind-member` 的校验位留好扩展点即可。

### 9.9 需用户拍板的决策点

| # | 决策 | 建议 |
|---|---|---|
| 1 | 邮箱链路是「UI 隐藏 + provider 保留」还是「彻底关闭」 | 先隐藏观察一个版本（老邮箱账号还能登录），再关 provider；权益绑商店账号，老账号无购买记录、损失≈0 |
| 2 | Android 是否显示 Apple 登录按钮（走 Chrome Tab OAuth 回退，体验一般） | Android 只显示 Google；iOS/macOS 只显示 Apple——每平台只给最顺的一条路（**最终口径**） |
| 3 | Phase 1 接受「bind 信任端侧」 | 接受（与方案 A 同级风险，非提权）；上量后再上 Phase 2 收据校验 |
| 4 | 同步弹框出现在购买成功后还是支付确认前 | 购买成功后（先给用户「买到了」的确定性，再谈同步；放确认前会压转化） |

**拍板结论（2026-09-10，用户确认）**：
1. **邮箱链路 → UI 隐藏 + provider 保留**（Supabase 控制台 Email provider 不关，老账号数据不动；App 端移除邮箱登录/注册/忘记密码/验证入口）。
2. **每平台只给一个按钮**：Android → 只给 Google；**iOS/macOS → 只给 Apple**
   （2026-09-10 追加确认：苹果设备只显示「Apple 一键注册」）。
   只提供 Apple 时不触发 App Store 4.8（该条仅在提供了其他第三方登录时才强制要求给 Apple），
   因此不存在审核风险；两条都是各自平台的系统级原生面板，体验最佳。
3. **接受 Phase 1 信任端侧**（bind 不做服务端收据校验，风险与方案 A 同级）。
4. **同步弹框 → 购买成功后**弹出。

### 9.10 验证清单（实施完成口径）

1. `dart analyze lib` 零 issue；
2. 未登录购买（沙盒）→ 弹同步框 → Apple 授权 → `user_profiles.is_member_active=true`（控制台 SQL 核对）；
3. 已登录购买 → 无弹框，库内 `is_member=true`；
4. 「暂不」后本机权益照常点亮，profile 出现手动同步入口；
5. 换设备登录（不恢复购买）→ 会员点亮；
6. 登录页无邮箱入口、四条邮箱路由 404 兜底不崩；
7. 埋点 `vip_bind` / `vip_sync_prompt_show` 上报正确（track.md 登记）。

### 9.11 实施进度（2026-09-10 Phase 1）

**已完成（客户端全部 + 服务端代码）**

| # | 项 | 落地 |
|---|---|---|
| 1 | `bind-member` Edge Function | `supabase/functions/bind-member/index.ts`（JWT 鉴权 + service_role 幂等写库）。✅ **2026-09-10 已部署**到 ref `nfoishlluynelazgwduc`（`--no-verify-jwt`，自行校验用户 token） |
| 2 | `MemberBindService` | `lib/common/auth/member_bind_service.dart`（含 `source` 埋点维度、三态返回） |
| 3 | 同步对话框 | `lib/feature/profile/widget/sync_member_dialog.dart` |
| 4 | 购买绑定逻辑 | `membership_provider.dart` 加 `needsSyncPrompt`；purchased 分支按登录态分静默 bind / 置位弹框 |
| 5 | 购买页弹框 | `purchase_page.dart` 监听 `needsSyncPrompt` → 弹框 → 刷新资料 → 返回 |
| 6 | profile 手动入口 | `profile_page.dart`「同步会员到账号」行（已登录 && owned && 云端未生效） |
| 7 | 登录页收敛 | `login.dart` 删邮箱表单，按平台二选一：iOS/macOS 只显示 Apple，其余只显示 Google（同步会员对话框同口径） |
| 8 | 邮箱链路删除 | 删 4 个页面 + `password_recovery_state.dart` + 4 条路由 + `reset-callback` 深链分支 + `passwordResetRedirectUrl` 常量 |
| 9 | i18n | 新增 8 个 `syncMember*` key（5 处已同步，arb JSON 校验通过） |
| 10 | 埋点 | `vip_bind` / `vip_sync_prompt_show` 已入 `track_events.dart` 并在 `doc/track.md` §8 登记 |

**校验**：`dart analyze lib` 零 issue；`flutter build bundle --debug` 通过；两个 arb 文件 JSON 合法。

**待办（非代码）**

1. ~~部署 Edge Function~~ ✅ 已完成，见下方部署记录；
2. ⚠️ **补齐 Google 两个 Client ID**（`oauth_config.dart` 的 `kGoogleIosClientId` / `kGoogleWebClientId`）——不配齐主路径不可用；
3. Supabase 控制台 Email provider：**保持开启**（决策 1：隐藏 UI、保留 provider）；Redirect URLs 确认已含 `uk.aknot.toolbox://**`；
4. 真机沙盒跑 9.10 的验证清单（尤其 2/3/5 三条跨设备路径）。

### 9.12 部署记录与命令（2026-09-10 首次部署）

**前置**：项目已 link（`supabase/.temp/project-ref` = `nfoishlluynelazgwduc`），
CLI 在 `/usr/local/bin/supabase`（v2.116.0），access token 存于 `local/env/dev.json` 的
`SUPABASE_ACCESS_TOKEN`。

**部署命令**（在 `tool_box/` 根目录执行）：

```bash
mkdir -p /tmp/supabase_home
export HOME=/tmp/supabase_home      # 关键：CLI 要写 $HOME/.supabase/telemetry.json，
                                    # 用真实 HOME 在沙箱/受限环境会 EPERM 直接崩
set -a; export SUPABASE_ACCESS_TOKEN="$(python3 -c "import json;print(json.load(open('local/env/dev.json')).get('SUPABASE_ACCESS_TOKEN',''))")"; set +a   # 勿 echo
supabase functions deploy bind-member --project-ref nfoishlluynelazgwduc --no-verify-jwt
```

- `--no-verify-jwt`：跳过网关默认 JWT 校验，改由函数内 `getUser()` 自行解析身份，
  便于对「未带 token / token 无效」给出可区分的业务错误码。
- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` 由平台自动注入函数环境，**不需要**手动传 secrets。
- 警告 `WARNING: Docker is not running` 可忽略——本次部署是远程上传，不需要本地 Docker。

**冒烟验证**（已实测）：

| 请求 | 期望 | 实测 |
|---|---|---|
| 只带 `apikey`、无 Authorization | 401 `{"error":"missing_user_token"}` | ✅ 一致 |
| 带伪造 Bearer token | 401 `{"error":"invalid_user_token", ...}` | ✅ 一致 |

两条都返回的是**我们自己代码里的错误码**，说明函数确实在运行（而非被网关挡在门外）。
真实绑定路径（带合法用户 token → 写库 → `{"ok":true}`）需真机登录后验证，见 §9.10。


---

## §10 Android「恢复购买查不到」——用户坚称已付费的排查清单

> 场景（2026-10-01 真机）：用 `zhang13655179933@gmail.com` 购买过 `pro_unlock`，
> 点「恢复购买」却提示「未找到可恢复的购买记录」，且期望系统弹出本机 Gmail 账号列表。
> 该账号云端 `public.users.is_member=true` → 按设计应直接短路成「你已是 Pro 会员」，
> 所以「提示没买过」本身就已经是判定错误（见 §10.3）。

### §10.1 先讲清口径（这是最常见的误解，务必先对齐）

- **Google Play 的恢复身份 = 这台设备当前登录的 Google 账号 + 包名**，
  与 App 内 Supabase 登录的邮箱**完全无关**。
- 系统**永远不会**弹出账号选择器让你选「用哪个 Gmail 恢复」——
  Billing API 默默使用系统账号认的那个，选不了。用户抱怨「没弹出让我选」时，
  先说明这个事实，再谈排查，否则会一直以为是被弹窗吞掉了。
- 同理，**iOS 的恢复也是设备绑定的**（Apple ID + 设备），不跨设备。
  「换机恢复」的唯一正解是**权益上云**（`bind-member` → `users.is_member`），
  不是 Restore。

### §10.2 查不到的四类根因（按概率排序）

| # | 根因 | 核查位置 | 判定 |
|---|---|---|---|
| 1 | **测试购买**：在 internal/closed track 用测试卡、licensing 测试、Play Console 沙盒买的 | Play Console → 交易/订单，搜该邮箱 | 测试订单**永远**不会出现在 `queryPurchases`，恢复必然为空，属正常 |
| 2 | **订单已退款/已取消**：App 未及时 `acknowledgePurchase`，Google 3 天未确认自动退款 | Play Console → 订单状态 / 商品 `pro_unlock` 的销售与退款报表 | 状态显示「已退款」即解释了恢复为空；需在 `pendingCompletePurchase` 时立刻 complete（代码已做） |
| 3 | **账号/设备不一致**：购买发生在另一台设备、另一个 Google 账号、或设备的多用户 profile | 手机 设置 → 账号，确认系统 Google 账号 = 购买时的账号 | 换设备/换号后 Restore 查不到是正常的，改用云端（`users.is_member`） |
| 4 | **商品未激活**：`pro_unlock` 在 Play Console 不是 active（未上架/未开启） | Play Console → 商品 → 应用内商品 → `pro_unlock` 状态 | 非 active 时正式包查不到，仅测试轨道安装的包能买 |

> 只有「Google 确实返回了这笔购买、而我们没认出来」才算**代码 bug**，
> 这一类才需要看 §10.3 的日志。
> 注意：Google 侧还有**已 consume 的消耗型**不返回，我们用的是 non-consumable，不受此限。

### §10.3 代码侧改动（`dart analyze lib` 零 issue）

`lib/feature/profile/provider/membership_provider.dart`：

1. **`_silentRestore` 超时 800ms → 2500ms**。
   `restorePurchases()` 底层是 `BillingClient.queryPurchases()`（见
   `in_app_purchase_android-0.5.3/lib/src/in_app_purchase_android_platform_addition.dart:67`，
   同时查 `ProductType.inapp` 与 `subs`），结果**经 purchaseStream 异步推送**、不是返回值；
   且要先建连 BillingClient（`runWithClient` 里的 `_readyFuture`）。
   → 旧 800ms 在弱网/冷启动时会**抢在商店返回之前**判成「未找到购买记录」，
   把真实付费说成没买过。返回值也改成 `Future<bool>`，明确「本次是否确认命中」。
2. **新增 `_recheckRestore()`**：主查询判空后再问一次（连接已建，通常毫秒级返回）。
   BillingClient 首次查询掉线但不代表没买过，多问一次几乎零成本。
   `restore()` 的 Android 分支在首次未命中时调用。
3. **逐笔商店事件日志**：`_onPurchaseUpdated` 打印
   `sku / status / pendingComplete / verifySource`——这是「商店到底推了什么」的唯一现场证据。
   ⚠️ 注意 `in_app_purchase 3.3.0` 的 `PurchaseVerificationData` 只有
   `source`（**String，没有 `.name` 可用**）/ `data` / `serverVerificationData` / `signature`，
   没有 `status` getter，写错 analyzer 直接报 `undefined_getter`。
4. **恢复结论落定后补上 `vip_restore_result` 埋点**（该事件早就定义却从没上报过），
   参数 `hit / store / product / platform` 四件套，直接定位是账号问题、商品未上架还是网络问题。

### §10.4 现场抓取（定位「是不是代码 bug」的唯一手段）

```bash
# 真机装 debug 包 → Profile → 恢复购买 → 然后：
$SDK/platform-tools/adb logcat -d | grep 'Member' | tail -40
```

关键看三行：

- `[Member] 商店事件: ...` —— Google 到底推了没推、推的 sku 对不对；
- `[Member] 恢复查询结束: owned=..., store=..., hasProduct=..., 耗时=...ms` —— 商店通不通、商品有没有；
- `[Member] 复查结束: owned=...` —— 二次查询是否命中。

判读：

| 日志表现 | 结论 |
|---|---|
| 有 `商店事件` 且 `sku=pro_unlock` | 商店认账，是 App 解析/状态机问题 → 看源码 |
| 无 `商店事件`、`store=false` | 商店不可用（未登录/断网/受限）→ 走 §10.2 #3 |
| 无 `商店事件`、`hasProduct=false` | 商品未上架 → 走 §10.2 #4 |
| 两轮都没有 `商店事件` | Google 侧就没有这笔活跃购买 → 回 §10.2 #1/#2 查订单 |

### §10.5 给开发者的回归建议

- Android 真机测购买时，务必用**正式包（Play 正式轨道 / 内部应用共享的 release 包）**
  且商品为 active，测试卡产生的订单不能当作真实恢复路径的验证依据。
- 每次 `completePurchase` 都要在 `pendingCompletePurchase == true` 时立刻调用，
  Google 侧 3 天未确认会**自动退款**（代码已在分支末尾处理）。
