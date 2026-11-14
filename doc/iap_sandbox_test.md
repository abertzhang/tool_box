# 真机沙盒测 IAP 操作 SOP（tool_box 买断会员）

> 工程：`tool_box`（包名 `uk.aknot.toolbox`）
> 商品：`uk.aknot.toolbox.pro`（买断制 non-consumable，1.99 美元）
> 关联文档：[`purchase_handoff.md`](./purchase_handoff.md)（实现总览）、[`purchase_android.md`](./purchase_android.md)（Android 联调）
> 用途：送审前 / 改完 IAP 逻辑后，照这份在真机验证"购买 → 会员点亮 → 恢复购买 → 注销后找回"闭环。
> 最后更新：2026-11-08

---

## 0. 沙盒测试账号（务必先建，否则真机点购买走真实收款）

| 项 | 值 |
|---|---|
| 类型 | Apple 沙盒测试员（Sandbox Tester） |
| 邮箱 | `zhang13655179933+sbx2@gmail.com` |
| 密码 | **自设**（符合复杂度：大小写 + 数字、≥8 位）。**勿写入版本库**，记在私人密码管理器。 |
| 地区 (Territory) | 中国（显示 ¥）；或按需选其他 |
| 密保问题 / 答案 | 自设并记下，首次沙盒登录可能要答 |

> Gmail 的 `+sbx2` 让它在 Apple 侧算一个**独立于** `zhang13655179933@gmail.com` 的全新地址，
> 不会和已有 Apple ID 冲突，可顺利建测试员。
> ⚠️ 该邮箱**必须**在 App Store Connect 的「沙盒 → 测试员」里真正建出来，不是脑子里记着就行。
> ⚠️ 最早想用的 `+sbx1` 报「already have an Apple Account / 已关联 Apple Account」不可用（Apple 侧已存在该地址），
> 故改用 `+sbx2`。**任何曾经当过真实 Apple ID 或沙盒测试员的地址都不可再建**，必须换 Apple 从没见过的变体。
> 📧 **建号后必须邮箱验证**：Apple 会往该地址发验证邮件（因 `+sbx2` 是 Gmail 别名，实际落到主邮箱
> `zhang13655179933@gmail.com` 收件箱，含推广/垃圾标签）——点验证链接前，手机上登录/购买会失败。

---

## 1. iOS：在 App Store Connect 建沙盒测试员

