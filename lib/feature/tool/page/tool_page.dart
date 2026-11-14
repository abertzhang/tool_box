// ============================================================================
// 文件：feature/tool/page/tool_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   底部导航「工具」Tab 的页面。按 Pixso 设计稿实现，当前仅保留
//   「通用工具」一个分区，以 2 列网格呈现各通用工具入口。
//   各子工具页多数尚未实现，点击统一弹 SnackBar 占位；已实现的（如指南针）
//   通过 [_ToolItem.route] 配置跳转，由 [ToolPage._onToolTap] 路由进入。
//
// 设计稿：
//   Pixso 浅色 3:172 / 深色 5:25。所有颜色取自设计稿色卡，
//   通过 _ToolPalette 双主题色板集中管理，不使用 Theme 的 colorScheme，
//   因为该页配色是独立的品牌色系（大地色 / 暖金），与 Material 默认色板不一致。
//
// 关键依赖：
//   - flutter_riverpod：ConsumerWidget，为后续接入工具使用记录等 Provider 预留 ref。
//
// 结构一览：
//   ToolPage ─ _Section（分区标题 + 内容）
//            └ _ToolCard（普通卡 / featured 渐变卡）← _ToolItem 数据
//   _ToolPalette：双主题色板；_buildGeneralItems：工具数据源；_toolGrid：双列网格。
// ============================================================================

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tool_box/common/ads/banner_ad_view.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/provider/app_settings/free_usage_provider.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
// 会员状态：读取 isMemberProvider 决定顶部状态条的「已购买 / 去购买」两种形态；
// 点击「去购买」跳转到 profile 模块的独立购买页面（PurchasePage，路由 /profile/purchase），
// 由该页面承载 IAP 确认与支付拉起，避免本页重复写购买流程。
import 'package:tool_box/feature/profile/provider/membership_provider.dart';
import 'package:tool_box/feature/profile/routes/route_profile.dart';
import 'package:tool_box/l10n/app_localizations.dart';

import '../provider/flashlight_provider.dart';
import '../route/tool_route.dart';

/// 工具页（Tools）
///
/// 设计稿：浅色 3:172 / 深色 5:25（Pixso）。
/// 当前仅保留「通用工具」一个分区。
/// 配色严格对齐设计稿，按 Brightness 切换双主题色板。
class ToolPage extends ConsumerWidget {
  /// 创建工具页。
  ///
  /// 无参数：工具清单由 [_buildGeneralItems] 在 build 阶段解析（多语言文案依赖 [AppLocalizations]）。
  /// 配色由 [_ToolPalette.of] 依据当前主题现场解析。
  const ToolPage({super.key});

  /// 构建工具页 UI。
  ///
  /// - [context]：用于解析双主题色板与弹出 SnackBar。
  /// - [ref]：Riverpod 句柄，当前未使用。
  ///
  /// 注意：整页用 [SingleChildScrollView] 承载，页面顶部（会员状态条之下）先放备忘录轮播图
  /// （出行备忘录，原「绳结保养指南」，由两张 banner 自动横滑轮播，点击跳备忘录页），
  /// 其下才是「通用工具」分区；该分区工具卡为**双列网格**
  /// （见 [_toolGrid]，一行 2 张、内容自适应高度），横幅广告插在第一行（Compass + Noise）之下。
  /// 滚动统一交给外层。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = _ToolPalette.of(context);
    // 会员状态：**会员免广告**的判定来源。
    //
    // 为什么必须在这里 watch 而不是让 AdBannerSlot 自己读：
    // 会员购买成功后，本页需要「立刻把广告从树上摘掉」—— 只隐藏还不够，
    // 摘掉才会触发 AdBannerSlot.dispose() 释放原生广告实例。
    // 由页面统一持有这个状态，广告组件就能保持通用（不感知会员体系）。
    //
    // 顺带说明：VIP 卖点文案写的是「One-time purchase. No ads.」，
    // 因此「会员看到广告」属于功能缺陷，不是体验优化项。
    final bool isMember = ref.watch(isMemberProvider);

    // 免费使用次数：进入工具页即触发加载 + 云端对齐（build 内 watch 保证首帧前开始），
    // 这样登录用户跨设备累计的额度在首次点击前就已合并到本地。
    // 结果由 _onToolTap 经 ref.read 实时取用，这里仅负责「启动」，故忽略返回值。
    // ignore: unnecessary_statements
    ref.watch(freeUsageProvider);
    // ⚠️ 这里**不再**用 `ref.listen(currentUserProvider, ...)` 做登录态对齐：
    // 该回调会在「页面正在卸载 / finalize」阶段、且鉴权流恰巧发生变化时触发，
    // 此时 `ref` 已处于「即将或已经卸载」的不安全状态，Riverpod 会抛
    // `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe`。
    // 登录/登出→云端重新对齐已由 [FreeUsageController._subscribeAuthSync] 在 Provider 内部
    // 常驻订阅 `onAuthStateChange` 完成（页面无关、ref.keepAlive、ref.onDispose 回收订阅），
    // 此处再监听属于冗余且会崩溃，故删除。
    // 单卡宽度：屏宽减去左右内边距(各 20.w)与列间距(12.w)后取半；
    // 用 [MediaQuery] 取逻辑屏宽，再配合 .w 缩放，保证任意机型两列等宽且居中。
    final cardW = (MediaQuery.of(context).size.width - 40.w - 12.w) / 2;
    // 出行备忘录（原「绳结保养指南」改名）：顶部整行渐变特色卡，
    // 位于页面顶部（会员状态条之下，而非分区底部）。
    final travelMemoItem = _buildTravelMemoItem(l10n);
    // 通用工具清单（多语言文案依赖 l10n，故只能在 build 阶段解析）。
    // 横幅广告要插在第一行（Compass + Noise）之下，因此需要在这里持有完整清单，
    // 再按「第一行 / 其余行」切两段渲染（见下方 [_Section]）。
    final List<_ToolItem> generalItems = _buildGeneralItems(l10n);
    // 第一行含 2 张卡（双列：Compass + Noise），广告插在这一行之下。
    // 写成「取前 2 项 / 跳过前 2 项」而不是硬编码下标，便于日后调整插入位置。
    const int adInsertIndex = 2;

