// GET /api/r2/<key> — streams a pet file (spritesheet / pet.json) from R2.
export async function onRequestGet({ env, params }) {
  const key = Array.isArray(params.key) ? params.key.join("/") : params.key;
  if (!key || !key.startsWith("pets/")) return new Response("Not found", { status: 404 });

  const obj = await env.PETS.get(key);
  if (!obj) return new Response("Not found", { status: 404 });

  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  headers.set("cache-control", "public, max-age=86400");
  return new Response(obj.body, { headers });
}
