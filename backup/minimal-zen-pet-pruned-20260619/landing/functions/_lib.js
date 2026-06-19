// Shared helpers for the community pet gallery Functions.
// Files starting with `_` are modules, not routes.

export const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...extra },
  });

export const slugify = (s) =>
  (s || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40) || "pet";

export const shortId = () => Math.random().toString(36).slice(2, 8);

/** Reads width/height from a PNG's IHDR header, or null if not a valid PNG. */
export function pngSize(buf) {
  const b = new Uint8Array(buf);
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  if (b.length < 24) return null;
  for (let i = 0; i < 8; i++) if (b[i] !== sig[i]) return null;
  const dv = new DataView(buf);
  return { width: dv.getUint32(16), height: dv.getUint32(20) };
}

/** Validates an uploaded spritesheet. Returns {ok} or {error}. */
export function validateSheet(buf) {
  if (buf.byteLength > 2 * 1024 * 1024) return { error: "Image must be ≤ 2MB." };
  const size = pngSize(buf);
  if (!size) return { error: "Must be a PNG image." };
  const { width, height } = size;
  if (width < 64 || height < 64 || width > 4096 || height > 4096)
    return { error: "Image dimensions look off (need 64–4096px)." };
  return { ok: true, width, height };
}

/** Public URL base for serving R2 objects through this site. */
export const fileUrl = (origin, key) => `${origin}/api/r2/${key}`;

/** Sends a Telegram message if the bot env is configured; never throws. */
export async function telegram(env, text) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) return;
  try {
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        chat_id: env.TELEGRAM_CHAT_ID,
        text,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
  } catch (_) {}
}

export const clientIp = (request) =>
  request.headers.get("cf-connecting-ip") || "0.0.0.0";

export const escapeHtml = (s) =>
  (s || "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/** True for local `wrangler pages dev`, used to gate the dev-only login. */
export const isLocalRequest = (request) => {
  const h = new URL(request.url).hostname;
  return h === "localhost" || h === "127.0.0.1" || h === "0.0.0.0";
};

// ---- Sessions & auth ----
export const SESSION_COOKIE = "sid";
const SESSION_MS = 30 * 24 * 3600 * 1000;

export function randomToken() {
  const b = new Uint8Array(24);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}

export function parseCookies(request) {
  const out = {};
  const raw = request.headers.get("cookie") || "";
  for (const part of raw.split(";")) {
    const i = part.indexOf("=");
    if (i > 0) out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}

export function cookieHeader(name, value, { maxAge, secure = true } = {}) {
  let c = `${name}=${encodeURIComponent(value)}; Path=/; HttpOnly; SameSite=Lax`;
  if (secure) c += "; Secure";
  if (maxAge != null) c += `; Max-Age=${maxAge}`;
  return c;
}

/** Creates a session for `userId` at `now` (unix ms); returns its Set-Cookie value.
 *  Pass `secure=false` for local http dev, where a Secure cookie would be dropped. */
export async function createSession(env, userId, now, secure = true) {
  const id = randomToken();
  await env.DB.prepare(
    "INSERT INTO sessions (id, user_id, created_at, expires_at) VALUES (?,?,?,?)"
  ).bind(id, userId, now, now + SESSION_MS).run();
  return cookieHeader(SESSION_COOKIE, id, { maxAge: SESSION_MS / 1000, secure });
}

/** Resolves the signed-in user from the session cookie, or null. */
export async function getUser(env, request, now) {
  const sid = parseCookies(request)[SESSION_COOKIE];
  if (!sid) return null;
  const row = await env.DB.prepare(
    `SELECT u.id, u.name, u.avatar_url, u.provider, s.expires_at
       FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.id = ?`
  ).bind(sid).first();
  if (!row) return null;
  if (now != null && row.expires_at < now) {
    await env.DB.prepare("DELETE FROM sessions WHERE id = ?").bind(sid).run();
    return null;
  }
  return { id: row.id, name: row.name, avatar_url: row.avatar_url, provider: row.provider };
}

export async function destroySession(env, request) {
  const sid = parseCookies(request)[SESSION_COOKIE];
  if (sid) await env.DB.prepare("DELETE FROM sessions WHERE id = ?").bind(sid).run();
  return cookieHeader(SESSION_COOKIE, "", { maxAge: 0, secure: !isLocalRequest(request) });
}

/** Inserts or updates an OAuth user, returns its id. */
export async function upsertUser(env, provider, providerId, name, avatarUrl, now) {
  await env.DB.prepare(
    `INSERT INTO users (provider, provider_id, name, avatar_url, created_at)
       VALUES (?,?,?,?,?)
     ON CONFLICT(provider, provider_id) DO UPDATE SET name=excluded.name, avatar_url=excluded.avatar_url`
  ).bind(provider, providerId, name, avatarUrl, now).run();
  const row = await env.DB.prepare(
    "SELECT id FROM users WHERE provider = ? AND provider_id = ?"
  ).bind(provider, providerId).first();
  return row.id;
}