    return Scaffold(
      backgroundColor: palette.pageBg,
      // 无 AppBar：顶部标题栏（原「Tools」标题 + 右侧登录入口图标）已按需求整体移除，
      // 登录入口统一由 Profile 页承担，本页只保留工具内容本身。
      //
      // 注意：l10n.tools 词条不能删——底部导航 main_bottom_nav.dart 仍在使用。
      body: SafeArea(
        // 取消 AppBar 后，顶部状态栏（刘海 / 灵动岛）无人避让，
        // 故 top 恢复为 true，由 SafeArea 自己处理顶部安全区；
        // 底部依旧不避让（底部安全区由 MainBottomNav 处理）。
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          // 顶部 4.h 是「有 AppBar 时」的取值；移除 AppBar 后内容直接接在状态栏下方，
          // 这里上调到 12.h，避免会员状态条贴着状态栏显得拥挤。
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 会员状态条：页面顶部、通用工具网格之上。已购买时显示简短「VIP」状态，
              // 未购买时整条可点击跳转到购买流程（iOS 风格确认弹窗 → 系统支付）。
              // 用 ConsumerWidget 订阅 isMemberProvider，购买成功后自动切换形态。
              _MembershipStatusBar(),
              SizedBox(height: 16.h),
              // 出行备忘录轮播图：用两张 banner（banner_memo_01/02）横滑自动轮播，
              // 取代原先的整行渐变特色卡，占据页面顶部（会员状态条之下）。
              // 整卡可点，走与原本 memo 卡相同的 [_onToolTap]（含免费次数限额拦截 + 埋点），
              // 最终跳转到备忘录页（[ToolRoute.memo]）。
              // SizedBox(width: double.infinity) 强制其横向铺满。
              SizedBox(
                width: double.infinity,
                child: _MemoBannerCarousel(
                  onTap: () => _onToolTap(context, ref, travelMemoItem),
                ),
              ),
              SizedBox(height: 24.h),
              _Section(
                title: l10n.sectionGeneral,
                palette: palette,
                children: [
                  // 通用工具第一段：网格第一行（双列，当前为 Compass + Noise）。
                  ..._toolGrid(
                    context: context,
                    ref: ref,
                    palette: palette,
                    items: generalItems.take(adInsertIndex).toList(),
                    cardW: cardW,
                    onTap: _onToolTap,
                  ),
                  // 横幅广告：位于网格第一行（Compass + Noise）之下。
                  //
                  // 为什么不用「钉在底部导航栏上方」：
                  //   1) 广告紧贴底部 Tab（高频点击区）容易误触，是 AdMob 明确的违规风险点；
                  //   2) 不改动 Tab 壳层结构，Tab 切换时不会重建广告（省一次请求）。
                  //
                  // 会员（已买断）时整块不放进 widget 树 —— 既不请求也不展示，
                  // 且移除动作会触发 AdBannerSlot.dispose()，立即释放原生广告对象。
                  if (!isMember) ...[
                    SizedBox(height: 12.h),
                    AdBannerSlot(
                      labelText: l10n.adLabel,
                      position: BannerPosition.tools,
                    ),
                  ],
                  SizedBox(height: 12.h),
                  // 通用工具第二段：第一行之后的其余各行（同样双列）。
                  ..._toolGrid(
                    context: context,
                    ref: ref,
                    palette: palette,
                    items: generalItems.skip(adInsertIndex).toList(),
                    cardW: cardW,
                    onTap: _onToolTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 工具卡片点击处理。
  ///
  /// - [context]：用于路由跳转与弹出提示；
  /// - [ref]：Riverpod 句柄，用于驱动手电筒开关；
  /// - [item]：被点击的工具条目。
  ///
  /// 各子工具页尚未开发，这里统一弹出 1 秒的 SnackBar 作为反馈，
  /// 既能确认点击命中了正确的卡片，也避免「点了完全没反应」的体验问题。
  Future<void> _onToolTap(
    BuildContext context,
    WidgetRef ref,
    _ToolItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // 提前捕获 context 派生的句柄：本方法后续有多处 await（弹框 / 计数 / 权限申请），
    // 全部捕获到本地后，下方逻辑不再跨 async gap 直接使用 context，
    // 既规避 use_build_context_synchronously 也避免页面已销毁后仍触碰 context 的红屏。
    final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(
      context,
    );
    final GoRouter goRouter = GoRouter.of(context);

    // —— 免费使用次数限额拦截 ——
    // 会员（已购 Pro）不受限；其余用户「剩余免费次数」耗尽（封顶 10 次，
    // 看广告可把已用还回来、但总可用额度不会超过 10）后点击任意工具弹「升级 Pro」引导。
    // 计数以本地为准（免费用户多未登录），登录后由 freeUsageProvider 自动与云端对齐。
    //
    // 为什么放最前：拦截必须发生在「埋点 / 手电筒开关 / 路由跳转 / 开发中占位」
    // 之前，否则超限用户每点一次仍会触发真实行为或埋点，限额形同虚设。
    final bool isMember = ref.read(isMemberProvider);
    if (!isMember) {
      // 读取已合并（本地与云端取 max）的免费次数。注意：必须等 provider 解析完成，
      // 不能用 `.value?.count ?? 0`——在 AsyncLoading 期间 .value 为 null 会落到 0，
      // 重装后本地归零、云端尚未拉回的那几百毫秒窗口里，每次点击都会误判为「未超限」
      // 而放行，导致可趁机点开全部工具。故仍在加载时直接拦截本次点击，待解析完成后再判定。
      final AsyncValue<FreeUsageState> usageState = ref.read(freeUsageProvider);
      if (usageState is AsyncLoading) return; // 加载中：本次点击先拦，避免窗口绕过
      final int used = usageState.value?.count ?? 0;
      // 剩余 = 基础额度 + 广告奖励 - 已用（state 已封装该公式，含未登录 5 / 已登录 10
      // 的动态基础额度，以及看激励广告累加、不封顶的奖励次数）。
      final int remaining =
          usageState.value?.remaining ??
          (FreeUsageController.maxFreeGuest - used).clamp(
            0,
            FreeUsageController.maxFreeGuest,
          );
      if (remaining <= 0) {
        // 弹框曝光（漏斗口径）：确认 → 跳转购买页；取消 → 弹框消失。
        // 两者都不打开工具、也不计数（直接 return）。
        unawaited(
          AppTrack.logNow(
            TrackEvents.freeLimitReached,
            params: <String, Object?>{'tool': item.analyticsKey},
          ),
        );
        // goRouter 已在方法顶部捕获，弹框 await 后直接用它跳转，不触碰 context。
        final bool? goPurchase = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            // 文案不写死具体工具 / 位置，与隐私政策广告披露口径一致。
            title: Text(l10n.freeLimitTitle),
            content: Text(l10n.freeLimitBody),
            actions: <Widget>[
              // 取消：仅关弹框，不跳转。
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.dialogCancel),
              ),
              // 确认：关弹框并跳购买页（经 extra 透传来源，便于漏斗区分转化）。
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.freeLimitUpgrade),
              ),
            ],
          ),
        );
        if (goPurchase == true) {
          goRouter.push(
            ProfileRoute.purchase,
            extra: <String, Object?>{'source': 'free_limit'},
          );
        }
        return;
      }
      // 未超限：记一次使用（本地 +1；云端 +1 由 tool_entry_open 埋点管道自动完成）。
      await ref.read(freeUsageProvider.notifier).increment();
    }

