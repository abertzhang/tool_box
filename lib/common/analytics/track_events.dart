// ============================================================================
// 文件：common/analytics/track_events.dart
// 模块：埋点 · 业务侧事件定义层（analytics）
//
// 职责：
//   1) 集中声明 App 全部埋点事件名常量 —— 业务代码只允许引用这里的常量，
//      不允许散落字符串字面量，避免「同一个事件被拼成两种名字」导致 SQL 聚合漏数。
//   2) 提供参数**桶化**工具（数值 → 区间字符串），落实隐私红线：
//      具体数值（绳长 137.5cm、分贝 63.2）无分析价值且可能涉密，
//      统一转成量级桶（'100-200'、'moderate'）再上报。
//
// 为什么单独放 analytics/ 而不是 common/track/：
//   `common/track/` 是**可跨工程整体复制**的通用工具类，依赖洁癖要求它只依赖
//   hive_flutter + package_info_plus。事件名是 tool_box 这个 App 的业务知识，
//   混进去会让复制出去的目录带着别的 App 的事件表。故此处独立成层，
//   analytics 依赖 track（单向），track 不感知 analytics。
//
// 事件清单与「收集目的」见 doc/track.md 的「埋点清单」章节。
// ============================================================================

/// App 全部埋点事件名常量。
///
/// 命名约定（`doc/track.md` 1.1）：
///   - 全部 snake_case，结构为「模块前缀 + 动作」；
///   - **同模块内用参数区分对象**，而不是拆成多个事件名（如五个工具的「保存记录」
///     统一为 [toolDataSaved]，用 `params.tool` 区分），新增工具无需新增事件名；
///   - 布尔结果统一一个事件 + `success` 参数（如 [authLoginResult]），
///     不拆成 login_success / login_failed，否则无法直接算成功率。
abstract final class TrackEvents {
  // ===== 通用与会话 =====

  /// 启动屏结束、进入首页。DAU 分母。
  static const String appOpen = 'app_open';

  /// 本次前台会话结束（进入后台）。计算单次使用时长与会话深度。
  static const String appSessionEnd = 'app_session_end';

  /// 页面浏览。PV/UV 与来源分布。
  static const String pageView = 'page_view';

  /// 捕获到异常 / 关键链路失败。量化各模块失败率。
  static const String appError = 'app_error';

  // ===== 账号 =====

  /// 登录流程结束（成功或失败）。算登录成功率并拆分渠道。
  static const String authLoginResult = 'auth_login_result';

  /// 注册流程结束。注册转化漏斗终点。
  static const String authRegisterResult = 'auth_register_result';

  /// 退出登录二次确认通过后。账号流失信号。
  static const String authLogout = 'auth_logout';

  /// 注销账号（删除用户）二次确认通过后。不可逆流失信号，需与登录量对照看。
  static const String authDeleteAccount = 'auth_delete_account';

  /// 提交「忘记密码」。评估找回密码的真实需求量。
  static const String authPasswordReset = 'auth_password_reset';

  // ===== 工具入口 =====

  /// 工具页点击任意卡片。工具热度排行 + 未实现功能的需求投票。
  ///
  /// 收敛说明：本事件已完全取代早期的 `tool_compass_open`（一个工具一个事件名），
  /// 旧事件名常量与双发分支已移除；历史数据仍保留在 `app_events` 表中，
  /// 分析时如需合并旧数据可用 `event_name in ('tool_entry_open','tool_compass_open')`。
  static const String toolEntryOpen = 'tool_entry_open';

  /// 手电筒开 / 关。验证手电筒是否为高频工具。
  static const String toolFlashlightToggle = 'tool_flashlight_toggle';

  // ===== 工具数据闭环 =====

  /// 定位 / 麦克风权限申请结束。权限失败会让核心功能直接不可用。
  static const String toolPermissionResult = 'tool_permission_result';

  /// 任一工具写入一条记录成功。统计每个工具的真实产出量（区分「打开看看」与「真的在用」）。
  static const String toolDataSaved = 'tool_data_saved';

  /// 删除一条记录确认后。删除频次高说明记录质量差或误操作多。
  static const String toolDataDeleted = 'tool_data_deleted';

  /// 导出（复制到剪贴板）成功。重度用户信号。
  static const String toolExport = 'tool_export';

