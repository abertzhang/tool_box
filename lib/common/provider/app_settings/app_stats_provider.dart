// ============================================================================
// 文件：common/provider/app_settings/app_stats_provider.dart
// 模块：app 级统计（全 App 工具使用总量）
//
// 职责：暴露「全 App 工具使用总量」这一数字给 UI
//       （当前用于 profile 资料区统计条第 3 栏）。
//
// 为什么必须走 RPC 聚合：
//   - 该数字 = sum(users.tool_usage_count) + sum(anonymous_devices.free_tool_usage_count)，
//     跨所有用户与设备求和；
//   - 客户端（anon / authenticated 角色）受 RLS 限制，读不到其它用户 / 设备行，本地无法聚合；
//   - 故由服务端 SECURITY DEFINER 函数 get_app_tool_usage_total()
//     （见 scripts/sql/app_tool_usage_total.sql）计算后返回单个整数。
//
// 兜底策略（关键）：
//   - 该函数需在本机 Supabase SQL Editor 执行 app_tool_usage_total.sql 才会存在；
//     未部署时 rpc() 抛 PGRST 错误，这里 catch 后返回 0，UI 显示 0 而非崩溃 / 空白。
//   - Supabase 未初始化（release 漏 dart-define 等极端情况）同样回落 0。
//   - 用 FutureProvider：首帧异步加载，UI 在加载态先显示 0，拿到真值后自动刷新。
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 全 App 工具使用总量 Provider。
///
/// 返回 [int]：所有登录用户与所有游客设备的累计工具使用次数之和。
/// 任何异常（RPC 未部署 / 网络错 / Supabase 未初始化）均回落 0。
final appToolUsageTotalProvider = FutureProvider<int>((ref) async {
  try {
    final dynamic result =
        await Supabase.instance.client.rpc('get_app_tool_usage_total');
    // 标量函数一般直接返回 int；个别 PostgREST 版本会把结果包成
    // {get_app_tool_usage_total: n} 形态，故两种结构都兼容，取第一个 int 值。
    if (result is int) return result;
    if (result is Map) {
      for (final dynamic v in result.values) {
        if (v is int) return v;
      }
    }
    return 0;
  } catch (e) {
    debugPrint('[AppStats] 获取全 App 使用总量失败，回落 0: $e');
    return 0;
  }
});