    // 工具入口埋点：所有卡片统一走 tool_entry_open，用 params.tool 区分具体工具。
    //
    // 为什么不用「一个工具一个事件名」（早期的 tool_compass_open 就是这么做的）：
    // 那样每加一个工具就要新增一个事件名，SQL 里 `group by event_name` 也拿不到
    // 干净的工具维度；统一事件名后 `where event_name='tool_entry_open' group by params->>'tool'`
    // 一行就能出热度排行，新增工具零成本。
    //
    // implemented=false 的点击量是**需求投票**：用户点了却只有「开发中」提示，
    // 说明这个功能是真实需求，据此排开发优先级（详见 doc/track.md 第 4 节）。
    AppTrack.log(
      TrackEvents.toolEntryOpen,
      params: <String, Object?>{
        'tool': item.analyticsKey,
        'implemented': item.route != null || item.flashlight,
        'source': 'tool_page',
      },
    );

    // 手电筒：直接切换闪光灯开关，不走路由也不弹「开发中」。
    if (item.flashlight) {
      // l10n / messenger / goRouter 均已在方法顶部捕获，此处不再触碰 context。
      // 提前捕获 messenger，避免 async 间隙后使用 BuildContext 的 lint / 潜在崩溃。
      final messenger = scaffoldMessenger;
      // 先显式申请相机权限（手电筒走的是相机通道）。
      //
      // 为什么不让 camera 插件在 initialize 里顺带申请：那样权限结果是混在
      // CameraException 里的，无法区分「用户拒绝」与「设备不支持」，也就没法给出
      // 「打开设置」这种针对性挽回入口。显式申请后状态是确定的。
      PermissionStatus camStatus = await Permission.camera.status;
      if (!camStatus.isGranted) {
        camStatus = await Permission.camera.request();
      }
      AppTrack.log(
        TrackEvents.toolPermissionResult,
        params: <String, Object?>{
          'tool': 'flashlight',
          'permission': 'camera',
          'granted': camStatus.isGranted,
          'permanently_denied': camStatus.isPermanentlyDenied,
          // 手电筒是首页卡片、没有独立页面，申请时机等同于「用户点按钮要用」。
          'trigger': 'record',
        },
      );
      if (!camStatus.isGranted) {
        // 被拒（含永久拒绝）：直接给出「打开设置」入口，不再去初始化相机
        // （初始化必然再次失败，只会让用户多等一轮）。
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.flashlightPermissionDenied),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: l10n.commonOpenSettings,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
      try {
        // 切换开关；开启失败（如相机权限被拒）会抛异常，由下方 catch 提示。
        await ref.read(flashlightProvider.notifier).toggle();
        // 手电筒开关埋点：验证它是否属于高频工具。
        // 若开灯次数远高于其他工具，应考虑提到更显眼的位置或做桌面小组件。
        final bool on = ref.read(flashlightProvider);
        AppTrack.log(
          TrackEvents.toolFlashlightToggle,
          params: <String, Object?>{'on': on, 'source': 'tool_page'},
        );
      } on CameraException {
        // 相机权限被拒或不可用：提示用户去设置开启，并保持卡片为关闭态。
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.flashlightPermissionDenied),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // 其它意外（如无相机设备）：同样给出友好提示。
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.flashlightUnavailable),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    // 已实现跳转的子工具（route 非空）直接 push 进入；其余维持 SnackBar 占位。
    if (item.route != null) {
      goRouter.push(item.route!);
      return;
    }
    // 子工具页尚未实现，先用 SnackBar 占位。
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(l10n.devToast(item.title)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// 双主题色板，严格对齐 Pixso 浅色(3:172)/深色(5:25)。
///
/// 设计上刻意不复用 [ThemeData.colorScheme]：工具页是一套独立的大地色系品牌配色，
/// 深浅两版并非同一组色值调明度得到，而是设计稿分别给定，因此这里逐项硬编码，
/// 并通过 [of] 按当前 [Brightness] 返回对应的一整套取值。
class _ToolPalette {
  /// 创建色板。所有颜色均为必填，避免遗漏某一项导致深浅色下出现「串色」。
  const _ToolPalette({
    required this.pageBg,
    required this.sectionTitle,
    required this.cardBg,
    required this.cardTitle,
    required this.cardDesc,
    required this.iconBg,
    required this.iconStroke,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 分区标题（「通用工具」）文字色。
  final Color sectionTitle;

  /// 普通卡片背景色。
  final Color cardBg;

  /// 普通卡片标题色。
  final Color cardTitle;

  /// 普通卡片描述文字色。
  final Color cardDesc;

  /// 普通卡片图标底板（44×44 圆角方块）背景色。
  final Color iconBg;

  /// 普通卡片图标本身的颜色。
  final Color iconStroke;

  /// 依据当前主题返回对应色板。
  ///
  /// 通用语义色（页面底 / 分区标题 / 卡片底 / 卡片标题 / 卡片描述）取自 [AppPalette]，
  /// 使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」两个维度的切换。
  ///
  /// ⚠️ 以下字段**保留设计稿常量**，不随色卡变化：
  /// - [iconBg] / [iconStroke]：两者成对——[iconStroke] 是画在 [iconBg] 底板之上的图标色
  ///   （浅色为深咖底白图标，深色为深褐底暖金图标）。若只改其一会出现「白底白图标」，
  ///   且这两值与 [AppPalette] 任一语义色都不相等，故**两者都不改**。
  ///
  /// [context] 必须能向上找到 [Theme]。
  static _ToolPalette of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      // 深色版（设计稿 5:25）：深底 + 暖色图标，卡片比页面底色略浅以形成层次。
      //
      // 页面底与卡片底取自 [AppPalette]：这样「深色 + 蓝色主题」组合下本页也能切到深蓝底。
      // 代价是咖啡色深色的 pageBg / cardBg 由设计稿的 #1A1714 / #252118
      // 归一为 #1C1C1E / #2C2C2E（相差 1~2 个色阶，肉眼几乎无感），
      // 换来的是两套色卡 × 两套明暗的四种组合都能正确呈现。
      return _ToolPalette(
        pageBg: app.pageBg,
        cardBg: app.cardBg,
        // 以下文字色保留设计稿原值：#EBEBF0 与 #7A7269 属中性暖灰，
        // 在深蓝底上同样具备足够对比度，改为冷灰反而可能降低可读性。
        sectionTitle: const Color(0xFFEBEBF0),
        cardTitle: const Color(0xFFEBEBF0),
        cardDesc: const Color(0xFF7A7269),
        iconBg: const Color(0xFF3D3429),
        iconStroke: const Color(0xFFB09878),
      );
    }
    // 浅色版（设计稿 3:172）：米白底 + 深咖图标底板 + 白色图标，
    // 与深色版相比 iconBg / iconStroke 的明暗关系是反过来的，属设计稿原样，不要「统一」。
    return _ToolPalette(
      pageBg: app.pageBg,
      // 分区标题与卡片标题同为一级文字色。
      sectionTitle: app.titleText,
      cardBg: app.cardBg,
      cardTitle: app.titleText,
      // 卡片描述为次级说明文字，取标签色一档。
      cardDesc: app.labelText,
      // iconBg / iconStroke 成对保留常量（理由见方法文档注释）。
      iconBg: const Color(0xFF6B5C44),
      iconStroke: const Color(0xFFFFFFFF),
    );
  }
}

/// 工具条目。
///
/// 描述一个工具入口的展示数据；纯数据类，不含行为，
/// 因此可声明为编译期常量列表（见 [_buildGeneralItems]）。
class _ToolItem {
  /// 创建工具条目。
  ///
  /// - [title]：卡片主标题；
  /// - [description]：一句话说明；
  /// - [icon]：卡片左上角图标；
  /// - [featured]：是否为「特色卡」，默认 false；
  /// - [flashlight]：是否为手电筒开关卡，默认 false。
  const _ToolItem({
    required this.analyticsKey,
    required this.title,
    required this.description,
    required this.icon,
    this.flashlight = false,
    this.route,
  });

  /// 埋点用的稳定工具标识（snake_case）。
  ///
  /// 刻意与展示标题 / 多语言文案解耦：标题会随语言切换而变，
  /// 用它当埋点维度会导致同一工具在中外语环境下被拆成两行。
  /// 新增工具时在这里定一个新 key，即可直接进热度排行，无需改埋点代码。
  final String analyticsKey;

  final String title;
  final String description;
  final IconData icon;

  /// 标记该条目为「手电筒」开关卡。
  ///
  /// 为 true 时，[_ToolCard] 会订阅 [flashlightProvider] 实时反映开 / 关状态，
  /// 且点击由 [ToolPage._onToolTap] 接管为手电筒开关（而非路由跳转或占位提示）。
  final bool flashlight;

  /// 可选：点击后跳转的子工具路由路径。
  ///
  /// 为 null 时维持原 SnackBar「开发中」占位（其余未实现的工具）；
  /// 已实现的工具（如指南针）填对应路由，[ToolPage._onToolTap] 据此跳转。
  final String? route;
}

/// 通用工具分区的工具清单。
///
/// 全部渲染为双列网格（当前 6 项，一行 2 张、共 3 行），无特色卡。
/// 顺序即展示顺序：Compass + Noise 构成第一行，横幅广告插在这行下面
/// （见 [ToolPage.build]）。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
List<_ToolItem> _buildGeneralItems(AppLocalizations l10n) => [
  _ToolItem(
    analyticsKey: 'compass',
    title: l10n.toolCompass,
    description: l10n.toolCompassDesc,
    icon: Icons.explore,
    route: ToolRoute.compass,
  ),
  _ToolItem(
    analyticsKey: 'noise',
    title: l10n.toolNoise,
    description: l10n.toolNoiseDesc,
    icon: Icons.mic,
    route: ToolRoute.noise,
  ),
  _ToolItem(
    analyticsKey: 'level',
    title: l10n.toolLevel,
    description: l10n.toolLevelDesc,
    icon: Icons.screen_rotation,
    route: ToolRoute.level,
  ),
  _ToolItem(
    analyticsKey: 'ruler',
    title: l10n.toolRuler,
    description: l10n.toolRulerDesc,
    icon: Icons.straighten,
    route: ToolRoute.ruler,
  ),
  _ToolItem(
    analyticsKey: 'flashlight',
    title: l10n.toolFlashlight,
    description: l10n.toolFlashlightDesc,
    icon: Icons.flashlight_off,
    flashlight: true,
  ),
  // 世界时钟（2026-09-25 替换原「潮汐」入口位）：
  // 潮汐页与 /tool/tide 路由保留不删，仅本入口让位给世界时钟。
  _ToolItem(
    analyticsKey: 'world_clock',
    title: l10n.toolWorldClock,
    description: l10n.toolWorldClockDesc,
    icon: Icons.public,
    route: ToolRoute.worldClock,
  ),
];

/// 出行备忘录（Travel Memo）条目。
///
/// 该卡最早是「绳结保养指南（Rope Care Guide）」，原属「绳索专用」分区、
/// 作为整行渐变特色卡呈现；该分区整体移除后卡片被保留下来，
/// 现按需求改为「出行备忘录」。2026-09-22 起，工具页顶部不再渲染这张特色卡，
/// 改由 [_MemoBannerCarousel] 用两张 banner 自动横滑轮播代替；本方法仅作为
/// 点击轮播图时的数据源（提供 [route] 与埋点 [analyticsKey]），复用 [_ToolPage._onToolTap]
/// 的免费次数限额拦截 + 埋点 + 跳备忘录页逻辑，交互行为与原本 memo 卡一致。
/// 文案为多语言，需在 build 阶段依赖 [AppLocalizations] 解析，故为方法而非 const。
///
/// ⚠️ 埋点 `analyticsKey` 由 `rope_care` 改为 `travel_memo`：
/// 工具热度排行按此 key 聚合，改名后历史数据会断档（旧数据仍在 `rope_care` 名下）。
/// 该工具改名时从未真正上线（无 route，点击只有「开发中」提示），
/// 历史点击量无分析价值，故直接改用新名。
///
/// 2026-09-18：本卡已接入 [ToolRoute.memo]，点击跳转备忘录页（MemoPage）。
/// 注意文案是「出行备忘录」，而页内标题是通用的「备忘录」 —— 二者刻意不强行对齐：
/// 卡片承担的是入口卖点描述，页面承担的是功能名；若产品侧希望完全一致，
/// 改这里的 [title] 或 memoTitle 文案其一即可，不影响路由。
_ToolItem _buildTravelMemoItem(AppLocalizations l10n) => _ToolItem(
  analyticsKey: 'travel_memo',
  title: l10n.toolTravelMemo,
  description: l10n.toolTravelMemoDesc,
  icon: Icons.luggage,
  // 点击轮播图跳转载入备忘录页（MemoPage）：[ToolPage._onToolTap] 见到非空 route
  // 即 push 到这里指定的路径，不再弹「开发中」占位提示。
  route: ToolRoute.memo,
);

/// 分区：标题 + 内容。
///
/// 把「17pt 半粗标题 + 12pt 间距 + 任意内容」这一固定版式抽出来，
/// 保证「通用工具」分区的排版一致。
class _Section extends StatelessWidget {
  /// 创建分区。
  ///
  /// - [title]：分区标题文案；
  /// - [palette]：由页面统一解析后传入的色板，子组件不再重复判断明暗；
  /// - [children]：分区内容，按传入顺序纵向排列。
  const _Section({
    required this.title,
    required this.palette,
    required this.children,
  });

  final String title;
  final _ToolPalette palette;
  final List<Widget> children;

  /// 构建分区：标题在上，内容依次展开在下。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: palette.sectionTitle,
          ),
        ),
        SizedBox(height: 12.h),
        ...children,
      ],
    );
  }
}

