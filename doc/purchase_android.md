# Google Play 内购（买断制会员）联调文档

> 工程：`tool_box`（包名 `uk.aknot.toolbox`）
> 功能：1.99 美元**买断制终身会员**（managed product / non-consumable）
> 关联文档：`doc/purchase_handoff.md`（iOS + Android 总览）；本文件聚焦 **Android / Google Play Billing** 一条线。
> 状态：代码链路完成（跨平台 provider 自动走 Play Billing）；**Play Console 后台 + 真机实测待用户完成**

---

## 0. 一句话结论

**Android 端不需要写任何新的购买代码**——`membership_provider.dart` 用跨平台 `InAppPurchase.instance`，在 Android 上自动映射为 Google Play Billing。`purchase_page.dart` 点「Upgrade Now」→ `membershipProvider.buy()` → `buyNonConsumable`，即 Google Play 支付对话框。

你（用户）要做的只有两件事：**① 在 Play Console 建商品 + 上传内部测试轨道；② 真机跑一次购买验证**。其余步骤沙箱/无设备环境跑不了。

---

## 0.1 需要登录的网址（Play Console）

联调需要在浏览器登录以下后台。Play Console 每个应用都有独立深链，需把 `{appId}` 换成你应用的实际 ID（在 Play Console 应用设置页的地址栏即可复制，形如 `app/xxxxxxxxxx`）。所有链接均需用**开发者 Gmail** 登录。

| 用途 | 网址 | 对应步骤 |
|---|---|---|
| **Play Console 主站登录** | `https://play.google.com/console/` | 一切后台配置入口 |
| 开发者账号注册（若还没有） | `https://play.google.com/console/signup` | 一次性 $25 注册费，发布者账号关联 `uk.aknot.toolbox` |
| Monetize → In-app products | `https://play.google.com/console/app/{appId}/monetize/products` | §3.1 建商品 |
| Monetize → Releases → Internal testing | `https://play.google.com/console/app/{appId}/releases/internal` | §3.2 上传内部测试轨道 |
| Setup → License testing | `https://play.google.com/console/app/{appId}/setup/licensing` | §3.3 加沙盒账号 |
| Setup → 付款资料 / 协议 | `https://play.google.com/console/app/{appId}/setup/developer-payment` | §3.4 签《商家协议》 |

> 若已登录 Play Console，直接把应用深链里的 `{appId}` 替换为地址栏里的真实值即可跳到对应页面，无需层层点菜单。

---

## 1. 代码现状（已具备，无需改动）

| 文件 | 关键位置 | Android 侧作用 |
|---|---|---|
| `lib/feature/profile/provider/membership_provider.dart` | L60 | `kMemberProductId = 'pro_unlock'` —— 全工程唯一商品 ID 常量，两端商店须一致 |
| 同上 | L187-223 `_probeStore()` | `InAppPurchase.instance.isAvailable()` + `queryProductDetails()`；Android 上即 BillingClient 建连与商品查询 |
| 同上 | L247-268 `buy()` | `buyNonConsumable`；Android 上即拉起 Google Play 支付对话框 |
| 同上 | L340-351 `_onPurchaseUpdated()` | 命中 purchased/restored → `owned=true`；对所有 `pendingCompletePurchase` 调 `completePurchase`（**Android 即 `acknowledge`，漏调 3 天自动退款**） |
| 同上 | L233-241 `_syncOwnedOnStart()` | **Android 分支直接 return**（L234 仅 iOS 走静默恢复）；Android 靠 BillingClient 冷启动自动推活跃购买，无需主动调用 |
| `lib/feature/profile/page/purchase_page.dart` | — | Material 风格购买页，跟随主题色；点按钮直接 `membershipProvider.buy()` |
| `android/app/src/main/AndroidManifest.xml` | — | 已声明 `<uses-permission android:name="com.android.vending.BILLING" />` |
| `android/app/build.gradle.kts` | `flutter.minSdkVersion` | **无需改**：master SDK 默认 `minSdk = 24`，满足 Play Billing Library 8 的 `minSdk ≥ 24` |
| `scripts/smoke_iap.dart` / `iapsmoke.sh` | `--device` / `--buy` | 真机联调入口（见 §5） |

