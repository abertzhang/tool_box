import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../constants/app_box.dart';

/// 文件职责：以 Riverpod 管理应用当前语言代码（locale），并与 Hive 持久化打通。
///
/// 所属模块：common/provider/locale（国际化状态层）。
/// 关键依赖：[flutter_riverpod]、[hive]、[AppBox]（统一 Box 名称）。
///
/// 说明：语言代码以字符串形式持久化在 [AppBox.boxName] 指定的 Box 的
/// `locale` 键下。**无记录时默认英语**（2026-11-07 产品决策调整：此前为「跟随系统语言」），
/// 取值优先级见 [LocaleNotifier.build]。
///
/// ⚠️ 边界：本 Provider 只管 App **内部**界面语言，管不到 iOS 原生权限弹窗 ——
/// 弹窗由系统按「系统语言」解析 App bundle 的 `.lproj/InfoPlist.strings`，
/// 在 App 内切语言不会改变弹窗语种。

/// 支持的语言代码常量：App 现有「英文 / 中文 / 日文 / 德文 / 法文」五套文案。
const String _langEn = 'en';
const String _langZh = 'zh';
const String _langJa = 'ja';
const String _langDe = 'de';
const String _langFr = 'fr';

/// Hive 中语言记录的键。
const String _localeKey = 'locale';

/// 语言状态 Provider，状态值为当前语言代码字符串（如 `en` / `zh` / `ja`）。
final localeProvider = NotifierProvider<LocaleNotifier, String>(
  LocaleNotifier.new,
);

/// 语言状态管理者，负责恢复与更新持久化的语言代码。
class LocaleNotifier extends Notifier<String> {
  final Box _box = Hive.box(AppBox.boxName);

  @override
  String build() {
    // 1) 手动选择优先：用户在资料页切过语言就以记录值为准，系统语言再变也不覆盖。
    final saved = _box.get(_localeKey) as String?;
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    // 2) 无记录（首次启动 / 从未手动切过）：默认英语。
    //
    // 2026-11-07 产品决策调整：此前此处跟随系统语言（中文系统用户会看到中文界面），
    // 现改为默认英语，符合 App 出海默认英文的取向。「跟随系统」能力仍保留在
    // [followSystem] 中，未来若需在设置页提供「跟随系统」入口可直接接入，
    // 不会破坏既有逻辑。
    return _langEn;
  }

  /// 切换语言并持久化。
  ///
  /// 参数：[lang] 目标语言代码，会写入 Hive 的 `locale` 键，
  /// 并更新 [Notifier.state] 触发 UI 重建。
  Future<void> setLanguage(String lang) async {
    await _box.put(_localeKey, lang);
    state = lang;
  }

  /// 恢复「跟随系统语言」：清掉手动记录，状态重算为系统语言。
  ///
  /// 用途：日后资料页若加「跟随系统」选项可直接复用；当前未被 UI 调用，
  /// 保留以便用户改系统语言后能回到跟随态，不必清 App 数据。
  Future<void> followSystem() async {
    await _box.delete(_localeKey);
    state = _resolveSystemLanguage();
  }

  /// 从系统首选语言列表解析出本 App 支持的语言代码。
  ///
  /// 规则：
  ///   - 命中 `zh`（含 zh-Hans / zh-Hant / zh-CN 等）→ 用中文。
  ///     繁体目前复用简体文案（App 只有一套中文资源），后续补繁体再细分。
  ///   - 命中 `ja` → 用日文；命中 `de` → 用德文；命中 `fr` → 用法文；
  ///     命中 `en` → 用英文。
  ///   - 其它语种 → 统一回落英文，避免落到不存在的文案。
  ///
  /// 为什么遍历 [PlatformDispatcher.locales] 而不是只看 [PlatformDispatcher.locale]：
  /// 前者是系统「首选语言」的有序列表，用户排了「繁中 → 英文」时只看第一个
  /// 可能错过可读的英文；按顺序取第一个能命中的更稳。
  static String _resolveSystemLanguage() {
    for (final locale in PlatformDispatcher.instance.locales) {
      final code = locale.languageCode.toLowerCase();
      if (code.startsWith(_langZh)) {
        return _langZh;
      }
      if (code == _langJa) {
        return _langJa;
      }
      if (code == _langDe) {
        return _langDe;
      }
      if (code == _langFr) {
        return _langFr;
      }
      if (code == _langEn) {
        return _langEn;
      }
    }
    return _langEn;
  }
}
