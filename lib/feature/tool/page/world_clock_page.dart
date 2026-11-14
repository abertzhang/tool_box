// ============================================================================
// 文件：feature/tool/page/world_clock_page.dart
// 模块：工具箱（tool）
//
// 职责：
//   世界时钟页。顶部「当前定位」卡片（按定位到的经纬度显示当地时钟）+
//   下方 2 列世界城市时间卡片网格，每秒自动刷新。
//
//   用于替换 tools 页上的「Tides（潮汐）」入口（潮汐页与路由暂保留不删，
//   仅入口让位）；后续若确认永久替换，再清理潮汐相关代码。
//
// 时区实现说明（重要）：
//   工程未引入 `timezone` 等时区库（增依赖必须本机跑 pub get，沙箱不可行），
//   因此采用「UTC 时刻 + 固定标准偏移 + 规则化夏令时修正」的纯计算方案：
//   - 定位卡：当地时区由**经度估算**（每 15° = 1 小时，即每度 4 分钟），
//     并夹取到现实时区范围 [-12h, +14h]。该估算不含政治时区与夏令时修正，
//     在单一时区且无夏令时的地区（如中国）与真实时区一致；
//   - 城市卡：无夏令时时区（北京/东京/新加坡/迪拜等）恒定偏移，永远精确；
//     有夏令时时区（纽约/洛杉矶/伦敦/巴黎/悉尼）按各时区现行夏令时切换
//     规则（美国 / 欧盟 / 澳洲东部）计算切换日的 UTC 时刻再判定。
//
// 关键依赖：
//   - dart:async：Timer.periodic 每秒刷新。
//   - geolocator：获取定位经纬度（进页申请权限，失败/拒绝降级为本机时间）。
//   - AppPalette：通用语义色板（页面底 / 卡片 / 文字 / 强调色），随主题联动。
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tool_box/common/provider/theme/app_palette.dart';
import 'package:tool_box/l10n/app_localizations.dart';

/// 夏令时切换规则（按地区归类，规则见各分支注释）。
enum _DstRule {
  /// 无夏令时。
  none,

  /// 美国：3 月第 2 个周日 02:00（当地标准时）开 → 11 月第 1 个周日 02:00（当地
  /// 夏令时，即 01:00 标准时）关。纽约（UTC-5）/ 洛杉矶（UTC-8）适用。
  us,

  /// 欧盟：3 月最后一个周日 01:00 UTC 开 → 10 月最后一个周日 01:00 UTC 关。
  /// 伦敦（UTC+0）/ 巴黎（UTC+1）适用。
  eu,

  /// 澳洲东部（悉尼 UTC+10）：10 月第 1 个周日 02:00 当地开 → 次年 4 月第 1 个
  /// 周日 03:00（夏令时，即 02:00 标准时）关；切换点换算到 UTC 均为 16:00，
  /// 且区间跨年（南半球夏季）。
  au,
}

/// 世界城市时区定义。
///
/// 纯数据类：城市显示名（i18n getter）、标准 UTC 偏移（分钟）与夏令时规则。
class _CityZone {
  /// 创建城市时区。
  ///
  /// - [name]：城市名取值函数（从 [AppLocalizations] 读对应 i18n 词条）；
  /// - [offsetMinutes]：标准时间下的 UTC 偏移（分钟，东正西负）；
  /// - [dst]：夏令时规则，默认 [_DstRule.none]。
  const _CityZone({
    required this.name,
    required this.offsetMinutes,
    this.dst = _DstRule.none,
  });

  /// 城市显示名（随语言切换）。
  final String Function(AppLocalizations l10n) name;

  /// 标准时间 UTC 偏移（分钟）。
  final int offsetMinutes;

  /// 夏令时规则。
  final _DstRule dst;
}

