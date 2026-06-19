import { PROVIDERS, redirectUri } from "../../../_auth.js";
import { randomToken, cookieHeader, isLocalRequest, json } from "../../../_lib.js";

// GET /api/auth/<provider>/login -> redirect to the provider's consent screen.
export async function onRequestGet({ env, params, request }) {
  const p = PROVIDERS[params.provider];
  if (!p) return json({ error: "Unknown provider." }, 404);
  if (!p.id(env) || !p.secret(env))
    return json({ error: `${params.provider} login is not configured.` }, 503);

  const origin = new URL(request.url).origin;
  const state = randomToken();
  const url = new URL(p.authUrl);
  url.searchParams.set("client_id", p.id(env));
  url.searchParams.set("redirect_uri", redirectUri(origin, params.provider));
  url.searchParams.set("scope", p.scope);
  url.searchParams.set("state", state);
  url.searchParams.set("response_type", "code");

  const headers = new Headers({ location: url.toString() });
  headers.append("set-cookie", cookieHeader("oauth_state", state, {
    maxAge: 600, secure: !isLocalRequest(request),
  }));
  return new Response(null, { status: 302, headers });
}
