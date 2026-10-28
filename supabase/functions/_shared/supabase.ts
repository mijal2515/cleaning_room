// Edge Functions 공용: 서버 권한 클라이언트, 로그인 사용자 확인, 설정 읽기, 응답 헬퍼
import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import Anthropic from "@anthropic-ai/sdk";
import type { ImageMediaType } from "./room-analysis.ts";

export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function anthropicClient(): Anthropic {
  return new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
}

export async function requireUser(req: Request, admin: SupabaseClient): Promise<User | null> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  return error ? null : data.user;
}

export async function getConfig<T>(admin: SupabaseClient, key: string, fallback: T): Promise<T> {
  const { data } = await admin.from("app_config").select("value").eq("key", key).maybeSingle();
  return (data?.value as T) ?? fallback;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

const MEDIA_TYPES: ImageMediaType[] = ["image/jpeg", "image/png", "image/webp"];
// 앱은 긴 변 1024px, JPEG 품질 70으로 줄여 보낸다(보통 200KB 안팎). 여유를 두고 1.5MB까지 받는다.
const MAX_IMAGE_BASE64_CHARS = 2_000_000;

export function readImage(value: unknown): string | null {
  if (typeof value !== "string" || value.length === 0 || value.length > MAX_IMAGE_BASE64_CHARS) return null;
  return /^[A-Za-z0-9+/]+={0,2}$/.test(value) ? value : null;
}

export function readMediaType(value: unknown): ImageMediaType | null {
  return MEDIA_TYPES.includes(value as ImageMediaType) ? (value as ImageMediaType) : null;
}
