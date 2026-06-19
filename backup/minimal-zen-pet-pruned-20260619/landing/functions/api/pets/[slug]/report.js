import { json } from "../../../_lib.js";

// POST /api/pets/<slug>/report — flag a pet. Auto-hides once it passes the
// report threshold so the worst content drops off without manual action.
export async function onRequestPost({ env, params }) {
  const slug = params.slug;
  const threshold = parseInt(env.REPORT_HIDE_THRESHOLD || "3", 10);

  const row = await env.DB.prepare("SELECT reports, status FROM pets WHERE slug = ?")
    .bind(slug).first();
  if (!row) return json({ error: "Not found." }, 404);

  const reports = (row.reports || 0) + 1;
  const status = reports >= threshold ? "hidden" : row.status;
  await env.DB.prepare("UPDATE pets SET reports = ?, status = ? WHERE slug = ?")
    .bind(reports, status, slug).run();

  return json({ ok: true, hidden: status === "hidden" });
}
