// ============================================================================
// 文件：feature/tool/shared/tool_share_service.dart
// 模块：feature/tool/shared（跨子工具复用）
//
// 职责：把「调起系统分享面板」这一件事封装成一处，供各子工具页（水平仪 / 噪音 /
//       直尺 …）复用，避免每个页面各写一遍 share_plus 调用与异常兜底。
//
// 为什么用系统面板而不是各平台 SDK：
//   · 系统面板（iOS UIActivityViewController / Android ACTION_SEND）会列出本机
//     已安装的全部分享目标——微信、朋友圈、微博、QQ、邮件、信息、拷贝等，
//     等于「一次接入，覆盖主要平台」；
//   · 不需要去各家开放平台申请 AppID、不需要配 URL Scheme / 包名白名单，
//     也不会因为 SDK 版本与审核政策变化而返工；
//   · 代价是拿不到「用户到底分享到了哪个平台」的回调（平台方不提供），
//     分析侧只能看「是否分享成功」，不能拆渠道。
//
// 关键依赖：share_plus（^13.3.0）。其 12.0 起改为实例 API：
//           `SharePlus.instance.share(ShareParams(...))`，旧的静态方法 `Share.share()`
//           已移除，升级时不要照抄旧博客的写法。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/l10n/app_localizations.dart';

// ----------------------------------------------------------------------------
// 商店链接：分享 App 介绍时附在正文末尾，接收方点开即可直达商店页。
//   · Android 包名已知，链接可直接写死；
//   · iOS 需要 App Store Connect 上的数字 Apple ID，上架后把 id 填进
//     _kAppStoreUrl（形如 https://apps.apple.com/app/id6740000000）；
//   · 留空表示「这一端暂不附加链接」，正文不会多出空行。
// ----------------------------------------------------------------------------
const String _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=uk.aknot.toolbox';
const String _kAppStoreUrl = ''; // TODO(上架后): 填入 App Store 数字 ID

/// 分享结果。比 bool 多区分一层：用户取消（正常行为，不该打扰）与
/// 真正失败（面板起不来，值得提示）。
enum ToolShareStatus {
  /// 用户选中了某个目标并完成分享。
  success,

  /// 用户主动取消 / 直接关掉面板。最常见，不做任何提示。
  dismissed,

  /// 面板不可用或平台调用抛异常。可以给一次轻量提示。
  failed,
}

/// 工具页分享服务。
///
/// 只暴露静态方法，不持有状态，便于任意页面直接调用。
abstract final class ToolShareService {
  /// 调起系统分享面板分享一段纯文本。
  ///
  /// [text]    分享正文（各平台通用的部分）。
  /// [subject] 邮件 / 部分应用的标题（Android 走 EXTRA_SUBJECT，iOS 部分目标使用）。
  /// [sharePositionOrigin] iPad / Mac 上锚定弹出层的矩形；不传时 iPad 会居中弹出，
  ///           不会报错，但体验略差，建议传入被点击按钮的全局矩形。
  /// [module]  仅用于失败埋点的模块名（如 'level'），便于定位是哪个工具分享失败。
  ///
  /// 返回值见 [ToolShareStatus]：调用方据此决定要不要提示
  /// （用户取消是最常见的结果，不该弹任何提示）。
  ///
  /// ⚠️ 平台通道在极端情况下会抛异常（如无可用分享目标、并发重复调起），
  ///    必须 try/catch 兜住，否则异常冒泡会让整页红屏。
  static Future<ToolShareStatus> shareText({
    required String text,
    String? subject,
    Rect? sharePositionOrigin,
    String module = 'unknown',
  }) async {
    try {
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          // Android 选择器标题与 EXTRA_TITLE 也用 subject，省一个参数。
          title: subject,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return ToolShareStatus.success;
        case ShareResultStatus.dismissed:
          return ToolShareStatus.dismissed;
        case ShareResultStatus.unavailable:
          // 面板不可用（Android 上并发调起时前一个调用也会落到这里）。
          return ToolShareStatus.failed;
      }
    } catch (e, s) {
      // 分享失败不影响主功能，只上报，不向用户抛。
      AppTrack.error('share:$module', e, s);
      return ToolShareStatus.failed;
    }
  }

  /// 分享 **App 介绍**（不是某条测量数据）：拉新传播用。
  ///
  /// 各工具页（水平仪 / 噪音 / 直尺）的分享按钮统一分享这段介绍文案 +
  /// 商店链接，而不是当前读数 —— 读数对接收方毫无上下文，介绍才可能被二次转发。
  ///
  /// [tool]  触发分享的页面标识（'level' / 'noise' / 'ruler'），只用于埋点区分入口。
  /// [sharePositionOrigin] 同 [shareText]。
  /// [onFailed] 需要提示用户时的回调（文案由调用方给，因为 l10n 与 context 在页面侧）。
  static Future<ToolShareStatus> shareAppIntro({
    required BuildContext context,
    required String tool,
    Rect? sharePositionOrigin,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // 商店链接按平台取：iOS 填了才附加，Android 用 Play 链接，其余平台（macOS 等）留空。
    final String link = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _kAppStoreUrl,
      TargetPlatform.android => _kPlayStoreUrl,
      _ => '',
    };

    // 正文：标题 + 空行 + 介绍；有链接再补一行（空链接不补，避免多余空行）。
    final String text = link.isEmpty
        ? '${l10n.appShareSubject}\n\n${l10n.appShareBody}'
        : '${l10n.appShareSubject}\n\n${l10n.appShareBody}\n\n$link';

    final ToolShareStatus status = await shareText(
      text: text,
      subject: l10n.appShareSubject,
      sharePositionOrigin: sharePositionOrigin,
      module: tool,
    );

    // 埋点：只记「从哪个工具页发起 + 是否分享成功」。
    // 不再带 status / calibrated —— 分享的已不是读数，带上去反而误导分析。
    AppTrack.log(
      TrackEvents.toolShare,
      params: <String, Object?>{
        'tool': tool,
        'success': status == ToolShareStatus.success,
      },
    );
    return status;
  }

  /// 计算某 widget 的全局矩形，供 iPad / Mac 锚定分享弹出层。
  ///
  /// 传入的 [key] 必须已挂到目标 widget 上；widget 未挂载时返回 null（调用方
  /// 直接把 null 传给 sharePositionOrigin 即可，系统面板会退化为居中弹出）。
  static Rect? originRectOf(GlobalKey key) {
    final BuildContext? ctx = key.currentContext;
    if (ctx == null) return null;
    final RenderObject? obj = ctx.findRenderObject();
    if (obj is! RenderBox || !obj.attached) return null;
    // localToGlobal 得到左上角，再并上自身尺寸得到完整矩形。
    return obj.localToGlobal(Offset.zero) & obj.size;
  }
}