/// 展示城市清单（顺序即展示顺序，2 列网格从左到右、从上到下）。
///
/// 全部选自「国际时钟」高频城市；偏移为标准时间值，夏令时由 [_DstRule] 动态修正。
const List<_CityZone> _cities = <_CityZone>[
  _CityZone(name: _cityBeijing, offsetMinutes: 8 * 60), // 北京 UTC+8
  _CityZone(name: _cityTokyo, offsetMinutes: 9 * 60), // 东京 UTC+9
  _CityZone(name: _citySingapore, offsetMinutes: 8 * 60), // 新加坡 UTC+8
  _CityZone(name: _citySydney, offsetMinutes: 10 * 60, dst: _DstRule.au), // 悉尼
  _CityZone(name: _cityDubai, offsetMinutes: 4 * 60), // 迪拜 UTC+4
  _CityZone(name: _cityLondon, offsetMinutes: 0, dst: _DstRule.eu), // 伦敦
  _CityZone(name: _cityParis, offsetMinutes: 60, dst: _DstRule.eu), // 巴黎
  _CityZone(name: _cityNewYork, offsetMinutes: -5 * 60, dst: _DstRule.us), // 纽约
  _CityZone(name: _cityLosAngeles, offsetMinutes: -8 * 60, dst: _DstRule.us), // 洛杉矶
];

/// 国家 / 地区（第一级下拉框选项）。
///
/// 仅收纳 [/_cities] 中已覆盖的国家，便于「国家 → 城市」两级联动；
/// 未覆盖的游离城市（如有）不在此列。纯数据类，与 [_CityZone] 同构。
class _Region {
  /// 创建国家 / 地区。
  ///
  /// - [key]：稳定标识（不随语言变化，用于状态比较与联动）；
  /// - [name]：国家显示名（从 [AppLocalizations] 读 i18n 词条）；
  /// - [cities]：该国 / 地区下可选城市清单。
  const _Region({
    required this.key,
    required this.name,
    required this.cities,
  });

  /// 稳定标识（状态比较用，避免依赖会随语言切换的显示名）。
  final String key;

  /// 国家显示名（随语言切换）。
  final String Function(AppLocalizations l10n) name;

  /// 该国 / 地区下可选城市清单。
  final List<_CityZone> cities;
}

/// 国家 / 地区清单（顺序即第一级下拉框展示顺序）。
///
/// 每个国家对应 [/_cities] 中同属该国的若干城市；美国含纽约、洛杉矶两个城市，
/// 故其第二级下拉会有两个选项。国家名经 i18n，城市名复用 [/_cities] 的同名定义。
const List<_Region> _regions = <_Region>[
  _Region(
    key: 'cn',
    name: _countryCn,
    cities: <_CityZone>[
      _CityZone(name: _cityBeijing, offsetMinutes: 8 * 60), // 北京 UTC+8
    ],
  ),
  _Region(
    key: 'jp',
    name: _countryJp,
    cities: <_CityZone>[
      _CityZone(name: _cityTokyo, offsetMinutes: 9 * 60), // 东京 UTC+9
    ],
  ),
  _Region(
    key: 'sg',
    name: _countrySg,
    cities: <_CityZone>[
      _CityZone(name: _citySingapore, offsetMinutes: 8 * 60), // 新加坡 UTC+8
    ],
  ),
  _Region(
    key: 'au',
    name: _countryAu,
    cities: <_CityZone>[
      _CityZone(name: _citySydney, offsetMinutes: 10 * 60, dst: _DstRule.au), // 悉尼
    ],
  ),
  _Region(
    key: 'ae',
    name: _countryAe,
    cities: <_CityZone>[
      _CityZone(name: _cityDubai, offsetMinutes: 4 * 60), // 迪拜 UTC+4
    ],
  ),
  _Region(
    key: 'gb',
    name: _countryGb,
    cities: <_CityZone>[
      _CityZone(name: _cityLondon, offsetMinutes: 0, dst: _DstRule.eu), // 伦敦
    ],
  ),
  _Region(
    key: 'fr',
    name: _countryFr,
    cities: <_CityZone>[
      _CityZone(name: _cityParis, offsetMinutes: 60, dst: _DstRule.eu), // 巴黎
    ],
  ),
  _Region(
    key: 'us',
    name: _countryUs,
    cities: <_CityZone>[
      _CityZone(name: _cityNewYork, offsetMinutes: -5 * 60, dst: _DstRule.us), // 纽约
      _CityZone(name: _cityLosAngeles, offsetMinutes: -8 * 60, dst: _DstRule.us), // 洛杉矶
    ],
  ),
];

/// 城市名取值函数（顶层数组 const 里无法写闭包捕获，故用顶层函数引用）。
String _cityBeijing(AppLocalizations l10n) => l10n.worldClockCityBeijing;

