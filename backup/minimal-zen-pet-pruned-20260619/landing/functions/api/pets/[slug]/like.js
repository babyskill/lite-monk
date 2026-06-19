import { json, getUser } from "../../../_lib.js";

// POST /api/pets/<slug>/like — toggle the signed-in user's like. Returns the
// new state and count.
export async function onRequestPost({ env, request, params }) {
  const slug = params.slug;
  const user = await getUser(env, request, Date.now());
  if (!user) return json({ error: "Please sign in to like." }, 401);

  const pet = await env.DB.prepare("SELECT 1 FROM pets WHERE slug = ?").bind(slug).first();
  if (!pet) return json({ error: "Not found." }, 404);

  const existing = await env.DB.prepare(
    "SELECT 1 FROM pet_likes WHERE pet_slug = ? AND user_id = ?"
  ).bind(slug, user.id).first();

  let liked;
  if (existing) {
    await env.DB.prepare("DELETE FROM pet_likes WHERE pet_slug = ? AND user_id = ?").bind(slug, user.id).run();
    await env.DB.prepare("UPDATE pets SET likes = MAX(0, likes - 1) WHERE slug = ?").bind(slug).run();
    liked = false;
  } else {
    await env.DB.prepare(
      "INSERT INTO pet_likes (pet_slug, user_id, created_at) VALUES (?,?,?)"
    ).bind(slug, user.id, Date.now()).run();
    await env.DB.prepare("UPDATE pets SET likes = likes + 1 WHERE slug = ?").bind(slug).run();
    liked = true;
  }
  const row = await env.DB.prepare("SELECT likes FROM pets WHERE slug = ?").bind(slug).first();
  return json({ ok: true, liked, likes: row?.likes ?? 0 });
}
