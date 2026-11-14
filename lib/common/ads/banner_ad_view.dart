// ============================================================================
// 文件：common/ads/banner_ad_view.dart
// 模块：广告（ads）· 自适应横幅（Banner）广告位
//
// 职责：
//   提供一个「放进任意滚动/列布局即可用」的横幅广告位组件 [AdBannerSlot]：
//   - 自动按当前屏幕宽度向 AdMob 请求**锚定自适应尺寸**（Adaptive Anchored Banner），
//     避免 320×50 固定尺寸在宽屏上留白、在窄屏上溢出；
//   - 加载成功才占位，失败则**完全不占空间**（SizedBox.shrink），
//     不会出现「一条空白把内容顶开」的糟糕观感；
//   - 屏幕宽度变化（旋转 / 分屏）时重新按新宽度请求；
//   - 组件销毁时释放原生广告对象，避免内存与广告实例泄漏。
//
// 为什么不用「固定高度预留 + 骨架屏」：
//   本项目当前在 tools 页内容底部、噪音页「历史记录」上方各放一条 banner，
//   预留空白在广告加载失败（离线 / 新 AdMob 账号前 24h 无填充）时会变成
//   一条突兀的空白；加载成功再撑开高度，滚动位置跳动更小也更好看。
//
// 关键依赖：
//   - google_mobile_ads：BannerAd / AdWidget / AdSize；
//   - admob_config.dart：广告位 ID 与平台支持判定；
//   - AppTrack：仅用于「加载结果」埋点，不影响展示逻辑。
//
// 多处复用说明：
//   同一个广告单元可以在一个页面的多处展示，每个 [AdBannerSlot] 持有
//   自己独立的 BannerAd 实例（析构时各自 dispose），互不影响。
//   若日后想按位置分开统计收益，在 admob_config 里再开一组单元 ID 即可。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';

import 'admob_config.dart';
import 'consent_helper.dart';

// 仅导出 [BannerPosition]，让调用方在 import 本文件后即可按位置传广告位，
// 不必再单独 import admob_config.dart。
export 'admob_config.dart' show BannerPosition;

/// 横幅广告位。
///
/// 用法（放进 Column / Sliver 均可）：
/// ```dart
/// AdBannerSlot(labelText: l10n.adLabel)
/// ```
///
/// 展示规则：
/// - 平台不支持（桌面端）或广告位 ID 为空 → 渲染空盒子，不发起任何请求；
/// - 加载失败 → 同样渲染空盒子，页面布局不被破坏；
/// - 会员免广告由**调用方**控制（不把本组件放进 widget 树即可），
///   本组件不读会员状态，保持通用。
class AdBannerSlot extends StatefulWidget {
  /// 创建横幅广告位。
  ///
  /// - [labelText]：广告位上方的小字标签（如「广告 / Ad」）。传 null 则不显示。
  ///   由调用方传入是为了让本组件不依赖 l10n，保持 common/ads 的独立性。
  /// - [slot]：埋点用的广告位标识（snake_case），用于区分同一页面上的多个广告位。
  // 默认值对应 tools 页那条广告。原名 tool_page_bottom（2026-09-09 接入时广告在
  // 页面底部），2026-09-10 上移到 Compass 一栏下方后更名，避免埋点维度名与实际
  // 位置不符造成误读；此时 App 未上架，无历史数据连续性顾虑。
  const AdBannerSlot({
    super.key,
    this.labelText,
    this.slot = 'tool_compass_after',
    this.position = BannerPosition.tools,
  });

  /// 广告位上方的小字标签；为空则不渲染该行。
  final String? labelText;

  /// 广告位标识，进埋点 `params.slot`。
  final String slot;