### 1.1 Android 与 iOS 在代码层的差异

| 维度 | Android（Play Billing） | iOS（StoreKit 2） |
|---|---|---|
| 调起支付 | `buyNonConsumable` → Google Play 对话框 | 同（自动映射 StoreKit） |
| 恢复购买 | `restorePurchases()` 幂等重查，**启动不主动调** | 启动静默 `restorePurchases()`（读本机缓存） |
| 完成交易 | `completePurchase` = `acknowledge`（**3 天不确认自动退款**） | `completePurchase` = `finish`（不 finish 会反复重投） |
| 冷启动恢复 | BillingClient 建连自动推活跃购买到 `purchaseStream` | 需 `restorePurchases()` 读 `currentEntitlements` |
| entitlement | **无此概念**（Android 不需要 entitlements 文件） | 内购是 App Service，显式 App ID 即具备，**不写幻觉键** |

---

## 2. 平台配置真相（★避免踩坑）

1. **Android 没有 entitlement 文件**——不要去类比 iOS 加任何 capability 声明；BILLING 权限已在 `AndroidManifest.xml` 声明即可，`in_app_purchase` 插件自动接入 Play Billing。
2. **`minSdk ≥ 24`**：本工程 `flutter.minSdkVersion` 默认 24（master SDK 实测），Play Billing Library 8 要求满足，`build.gradle.kts` 无需改。
3. **包名必须一致**：代码侧 APK/AAB 的 `applicationId` 须为 `uk.aknot.toolbox`，与 Play Console 应用一致；否则 Play 拒绝关联商品。
4. **价格/名称取商店值**：`price`/`title` 来自 `ProductDetails`，App 不自算汇率；商店未配置时兜底 `Pro Unlock`/`$1.99`（l10n 提供）。
5. **★ App 本身必须是 Free（免费下载）**：本工程商业模式是「免费 App + 内购会员 `$1.99`（`pro_unlock`）」。**App pricing（应用定价）必须设 Free**——`$1.99` 只是应用内商品，不是下载价。若 Play 在**下载安装时就先收 $1.99**，说明 App 被误设为 Paid 应用，去 **App content → Pricing & distribution → App pricing** 改回 Free 并重新发布一次即可（付费改免费单向不可逆，但本应用本就该免费，无影响）。

---

## 3. Play Console 后台配置（代码之外，必须做）

> ⚠️ **硬性前置（最容易被漏）**：Android 真机要能 `queryProductDetails` 查到商品并调起支付，
> App **必须已上传到 Play Console（测试轨道：内部测试 / 封闭式测试均可）** 且包名 `uk.aknot.toolbox` 一致。
> 仅 `flutter run` 装的 debug APK（未上传 Play）在真机上 `queryProductDetails` 会返回空——这是 Play 机制，不是代码 bug。

### 3.1 创建商品（In-app product）

路径：**Play Console → 你的应用 → Monetize → Products → In-app products → 创建 managed product**

- 登录网址：`https://play.google.com/console/app/{appId}/monetize/products`（把 `{appId}` 换成你应用真实 ID；已登录可直达）

- **Product ID = `pro_unlock`**（与代码 `kMemberProductId` 完全一致，差一字查不到）
- 标题：**Pro Unlock**（中文本地化 **Pro 解锁**）
- 描述：可选，建议填「解锁全部工具终身会员」
- 价格：**$1.99**（USD 档；各区域由 Play 自动换算）
- 状态：**Active（激活）**

### 3.2 上传封闭式测试轨道 + 添加测试人员 + opt-in 链接安装

> 本工程实际走的是 **封闭式测试（Closed testing）** 轨道 `tool_box_test`（发布版本 `1.0.0 internal`，2026-09-12 创建）。
> 以下以封闭式测试为准；若改用内部测试（Internal testing）轨道，步骤基本一致，仅入口为 `Releases → Internal testing`。

