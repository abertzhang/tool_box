// ============================================================================
// 文件：feature/tool/page/memo_fields_form.dart
// 模块：工具箱（tool）
//
// 职责：
//   出行备忘录 / 模板共用的「标题 + 出行时间 + 多行 key-value 表单」组件，
//   以及双主题色板 [MemoTheme]。把这份表单从 memo_page / 模板页抽出来，
//   避免两份逻辑分叉（出行时间解析、key:value 拼装规则必须保持一致）。
//
// 存储约定（与 memo/content 一致，纯文本零风险）：
//   首行可选「出行时间：YYYY-MM-DD HH:MM」前缀，其后每行「key：value」
//   （中文全角冒号分隔）。该约定由 [KeyValueFormState] 负责组装与回显，
//   并由 [parseMemoTravelTime] 供卡片读取出行时间做倒计时徽标。
//
// 关键依赖：
//   - flutter_riverpod：本文件不直接依赖，仅 KeyValueForm 作为纯 UI 组件。
//   - flutter_screenutil_plus：响应式尺寸（.w / .h / .r / .sp）。
//   - AppPalette：双主题 + 色卡语义色来源。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 备忘录 / 模板双主题色板。
///
/// 颜色沿用工具箱既有页面：通用语义色（页面底 / 卡片 / 文字 / 输入框 / 危险色）
/// 取自 [AppPalette]，随「色卡（咖啡 / 蓝）+ 明暗」两个维度变化；
/// 设计稿专属的深色强调色与浅色分隔线在 AppPalette 中无同值字段，保留硬编码。
class MemoTheme {
  /// 创建双主题色板。
  const MemoTheme({
    required this.pageBg,
    required this.cardBg,
    required this.titleText,
    required this.bodyText,
    required this.hintText,
    required this.accent,
    required this.fieldBg,
    required this.divider,
    required this.danger,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 卡片底色（备忘项）。
  final Color cardBg;

  /// 标题文字色（备忘标题、区块标题）。
  final Color titleText;

  /// 正文文字色（备忘预览、说明）。
  final Color bodyText;

  /// 次级提示文字色（占位、日期）。
  final Color hintText;

  /// 强调色（新建按钮、空状态图标）。
  final Color accent;

  /// 输入框底色。
  final Color fieldBg;

  /// 分隔线颜色。
  final Color divider;

  /// 危险操作色（删除）。
  final Color danger;

  /// 按当前主题返回对应色板实例。
  ///
  /// 通用语义色（页面底 / 卡片 / 文字 / 输入框 / 分隔线 / 危险色）统一取自
  /// [AppPalette]，使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」
  /// 两个维度的切换。
  /// 深色强调色 #B87B5C 与浅色分隔线 #E5E0D8 是设计稿专属取值，
  /// [AppPalette] 中无同值字段（coffeeDark.accent 为 #8B5C44、
  /// coffeeLight.divider 为 #E4E0D9），强行套用会造成咖啡色主题下的视觉回归，
  /// 故保留常量。
  static MemoTheme of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return MemoTheme(
        pageBg: app.pageBg,
        cardBg: app.cardBg,
        titleText: app.titleText,
        bodyText: app.bodyText,
        hintText: app.hintText,
        // 深色强调色是设计稿的提亮档，AppPalette 无同值字段。
        accent: const Color(0xFFB87B5C),
        fieldBg: app.fieldBg,
        divider: app.divider,
        danger: app.danger,
      );
    }
    return MemoTheme(
      pageBg: app.pageBg,
      // 浅色下备忘卡为「浮起」的白卡，取抬升卡片色。
      cardBg: app.cardElevated,
      titleText: app.titleText,
      bodyText: app.bodyText,
      hintText: app.hintText,
      accent: app.accent,
      fieldBg: app.fieldBg,
      // 设计稿独立取值，比 AppPalette.divider 略暖一档。
      divider: const Color(0xFFE5E0D8),
      danger: app.danger,
    );
  }
}

/// 出行时间行可能的前缀（中英文，按存储约定用全角冒号分隔）。
///
/// 备忘录 / 模板可能在任一语言下创建，这里两种都尝试匹配，保证跨语言回显时
/// 出行时间不会被误判为普通 key-value 行。
const List<String> _kTravelTimePrefixes = <String>['出行时间：', 'Travel Time：'];

/// 从首行尝试匹配出行时间前缀，命中返回前缀串，否则 null。
String? _matchTravelTimePrefix(String firstLine) {
  for (final String p in _kTravelTimePrefixes) {
    if (firstLine.startsWith(p)) return p;
  }
  return null;
}

