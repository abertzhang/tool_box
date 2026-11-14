// ============================================================================
// 文件：feature/tool/page/memo_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   出行备忘录页。用户可新建 / 编辑 / 删除备忘（标题 + 正文），
//   数据持久化到 Isar（memoRecords 集合），列表按最后更新时间倒序展示。
//   新增 / 编辑表单直接内联在页面上（列表态 ↔ 编辑态切换），不弹底部抽屉；
//   删除走二次确认 + SnackBar 撤销；卡片显示出行时间倒计时徽标，
//   并支持「复制到剪贴板」与「存为模板」（按本条内容生成 `Template_原名` 模板）。
//
// 设计稿：
//   无独立 Pixso 稿，沿用工具箱既有双主题配色（浅 #F5F3EF / 深 #1C1C1E
//   页面底，卡片 #FFFFFF / #2C2C2E，强调棕 #8B5C44 / 浅棕 #E0926D），
//   与单位换算、长度计算器等视觉一致。
//
// 关键依赖：
//   - flutter_riverpod：ConsumerStatefulWidget + FutureProvider（memoRecordsProvider）。
//   - isar_community：MemoRecord 集合的读写（经 IsarService 单例）。
//   - memo_fields_form：共用表单 [KeyValueForm] 与色板 [MemoTheme]。
//   - tool_share_service：系统分享面板封装（复用既有分享能力）。
//   - flutter_screenutil_plus：响应式尺寸（.w / .h / .r / .sp）。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/shared/tool_share_service.dart';
import 'package:tool_box/feature/tool/data/model/memo_record.dart';
import 'package:tool_box/feature/tool/page/memo_fields_form.dart';
import 'package:tool_box/feature/tool/page/memo_template_page.dart';
import 'package:tool_box/feature/tool/provider/memo_records_provider.dart';
import 'package:tool_box/feature/tool/provider/memo_template_store.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 出行备忘录页。
///
/// 以 ConsumerStatefulWidget 维护「列表态 / 编辑态」切换：列表态渲染备忘列表，
/// 编辑态直接在页面上展开新增 / 编辑表单（不再弹底部抽屉）。
class MemoPage extends ConsumerStatefulWidget {
  /// 创建备忘录页（无参数）。
  const MemoPage({super.key});

  @override
  ConsumerState<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends ConsumerState<MemoPage> {
  // 编辑态：_editing 非 null 或 _isNew 为真时，页面展示内联编辑表单；
  // 两者皆假时展示列表。_editing 为正在编辑的既有备忘（新建时为 null）。
  MemoRecord? _editing;
  bool _isNew = false;

  // 展开态：当前展开（手风琴）的备忘 id；null 表示全部收起。
  // 同一时刻只展开一条，点击已展开项则收起，点其他项切换并收起其余。
  int? _expandedId;

  // 编辑态表单的全局 key，用于「分享」时读取当前草稿（标题 + 正文）。
  final GlobalKey<KeyValueFormState> _formKey = GlobalKey<KeyValueFormState>();

  /// 进入新建表单。
  void _startNew() => setState(() {
        _editing = null;
        _isNew = true;
      });

  /// 进入编辑表单（编辑既有备忘）。
  void _startEdit(MemoRecord memo) => setState(() {
        _editing = memo;
        _isNew = false;
      });

  /// 退出编辑态，回到列表。
  void _closeEditor() => setState(() {
        _editing = null;
        _isNew = false;
      });

  /// 手风琴式展开/收起某条备忘：点已展开项收起，点其他项则切换并收起其余。
  void _toggleExpand(int id) => setState(() {
        _expandedId = _expandedId == id ? null : id;
      });

  @override
  Widget build(BuildContext context) {
    final MemoTheme theme = MemoTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // 编辑态：直接把表单铺在页面上（带关闭 + 分享的 AppBar）。
    if (_editing != null || _isNew) {
      return Scaffold(
        backgroundColor: theme.pageBg,
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            onPressed: _closeEditor,
            icon: const Icon(Icons.close),
            tooltip: l10n.memoCancel,
          ),
          title: Text(_isNew ? l10n.memoAdd : l10n.memoEdit),
          actions: <Widget>[
            // 分享当前草稿（未保存也能分享，便于随身带走）。
            IconButton(
              onPressed: _shareDraft,
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.memoShare,
            ),
          ],
        ),
        body: KeyValueForm(
          key: _formKey,
          initialTitle: _editing?.title ?? '',
          initialContent: _editing?.content ?? '',
          onSave: (title, content) async {
            // 新建传 null（_saveMemo 内部建档），编辑传既有对象（原地更新）。
            await _saveMemo(ref, _isNew ? null : _editing, title, content);
            ref.invalidate(memoRecordsProvider);
            _closeEditor();
          },
          onDelete: _isNew
              ? null
              : () async {
                  await _deleteWithUndo(ref, _editing!);
                  _closeEditor();
                },
        ),
      );
    }

