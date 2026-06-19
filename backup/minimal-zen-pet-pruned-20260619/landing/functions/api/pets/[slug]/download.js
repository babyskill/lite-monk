import { json, clientIp } from "../../../_lib.js";

// POST /api/pets/<slug>/download — bump the download counter (feeds the
// leaderboard). Throttled to once per IP per pet per 10 minutes.
export async function onRequestPost({ env, request, params }) {
  const slug = params.slug;
  const exists = await env.DB.prepare("SELECT 1 FROM pets WHERE slug = ?").bind(slug).first();
  if (!exists) return json({ error: "Not found." }, 404);

  const ip = clientIp(request);
  const now = Date.now();
  const recent = await env.DB.prepare(
    "SELECT 1 FROM downloads_log WHERE ip = ? AND pet_slug = ? AND created_at > ?"
  ).bind(ip, slug, now - 600_000).first();
  if (recent) return json({ ok: true, counted: false });

  await env.DB.prepare(
    "INSERT INTO downloads_log (ip, pet_slug, created_at) VALUES (?,?,?)"
  ).bind(ip, slug, now).run();
  await env.DB.prepare("UPDATE pets SET downloads = downloads + 1 WHERE slug = ?").bind(slug).run();
  return json({ ok: true, counted: true });
}