/// 会员状态条（tools 页顶部）。
///
/// 依据 [isMemberProvider] 呈现两种形态：
/// - **已购买**：左侧解锁图标（开放锁）+ 简短「VIP」文字表明购买状态，整条**不可点击**
///   （仅作状态展示，不触发任何跳转；不再显示「Upgrade Now」胶囊）；
/// - **未购买**：整条可点击，左侧锁图标 + 卖点文案 + 右侧「Upgrade Now」胶囊按钮，
///   点击跳转到独立购买页面 [PurchasePage]（路由 /profile/purchase）承载 IAP 确认与支付拉起。
///
/// 配色复用工具页品牌色板 [_ToolPalette]：底色用普通卡色，强调色用特色卡渐变首色，
/// 与下方工具卡视觉连贯但不喧宾夺主。订阅 [isMemberProvider] 后，购买成功
/// （membershipProvider.owned 翻 true）会自动从「去购买」切回「已购买」形态。
class _MembershipStatusBar extends ConsumerWidget {
  /// 创建会员状态条。无参数：形态完全由 Provider 驱动。
  const _MembershipStatusBar();

  /// 构建状态条。
  ///
  /// [context] 用于解析品牌色板与多语言；[ref] 订阅会员状态并驱动购买。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = _ToolPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bool isMember = ref.watch(isMemberProvider);

