// AI 품질 테스트: 사진 폴더를 앱과 같은 프롬프트로 분석하고, 직접 채점할 수 있는 HTML 보고서를 만든다.
//
//   ANTHROPIC_API_KEY=... node tools/ai-eval/run.ts <사진 폴더> [--model claude-haiku-5-5] [--model claude-sonnet-5-5]
//
// 결과: tools/ai-eval/out/<시각>/report.html, results.json
import Anthropic from "@anthropic-ai/sdk";
import sharp from "sharp";
import { mkdir, readdir, writeFile } from "node:fs/promises";
import { extname, join, basename } from "node:path";
import { analyzeRoom, PROMPT_VERSION, type RoomAnalysis, type Usage } from "../../supabase/functions/_shared/room-analysis.ts";

// 달러 / 100만 토큰 (2026-10 기준). 모르는 모델은 비용을 비워둔다.
const PRICES: Record<string, { input: number; output: number }> = {
  "claude-haiku-5-5": { input: 0.1, output: 0.5 },
  "claude-sonnet-5-5": { input: 2, output: 10 },
};
const IMAGE_EXTS = new Set([".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"]);
const CONCURRENCY = 3;

interface Row {
  file: string;
  model: string;
  ms: number;
  usage?: Usage;
  costUsd?: number;
  result?: RoomAnalysis;
  error?: string;
}

function parseArgs(argv: string[]): { dir: string; models: string[] } {
  const models: string[] = [];
  let dir = "";
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--model") models.push(argv[++i]);
    else dir = argv[i];
  }
  if (!dir) {
    console.error("사용법: node tools/ai-eval/run.ts <사진 폴더> [--model 모델ID ...]");
    process.exit(1);
  }
  return { dir, models: models.length ? models : ["claude-haiku-5-5"] };
}

// 앱과 같은 조건: 긴 변 1024px, JPEG 품질 70
async function prepare(path: string): Promise<{ jpeg: Buffer; thumb: string }> {
  const jpeg = await sharp(path).rotate().resize(1024, 1024, { fit: "inside", withoutEnlargement: true }).jpeg({ quality: 70 }).toBuffer();
  const thumb = await sharp(jpeg).resize(360, 360, { fit: "inside" }).jpeg({ quality: 60 }).toBuffer();
  return { jpeg, thumb: `data:image/jpeg;base64,${thumb.toString("base64")}` };
}

async function pool<T>(items: T[], limit: number, worker: (item: T) => Promise<void>): Promise<void> {
  const queue = [...items];
  await Promise.all(
    Array.from({ length: Math.min(limit, queue.length) }, async () => {
      for (let item = queue.shift(); item !== undefined; item = queue.shift()) await worker(item);
    }),
  );
}

function esc(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
}

function renderResult(r: Row): string {
  if (r.error) return `<p class="err">오류: ${esc(r.error)}</p>`;
  const a = r.result!;
  if (!a.is_room) return `<p class="muted">방이 아니라고 판단함 (is_room: false)</p>`;
  const today = a.today_tasks.map((t) => `<li>${esc(t.title)} <span class="muted">· ${esc(t.area)} · ${t.minutes}분</span></li>`).join("");
  const hotspots = a.hotspots
    .map(
      (h) =>
        `<li><b>${esc(h.name)}</b> <span class="muted">(${h.typical_items.map(esc).join(", ")})</span><ul>${h.tasks
          .map((t) => `<li>${esc(t.title)} <span class="muted">· ${t.minutes}분</span></li>`)
          .join("")}</ul></li>`,
    )
    .join("");
  const total = a.today_tasks.reduce((s, t) => s + t.minutes, 0);
  return `<p>어지러움 <b>${a.messiness}</b> · ${esc(a.summary)}</p>
<p><b>오늘 할 일</b> <span class="muted">(합계 ${total}분)</span></p><ol>${today}</ol>
<details><summary>방 프로필 구역 ${a.hotspots.length}개</summary><ul>${hotspots}</ul></details>
<p class="voice">“${esc(a.encouragement)}”</p>`;
}