#### 3.2.1 发布到封闭式测试轨道
- 路径：**Play Console → 你的应用 → 测试 → 封闭式测试 → `tool_box_test`**
- 登录网址：`https://play.google.com/console/app/{appId}/releases/closedtesting`
- 上传 AAB（`flutter build appbundle --release` 产物，包名须 `uk.aknot.toolbox`）。
- 提交后轨道进入「待审核 / 生效」过程（通常几分钟到数小时），生效后才生成安装链接。

#### 3.2.2 添加测试人员（关键，否则装不上也查不到商品）
1. 在 `tool_box_test` 轨道的 **测试人员** 标签 → **创建邮箱列表**（或选已有列表）。
2. 把用于联调的 **Google 账号邮箱**加入该列表并保存。
3. 列表保存后，Play Console 会在测试人员页生成一个 **opt-in 测试链接**（形如 `https://play.google.com/apps/testing/uk.aknot.toolbox`）。
   - 封闭式测试也可用 **Google 网上论坛（Group）** 批量邀请，但邮箱列表最直接。

#### 3.2.3 用 opt-in 链接在真机安装（不再用 `flutter run` debug 包）
1. **真机先用第 3.2.2 步那个 Gmail 登录 Google Play**（系统设置 → 账号）。
2. 手机 Chrome 打开 opt-in 链接 → 点 **「成为测试人员 / Join the test」**。
3. 跳转商店页 → **安装**（此时 App 来自 Play 分发，签名与 Play 登记一致）。
4. 装好前**先卸载掉之前 `flutter run` 装的 debug 包**（同包名两个版本易混淆；建议卸 debug 再装 Play 版，最干净）。

> ⚠️ 只有「从 Play 测试链接安装的版本」才会让 Play Billing 返回商品；debug 侧载包 `queryProductDetails` 永远返回空 —— 这正是你此前看到 "Membership product is not available yet" 的原因。

### 3.3 License testing（沙盒）

路径：**Play Console → 设置（Setup）→ License testing**

- 登录网址：`https://play.google.com/console/app/{appId}/setup/licensing`

- 加入你的 **Gmail**（用于联调的 Google 账号）。
- License tester 购买**不真实扣费**，且可用于反复测。
- 未加 License testing 的账号走真实扣费，且可能触发风控。

> **指定测试账号（★2026-09-12 敲定）**：`leoil.wangsy@gmail.com`
> —— 本工程 Android 内购联调的**唯一指定测试 Gmail**，需同时加进以下三处：
> ① 本 §3.3 License testing（沙盒不扣费）；② §3.2.2 封闭式测试 `tool_box_test` 测试人员邮箱列表（装得上 App）；
> ③ 若要走内部应用分享以外的安装方式，同理。模拟器/真机登录 Google 时也用这一个号。

### 3.4 协议前置

- **《Paid apps / 商家协议》必须已签**（Play Console → 设置 → 协议 / 付款资料）。
  - 登录网址：`https://play.google.com/console/app/{appId}/setup/developer-payment`
  未签 → `queryProductDetails` 返回空，症状同「商品未上架」。

### 3.5 内部应用分享（Internal app sharing）—— 免地区限制的推荐自测通道

> 相比封闭式测试轨道（§3.2），**内部应用分享**是本地自测最快的一条路：
> **不需要建测试人员名单、不受国家/地区限制、上传后立刻可装**。
> 但设备侧有一个默认关闭的开关，没打开会直接装不上（见 §3.5.2）。

#### 3.5.1 在 Play Console 上传并拿链接
1. Play Console → 找 **Internal app sharing（内部应用分享）** 入口。
   - 该项位于**开发者账号级**（不是某个应用内）；新版 Console 若直观找不到，
     可在左侧导航靠下位置或「高级设置」附近寻找，界面版本差异请以实际菜单为准。
2. 上传 release AAB：`flutter build appbundle --release` 产出的 `app-release.aab`。
   - ⚠️ 每次改了代码都要**重新打并重传**；若还想重传旧版本码，Play 会因 versionCode 重复拒收（须先递增）。
3. 上传完成后复制生成的**分享链接**（形如 `https://play.google.com/apps/internaltest/...`）。

#### 3.5.2 设备侧开启「内部应用分享」开关（★必须先做，否则装不上）
直接点开分享链接若报错：

