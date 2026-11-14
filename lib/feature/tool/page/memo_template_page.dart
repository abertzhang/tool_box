// ============================================================================
// 文件：feature/tool/page/memo_template_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   出行备忘录的「模板」管理页（列表 + 编辑）。
//   · 列表页：展示用户可编辑的模板（首次启动由存储层灌入内置种子模板），
//     支持「使用」（据此新建一条备忘）、「编辑」、「删除」；空状态引导新建。
//   · 编辑页：复用 [KeyValueForm]（标题 + 出行时间 + key-value 表单），
//     保存即 upsert 到 SharedPreferences。
//
// 模板是可编辑的备忘蓝图（用户明确要求「能修改模板」），与备忘录同构但独立存储，
// 不新增 Isar 集合（见 memo_template_store.dart 说明）。
//
// 关键依赖：
//   - flutter_riverpod：memoTemplatesProvider。
//   - isar_community：MemoRecord（「使用模板」落库为备忘）。
//   - memo_fields_form：KeyValueForm / MemoTheme 共用表单与色板。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/feature/tool/data/model/memo_record.dart';
import 'package:tool_box/feature/tool/page/memo_fields_form.dart';
import 'package:tool_box/feature/tool/provider/memo_records_provider.dart';
import 'package:tool_box/feature/tool/provider/memo_template_store.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 模板管理页（列表态）。
///
/// 由备忘录页 AppBar 的「模板」入口 push 进入；「使用模板」后 pop(true) 回备忘录页，
/// 由备忘录页据此弹「已套用模板」提示。
class MemoTemplatePage extends ConsumerWidget {
  /// 创建模板列表页（无参数）。
  const MemoTemplatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MemoTheme theme = MemoTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<MemoTemplate>> templates =
        ref.watch(memoTemplatesProvider);

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.memoCancel,
        ),
        title: Text(l10n.memoTemplateTitle),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        backgroundColor: theme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: TextStyle(color: theme.hintText, fontSize: 13.sp)),
        ),
        data: (List<MemoTemplate> list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.list_alt_outlined, size: 48, color: theme.hintText),
                  SizedBox(height: 12.h),
                  Text(l10n.memoTemplateEmpty,
                      style: TextStyle(color: theme.hintText, fontSize: 14.sp)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 96.h),
            itemCount: list.length,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (ctx, i) => _MemoTemplateCard(
              theme: theme,
              template: list[i],
              onUse: () => _useTemplate(context, ref, list[i]),
              onEdit: () => _openEditor(context, ref, initial: list[i]),
              onDelete: () => _confirmDelete(context, ref, list[i], l10n),
            ),
          );
        },
      ),
    );
  }

  /// 打开模板编辑页（新建或编辑既有）。
  void _openEditor(BuildContext context, WidgetRef ref, {MemoTemplate? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MemoTemplateEditor(initial: initial),
      ),
    );
  }

  /// 「使用模板」：据此新建一条备忘并落库，随后返回备忘录页（pop(true)）。
  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    MemoTemplate t,
  ) async {
    // 先同步捕获 Navigator，避免在 await 后使用 BuildContext 触发告警。
    final NavigatorState navigator = Navigator.of(context);
    final isar = IsarService.instance;
    final DateTime now = DateTime.now();
    final MemoRecord rec = MemoRecord(
      title: t.title,
      content: t.content,
      createdAt: now,
      updatedAt: now,
    );
    await isar.writeTxn(() async {
      await isar.memoRecords.put(rec);
    });
    // 埋点：来源标记 template_apply，便于分析模板复用率（只报标题，不报正文）。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'memo',
        'action': 'template_apply',
        'template': t.title,
      },
    );
    // 失效备忘录列表 Provider，回到备忘录页时自动刷新出新建的备忘。
    ref.invalidate(memoRecordsProvider);
    if (context.mounted) navigator.pop(true);
  }

  /// 删除二次确认。
  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MemoTemplate t,
    AppLocalizations l10n,
  ) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.memoDelete),
        content: Text(l10n.memoTemplateDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.memoCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final List<MemoTemplate> list = List<MemoTemplate>.from(
                  ref.read(memoTemplatesProvider).value ?? <MemoTemplate>[]);
              list.removeWhere((e) => e.id == t.id);
              await saveMemoTemplates(list);
              ref.invalidate(memoTemplatesProvider);
            },
            child: Text(l10n.memoDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 单条模板卡片。
class _MemoTemplateCard extends StatelessWidget {
  /// 创建模板卡片。
  const _MemoTemplateCard({
    required this.theme,
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  /// 双主题色板。
  final MemoTheme theme;

  /// 被展示的模板。
  final MemoTemplate template;

  /// 使用（新建备忘）。
  final VoidCallback onUse;

  /// 编辑。
  final VoidCallback onEdit;

  /// 删除（二次确认）。
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // 取正文首行作为副标题预览（去掉「键：」后缀更干净）。
    final String preview = template.content.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 上：标题 + 预览 + 删除图标。
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        template.title.isEmpty
                            ? l10n.memoUntitled
                            : template.title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.titleText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        preview.isEmpty ? l10n.memoNoContent : preview,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: theme.bodyText,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 20, color: theme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // 下：使用 / 编辑 操作行。
            Row(
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: onUse,
                  icon: const Icon(Icons.file_copy_outlined, size: 16),
                  label: Text(l10n.memoUseTemplate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  ),
                ),
                SizedBox(width: 10.w),
                TextButton(
                  onPressed: onEdit,
                  child: Text(l10n.memoEdit,
                      style: TextStyle(color: theme.accent)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 模板编辑页（新建 / 编辑）。
///
/// 复用 [KeyValueForm]（标题 + 出行时间 + key-value 表单），保存即 upsert
/// 到 SharedPreferences；删除仅编辑态可用。
class _MemoTemplateEditor extends ConsumerStatefulWidget {
  /// 创建模板编辑页。
  const _MemoTemplateEditor({this.initial});

  /// 被编辑的模板（null = 新建）。
  final MemoTemplate? initial;

  @override
  ConsumerState<_MemoTemplateEditor> createState() =>
      _MemoTemplateEditorState();
}

class _MemoTemplateEditorState extends ConsumerState<_MemoTemplateEditor> {
  @override
  Widget build(BuildContext context) {
    final MemoTheme theme = MemoTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isNew = widget.initial == null;
    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: l10n.memoCancel,
        ),
        title: Text(isNew ? l10n.memoNewTemplate : l10n.memoEdit),
      ),
      body: KeyValueForm(
        initialTitle: widget.initial?.title ?? '',
        initialContent: widget.initial?.content ?? '',
        onSave: (title, content) => _save(title, content),
        onDelete: isNew
            ? null
            : () async {
                // 先同步捕获 Navigator，避免在 await 后使用 BuildContext 触发告警。
                final NavigatorState navigator = Navigator.of(context);
                final List<MemoTemplate> list = List<MemoTemplate>.from(
                    ref.read(memoTemplatesProvider).value ?? <MemoTemplate>[]);
                list.removeWhere((e) => e.id == widget.initial!.id);
                await saveMemoTemplates(list);
                ref.invalidate(memoTemplatesProvider);
                if (!mounted) return;
                navigator.pop();
              },
      ),
    );
  }

  /// upsert 模板并回模板列表页。
  Future<void> _save(String title, String content) async {
    final List<MemoTemplate> list = List<MemoTemplate>.from(
        ref.read(memoTemplatesProvider).value ?? <MemoTemplate>[]);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (widget.initial == null) {
      // 新增：用时间戳生成 id。
      list.add(MemoTemplate(
        id: MemoTemplate.newId(),
        title: title,
        content: content,
        updatedAt: nowMs,
      ));
    } else {
      // 编辑：按 id 原地替换，保留 id。
      final int idx = list.indexWhere((e) => e.id == widget.initial!.id);
      if (idx >= 0) {
        list[idx] = MemoTemplate(
          id: widget.initial!.id,
          title: title,
          content: content,
          updatedAt: nowMs,
        );
      }
    }
    await saveMemoTemplates(list);
    ref.invalidate(memoTemplatesProvider);
    if (mounted) Navigator.of(context).pop();
  }
}