  /// 横幅所在的页面位置，决定实际使用的广告单元 ID（分位置统计收益）。
  ///
  /// 默认 [BannerPosition.tools]：历史调用多不带此参数，回落到工具页那条；
  /// 各页面现已显式传入对应位置（compass / noise / level / profile 等）。
  final BannerPosition position;

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  /// 当前持有的原生广告对象；未加载或已释放时为 null。
  BannerAd? _bannerAd;

  /// 广告是否已成功加载（唯一决定是否渲染 [AdWidget] 的开关）。
  ///
  /// ⚠️ [AdWidget] 只能在广告 loaded 之后放进 widget 树，
  /// 提前放会抛断言错误，因此这个标志不能省。
  bool _isLoaded = false;

  /// 上一次请求所用的屏幕宽度（逻辑像素取整）。
  ///
  /// 用来判断「宽度是否真的变了」：didChangeDependencies 在主题切换、
  /// MediaQuery 变化等场景都会触发，不比对的话会白白重复请求广告，
  /// 而 AdMob 对短时间内的重复请求有频率限制（表现为错误码 3 无填充）。
  int _lastRequestedWidth = 0;

  /// 是否已订阅「同意状态变化」通知（避免每次加载重复订阅）。
  ///
  /// 只在「因未取得用户同意而跳过本次加载」时订阅一次，
  /// 用户在同意表单做出选择后（[AdsConsent.revision] 自增）自动补加载。
  bool _consentSubscribed = false;

  /// 当前用于布局的广告高度（逻辑像素）。
  ///
  /// 取自适应尺寸算出的高度；加载完成后若平台返回了真实尺寸则以其为准
  /// （两者偶有 1~2 像素差异，用真实值可避免底部被裁一条）。
  double _height = 0;

  /// 按给定宽度请求一条自适应锚定横幅。
  ///
  /// - [width]：可用宽度（逻辑像素整数），通常取屏宽或父容器宽。
  ///
  /// 流程：先向平台问「这个宽度下推荐多高」（自适应尺寸），拿到后再建广告对象并 load。
  /// 问不到（极窄屏 / 平台异常）时回落标准 320×50，宁可小也不留空白。
  Future<void> _loadAd(int width) async {
    final String unitId = AdMobIds.bannerUnitIdFor(widget.position);
    // 平台不支持或没配广告位：静默跳过，不请求也不报错。
    if (!AdMobIds.isSupported || unitId.isEmpty) return;

    // 同意门控（UMP / GDPR）：尚未取得用户同意时**不得发起广告请求**。
    // 这不是可选项——EEA / UK 地区未经同意请求个性化广告属违规。
    // 此处不直接失败，而是订阅 [AdsConsent.revision]：用户在同意表单里
    // 做出选择后（计数器自增）本组件会自动补一次加载，避免「同意了却永远空白」。
    final bool allowed = await AdsConsent.canRequestAds();
    if (!allowed) {
      debugPrint(
        '[AdMob] Banner 等待用户同意，本次不请求：slot=${widget.slot}',
      );
      _subscribeConsent();
      return;
    }

    // 先释放上一条（旋转场景），否则原生侧会堆积广告实例。
    _disposeAd();

    AdSize size;
    try {
      final AdSize? adaptive = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        width,
      );
      size = adaptive ?? AdSize.banner;
    } catch (e) {
      // 尺寸探测失败（插件通道异常等）：回落标准尺寸，继续尝试加载。
      size = AdSize.banner;
    }

