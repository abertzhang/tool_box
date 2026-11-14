// ============================================================================
// 文件：feature/tool/provider/memo_template_store.dart
// 模块：工具箱（tool）
//
// 职责：
//   出行备忘录「模板」的本地存储与读取。模板是用户可自建 / 编辑 / 删除的
//   备忘蓝图（标题 + 正文，正文约定同备忘录：出行时间首行 + key:value 行），
//   「使用模板」即据此新建一条备忘。
//
// 为什么用 SharedPreferences 而不是新增 Isar 集合：
//   本工程在沙箱内无法运行 build_runner，新增 @collection 必须改 .g.dart，
//   手工改有运行时崩溃风险；模板属轻量、用户量小的配置型数据，JSON 存
//   SharedPreferences 足够，且完全不污染既有 Isar 备忘录集合。
//
// 种子模板：
//   首次启动把一组内置常用模板写入存储（带 seeded 标记，避免用户清空后再次灌入）。
//   之后模板完全由用户掌控（增 / 改 / 删）。
//
// 关键依赖：
//   - shared_preferences：轻量键值存储（异步单例）。
//   - flutter_riverpod：memoTemplatesProvider 暴露模板列表。
// ============================================================================

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 键：模板列表（JSON 数组）。版本号后缀便于日后迁移。
const String _kTemplatesPrefKey = 'memo_templates_v1';

/// SharedPreferences 键：是否已写入过种子模板（区分「首次启动」与「用户清空」）。
const String _kTemplatesSeededKey = 'memo_templates_seeded_v1';

/// 一条备忘录模板（可编辑的备忘蓝图）。
///
/// 与 [MemoRecord] 同构（标题 + 正文），但独立存储、可反复「使用」生成备忘。
class MemoTemplate {
  /// 创建模板。
  const MemoTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  /// 模板唯一 id（新建时由时间戳生成；种子模板用稳定 id 防重复）。
  final String id;

  /// 模板标题（如「出差清单」）。
  final String title;

  /// 模板正文（出行时间首行 + key:value 行，约定同备忘录）。
  final String content;

  /// 最后更新时间（毫秒时间戳），列表排序用。
  final int updatedAt;

  /// 从 JSON 反序列化（SharedPreferences 读取后用）。
  factory MemoTemplate.fromJson(Map<String, dynamic> json) {
    return MemoTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      updatedAt: json['updatedAt'] as int,
    );
  }

  /// 序列化为 JSON（写入 SharedPreferences 用）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt,
      };

  /// 生成一个新的模板 id（时间戳，碰撞概率极低）。
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

/// 内置种子模板（仅首次启动写入一次；老用户也会按需合并缺失的种子）。
///
/// 围绕工具箱「出行 / 露营 / 日常」场景预设，正文用「键：」占位（值为空），
/// 便于用户在备忘录编辑器中回显为多行 key-value 输入。稳定 id 防止重复灌入。
///
/// 清单内容按欧美出行 / 露营习惯组织（证件、转换插头、营地炉具、睡袋、头灯等）。
List<MemoTemplate> _defaultTemplates() {
  final int now = DateTime.now().millisecondsSinceEpoch;
  return <MemoTemplate>[
    // 出差清单：按欧美商务出行习惯（护照/签证/旅行保险/转换插头/名片/正装等）。
    MemoTemplate(
      id: 'seed_business',
      title: '出差清单',
      content: '护照：\n签证：\n登机牌：\n旅行保险：\n酒店预订单：\n'
          '国际驾照（如需）：\n现金与信用卡：\n手机与充电器：\n'
          '笔记本电脑与充电器：\n转换插头：\n名片：\n正装与衬衫：\n'
          '洗漱用品：\n常用药：\n会议资料：',
      updatedAt: now,
    ),
    MemoTemplate(
      id: 'seed_travel',
      title: '旅行行李',
      content: '衣物：\n洗漱用品：\n相机：\n常用药：',
      updatedAt: now,
    ),
    MemoTemplate(
      id: 'seed_meeting',
      title: '会议记录',
      content: '时间：\n地点：\n参会人：\n待办：',
      updatedAt: now,
    ),
    MemoTemplate(
      id: 'seed_shopping',
      title: '购物清单',
      content: '日用品：\n食品：\n家居：',
      updatedAt: now,
    ),
    MemoTemplate(
      id: 'seed_weekend',
      title: '周末出游',
      content: '目的地：\n同行人：\n装备：',
      updatedAt: now,
    ),
    // 露营清单·装备：帐篷 / 睡眠系统 / 照明 / 椅 / 工具，按欧美露营习惯。
    MemoTemplate(
      id: 'seed_camping_gear',
      title: '露营清单·装备',
      content: '帐篷：\n地布/防潮垫：\n睡袋：\n充气枕：\n营钉与防风绳：\n'
          '头灯：\n营灯：\n折叠椅：\n多功能刀：\n登山杖：',
      updatedAt: now,
    ),
    // 露营清单·炊具：炉具 / 锅具 / 储水 / 点火 / 食材，按欧美营地厨房习惯。
    MemoTemplate(
      id: 'seed_camping_kitchen',
      title: '露营清单·炊具',
      content: '营地炉具：\n气罐：\n锅具：\n餐具：\n保温箱：\n'
          '饮用水：\n滤水器：\n火柴/打火机：\n食材：\n垃圾袋：',
      updatedAt: now,
    ),
    // 露营清单·衣物：分层穿搭（速干/保暖/防风），按欧美户外穿衣习惯。
    MemoTemplate(
      id: 'seed_camping_clothes',
      title: '露营清单·衣物',
      content: '速干衣：\n保暖外套：\n冲锋衣：\n登山鞋：\n袜子：\n'
          '帽子：\n手套：\n泳衣（如需）：',
      updatedAt: now,
    ),
    // 露营清单·安全：急救 / 驱虫 / 防晒 / 导航 / 防雨，按欧美野外安全习惯。
    MemoTemplate(
      id: 'seed_camping_safety',
      title: '露营清单·安全',
      content: '急救包：\n驱虫剂：\n防晒霜：\n地图与指南针：\n'
          '绳索/伞绳：\n防雨布：\n移动电源：',
      updatedAt: now,
    ),
  ];
}