  /// 任一工具点击分享并拉起系统面板。分享传播量与「读数被带出去」的场景分布。
  ///
  /// 同模块内用 `params.tool` 区分是哪个工具（与 [toolDataSaved] 一致），
  /// 不按工具拆事件名。`success` 区分「分享成功」与「用户取消 / 面板不可用」。
  static const String toolShare = 'tool_share';

  // ===== 工具特有交互 =====

  /// 指南针锁定 / 解锁指针。判断「读数锁定」是否为刚需交互。
  static const String compassLockToggle = 'compass_lock_toggle';

  /// 水平仪点击校准。校准使用率 + 校准幅度。
  static const String levelCalibrate = 'level_calibrate';

  /// 直尺 cm / inch 切换。单位偏好分布。
  static const String rulerUnitSwitch = 'ruler_unit_switch';

  /// 直尺进入 / 退出全屏。全屏使用占比。
  static const String rulerFullscreen = 'ruler_fullscreen';

  /// 单位换算产生结果。找出最高频单位对、决定是否设为默认。
  static const String convUnitConvert = 'conv_unit_convert';

  /// 拉力 / 承重换算产生结果。校验安全系数档位设置。
  static const String convForceConvert = 'conv_force_convert';

  // ===== 个人资料 =====

  /// 编辑资料保存成功。资料完善率。
  static const String profileEditSaved = 'profile_edit_saved';

  /// 点击头像「换一换」。连续换很多次说明内置头像库不够用。
  static const String profileAvatarShuffle = 'profile_avatar_shuffle';

  // ===== 会员与支付（唯一直接影响收入的漏斗）=====

  /// iOS 风格购买确认弹窗弹出。漏斗第 1 层曝光量。
  static const String vipSheetShown = 'vip_sheet_shown';

  /// 弹窗内点击「确认购买」。漏斗第 2 层，衡量文案与价格的说服力。
  static const String vipSheetConfirmed = 'vip_sheet_confirmed';

  /// 拉起系统支付的结果。漏斗第 3 层。
  static const String vipPurchaseResult = 'vip_purchase_result';

  /// 会员从未持有变为持有。转化终点：真实付费率。
  static const String vipActivated = 'vip_activated';

  /// 恢复购买结束。恢复成功率 —— 长期偏低意味着换机后拿不回权益。
  static const String vipRestoreResult = 'vip_restore_result';

  /// 免费使用次数达上限后弹「升级 Pro」引导的曝光。
  ///
  /// 漏斗第 0 层：免费用户点击工具被限额拦截时上报，params.tool 标具体工具。
  /// 与 [vipActivated] 组成「免费限额曝光 → 付费转化」链路，衡量限额引导的转化效率；
  /// 频繁上报属低频（仅超限点击），无需节流。
  static const String freeLimitReached = 'free_limit_reached';

  /// 「同步会员到新设备」对话框曝光（购买成功后弹出）。
  ///
  /// 漏斗第 1 层：与 [vipBind] 组成「曝光 → 授权 → 绑定成功」转化链，
  /// 用来判断引导文案是否值得保留（曝光多、绑定少就该改文案或改时机）。
  ///
  /// 参数：`source` 触发来源（purchase_prompt / profile）。
  static const String vipSyncPromptShow = 'vip_sync_prompt_show';

  /// 会员权益上云绑定的结果（Edge Function `bind-member`）。
  ///
  /// 参数：`source` 触发来源（auto / purchase_prompt / profile / login_after_buy）、
  /// `result` 结果（ok / need_login / failed）。
  /// 用途：衡量「买断用户最终有多少把权益挂到了账号上」——
  /// 这个比例决定换机用户的权益可恢复面，是方案 B 的核心健康指标。
  static const String vipBind = 'vip_bind';

  // ===== 广告（AdMob）=====

  /// 横幅广告一次加载请求的结果（成功 / 失败）。
  ///
  /// 参数：`slot` 广告位标识、`success` 布尔、`code` 失败错误码（成功时为 null）。
  /// 用途：算填充率（fill rate）—— 长期 `code=3`（无填充）说明广告位或地区配置有问题；
  /// `code=1`（请求无效）几乎总是 App ID / 单元 ID 配错，属于能靠监控立刻发现的低级故障。
  /// 注意：本事件**不是**收入指标，只反映「广告能不能加载出来」。
  static const String adBannerResult = 'ad_banner_result';

