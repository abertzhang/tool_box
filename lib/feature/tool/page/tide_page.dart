// ============================================================================
// 文件：feature/tool/page/tide_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   潮汐页。依据 Pixso 设计稿（浅色 193:4 / 深色 202:793）实现，包含
//   「今日潮汐时刻表」「当前潮位信息卡」「历史记录」三大区块；顶部提供
//   「导出」（复制时刻表到剪贴板）与「记录当前」（落库一条潮汐记录）两个动作。
//
// 设计稿配色（逐项硬编码，避免深浅串色）：
//   浅色：页面 #F5F3EF / 时刻表行白卡 #FFFFFF / 信息卡·历史卡米色 #EBE7E0 /
//         主色棕 #8B5C44 / 潮型强调青 #3B757F / 文字 #2C2924·#7A746B。
//   深色：页面 #1C1C1E / 卡片 #2C2C2E / 其余主色与浅色保持一致。
//
// 关键依赖：
//   - flutter_riverpod：历史列表来自 [tideRecordsProvider]，记录当前后 invalidate 刷新。
//   - isar_community：首次进入若历史为空，注入 3 条 mock 记录，保证「记录当前」闭环可见。
//   - flutter/services：导出按钮将时刻表复制到系统剪贴板。
//
// 数据说明：当前潮位读数与时刻表均为 mock（与设计稿一致），历史记录持久化于 Isar。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter/services.dart';

import 'package:tool_box/common/analytics/app_track.dart';
import 'package:tool_box/common/analytics/track_events.dart';
import 'package:tool_box/common/database/isar_service.dart';
import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/feature/tool/data/model/tide_record.dart';
import 'package:tool_box/feature/tool/provider/tide_records_provider.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 单次潮汐事件（高潮 / 低潮），仅用于「今日时刻表」展示。
class _TideEvent {
  /// 创建潮汐事件。
  ///
  /// - [height]：潮高（米）；
  /// - [time]：时刻 HH:mm；
  /// - [isHigh]：true=满潮，false=低潮。
  const _TideEvent(this.height, this.time, this.isHigh);

  /// 潮高（米）。
  final double height;

  /// 时刻（HH:mm 字符串）。
  final String time;

  /// 是否满潮：true=满潮，false=低潮。
  final bool isHigh;
}

/// 今日潮汐时刻表（mock 数据，与设计稿一致：4 个高低潮点）。
const List<_TideEvent> _mockSchedule = [
  _TideEvent(0.5, '01:10', false),
  _TideEvent(1.9, '18:52', true),
  _TideEvent(0.3, '12:45', false),
  _TideEvent(2.1, '06:23', true),
];

/// 当前潮位读数（mock）。
const double _mockCurrentHeight = 1.8;
const bool _mockIsRising = true;
const String _mockTimeToHigh = '02:45';
const String _mockNextLow = '12:45';
const String _mockNextHigh = '18:52';

