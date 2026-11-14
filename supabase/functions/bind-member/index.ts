// 文件职责：Supabase Edge Function —— bind-member（会员权益上云绑定网关）。
// 所属模块：supabase/functions/bind-member（边缘函数）。
// 关键依赖：Deno runtime + supabase-js（v2，CDN 导入）。
//
// 业务背景（方案 B · Phase 1，见 doc/purchase_handoff.md §9）：
//   用户在 App 内完成买断购买后（或已持有本机买断权益后登录），把「买过会员」
//   这一事实同步到 `public.users.is_member`，实现跨设备 / 重装后的云端恢复。
//   客户端判定层读 `user_profiles.is_member_active`（视图已算好「买过且未过期」），
//   上云后无需改动客户端判定逻辑即自动生效。
//
// 安全边界（Phase 1，用户已拍板接受）：
//   本函数**不校验商店收据** —— 已登录用户伪造一次调用即可点亮云端会员。
//   风险评估与「方案 A 纯端侧」等价：伪造者不登录也有本机买断权益，上云绑定
//   不是提权，只是多一条恢复通道。真正防伪造的收据校验属 Phase 2（可选），
//   扩展点已在下方 write 步骤预留。service_role key 只存在于服务端环境变量，
//   绝不回传客户端。
//
// 接口约定：
//   URL:    {SUPABASE_URL}/functions/v1/bind-member
//   Method: POST
//   Headers:
//     - apikey: <anon/publishable key>           ← Edge Function 默认要求
//     - Authorization: Bearer <user access token> ← 关键：取调用者身份，拒绝匿名
//   Body: {}（当前无业务参数；Phase 2 会加 transactionId / purchaseToken 等收据字段）
//
// 返回值：
//   - 200：写入成功，返回 { ok: true }
//   - 400：请求体非法
//   - 401：未携带用户 token / 无法解析出调用者身份（匿名拒绝）
//   - 500：数据库写失败
//
// 部署（沿用 track-event 模式）：
//   supabase functions deploy bind-member --no-verify-jwt
//   （SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 由 Supabase 平台自动注入，
//    无需 --env-vars；--no-verify-jwt 是因为我们自行校验用户 token 而非
//    依赖平台网关对 JWT 的默认校验，便于对鉴权失败给出更清晰的业务错误码。）

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/** 统一 JSON 响应封装，关闭缓存。 */
function jsonResponse(status: number, body: Record<string, any>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

/** 入口主处理函数。 */
Deno.serve(async (req: Request) => {
  // 1. 方法校验：只接受 POST。
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  // 2. 取平台与用户令牌。
  //    - apikey：Edge Function 的默认门禁（anon key 即可）；
  //    - Authorization Bearer：**用户 access token**，用于解析调用者身份。
  //      与 track-event 不同，这里必须拿到「是哪个用户」才能写对行，
  //      所以 Bearer 必须传，且不能是 anon key。
  const apikey = req.headers.get("apikey") ?? "";
  const auth = req.headers.get("authorization") ?? "";
  const bearer = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7) : "";
  if (!apikey) {
    return jsonResponse(401, { error: "missing_apikey" });
  }
  if (!bearer) {
    return jsonResponse(401, { error: "missing_user_token" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(500, { error: "missing_function_env" });
  }

  // 3. 用**用户 token** 建立临时客户端，解析调用者身份。
  //    这里不能用 service_role 解析身份（service_role 不绑定具体用户），
  //    而 getUser 需要携带用户的 access token 才能返回正确 uid。
  const userClient = createClient(supabaseUrl, apikey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData?.user) {
    return jsonResponse(401, { error: "invalid_user_token", detail: authError?.message });
  }
  const uid = authData.user.id;

  // 4. 解析 body（Phase 1 业务上不需要参数；Phase 2 在此取收据字段并校验）。
  //
  // ⚠️ 必须容错「空 body」：客户端 `functions.invoke('bind-member')` 不传 body 时
  // 请求体是**空字符串**，直接 `req.json()` 会抛异常 → 误判成 400 invalid_json，
  // 表现为「绑定永远失败」。所以先读文本，空则当 `{}` 处理。
  let body: any = {};
  try {
    const raw = await req.text();
    if (raw.trim().length > 0) {
      body = JSON.parse(raw);
    }
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }
  // 保留 Phase 2 扩展位：收据校验逻辑应放在「写库」之前，校验失败即拒绝。
  // void body; // Phase 2 使用，Phase 1 无需读取。

  // 5. service_role 写库：绕开 RLS（public.users 的 RLS 只允许用户改自己的
  //    资料行，会员字段更是被触发器对非特权调用者强制拒绝）。
  //    ⚠️ 幂等：`set is_member = true, member_expire_at = null` 二次执行结果不变，
  //    重复调用无副作用（买断制 → 到期置 null 表示不限期）。
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // 先确认行存在；handle_new_user 触发器理论上保证 OAuth 建号即补行，
  // 但为稳妥起见：行缺失时补插兜底（只带 id 主键，其余走数据库默认值）。
  const { data: existing } = await admin
    .from("users")
    .select("id")
    .eq("id", uid)
    .maybeSingle();
  if (!existing) {
    const { error: insErr } = await admin.from("users").insert({ id: uid });
    if (insErr) {
      return jsonResponse(500, { error: "insert_user_failed", detail: insErr.message });
    }
  }

  const { error: updErr } = await admin
    .from("users")
    .update({ is_member: true, member_expire_at: null })
    .eq("id", uid);
  if (updErr) {
    return jsonResponse(500, { error: "update_failed", detail: updErr.message });
  }

  return jsonResponse(200, { ok: true });
});
