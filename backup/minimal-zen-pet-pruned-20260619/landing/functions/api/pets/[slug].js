import { json, fileUrl, getUser } from "../../_lib.js";

// GET /api/pets/<slug> — full detail for the pet page.
export async function onRequestGet({ env, request, params }) {
  const origin = new URL(request.url).origin;
  const p = await env.DB.prepare(
    `SELECT p.*, u.name AS creator_name, u.avatar_url AS creator_avatar
       FROM pets p LEFT JOIN users u ON u.id = p.user_id
      WHERE p.slug = ? AND p.status = 'public'`
  ).bind(params.slug).first();
  if (!p) return json({ error: "Not found." }, 404);

  const user = await getUser(env, request, Date.now());
  let liked = false;
  if (user) {
    const l = await env.DB.prepare(
      "SELECT 1 FROM pet_likes WHERE pet_slug = ? AND user_id = ?"
    ).bind(p.slug, user.id).first();
    liked = !!l;
  }

  return json({
    slug: p.slug,
    displayName: p.name,
    kind: p.kind,
    submittedBy: p.creator_name || p.author,
    creator: p.user_id ? { id: p.user_id, name: p.creator_name, avatar: p.creator_avatar } : null,
    spritesheetUrl: fileUrl(origin, `pets/${p.slug}/sheet.png`),
    petJsonUrl: fileUrl(origin, `pets/${p.slug}/pet.json`),
    width: p.width,
    height: p.height,
    downloads: p.downloads,
    likes: p.likes,
    createdAt: p.created_at,
    liked,
    isOwner: !!(user && user.id === p.user_id),
  });
}

// DELETE /api/pets/<slug> — owner (session) or admin (Bearer ADMIN_KEY).
export async function onRequestDelete({ env, request, params }) {
  const row = await env.DB.prepare(
    "SELECT sheet_key, json_key, user_id FROM pets WHERE slug = ?"
  ).bind(params.slug).first();
  if (!row) return json({ error: "Not found." }, 404);

  const auth = request.headers.get("authorization") || "";
  const isAdmin = env.ADMIN_KEY && auth === `Bearer ${env.ADMIN_KEY}`;
  const user = await getUser(env, request, Date.now());
  const isOwner = user && row.user_id && user.id === row.user_id;
  if (!isAdmin && !isOwner) return json({ error: "Not allowed." }, 403);

  await env.PETS.delete(row.sheet_key);
  await env.PETS.delete(row.json_key);
  await env.DB.prepare("DELETE FROM pets WHERE slug = ?").bind(params.slug).run();
  await env.DB.prepare("DELETE FROM pet_likes WHERE pet_slug = ?").bind(params.slug).run();
  return json({ ok: true, deleted: params.slug });
}
