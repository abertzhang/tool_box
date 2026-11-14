# 埋点清单

> 面向 `tool_box` 全 App 的埋点规划表。每个事件都标注了**收集目的**——即这条数据能回答什么问题、
> 会驱动什么决策；没有明确决策用途的事件不列入本表（避免"先埋了再说"的数据垃圾）。
>
> 数据落库表：`app_events`（字段说明见 [`database.md`](./database.md#埋点事件表app_events)）。
> 调用方式：`TrackService.instance.log(...)` / `logNow(...)`（API 详见下方 [埋点api使用说明](#埋点api使用说明)）。
>
> **状态图例**：✅ 已埋点 ｜ ⬜ 待埋点。**优先级**：P0 首批次必上 ｜ P1 次批次 ｜ P2 观察项。

---

## 1. 设计约定

### 1.1 事件命名

- 全部 `snake_case`，采用「模块前缀 + 动作」结构：`app_` / `auth_` / `tool_` / `vip_` / `settings_` …
- **同模块内用参数区分对象，而不是拆成多个事件名**。例如指南针与噪音的"保存记录"都叫
  `tool_data_saved`，用 `params.tool` 区分；这样新增工具时不必新增事件名，SQL 聚合也更简单。
- 布尔结果统一放一个事件 + `success` / `result` 参数（如 `auth_login_result`），
  不要拆成 `login_success` / `login_failed`——拆开后无法直接算成功率。

### 1.2 公共字段（业务方不用传）

以下字段由 `SessionContext` / `TrackService` 在 `toSupabaseRow` 阶段自动注入，**业务代码不要重复传**：

`app_id` · `user_id` · `session_id` · `platform` · `app_version` · `device` · `occurred_at` · `received_at`

其中 `user_id` 是**两级身份**（2026-09-06 修正，此前未登录时为 null）：

| 身份 | 取值 | 注入方式 | 时机 |
| --- | --- | --- | --- |
| 登录用户 | Supabase `auth.users.id` | `TrackService.setUserId(uid)` | `main()` 冷启动同步 + `onAuthStateChange` 监听 |
| 匿名设备 | 设备级 UUID（本地生成，存 Hive） | `TrackService.setAnonymousId(id)` | `main()` 里 `await TrackAnonymousId.load()` |

除 `user_id` 外，`params` 里还会**自动**带上两个身份维度（业务方同样不用传，
且**不能**被业务传入的同名 key 覆盖）：

- `anonymous_id` —— 无论是否登录都有值，用于按设备聚合、串联「登录前 → 登录后」的行为链；
- `is_anonymous` —— `true` 表示这条事件产生于未登录状态，分析真实用户时加 `is_anonymous = false`。

业务方只负责：`event_name` + `params`。

### 1.3 参数红线（隐私合规）

| 禁止上传 | 原因 | 替代方案 |
| --- | --- | --- |
| 邮箱、手机号、昵称原文 | PII，违反隐私政策与最小必要原则 | 需要用户维度分析时用 `user_id`（UUID）关联 |
| 精确经纬度、详细地址 | 位置敏感数据 | 上传 `has_gps: bool` 或方位桶 `cardinal: 'NE'` |
| 输入的具体数值（如力值 137.5N、分贝 63.2） | 无分析价值且可能涉密 | 上传量级桶 `result_bucket: '100-200'` |
| 密码、Token、Authorization 头 | 安全红线 | 一律不进 params |

> **反例对照**：设备级匿名 ID（`anonymous_id`）**允许**上传 —— 它是纯随机数，
> 不含 IMEI / IDFA / Mac 地址等硬件标识，清除 App 数据即失效，无法跨重装追踪。
> 判断标准是「这个值能否反向定位到具体的人或设备硬件」，不能就可以传。

### 1.4 旧事件 `tool_compass_open` 的收敛（已完成）

`tool_compass_open` 是验证埋点链路时打的第一个样，命名上属于"一个工具一个事件名"。
现已**完全收敛**到 `tool_entry_open{tool:'compass'}`：常量 `TrackEvents.toolCompassOpenLegacy`
与 `tool_page.dart` 里的双发分支均已移除，新数据不再产生旧事件名。

> 历史数据仍保留在 `app_events` 表中。如需把旧数据并入新曲线，分析时用：
> `where event_name in ('tool_entry_open', 'tool_compass_open')`。

---

## 2. 通用与会话（`app_` / `page_`）

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `app_open` | 启动屏轮播结束、进入 `/home` 时（cold）；后台超过 30 秒再回前台（warm） | `launch_type`: `cold`/`warm`<br>`splash_ms`: 启动屏耗时（cold）<br>`skipped`: 是否点击「跳过」提前进首页（cold）<br>`bg_ms`: 后台停留（warm） | 建立 DAU / 启动次数基线，是所有转化率的**分母**；`splash_ms` 与 `skipped` 合起来验证 3 秒启动屏是否拖慢体验——前者看停留时长分布，后者看「等不及的人」占比，跳过率高就该缩短轮播 | P0 · ✅ |
| `app_session_end` | App 进入后台（`paused`/`hidden`/`detached`，三者只结算一次） | `duration_ms`: 本次前台时长<br>`event_count`: 本次产生的事件数 | 计算**单次使用时长**与**会话深度**分布——功能做得好不好，最终要看用户愿意停留多久、用几个功能 | P0 · ✅ |
| `page_view` | 路由 push / pop / replace（`TrackPageObserver`）；底部 Tab 切换（`MainTabPage`） | `page`: 路由路径，如 `/tool/compass`；Tab 为 `tab_tool`/`tab_profile`<br>`from`: 来源页面<br>`via`: `router`/`tab` | 页面 PV/UV 与**来源分布**：判断某工具是被"工具页入口"带进来的，还是用户主动切 Tab 找回来的，用于优化入口排序 | P0 · ✅ |
| `app_error` | `FlutterError.onError` / `PlatformDispatcher.onError` 捕获到异常 | `module`: `auth`/`isar`/`iap`/`track`/`flutter`/`platform`<br>`error_type`: 异常类名<br>`stack_hash`: 栈顶哈希 | 量化各模块失败率并定位**最高频崩溃点**；`stack_hash` 让同一类问题能聚合计数而不是逐条刷屏 | P0 · ✅ |

---

## 3. 账号（`auth_`）

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `auth_login_result` | 登录流程结束（成功或失败） | `method`: `password`/`apple`/`google`<br>`success`: bool<br>`error_code`: 归一化错误码 | 算**登录成功率**并拆分渠道：邮箱密码失败率高说明要补找回引导；第三方失败率高说明 OAuth 回调配置有问题 | P0 · ✅ |
| `auth_register_result` | 注册流程结束 | `method`: `email`/`google`/`apple`<br>`success`: bool<br>`error_code` | 注册转化漏斗终点，配合 `page_view{page:'register'}` 算**注册转化率**；渠道占比决定要不要继续投入第三方登录 | P0 · ✅ |
| `auth_logout` | 退出登录二次确认通过后 | `had_cloud_profile`: bool | 账号流失信号。集中式登出可能意味着体验问题（如资料同步异常），需要结合后续是否回流判断 | P1 · ✅ |
| `auth_password_reset` | 提交"忘记密码" | `success`: bool | 评估找回密码的真实需求量。如果邮箱找回占比很高，说明应优先引导用户绑定第三方登录 | P2 · ✅ |

---

## 4. 工具入口（`tool_`）

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `tool_entry_open` | 工具页点击任意卡片 | `tool`: `travel_memo`/`compass`/`noise`/`level`/`ruler`/`flashlight`/`tide`<br>`implemented`: bool | **工具热度排行**，是首页排序与迭代投入的直接依据；`implemented=false` 的点击量等于"用户投票"，可直接排开发优先级 | P0 · ✅（旧事件 `tool_compass_open` 已下线，见 1.4） |

> ⚠️ `tool` 取值变更：顶部特色卡由「绳结保养指南」改为「出行备忘录」，
> `analyticsKey` 由 `rope_care` 改为 `travel_memo`（2026-09-08）。
> 该工具此前从未真正上线（无 route），历史点击量无分析价值，故直接改名不保留兼容；
> 若日后查热度排行，旧数据仍记在 `rope_care` 名下，两者需分开看。
| `tool_flashlight_toggle` | 手电筒开 / 关（工具页或直尺页） | `on`: bool<br>`source`: `tool_page`/`ruler` | 验证手电筒是否为高频工具：若开灯次数远高于其他工具，应考虑提到更显眼的位置或做桌面小组件 | P1 · ✅ |

---

## 5. 工具数据闭环（`tool_data_` / `tool_permission_` / `tool_export`）

> 这一组是**工具箱的核心价值验证**：用户不只是"看读数"，而是"存下了数据"。
> 保存率 = 工具是否真的有用；权限失败率 = 工具是否真的能用。

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `tool_permission_result` | 定位 / 麦克风权限申请结束 | `tool`: `compass`/`noise`<br>`permission`: `location`/`microphone`<br>`granted`: bool<br>`permanently_denied`: bool<br>`trigger`: `page_open`/`record`/`open_settings`<br>（compass 定位 / noise 麦克风 / flashlight 相机同口径） | 权限被拒会让核心功能**直接不可用**。量化拒绝率与"永久拒绝"占比，决定是否需要前置说明弹窗（提升授权率）。<br>`trigger` 区分**进页即申请**与**用到才申请**，可对比两种时机的授权率 | P0 · ✅（`trigger` 2026-09-09 新增；**2026-09-10 起 noise 页不再进页即申请**，该页此事件恒为 `trigger=record`，进页静默检查不上报） |
| `tool_data_saved` | 任一工具写入一条记录成功 | `tool`: `compass`/`noise`/`level`/`tide`/`memo`<br>`has_name`: bool<br>`compound`: 各工具自有维度（见 5.1） | 统计**每个工具的真实产出量**，区分"打开看看"和"真的在用"；`has_name` 反映用户是否愿意为记录付出额外操作成本 | P0 · ✅ |
| `tool_data_deleted` | 删除一条记录确认后 | `tool`: 同上<br>`remaining`: int | 删除频次高说明记录质量差或误操作多，可能需要撤销/批量管理；`remaining` 用于识别重度用户 | P2 · ✅ |
| `tool_export` | 导出（复制到剪贴板）成功 | `tool`: `compass`/`noise`/`tide`<br>`count`: int | 导出是**重度用户信号**，也是"要不要做文件分享 / 云同步"的决策依据；`count` 反映单人数据规模 | P1 · ✅ |
| `tool_share` | 点击分享并走完系统面板（分享内容是 **App 介绍**，不是测量数据） | `tool`: `level`…（入口页）<br>`success`: bool | 分享传播量。`success=false` 多是用户取消，取消率高说明介绍文案没说服力。<br>⚠️ 系统面板不回传"分享到了哪个平台"（平台方不提供），故**无法拆渠道** | P2 · ✅（2026-09-08 水平仪首个接入） |

### 5.1 `tool_data_saved` 的 `compound` 维度（各工具自有）

| tool | 附加 params | 分析目的 |
| --- | --- | --- |
| `compass` | `has_gps: bool`、`cardinal: 'N'/'NE'/…`、`prompt: bool` | 无 GPS 记录占比高 → 权限引导有问题；方位分布可验证罗盘读数是否偏斜 |
| `noise` | `db_bucket: 'quiet'/'moderate'/'loud'`、`prompt: bool` | 用户真实所处环境分布，指导默认量程区间与"嘈杂告警"阈值 |
| `level` | `status: 'level'/'tilt'`、`calibrated: bool`、`prompt: bool` | 区分"找平"与"测斜"两种场景；未校准就保存说明校准入口不够明显；`prompt` 表示本次保存是否经过命名弹窗（受设置项「保存时询问名称」控制，见 `settings_save_name_prompt_toggle`） |
| `tide` | `tide_type: 'rising'/'ebbing'/'high'/'low'` | 当前潮汐为 mock 数据，用真实记录量判断**值不值得接真实潮位 API** |
| `memo` | `action: 'create'/'update'`、`len_bucket: '0-50'/'50-200'/'200+'` | 内容型功能的创作量，决定是否值得做搜索 / 云同步 |

---

## 6. 工具特有交互

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `compass_lock_toggle` | 指南针锁定 / 解锁指针 | `locked`: bool | 判断"读数锁定"是否为刚需交互：使用率极低则可简化 UI，给主读数让出空间 | P2 · ✅ |
| `level_calibrate` | 水平仪点击校准 | `offset_bucket`: 校准前偏差桶 | 校准使用率 + 校准幅度。若多数用户偏差很大才校准，说明应做"进入即自动校准" | P1 · ✅ |
| `ruler_unit_switch` | 直尺 cm / inch 切换 | `unit`: `cm`/`inch` | 单位偏好分布，决定**是否按系统地区自动选默认单位**（减少一次手动切换） | P1 · ✅ |
| `ruler_fullscreen` | 直尺进入 / 退出全屏 | `enter`: bool | 全屏使用占比。高则说明横屏测量是主场景，值得投入横屏适配与边缘防误触 | P2 · ✅ |
| `conv_unit_convert` | 单位换算产生结果 | `category`: `area`/`volume`/`temp`/`speed`/`weight`/`length`<br>`from_unit`、`to_unit`<br>`swapped`: bool | 找出**最高频的单位对**，把它设为默认选中项；`category` 分布决定 pill 排序与是否拆分独立入口 | P1 · ✅ |
| `conv_force_convert` | 拉力 / 承重换算产生结果 | `from_unit`、`to_unit`<br>`result_bucket`: 量级桶 | 用户实际换算的力值区间，用于校验安全系数档位设置是否符合真实使用场景 | P1 · ✅ |

---

## 7. 个人资料（`profile_`）

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `profile_edit_saved` | 编辑资料保存成功 | `changed`: `['nickname','avatar']`<br>`avatar_source`: `preset`/`network` | 资料完善率。完善率高的用户往往留存更好，可用来验证"引导完善资料"是否值得做 | P1 · ✅ |
| `profile_avatar_shuffle` | 点击头像"换一换" | `count`: 本次连续换的第几次 | 连续换很多次说明**内置头像库不够用**或没有"上传自定义头像"能力，是明确的改进信号 | P2 · ✅ |

---

## 8. 会员与支付（`vip_`）

> 这是唯一**直接影响收入**的漏斗，五个事件串成完整转化链路：曝光 → 确认 → 拉起 → 支付 → 生效。

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `vip_sheet_shown` | iOS 风格购买确认弹窗弹出 | `product`: `pro_unlock`<br>`price`: 商店本地化价格 | 漏斗第 1 层**曝光量**，也是所有后续转化率的基准分母 | P0 · ✅ |
| `vip_sheet_confirmed` | 弹窗内点击"确认购买" | `price` | 漏斗第 2 层。曝光→确认的转化率衡量**弹窗文案与价格的说服力**，可用于 A/B 定价 | P0 · ✅ |
| `vip_purchase_result` | 拉起系统支付的结果 | `result`: `started`/`store_unavailable`/`product_missing` | 漏斗第 3 层。`product_missing` 高说明 App Store Connect 未配置商品，`store_unavailable` 高说明是沙盒环境问题——两者处理方式完全不同，必须能区分 | P0 · ✅ |
| `vip_activated` | 会员从"未持有"变为"持有" | `source`: `purchase`/`restore`/`cloud` | **转化终点**：真实付费率与买断收益；`source` 区分新购、恢复购买与云端同步，避免把恢复购买算成新增付费 | P0 · ✅ |
| `vip_restore_result` | 恢复购买结束 | `hit`: bool | 恢复成功率。长期偏低意味着用户换机后拿不回权益，既是**退款与差评来源**，也是 App Store 审核风险点 | P0 · ✅ |
| `vip_sync_prompt_show` | 「同步会员到账号」对话框曝光 | `source`: `purchase_prompt`/`profile` | 方案 B 同步漏斗第 1 层。与 `vip_bind` 组成「曝光 → 授权 → 绑定成功」转化链，用于判断引导文案与弹框时机是否值得保留 | P1 · ✅ |
| `vip_bind` | 权益上云绑定结果（Edge `bind-member`） | `source`: `auto`/`purchase_prompt`/`profile`<br>`result`: `ok`/`need_login`/`failed` | **方案 B 核心健康指标**：买断用户最终有多少把权益挂到账号上，直接决定换机用户的可恢复面。`failed` 高优先查 Edge Function 部署与鉴权 | P1 · ✅ |
| `free_limit_reached` | 免费用户点击工具触发「超过 30 次」升级引导弹框（曝光） | `tool`: `travel_memo`/`compass`/`noise`/`level`/`ruler`/`flashlight`/`tide` | **免费→付费漏斗第 0 层**：与 `vip_activated` 组成「限额曝光 → 付费转化」链路，衡量限额引导的转化效率；仅超限点击才上报，低频无需节流 | P1 · ✅（2026-09-13 新增，free_usage_provider + tool_page 限额拦截） |

### 8.1 广告（`ad_`）

> 与会员同属「变现」条线，且二者**互斥**（购买 Pro Unlock 后不再加载广告），
> 因此放在一起，便于观察「广告曝光 vs 会员转化」的取舍是否合理。

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `ad_banner_result` | 横幅广告一次加载请求结束 | `slot`、`success`、`platform`、`code` | 填充率与配置健康度。⚠️ **`code` 语义双端不同，必须先看 `platform`**：Android 0=内部错误 / 1=请求无效 / 2=网络 / 3=无填充；iOS 0=请求无效 / 1=**无填充** / 2=网络 / 3=服务端错误。即 **iOS `code=1` 是无填充而非配置错误**（新广告单元尚未开始投放、或在模拟器上用生产单元请求的常见结果），别据此改 ID。**不是收入指标**，只反映广告能否加载出来 | P1 · ✅ |

`slot` 取值（随广告位新增，用于区分同一 / 不同页面上的多个广告位）：

| slot | 位置 | 备注 |
| --- | --- | --- |
| `tool_compass_after` | tools 页「通用工具」网格第一行（Compass + Noise）之下 | 原名 `tool_page_bottom`（页尾），2026-09-10 位置上移后更名 |
| `noise_history_top` | 噪音检测器页「历史记录」标题上方 | 二级页面，页面 pop 即 dispose |
| `level_measurements_top` | 水平仪页「Measurements」标题上方 | 同上 |
| `compass_history_top` | 指南针页「历史记录」标题上方 | 同上 |
| `profile_about_top` | Profile 页「关于」分组之上、设置分组之下（2026-09-10 新增） | 与二级页不同，本页是 Tab 常驻页，切 Tab 即 dispose |

---

## 9. 设置与关于（`settings_`）

| 事件名 | 触发时机 | 关键 params | 目的 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| `settings_language_change` | 语言在 zh / en 间切换 | `from`、`to` | 语种实际分布（而非系统地区推测），决定翻译与新内容优先做哪种语言 | P1 · ✅ |
| `settings_theme_toggle` | 深色模式开关 | `dark`: bool | 深色使用占比。占比高则新页面的设计稿必须**同时产出深浅两版**，否则会被大量用户看到未适配界面 | P1 · ✅ |
| `settings_theme_color_change` | 主题色方案切换（咖啡色 / 蓝色） | `from`、`to` | 色卡偏好分布。蓝色占比可观则新页面设计稿需同时产出两套色卡 | P2 · ✅（2026-09-09 新增） |
| `settings_save_name_prompt_toggle` | 「保存时询问名称」开关 | `enabled`: bool | 命名弹窗偏好（默认关闭）。开启率很低 → 命名应做成**事后可改**而非保存前拦截；结合 `tool_data_saved` 的 `prompt` 看弹窗路径的取消率 | P2 · ✅（2026-09-09 水平仪首个接入） |
| `settings_cache_cleared` | 清除缓存完成 | `size_mb`: 清理前占用（桶） | 观察缓存增长速度。若短期内反复涨到很大，应加自动清理策略而不是让用户手动点 | P2 · ✅ |
| `settings_row_tap` | 点击尚未实现的设置 / 关于行 | `row`: `notification`/`account_security`/`about`/`agreement`/`check_update` | **需求投票机**：哪一行被点得最多，就优先实现哪一行，比拍脑袋排期可靠 | P1 · ✅ |
| `profile_rate_request` | 点击"给我们评分" | `result`: `in_app`/`store`/`unavailable` | `unavailable` 占比高说明应用内评分 API 在该区域不可用，需改成跳转商店的兜底方案 | P2 · ✅ |
| `page_doc_view` | 各文档页自己在 `initState` 上报（页面真实创建才计数，rebuild 不重复） | `page`: `privacy`/`sdk_list`/`about_us`<br>`locale` | 合规披露的**可触达性**证据（审核关注点）；同时反映用户对隐私的关注程度 | P2 · ✅ |
| `sdk_link_copied` | SDK 清单中复制链接 | `sdk_id`: 脱敏标识 | 哪些第三方被用户重点查看，用于优化披露文案的详略 | P2 · ✅ |

---

## 10. 落地现状与代码位置

> 三批事件**已全部落地**（2026-09-06）。下表给出「事件 → 上报点」的对照，
> 便于后续排查「某条数据为什么少了」时快速定位代码。

### 10.1 业务侧埋点层（`lib/common/analytics/`）

埋点代码分两层，职责不重叠：

| 目录 | 职责 | 是否可跨工程复用 |
| --- | --- | --- |
| `lib/common/track/` | 队列 / 批量 / 传输 / 身份 —— 通用能力 | ✅ 可整目录 `cp` 到别的 App |
| `lib/common/analytics/` | **事件名常量、参数桶化、页面/生命周期观察者** —— 本 App 的业务知识 | ❌ 跟随 tool_box |

分层的理由：`common/track/` 有严格的依赖洁癖（只依赖 `hive_flutter` + `package_info_plus`），
把 tool_box 的事件表塞进去，复制出去时会带着别的 App 的事件名。
依赖方向是**单向**的：`analytics` → `track`，`track` 不感知 `analytics`。

**业务代码只调 `AppTrack`，不直接碰 `TrackService`**，好处是：

1. 会话级事件计数（`app_session_end.event_count`）有统一采集点；
2. 高频事件节流的收口在一处，不必每个页面各写一遍；
3. 将来换埋点后端只改 `app_track.dart` 一个文件。

| 文件 | 内容 |
| --- | --- |
| `track_events.dart` | 全部事件名常量 + [TrackBuckets] 桶化工具 + [TrackThrottle] 节流器。**零 import**，可纯 `dart test` 覆盖 |
| `app_track.dart` | 上报门面：`log` / `logNow` / `error` / `authResult`，含会话计数 |
| `track_page_observer.dart` | `page_view` 自动采集（挂 GoRouter observers） |
| `app_lifecycle_tracker.dart` | `app_open`(warm) / `app_session_end`（挂 WidgetsBinding） |

### 10.2 上报点速查

| 分组 | 事件 | 上报位置 |
| --- | --- | --- |
| 通用会话 | `app_open`(cold) | `splash/page/splash_page.dart` → `_goHome()` |
| | `app_open`(warm)、`app_session_end` | `common/analytics/app_lifecycle_tracker.dart` |
| | `page_view` | `TrackPageObserver`（路由）+ `main_tab_page.dart`（Tab 切换） |
| | `app_error` | `main.dart` → `_installTrackErrorHandlers()` |
| 账号 | `auth_login_result` / `auth_password_reset` | `login/page/login.dart` |
| | `auth_register_result` | `login/page/register_page.dart` |
| | `auth_logout` | `profile/page/profile_page.dart` → `_confirmSignOut` |
| 工具入口 | `tool_entry_open`、`tool_flashlight_toggle` | `tool/page/tool_page.dart` |
| 数据闭环 | `tool_permission_result`、`tool_data_saved`、`tool_data_deleted`、`tool_export`、`tool_share` | 各工具页（compass / noise / level / tide / knot_memo） |
| 工具交互 | `compass_lock_toggle` | `compass_page.dart` |
| | `level_calibrate` | `level_page.dart` |
| | `ruler_unit_switch`、`ruler_fullscreen` | `ruler_page.dart` |
| | `conv_unit_convert`、`conv_force_convert` | `unit_converter/tabs/uc_converter_tab.dart`（共享组件） |
| 个人资料 | `profile_edit_saved`、`profile_avatar_shuffle` | `profile/page/edit_profile_page.dart` |
| 会员支付 | `vip_sheet_shown`、`vip_sheet_confirmed`、`vip_purchase_result`、`vip_restore_result` | `profile/page/profile_page.dart` |
| | `vip_activated` | `profile/provider/membership_provider.dart`（购买流回调） |
| | `vip_sync_prompt_show` | `profile/page/purchase_page.dart`（购买成功后弹同步框之前） |
| | `vip_bind` | `common/auth/member_bind_service.dart`（三处调用点统一收口） |
| 设置关于 | `settings_*`、`profile_rate_request`、`page_doc_view` | `profile/page/profile_page.dart` |
| | `sdk_link_copied` | `profile/page/third_party_sdk_page.dart` |
| 广告 | `ad_banner_result` | `common/ads/banner_ad_view.dart`（加载成功 / 失败回调） |

### 10.3 `page_view` 的实现方式

用 `NavigatorObserver` 统一注入，**不要求任何页面手写埋点** —— 新增路由自动获得 PV 统计。
`app_router.dart` 里与既有 `routeObserver` 并列挂载，两者职责不重叠：

```dart
observers: [routeObserver, _trackPageObserver],
```

实现要点（见 `common/analytics/track_page_observer.dart`）：

- **三个导航动作都覆盖**：`didPush`（新页入栈）、`didPop`（记 `previousRoute`，
  因为 pop 之后露出的是下面那一页）、`didReplace`。
- **过滤无名路由**：`showDialog` / `showModalBottomSheet` 推入的路由 `settings.name` 为 null，
  直接跳过 —— 弹窗不是「页面」，计入 PV 会污染页面维度。
- **800ms 去重**：连点两次卡片、或 go_router 同一次跳转内连派多个动作，
  都会让同一页面在几十毫秒内被记两次。
- **Tab 切换必须手动补**：`MainTabPage` 是在同一个 route 内换 body，不产生任何导航事件，
  因此在 `ref.listen(tabIdxProvider, ...)` 里补一条 `via: 'tab'` 的 page_view。

`page` 取值即 GoRouter 的路由路径（`state.name ?? state.path`，见 go_router 源码 `builder.dart`），
如 `/home` `/tool/compass`，稳定且不带 query 参数。

### 10.4 高频事件的处理

这是本次落地最容易踩的坑：**几个工具页都是「输入即重算」，没有「计算」按钮**。
如果直接把埋点写在 `onChanged` 里，输入 `12.5` 就是 4 条事件 —— 数据量放大一个数量级，
而且把这批数据当成「用户换算了 4 次」会完全误判。

处理办法是三条，按优先级：

| 手段 | 用在哪 | 说明 |
| --- | --- | --- |
| **节流**（`AppTrack.throttle`，默认 1.5s 窗口） | `conv_*` 等输入驱动型换算事件 | 连续输入只留一条。要的是**分布**，不是逐次明细 |
| **首帧屏蔽** | `uc_converter_tab` | `initState` 里会调一次重算给下方填初值，那是程序行为不是用户行为，不记 |
| **`log` 而非 `logNow`** | 除 `vip_*` 与 `app_open` 外全部事件 | `logNow` 每条事件单独发一次 HTTPS，高频调用既费电又拖慢 UI |

例外，用 `logNow` 的只有三处，都是「丢一条就断一层」的关键节点：
**会员支付漏斗各层**（`vip_*`）、**冷启动 `app_open`**（DAU 分母）、
**`vip_activated`**（购买是异步的，必须立刻落库）。

节流器本身刻意不依赖 Timer：调用方已是高频回调，再挂一堆 Timer 反而增加负担，
只记时间戳做内存比较即可（见 `TrackThrottle`）。

### 10.5 参数红线在代码里的落点

| 红线 | 代码里的处理 |
| --- | --- |
| 不传精确数值 | 一律过 `TrackBuckets.magnitude` / `textLength` / `decibel` 转成桶 |
| 不传经纬度 | 指南针只传 `has_gps: bool` + `cardinal` 方位桶 |
| 不传邮箱 / 昵称原文 | 登录注册失败只传 `AuthException.code`，**不传 message**（message 会回显用户输入的邮箱） |
| 不传用户输入 | 换算器只传单位对（`from_unit`/`to_unit`），不传换算数值 |
| 多语言串不能当维度 | `_ToolItem.analyticsKey`、`_KnotRule.key`、`UcUnit.key` 都是新增的稳定 snake_case 标识 |

最后一条是本次改动量最大但最必要的一处：原来的单位名 / 绳结名都是
`AppLocalizations` 解析出的多语言文案，直接当埋点维度会把「米 → 英尺」和
「Meter → Foot」拆成两行，统计不出真实的高频组合。

### 10.6 单测

```bash
dart test test/track_buckets_test.dart        # 桶化 + 节流（纯 Dart，15 个用例）
flutter test test/track_identity_test.dart    # 埋点身份与 UUID 格式
```

`track_buckets_test.dart` 刻意**不** import `flutter_test`：`TrackBuckets` 与 `TrackThrottle`
是纯逻辑，用 `package:test` 就能覆盖，从而绕开 `flutter_tester` 在受限环境下
无法建立本地 WebSocket 的问题。

---

# 埋点api使用说明

> 行为埋点 + 队列持久化 + 批量上报 + 多通道传输。客户端走 `lib/common/track/`（已落地），
> 服务端走 `supabase/functions/track-event`（已部署到 ref `nfoishlluynelazgwduc`）。
>
> 字段定义、SQL、RLS、索引等表结构说明见 [`database.md`](./database.md)。
> Edge Function 部署、调试、安全清单见 [`../supabase/functions/track-event/README.md`](../supabase/functions/track-event/README.md)。
>
> **现状（2026-09-05）**：表 `app_events` 与 Edge Function 均已上线，鉴权链路（GET/401/403）
> 已实测；service_role 落库写入（`200 {"inserted":1}`）需在本机终端手工跑一次冒烟测试
> （详见 [第 9 章：冒烟验证](#9-冒烟验证)）。
>
> **分层提示（2026-09-06）**：本章讲的是**通用工具层** `lib/common/track/` 的 API。
> tool_box 的业务代码不直接调它，而是走上一层的门面 `AppTrack`
> （`lib/common/analytics/`，含事件名常量与节流）。新增埋点请先读
> [埋点清单 · 第 10 章](#10-落地现状与代码位置)。

---

## 1. 30 秒接入

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tool_box/common/track/track.dart';
import 'package:tool_box/config/app_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await TrackService.instance.init(
    TrackConfig(
      enabled: true,                         // 上线前改 true
      appId: 'tool_box',
      edgeFunctionUrl: AppEnv.trackEdgeUrl,   // 已内置兜底地址
      clientToken: AppEnv.trackClientToken,   // 必须 --dart-define 注入
      useEdgeFunction: true,
      debug: kDebugMode,
    ),
    appVersion: await TrackService.currentAppVersion(),
    supabaseUrl: AppEnv.supabaseUrl,
    supabaseAnonKey: AppEnv.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ToolBoxApp()));
}
```

业务内任意位置上报：

```dart
TrackService.instance.log('compass_open', params: {'screen': 'home'});

await TrackService.instance.logNow('purchase_success',
    params: {'sku': 'vip_year', 'price_cny': 199});

TrackService.instance.setUserId(supabase.auth.currentUser!.id);
```

---

## 2. 架构总览

```
┌──────────────┐   log()/logNow()    ┌──────────────┐
│  业务代码     │ ───────────────────▶ │ TrackService │
└──────────────┘                      └──────┬───────┘
                                              │ enqueueRow()
                                              ▼
                                     ┌──────────────────┐
                                     │ TrackQueue       │
                                     │ (Hive Box)       │
                                     └──────┬───────────┘
                                            │ peekRows()
                                            ▼
                                     ┌──────────────────┐
                                     │ TrackBatcher     │  ← 阈值触发 + 定时 flush
                                     └──────┬───────────┘
                                            │ TrackBatch
                                            ▼
                              ┌────────────────────────────┐
                              │ TrackTransport             │
                              │ ├─ EdgeFunctionTransport   │  默认生产路径
                              │ └─ SupabaseRestTransport   │  备选开发路径
                              └─────────────┬──────────────┘
                                            │ HTTPS POST
                                            ▼
                            ┌──────────────────────────────┐
                            │ Edge Function: track-event  │
                            │  service_role 直写           │
                            └─────────────┬────────────────┘
                                          ▼
                                  ┌──────────────┐
                                  │ app_events   │
                                  └──────────────┘
```

---

## 3. 完整接入步骤

### 3.1 Supabase 侧（一次性）

```bash
# 1) 建表
psql "$DATABASE_URL" -f scripts/sql/app_events.sql

# 2) 链接 + 部署 Edge Function
supabase link --project-ref nfoishlluynelazgwduc
supabase functions deploy track-event --no-verify-jwt

# 3) 配白名单 + 业务令牌
supabase secrets set \
  ALLOWED_APP_IDS=tool_box \
  CLIENT_TOKEN=$(openssl rand -hex 20)
```

`CLIENT_TOKEN` 仅存于 Supabase secrets 与客户端编译期注入，**不要**进仓库。

### 3.2 Flutter 客户端

`pubspec.yaml` 必须依赖（已自带）：

| 包 | 用途 |
| --- | --- |
| `hive_flutter` | 持久化队列 |
| `package_info_plus` | 读取 App 版本号 |

`main.dart` 接入顺序：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `await Hive.initFlutter()`（**必须在 Track.init 前**）
3. `await Supabase.initialize(...)`（如使用）
4. `await TrackService.instance.init(...)`

### 3.3 运行时编译参数

| 注入 | 是否必填 | 说明 |
| --- | --- | --- |
| `--dart-define=TRACK_EDGE_URL=...` | 否 | 覆盖 `AppEnv.trackEdgeUrl` 默认值 |
| `--dart-define=TRACK_CLIENT_TOKEN=...` | 是（生产） | 客户端令牌，与 Edge Function 一致 |
| `--dart-define=TRACK_APP_ID=...` | 否 | 覆盖 `appId`，默认 `tool_box` |

---

## 4. 客户端 API 参考

### 4.1 `TrackService.instance`（全局单例）

| 方法 | 用途 | 关键参数 | 返回 |
| --- | --- | --- | --- |
| `init(config, ...)` | 初始化 | `TrackConfig`、`appVersion`、`supabaseUrl`、`supabaseAnonKey`、`transport?` | `Future<void>` |
| `updateConfig(newConfig)` | 热更新（不动 transport） | `TrackConfig` | `void` |
| `setUserId(uid?)` | 绑定用户 ID（登录后） | `String?` | `void` |
| `clearUserId()` | 清空用户 ID（登出后） | — | `void` |
| `setAnonymousId(id?)` | 绑定设备匿名 ID（未登录时兜底 `user_id`） | `String?` | `void` |
| `setGlobalParams(map)` | 设置全局公共参数（整体替换） | `Map<String, Object?>` | `void` |
| `backfillQueuedIdentity()` | 回填队列中缺身份的历史事件 | — | `Future<int>`（补写条数） |
| `log(eventName, ...)` | 记录一条事件（异步入队） | `eventName`、`params`、`userId?`、`occurredAt?` | `void` |
| `logNow(eventName, ...)` | 立即记录并触发 flush | 同上 | `Future<void>` |
| `flush()` | 主动触发一次 flush | — | `Future<void>` |
| `dispose()` | 释放（退出前调用） | — | `Future<void>` |
| `currentAppVersion()` | 静态：读取 `version+buildNumber` | — | `Future<String>` |

只读 getter：`config` / `sessionId` / `userId` / `queueLength`。

#### `log` vs `logNow`

- `log` —— 入队即可返回，事件稍候由阈值/定时 flush 发出。**开销最低**，适合高频事件。
- `logNow` —— 入队后**立即触发一次 flush**，调用方 `await` 至上报完成。
  适合关键节点（购买成功、错误上报、登录登出）。
- 两者都受 `enabled` 与 `sampleRate` 控制。

#### 身份绑定 —— `user_id` 不为空的关键

`TrackService` 只负责记录事件，它**不知道** App 用的是什么账号体系（Supabase / 自建 JWT / 无账号）。
因此身份注入的职责在调用方；不注入的话 `user_id` 列会一直是 null（2026-09-06 修复前就是这样）。

标准接入（`main()` 内，`init` 之后、`runApp` 之前）：

```dart
await TrackService.instance.init(...);

// 1) 匿名身份：首次启动生成并存 Hive，之后每次启动读出来复用。
//    未登录时用兜底 user_id，保证该列不为 null。
TrackService.instance.setAnonymousId(await TrackAnonymousId.load());

// 2) 登录身份：Supabase 会从本地存储恢复上次的 session，
//    所以冷启动时这里往往已经能拿到用户 —— 必须同步一次，
//    否则最早的 app_open 等事件会丢 user_id。
TrackService.instance.setUserId(_readSupabaseUserId());

// 3) 跟随登录态变化：登录 / 登出 / Token 续期都走这个流。
_subscribeAuthUserIdChanges();

// 4) 回填：上面三步之前入队的事件身份都是 null，补一次。
//    已有 user_id 的行不会被改写（不会把上个账号的事件挂到当前账号）。
await TrackService.instance.backfillQueuedIdentity();
```

```dart
String? _readSupabaseUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null; // Supabase 未初始化（缺 key）→ 交给匿名 ID 兜底
  }
}