/// 东京。
String _cityTokyo(AppLocalizations l10n) => l10n.worldClockCityTokyo;

/// 新加坡。
String _citySingapore(AppLocalizations l10n) => l10n.worldClockCitySingapore;

/// 悉尼。
String _citySydney(AppLocalizations l10n) => l10n.worldClockCitySydney;

/// 迪拜。
String _cityDubai(AppLocalizations l10n) => l10n.worldClockCityDubai;

/// 伦敦。
String _cityLondon(AppLocalizations l10n) => l10n.worldClockCityLondon;

/// 巴黎。
String _cityParis(AppLocalizations l10n) => l10n.worldClockCityParis;

/// 纽约。
String _cityNewYork(AppLocalizations l10n) => l10n.worldClockCityNewYork;

/// 洛杉矶。
String _cityLosAngeles(AppLocalizations l10n) =>
    l10n.worldClockCityLosAngeles;

/// 国家 / 地区名取值函数（顶层数组 const 里无法写闭包捕获，故用顶层函数引用）。
/// 顺序与 [_regions] 中的国家一一对应。
String _countryCn(AppLocalizations l10n) => l10n.worldClockCountryCn;

/// 日本。
String _countryJp(AppLocalizations l10n) => l10n.worldClockCountryJp;

/// 新加坡。
String _countrySg(AppLocalizations l10n) => l10n.worldClockCountrySg;

/// 澳大利亚。
String _countryAu(AppLocalizations l10n) => l10n.worldClockCountryAu;

/// 阿联酋。
String _countryAe(AppLocalizations l10n) => l10n.worldClockCountryAe;

/// 英国。
String _countryGb(AppLocalizations l10n) => l10n.worldClockCountryGb;

/// 法国。
String _countryFr(AppLocalizations l10n) => l10n.worldClockCountryFr;

/// 美国。
String _countryUs(AppLocalizations l10n) => l10n.worldClockCountryUs;

/// 双位补零（分钟/秒/日期等）。
String _two(int v) => v.toString().padLeft(2, '0');

/// 24 小时制 HH:mm。
String _formatHm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// 24 小时制 HH:mm:ss。
String _formatHms(
  DateTime t,
) => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// UTC 偏移展示文案：整小时省略分钟（UTC+8），半小时偏移带冒号（UTC+5:30）。
String _formatOffset(int minutes) {
  final bool neg = minutes < 0;
  final int abs = minutes.abs();
  final String mm = abs % 60 == 0 ? '' : ':${_two(abs % 60)}';
  return 'UTC${neg ? '-' : '+'}${abs ~/ 60}$mm';
}

/// 某年某月的第 [nth] 个周日的 [hourUtc] 点（UTC）。
///
/// 用于美国（3 月第 2 个周日 / 11 月第 1 个周日）与澳洲（10 月 / 4 月第 1 个周日）
/// 的夏令时切换日计算。`first.weekday`：周一=1 … 周日=7。
DateTime _nthSundayUtc(int year, int month, int nth, int hourUtc) {
  final DateTime first = DateTime.utc(year, month, 1);
  final int toSunday = (7 - first.weekday) % 7; // 距本月第一个周日的天数
  final int day = 1 + toSunday + (nth - 1) * 7;
  return DateTime.utc(year, month, day, hourUtc);
}

/// 某年某月最后一个周日的 [hourUtc] 点（UTC）。
///
/// 用于欧盟夏令时切换日（3 月 / 10 月最后一个周日）。`DateTime.utc(y, m+1, 0)`
/// 利用「第 0 天 = 上月最后一天」取到本月末，再向前回退到周日。
DateTime _lastSundayUtc(int year, int month, int hourUtc) {
  final int lastDay = DateTime.utc(year, month + 1, 0).day;
  int day = lastDay;
  while (DateTime.utc(year, month, day).weekday != DateTime.sunday) {
    day--;
  }
  return DateTime.utc(year, month, day, hourUtc);
}