/// 潮汐页双主题色板。
///
/// 颜色严格取自 Pixso 设计稿（浅色 / 深色两套），逐项硬编码避免深浅串色。
/// 结构：时刻表行卡片在浅色为纯白、深色为深灰；信息卡与历史卡在浅色为米色。
class _TideTheme {
  /// 创建潮汐双主题色板。
  const _TideTheme({
    required this.pageBg,
    required this.whiteCard,
    required this.beigeCard,
    required this.titleText,
    required this.labelText,
    required this.valueText,
    required this.accent,
    required this.accentText,
    required this.teal,
    required this.divider,
    required this.dotLow,
    required this.dotHigh,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 时刻表行卡片底色（浅色纯白）。
  final Color whiteCard;

  /// 信息卡 / 历史卡片底色（浅色米色）。
  final Color beigeCard;

  /// 标题文字色（区块标题、观测点名）。
  final Color titleText;

  /// 次级标签文字色（时间、经纬度、说明）。
  final Color labelText;

  /// 数值主文字色（潮高数值）。
  final Color valueText;

  /// 强调色（主按钮底色、当前潮高数值、满潮圆点）。
  final Color accent;

  /// 强调底色上的反白文字色。
  final Color accentText;

  /// 潮型强调色（涨/退、趋势图标、潮型文案）。
  final Color teal;

  /// 分隔线色。
  final Color divider;

  /// 低潮圆点色。
  final Color dotLow;

  /// 满潮圆点色（与强调色一致）。
  final Color dotHigh;

  /// 根据当前主题返回对应色板实例。
  ///
  /// 通用语义色（页面底 / 卡片 / 文字 / 强调 / 分隔线）统一取自 [AppPalette]，
  /// 使其同时响应「主题色方案（咖啡色 / 蓝色）」与「明暗模式」两个维度的切换。
  /// 潮型色 [teal] 与低潮圆点 [dotLow] 属业务语义固定色，不随主题变化，保留常量。
  static _TideTheme of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return _TideTheme(
        pageBg: app.pageBg,
        whiteCard: app.cardBg,
        beigeCard: app.cardBg,
        titleText: app.titleText,
        labelText: app.labelText,
        valueText: app.valueText,
        accent: app.accent,
        accentText: app.accentText,
        // 潮汐业务品牌青：语义固定，两套主题共用。
        teal: const Color(0xFF3B757F),
        divider: app.divider,
        dotLow: const Color(0xFF7A746B),
        dotHigh: app.accent,
      );
    }
    return _TideTheme(
      pageBg: app.pageBg,
      // 浅色下「白卡」用于浮起层次，取抬升卡片色；深色下与常规卡片同色。
      whiteCard: app.cardElevated,
      beigeCard: app.cardBg,
      titleText: app.titleText,
      labelText: app.labelText,
      valueText: app.valueText,
      accent: app.accent,
      accentText: app.accentText,
      teal: const Color(0xFF3B757F),
      divider: app.divider,
      dotLow: const Color(0xFF7A746B),
      dotHigh: app.accent,
    );
  }
}

/// 潮汐页。
///
/// 设计稿：浅色 193:4 / 深色 202:793。自下而上分为操作行、时刻表、当前潮位卡、
/// 历史记录四块；历史来自 Isar，记录当前后实时刷新。
class TidePage extends ConsumerStatefulWidget {
  /// 创建潮汐页（无参数，数据来自 mock 与 Isar）。
  const TidePage({super.key});

  @override
  ConsumerState<TidePage> createState() => _TidePageState();
}

