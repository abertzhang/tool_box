// 文件职责：token 失效的「全局一次性标记」，供路由层翻译成一次跳转。
// 所属模块：common/auth（认证与凭据）。
// 关键依赖：flutter foundation（ValueNotifier，不依赖 Widget 树）。
//
// 为什么需要一个全局标记（而不是在业务代码里 push 登录页）：
//   调用 ensureValidToken() 的地方可能在任意层级（页面、Provider、启动流程），
//   它们未必持有可用的 BuildContext；更麻烦的是冷启动/异步回调场景里
//   navigator 都还没就绪。这里沿用本工程「状态驱动导航」的既有套路
//   （与 password_recovery_state.dart 完全同构）：
//     业务侧只负责置位 → GoRouter 的 refreshListenable 感知 → redirect 跳 /login。
//   好处：导航时机由路由层统一决定，业务代码零耦合，也不会出现
//   「同一时刻被多处 push 两次登录页」的问题。
//
// 使用约定：
//   - 置位：由 AppTokenManager 在判定「需要重新登录」时置 true；
//   - 消费：由 app_router.dart 的 redirect 读取并立刻置回 false（一次性），
//     避免同一次失效反复触发跳转。

import 'package:flutter/foundation.dart';

/// token 已失效、需要用户重新登录的待处理标记。
///
/// true  → 路由层应把用户带到登录页；
/// false → 无需干预。
final ValueNotifier<bool> tokenExpiredPending = ValueNotifier<bool>(false);

/// 重置标记（供登出 / 重新登录后调用，清理可能残留的跳转请求）。
///
/// 场景：用户在登录页完成登录后，若标记没清，redirect 可能再次把人弹回登录页。
void resetTokenExpiredPending() {
  tokenExpiredPending.value = false;
}