    // 免费剩余次数：剩余 = 基础额度 + 广告奖励 - 已用。
    // 订阅 freeUsageProvider 后，每放行一次工具点击（increment 使 count +1）这里自动 -1；
    // 看完激励广告（grantRewardedUses 使 bonus +5）这里自动 +5，徽标实时反映剩余可用次数。
    // 基础额度随登录态变化（未登录 10 / 已登录 20），已封装在 state.maxFree 里。
    final usage = ref.watch(freeUsageProvider).value;
    final int remaining = usage?.remaining ?? FreeUsageController.maxFreeGuest;

    // 通用内含布局：无论哪种形态，外层都是同款圆角卡片，保证两种形态切换时
    // 不跳动；差异只在底色（已购用常规卡色，未购用同色但可点）与内容。
    final Widget inner = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: isMember
          // —— 已购买：对勾 + 简短 VIP 文字，右侧补一行「生效中」副文案 ——
          ? Row(
              children: [
                // 解锁图标（开放锁）表示会员已解锁；与未购买态的 lock_outline 形成对照。
                // 已购买时整条不再显示「Upgrade Now」胶囊（见下方 isMember 分支）。
                Icon(Icons.lock_open, color: const Color(0xFF4CAF50), size: 20),
                SizedBox(width: 8.w),
                Text(
                  l10n.profileMemberVip,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: palette.cardTitle,
                  ),
                ),
                const Spacer(),
                // 副文案用次级色、单行省略，窄屏也不会把卡片撑破。
                Expanded(
                  child: Text(
                    l10n.vipActiveTitle,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, color: palette.cardDesc),
                  ),
                ),
              ],
            )
          // —— 未购买：卖点 + 右侧「Upgrade Now」胶囊，整条可点 ——
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行：Pro Unlock 文本 + 「免费 N 次」剩余次数徽标（随工具使用实时递减）。
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            l10n.vipTitle,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: palette.cardTitle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          // 中性灰底胶囊：与右侧强调色「Upgrade Now」动作胶囊形成层级区分
                          // （前者为信息展示、后者为操作入口），不抢视觉焦点。
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: palette.cardDesc.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              l10n.freeRemainingCount(remaining),
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: palette.cardDesc,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        l10n.vipDesc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: palette.cardDesc,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                // 强调胶囊：取语义色板 accent（主题色方案核心色），随咖啡/蓝色色卡切换。
                // 文字用 accentText 保证对比度：浅色/咖啡主题是白字，
                // 蓝色深色主题 accent 已提亮为亮蓝，文字自动换深蓝（白字对比不足）。
                // （旧实现取 featuredGradient 首色 —— 渐变首色与胶囊底色语义不同：
                //  渐变要兼顾整卡视觉，胶囊要保证文字对比度，故二者分别取值。）
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).accent,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    l10n.vipOpen,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.of(context).accentText,
                    ),
                  ),
                ),
              ],
            ),
    );

    // 已购买：纯展示卡片（Material 仅作圆角裁剪，无点击）；
    // 未购买：InkWell 包裹整条，点击跳购买流程。
    if (isMember) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: inner,
      );
    }
    return Material(
      color: palette.cardBg,
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          ProfileRoute.purchase,
          extra: <String, Object?>{'source': 'tool_page'},
        ),
        child: inner,
      ),
    );
  }
}

