// 방 사진 분석과 비포·애프터 비교. Edge Functions(Deno)와 품질 테스트 도구(Node)가 함께 쓴다.
// 외부 모듈은 bare import로 적고, Deno는 deno.json의 import map, Node는 node_modules로 찾는다.
import type Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

export const PROMPT_VERSION = "room-v1";

export type Zone = "room" | "fridge" | "bathroom" | "kitchen";
export type ImageMediaType = "image/jpeg" | "image/png" | "image/webp";

const ZONE_LABEL: Record<Zone, string> = {
  room: "원룸의 방",
  fridge: "냉장고 안",
  bathroom: "화장실",
  kitchen: "주방",
};

const TaskSchema = z.object({
  title: z.string(),
  minutes: z.number().int(),
});

const HotspotSchema = z.object({
  name: z.string(),
  typical_items: z.array(z.string()),
  tasks: z.array(TaskSchema),
});

const RoomAnalysisSchema = z.object({
  is_room: z.boolean(),
  messiness: z.number().int(),
  summary: z.string(),
  hotspots: z.array(HotspotSchema),
  today_tasks: z.array(
    z.object({
      title: z.string(),
      area: z.string(),
      minutes: z.number().int(),
    }),
  ),
  encouragement: z.string(),
});

const CompareSchema = z.object({
  same_place: z.boolean(),
  improved_areas: z.array(z.string()),
  before_messiness: z.number().int(),
  after_messiness: z.number().int(),
  praise: z.string(),
});

export type RoomAnalysis = z.infer<typeof RoomAnalysisSchema>;
export type CompareResult = z.infer<typeof CompareSchema>;

export interface Usage {
  input_tokens: number;
  output_tokens: number;
}

export class RefusalError extends Error {}
export class ModelOutputError extends Error {}

const CHARACTER_VOICE =
  "캐릭터는 사용자와 함께 사는 작고 다정한 친구다. 반말로 짧게 말하고, 사용자를 탓하거나 부끄럽게 만들지 않는다. 이모지는 쓰지 않는다.";

function analysisSystem(zone: Zone): string {
  return [
    `너는 ${ZONE_LABEL[zone]}을 정리하도록 돕는 청소 코치다. 사용자는 청소를 귀찮아하고, 막막해서 시작을 못 하는 사람이다.`,
    "사진을 보고 아래 규칙대로 JSON을 채운다.",
    "",
    "규칙:",
    "- 사진에 실제로 보이는 물건과 구역만 말한다. 보이지 않는 것을 추측하지 않는다.",
    `- 사진이 ${ZONE_LABEL[zone]}이 아니거나 너무 어둡거나 흐려서 판단할 수 없으면 is_room을 false로 하고, 나머지 배열은 비우고 문자열은 빈 문자열, messiness는 0으로 둔다.`,
    "- messiness는 0(아주 깨끗함)부터 100(아주 어지러움)까지의 정수다.",
    "- summary는 지금 상태를 한 문장으로, 비난 없이 쓴다.",
    "- hotspots는 이 공간에서 자주 어질러지는 구역 2~6개다. name은 '책상 위', '침대 옆 의자'처럼 짧게 쓴다.",
    "- 각 hotspot의 typical_items는 그 구역에 보이는 물건 1~5개, tasks는 그 구역에서 할 수 있는 일 3~5개다.",
    "- 모든 task의 title은 '컵을 싱크대로 옮기기'처럼 바로 따라 할 수 있는 구체적인 행동으로, 40자 이내로 쓴다. minutes는 1~5분이다.",
    "- 청소기, 걸레질처럼 사진과 상관없이 늘 하는 일은 넣지 않는다. 그런 일은 앱의 반복 일정이 따로 챙긴다.",
    "- today_tasks는 지금 하면 가장 달라 보이는 일 정확히 3개다. 효과가 큰 순서로 정렬하고, minutes 합계는 5~10분이다. area는 hotspots의 name 중 하나다.",
    `- encouragement는 캐릭터가 건네는 한두 문장의 응원이다. ${CHARACTER_VOICE}`,
  ].join("\n");
}