function renderReport(rows: Row[], thumbs: Map<string, string>, models: string[]): string {
  const files = [...thumbs.keys()];
  const summary = models
    .map((m) => {
      const mine = rows.filter((r) => r.model === m);
      const ok = mine.filter((r) => r.result);
      const cost = mine.reduce((s, r) => s + (r.costUsd ?? 0), 0);
      const avgMs = ok.length ? Math.round(ok.reduce((s, r) => s + r.ms, 0) / ok.length) : 0;
      return `<tr><td>${esc(m)}</td><td>${ok.length}/${mine.length}</td><td>${(avgMs / 1000).toFixed(1)}초</td><td>$${cost.toFixed(4)}</td><td class="score" data-model="${esc(m)}">-</td></tr>`;
    })
    .join("");
  const cards = files
    .map((f) => {
      const cols = models
        .map((m) => {
          const r = rows.find((x) => x.file === f && x.model === m)!;
          const key = `${f}::${m}`;
          return `<div class="col"><h4>${esc(m)}</h4>${renderResult(r)}
<div class="grade" data-key="${esc(key)}" data-model="${esc(m)}">
  <label><input type="radio" name="${esc(key)}" value="2"> 바로 따라 할 만함</label>
  <label><input type="radio" name="${esc(key)}" value="1"> 애매함</label>
  <label><input type="radio" name="${esc(key)}" value="0"> 틀림·쓸모없음</label>
</div></div>`;
        })
        .join("");
      return `<section class="card"><img src="${thumbs.get(f)}" alt="${esc(f)}"><div class="body"><h3>${esc(f)}</h3><div class="cols">${cols}</div></div></section>`;
    })
    .join("");

  return `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI 품질 테스트</title>
<style>
:root{--bg:#fafaf7;--fg:#1d1d1b;--muted:#6b6b66;--line:#e2e1da;--accent:#2f6fde}
@media (prefers-color-scheme:dark){:root{--bg:#161615;--fg:#ecebe6;--muted:#9a9993;--line:#33322f;--accent:#7aa7ff}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;padding:16px;max-width:1200px;margin:auto}
table{border-collapse:collapse;margin:8px 0 24px}td,th{border-bottom:1px solid var(--line);padding:6px 12px;text-align:left}
.card{display:flex;gap:16px;border-top:1px solid var(--line);padding:16px 0;flex-wrap:wrap}
.card img{width:280px;max-width:100%;border-radius:8px;align-self:flex-start}.body{flex:1;min-width:280px}
.cols{display:flex;gap:16px;flex-wrap:wrap}.col{flex:1;min-width:260px}h3{margin:0 0 8px}h4{margin:0 0 4px;color:var(--accent)}
.muted{color:var(--muted)}.err{color:#c0392b}.voice{color:var(--muted);font-style:italic}
.grade{display:flex;flex-direction:column;gap:2px;margin-top:8px;padding:8px;border:1px solid var(--line);border-radius:8px}
</style></head><body>
<h1>AI 품질 테스트</h1>
<p class="muted">프롬프트 ${PROMPT_VERSION} · 사진 ${files.length}장 · ${new Date().toLocaleString("ko-KR")}</p>
<p>사진마다 "오늘 할 일 3개"를 보고 채점하세요. 채점은 이 브라우저에 저장됩니다. 관문 기준: "바로 따라 할 만함"이 80% 이상.</p>
<table><tr><th>모델</th><th>성공</th><th>평균 응답</th><th>비용</th><th>따라 할 만함</th></tr>${summary}</table>
${cards}
<script>
const KEY='ai-eval:'+document.title+':'+${JSON.stringify(PROMPT_VERSION)}+':'+${files.length};
let saved={};try{saved=JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){}
function refresh(){document.querySelectorAll('td.score').forEach(td=>{const m=td.dataset.model;const gs=[...document.querySelectorAll('.grade[data-model="'+CSS.escape(m)+'"]')];const done=gs.filter(g=>saved[g.dataset.key]!==undefined);const good=done.filter(g=>saved[g.dataset.key]==='2');td.textContent=done.length?Math.round(good.length/done.length*100)+'% ('+good.length+'/'+done.length+')':'-';});}
document.querySelectorAll('.grade').forEach(g=>{const v=saved[g.dataset.key];if(v!==undefined){const i=g.querySelector('input[value="'+v+'"]');if(i)i.checked=true;}
g.addEventListener('change',e=>{saved[g.dataset.key]=e.target.value;try{localStorage.setItem(KEY,JSON.stringify(saved))}catch(err){}refresh();});});
refresh();
</script></body></html>`;
}

async function main(): Promise<void> {
  const { dir, models } = parseArgs(process.argv.slice(2));
  const files = (await readdir(dir)).filter((f) => IMAGE_EXTS.has(extname(f).toLowerCase())).sort();
  if (files.length === 0) throw new Error(`사진이 없습니다: ${dir}`);

  const client = new Anthropic();
  const thumbs = new Map<string, string>();
  const images = new Map<string, string>();
  for (const f of files) {
    const { jpeg, thumb } = await prepare(join(dir, f));
    images.set(f, jpeg.toString("base64"));
    thumbs.set(f, thumb);
  }

  const jobs = files.flatMap((file) => models.map((model) => ({ file, model })));
  const rows: Row[] = [];
  let done = 0;
  await pool(jobs, CONCURRENCY, async ({ file, model }) => {
    const started = Date.now();
    try {
      const { result, usage } = await analyzeRoom(client, { model, image: images.get(file)!, mediaType: "image/jpeg" });
      const price = PRICES[model];
      const costUsd = price ? (usage.input_tokens * price.input + usage.output_tokens * price.output) / 1e6 : undefined;
      rows.push({ file, model, ms: Date.now() - started, usage, costUsd, result });
    } catch (e) {
      rows.push({ file, model, ms: Date.now() - started, error: e instanceof Error ? e.message : String(e) });
    }
    console.log(`[${++done}/${jobs.length}] ${basename(file)} · ${model}`);
  });

  const outDir = join(import.meta.dirname, "out", new Date().toISOString().replace(/[:.]/g, "-"));
  await mkdir(outDir, { recursive: true });
  await writeFile(join(outDir, "results.json"), JSON.stringify({ prompt_version: PROMPT_VERSION, rows }, null, 2));
  await writeFile(join(outDir, "report.html"), renderReport(rows, thumbs, models));
  console.log(`\n보고서: ${join(outDir, "report.html")}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
