// ============================================================================
// 文件：feature/profile/page/web_doc_page.dart
// 模块：个人中心（profile）/ 在线文档页（App 内 WebView 容器）
//
// 职责：
//   用一个 App 内 WebView 展示指定 URL。首个用途是「用户协议」
//   （原在线地址 https://www.aknot.uk/app/tool-box?type=1，已废弃——该域名至今
//   无 A 记录无法解析；2026-09-17 起在线文档改托管到 GitHub Pages，见
//   profile_page 的 [_privacyPolicyUrl]），由资料页「关于」分组的「用户协议」行
//   push 进入。
//
//   刻意做成**通用容器**（标题 / 地址 / 埋点标识全部由外部传入），而不是写死一个
//   协议页：将来隐私政策、帮助中心若也要迁到在线网页，直接复用本页即可，无需复制。
//
// 设计取舍：
//   1. **为什么不跳外部浏览器**：url_launcher 会把用户切到 Safari / Chrome，返回
//      要靠系统手势，读完很难回到原处；App 内 WebView 保留 AppBar 与返回键形成闭环，
//      也是协议类内容「应在 App 内可读」的通行做法。
//   2. **⚠️ webview_flutter 只支持 Android / iOS / macOS**：插件 pubspec 只为这三端
//      指定了 default_package（macOS 走 webview_flutter_wkwebview 的 Darwin 共享源码），
//      Windows / Linux / Web 端均无实现，构造 WebViewController 会抛
//      MissingPluginException（类比 google_mobile_ads，必须先判平台）。
//      故按 [defaultTargetPlatform] 分流：受支持的三端渲染 WebView，其余降级成
//      「不支持 + 展示网址」的提示页，而不是让整页崩掉。
//      ⚠️ macOS 还依赖签名权限 **Outgoing Connections (Client)**
//      （com.apple.security.network.client）：缺它时沙箱拦掉全部出站请求，
//      WebView 表现为「加载失败」而非报错；已在 macos/Runner/*.entitlements 补齐。
//   3. **controller 只在 initState 建一次**：build 会因切主题 / 切语言而重建，
//      若把 loadRequest 放进 build，每次重建都会刷新网页、丢掉用户的阅读位置。
//   4. **加载态与错误态可见**：顶部线性进度条跟随 onProgress；资源加载失败
//      （onWebResourceError）落到错误页并提供重试（reload），
//      避免用户只看到一片空白、不知道是网络问题还是功能坏了。
//   5. **埋点**：入页记一次 page_doc_view（page 标识由外部传），与隐私政策 /
//      第三方 SDK 清单等文档页口径一致；写在 initState 而非 build，防止重复上报。
//
// 关键依赖：
//   - webview_flutter：WebViewController / WebViewWidget（仅 Android / iOS）；
//   - go_router：路径由 feature/profile/routes/route_profile.dart 登记；
//   - app_track / track_events：到达埋点 page_doc_view。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../common/provider/locale/locale_provider.dart';

/// 当前平台是否被 webview_flutter 支持。
///
/// 插件 4.14.1 的 pubspec 只为三端指定了实现：**Android / iOS / macOS**
/// （macOS 复用 webview_flutter_wkwebview 的 sharedDarwinSource 源码）；
/// Windows / Linux / Web 端均无实现，构造 WebViewController 会抛
/// MissingPluginException，故必须先判平台再决定是否创建 controller。
bool _isWebViewSupported() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// App 内在线文档页（WebView 容器）。
///
/// 用法：由路由把「标题 + 地址 + 埋点页面标识」经 extra 透传进来，
/// 本页只负责渲染与容错，不关心具体内容是什么协议。
class WebDocPage extends ConsumerStatefulWidget {
  /// 创建在线文档页。
  const WebDocPage({
    super.key,
    required this.title,
    required this.url,
    required this.trackPage,
  });

  /// AppBar 标题（由调用方传入，通常直接用已本地化的行标题）。
  final String title;

  /// 要展示的网页地址（必须带 scheme，如 `https://`）。
  final String url;

  /// 埋点用的稳定页面标识（如 `user_agreement`），用于页面到达统计。
  final String trackPage;

  @override
  ConsumerState<WebDocPage> createState() => _WebDocPageState();
}

class _WebDocPageState extends ConsumerState<WebDocPage> {
  /// WebView 控制器。桌面端不支持时为 null（走降级视图）。
  WebViewController? _controller;

  /// 当前加载进度（0~100），驱动顶部进度条。
  int _progress = 0;

  /// 资源加载失败的描述文案；非 null 时渲染错误态而不是网页。
  String? _errorText;

  /// 失败时的平台原生错误码（如 Android 的 `net::ERR_NAME_NOT_RESOLVED`
  /// 对应 -105），仅用于错误页展示与排查，不参与任何逻辑判断。
  int? _errorCode;

