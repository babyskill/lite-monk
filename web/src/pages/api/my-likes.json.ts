import type { APIRoute } from "astro";
import { env } from "cloudflare:workers";
import { verifySession, SESSION_COOKIE } from "../../lib/auth";
import { getDB, ensureSchema } from "../../lib/db";

export const prerender = false;

const v = (n: string): string => {
  try { const e = (env as any)?.[n]; if (e) return String(e); } catch {}
  return (import.meta as any).env?.[n] ?? "";
};

// Slugs the signed-in user has liked (for the heart state). Personalized, so it is
// never cached. Returns an empty list when logged out.
export const GET: APIRoute = async ({ cookies }) => {
  const token = cookies.get(SESSION_COOKIE)?.value || "";
  const user = token ? await verifySession(token, v("SESSION_SECRET")) : null;
  let mine: string[] = [];
  const db = getDB();
  if (user && db) {
    await ensureSchema(db);
    const m: any = await db.prepare("SELECT slug FROM pet_likes WHERE user_id=?").bind(user.id).all();
    mine = (m?.results ?? []).map((r: any) => r.slug);
  }
  return new Response(JSON.stringify({ mine }), {
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
};
