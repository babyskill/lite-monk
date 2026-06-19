import { destroySession, json } from "../../_lib.js";

// POST /api/auth/logout -> clear the session.
export async function onRequestPost({ env, request }) {
  const clear = await destroySession(env, request);
  return json({ ok: true }, 200, { "set-cookie": clear });
}
