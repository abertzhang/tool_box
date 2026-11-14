import 'app_env.dart';

/// 文件职责：按运行环境（dev / uat / prd）提供对应的接口基础地址与
/// Supabase 地址，实现「一套代码、多环境切换」。
///
/// 所属模块：config（应用配置层）。
/// 关键依赖：[AppEnv]（读取编译期环境变量 `ENV` 决定当前环境）。
///
/// 使用方式：通过 [AppUrl] 的 `base` / `supabase` getter 获取当前环境地址，
/// 无需在业务代码中硬编码域名。

/// 抽象基类，定义各环境都必须提供的接口地址契约。
abstract class BaseUrl {
  /// 业务接口的基础域名。
  String get base;

  /// Supabase 服务的基础域名。
  String get supabase;
}

/// 当前环境地址聚合入口，根据 [AppEnv.env] 动态代理到对应环境的具体实现。
class AppUrl extends BaseUrl {
  @override
  String get base => switch (AppEnv.env) {
    'dev' => DevUrl().base,
    'uat' => UatUrl().base,
    'prd' => PrdUrl().base,
    _ => DevUrl().base,
  };

  @override
  String get supabase => switch (AppEnv.env) {
    'dev' => DevUrl().supabase,
    'uat' => UatUrl().supabase,
    'prd' => PrdUrl().supabase,
    _ => DevUrl().supabase,
  };
}

/// 开发环境接口地址。
class DevUrl extends BaseUrl {
  @override
  String get base => "https://xxx-dev.supabase.co";

  @override
  String get supabase => "https://xxx-dev.supabase.co";
}

/// 测试（UAT）环境接口地址。
class UatUrl extends BaseUrl {
  @override
  String get base => "https://xxx-uat.supabase.co";

  // 注意：该环境的 supabase 地址复用同一 dev 桶（当前约定），勿随意改动。
  @override
  String get supabase => "https://xxx-dev.supabase.co";
}

/// 生产环境接口地址。
class PrdUrl extends BaseUrl {
  @override
  String get base => "https://xxx-prd.supabase.co";

  // 注意：该环境的 supabase 地址复用同一 dev 桶（当前约定），勿随意改动。
  @override
  String get supabase => "https://xxx-dev.supabase.co";
}