> 「**内部应用分享设置已关闭** —— 如需下载此应用，请在 Google Play 设置中开启内部应用分享。」

按下面步骤开启：
1. 打开 **Google Play 商店** App → 右上角**头像** → **设置**。
2. 滑到底部 → **关于（About）**。
3. 找到 **Play 商店版本（Play Store version）**，**连续点按 7 次** → 提示「你现在是开发者了」。
4. 返回 **设置** 页 → 此时会多出 **内部应用分享（Internal app sharing）** → **打开开关**。
5. 重新打开分享链接 → 即可正常下载安装。

> ⚠️ 该开关**按 Google 账号生效**：开启时用的账号必须与打开分享链接的账号一致。
> 本工程统一使用 §3.3 指定的测试账号 **`leoil.wangsy@gmail.com`**。

#### 3.5.3 与另外几种安装方式的区别（★2026-09-13 真机实测修正）
| 安装方式 | 能否查到 `pro_unlock` 商品 | 适用场景 |
|---|---|---|
| **内部应用分享**（本节） | ❌ **实测查不到** | 只能验 UI / 安装流程，**验不了内购** |
| 封闭式测试轨道 opt-in（§3.2） | ✅ **唯一已验证可行的路径** | 验内购必须走这条 |
| `flutter run` debug 包 | ❌ | 仅功能自测，验不了内购 |
| 本地 `adb install` 的 release APK | ❌ | 仅验 UI/性能，验不了内购；且是 debug 签名，Play 拒收 |

> 🔴 **2026-09-13 真机实测结论（推翻此前"通常可以"的推测）**：
> 通过内部应用分享安装后，`installerPackageName=com.android.vending`（确为 Play 分发），
> 但 App 内点 Upgrade Now 依然显示 **"Membership product is not available yet"**（`hasProduct=false`）。
> 根因：**内部应用分享不是一条"已发布的测试轨道"**，Play Billing 只向
> **已发布到 内部/封闭/开放/生产 轨道** 的同包名 App 返回商品。
> ⇒ **要验证内购，必须把 AAB 发布到 `tool_box_test`（或内部测试）轨道，再用 opt-in 链接安装（§3.2）。**
>
> ⚠️ 注意：购买页会展示 `Pro Unlock / $1.99`，那是**兜底文案**（`purchase_page.dart` 的本地默认值），
> **不代表真的查到了商品**——别被这个假象误导，以点击后是否弹出 Play 支付框为准。

#### 3.5.4 adb 取证命令（排查 release-only / 内购不通问题时很有用）
无需看 UI，直接问设备要证据：
```bash
ADB=$HOME/sdk/android_sdk/platform-tools/adb
export DEV=<设备序列号>      # adb devices 取

# ① 安装来源：确认是不是 Play 分发的包（关键！侧载包一律查不到商品）
$ADB -s $DEV shell dumpsys package uk.aknot.toolbox | grep -E "installerPackageName|versionName|versionCode"

# ② 权限核验（release 包必须用 aapt2，别用 strings —— 二进制 AXML 会漏，产生假阴性）
aapt2 dump badging <xxx.apk> | grep -i "uses-permission" | grep BILLING

# ③ App 内商品 ID 串（确认打进去的是不是 pro_unlock）
# ③ App 内商品 ID（确认打进去的是不是 pro_unlock）—— 做法：
#    pm path 找到 split_config.arm64_v8a.apk → pull 到本地 → 解压取 libapp.so → strings
$ADB -s $DEV shell pm path uk.aknot.toolbox              # 列出各分包路径
$ADB -s $DEV pull <split_config.arm64_v8a.apk 的路径> ./split.apk
unzip -p split.apk lib/arm64-v8a/libapp.so | strings \
  | grep -oE "pro_unlock|toolbox_member_lifetime" | sort | uniq -c

# ④ 抓崩溃堆栈（release 闪退必用）
$ADB -s $DEV logcat -c
$ADB -s $DEV shell monkey -p uk.aknot.toolbox -c android.intent.category.LAUNCHER 1
sleep 8 && $ADB -s $DEV logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime"
```