/// 判断 [utcNow] 时刻该城市是否处于夏令时。
///
/// 北半球（美/欧）：区间为「同年 3 月 → 11 月」，`start <= now < end` 即激活；
/// 南半球（悉尼）：区间跨年（10 月 → 次年 4 月），`now < 4月切换点` 或
/// `now >= 10月切换点` 即激活。切换点均按现行规则换算为 UTC 时刻。
bool _isDstActive(_CityZone zone, DateTime utcNow) {
  switch (zone.dst) {
    case _DstRule.none:
      return false;
    case _DstRule.us:
      // 开：3 月第 2 个周日 02:00 当地标准时 → UTC 小时 = 2 - 标准偏移小时
      //（纽约 -5 → 07:00 UTC；洛杉矶 -8 → 10:00 UTC）。
      final int oh = zone.offsetMinutes ~/ 60;
      final DateTime start = _nthSundayUtc(utcNow.year, 3, 2, 2 - oh);
      // 关：11 月第 1 个周日 02:00 当地夏令时 = 01:00 标准时 → UTC 小时 = 1 - oh
      //（纽约 → 06:00 UTC；洛杉矶 → 09:00 UTC）。
      final DateTime end = _nthSundayUtc(utcNow.year, 11, 1, 1 - oh);
      return !start.isAfter(utcNow) && utcNow.isBefore(end);
    case _DstRule.eu:
      // 欧盟切换点直接以 UTC 定义（01:00 UTC），与城市偏移无关。
      final DateTime start = _lastSundayUtc(utcNow.year, 3, 1);
      final DateTime end = _lastSundayUtc(utcNow.year, 10, 1);
      return !start.isAfter(utcNow) && utcNow.isBefore(end);
    case _DstRule.au:
      // 悉尼：10 月第 1 个周日 02:00 AEST = 16:00 UTC 开；
      // 4 月第 1 个周日 03:00 AEDT = 02:00 AEST = 16:00 UTC 关。
      final DateTime start = _nthSundayUtc(utcNow.year, 10, 1, 16);
      final DateTime end = _nthSundayUtc(utcNow.year, 4, 1, 16);
      return utcNow.isBefore(end) || !start.isAfter(utcNow);
  }
}

/// 计算城市当前本地时刻：UTC 时刻 + 标准偏移 + 夏令时修正（激活时 +60 分钟）。
DateTime _zoneNow(_CityZone zone, DateTime utcNow) {
  final int offset = zone.offsetMinutes + (_isDstActive(zone, utcNow) ? 60 : 0);
  return utcNow.add(Duration(minutes: offset));
}

/// 依据定位经度估算当地 UTC 偏移（分钟）。
///
/// 地球每小时 15°（360°/24h）：先按 `经度 / 15` 四舍五入到**整小时**，
/// 再夹取到现实时区范围 [-12h, +14h]。
/// 注意：该估算不含政治时区边界与夏令时（详见文件头说明）。
int _offsetFromLongitude(double longitude) {
  final int hours = (longitude / 15).round();
  return (hours * 60).clamp(-12 * 60, 14 * 60).toInt();
}

/// 顶部卡片的三种状态。
enum _PlaceState {
  /// 正在定位（权限申请 / 等待 GPS fix）。
  locating,

  /// 定位成功：按时区估算显示当地时钟 + 坐标。
  located,

  /// 定位失败（权限被拒 / 服务关闭 / 超时）：降级显示本机时间。
  failed,
}

/// 世界时钟页。
///
/// 结构：AppBar（标题）→ 顶部卡片（定位成功=当地时间+坐标 / 定位中=加载态 /
/// 失败=本机时间降级）→ 城市时间 2 列网格。每秒 setState 刷新一次（仅文本变化）。
class WorldClockPage extends StatefulWidget {
  /// 创建世界时钟页。无参数：数据来自系统时钟实时计算 + 定位（可选）。
  const WorldClockPage({super.key});

  @override
  State<WorldClockPage> createState() => _WorldClockPageState();
}

/// [WorldClockPage] 状态：持有每秒刷新定时器与定位结果。
class _WorldClockPageState extends State<WorldClockPage> {
  /// 每秒刷新定时器；仅本页在栈顶可见时有意义，dispose 必须 cancel 防泄漏。
  Timer? _timer;

  /// 顶部卡片状态（定位中 / 已定位 / 失败降级）。
  _PlaceState _placeState = _PlaceState.locating;

  /// 定位结果（仅 [_PlaceState.located] 时非空）。
  Position? _position;

  /// 第一级下拉框选中的国家 / 地区 key（null = 未选）。
  String? _regionKey;

