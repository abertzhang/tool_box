Tool Box — App Store 提交材料总索引（README）
===============================================
日期：2026-09-27
入口文件：本文件是 doc/ 下全部审核材料的索引与导航，先读本文件。

====================================================================
一、材料清单（doc/ 目录，共 8 份 + 本索引）
====================================================================
| # | 文件名 | 用途 | 提交状态 |
|---|---|---|---|
| 0 | README.txt（本文件） | 总索引 + 进度追踪 | 自用 |
| 1 | SUBMISSION-PACKAGE.txt | 提交包总览（先读这个） | 自用 |
| 2 | app-review-response-en.txt | 审核回复英文版（粘贴提交） | ✅ 待粘贴 |
| 3 | app-review-response.txt | 审核回复中文版 | 自用 |
| 4 | screen-recording-script.txt | 录屏脚本 | 待录制 |
| 5 | review-fields-checklist.txt | 其他审核字段核对表 | 自用 |
| 6 | app-privacy-guide.txt | 隐私问卷操作指引 | 待填写 |
| 7 | FINAL-CHECKLIST.txt | 内购/元数据核对 + 提交顺序 | 自用 |
| 8 | store-metadata-visuals.txt | 描述/关键词/图标/截图 | 待上架填写 |

====================================================================
二、App 名称「Tool Box」占用情况核对（2026-09-27 搜索结果）
====================================================================
结论：App Store 存在大量「Toolbox / Tool Box」同名或近似的工具类 App，
      但苹果对 App 名称【不实行唯一占用】，同名应用可并存，
      关键看【是否触发商标投诉】，而非名称是否重复。

已存在的相似 App（供你判断差异化空间）：
1. Toolbox - All Tools One App（工具：二维码/密码/手电筒等）
2. ToolBox - Softpath Electronics（20+ 工具，骰子/QR/BMI 等）
3. Bosch Toolbox（博世官方，工程师工具）
4. All in one tools - Toolbox（25+ 工具，离线）
5. Toolbox by Koizeay（指南针/地图/换算等，功能与你高度接近）
6. Toolbox - location utilities（定位/角度/QR，功能与你接近）
7. Toolbox PRO: Smart Meter Tools（气压/高度/指南针/手电筒）

给你的建议：
1. 【不冲突】「Tool Box」作为通用词，你可用；苹果不因重名拒绝上架。
2. 【有风险】为避免搜不到/混淆，可在副标题或描述强化你的差异化卖点：
   - 副标题建议：All-in-One Everyday Toolkit
   - 关键词加入 compass/level/noise meter（搜索量高、你的核心差异）
3. 【商标提示】仅当你使用与他人注册商标完全相同的名称+同领域才可能被投诉；
   当前「Tool Box」属通用描述词，风险低。
4. 若担心混淆，可考虑备选名（供参考，不一定需要改）：
   - ToolBox Kit / ToolKit Box / Everyday ToolBox
   （保持与代码 bundle id uk.aknot.toolbox 无关，改名只影响商店显示名）

建议：继续使用「Tool Box」，无需改名。

====================================================================
三、Google Play 对应上架材料要点（供后续双端上架）
====================================================================
你的项目是 Flutter 跨端，Android 已存在（android/ 目录），可同步上架 Google Play。

| 项 | 要求/建议 |
|---|---|
| App 名称 | 与 iOS 一致：Tool Box（Google Play 同名无碍） |
| 应用类型 | 应用（非游戏）；类别：工具（Tools） |
| 描述 | 复用 store-metadata-visuals.txt 的英文描述 |
| 图标 | 512×512 PNG（Play 要求），可用 iOS 1024 图缩放 |
| 截图 | 至少 2 张，建议 6-8 张，真实运行画面；电话/平板各一 |
| 内容分级 | 按问卷填写（工具类，含广告 → 非儿童向），类似 iOS 4+ |
| 内购 | Google Play Console 建同名 managed product：pro_unlock，$1.99 |
| 广告 | AdMob 需配置 Android App ID（admob_config.dart 已有） |
| 数据安全 | Play 数据安全表单（类似 iOS 隐私问卷） |
| 测试 | 内部测试轨道 + 正式版审核 |

注意：
- Google Play 若也选择排除中国大陆则无需处理；若 Play 开放国区，
  需额外准备国内合规（备案等），建议与 iOS 一致剔除国区。
- app-ads.txt 已存在（doc/app-ads.txt），可同时服务 iOS/Android。

====================================================================
四、提交进度追踪表（复制到别处或用 Markdown 勾选）
====================================================================
阶段 A：审核回复
[ ] 已阅读 SUBMISSION-PACKAGE.txt
[ ] app-review-response-en.txt 已粘贴到 Resolution Center
[ ] 同一份已粘贴到 App Review Information → Notes

阶段 B：录屏
[ ] 按 screen-recording-script.txt 录制真机录屏
[ ] 录屏含：登录 → 注销 → 内购购买 → 恢复购买
[ ] 录屏上传到 Resolution Center

阶段 C：隐私问卷
[ ] 按 app-privacy-guide.txt 勾选数据类别
[ ] 每个勾选项填写：关联身份/是否追踪/用途
[ ] 隐私政策 URL 已填且可访问

阶段 D：内购与元数据
[ ] 内购商品 pro_unlock（non-consumable, $1.99）已建，状态「准备提交」
[ ] 价格=免费，供应地区剔除中国大陆
[ ] 描述/关键词按 store-metadata-visuals.txt 填写
[ ] 图标 1024×1024、截图 1290×2796 等真实界面已上传

阶段 E：其他字段
[ ] 年龄分级 4+，不勾「专为儿童」
[ ] 加密 ITSAppUsesNonExemptEncryption=false
[ ] 广告项选「是」（UMP 已接、不请求 IDFA）

阶段 F：提交
[ ] 支持/隐私 URL 可访问
[ ] 截图符合 2.3.3（真实运行界面）
[ ] 点击「提交审核」

进度状态（当前）：
- 阶段 A：材料已就绪，待粘贴
- 阶段 B-D：待执行
- 阶段 E：已核对
