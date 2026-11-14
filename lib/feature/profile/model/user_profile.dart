// ============================================================================
// 文件：feature/profile/model/user_profile.dart
// 模块：个人中心（profile）/ 数据模型
//
// 职责：
//   承载 Supabase 视图 `public.user_profiles` 的一行数据，
//   供 ProfilePage 展示「头像 / 邮箱 / 会员状态」。
//
// 为什么读视图而不是直接读 `public.users` 表：
//   视图里已经算好了 `is_member_active`（会员有效 = 买过 且 未到期）。
//   App 端直接用它，不必再自己写一遍「过期判断」——
//   否则日期比较逻辑会同时存在于 SQL 与 Dart 两处，改一处漏一处。
//
// 安全性说明：
//   视图带 `with (security_invoker = true)`，会以调用者身份执行，
//   因此底层 `public.users` 的 RLS（`id = auth.uid()`）依旧生效，
//   读视图不会绕过行级安全。视图只给 authenticated 授了 SELECT。
//
// 关键依赖：无。纯 Dart 解析，不依赖 Supabase SDK，便于单测与降级渲染。
// ============================================================================

/// 会员资料（对应 `public.user_profiles` 视图的一行）。
///
/// 所有字段均可空：视图查不到行（如触发器还没把 `public.users` 补上）时，
/// UI 会用 Auth 侧的 `User` 信息兜底，而不是直接报错。
class UserProfile {
  /// 创建会员资料实例。
  ///
  /// 参数与视图列名一一对应，全部为可空，解析失败时保持 null 而非抛异常。
  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.isMember = false,
    this.memberExpireAt,
    this.isMemberActive = false,
    this.createdAt,
  });

  /// 用户 ID（与 `auth.users.id` 同值，即 `public.users` 的主键）。
  final String id;

  /// 邮箱。
  final String? email;

  /// 昵称；未设置时为 null，UI 需回落到邮箱前缀。
  final String? displayName;

  /// 头像 URL；Google 登录时由 Supabase 写入，邮箱注册通常为空。
  final String? avatarUrl;

  /// 是否买过会员（只看「买过」，不管是否已过期）。
  final bool isMember;

  /// 会员到期时间；null 表示不限期（买断制）。
  final DateTime? memberExpireAt;

  /// 会员当前是否有效（买过 且 未到期），由视图算好，UI 直接用。
  final bool isMemberActive;

  /// 注册时间，暂未展示，预留给「加入 xx 天」之类文案。
  final DateTime? createdAt;

  /// 从 PostgREST 返回的行数据构造实例。
  ///
  /// 为什么每个字段都做类型兜底：PostgREST 把 timestamp 以字符串返回、
  /// 布尔也可能因视图/驱动差异表现为字符串，直接 `as bool` 会在真机上崩溃。
  /// 这里统一走 `_asBool` / `_asDate`，解析不出来就取默认值，宁可少显示一项。
  ///
  /// 参数：[row] `select()` 返回的一行 Map，键为列名。
  factory UserProfile.fromRow(Map<String, dynamic> row) {
    // 头像：空字符串视为「没有头像」，避免 Image.network('') 抛异常。
    final rawAvatar = row['avatar_url']?.toString().trim();
    return UserProfile(
      id: row['id']?.toString() ?? '',
      email: row['email']?.toString(),
      displayName: row['display_name']?.toString(),
      avatarUrl: (rawAvatar == null || rawAvatar.isEmpty) ? null : rawAvatar,
      isMember: _asBool(row['is_member']) ?? false,
      memberExpireAt: _asDate(row['member_expire_at']),
      isMemberActive: _asBool(row['is_member_active']) ?? false,
      createdAt: _asDate(row['created_at']),
    );
  }

  /// 把动态值转成 bool。
  ///
  /// 支持 bool 与 'true'/'false' 字符串两种形态；其余返回 null。
  static bool? _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// 把动态值转成 DateTime。
  ///
  /// PostgREST 返回形如 `2026-09-02T12:34:56+00:00` 的字符串，
  /// [DateTime.tryParse] 可直接处理；解析失败返回 null 而不是抛异常。
  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// 展示用昵称：昵称 → 邮箱前缀 → 兜底 'User'。
  ///
  /// 三级回落保证 UI 永远有内容可显示，不会出现空白昵称行。
  String get bestDisplayName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return 'User';
  }
}