/// 从正文解析出行时间。
///
/// 约定首行 `出行时间：YYYY-MM-DD HH:MM`（label 取当前语言，用全角冒号分隔）。
/// 同时兼容中英文两种前缀（模板可能在另一语言下创建）。用于卡片倒计时徽标；
/// 无此前缀返回 null。
DateTime? parseMemoTravelTime(String content, String label) {
  final List<String> lines = content.split('\n');
  if (lines.isEmpty) return null;
  // 先试当前语言前缀，再退到中英文候选，避免单一语言前缀遗漏。
  final List<String> prefixes = <String>['$label：', ..._kTravelTimePrefixes];
  for (final String p in prefixes) {
    if (lines.first.startsWith(p)) {
      return _parseTravelTimeString(lines.first.substring(p.length).trim());
    }
  }
  return null;
}

/// 解析「2026-09-20 08:00」形式的本地时间字符串，格式不符返回 null。
DateTime? _parseTravelTimeString(String s) {
  final RegExpMatch? m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})',
  ).firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
  );
}

/// 新增 / 编辑表单（内联在页面上，非弹框）。
///
/// 由备忘录编辑页或模板编辑页承载：标题 + 出行时间 + 多行 key-value 表单，
/// 默认 6 行、可动态「增加一行」，底部「保存」。出行时间与 key-value 以
/// 约定文本格式拼入正文（[initialContent]），不新增 Isar 列（用户选「拼进正文」方案）。
///
/// 抽出为共用组件后，备忘录与模板使用同一套解析 / 拼装规则，避免分叉。
class KeyValueForm extends StatefulWidget {
  /// 创建内联编辑表单。
  const KeyValueForm({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.onSave,
    this.onDelete,
  });

  /// 初始标题（新建传空串）。
  final String initialTitle;

  /// 初始正文（标题/出行时间/key-value 的约定文本）。
  final String initialContent;

  /// 保存回调（标题 + 正文，已 trim）。
  final Future<void> Function(String title, String content) onSave;

  /// 删除回调（仅编辑既有对象时非 null）。
  final Future<void> Function()? onDelete;

  @override
  State<KeyValueForm> createState() => KeyValueFormState();
}