/// 由备忘录「存为模板」时，模板标题所用前缀（英文 Template + 下划线）。
///
/// 用户要求：模板名 = 前缀 + 原备忘标题，便于在模板列表里一眼区分派生模板。
const String kMemoTemplateTitlePrefix = 'Template_';

/// 把一条备忘派生为模板：标题加 [kMemoTemplateTitlePrefix] 前缀，正文原样复制。
///
/// - [memoTitle] 为空（或纯空白）时，用 [untitledFallback]（通常是「无标题」）兜底；
/// - 同名前缀标题的模板已存在时**按标题原地覆盖更新**（保留原 id），
///   避免用户连点生成一堆内容相同的重复模板；
/// - 返回最终写入的模板标题，供调用方弹提示用。
Future<String> createTemplateFromMemo({
  required String memoTitle,
  required String memoContent,
  required String untitledFallback,
}) async {
  final String base =
      memoTitle.trim().isEmpty ? untitledFallback : memoTitle.trim();
  final String title = '$kMemoTemplateTitlePrefix$base';
  final List<MemoTemplate> list =
      List<MemoTemplate>.from(await loadMemoTemplates());
  final int nowMs = DateTime.now().millisecondsSinceEpoch;
  final int idx = list.indexWhere((e) => e.title == title);
  if (idx >= 0) {
    // 已存在同名模板：保留 id 覆盖内容与更新时间（幂等，连点不会堆重复项）。
    list[idx] = MemoTemplate(
      id: list[idx].id,
      title: title,
      content: memoContent,
      updatedAt: nowMs,
    );
  } else {
    // 新增：时间戳 id，与模板编辑页新建保持一致。
    list.add(MemoTemplate(
      id: MemoTemplate.newId(),
      title: title,
      content: memoContent,
      updatedAt: nowMs,
    ));
  }
  await saveMemoTemplates(list);
  return title;
}

/// 读取全部模板（按更新时间倒序）。
///
/// 首次启动（未写过种子且存储为空）会写入内置种子模板，之后完全由用户掌控。
Future<List<MemoTemplate>> loadMemoTemplates() async {
  final SharedPreferences sp = await SharedPreferences.getInstance();
  final bool seeded = sp.getBool(_kTemplatesSeededKey) ?? false;
  final String? raw = sp.getString(_kTemplatesPrefKey);

  // 首次启动：灌入种子模板并打标记。
  if (!seeded) {
    final List<MemoTemplate> seeds = _defaultTemplates();
    await sp.setString(
      _kTemplatesPrefKey,
      jsonEncode(seeds.map((e) => e.toJson()).toList()),
    );
    await sp.setBool(_kTemplatesSeededKey, true);
    return seeds;
  }

  if (raw == null || raw.isEmpty) return <MemoTemplate>[];
  try {
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final List<MemoTemplate> items = list
        .map((e) => MemoTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    // 合并缺失的内置种子：新增种子（如露营清单）也能出现在老用户列表里，
    // 且仅按 id 补齐、不覆盖用户已有的自定义 / 编辑过的模板。
    final Set<String> existingIds = items.map((e) => e.id).toSet();
    final List<MemoTemplate> missing = _defaultTemplates()
        .where((s) => !existingIds.contains(s.id))
        .toList();
    if (missing.isNotEmpty) {
      items.addAll(missing);
      await sp.setString(
        _kTemplatesPrefKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    }
    // 最近编辑的排最前。
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  } catch (e) {
    // JSON 损坏不应让页面崩，降级为清空（极少发生）。
    return <MemoTemplate>[];
  }
}

/// 整体写回模板列表（upsert / 删除都走这个全量覆盖）。
Future<void> saveMemoTemplates(List<MemoTemplate> list) async {
  final SharedPreferences sp = await SharedPreferences.getInstance();
  await sp.setString(
    _kTemplatesPrefKey,
    jsonEncode(list.map((e) => e.toJson()).toList()),
  );
}

/// 模板列表 Provider（FutureProvider）。
///
/// 任意增删改后由调用方 [ref.invalidate] 刷新；模板量小，全量读开销可忽略。
final FutureProvider<List<MemoTemplate>> memoTemplatesProvider =
    FutureProvider<List<MemoTemplate>>((_) => loadMemoTemplates());
