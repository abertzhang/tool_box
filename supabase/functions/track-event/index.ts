// 文件职责：Supabase Edge Function —— track-event 网关。
// 所属模块：supabase/functions/track-event（边缘函数）。
// 关键依赖：Deno runtime + supabase-js（v2，CDN 导入）。
//
// 接口约定（与 Flutter client track transport 对齐）：
//   URL:    {SUPABASE_URL}/functions/v1/track-event
//   Method: POST
//   Headers:
//     - Content-Type: application/json
//     - apikey: <anon/publishable key>          ← Supabase Edge Function 默认要求
//     - Authorization: Bearer <anon key>       ← 同上
//     - X-Client-Token: <可选客户端令牌>          ← 业务校验
//   Body:
//     { "app_id": "tool_box", "events": [ {row}, {row}, ... ] }
//
// 返回值：
//   - 200 / 201：写入成功，返回 { inserted: N }
//   - 400：app_id 缺失 / events 为空 / 单批超限
//   - 401：未携带 apikey 或 Authorization
//   - 403：app_id 不在白名单 或 X-Client-Token 错误
//

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------- 配置 ----------------
// 通过 `supabase secrets set` 或 `supabase functions deploy --env-vars` 注入。
// 这里给的是占位，生产必须替换。
const ALLOWED_APP_IDS = (Deno.env.get("ALLOWED_APP_IDS") ?? "tool_box,knot_phone")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const CLIENT_TOKEN = Deno.env.get("CLIENT_TOKEN") ?? ""; // 留空表示跳过 X-Client-Token 校验

// 单批最大事件数（与 dart 端 TrackConfig.maxBatchBytes 配合）。
const MAX_BATCH = 500;

// ---------------- 工具 ----------------
function jsonResponse(status: number, body: Record<string, any>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      // 关闭 Edge Function 默认缓存，确保客户端即时看到结果
      "Cache-Control": "no-store",
    },
  });
}

/** 入口主处理函数。 */
Deno.serve(async (req: Request) => {
  // 1. 方法校验
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  // 2. 鉴权：apikey / Authorization 任一即可（Edge Function 默认要求）
  const apikey = req.headers.get("apikey") ?? "";
  const auth = req.headers.get("authorization") ?? "";
  const bearer = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7) : "";
  if (!apikey && !bearer) {
    return jsonResponse(401, { error: "missing_apikey" });
  }
  const supabaseKey = apikey || bearer;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) {
    return jsonResponse(500, { error: "missing_supabase_url_in_function_env" });
  }

  // 3. 业务令牌校验（可选）
  const clientToken = req.headers.get("x-client-token") ?? "";
  if (CLIENT_TOKEN && clientToken !== CLIENT_TOKEN) {
    return jsonResponse(403, { error: "invalid_client_token" });
  }

  // 4. 解析 body
  let body: any;
  try {
    body = await req.json();
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }
  const appId: string = body?.app_id ?? "";
  const events: any[] = Array.isArray(body?.events) ? body.events : [];

  // 5. app_id 白名单
  if (!ALLOWED_APP_IDS.includes(appId)) {
    return jsonResponse(403, { error: "app_id_not_allowed", app_id: appId });
  }
  if (events.length === 0) {
    return jsonResponse(400, { error: "empty_events" });
  }
  if (events.length > MAX_BATCH) {
    return jsonResponse(400, {
      error: "batch_too_large",
      limit: MAX_BATCH,
      received: events.length,
    });
  }

  // 6. 服务端二次过滤：丢弃 app_id 不一致的行、剥离客户端不可控字段
  //    防止客户端伪造 / 注入脏数据
  const cleaned = events
    .filter((e: any) => e && typeof e === "object")
    .map((e: any) => {
      // 强制覆盖 app_id，避免客户端伪造
      const rest = { ...e, app_id: appId };
      // received_at / created_at 由数据库默认值生成，客户端写的覆盖掉
      delete rest.received_at;
      delete rest.created_at;
      delete rest.id; // 主键交给数据库 gen_random_uuid
      return rest;
    });

  if (cleaned.length === 0) {
    return jsonResponse(400, { error: "no_valid_events" });
  }

  // 7. service_role 直写：绕开 RLS（RLS 本来就禁了 anon / authenticated）
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", {
    auth: { persistSession: false },
  });

  const { error } = await admin.from("app_events").insert(cleaned);
  if (error) {
    return jsonResponse(500, {
      error: "insert_failed",
      detail: error.message ?? String(error),
    });
  }

  return jsonResponse(200, { inserted: cleaned.length });
});