/// [KeyValueForm] 的状态类（公开，便于父页用 GlobalKey 读取 [assembled] 草稿做分享）。
class KeyValueFormState extends State<KeyValueForm> {
  // 标题输入控制器，编辑态用既有值初始化。
  final TextEditingController _titleCtrl = TextEditingController();
  // 出行时间：拼进正文首行的结构化字段，不单独建 Isar 列（用户选「拼进正文」方案）。
  DateTime? _travelTime;
  // key-value 行：每行一对控制器（左 key / 右 value），默认 6 行，可动态增。
  final List<TextEditingController> _keyCtrls = <TextEditingController>[];
  final List<TextEditingController> _valueCtrls = <TextEditingController>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 仅设置标题初始值。出行时间 / key-value 的解析依赖 Localizations（首行前缀按
    // 当前语言拼接），而 [State.initState] 阶段禁止读取 inherit 依赖（会触发
    // "dependOnInheritedWidgetOfExactType called before initState completed" 断言崩溃），
    // 故延后到 [didChangeDependencies]（inherit 依赖就绪后）首次执行。
    _titleCtrl.text = widget.initialTitle;
  }

  /// 是否已按 [widget.initialContent] 解析并填充过控制器。
  ///
  /// 防止 [didChangeDependencies] 因语言切换等依赖变化被重复调用，导致控制器被
  /// 重复 add（出现重复行）。解析只需在首次进入编辑态时做一次。
  bool _contentParsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contentParsed) return;
    _contentParsed = true;
    if (widget.initialContent.isNotEmpty) {
      // 解析正文：首行「出行时间」前缀（中英文都尝试）+ 其余 key:value 行，便于编辑回显。
      final (DateTime? time, List<(String, String)> rows) =
          _splitContent(widget.initialContent);
      _travelTime = time;
      for (final (String k, String v) in rows) {
        _keyCtrls.add(TextEditingController(text: k));
        _valueCtrls.add(TextEditingController(text: v));
      }
    }
    // 保证至少 6 行 key-value（默认六行）。
    while (_keyCtrls.length < 6) {
      _keyCtrls.add(TextEditingController());
      _valueCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final TextEditingController c in _keyCtrls) {
      c.dispose();
    }
    for (final TextEditingController c in _valueCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  /// 当前表单组装结果（标题 + 正文），供父页「分享」等场景读取草稿。
  (String, String) get assembled {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String title = _titleCtrl.text.trim();
    final StringBuffer buf = StringBuffer();
    if (_travelTime != null) {
      buf.writeln(
          '${l10n.memoTravelTime}：${_formatTravelTime(_travelTime!)}');
    }
    for (int i = 0; i < _keyCtrls.length; i++) {
      final String k = _keyCtrls[i].text.trim();
      final String v = _valueCtrls[i].text.trim();
      if (k.isEmpty && v.isEmpty) continue;
      buf.writeln('$k：$v');
    }
    return (
      title.isEmpty ? l10n.memoUntitled : title,
      buf.toString().trim(),
    );
  }

  /// 把出行时间格式化为本地时间字符串（与卡片显示格式一致）。
  String _formatTravelTime(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)} '
        '${pad(d.hour)}:${pad(d.minute)}';
  }

  /// 从正文解析出行时间 + key:value 行。
  ///
  /// 约定格式：首行可选「出行时间：…」前缀，其后每行「key：value」。
  /// 用于编辑态回显。出行时间前缀兼容中英文（创建模板时的语言可能与当前不同）。
  (DateTime?, List<(String, String)>) _splitContent(String content) {
    final List<String> lines = content.split('\n');
    DateTime? time;
    int start = 0;
    if (lines.isNotEmpty) {
      // 出行时间前缀兼容中英文（创建模板时的语言可能与当前不同）。
      final String? prefix = _matchTravelTimePrefix(lines.first);
      if (prefix != null) {
        time = _parseTravelTimeString(lines.first.substring(prefix.length).trim());
        start = 1;
      }
    }
    final List<(String, String)> rows = <(String, String)>[];
    for (int i = start; i < lines.length; i++) {
      final String line = lines[i];
      if (line.trim().isEmpty) continue;
      final int idx = line.indexOf('：');
      if (idx >= 0) {
        rows.add((line.substring(0, idx).trim(), line.substring(idx + 1).trim()));
      } else {
        // 无冒号视为只有 key（值为空）。
        rows.add((line.trim(), ''));
      }
    }
    return (time, rows);
  }

  /// 新增一行 key-value 输入（在 setState 中追加一对控制器）。
  void _addRow() {
    setState(() {
      _keyCtrls.add(TextEditingController());
      _valueCtrls.add(TextEditingController());
    });
  }

  /// 弹出日期 + 时间选择器，写入出行时间。
  Future<void> _pickTravelTime() async {
    final DateTime now = DateTime.now();
    final DateTime base = _travelTime ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _travelTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// 保存：trim 后若标题为空则回退为「无标题」，出行时间拼回正文首行，
  /// 交给父级落库并关闭编辑态。
  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final (String title, String content) = assembled;
    await widget.onSave(title, content);
    // 关闭编辑态由父级 setState 处理（onSave 内已调用 _closeEditor）。
  }

  /// 删除：执行回调后由父级退出编辑态。
  Future<void> _handleDelete() async {
    if (widget.onDelete == null) return;
    await widget.onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    final MemoTheme theme = MemoTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      // 内联页面表单：整页可滚动，无需限制最大高度或键盘 inset 兜底。
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 第一行：左侧「标题」标签 + 右侧标题输入框（编辑态右侧附删除）。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 72.w,
                child: Text(l10n.memoFieldTitle,
                    style: TextStyle(fontSize: 14.sp, color: theme.titleText)),
              ),
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  style: TextStyle(color: theme.titleText, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: l10n.memoTitleHint,
                    hintStyle: TextStyle(color: theme.hintText, fontSize: 14.sp),
                    filled: true,
                    fillColor: theme.fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  ),
                ),
              ),
              // 删除（仅编辑态可见），贴标题行右侧。
              if (widget.onDelete != null)
                IconButton(
                  onPressed: _handleDelete,
                  icon: Icon(Icons.delete_outline, size: 20, color: theme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          // 第二行：左侧「出行时间」标签 + 右侧时间选择框（点开选日期/时间）。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 72.w,
                child: Text(l10n.memoTravelTime,
                    style: TextStyle(fontSize: 14.sp, color: theme.titleText)),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickTravelTime,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: theme.fieldBg,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      _travelTime == null
                          ? l10n.memoTravelTimeHint
                          : _formatTravelTime(_travelTime!),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: _travelTime == null
                            ? theme.hintText
                            : theme.titleText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // 第三行起：每行左侧 key、右侧 value 的 key-value 表单（默认六行）。
          for (int i = 0; i < _keyCtrls.length; i++) ...<Widget>[
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _keyCtrls[i],
                    style: TextStyle(color: theme.titleText, fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: l10n.memoKeyHint,
                      hintStyle: TextStyle(color: theme.hintText, fontSize: 14.sp),
                      filled: true,
                      fillColor: theme.fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _valueCtrls[i],
                    style: TextStyle(color: theme.titleText, fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: l10n.memoValueHint,
                      hintStyle: TextStyle(color: theme.hintText, fontSize: 14.sp),
                      filled: true,
                      fillColor: theme.fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20.h),
          // 底部：左侧「增加一行」，右侧「保存」。
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: _addRow,
                icon: Icon(Icons.add, color: theme.accent, size: 18),
                label: Text(l10n.memoAddRow, style: TextStyle(color: theme.accent)),
              ),
              const Spacer(),
              // 保存。
              ElevatedButton(
                onPressed: _saving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(l10n.memoSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