/// 工具卡片（普通卡，纯色背景，用于 2 列网格）。
///
/// 当 [item.flashlight] 为 true 时，本卡片会订阅 [flashlightProvider]，
/// 实时反映手电筒开 / 关状态（图标、图标色、描述随之变化）。
class _ToolCard extends ConsumerWidget {
  /// 创建工具卡片。
  ///
  /// - [item]：展示数据；
  /// - [palette]：页面级色板；
  /// - [onTap]：点击回调；
  const _ToolCard({
    required this.item,
    required this.palette,
    required this.onTap,
  });

  final _ToolItem item;
  final _ToolPalette palette;
  final VoidCallback onTap;

  /// 构建卡片。
  ///
  /// 手电筒卡片额外按实时开关状态覆盖图标 / 图标色 / 描述。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleColor = palette.cardTitle;
    final descColor = palette.cardDesc;
    final iconTileColor = palette.iconBg;
    // 普通卡图标取语义色板 iconStroke（深浅两版分别给定，见 [_ToolPalette]）。
    final iconColor = palette.iconStroke;

    // 手电筒卡片：依据实时开关状态切换图标、图标色、底板色与描述文案，
    // 让卡片直观反映“是否点亮”，点击即开 / 关。
    IconData effectiveIcon = item.icon;
    Color effectiveIconColor = iconColor;
    Color effectiveTileColor = iconTileColor;
    String effectiveDesc = item.description;
    if (item.flashlight) {
      final isOn = ref.watch(flashlightProvider);
      effectiveIcon = isOn ? Icons.flashlight_on : Icons.flashlight_off;
      // 点亮时用暖金色强调，关闭时回到常规图标色。
      effectiveIconColor = isOn ? const Color(0xFFF0C850) : iconColor;
      // 点亮时底板略微提亮（与熄灭态区分），关闭时回到常规图标底板色。
      effectiveTileColor = isOn ? const Color(0xFF4A3D28) : iconTileColor;
      effectiveDesc = isOn
          ? AppLocalizations.of(context)!.flashlightOn
          : item.description;
    }