> ⚠️ 排查铁律：**任何"没找到/正常"的结论都要用第二种方式复核**。
> 本机 `strings` 查二进制 manifest 会漏（本次 BILLING 权限就是 `strings` 假阴性、靠 aapt2 才查实），
> 本机 BSD `grep` 的 `a\|b` 也会静默返回空。

---

## 3.6 Release 打包必须注入 Supabase 配置（★漏了必炸）

### 症状

Release 包装好后一切正常，**唯独点登录/注册时弹**：

```
Supabase is not initialized. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define
```

Debug 跑得好好的，Release 才出现 —— 典型的**「构建期参数漏传」**。

### 根因

`lib/config/app_env.dart` 里两个是**编译期常量**（`String.fromEnvironment`），
**没有默认值**，不通过 `--dart-define` 注入就是空串：

```dart
static const String supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

而 `main.dart` 第 84 行是「配了才初始化、没配就跳过」的写法（为了不打配置也能启动）：

```dart
if (AppEnv.supabaseAnonKey.isNotEmpty) { await Supabase.initialize(...); }
else { debugPrint('[Supabase] 未配置…跳过初始化'); }
```

→ 于是**裸跑 `flutter build apk --release` 打出的包，Supabase 从未初始化**，一点登录就报错。

> 顺带注意：`base_url.dart` 里三个环境的 `supabase` 仍是 `https://xxx-*.supabase.co`
> **占位符**，别指望它兜底——URL 也必须靠 `SUPABASE_URL` 注入。

### 正确做法（推荐：用统一脚本 `scripts/prd.sh`，别手敲）

项目已提供脚本 **`scripts/prd.sh`**（2026-09-13 改造：新增 AAB 支持 + 打包前置校验），
默认就会带上 `--dart-define-from-file=local/env/prd.json`：

```bash
cd /Users/zhangchunhua/project_knot/repo/knot/tool_box

./scripts/prd.sh aab     # 只打 AAB ← 上传 Play / 内部应用分享 / 封闭测试轨道，最常用
./scripts/prd.sh apk     # 只打 APK ← 本地 adb 直装自测
./scripts/prd.sh both    # APK + AAB 一次全打
./scripts/prd.sh         # 不带参数则进入交互菜单选择
```

脚本内部等价于（手敲时**一个参数都不能少**）：

```bash
export FLUTTER_ROOT=/Users/zhangchunhua/sdk/flutter/master
cd /Users/zhangchunhua/project_knot/repo/knot/tool_box

$FLUTTER_ROOT/bin/flutter build appbundle --release \
  --dart-define=ENV="prd" \
  --dart-define=ENABLE_DEBUG_LOG="false" \
  --dart-define-from-file=local/env/prd.json
```

> **为什么用 `--dart-define-from-file` 而不是逐个 `--dart-define=KEY=VALUE`**：
> 密钥统一存在 `local/env/prd.json`（已被 `.gitignore` 忽略，不入库），
> 文件注入不会让 anon key 出现在命令行历史或 CI 日志里。dev.sh / prd.sh / iapsmoke.sh
> 走的都是同一套约定。

> **可选：开启 Dart 混淆**：脚本支持 `-O` / `--obfuscate` 参数（例：`./scripts/prd.sh --obfuscate aab`）。
> 开启后向 flutter 传入 `--obfuscate --split-debug-info=build/app/outputs/symbols`，
> 仅混淆 **Dart 符号**，不影响已用 `isMinifyEnabled=false` 关闭的**原生 R8 混淆**（二者无关——
> 之前 release 闪退是原生 R8 所致，与 Dart 混淆无关）。
> 调试符号会拆到 `build/app/outputs/symbols/`（按 ABI 分 x64/arm64/arm 三个文件），
> 日后崩溃栈需靠它还原类名/函数名。
> 本工程枚举（theme_color / theme_mode）走 Hive **int 索引**持久化、不依赖枚举名，
> 故开启 Dart 混淆安全；若日后新增「枚举名当持久化键」的写法才需谨慎。

### 打完怎么验（30 秒，别等装到手机上才发现）

