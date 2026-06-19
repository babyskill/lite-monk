import { json } from "../../_lib.js";

// DELETE /api/admin/<slug>  (Authorization: Bearer <ADMIN_KEY>)
// Removes a pet's row and its R2 files. Used to take down reported/abusive pets.
export async function onRequestDelete({ env, request, params }) {
  const auth = request.headers.get("authorization") || "";
  if (!env.ADMIN_KEY || auth !== `Bearer ${env.ADMIN_KEY}`)
    return json({ error: "Unauthorized." }, 401);

  const slug = params.slug;
  const row = await env.DB.prepare("SELECT sheet_key, json_key FROM pets WHERE slug = ?")
    .bind(slug).first();
  if (!row) return json({ error: "Not found." }, 404);

  await env.PETS.delete(row.sheet_key);
  await env.PETS.delete(row.json_key);
  await env.DB.prepare("DELETE FROM pets WHERE slug = ?").bind(slug).run();
  return json({ ok: true, deleted: slug });
}