const COMPARE_SYSTEM = [
  "너는 청소 코치다. 첫 번째 사진은 청소 전, 두 번째 사진은 청소 후다.",
  "규칙:",
  "- 두 사진이 같은 공간이 아니면 same_place를 false로 하고 improved_areas는 비운다.",
  "- improved_areas는 눈에 띄게 나아진 구역이나 물건을 1~4개, 짧은 구절로 쓴다. 나아진 곳이 없으면 비운다.",
  "- before_messiness와 after_messiness는 0(아주 깨끗함)~100(아주 어지러움) 정수다.",
  `- praise는 캐릭터가 건네는 한두 문장의 칭찬이다. 나아진 점을 구체적으로 짚는다. ${CHARACTER_VOICE}`,
].join("\n");

function clampInt(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, Math.round(n)));
}

function cut(s: string, max: number): string {
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

// 모델 출력을 앱이 믿고 쓸 수 있는 범위로 다듬는다.
export function normalizeAnalysis(raw: RoomAnalysis): RoomAnalysis {
  if (!raw.is_room) {
    return { is_room: false, messiness: 0, summary: "", hotspots: [], today_tasks: [], encouragement: "" };
  }
  const hotspots = raw.hotspots.slice(0, 6).map((h) => ({
    name: cut(h.name, 40),
    typical_items: h.typical_items.slice(0, 5).map((i) => cut(i, 30)),
    tasks: h.tasks.slice(0, 5).map((t) => ({ title: cut(t.title, 40), minutes: clampInt(t.minutes, 1, 5) })),
  }));
  return {
    is_room: true,
    messiness: clampInt(raw.messiness, 0, 100),
    summary: cut(raw.summary, 120),
    hotspots,
    today_tasks: raw.today_tasks.slice(0, 3).map((t) => ({
      title: cut(t.title, 40),
      area: cut(t.area, 40),
      minutes: clampInt(t.minutes, 1, 5),
    })),
    encouragement: cut(raw.encouragement, 120),
  };
}

function imageBlock(data: string, mediaType: ImageMediaType): Anthropic.ImageBlockParam {
  return { type: "image", source: { type: "base64", media_type: mediaType, data } };
}

function checkStop(response: { stop_reason: string | null }): void {
  if (response.stop_reason === "refusal") throw new RefusalError("model refused the request");
  if (response.stop_reason === "max_tokens") throw new ModelOutputError("response hit max_tokens");
}

export async function analyzeRoom(
  client: Anthropic,
  opts: { model: string; image: string; mediaType: ImageMediaType; zone?: Zone },
): Promise<{ result: RoomAnalysis; usage: Usage }> {
  const zone = opts.zone ?? "room";
  const response = await client.messages.parse({
    model: opts.model,
    max_tokens: 8000,
    output_config: { effort: "low", format: zodOutputFormat(RoomAnalysisSchema) },
    system: analysisSystem(zone),
    messages: [
      {
        role: "user",
        content: [imageBlock(opts.image, opts.mediaType), { type: "text", text: "이 사진을 분석해줘." }],
      },
    ],
  });
  checkStop(response);
  if (!response.parsed_output) throw new ModelOutputError("structured output could not be parsed");
  return { result: normalizeAnalysis(response.parsed_output), usage: response.usage };
}

export async function compareBeforeAfter(
  client: Anthropic,
  opts: { model: string; before: string; after: string; mediaType: ImageMediaType },
): Promise<{ result: CompareResult; usage: Usage }> {
  const response = await client.messages.parse({
    model: opts.model,
    max_tokens: 4000,
    output_config: { effort: "low", format: zodOutputFormat(CompareSchema) },
    system: COMPARE_SYSTEM,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: "청소 전:" },
          imageBlock(opts.before, opts.mediaType),
          { type: "text", text: "청소 후:" },
          imageBlock(opts.after, opts.mediaType),
        ],
      },
    ],
  });
  checkStop(response);
  const raw = response.parsed_output;
  if (!raw) throw new ModelOutputError("structured output could not be parsed");
  return {
    result: {
      same_place: raw.same_place,
      improved_areas: raw.same_place ? raw.improved_areas.slice(0, 4).map((a) => cut(a, 40)) : [],
      before_messiness: clampInt(raw.before_messiness, 0, 100),
      after_messiness: clampInt(raw.after_messiness, 0, 100),
      praise: cut(raw.praise, 120),
    },
    usage: response.usage,
  };
}