抽 `libapp.so` 搜 Supabase 项目 ref，命中即证明注入生效：

```bash
/usr/bin/python3 - <<'PY'
import zipfile, re
for art in ['build/app/outputs/flutter-apk/app-release.apk',
            'build/app/outputs/bundle/release/app-release.aab']:
    z = zipfile.ZipFile(art)
    for name in [n for n in z.namelist() if n.endswith('libapp.so')]:
        c = len(re.findall(rb'nfoishlluynelazgwduc', z.read(name)))
        print(f"{art.split('/')[0]:6s} {name:38s} ref命中={c}")
PY
```

- 命中 ≥1 → ✅ `SUPABASE_URL` 已进包（同一份 JSON 注入，anon key 必然也在）。
- 命中 0 或只看到 `xxx-dev.supabase.co` → ❌ 漏了 `--dart-define-from-file`，重打。

> ⚠️ 上传 Play 前记得先递增 `pubspec.yaml` 的 `version: 1.0.0+N`，
> versionCode 重复会被拒收。

---

## 4. 验证清单（对照表）

| 检查项 | 期望 | 不通过常见原因 |
|---|---|---|
| Play Console 商品 ID | `pro_unlock` | 手滑差字符 → `productMissing` |
| 商品状态 | Active | 草稿态查不到 |
| 内部测试轨道 | 已上传 + 测试账号已接受邀请 | 未上传 → `queryProductDetails` 空 |
| License testing | 你的 Gmail 已加入 | 未加 → 真实扣费 / 走不通 |
| 商家协议 | 已签 | 未签 → 查不到商品 |
| 真机安装来源 | 内部测试链接 或 同包名 debug | 包名不一致 → Play 拒关联 |
| `minSdk` | ≥ 24 | 本工程已满足，勿改 |
| 脚本 smoke | `hasProduct=true` / `$1.99` / ID 一致 | 多因上表某项未满足 |

---

## 5. 真机联调步骤（Android）

前提：一台 Android 真机（或装有 Play Store 且登录 license tester 的模拟器）+ Mac/PC 已 `flutter devices` 识别。

```bash
cd /Users/zhangchunhua/project_knot/repo/knot/tool_box

# 1) 先确保脚本与依赖 OK（沙箱无 Flutter SDK，需你本机跑）
flutter pub get
flutter analyze scripts/smoke_iap.dart

# 2) 真机登录 license tester 的 Google 账号
#    设置 → Google → 支付资料 / 沙盒（或直接从内部测试链接安装后登录）

# 3) 拿 Android 设备 id
flutter devices

# 4) 先 smoke 验商品（不购买，安全）
./scripts/iapsmoke.sh --device <Android 设备 id>
#   → 确认输出 hasProduct=true、价格 $1.99、Product ID = pro_unlock

# 5) smoke 通过后再跑真购买（license tester 不真实扣费）
./scripts/iapsmoke.sh --buy --device <Android 设备 id>
#   → Google Play 支付对话框点完成 → 脚本自动 completePurchase(acknowledge)

# 6) 成功：会员卡点亮（owned=true）；重装后 BillingClient 建连自动恢复，无需手动恢复
```

> App 内手动验证路径：Profile 页 → 点 **Upgrade Now** → 独立购买页显示 **Pro Unlock + $1.99** → 点按钮 → Google Play 支付对话框 → 完成 → 会员卡从「Upgrade Now」变为「Pro 已开通/生效中」。

---

## 6. 常见坑速查

