import { json } from "../_lib.js";

const SORTS = { downloads: "downloads", likes: "likes", pets: "pets" };

// GET /api/creators?sort=downloads|likes|pets — leaderboard of creators.
export async function onRequestGet({ env, request }) {
  const sort = SORTS[new URL(request.url).searchParams.get("sort")] || "downloads";
  const { results } = await env.DB.prepare(
    `SELECT u.id, u.name, u.avatar_url,
            COUNT(p.slug) AS pets,
            COALESCE(SUM(p.downloads), 0) AS downloads,
            COALESCE(SUM(p.likes), 0) AS likes
       FROM users u JOIN pets p ON p.user_id = u.id AND p.status = 'public'
      GROUP BY u.id
      ORDER BY ${sort} DESC, pets DESC
      LIMIT 100`
  ).all();
  const creators = (results || []).map((c) => ({
    id: c.id, name: c.name, avatar: c.avatar_url,
    pets: c.pets, downloads: c.downloads, likes: c.likes,
  }));
  return json({ sort, creators }, 200, { "cache-control": "public, max-age=30" });
}