void _subscribeAuthUserIdChanges() {
  try {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final String? uid = state.session?.user.id;
      if (uid == null) {
        TrackService.instance.clearUserId();
      } else {
        TrackService.instance.setUserId(uid);
      }
    });
  } catch (_) {}
}
```

三个必须注意的点：

1. **不要在 `common/track/` 里 import supabase** —— 该目录的定位是「跨工程可复制复用」，
   依赖只允许 `hive_flutter` + `package_info_plus`。账号绑定一律放在 `main.dart`。
2. `user_id` 在**入队那一刻**就写死进事件 row，登录只影响**之后**的事件；
   历史匿名事件靠 `params.anonymous_id` 关联，不回填。
3. 未登录时 `user_id` 填的是匿名 UUID，**不是**真实账号。分析真实用户务必加
   `where params->>'is_anonymous' = 'false'`，否则会把匿名设备算成用户。
4. `user_id` 在**入队那一刻**就写死，`setUserId` 改不了已经在队列里的事件。
   启动阶段用 `backfillQueuedIdentity()` 补一次；登录后的历史事件靠
   `params.anonymous_id` 关联，不做改写（避免串号）。

#### 初始化幂等

二次调用 `init` 走更新分支：保留队列与上下文，替换 config 后重建 batcher；不会丢失在途事件。

### 4.2 `TrackConfig`（运行时配置）

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `enabled` | `bool` | `false` | 总开关。**默认关闭**，上线前改为 `true` |
| `appId` | `String` | `'unknown_app'` | 与 `app_events.app_id` 对齐 |
| `edgeFunctionUrl` | `String` | `''` | Edge Function 部署 URL |
| `supabaseTable` | `String` | `'app_events'` | REST 直写模式下的表名 |
| `clientToken` | `String?` | `null` | Edge Function 业务令牌（空则跳过业务校验） |
| `useEdgeFunction` | `bool` | `true` | `true` → Edge 网关；`false` → REST 直写 |
| `flushThreshold` | `int` | `20` | 入队达此阈值立刻 flush |
| `flushInterval` | `Duration` | `30s` | 定时 flush 周期 |
| `sampleRate` | `double` | `1.0` | 0.0~1.0；未命中样本丢弃（**不入队**） |
| `maxRetries` | `int` | `3` | 失败重试预留（当前实现为保留入队） |
| `maxBatchBytes` | `int` | `262144` (256 KiB) | 单批字节上限，超出裁半再发 |
| `debug` | `bool` | `false` | 控制台输出每次上报概要 |

`TrackConfig.copyWith(...)` 用于局部覆盖字段。

### 4.3 `TrackEvent`（事件模型）

不可变模型；字段含义与 `app_events` 列一一对应：

| 字段 | 类型 | 来源 | 说明 |
| --- | --- | --- | --- |
| `eventName` | `String` | 业务调用 | snake_case，按业务前缀聚合（`tool_entry_open`） |
| `params` | `Map<String, Object?>` | 业务调用 | 自动过滤 null 值 |
| `sessionId` | `String` | `SessionContext` | 单次启动唯一，**标准 v4 UUID** |
| `userId` | `String?` | `setUserId` / 入参 | 登录后由业务方注入，未登录为 null |
| `occurredAt` | `DateTime?` | 业务调用或 now | UTC；为空时使用 `DateTime.now().toUtc()` |

`appId` / `platform` / `appVersion` / `device` 由 `SessionContext` 在 `toSupabaseRow`
阶段注入，**不**在 `TrackEvent` 自身存储。

序列化示例（一条事件入表时的完整 row）：

```json
{
  "app_id":      "tool_box",
  "user_id":     "9b1a4e08-3a2f-...",
  "session_id":  "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "event_name":  "compass_open",
  "params":      { "screen": "home" },
  "platform":    "ios",
  "app_version": "1.0.0+1",
  "device":      { "os": "ios", "os_version": "17.4", "locale": "zh_CN" },
  "occurred_at": "2026-09-05T12:34:56.789Z"
}
```

### 4.4 `SessionContext`（运行时上下文）

构造时机：`TrackService.init` 时调用一次，结果贯穿整个 App 生命周期。

| 字段 | 说明 |
| --- | --- |
| `sessionId` | 标准 RFC 4122 v4 UUID（`8-4-4-4-12`），系统熵源 |
| `platform` | `ios` / `android` / `macos` / `windows` / `linux` / `web` |
| `appVersion` | 来自 `PackageInfo.version+buildNumber` |
| `device` | `{os, os_version, locale}`；**不含** IMEI / IP / Mac 地址等 PII |

### 4.5 `TrackQueue`（Hive 持久化队列）

| API | 行为 |
| --- | --- |
| `TrackQueue.open()` | 打开 `KnotBoxTrack` Box（独立于现有 `KnotBox`） |
| `enqueueRow(row)` | 入队；key = `毫秒_4位随机` 保证顺序与不覆盖 |
| `peekRows(count: 50)` | 取最多 N 条队首 row（**不出队**） |
| `removeAll(rows)` | 按 contents 匹配删除（取/删分离，避免丢事件） |
| `clear()` | 清空（调试/登出换账号） |

队列存的是「已填好公共字段的完整 row」——重启后从队列续传不丢上下文。

### 4.6 `TrackBatcher`（批量调度器）

```
flush 触发条件：
  1. 队列长度 ≥ flushThreshold  → 立即 flush
  2. 定时器（flushInterval）    → 周期 flush
  3. TrackService.flush()       → 业务手动触发
  4. TrackService.dispose()     → 退出前强刷