| 现象 | 原因 / 处理 |
|---|---|
| `queryProductDetails` 返回空 / `hasProduct=false` | Play Console 商品未 Active；或未上传内部测试轨道；或 License testing 未加账号；或商家协议未签；或包名不一致 |
| 模拟器 `notFound` | Android 模拟器多无 Play 商店服务，**必须真机测**（或装 Play Store 且登录 license tester 的模拟器） |
| 购买完成但 3 天后被退款 | `completePurchase`（acknowledge）漏调；本工程 `_onPurchaseUpdated` 已统一处理，正常不会 |
| 支付对话框反复弹 | 交易未 `acknowledge`；代码已处理，若仍出现查 `pendingCompletePurchase` 分支 |
| 重装后会员没了 | 应是 BillingClient 冷启动自动恢复；若未恢复，点「恢复购买」走 `restorePurchases()` |
| `flutter run` 装的包查不到商品 | 包名未与 Play 登记一致，或未上传内部轨道；用内部测试链接安装最稳妥 |
| 真机 `isAvailable()=false` | 真机未登录 Google 账号 / 断网 / Play 商店服务异常 |
| **下载安装时先收 $1.99** | App 被误设为**付费应用**（App pricing = Paid）。本应用应免费下载，去 **App content → Pricing & distribution → App pricing** 改 **Free** 并重发一次；`$1.99` 只应是 App 内 `pro_unlock` 内购，下载时绝不收（见 §2 第 5 条） |
| **点登录提示 `Supabase is not initialized…`** | Release 构建**漏传** `--dart-define-from-file=local/env/prd.json`，编译期 `SUPABASE_ANON_KEY` 为空 → `main.dart` 静默跳过 `Supabase.initialize`。改用 `scripts/prd.sh` 打安卓包即可（详见 §3.6） |
| 点内部应用分享链接报「**内部应用分享设置已关闭**」 | 设备侧开关没开：Play 商店 → 头像 → 设置 → 关于 → **连点「Play 商店版本」7 次** → 返回设置开启「内部应用分享」（详见 §3.5.2）。该开关**按 Google 账号生效**，须与打开链接的账号一致 |
| release 包**启动即闪退**（debug 正常） | R8 混淆把反射依赖的库（WorkManager 的 Room `WorkDatabase_Impl`）改名/剔除。本工程已显式 `isMinifyEnabled=false` 规避；若再开瘦身须先补 keep 规则（见 `android/app/build.gradle.kts` 注释） |

---

## 7. 与 iOS 的差异对照（联调视角）

| 项 | Android | iOS |
|---|---|---|
| 沙盒账号 | Play Console **License testing** 加 Gmail（不真实扣费） | App Store Connect **Sandbox Tester**（如已建 `zhang13655179933@gmail.com`） |
| 本地离线测试 | 无（Play 不提供本地 StoreKit 等价物） | Xcode + `StoreKitConfig.storekit`（`ios/` 下已生成） |
| 必须上传商店？ | 是（内部测试轨道） | 否（沙盒直连即可，但需 Paid Apps 协议已签） |
| 上架前置 | 商家协议 + 内部/封闭/开放轨道 | Paid Apps 协议 + 显式 App ID |
| entitlement | 无概念 | 内购是 App Service，不写幻觉键 |

> 完整 iOS 步骤见 `doc/purchase_handoff.md` §3.1 / §5-C。

---

## 8. 待办（抽取技能前）

- [x] **Play Console 建 `pro_unlock`（managed product）** —— 2026-09-12 已完成，商品 ID 与 iOS 端一致，**代码侧零改动**（`kMemberProductId` 两端共用，BILLING 权限 / applicationId / minSdk 均已就位）。
- [ ] 内部测试轨道上传 + License testing 加 Gmail + 商家协议已签（见 §3）。
- [ ] 真机实测：路径 §5 的 smoke + buy 一次跑通，确认会员卡点亮。
- [ ] 抽取技能时，把本文件「平台配置真相 / 常见坑」整理进 `flutter-iap-lifetime` 技能的 Android 章节。

---

## 9. pro_unlock 商品联调清单（实战速查）

> **指定测试账号**：`leoil.wangsy@gmail.com`（★2026-09-12 敲定，详见 §3.3）。以下「联调 Gmail」均指此账号。

> 商品已定型：**Product ID = `pro_unlock`**，名称 `Pro Unlock`（中 `Pro 解锁`），价格 **$1.99**，类型 **Non-Consumable / managed product**。
> 代码侧常量 `kMemberProductId` 已于 2026-09-12 由占位 `toolbox_member_lifetime` 同步为 `pro_unlock`（`membership_provider.dart:61`）；
> iOS 本地测试配置 `ios/StoreKitConfig.storekit` 的 identifier 也已同步。两端商店商品 ID 必须与 `pro_unlock` **一字不差**。

