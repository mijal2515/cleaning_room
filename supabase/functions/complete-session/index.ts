// 청소 완료: 체크한 할 일 수로 코인을 주고, 비포·애프터 사진이 있으면 AI 칭찬을 붙인다.
// 사진은 선택이다. 사진이 없어도 기본 코인은 받는다.
import { compareBeforeAfter } from "../_shared/room-analysis.ts";
import {
  anthropicClient,
  getConfig,
  json,
  readImage,
  readMediaType,
  requireUser,
  serviceClient,
} from "../_shared/supabase.ts";

const KINDS = ["daily", "register", "weekly", "now"] as const;
type Kind = (typeof KINDS)[number];

interface TaskInput {
  title: string;
  minutes: number;
  done: boolean;
}

function readTasks(value: unknown): TaskInput[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > 10) return null;
  const tasks: TaskInput[] = [];
  for (const t of value) {
    if (typeof t?.title !== "string" || typeof t?.done !== "boolean") return null;
    tasks.push({
      title: t.title.slice(0, 40),
      minutes: Number.isFinite(t.minutes) ? Math.min(30, Math.max(1, Math.round(t.minutes))) : 1,
      done: t.done,
    });
  }
  return tasks;
}

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

  const kind = (body.kind ?? "daily") as Kind;
  const tasks = readTasks(body.tasks);
  if (!KINDS.includes(kind) || !tasks) return json({ error: "invalid_request" }, 400);

  const after = body.after_image === undefined ? null : readImage(body.after_image);
  const before = body.before_image === undefined ? null : readImage(body.before_image);
  const mediaType = readMediaType(body.media_type ?? "image/jpeg");
  if ((body.after_image !== undefined && !after) || (body.before_image !== undefined && !before) || !mediaType) {
    return json({ error: "invalid_image" }, 400);
  }

  // 비포·애프터가 모두 있을 때만 AI로 비교한다. 실패해도 코인은 준다.
  let compare = null;
  if (before && after) {
    const { data: allowed } = await admin.rpc("consume_ai_quota", { p_user_id: user.id, p_kind: "compare" });
    if (allowed) {
      try {
        const model = await getConfig(admin, "ai_model", "claude-haiku-5-5");
        compare = (await compareBeforeAfter(anthropicClient(), { model, before, after, mediaType })).result;
      } catch (e) {
        console.error("compare failed", e);
      }
    }
  }

  // 서로 다른 곳을 찍었으면 사진 보너스를 주지 않는다.
  const afterPhoto = after !== null && (compare === null || compare.same_place);

  const { data: reward, error } = await admin.rpc("complete_session", {
    p_user_id: user.id,
    p_kind: kind,
    p_tasks: tasks,
    p_tasks_total: tasks.length,
    p_tasks_completed: tasks.filter((t) => t.done).length,
    p_after_photo: afterPhoto,
  });
  if (error) {
    console.error("complete_session failed", error);
    return json({ error: "server_error" }, 500);
  }

  return json({ ...reward, compare });
});