    // 列表态：订阅 memoRecordsProvider 渲染备忘卡片列表。
    final AsyncValue<List<MemoRecord>> memos =
        ref.watch(memoRecordsProvider);

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.memoTitle),
        actions: <Widget>[
          // 进入模板管理页（可编辑模板）。
          IconButton(
            onPressed: _openTemplates,
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: l10n.memoTemplateTitle,
          ),
        ],
      ),
      // 右下角浮动按钮：新建一条备忘（进入编辑态）。
      floatingActionButton: FloatingActionButton(
        onPressed: _startNew,
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: memos.when(
        // 加载中：居中转圈。
        loading: () => const Center(child: CircularProgressIndicator()),
        // 出错：简短提示（不阻塞页面其余功能）。
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: TextStyle(color: theme.hintText, fontSize: 13.sp),
          ),
        ),
        data: (List<MemoRecord> list) {
          if (list.isEmpty) {
            // 空状态：引导用户点击右下角新建（按钮直达编辑态）。
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.note_alt_outlined, size: 48, color: theme.hintText),
                  SizedBox(height: 12.h),
                  Text(
                    l10n.memoEmpty,
                    style: TextStyle(color: theme.hintText, fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: _startNew,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.memoAdd),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // 列表：每条备忘一张卡片，点击进入编辑。
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 96.h),
            itemCount: list.length,
            separatorBuilder: (_, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final MemoRecord memo = list[index];
              return _MemoCard(
                theme: theme,
                memo: memo,
                expanded: _expandedId == memo.id,
                onToggle: () => _toggleExpand(memo.id),
                onTap: () => _startEdit(memo),
                onCopy: () => _copyMemo(memo),
                onSaveAsTemplate: () => _saveAsTemplate(memo),
                onDelete: () => _confirmDelete(context, ref, memo, l10n),
              );
            },
          );
        },
      ),
    );
  }

  /// 打开模板管理页；使用模板返回 true 时弹「已套用模板」提示。
  Future<void> _openTemplates() async {
    final dynamic res = await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const MemoTemplatePage()),
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.memoTemplateApplied)),
      );
    }
  }

  /// 分享当前编辑中的草稿（编辑态 AppBar 分享按钮）。
  void _shareDraft() {
    final KeyValueFormState? state = _formKey.currentState;
    if (state == null) return;
    final (String title, String content) = state.assembled;
    _shareText(title, content);
  }

  /// 复制一条已保存的备忘（标题 + 正文）到剪贴板，并弹「已复制」提示。
  Future<void> _copyMemo(MemoRecord memo) async {
    final String text = '${memo.title}\n\n${memo.content}';
    await Clipboard.setData(ClipboardData(text: text));
    // 复制为即时操作，await 后先判 mounted 再碰 context，规避异步间隙告警。
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.memoCopied)),
    );
  }

  /// 把一条已保存的备忘「存为模板」（卡片模板按钮）。
  ///
  /// 标题加 `Template_` 前缀、正文原样复制进模板库；同名派生模板会被覆盖更新，
  /// 连点不会产生重复项。完成后弹「已生成模板：xxx」提示。
  Future<void> _saveAsTemplate(MemoRecord memo) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // 异步前先捕获 Messenger 与文案，避免 await 后跨间隙使用 BuildContext。
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String title = await createTemplateFromMemo(
      memoTitle: memo.title,
      memoContent: memo.content,
      untitledFallback: l10n.memoUntitled,
    );
    // 模板列表 Provider 失效，模板管理页下次进入即读到刚生成的模板。
    ref.invalidate(memoTemplatesProvider);
    // 埋点：模板生成量（只报正文字数桶，模板标题与正文原文绝不上报）。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'memo',
        'action': 'template_create',
        'len_bucket': TrackBuckets.textLength(memo.content.trim().length),
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.memoTemplateCreated}：$title')),
    );
  }

  /// 组装分享文本并调起系统分享面板（复用既有 ToolShareService）。
  Future<void> _shareText(String title, String content) async {
    final String text = '$title\n\n$content';
    await ToolShareService.shareText(
      text: text,
      subject: title,
      module: 'memo',
    );
  }

  /// 落库一条备忘（新增或更新）。
  Future<void> _saveMemo(
    WidgetRef ref,
    MemoRecord? existing,
    String title,
    String content,
  ) async {
    final isar = IsarService.instance;
    final DateTime now = DateTime.now();
    if (existing == null) {
      // 新增：创建时间 = 更新时间 = 当前时间。
      final MemoRecord rec = MemoRecord(
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
      );
      await isar.writeTxn(() async {
        await isar.memoRecords.put(rec);
      });
    } else {
      // 编辑：保留原创建时间，刷新更新时间。
      existing.title = title;
      existing.content = content;
      existing.updatedAt = now;
      await isar.writeTxn(() async {
        await isar.memoRecords.put(existing);
      });
    }

    // 保存埋点：内容型功能的创作量，决定是否值得做搜索 / 云同步。
    // 只上传正文字数桶与「有否标题」，正文与标题原文绝不上报（隐私红线）。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'memo',
        'action': existing == null ? 'create' : 'update',
        'has_title': title.trim().isNotEmpty,
        'len_bucket': TrackBuckets.textLength(content.trim().length),
      },
    );
  }

  /// 删除一条备忘，并弹 SnackBar 支持「撤销」（撤销即把原对象按 id 写回）。
  Future<void> _deleteWithUndo(WidgetRef ref, MemoRecord memo) async {
    final isar = IsarService.instance;
    // 删除前保留原对象引用（id 不变），撤销时直接 put 回去即可还原。
    await isar.writeTxn(() async {
      await isar.memoRecords.delete(memo.id);
    });
    ref.invalidate(memoRecordsProvider);

    final int remaining = (ref.read(memoRecordsProvider).value?.length ?? 0);
    AppTrack.log(
      TrackEvents.toolDataDeleted,
      params: <String, Object?>{
        'tool': 'memo',
        'remaining': remaining,
      },
    );

    // 撤销提示：用户点「撤销」则把原备忘对象写回（同 id 还原）。
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.memoDeleted),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.memoUndo,
          onPressed: () async {
            await isar.writeTxn(() async {
              await isar.memoRecords.put(memo);
            });
            ref.invalidate(memoRecordsProvider);
          },
        ),
      ),
    );
  }

  /// 删除二次确认（确认后走 _deleteWithUndo，支持撤销）。
  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MemoRecord memo,
    AppLocalizations l10n,
  ) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.memoDelete),
        content: Text(l10n.memoDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.memoCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteWithUndo(ref, memo);
            },
            child: Text(
              l10n.memoDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条备忘卡片。
class _MemoCard extends StatelessWidget {
  /// 创建备忘卡片。
  const _MemoCard({
    required this.theme,
    required this.memo,
    required this.expanded,
    required this.onToggle,
    required this.onTap,
    required this.onCopy,
    required this.onSaveAsTemplate,
    required this.onDelete,
  });

  /// 双主题色板。
  final MemoTheme theme;

  /// 被展示的备忘。
  final MemoRecord memo;

  /// 是否已展开（手风琴：本卡片是否当前展开项）。
  final bool expanded;

  /// 点击标题右侧箭头：展开/收起本卡片。
  final VoidCallback onToggle;

  /// 点击（进入编辑）。
  final VoidCallback onTap;

  /// 复制（标题 + 正文写入剪贴板）。
  final VoidCallback onCopy;

  /// 存为模板（按本条内容生成一个模板，标题加 `Template_` 前缀）。
  final VoidCallback onSaveAsTemplate;

  /// 删除（二次确认）。
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // 出行时间倒计时徽标：从正文首行解析出行时间，计算与今天的差值。
    final DateTime? travel =
        parseMemoTravelTime(memo.content, l10n.memoTravelTime);
    final String? badge = _travelBadge(travel, l10n);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 左：标题 + 预览 + 徽标/日期。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 标题行：标题 + 右侧展开箭头（手风琴，点箭头只切换展开）。
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              memo.title.isEmpty
                                  ? l10n.memoUntitled
                                  : memo.title,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.titleText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 展开/收起箭头：点击只触发展开切换，不进编辑态。
                          IconButton(
                            onPressed: onToggle,
                            icon: AnimatedRotation(
                              turns: expanded ? -0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                size: 22,
                                color: theme.hintText,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: expanded ? l10n.memoCollapse : l10n.memoExpand,
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // 正文：展开态显示完整内容，收起态仅两行预览。
                      Text(
                        memo.content.isEmpty
                            ? l10n.memoNoContent
                            : memo.content,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: theme.bodyText,
                          height: 1.4,
                        ),
                        maxLines: expanded ? null : 2,
                        overflow:
                            expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      // 出行倒计时徽标（若有）与更新时间并排。
                      Row(
                        children: <Widget>[
                          if (badge != null) ...<Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: theme.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: theme.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                          ],
                          Text(
                            _formatDate(memo.updatedAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.hintText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 右：复制 / 存为模板 / 删除（均为独立 IconButton，不触发卡片点击）。
                // 顺序即用户要求：模板图标紧邻复制图标右侧；删除仍在最右，
                // 且有二次确认兜底，误触不会直接丢数据。
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: onCopy,
                      icon: Icon(Icons.copy_outlined, size: 20, color: theme.hintText),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: l10n.memoCopy,
                    ),
                    SizedBox(width: 6.w),
                    IconButton(
                      onPressed: onSaveAsTemplate,
                      icon: Icon(
                        Icons.list_alt_outlined,
                        size: 20,
                        color: theme.hintText,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: l10n.memoSaveAsTemplate,
                    ),
                    SizedBox(width: 6.w),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 20, color: theme.danger),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 计算出行倒计时文案：还有 N 天 / 今天出发 / 已出发；无出行时间返回 null。
  String? _travelBadge(DateTime? travel, AppLocalizations l10n) {
    if (travel == null) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tday = DateTime(travel.year, travel.month, travel.day);
    final int diff = tday.difference(today).inDays;
    if (diff > 0) {
      return '${l10n.memoDaysLeftPrefix}$diff${l10n.memoDaysLeftSuffix}';
    } else if (diff == 0) {
      return l10n.memoTodayDepart;
    }
    return l10n.memoDeparted;
  }

  /// 日期格式化（不引 intl，规避 ruler_page 同款 TextDirection 遮蔽）。
  ///
  /// 输出形如 `2026-08-09 16:30` 的本地时间字符串。
  String _formatDate(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)} '
        '${pad(d.hour)}:${pad(d.minute)}';
  }
}