    final Widget content = Container(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: effectiveTileColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(effectiveIcon, color: effectiveIconColor, size: 22),
          ),
          SizedBox(height: 10.h),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
            // 标题至多一行，过长省略，防止极端长文案把卡片撑破。
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),
          Text(
            effectiveDesc,
            style: TextStyle(fontSize: 12.sp, color: descColor),
            // 描述至多三行，过长省略，作为垂直溢出的兜底防线。
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // Material 负责底色与圆角裁剪，InkWell 负责点击与水波纹；
    // clipBehavior 为 antiAlias 以保证水波纹不会溢出 16 圆角。
    return Material(
      color: palette.cardBg,
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// 备忘录轮播图（替代原整行渐变特色卡）。
///
/// 用 [PageView] 横滑切换两张 banner（[banner_memo_01] / [banner_memo_02]），
/// 每 4 秒自动切下一张（到尾回到首张循环），右下角带小圆点指示当前页；
/// 整卡可点，[onTap] 由页面传入（即 [_ToolPage._onToolTap]），复用其免费次数限额拦截、
/// 埋点与跳备忘录页的完整逻辑，保证交互行为与原本 memo 特色卡一致。
///
/// 尺寸：按 banner 真实比例 1280×719 用 [AspectRatio] 自适应屏宽，避免拉伸变形。
///
/// 点击 vs 横滑：外层 [GestureDetector] 只认「纯点击（无拖拽）」，横滑手势由
/// 内部 [PageView] 独占处理，二者互不干扰。
class _MemoBannerCarousel extends StatefulWidget {
  /// 创建轮播图。
  ///
  /// - [onTap]：整卡点击回调（横滑不触发），由页面传入以复用 memo 跳转逻辑。
  const _MemoBannerCarousel({required this.onTap});

  /// 整卡点击回调（横滑不触发）。
  final VoidCallback onTap;

  /// 创建状态。无额外参数。
  @override
  State<_MemoBannerCarousel> createState() => _MemoBannerCarouselState();
}

/// [_MemoBannerCarousel] 的状态：持有 [PageController]、当前页索引与自动轮播定时器。
class _MemoBannerCarouselState extends State<_MemoBannerCarousel> {
  /// 横滑控制器：用于自动轮播时平滑切页。
  final PageController _controller = PageController();

  /// 轮播图资源清单（assets 目录下三张 banner）。
  /// 顺序即展示顺序；数量变化只需改这里与圆点指示的生成。
  static const List<String> _images = <String>[
    'assets/images/banner_memo_01.jpg',
    'assets/images/banner_memo_02.jpg',
    'assets/images/banner_memo_03.jpg',
  ];

  /// 自动轮播定时器；到组件销毁必须 cancel，否则泄漏后台循环。
  Timer? _timer;

  /// 当前页索引（0 基），用于高亮对应小圆点。
  int _page = 0;

  /// 初始化：启动自动轮播（每 4 秒切下一张，循环）。
  ///
  /// 为什么在 initState 启动而不是 build：定时任务是副作用，不能随每帧重建反复注册；
  /// mounted 守卫避免组件已卸载后还 setState（防御定时器回调晚于 dispose 的竞态）。
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      // 取模实现「到尾回到首张」的循环轮播。
      _page = (_page + 1) % _images.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 释放：取消定时器并释放控制器，防止内存泄漏。
  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 构建轮播图。
  ///
  /// 外层 [ClipRRect] 做 16 圆角裁剪；[Stack] 叠加底图 [PageView] 与右下角圆点指示器；
  /// [GestureDetector] 拦截纯点击跳 memo，[PageView] 独占横滑。
  @override
  Widget build(BuildContext context) {
    final double radius = 16.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        // banner 为 16:9 标准比例，随屏宽自适应高度，避免 cover 拉伸变形。
        aspectRatio: 16 / 9,
        child: Stack(
          children: <Widget>[
            // 横滑轮播主体：纯点击（无拖拽）会穿透到外层 GestureDetector 触发 onTap。
            // 外包 ExcludeSemantics：自动轮播的 PageView 在翻页动画里，其页面
            // RenderObject 持续处于「需要重新布局」状态，语义收集阶段会触发框架断言
            // '!childSemantics.renderObject._needsLayout'。轮播图是装饰性内容，
            // 排除其语义节点即可消除该断言；外层 GestureDetector 的点击语义不受影响。
            GestureDetector(
              onTap: widget.onTap,
              child: ExcludeSemantics(
                child: PageView.builder(
                  controller: _controller,
                  // 用户手动横滑时同步更新当前页，保证圆点高亮正确。
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _images.length,
                  itemBuilder: (_, i) => Image.asset(
                    _images[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            // 右下角小圆点指示器：当前页白点加宽，其余半透明白点，区分当前位置。
            Positioned(
              right: 12.w,
              bottom: 10.h,
              child: Row(
                children: List<Widget>.generate(_images.length, (i) {
                  final bool active = i == _page;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 18.w : 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具卡双列网格（内容尺寸，必定可渲染）。
///
/// 用 [Wrap] 替代固定 [childAspectRatio] 的 [GridView.count]：每张卡宽度固定为
/// 半屏（[cardW]），高度随文案自然撑开，英文标题 / 描述换行后不会因固定单元格高度
/// 而垂直溢出；[Wrap] 内容尺寸布局也不会引入 [Row] + [CrossAxisAlignment.stretch]
/// 在滚动容器内偶发的布局异常，渲染更稳定。
///
/// 2026-09-10 短暂改为过单列列表，随后按需求恢复双列（一行 2 张）；
/// 本页将 6 张卡切成「前 2 张 / 其余」两段渲染，横幅广告插在两段之间
/// （即第一行 Compass + Noise 之下），因此本函数会被调用两次。
///
/// - [context] / [ref]：透传给点击回调；
/// - [palette]：页面级色板；
/// - [items]：待渲染的工具条目（按展示顺序两两成行）；
/// - [cardW]：单卡宽度（半屏减去间距）；
/// - [onTap]：点击回调，签名同 [ToolPage._onToolTap]。
List<Widget> _toolGrid({
  required BuildContext context,
  required WidgetRef ref,
  required _ToolPalette palette,
  required List<_ToolItem> items,
  required double cardW,
  required void Function(BuildContext, WidgetRef, _ToolItem) onTap,
}) {
  // 空列表直接返回空数组：调用方用 `...` 展开，无需额外判空。
  if (items.isEmpty) return const <Widget>[];

  return <Widget>[
    Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: items.map((item) {
        return SizedBox(
          width: cardW,
          child: _ToolCard(
            item: item,
            palette: palette,
            onTap: () => onTap(context, ref, item),
          ),
        );
      }).toList(),
    ),
  ];
}