    final BannerAd ad = BannerAd(
      size: size,
      adUnitId: unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => _onLoaded(ad as BannerAd),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // 必须 dispose：失败的广告对象不释放会一直占着原生实例。
          ad.dispose();
          _onFailed(error);
        },
      ),
    );
    _bannerAd = ad;
    _height = size.height.toDouble();

    // load() 内部走平台通道，异常（如未初始化、无网络）会以 Future error 抛出，
    // 也可能通过 onAdFailedToLoad 回送；两边都要兜，避免未捕获异常冒泡红屏。
    try {
      await ad.load();
    } catch (e) {
      _onFailed(null);
    }
  }

  /// 广告加载成功：以平台返回的真实高度为准刷新布局。
  Future<void> _onLoaded(BannerAd ad) async {
    // 先取真实尺寸再 setState：getPlatformAdSize 是异步的，
    // 提前返回会让首帧用估算高度、次帧再跳一次（视觉抖动）。
    double height = ad.size.height.toDouble();
    try {
      final AdSize? platformSize = await ad.getPlatformAdSize();
      if (platformSize != null) height = platformSize.height.toDouble();
    } catch (_) {
      // 取不到就用请求的尺寸，不影响展示。
    }
    // 组件可能在 await 期间被销毁（页面 pop / 会员购买成功移除本组件），
    // 直接 setState 会抛 "setState() called after dispose()"。
    if (!mounted) return;
    setState(() {
      _bannerAd = ad;
      _height = height;
      _isLoaded = true;
    });
    AppTrack.log(
      TrackEvents.adBannerResult,
      params: <String, Object?>{
        'slot': widget.slot,
        'success': true,
        // 平台维度：两端错误码语义不同，且填充率本身就有差异，
        // 分开统计才能判断是「某端配置问题」还是「整体无填充」。
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  /// 广告加载失败：隐藏自己，不占任何空间。
  ///
  /// 这里**不做自动重试**：AdMob 明确不鼓励客户端自行重试
  /// （无填充时重试只会加重限流，且新账号前 24 小时无填充属正常现象）。
  void _onFailed(LoadAdError? error) {
    // ⚠️ 错误码语义 **Android 与 iOS 不是同一张表**，看日志时务必先看 platform：
    //   Android（GMA SDK）：0=内部错误 / 1=请求无效（多为 App ID 或单元 ID 配错）
    //                        / 2=网络 / 3=无填充
    //   iOS（GADErrorCode） ：0=请求无效 / 1=无填充 / 2=网络 / 3=服务端错误
    // 也就是说 **iOS 上 code=1 表示「无填充」而非配置错误** ——
    // 新广告单元尚未开始投放、或在模拟器上用生产单元请求，都会落到这个码，
    // 不要据此去改广告 ID。
    debugPrint(
      '[AdMob] Banner 加载失败：slot=${widget.slot} '
      'platform=${defaultTargetPlatform.name} '
      'unit=${AdMobIds.bannerUnitIdFor(widget.position)} '
      'code=${error?.code} '
      'msg=${error?.message ?? "(load() 抛异常，无 LoadAdError)"}',
    );
    if (!mounted) return;
    setState(() {
      _isLoaded = false;
      _bannerAd = null;
      _height = 0;
    });
    AppTrack.log(
      TrackEvents.adBannerResult,
      params: <String, Object?>{
        'slot': widget.slot,
        'success': false,
        // ⚠️ 同一个数字在两端含义不同（见 _onFailed 顶部注释），
        // 因此必须带上 platform，否则这条错误码无法解读。
        'platform': defaultTargetPlatform.name,
        'code': error?.code,
      },
    );
  }

  /// 订阅「同意状态变化」通知（幂等，重复调用只有第一次生效）。
  ///
  /// 触发时机：用户在 UMP 同意表单或隐私选项表单里做出选择后，
  /// [AdsConsent.revision] 自增 → 本回调重新判定并补加载广告。
  void _subscribeConsent() {
    if (_consentSubscribed) return;
    _consentSubscribed = true;
    AdsConsent.revision.addListener(_onConsentChanged);
  }

  /// 同意状态变化后的补加载逻辑。
  ///
  /// 只有「现在真的可以请求广告了」才重新走 [_loadAd]；
  /// 用户只是关掉表单但仍未同意时保持空白（合规要求）。
  Future<void> _onConsentChanged() async {
    if (!mounted) return;
    final bool allowed = await AdsConsent.canRequestAds();
    if (!allowed || !mounted) return;
    // 用上次量到的宽度重试；尚未量到宽度（极端：组件还没 build）则放弃，
    // 下次 build 会自然带上正确宽度再走一次 _loadAd。
    final int width = _lastRequestedWidth;
    if (width <= 0) return;
    await _loadAd(width);
  }

  /// 释放当前广告对象并清空引用。
  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    // 必须释放：不 dispose 会在原生侧泄漏一个广告实例，
    // 反复进出页面后 GMA SDK 会报 "Ad is already used" 类错误。
    _disposeAd();
    // 同步摘掉同意状态监听：否则 Notifier 会一直持有本 State 引用，
    // 页面关闭后仍被回调（内存泄漏 + 对已销毁组件 setState 的隐患）。
    if (_consentSubscribed) {
      AdsConsent.revision.removeListener(_onConsentChanged);
      _consentSubscribed = false;
    }
    super.dispose();
  }

  /// 构建：先量宽度再决定请求，然后渲染广告或空盒子。
  ///
  /// 请求广告刻意放在布局阶段而不是 didChangeDependencies —— 后者只能拿到
  /// [MediaQuery] 的**屏幕宽度**，而广告位几乎总是放在带左右 padding 的
  /// 滚动容器里（tools 页 20.w、噪音页 16.w），按屏宽请求会让广告比容器
  /// 宽出 32~40 px、横向溢出一条（控制台报 "overflowed by N pixels"）。
  @override
  Widget build(BuildContext context) {
    // 用 LayoutBuilder 取父容器给出的实际可用宽度（而不是屏宽），
    // 保证请求到的自适应横幅不会超出容器；旋转 / 分屏导致宽度变化时
    // 会重新走 builder，下面的比对会拦住「宽度没变」的重复请求。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        // maxW 为 Infinity 的情况：本组件被放进横向无界容器（如 Row）。
        // 此时回落到屏宽，宁可宽一点也不至于拿不到尺寸。
        final double targetW =
            maxW.isFinite && maxW > 0 ? maxW : MediaQuery.sizeOf(context).width;
        final int width = targetW.truncate();
        if (width > 0 && width != _lastRequestedWidth) {
          _lastRequestedWidth = width;
          // 在 build 里触发是安全的：_loadAd 内部第一个 await 之后才可能
          // setState，不会在构建阶段同步修改状态。
          _loadAd(width);
        }
        return _buildAdOrEmpty(context);
      },
    );
  }

  /// 真正渲染广告或空盒子。
  ///
  /// 抽出来的原因：[build] 已被 [LayoutBuilder] 占用，
  /// 这里只负责「有没有广告可展示」的分支，读起来更清楚。
  Widget _buildAdOrEmpty(BuildContext context) {
    final BannerAd? ad = _bannerAd;
    // 未加载成功 / 平台不支持 / 加载失败：一律零尺寸占位，页面布局不受影响。
    if (!_isLoaded || ad == null || _height <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 「广告 / Ad」小标签：让用户一眼分清这是广告而不是 App 自有内容。
        // 不是 AdMob 的强制要求，但对工具类 App 的口碑是正向的。
        if (widget.labelText != null && widget.labelText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              widget.labelText!,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        // 必须给 AdWidget 一个**确定高度**的容器：
        // AdWidget 是平台视图（Android）/ UIView（iOS），自身没有内在尺寸，
        // 放在无界高的容器里会抛 unbounded height 断言。
        // 外层再包 ExcludeSemantics：平台视图的 RenderObject 在语义收集阶段偶发
        // 仍处于「需要重新布局」状态，会触发框架断言
        // '!childSemantics.renderObject._needsLayout'（控制台刷红字）。广告属装饰性
        // 内容，无需进入无障碍语义树，排除后该断言不再抛出。
        ExcludeSemantics(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: _height,
            child: AdWidget(ad: ad),
          ),
        ),
      ],
    );
  }
}