  /// 插页（Interstitial）广告一次加载 / 展示的结果（成功 / 失败）。
  ///
  /// 参数：`slot` 广告位标识、`success` 布尔、`code` 失败错误码（成功时为 null）。
  /// 用途：与 [adBannerResult] 同口径观察插页广告的填充率与可用性；
  /// `code=-1` 表示 20s 兜底超时（系统未回调，极少见）。
  static const String adInterstitialResult = 'ad_interstitial_result';

  /// 激励（Rewarded）广告一次加载 / 展示 / 发奖的结果（成功 / 失败）。
  ///
  /// 参数：`slot` 广告位标识、`success` 布尔、`code` 失败错误码（成功时为 null）、
  /// `rewarded` 是否真的走到 onUserEarnedReward（拿到奖励）。
  /// 用途：与 [adInterstitialResult] 同口径观察激励广告的可用性与发奖成功率——
  /// 「展示成功但 rewarded=false」是异常组合，说明用户中途退出没拿到奖励，
  /// 这类数据用于判断是否需要调整「看多久才算看完」的产品策略。
  static const String adRewardedResult = 'ad_rewarded_result';

  /// UMP 用户同意流程（Consent）的结果（成功 / 失败）。
  ///
  /// 参数：`success` 布尔（表单正常关闭为 true；拉取失败或表单异常为 false）、
  /// `code` 失败错误码（成功时为 null）、`status` 当前 consent 状态名。
  /// 用途：观察同意流程的可用性与失败率。欧盟 / 英国地区 `success=false` 偏高
  /// 通常意味着 UMP 消息未在 AdMob 控制台发布，或网络被墙导致拉取失败——
  /// 这类用户只能填充非个性化广告（单价低 60~80%），是收益排查的第一现场。
  static const String adConsentResult = 'ad_consent_result';

  // ===== 设置与关于 =====

  /// 语言在 zh / en 间切换。语种实际分布。
  static const String settingsLanguageChange = 'settings_language_change';

  /// 深色模式开关。深色使用占比。
  static const String settingsThemeToggle = 'settings_theme_toggle';

  /// 主题色方案切换（咖啡色 / 蓝色）。用于判断是否需要为新主题投入适配成本。
  static const String settingsThemeColorChange = 'settings_theme_color_change';

  /// 「保存时询问名称」开关。开启率反映用户对记录命名的在意程度：
  /// 若绝大多数人保持默认关闭，命名应做成「事后可改」而非「保存前拦截」。
  static const String settingsSaveNamePromptToggle =
      'settings_save_name_prompt_toggle';

  /// 清除缓存完成。观察缓存增长速度。
  static const String settingsCacheCleared = 'settings_cache_cleared';

  /// 点击尚未实现的设置 / 关于行。**需求投票机**。
  static const String settingsRowTap = 'settings_row_tap';

  /// 点击「给我们评分」。`unavailable` 占比高需改成跳转商店兜底。
  static const String profileRateRequest = 'profile_rate_request';

  /// 打开隐私政策 / 第三方 SDK 清单。合规披露的可触达性证据。
  static const String pageDocView = 'page_doc_view';

  /// SDK 清单中复制链接。哪些第三方被用户重点查看。
  static const String sdkLinkCopied = 'sdk_link_copied';
}

/// 参数桶化工具。
///
/// 对应 `doc/track.md` 1.3「参数红线」：禁止上传精确数值与 PII，
/// 统一折算成区间字符串——既保留分布信息，又无法反推具体输入。
abstract final class TrackBuckets {
  /// 把数值折算成量级桶，默认边界为 10 / 100 / 1000 / 10000。
  ///
  /// 返回值形如 `'0-10'` `'10-100'` `'100-1000'` `'1000-10000'` `'10000+'`。
  /// 负数取绝对值后按同一套边界分档（绳索长度、力值等业务量不会为负，
  /// 这里只是防止异常输入产出 `'--10'` 这类脏桶名）。
  ///
  /// - [value]：待分档的数值；`NaN` / 无穷一律归入 `'invalid'`，
  ///   因为这类值通常意味着换算溢出，本身就是值得单独统计的异常。
  static String magnitude(
    double value, {
    List<double> edges = const <double>[10, 100, 1000, 10000],
  }) {
    if (value.isNaN || value.isInfinite) return 'invalid';
    final double v = value.abs();
    double lower = 0;
    for (final double edge in edges) {
      if (v < edge) return '${_fmt(lower)}-${_fmt(edge)}';
      lower = edge;
    }
    return '${_fmt(lower)}+';
  }