### 阶段一：商店后台（网页端，用户操作）
- [ ] **App Store Connect**：建非消耗型内购项目，Product ID = `pro_unlock`，名称 `Pro Unlock` / `Pro 解锁`，价格 $1.99，状态 Ready to Submit / Approved。
- [ ] **Play Console → Monetize → In-app products**：建 managed product，Product ID = `pro_unlock`（与代码完全一致），标题 `Pro Unlock`，状态 **Active**（详见 §3.1）。
- [ ] **Play Console → Releases → Internal testing**：上传 AAB（`flutter build appbundle --release` 产物），邀请联调 Gmail 并接受测试邀请（§3.2）。
- [ ] **Play Console → Setup → License testing**：把联调 Gmail 加入（沙盒不真实扣费；§3.3）。
- [ ] **Play Console → Setup → 付款资料**：签署《商家协议》（未签 → `queryProductDetails` 返回空，症状同「商品未上架」；§3.4）。

### 阶段二：构建与安装（本机）
- [ ] `flutter devices` 取真机 id。
- [ ] 优先从 **Play 内部测试链接** 安装（最稳妥，签名与 Play 登记一致）。
- [ ] 或 `flutter run -d <id>` 装 debug 侧载包（包名须 `uk.aknot.toolbox`）。
- [ ] ⚠️ **debug / 侧载包查不到 Play 商品是 Android 机制限制，非 bug**——要真正验购买必须走内部测试轨道安装，否则会看到 "Membership product is not available yet"（`hasProduct=false`）。

### 阶段三：脚本验证（本机，不购买，安全）
```bash
cd /Users/zhangchunhua/project_knot/repo/knot/tool_box
./scripts/iapsmoke.sh --device <Android 设备 id>
```
- [ ] 输出 `is_available=true`
- [ ] `product_details` 含 `pro_unlock`，价格 `$1.99`

### 阶段四：真实购买（license tester 不真实扣费）
```bash
./scripts/iapsmoke.sh --buy --device <Android 设备 id>
```
- [ ] 弹出 Google Play 支付对话框 → 选号 / 完成
- [ ] 脚本自动 `completePurchase`（= acknowledge），会员卡点亮（`owned=true`）

### 阶段五：App 内手动确认
- [ ] Profile 页 → 点 **Upgrade Now** → 独立购买页显示 **Pro Unlock + $1.99**
- [ ] 点购买 → Play 支付框 → 完成 → 会员卡从「Upgrade Now」变为「Pro 已开通 / 生效中」

### 失败定位（按症状，详见 §6）
| 症状 | 优先排查 |
|---|---|
| `hasProduct=false` / `productMissing` | 商品 ID 非 `pro_unlock` 拼写错、状态非 Active、未上传内部测试轨道、License testing 未加、商家协议未签、debug 侧载包 |
| `isAvailable()=false` | 真机未登录 Google 账号 / 断网 / Play 商店服务异常 |
| 支付完成 3 天后被退款 | `completePurchase`（acknowledge）漏调（本工程 `_onPurchaseUpdated` 已统一处理，正常不会） |

---

## 10. 待办（抽取技能前）

- [x] 商品 ID 定型为 `pro_unlock`，代码 / 配置 / 文档全树同步（2026-09-12）。
- [x] Play Console 建 `pro_unlock`（managed product）已按真实 ID 完成（§3.1 / §9 阶段一）。
- [x] 封闭式测试轨道已创建（`tool_box_test`，发布 **1.0.0 internal**，2026-09-12 用户完成）。
- [ ] **License testing 加 Gmail + 商家协议已签（§3.3 / §3.4）**：还须用户确认；二者任一缺失都会导致 `queryProductDetails` 返回空（症状同「商品未上架」）。
- [ ] 真机实测：§9 阶段三、四、五跑通，确认会员卡点亮。
- [ ] 抽取技能时，把本文件「平台配置真相 / 常见坑 / §9 联调清单」整理进 `flutter-iap-lifetime` 技能的 Android 章节。