1. 打开 [App Store Connect](https://appstoreconnect.apple.com) → **用户与访问 (Users and Access)**。
2. 左侧 **沙盒 (Sandbox)** → **测试员 (Testers)** → 点 **+**。
3. 填：邮箱 `zhang13655179933+sbx2@gmail.com`、姓名（随意）、密码、密保、地区 → 保存。
4. 不需要真实付款方式；保存后 Apple 会发**验证邮件**到该地址（实际进主邮箱 `zhang13655179933@gmail.com`）→
   **必须先点验证链接完成邮箱验证**，否则手机上登录/购买会失败。

---

## 2. iOS：在 iPhone 上登录沙盒账号

> 沙盒账号是"购买签名身份"，要先让真机退出真实 Apple ID 的"媒体与购买"，才能切到沙盒。

1. iPhone **设置 → 顶部你的 Apple ID → 媒体与购买 (Media & Purchases) → 退出登录**
   （只退购买，iCloud / App Store 顶部登录可保留，日常使用不受影响）。
2. 返回 **设置 → App Store**，拉到最底部出现 **"沙盒账户 (Sandbox Account)"** 一栏 → 点进去，
   用 `zhang13655179933+sbx2@gmail.com` + 自设密码登录。
3. 登录成功，底部即显示该沙盒账号。

（偷懒法：不实签，直接跑 App 点购买，系统会弹窗让你填沙盒账号——但预签更稳，推荐上面这种。）

---

## 3. iOS：真机跑开发包并购买

1. **必须用开发包或 TestFlight 包**，**不能是 App Store 正式包**——正式包沙盒不生效、会走真实收款。
   - 开发包：Xcode 真机 `run`（需设备已注册到 provisioning profile）。
2. App 内进入购买页 → 点购买。
3. 弹出的支付面板**顶部标明 "Sandbox" / 沙盒环境** → 确认即可。
4. 沙盒**不扣真钱**；交易走 `purchased` 事件 → `membership_provider` 点亮本机 `owned=true` → 会员立即生效。
5. 验证：支付面板消失、会员卡变 VIP 即成功。
   - 之前在模拟器看到的 "Payment sheet opened" 提示在真机沙盒下同样正常，非报错。

---

## 4. Android：Play 许可测试员（简略）

1. **Google Play Console → 设置 → 许可测试 (License testing)** → 添加测试者 Google 账号。
2. 手机用**该 Google 账号**作为 Play 主账号登录。
3. 装**内部测试轨道 / 内部应用分享**包（或 debug 包）；测试者购买免费、不扣款。
4. 前提：Play Console 已上架商品 `uk.aknot.toolbox.pro`（沙盒称"许可测试"）。

---

## 5. 端到端要验证的闭环（送审前 checklist）

- [ ] 真机沙盒购买 → 会员点亮（本机 `owned=true`）。
- [ ] **恢复购买**：杀 App 重进（iOS 启动静默 `restorePurchases` 读本机缓存）→ 仍显示会员。
- [ ] **注销账号后找回**（见 [`purchase_handoff.md`](./purchase_handoff.md) §会员状态双源判定）：
  - 同设备注销后重登 → 启动静默恢复点亮，仍是会员；
  - 换设备 → 点"恢复购买" → `_bindAfterRestore` 调 `bind-member` 把 `is_member=true` 写回云端。
- [ ] 购买 / 恢复 / 注销各路径 UI 文案与交互无红屏、无未捕获异常。

---

## 6. 常见坑

- ❌ 沙盒测试员邮箱**不能**是已存在的真实 Apple ID，否则建不了（用 `+` 变体规避）。
- ❌ 真机必须**开发 / TestFlight 包**，正式包点购买会真实收款。
- 📧 **建号后必须邮箱验证**：Apple 发验证信到该地址（Gmail `+sbx2` 别名 → 落到主邮箱，记得翻推广/垃圾标签），
  未验证前手机登录沙盒账户或点购买会报错；点验证链接后才生效。
- ⚠️ **地址一次性**：`+sbx1` 曾报「已关联 Apple Account」即说明 Apple 侧已存在该地址（可能之前建过沙盒测试员），
  不可复用，只能换 `+sbx2` 这类 Apple 从未见过的变体。
- ⚠️ iOS 沙盒偶尔"环境"识别慢：面板没显示 Sandbox → 杀 App 重进，或沙盒账户里登出再登入。
- ⚠️ 沙盒里**恢复购买**走沙盒账号，和真机正式购买隔离——换回真实 Apple ID 登录这台手机时
  **看不到**沙盒买的会员（StoreKit 缓存按 Apple ID 隔离），这是正常的，不是 bug。
- ⚠️ 注销账号会删 `public.users.is_member`（云端"买过"标记），但**真实付款记录留在 Apple/Google 侧**，
  绝不会因为 App 注销而退款或撤销；重新恢复即自动上云重新点亮。

---

## 7. 一键回顾（给健忘的自己）

> 沙盒账号：`zhang13655179933+sbx2@gmail.com`（密码自设，勿入库）
> 建：App Store Connect → 用户与访问 → 沙盒 → 测试员 → +
> 登：iPhone 设置 → 媒体与购买退出 → App Store → 底部沙盒账户登录
> 测：Xcode 真机开发包 → App 内购买 → 面板顶部 "Sandbox" → 确认（不扣钱）

---

## 8. 未登录购买 = 强制自动建号（2026-11-08 改）

> 需求：购买完成后，若用户尚未登录 App 账号，**直接自动拉起平台授权建号**（不再弹可选的"同步会员"说明框）。
> 实现见 `membership_provider.dart` / `member_bind_service.dart` / `purchase_page.dart`。

- **未登录直接购买**：购买成功后本机会员立即点亮（StoreKit 权益 `owned=true`），
  **同时自动拉起 Apple / Google 授权**（iOS 走原生 Apple、Android 走原生 Google）。
  - 授权成功 → 自动建号（OAuth 注册=登录合一）+ 写云端 `users.is_member`；
  - 用户**取消授权** → 不报错，留本机会员，不做云端绑定。
- **取消后"再提示"**：下次启动 App 时，启动探测发现"本机已购但未登录"，
  **会再次自动拉起授权**，直到建号为止（见 `MembershipController._autoRelinkOnLaunch`）。
- **登录即上云（兜底）**：新增全局 `onAuthStateChange` 监听，任何登录（含 Apple OAuth 回退、登录页正常登录）
  只要"已登录 + 本机有权益 + 云端未会员"就自动 `bind-member`——覆盖"先买后登"等所有路径。
- **已登录购买**：走原逻辑，购买即静默 `bind` 上云（无弹框）。
- **手动同步入口仍在**：profile 页的"同步会员"对话框保留「暂不」按钮（可选路径），与强制路径互不冲突。
- ⚠️ 送审/体验提示：强制自动建号会在"未同步的已购用户"每次启动 App 时弹一次平台授权，属预期行为；
  若觉过激，可改为启动仅弹"同步会员"说明框（保留「暂不」）——属产品取舍，非 bug。
