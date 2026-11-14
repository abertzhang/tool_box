// ============================================================================
// 文件：feature/profile/provider/user_profile_provider.dart
// 模块：个人中心（profile）/ 状态层
//
// 职责：
//   把「Supabase 是否可用 → 当前登录用户 → 会员资料」这条链路暴露成 Riverpod
//   Provider，供 ProfilePage 直接 watch。整条链路全程可降级：
//   任一环节缺失都返回空值，绝不让「Supabase 没配 / 没登录 / 查表失败」
//   演变成页面崩溃或白屏。
//
// 三个 Provider 的分层：
//   1. [supabaseReadyProvider] —— Supabase 是否初始化成功（bool，同步）。
//   2. [currentUserProvider]   —— 当前登录用户（User?，登录/登出自动刷新）。
//   3. [userProfileProvider]   —— 会员资料（AsyncValue<UserProfile?>，异步查视图）。
//
// 关键依赖：
//   - supabase_flutter：Auth 状态流 `onAuthStateChange` + 视图查询。
//   - flutter_riverpod：FutureProvider / StreamProvider / Provider。
//
// 为什么用 try/catch 探 Supabase：
//   `Supabase.instance` 在未初始化时访问会抛 LateInitializationError。
//   main.dart 的约定是「缺 key 就跳过初始化、App 照常启动」，
//   所以这里必须用 try/catch 兜住，把「不可用」表达成 false 而不是异常。
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/user_profile.dart';

/// 会员资料来源视图名。
///
/// 读视图而不是 `public.users`：视图已算好 `is_member_active`，
/// 且带 `security_invoker = true`，RLS 依旧生效（见 model 文件头注释）。
const String _profileView = 'user_profiles';

/// 业务用户表名（编辑资料时的**写入**目标）。
///
/// 为什么写表不写视图：视图只授了 SELECT，写不进去；
/// 且视图是「只读投影」，通过它改数据属于绕路。
/// 写表时 PostgREST 会走 `public.users` 自己的 RLS 与触发器，安全边界不变。
const String _usersTable = 'users';

/// Supabase 是否已初始化成功。
///
/// true  → 可用 `Supabase.instance.client`；
/// false → 没配 key，登录注册不可用，页面展示本地兜底态。
final Provider<bool> supabaseReadyProvider = Provider<bool>((ref) {
  try {
    // 只要能取到 client 就说明 main.dart 里的 Supabase.initialize 跑过了。
    // ignore: unnecessary_statements
    Supabase.instance.client;
    return true;
  } catch (e) {
    // 未初始化时这里会抛 LateInitializationError，属预期内分支，仅打日志。
    debugPrint('[Supabase] 未初始化，个人中心走本地兜底态: $e');
    return false;
  }
});

