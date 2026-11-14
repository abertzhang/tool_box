// 文件职责：Supabase Edge Function —— delete-account（注销账号网关）。
// 所属模块：supabase/functions/delete-account（边缘函数）。
// 关键依赖：Deno runtime + supabase-js（v2，CDN 导入）。
//
// 业务背景：
//   用户在 App「账号安全」页发起自助注销（删除自己的账号）。supabase_flutter 的
//   客户端**没有**「删除当前用户」的 API（GoTrue 出于安全不暴露），必须用 service_role
//   走 Admin API。因此本函数承担这一服务端能力，并严格校验「调用者只能删自己」。
//
// 安全边界（务必守住）：
//   1. 身份取自**调用者本人的 access token**（Bearer），用 user token 建客户端
//      getUser() 解析出 uid，绝不用 service_role 解析身份 —— 否则任何人都能删别人；
//   2. 只删除「当前调用者」这一个 uid，函数不接受任何 body 参数指定目标用户；
//   3. service_role key 只在服务端环境变量，绝不回传客户端。
//
// 删除顺序（兼容性考虑）：
//   先以 service_role 直删 public.users 行（绕开 RLS），再删 auth.users。
//   —— public.users.id 通常带 `references auth.users(id) on delete cascade`，
//      若级联已配置，删 auth 用户会顺带清掉业务行；但部分老表是 NO ACTION，
//      此时若先删 auth 会因外键约束失败。故「先业务表、后 auth」两步走，
//      无论级联是否配置都能成功，且 public.users 行不存在也不报错。
//
// 接口约定：
//   URL:    {SUPABASE_URL}/functions/v1/delete-account
//   Method: POST
//   Headers:
//     - apikey: <anon/publishable key>            ← Edge Function 默认门禁
//     - Authorization: Bearer <user access token> ← 取调用者身份，拒绝匿名
//   Body: {}（无业务参数；客户端空 body 会被当 {} 处理，见下方容错）
//
// 返回值：
//   - 200：删除成功，返回 { ok: true }
//   - 401：缺 apikey / 缺用户 token / token 无效（匿名拒绝）
//   - 500：数据库删除失败 / 缺函数环境变量
//
// 部署（沿用 bind-member 模式）：
//   supabase functions deploy delete-account --no-verify-jwt
//   （SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 由 Supabase 平台自动注入；
//     --no-verify-jwt 是因为我们自行校验用户 token，便于给出清晰业务错误码。）

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
  const apikey = req.headers.get("apikey") ?? "";
  const auth = req.headers.get("authorization") ?? "";
  const bearer = auth.toLowerCase().startsWith("bearer ")
    ? auth.slice(7)
    : "";
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

  // 3. 用**用户 token** 建立临时客户端，解析调用者身份（只能用用户 token 解析身份）。
  const userClient = createClient(supabaseUrl, apikey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData?.user) {
    return jsonResponse(401, {
      error: "invalid_user_token",
      detail: authError?.message,
    });
  }
  const uid = authData.user.id;

  // 4. 容错「空 body」：客户端 functions.invoke 不传 body 时请求体是空串，
  //    直接 req.json() 会抛异常 → 误判 400。先读文本，空则当 {}。
  try {
    const raw = await req.text();
    if (raw.trim().length > 0) {
      JSON.parse(raw);
    }
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }

  // 5. service_role 客户端：先删业务表行，再删 auth 用户（顺序见文件头说明）。
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // 5.1 先删 public.users（admin 直写，绕开 RLS；无行也不报错）。
  const { error: delUserErr } = await admin
    .from("users")
    .delete()
    .eq("id", uid);
  if (delUserErr) {
    return jsonResponse(500, {
      error: "delete_user_row_failed",
      detail: delUserErr.message,
    });
  }

  // 5.2 再删 auth.users（级联会清掉 public.users；前面已删则无影响）。
  const { error: delAuthErr } = await admin.auth.admin.deleteUser(uid);
  if (delAuthErr) {
    return jsonResponse(500, {
      error: "delete_auth_failed",
      detail: delAuthErr.message,
    });
  }

  return jsonResponse(200, { ok: true });
});