```

flush 流程：

1. `peekRows(flushThreshold)` 取一批
2. 按 `maxBatchBytes` 二次裁剪（超出裁半）
3. `transport.send(TrackBatch)`
4. 成功 → `removeAll`；失败 → 保留，下轮再试
5. 串行执行：flush 期间不再触发第二次（互斥锁）

---

## 5. 传输层（`TrackTransport`）

### 5.1 接口契约

```dart
abstract class TrackTransport {
  Future<TrackTransportResult> send(TrackBatch batch);
}
```

**实现必须**捕获所有内部异常并以 `TrackTransportResult.fail(...)` 返回，**不得**抛异常。

### 5.2 `TrackBatch`

```dart
class TrackBatch {
  final String appId;
  final List<Map<String, Object?>> events; // 已是 Supabase insert 行的形态
  final String? clientToken;               // Edge Function 鉴权用，REST 直写忽略
}
```

### 5.3 `TrackTransportResult` 错误分类

| `success` | `failureKind` | 含义 | 客户端处理 |
| --- | --- | --- | --- |
| `true` | — | 写入成功 | 出队 |
| `false` | `transient` | 5xx / 网络 / 超时 | 保留入队，等下次 flush |
| `false` | `permanent` | 4xx（数据格式 / RLS 拒绝 / 字段错） | **不再重试**，丢弃 |
| `false` | `auth` | 401 / 403（apikey/token 错误） | **不再重试**，需告警 |

### 5.4 两种实现

| 类 | 适用 | 安全模型 |
| --- | --- | --- |
| `EdgeFunctionTransport` | **生产推荐** | `apikey` 走 Edge Function → service_role 直写表 |
| `SupabaseRestTransport` | 开发期 / 内部 demo | anon 直写 PostgREST，需 SQL 加 GRANT + 白名单 RLS |

自定义示例（推 Kafka / 友盟 / 神策）：

```dart
class MyKafkaTransport implements TrackTransport {
  @override
  Future<TrackTransportResult> send(TrackBatch batch) async {
    // ... 你的实现 ...
    return TrackTransportResult.ok;
  }
}