/// 鉴权状态流。
///
/// 登录后、登出后、Token 自动续期都会推送事件，页面据此自动刷新，
/// 不需要在「登录页返回」时手动触发刷新。
/// Supabase 不可用时返回空流，避免 Provider 进入永久 loading。
final StreamProvider<AuthState> authStateProvider = StreamProvider<AuthState>((
  ref,
) {
  if (!ref.watch(supabaseReadyProvider)) {
    return const Stream<AuthState>.empty();
  }
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// 当前登录用户；未登录或未配置 Supabase 时为 null。
///
/// 取值顺序：流里的 session.user（实时）→ `auth.currentUser`（首帧兜底）。
/// 之所以要兜底：`onAuthStateChange` 只在「状态变化」时推送，
/// App 冷启动且本地已存 session 时首帧还没事件，直接 watch 会误判为未登录。
final Provider<User?> currentUserProvider = Provider<User?>((ref) {
  if (!ref.watch(supabaseReadyProvider)) return null;
  // 用 .value 而非 .valueOrNull：本工程 riverpod 版本的 AsyncValue 尚无后者，
  // .value 在 loading / error 时同样返回 null，语义等价。
  final streamed = ref.watch(authStateProvider).value?.session?.user;
  return streamed ?? Supabase.instance.client.auth.currentUser;
});

/// 当前用户的会员资料。
///
/// 三种返回值：
/// - `null`：未登录 / Supabase 未配置（不需要查库，直接返回，零网络开销）；
/// - `UserProfile`：查到了 `user_profiles` 对应行；
/// - AsyncError：查询失败（网络异常、视图缺失、RLS 拒绝等），
///   UI 侧需要给出「重试」入口。
///
/// 注意：查不到行（row == null）也返回 null —— 例如 `handle_new_user`
/// 触发器还没来得及写 `public.users`。此时 UI 会用 [currentUserProvider]
/// 的邮箱兜底展示，而不是显示「资料加载失败」。
final FutureProvider<UserProfile?> userProfileProvider =
    FutureProvider<UserProfile?>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      try {
        final Map<String, dynamic>? row = await Supabase.instance.client
            .from(_profileView)
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) {
          debugPrint('[Profile] user_profiles 无对应行（id=${user.id}），用 Auth 信息兜底');
          return null;
        }
        return UserProfile.fromRow(row);
      } catch (e, st) {
        // 这里必须打堆栈：线上最常见的失败是「忘了跑建表脚本第 9 段」
        // 导致视图不存在（PGRST205），日志里要能一眼看出来。
        debugPrint('[Profile] 读取 $_profileView 失败: $e');
        debugPrint('$st');
        rethrow;
      }
    });

/// 手动刷新会员资料。
///
/// 用于「下拉刷新 / 登录成功后立刻回个人中心 / 点重试」等场景。
/// 只 invalidate 资料 Provider 即可：鉴权状态由流自动推送，不需要手动失效。
void refreshUserProfile(WidgetRef ref) {
  ref.invalidate(userProfileProvider);
}

/// 保存用户自行编辑的资料（昵称 + 头像）。
///
/// 写入策略与注册页的 `_syncUserRow` 保持一致：走 **upsert（按主键 id 合并）**，
/// 因此无论 `public.users` 里有没有这一行都能成功——
/// 早期注册、触发器还没补行的账号也能直接把资料写进去，不会「保存无效」。
///
/// 为什么 payload 里只放这四个字段（关键是**不能**放什么）：
///   建表脚本第 6 段的 `users_before_update` 触发器会拦截
///   `is_member` / `member_expire_at` / `payment_*` 的任何变动。
///   PostgREST 生成 UPDATE 时只包含 payload 里的列，其余列在触发器的 new 记录里
///   保持原值，所以这里只要**不带**那些钱相关字段就不会触发异常。
///   `updated_at` 同样由该触发器自动维护，客户端不传。
///
/// 安全性：
///   写入仍受 RLS 约束（`update own row` 策略用 using + with check 双重校验
///   `id = auth.uid()`），用户改不了别人的行，也无法把行转给自己以外的 id。
///
/// 参数：
/// - [userId] 当前登录用户的 uuid（取自 Auth），作为 upsert 的冲突键；
/// - [displayName] 昵称，调用方需先做非空与长度校验；
/// - [avatarUrl] 头像完整 URL；传 null 表示「不改动」而非「清空」——
///   本函数会**省略**该键，避免误把 Google 头像覆盖成空。
/// - [email] 可选，顺带冗余一份邮箱；为 null 时同样省略不写。
Future<void> saveUserProfile({
  required String userId,
  required String displayName,
  String? avatarUrl,
  String? email,
}) async {
  await Supabase.instance.client.from(_usersTable).upsert(<String, dynamic>{
    'id': userId,
    // `?` 是 Dart 的空感知 map 元素：值为 null 时整项被跳过，
    // 而不是写入 null。这样既保留邮箱 / 头像原值，也不会误清数据。
    'email': ?email,
    'display_name': displayName,
    'avatar_url': ?avatarUrl,
  });
}