  /// 地址非法 / 缺失（路由 extra 丢失或调用方漏传）时为 true。
  ///
  /// 此时**不创建** controller：空地址传给 loadRequest 会在原生侧抛异常，
  /// 与其让页面红屏，不如落到错误态明确告诉用户「没拿到地址」。
  /// 该路径下 controller 恒为 null，错误页据此隐藏「重试」按钮。
  bool _invalidUrl = false;

  @override
  void initState() {
    super.initState();

    // 到达埋点：证明该在线文档被真正打开过，并带上语言便于分区观察。
    // 与隐私政策 / 第三方 SDK 清单等文档页同口径；放在 initState 避免 build 重建重复上报。
    // ref.read 在 initState 中允许（watch 才不允许）。
    AppTrack.log(
      TrackEvents.pageDocView,
      params: <String, Object?>{
        'page': widget.trackPage,
        'locale': ref.read(localeProvider),
      },
    );

    // 桌面端不创建 controller：构造它就会抛 MissingPluginException。
    if (!_isWebViewSupported()) return;

    // 空地址直接转错误态（详见 [_invalidUrl] 说明），不往下建 controller。
    if (widget.url.trim().isEmpty) {
      _invalidUrl = true;
      return;
    }

    _controller = WebViewController()
      // 托管页面普遍依赖 JS 做排版与交互，禁用会导致页面白屏或功能残缺。
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // 进度回调：0~100，用于顶部进度条。
          onProgress: (int value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          // 加载完成：把进度补满，进度条随之隐藏。
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _progress = 100;
              // ⚠️ 页面加载完成即视为成功，抹掉此前可能存在的失败标记。
              // 真实场景：先有子资源报错把页面切到错误态，随后主文档加载完成 ——
              // 若不清掉，就会永久卡在失败页，连「重试」也回不来。
              _errorText = null;
              _errorCode = null;
            });
          },
          // 加载失败：记下描述文案并切到错误态（提供重试入口）。
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            // ⚠️ 只有**主文档**失败才算整页失败。favicon、CSS、图片等子资源
            // 报错在真实站点上很常见（例如 favicon 404、iOS 的 -999 取消），
            // 若一并判死，页面明明能正常显示却被换成失败页。
            // isForMainFrame 为 null 说明平台实现未上报该字段，此时按主文档处理，
            // 宁可多报一次也不能漏掉真正打不开的页面。
            if (error.isForMainFrame == false) return;
            setState(() {
              // 少数情况下 description 为空，兜一句通用失败文案由外层标题承担。
              _errorText = error.description;
              _errorCode = error.errorCode;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: <Widget>[
          // 顶部加载进度条：仅在「移动端 + 加载中 + 未出错」时占位 2px。
          // 完成后 progress 到 100 自然隐藏，不会挤压正文布局。
          if (_controller != null && _errorText == null && _progress < 100)
            LinearProgressIndicator(
              // 进度为 0（刚开始）时传 null，显示不确定动画比显示空条更自然。
              value: _progress > 0 ? _progress / 100 : null,
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// 主体内容：按「平台是否支持 → 是否出错」两级分流。
  Widget _buildBody(BuildContext context) {
    // ① 桌面端：webview_flutter 无实现，降级为提示 + 网址（可长按复制）。
    if (!_isWebViewSupported()) return _buildUnsupported(context);

    // ② 地址缺失（extra 丢失）或资源加载出错：都落到错误态，
    //    让用户看到「为什么是空白」而不是对着白屏发呆。
    if (_invalidUrl || _errorText != null) return _buildError(context);

    // ③ 正常（含首帧尚未建完的极短瞬间）：渲染 WebView。
    final WebViewController? controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: controller);
  }

  /// 桌面端降级视图：说明不支持，并把完整网址展示出来供用户自行在浏览器打开。
  Widget _buildUnsupported(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.language_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              l10n.webUnsupported,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // 网址可长按选中复制 —— 桌面端用户据此去浏览器打开。
            SelectableText(
              widget.url,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载失败视图：失败原因 + 重新加载按钮。
  Widget _buildError(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              l10n.webLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            // 原始错误描述：给排查留线索（如域名不可达 / SSL 失败）。
            if (_errorText != null && _errorText!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
            // 原生错误码：与上面的描述配套，便于直接对照平台文档定位
            // （如 Android -105 = ERR_NAME_NOT_RESOLVED，即域名解析失败）。
            if (_errorCode != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'code: $_errorCode',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
            // 目标地址：域名写错 / 站点未上线时，一眼就能看出来。
            const SizedBox(height: 8),
            SelectableText(
              widget.url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            // 重试按钮仅在 controller 存在时给：地址本身就是错的
            // （_invalidUrl）时 controller 为 null，重试没有意义，藏起来。
            if (_controller != null) ...<Widget>[
              const SizedBox(height: 20),
              OutlinedButton(
                // profileRetry 语义是通用的「重试」，与资料加载失败共用同一词条。
                onPressed: () {
                  setState(() {
                    _errorText = null;
                    _errorCode = null;
                    _progress = 0;
                  });
                  _controller?.reload();
                },
                child: Text(l10n.profileRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