await TrackService.instance.init(
  TrackConfig(enabled: true, appId: 'my_app', useEdgeFunction: false),
  appVersion: '1.0.0+1',
  supabaseUrl: '',
  supabaseAnonKey: '',
  transport: MyKafkaTransport(),
);
```

### 5.5 内部 HTTP 细节（EdgeFunctionTransport）

| 项 | 值 |
| --- | --- |
| `Method` | `POST` |
| `Content-Type` | `application/json` |
| `apikey` | anon/publishable key（Edge Function 默认要求） |
| `Authorization` | `Bearer <anon key>`（与上二选一即可） |
| `X-Client-Token` | 业务令牌，仅在 `clientToken` 非空时发送 |
| 超时 | 15s（默认）；连接超时 10s |
| 错误码 → 分类 | 401/403 → `auth`；4xx → `permanent`；5xx → `transient`；SocketException/TimeoutException → `transient` |

---

## 6. Edge Function HTTP 接口契约

```
POST  https://<ref>.supabase.co/functions/v1/track-event
```

### 6.1 请求头

| 头 | 必填 | 说明 |
| --- | --- | --- |
| `Content-Type` | ✅ | `application/json` |
| `apikey` | ✅ | Supabase anon / publishable key |
| `Authorization` | 二选一 | `Bearer <同上>` |
| `X-Client-Token` | 可选 | 业务令牌，与 `CLIENT_TOKEN` 一致 |

### 6.2 请求体

```json
{
  "app_id": "tool_box",
  "events": [
    {
      "event_name":  "compass_open",
      "params":      { "tool": "compass", "from": "home" },
      "user_id":     "<uuid 或 null>",
      "session_id":  "<uuid>",
      "platform":    "ios",
      "app_version": "1.0.0+1",
      "device":      { "os": "ios", "os_version": "...", "locale": "zh_CN" },
      "occurred_at": "2026-09-05T12:00:00.000Z"
    }
  ]
}
```

约束（Edge Function 校验）：

- `app_id` 必须命中 `ALLOWED_APP_IDS` 白名单
- `events` 数组非空，且 ≤ 500 条
- 服务端二次清洗：覆盖 `app_id`、剥离 `received_at` / `created_at` / `id`，**防止客户端伪造**

### 6.3 响应码

| 状态码 | 含义 | Body 示例 |
| --- | --- | --- |
| `200` | 全部写入成功 | `{"inserted": 42}` |
| `400` | 参数缺失 / 批次超限 / 全无效事件 | `{"error":"empty_events"}` |
| `401` | 缺少 apikey | `{"error":"missing_apikey"}` |
| `403` | app_id 不在白名单 / 业务令牌错误 | `{"error":"app_id_not_allowed","app_id":"..."}` |
| `405` | 非 POST | `{"error":"method_not_allowed"}` |
| `500` | 数据库写入失败 | `{"error":"insert_failed","detail":"..."}` |

---

## 7. 安全清单

### 7.1 客户端

- **不要**把 `email` / `phone` / `IDFA` / `IP` / `IMEI` / `Mac` 等 PII 塞 `params`；
  用户关联用 `userId`（uuid）字段。
- `device` 已在 `SessionContext` 阶段脱敏（仅 OS / locale），业务方不要再扩展敏感字段。
- 生产路径**必须**走 Edge Function（`useEdgeFunction: true`）；REST 直写等同公开 API。
- `clientToken` 不要进仓库、版本控制、CI 日志；通过 `--dart-define` 注入。

### 7.2 服务端

- `app_events` 表启用 RLS 且不创建任何 anon / authenticated policy → 所有写入必须经过 Edge Function。
- Edge Function 必须用 `SUPABASE_SERVICE_ROLE_KEY`（Deno 运行时自动注入）。
- `ALLOWED_APP_IDS` 是首要白名单；`CLIENT_TOKEN` 是次级防误用。
- `app_events` 在 SQL Editor 跑 `scripts/sql/app_events.sql` 建好后，无需再手动改表结构。

---

## 8. 跨工程复用

整套 `lib/common/track/` 自包含，跨工程复制步骤：

1. `cp -r lib/common/track <目标工程>/lib/common/`
2. 目标工程 `pubspec.yaml` 确认 `hive_flutter` + `package_info_plus` 已依赖
3. `main.dart` 按 [第 3 章](#3-完整接入步骤) 接入
4. 跑 `flutter analyze` 校验零 error

如要封装成独立 Dart package，按 `lib/common/track/` 上层套一层 package 骨架
（`pubspec.yaml` / `lib/<package>.dart` export `src/track.dart`）。

---

## 9. 冒烟验证

**这一步我在沙箱里做不了**——任何读取 anon key 的进程都会被 SIGTERM。
请你在本机终端执行：

```bash
REF=nfoishlluynelazgwduc
ANON=$(cat local/env/prd.json | jq -r .SUPABASE_ANON_KEY)    # 或从 supabase 仪表盘复制
TOKEN=$(openssl rand -hex 20)                     # 必须与 Edge Function CLIENT_TOKEN 一致

