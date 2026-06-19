import { getUser, json } from "../_lib.js";

// GET /api/me -> the signed-in user, or { user: null }.
export async function onRequestGet({ env, request }) {
  const user = await getUser(env, request, Date.now());
  return json({ user });
}
