// 방 사진 1장 → 방 프로필(구역별 할 일)과 지금 할 일 3개
// 방 등록(register), 주간 점검(weekly), "오늘 너무 지저분해" 버튼(now)에서만 부른다.
import { analyzeRoom, ModelOutputError, PROMPT_VERSION, RefusalError } from "../_shared/room-analysis.ts";
import {
  anthropicClient,
  getConfig,
  json,
  readImage,
  readMediaType,
  requireUser,
  serviceClient,
} from "../_shared/supabase.ts";

const MODES = ["register", "weekly", "now"] as const;
type Mode = (typeof MODES)[number];

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = serviceClient();
  const user = await requireUser(req, admin);
  if (!user) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const mode = body.mode as Mode;
  const image = readImage(body.image);
  const mediaType = readMediaType(body.media_type);
  if (!MODES.includes(mode) || !image || !mediaType) return json({ error: "invalid_request" }, 400);

  // MVP는 방만 연다. 냉장고·화장실은 3차에서 연다.
  const zone = "room";

  const { data: allowed, error: quotaError } = await admin.rpc("consume_ai_quota", {
    p_user_id: user.id,
    p_kind: "analysis",
  });
  if (quotaError) return json({ error: "server_error" }, 500);
  if (!allowed) return json({ error: "daily_limit" }, 429);

  const model = await getConfig(admin, "ai_model", "claude-haiku-5-5");

  let analysis;
  try {
    analysis = (await analyzeRoom(anthropicClient(), { model, image, mediaType, zone })).result;
  } catch (e) {
    if (e instanceof RefusalError) return json({ error: "refused" }, 422);
    if (e instanceof ModelOutputError) return json({ error: "ai_output" }, 502);
    console.error("analyze-room failed", e);
    return json({ error: "ai_unavailable" }, 502);
  }

  if (!analysis.is_room) return json({ is_room: false });

  // 방 등록과 주간 점검은 AI가 만든 구역을 새로 바꾼다. 사용자가 직접 만든 구역은 그대로 둔다.
  if (mode === "register" || mode === "weekly") {
    const { error: deleteError } = await admin
      .from("room_hotspots")
      .delete()
      .eq("user_id", user.id)
      .eq("zone", zone)
      .eq("source", "ai");
    if (deleteError) return json({ error: "server_error" }, 500);

    const { error: insertError } = await admin.from("room_hotspots").insert(
      analysis.hotspots.map((h, i) => ({
        user_id: user.id,
        zone,
        name: h.name,
        typical_items: h.typical_items,
        tasks: h.tasks,
        source: "ai",
        sort_order: i,
      })),
    );
    if (insertError) return json({ error: "server_error" }, 500);
  }

  const { data: session, error: sessionError } = await admin
    .from("sessions")
    .insert({
      user_id: user.id,
      kind: mode,
      zone,
      tasks: analysis.today_tasks,
      messiness: analysis.messiness,
      tasks_total: analysis.today_tasks.length,
    })
    .select("id")
    .single();
  if (sessionError) return json({ error: "server_error" }, 500);

  return json({ ...analysis, session_id: session.id, prompt_version: PROMPT_VERSION });
});