  /// 文本长度桶：用于备忘录正文字数分布（`0-50` / `50-200` / `200+`）。
  ///
  /// 只上传桶而不上传正文，既合规又不影响「内容型功能创作量」的统计。
  static String textLength(int length) {
    if (length < 50) return '0-50';
    if (length < 200) return '50-200';
    return '200+';
  }

  /// 缓存占用桶（MB）：`0-10` / `10-50` / `50-200` / `200+`。
  ///
  /// 精确字节数对分析无意义，只关心「是否涨到需要自动清理」。
  static String megabytes(double mb) => magnitude(mb, edges: const <double>[10, 50, 200]);

  /// 分贝桶：噪音记录的环境分布。
  ///
  /// 分档参考常见声压级划分：`quiet`(<45) / `moderate`(45–70) /
  /// `loud`(70–90) / `very_loud`(≥90)。用于指导默认量程与「嘈杂告警」阈值。
  static String decibel(double db) {
    if (db < 45) return 'quiet';
    if (db < 70) return 'moderate';
    if (db < 90) return 'loud';
    return 'very_loud';
  }

  /// 方位角 → 8 向字母桶（`N` / `NE` / `E` / `SE` / `S` / `SW` / `W` / `NW`）。
  ///
  /// 指南针记录用：只上报方位扇区，绝不上报精确经纬度。
  /// 方位分布可用于验证罗盘读数是否存在系统性偏斜。
  static String cardinal(double heading) {
    // 先归一到 [0,360)，避免负数或超过一圈的角度落到错误扇区。
    final double h = ((heading % 360) + 360) % 360;
    const List<String> dirs = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    // 每个扇区 45°，中心偏移 22.5° 使「正北」落在 N 而非被劈成两半。
    final int idx = ((h + 22.5) % 360) ~/ 45;
    return dirs[idx];
  }

  /// 去掉小数尾随零的紧凑格式（10.0 → '10'，0.5 → '0.5'），仅用于桶名可读性。
  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.truncate().toString() : v.toString();
}

/// 轻量节流器：同一 key 在 [window] 内只允许通过一次。
///
/// 用途举例：单位换算的输入框每敲一个字符都会触发重算，如果直接埋点，
/// 输入 "12.5" 就是 4 条事件。节流后一个静止窗口内只留 1 条，
/// 既保住「这次换算发生过」的事实，又不制造事件风暴。
///
/// 实现刻意不依赖 `dart:async` 的 Timer：调用方（输入框 onChanged）本身
/// 已是高频回调，再挂一堆 Timer 反而增加负担；这里只记时间戳，
/// 判断是纯内存比较，成本可忽略。
///
/// 放在本文件（而非 app_track.dart）是为了可测性：本文件不 import 任何东西，
/// 因此节流逻辑可以用**纯 dart test** 覆盖，不必拉起 Flutter 环境。
class TrackThrottle {
  /// 创建节流器。
  ///
  /// - [window]：同一 key 的最小触发间隔，默认 1.5 秒（够长以覆盖连续输入，
  ///   又够短以免把用户的两次独立操作误并成一次）。
  TrackThrottle({this.window = const Duration(milliseconds: 1500)});

  /// 节流窗口。
  final Duration window;

  /// key → 上次放行时间。
  final Map<String, DateTime> _lastPass = <String, DateTime>{};

  /// 判断 [key] 本次是否放行；放行时内部记下时间戳。
  ///
  /// 有副作用（会写时间戳），因此「只想查询不想记录」的场景不适用。
  bool allow(String key) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastPass[key];
    if (last != null && now.difference(last) < window) return false;
    _lastPass[key] = now;
    return true;
  }

  /// 清空全部记录（页面 dispose 时可调用，避免 key 无限增长）。
  ///
  /// 实际上 key 空间很小（换算分类 / 计算器模式，合计十个左右），
  /// 不调也不会泄漏到危险规模；这里提供方法是为长生命周期页面留出主动清理手段。
  void clear() => _lastPass.clear();
}
