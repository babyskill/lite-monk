import { PROVIDERS, redirectUri, exchangeCode } from "../../../_auth.js";
import { parseCookies, cookieHeader, createSession, upsertUser, isLocalRequest, json } from "../../../_lib.js";

// GET /api/auth/<provider>/callback -> finish OAuth, create a session, go home.
export async function onRequestGet({ env, params, request }) {
  const p = PROVIDERS[params.provider];
  if (!p) return json({ error: "Unknown provider." }, 404);

  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const saved = parseCookies(request)["oauth_state"];
  if (!code || !state || state !== saved)
    return json({ error: "Login failed (bad state). Please try again." }, 400);

  const token = await exchangeCode(p, env, code, redirectUri(url.origin, params.provider));
  if (!token) return json({ error: "Login failed (token exchange)." }, 400);

  const prof = await p.profile(token);
  if (!prof || !prof.id) return json({ error: "Login failed (profile)." }, 400);

  const now = Date.now();
  const secure = !isLocalRequest(request);
  const userId = await upsertUser(env, params.provider, prof.id, prof.name, prof.avatar, now);

  const headers = new Headers({ location: "/pet/" });
  headers.append("set-cookie", await createSession(env, userId, now, secure));
  headers.append("set-cookie", cookieHeader("oauth_state", "", { maxAge: 0, secure }));
  return new Response(null, { status: 302, headers });
}