class _TidePageState extends ConsumerState<TidePage> {
  /// 历史区是否展开（收起时仅显示前 2 条，与「查看全部 / 收起」联动）。
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // 首次进入若历史为空，注入 3 条 mock 记录，保证「记录当前」闭环可见。
    // 必须等首帧后再读 Provider，避免在 build 之前触碰异步状态。
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSeed());
  }

  /// 便捷获取当前文案（i18n）。
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// 若历史为空则写入 3 条 mock 种子记录（仅首次）。
  Future<void> _ensureSeed() async {
    final List<TideRecord> existing = await ref.read(
      tideRecordsProvider.future,
    );
    if (existing.isNotEmpty || !mounted) return;
    // 种子记录与设计稿历史卡片三者一致，带过去的时间戳用于倒序排序。
    final List<TideRecord> seeds = [
      TideRecord(
        location: '金沙滩 • 2号观测点',
        coords: 'N 36.04° E 120.35°',
        tideType: l10n.tideHigh,
        height: 1.88,
        isRising: true,
        recordDate: l10n.tideDateFormat(10, 10, '19', '20'),
        createdAt: DateTime(2025, 10, 10, 19, 20),
      ),
      TideRecord(
        location: '石老人海水浴场',
        coords: 'N 36.08° E 120.47°',
        tideType: l10n.tideEbbing,
        height: 0.42,
        isRising: false,
        recordDate: l10n.tideDateFormat(11, 11, '08', '15'),
        createdAt: DateTime(2025, 10, 11, 8, 15),
      ),
      TideRecord(
        location: '金沙滩 • 1号观测点',
        coords: 'N 36.05° E 120.38°',
        tideType: l10n.tideRising,
        height: 1.65,
        isRising: true,
        recordDate: l10n.tideDateFormat(12, 12, '14', '30'),
        createdAt: DateTime(2025, 10, 12, 14, 30),
      ),
    ];
    await IsarService.instance.writeTxn(() async {
      for (final TideRecord s in seeds) {
        await IsarService.instance.tideRecords.put(s);
      }
    });
    // 重新拉取，使历史区显示刚写入的种子。
    if (mounted) ref.invalidate(tideRecordsProvider);
  }

  /// 记录当前潮位：以 mock 读数生成一条记录落库，并刷新历史列表。
  Future<void> _recordCurrent() async {
    final DateTime now = DateTime.now();
    final TideRecord record = TideRecord(
      location: '金沙滩 • 1号观测点',
      coords: 'N 36.05° E 120.38°',
      tideType: l10n.tideRising,
      height: _mockCurrentHeight,
      isRising: _mockIsRising,
      recordDate: _formatNow(now),
      createdAt: now,
    );
    await IsarService.instance.writeTxn(() async {
      await IsarService.instance.tideRecords.put(record);
    });

    // 保存埋点：当前潮汐数据为 mock，这一条的真实用途是**判断值不值得接真实潮位 API**
    // —— 记录量上来了才值得投入，否则继续用 mock。
    // 注意不带 has_name 之类的死参数：本页没有名称输入字段，
    // 硬编码常量的参数零信息量，只会白占存储与带宽。
    AppTrack.log(
      TrackEvents.toolDataSaved,
      params: <String, Object?>{
        'tool': 'tide',
        'tide_type': _mockIsRising ? 'rising' : 'ebbing',
      },
    );

    if (mounted) {
      // 写入后让历史 Provider 失效并重算，新记录即时出现在列表顶部。
      ref.invalidate(tideRecordsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tideSavedToast)));
    }
  }

  /// 导出时刻表：将今日潮汐数据拼成文本复制到系统剪贴板。
  Future<void> _exportSchedule() async {
    final StringBuffer buf = StringBuffer();
    buf.writeln(l10n.tideScheduleTitle);
    for (final _TideEvent e in _mockSchedule) {
      final String type = e.isHigh ? l10n.tideHighTide : l10n.tideLowTide;
      buf.writeln('${e.time}  $type  ${e.height.toStringAsFixed(1)} m');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    // 导出埋点：潮汐导出的是时刻表而非历史记录，count 记条目数。
    AppTrack.log(
      TrackEvents.toolExport,
      params: <String, Object?>{'tool': 'tide', 'count': _mockSchedule.length},
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tideExported)));
    }
  }

  /// 将时间戳格式化为展示文案（多语言，依赖 [AppLocalizations]）。
  String _formatNow(DateTime t) => l10n.tideDateFormat(
        t.month,
        t.day,
        t.hour.toString().padLeft(2, '0'),
        t.minute.toString().padLeft(2, '0'),
      );

  @override
  Widget build(BuildContext context) {
    final _TideTheme theme = _TideTheme.of(context);
    final AppLocalizations l10n = this.l10n;
    // 订阅历史列表：写入后 invalidate 会触发此处重建。
    final AsyncValue<List<TideRecord>> historyAsync = ref.watch(
      tideRecordsProvider,
    );

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(
        // 标题居中显示（设计稿为居中排布）。
        centerTitle: true,
        title: Text(l10n.tideTitle),
        // 操作区统一置于右侧：导出（图标钮）+ 记录当前/保存（文字钮，最右）。
        actions: [
          // 导出：圆形主色图标钮，复制今日时刻表到剪贴板。
          IconButton(
            onPressed: _exportSchedule,
            icon: Icon(Icons.upload, color: theme.accent),
          ),
          // 记录当前（保存）：文字钮，置于 AppBar 最右侧。
          TextButton.icon(
            onPressed: _recordCurrent,
            icon: Icon(Icons.edit, color: theme.accent, size: 18),
            label: Text(
              l10n.tideRecordCurrent,
              style: TextStyle(
                color: theme.accent,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        // 顶部由 AppBar 处理；底部避让 Home Indicator，避免内容贴边。
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              // 今日潮汐时刻表。
              _ScheduleSection(theme: theme, l10n: l10n),
              SizedBox(height: 24.h),
              // 当前潮位信息卡。
              _CurrentInfoCard(theme: theme, l10n: l10n),
              SizedBox(height: 24.h),
              // 历史记录（来自 Isar）。
              _HistorySection(
                theme: theme,
                l10n: l10n,
                expanded: _expanded,
                historyAsync: historyAsync,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日潮汐时刻表区块（4 行高低潮 + 区块标题）。
class _ScheduleSection extends StatelessWidget {
  /// 创建时刻表区块。
  const _ScheduleSection({required this.theme, required this.l10n});

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时刻表行列表：每个低/满潮一行，行间距 10。
        Column(
          children: _mockSchedule
              .map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _ScheduleRow(theme: theme, l10n: l10n, event: e),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 12.h),
        // 区块标题（行列表之下，与设计稿顺序一致）。
        Text(
          l10n.tideScheduleTitle,
          style: TextStyle(
            color: theme.titleText,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 时刻表单行：左侧类型 + 圆点，右侧潮高 + 时刻。
class _ScheduleRow extends StatelessWidget {
  /// 创建时刻表单行。
  const _ScheduleRow({
    required this.theme,
    required this.l10n,
    required this.event,
  });

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  /// 本行对应的潮汐事件。
  final _TideEvent event;

  @override
  Widget build(BuildContext context) {
    final String type = event.isHigh ? l10n.tideHighTide : l10n.tideLowTide;
    final Color dotColor = event.isHigh ? theme.dotHigh : theme.dotLow;
    return Container(
      height: 41.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: theme.whiteCard,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          // 左侧：圆点 + 潮型文案（低潮 / 满潮）。
          Row(
            children: [
              Container(
                width: 10.w,
                height: 10.h,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                type,
                style: TextStyle(color: theme.titleText, fontSize: 14.sp),
              ),
            ],
          ),
          const Spacer(),
          // 右侧：潮高（强调） + 时刻（次级）。
          Text(
            '${event.height.toStringAsFixed(1)} m',
            style: TextStyle(
              color: theme.valueText,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            event.time,
            style: TextStyle(color: theme.labelText, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

/// 当前潮位信息卡（大卡：状态组 + 当前潮高组 + 分隔线 + 下一轮低/满潮）。
class _CurrentInfoCard extends StatelessWidget {
  /// 创建当前潮位信息卡。
  const _CurrentInfoCard({required this.theme, required this.l10n});

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.beigeCard,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          // 顶部：左侧状态组（距满潮倒计时 + 涨潮中徽标），右侧当前潮高组。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 状态组：倒计时文案在上，涨潮中徽标在下。
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tideTimeToHigh(_mockTimeToHigh),
                    style: TextStyle(color: theme.labelText, fontSize: 13.sp),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      l10n.tideRising,
                      style: TextStyle(
                        color: theme.accentText,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
              // 当前潮高组：大号强调数值在上，标签在下。
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_mockCurrentHeight.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    l10n.tideCurrentHeight,
                    style: TextStyle(color: theme.labelText, fontSize: 13.sp),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          // 分隔线（1px，沿用主题分隔色）。
          Divider(color: theme.divider, height: 1),
          SizedBox(height: 14.h),
          // 底部：下一轮低潮 / 满潮两项并排。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NextTideItem(
                theme: theme,
                time: _mockNextLow,
                label: l10n.tideNextLow,
              ),
              _NextTideItem(
                theme: theme,
                time: _mockNextHigh,
                label: l10n.tideNextHigh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 下一轮潮位项（数值 + 标签，左对齐）。
class _NextTideItem extends StatelessWidget {
  /// 创建下一轮潮位项。
  const _NextTideItem({
    required this.theme,
    required this.time,
    required this.label,
  });

  /// 当前主题色板。
  final _TideTheme theme;

  /// 时刻文案（如「12:45」）。
  final String time; // 视觉上作为数值展示

  /// 标签文案（如「下一轮低潮」）。
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: TextStyle(
            color: theme.valueText,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(color: theme.labelText, fontSize: 13.sp),
        ),
      ],
    );
  }
}

/// 历史记录区块（标题 + 查看全部/收起 + 卡片列表）。
class _HistorySection extends StatelessWidget {
  /// 创建历史记录区块。
  const _HistorySection({
    required this.theme,
    required this.l10n,
    required this.expanded,
    required this.historyAsync,
    required this.onToggle,
  });

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  /// 是否展开（展开显示全部，收起仅前 2 条）。
  final bool expanded;

  /// 历史记录异步数据（来自 Isar Provider）。
  final AsyncValue<List<TideRecord>> historyAsync;

  /// 展开/收起切换回调。
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // 解包异步数据：加载中或出错时先给空列表，加载完成后填充。
    final List<TideRecord> list = historyAsync.value ?? [];
    // 收起态只展示前 2 条，避免首屏过长。
    final List<TideRecord> visible = expanded ? list : list.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.tideHistory,
              style: TextStyle(
                color: theme.titleText,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 仅当记录超过 2 条时显示「查看全部 / 收起」开关。
            if (list.length > 2)
              GestureDetector(
                onTap: onToggle,
                child: Text(
                  expanded ? l10n.tideCollapse : l10n.tideViewAll,
                  style: TextStyle(color: theme.accent, fontSize: 13.sp),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        // 无记录时显示空态占位；否则渲染可见卡片列表。
        if (list.isEmpty)
          _HistoryEmpty(theme: theme, l10n: l10n)
        else
          Column(
            children: visible
                .map(
                  (r) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _HistoryCard(theme: theme, l10n: l10n, record: r),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

/// 历史记录卡片（左：观测点/经纬度/日期，右：趋势图标 + 潮型 + 潮高）。
class _HistoryCard extends StatelessWidget {
  /// 创建历史记录卡片。
  const _HistoryCard({
    required this.theme,
    required this.l10n,
    required this.record,
  });

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  /// 本条历史记录。
  final TideRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 81.h,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.beigeCard,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          // 左侧：观测点名（主）+ 经纬度 + 日期（次级）。
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  record.location,
                  style: TextStyle(
                    color: theme.titleText,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  record.coords,
                  style: TextStyle(color: theme.labelText, fontSize: 12.sp),
                ),
                SizedBox(height: 2.h),
                Text(
                  record.recordDate,
                  style: TextStyle(color: theme.labelText, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // 右侧：趋势图标（青）+ 潮型（青）+ 潮高（强调）。
          Row(
            children: [
              Icon(
                record.isRising ? Icons.trending_up : Icons.trending_down,
                color: theme.teal,
                size: 20,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    record.tideType,
                    style: TextStyle(color: theme.teal, fontSize: 13.sp),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${record.height.toStringAsFixed(2)}m',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 历史空态占位（无记录时显示）。
class _HistoryEmpty extends StatelessWidget {
  /// 创建历史空态占位。
  const _HistoryEmpty({required this.theme, required this.l10n});

  /// 当前主题色板。
  final _TideTheme theme;

  /// 文案（i18n）。
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 24.h),
    child: Center(
      child: Text(
        l10n.tideNoRecords,
        style: TextStyle(color: theme.labelText, fontSize: 13.sp),
      ),
    ),
  );
}