  /// 第二级下拉框选中的城市时区（null = 未选，或国家尚未选定）。
  _CityZone? _pickedCity;

  /// 初始化：启动每秒刷新 + 触发定位（进页即申请权限，与指南针页口径一致）。
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // 定位是纯异步操作、不依赖 inherit（无 context 读取），可直接在 initState 发起。
    unawaited(_locate());
  }

  /// 定时回调：mounted 守卫避免组件已卸载后仍触发 setState。
  void _onTick() {
    if (mounted) setState(() {});
  }

  /// 定位流程：系统定位开关 → 权限（必要时弹框申请）→ 取一次当前位置。
  ///
  /// 任何一步失败都降级为 [_PlaceState.failed]（顶部卡回退显示本机时间），
  /// 不阻塞城市卡网格；定位成功则记录 [Position] 供每帧换算当地时钟。
  ///
  /// ⚠️ `getCurrentPosition` 必须传 `timeLimit`（写在 LocationSettings 里），
  /// 室内 / 无 GPS 信号时否则会把流程卡到系统超时（与指南针页同坑，见其注释）。
  Future<void> _locate() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _placeState = _PlaceState.failed);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      // 只有「从未决定 / 普通拒绝」时系统才会真的弹框；重复进页安全不骚扰。
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final bool granted =
          perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
      if (!granted) {
        // 权限被拒 / 永久拒绝：不引导跳设置（本页定位只是增强功能），
        // 直接降级为本机时间。
        if (mounted) setState(() => _placeState = _PlaceState.failed);
        return;
      }
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = p;
        _placeState = _PlaceState.located;
      });
    } catch (_) {
      // 权限 / 定位平台异常一律降级，不影响城市卡网格。
      if (mounted) setState(() => _placeState = _PlaceState.failed);
    }
  }

  /// 释放：取消定时器，防止页面退出后仍在后台空转。
  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// 构建页面。
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final _WorldClockTheme theme = _WorldClockTheme.of(context);
    final DateTime now = DateTime.now();
    final DateTime utcNow = now.toUtc();

    return Scaffold(
      backgroundColor: theme.pageBg,
      appBar: AppBar(centerTitle: true, title: Text(l10n.worldClockTitle)),
      body: SafeArea(
        // 顶部由 AppBar 处理；底部避让 Home Indicator。
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 8.h),
              // 顶部卡片：定位成功显示当地时间（按经度估算），失败降级本机时间。
              _PlaceTimeCard(
                theme: theme,
                state: _placeState,
                position: _position,
                deviceNow: now,
                utcNow: utcNow,
                locatedLabel: l10n.worldClockLocLabel,
                locatingLabel: l10n.worldClockLocating,
                fallbackLabel: l10n.worldClockLocalLabel,
                failedHint: l10n.worldClockLocFailed,
              ),
              SizedBox(height: 24.h),
              // 国家 / 地区 → 城市 两级级联下拉框：选中城市后在其下方显示大号走秒时钟。
              _RegionCityPicker(
                theme: theme,
                l10n: l10n,
                regionKey: _regionKey,
                pickedCity: _pickedCity,
                onRegionChanged: (String? key) {
                  setState(() {
                    _regionKey = key;
                    // 切换国家时清空已选城市；若该国只有 1 个城市则自动选中，
                    // 免去第二步多余操作（单城市国家占多数）。
                    final _Region? reg = key == null
                        ? null
                        : _regions.firstWhere((_Region r) => r.key == key);
                    _pickedCity = reg == null
                        ? null
                        : reg.cities.length == 1
                        ? reg.cities.first
                        : null;
                  });
                },
                onCityChanged: (_CityZone? city) {
                  setState(() => _pickedCity = city);
                },
              ),
              SizedBox(height: 16.h),
              // 选中的城市时钟（大号走秒）：联动级联下拉框，未选时不显示。
              if (_pickedCity != null)
                _PickedCityCard(
                  theme: theme,
                  zone: _pickedCity!,
                  local: _zoneNow(_pickedCity!, utcNow),
                ),
              SizedBox(height: 24.h),
              // 城市时间网格（2 列）：卡片宽度由 LayoutBuilder 按屏宽均分，
              // 9 个城市自动换行（最后一行单卡靠左，与工具页网格行为一致）。
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  final double w = constraints.maxWidth;
                  // 卡宽 = 总宽减去列间距(12.w)后取半，与 tools 页网格口径一致。
                  final double cardW = (w - 12.w) / 2;
                  return Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: _cities
                        .map(
                          (_CityZone zone) => SizedBox(
                            width: cardW,
                            child: _CityTimeCard(
                              theme: theme,
                              zone: zone,
                              local: _zoneNow(zone, utcNow),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部卡片：按时区状态显示「当地时间」。
///
/// 三种形态共用同一卡片骨架（圆角白卡 + 标签 + 大字时刻 + 日期行），差异仅在
/// 标签文案与附加信息，避免三棵 widget 树后改样式漏改：
/// - [/_PlaceState.locating]：标签「定位中…」+ 菊花；
/// - [/_PlaceState.located]：标签「当前定位」+ 经纬度行 + 按经度估算的当地时间；
/// - [/_PlaceState.failed]：标签「本机时间」+ 降级提示。
class _PlaceTimeCard extends StatelessWidget {
  /// 创建顶部卡片。
  const _PlaceTimeCard({
    required this.theme,
    required this.state,
    required this.position,
    required this.deviceNow,
    required this.utcNow,
    required this.locatedLabel,
    required this.locatingLabel,
    required this.fallbackLabel,
    required this.failedHint,
  });

  /// 页面主题色板。
  final _WorldClockTheme theme;

  /// 当前定位状态。
  final _PlaceState state;

  /// 定位结果（仅 located 状态非空）。
  final Position? position;

  /// 本机时刻（走秒，每帧由页面刷新）。
  final DateTime deviceNow;

  /// 当前 UTC 时刻（换算当地时间用）。
  final DateTime utcNow;

  /// 「当前定位」标签。
  final String locatedLabel;

  /// 「定位中…」标签。
  final String locatingLabel;

  /// 「本机时间」标签（降级态）。
  final String fallbackLabel;

  /// 定位失败提示文案。
  final String failedHint;

  /// 构建卡片。
  @override
  Widget build(BuildContext context) {
    // 时刻与日期行按状态取值：located 用经度估算的当地时间，其余用本机时间。
    final DateTime shown;
    switch (state) {
      case _PlaceState.located:
        final Position p = position!;
        shown = utcNow.add(
          Duration(minutes: _offsetFromLongitude(p.longitude)),
        );
      case _PlaceState.locating || _PlaceState.failed:
        shown = deviceNow;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标签行：左侧状态文案，定位中时右侧带小菊花。
          Row(
            children: <Widget>[
              Text(
                state == _PlaceState.located
                    ? locatedLabel
                    : state == _PlaceState.locating
                    ? locatingLabel
                    : fallbackLabel,
                style: TextStyle(color: theme.labelText, fontSize: 13.sp),
              ),
              if (state == _PlaceState.locating) ...<Widget>[
                const Spacer(),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accent,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          // 大字时刻（含秒，体现「实时走秒」）。
          Text(
            _formatHms(shown),
            style: TextStyle(
              color: theme.accent,
              fontSize: 40.sp,
              fontWeight: FontWeight.w700,
              // 数字等宽：走秒时不跳动，视觉更稳。
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4.h),
          // 第三行按状态给出差异信息：
          // located = 坐标 + 估算偏移；failed = 降级提示；locating = 空。
          if (state == _PlaceState.located)
            Text(
              '${_fmtCoord(position!.latitude, isLat: true)} · '
              '${_fmtCoord(position!.longitude, isLat: false)} · '
              '${_formatOffset(_offsetFromLongitude(position!.longitude))}',
              style: TextStyle(color: theme.labelText, fontSize: 13.sp),
            )
          else if (state == _PlaceState.failed)
            Text(
              failedHint,
              style: TextStyle(color: theme.labelText, fontSize: 13.sp),
            )
          else
            // 定位中：占位同高度文本，避免菊花出现/消失时卡片高度跳动。
            Text(
              ' ',
              style: TextStyle(color: theme.labelText, fontSize: 13.sp),
            ),
        ],
      ),
    );
  }

  /// 坐标格式化：`36.0678° N` / `120.3826° E`（南纬 S / 西经 W）。
  String _fmtCoord(double v, {required bool isLat}) {
    final String dir = isLat ? (v >= 0 ? 'N' : 'S') : (v >= 0 ? 'E' : 'W');
    return '${v.abs().toStringAsFixed(4)}° $dir';
  }
}

/// 城市时间卡片：城市名 + 时刻 + 偏移/日期。
class _CityTimeCard extends StatelessWidget {
  /// 创建城市卡片。
  const _CityTimeCard({
    required this.theme,
    required this.zone,
    required this.local,
  });

  /// 页面主题色板。
  final _WorldClockTheme theme;

  /// 城市时区定义。
  final _CityZone zone;

  /// 该城市当前本地时刻（由页面每秒重算传入）。
  final DateTime local;

  /// 构建卡片。
  @override
  Widget build(BuildContext context) {
    // 实际生效偏移（含夏令时修正），用于展示 UTC±N 徽标。
    final int effectiveOffset = _isDstActive(zone, DateTime.now().toUtc())
        ? zone.offsetMinutes + 60
        : zone.offsetMinutes;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 城市名 + 右侧 UTC 偏移徽标。
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  zone.name(AppLocalizations.of(context)!),
                  style: TextStyle(
                    color: theme.titleText,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                _formatOffset(effectiveOffset),
                style: TextStyle(color: theme.labelText, fontSize: 11.sp),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          // 时刻（HH:mm，城市卡不带秒，突出可读性）。
          Text(
            _formatHm(local),
            style: TextStyle(
              color: theme.accent,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 2.h),
          // 日期（纯数字 M/d）。
          Text(
            '${local.month}/${local.day}',
            style: TextStyle(color: theme.labelText, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

/// 国家 / 地区 → 城市 两级级联下拉框。
///
/// 第一级选国家（修改 [regionKey]），第二级选该国城市（修改 [pickedCity]）；
/// 未选国家时第二级禁用并提示先选国家。布局为两列等宽 [Row]，整体走主题色板。
class _RegionCityPicker extends StatelessWidget {
  /// 创建级联下拉框。
  const _RegionCityPicker({
    required this.theme,
    required this.l10n,
    required this.regionKey,
    required this.pickedCity,
    required this.onRegionChanged,
    required this.onCityChanged,
  });

  /// 页面主题色板。
  final _WorldClockTheme theme;

  /// 当前语言包（i18n 文案与城市/国家名）。
  final AppLocalizations l10n;

  /// 选中的国家 key（null = 未选）。
  final String? regionKey;

  /// 选中的城市（null = 未选）。
  final _CityZone? pickedCity;

  /// 国家变更回调（null 表示清空）。
  final ValueChanged<String?> onRegionChanged;

  /// 城市变更回调（null 表示清空）。
  final ValueChanged<_CityZone?> onCityChanged;

  /// 当前选中国家（按 key 反查，无匹配返回 null）。
  _Region? get _selectedRegion => regionKey == null
      ? null
      : _regions.firstWhere((_Region r) => r.key == regionKey);

  /// 统一的下拉样式封装：外层描边容器 + 去掉默认下划线的 [DropdownButton]。
  ///
  /// 用 [Border] 描边替代默认下划线，视觉更克制；[dropdownColor] 跟随卡片色
  /// 保证深色主题下弹层可读；[enabled]=false 时整体置灰（第二级未选国家时）。
  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.labelText.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(color: theme.labelText, fontSize: 14.sp),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
        isExpanded: true,
        // 去掉默认下划线（外层已描边），避免两条线叠在一起。
        underline: const SizedBox.shrink(),
        dropdownColor: theme.card,
        icon: Icon(Icons.arrow_drop_down, color: theme.labelText),
        style: TextStyle(color: theme.titleText, fontSize: 14.sp),
      ),
    );
  }

  /// 第一级下拉：国家 / 地区。
  Widget _buildRegionMenu() {
    return _dropdown<String>(
      value: regionKey,
      hint: l10n.worldClockSelectRegion,
      items: _regions
          .map(
            (_Region r) => DropdownMenuItem<String>(
              value: r.key,
              child: Text(r.name(l10n)),
            ),
          )
          .toList(),
      onChanged: onRegionChanged,
    );
  }

  /// 第二级下拉：城市（依赖第一级选中的国家）。
  Widget _buildCityMenu() {
    final _Region? region = _selectedRegion;
    final List<_CityZone> cities = region?.cities ?? const <_CityZone>[];
    // value 用「城市在列表中的序号」字符串，规避同语言下重名与 locale 切换导致的
    // value 不匹配（城市名随语言变化，序号才是稳定标识）。
    final String? value = region == null || pickedCity == null
        ? null
        : cities.indexOf(pickedCity!).toString();
    return _dropdown<String>(
      value: value,
      hint: l10n.worldClockSelectCity,
      enabled: region != null,
      items: cities
          .map(
            (_CityZone c) => DropdownMenuItem<String>(
              value: cities.indexOf(c).toString(),
              child: Text(c.name(l10n)),
            ),
          )
          .toList(),
      onChanged: (String? v) {
        if (v == null || region == null) return;
        onCityChanged(region.cities[int.parse(v)]);
      },
    );
  }

  /// 构建级联下拉框。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 区块小标题（国家/地区）。
        Text(
          l10n.worldClockRegion,
          style: TextStyle(color: theme.labelText, fontSize: 13.sp),
        ),
        SizedBox(height: 8.h),
        // 两列等宽：左国家、右城市。
        Row(
          children: <Widget>[
            Expanded(child: _buildRegionMenu()),
            SizedBox(width: 12.w),
            Expanded(child: _buildCityMenu()),
          ],
        ),
      ],
    );
  }
}

/// 级联下拉框选中的城市大号走秒时钟卡。
///
/// 与 [_CityTimeCard] 展示同一城市，但字号更大（带秒、走秒不跳动），
/// 作为「主动挑选」的强调展示，独立于下方 9 城快速浏览网格。
class _PickedCityCard extends StatelessWidget {
  /// 创建选中城市卡。
  const _PickedCityCard({
    required this.theme,
    required this.zone,
    required this.local,
  });

  /// 页面主题色板。
  final _WorldClockTheme theme;

  /// 选中的城市时区定义。
  final _CityZone zone;

  /// 该城市当前本地时刻（由页面每秒重算传入）。
  final DateTime local;

  /// 构建卡片。
  @override
  Widget build(BuildContext context) {
    // 实际生效偏移（含夏令时修正），用于展示 UTC±N 徽标。
    final int effectiveOffset = _isDstActive(zone, DateTime.now().toUtc())
        ? zone.offsetMinutes + 60
        : zone.offsetMinutes;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 城市名 + 右侧 UTC 偏移徽标。
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  zone.name(AppLocalizations.of(context)!),
                  style: TextStyle(
                    color: theme.titleText,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                _formatOffset(effectiveOffset),
                style: TextStyle(color: theme.labelText, fontSize: 12.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // 大字时刻（含秒，体现「实时走秒」）。
          Text(
            _formatHms(local),
            style: TextStyle(
              color: theme.accent,
              fontSize: 40.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4.h),
          // 日期（纯数字 M/d）。
          Text(
            '${local.month}/${local.day}',
            style: TextStyle(color: theme.labelText, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

/// 世界时钟双主题色板。
///
/// 与潮汐页主题类同构：通用色取自 [AppPalette]（随明暗与色卡切换），
/// 本页无独立品牌色，全部走语义色板。
class _WorldClockTheme {
  /// 创建色板。所有颜色均为必填，避免遗漏某项导致深浅色「串色」。
  const _WorldClockTheme({
    required this.pageBg,
    required this.card,
    required this.titleText,
    required this.labelText,
    required this.accent,
  });

  /// 页面背景色。
  final Color pageBg;

  /// 卡片背景色（浅色取抬升卡色形成层次，深色与常规卡同色）。
  final Color card;

  /// 一级文字色（城市名）。
  final Color titleText;

  /// 次级文字色（标签 / 偏移 / 日期）。
  final Color labelText;

  /// 强调色（时刻大字）。
  final Color accent;

  /// 依据当前主题返回对应色板。
  static _WorldClockTheme of(BuildContext context) {
    final AppPalette app = AppPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return _WorldClockTheme(
      pageBg: app.pageBg,
      // 浅色下取抬升卡片色（浮起层次）；深色下与常规卡片同色。
      card: dark ? app.cardBg : app.cardElevated,
      titleText: app.titleText,
      labelText: app.labelText,
      accent: app.accent,
    );
  }
}