curl -i -X POST "https://$REF.supabase.co/functions/v1/track-event" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON" \
  -H "Authorization: Bearer $ANON" \
  -H "X-Client-Token: $TOKEN" \
  -d '{
    "app_id": "tool_box",
    "events": [{
      "event_name":  "track_smoke_test",
      "params":      {"tool":"cli","src":"deploy_verify"},
      "session_id":  "'"$(uuidgen)"'",
      "platform":    "macos",
      "app_version": "0.0.0+verify",
      "device":      {"os":"macos"},
      "occurred_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }]
  }'
```

预期 `HTTP/1.1 200 OK` + `{"inserted":1}`。随后 SQL Editor 验证落库：

```sql
select id, event_name, params, platform, occurred_at, received_at
from app_events
where event_name = 'track_smoke_test'
order by received_at desc
limit 5;
```

> ⚠️ 上述 `curl` 命令行里直接出现 anon key 与 token；执行后清空 shell history：
> `history -d $(history | grep -n "track-event" | cut -f1 | head -1)` 或加 `unset HISTFILE`。

---

## 10. 排错清单

| 症状 | 原因 | 排查 |
| --- | --- | --- |
| 一点事件都不上报 | `enabled: false` | `TrackService.instance.config?.enabled` |
| 队列有事件但 flush 卡住 | 网络持续 5xx / auth 失败 | `debug: true` 看 `[TrackBatcher] flush failed: ...` |
| 401 居多 | anon key 与 Edge Function 不匹配 | 比对控制台 Project Settings → API |
| 403 `app_id_not_allowed` | `ALLOWED_APP_IDS` 没包含 `TrackConfig.appId` | `supabase secrets list` 检查 |
| 403 `invalid_client_token` | `--dart-define=TRACK_CLIENT_TOKEN` 与 `CLIENT_TOKEN` 不一致 | 重新跑 `supabase secrets set` |
| 重启后事件全重发 | Hive Box 没清 | `await TrackService.queue.clear()` 调试 |
| 事件字段全为 null | 走的是 REST 直写但字段名不匹配 | 切回 Edge 网关，或补 RLS/GRANT |
| `session_id invalid input syntax for type uuid` | 客户端 `sessionId` 不是合法 UUID | 已修：默认走 v4 UUID；详见 [`session_context.dart`](../lib/common/track/session_context.dart) |
| 调试日志刷屏 | `debug: true` | 仅在 `kDebugMode` 下开 |
| 队列越攒越多 | 一直 transient 失败（无网 / 服务挂） | 看 `TrackService.instance.queueLength`；正常情况下 < `flushThreshold` |

---

## 11. 相关文档

- 本文档上半部分 — [埋点清单](#埋点清单)：全 App 事件规划表（含收集目的、优先级、落地批次）
- [`database.md`](./database.md) — `app_events` / `users` / `user_profiles` 表结构
- [`../supabase/functions/track-event/README.md`](../supabase/functions/track-event/README.md) — Edge Function 部署、调试、冒烟验证
- [`../scripts/sql/app_events.sql`](../scripts/sql/app_events.sql) — 埋点表 DDL（建表 + 索引 + RLS + 可选 REST 段）
- [`../lib/common/track/README.md`](../lib/common/track/README.md) — 工具类内部 README（更面向复用）