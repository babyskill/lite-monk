import { createSession, upsertUser, isLocalRequest, cookieHeader, json } from "../../_lib.js";

// GET /api/auth/dev?name=Alice -> instant login as a fake user. LOCAL DEV ONLY,
// so every auth-gated feature can be tested without real OAuth apps.
export async function onRequestGet({ env, request }) {
  if (!isLocalRequest(request)) return json({ error: "Not available." }, 404);
  const url = new URL(request.url);
  const name = (url.searchParams.get("name") || "Dev User").slice(0, 40);
  const now = Date.now();
  const avatar = `https://api.dicebear.com/9.x/thumbs/svg?seed=${encodeURIComponent(name)}`;
  const userId = await upsertUser(env, "dev", name.toLowerCase(), name, avatar, now);
  const headers = new Headers({ location: "/pet/" });
  headers.append("set-cookie", await createSession(env, userId, now, false));
  return new Response(null, { status: 302, headers });
}
