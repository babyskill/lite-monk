import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { Pet } from "./pet";
import { SessionStore } from "./state";
import { loadCatalog, savedSlug, saveSlug } from "./catalog";
import { t, setLang, type Lang } from "./i18n";
import { sendNotification, isPermissionGranted, requestPermission } from "@tauri-apps/plugin-notification";

const canvas = document.getElementById("pet") as HTMLCanvasElement;
const bubble = document.getElementById("bubble") as HTMLDivElement;
const pet = new Pet(canvas);
const store = new SessionStore();

const IDLE_LINES = [
  "Let's grill some bugs.",
  "Tiny commit, tiny dopamine.",
  "The build is quiet. Too quiet.",
  "Ship something small.",
];
const STATE_LABEL: Record<string, string> = {
  working: "Working", waiting: "Needs you", done: "Done", registered: "Ready", idle: "Idle",
};

// --- bubble customization (theme / opacity / custom messages) ----------------
function applyBubble() {
  const theme = localStorage.getItem("ap_theme") || "dark";
  const op = (parseInt(localStorage.getItem("ap_opacity") || "92", 10) || 92) / 100;
  const r = document.documentElement.style;
  if (theme === "light") {
    r.setProperty("--bubble-bg", `rgba(255,255,255,${op})`);
    r.setProperty("--bubble-fg", "#1a1d2e");
    r.setProperty("--bubble-border", "rgba(0,0,0,0.08)");
  } else {
    r.setProperty("--bubble-bg", `rgba(22,24,38,${op})`);
    r.setProperty("--bubble-fg", "#ffffff");
    r.setProperty("--bubble-border", "rgba(255,255,255,0.10)");
  }
}
applyBubble();

// A stable custom line for a state (seeded by session id), or null for default.
function customLine(state: string, seed: string): string | null {
  const raw = localStorage.getItem("ap_msg_" + state);
  if (!raw) return null;
  const lines = raw.split("\n").map((s) => s.trim()).filter(Boolean);
  if (!lines.length) return null;
  let h = 5381;
  for (const c of seed) h = (Math.imul(h, 33) + c.charCodeAt(0)) | 0;
  return lines[Math.abs(h) % lines.length];
}

// --- pick + load a pet sprite -------------------------------------------------
(async () => {
  const pets = await loadCatalog();
  if (!pets.length) return;
  const slug = savedSlug();
  const chosen = pets.find((p) => p.slug === slug) ?? pets[Math.floor(pets.length / 2)];
  saveSlug(chosen.slug);
  pet.load(chosen.spritesheetUrl);
})();

// --- render loop for state + bubble ------------------------------------------
function render() {
  const top = store.active()[0];
  const state = top?.state ?? "idle";
  pet.setState(state);

  if (top && state !== "idle") {
    const label = t(STATE_LABEL[state] ?? "");
    const msg = customLine(state, top.session) || top.message || label;
    const proj = top.project ? top.project.split(/[\\/]/).pop() : "";
    bubble.innerHTML =
      `<span class="agent">${esc(top.agent)}</span>${proj ? " · " + esc(proj) : ""} ` +
      `${esc(msg)}<span class="state">${esc(label)}</span>`;
    bubble.hidden = false;
  } else {
    bubble.hidden = true;
  }
}
setInterval(render, 500);

function esc(s: string): string {
  return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c] || c));
}

// --- notifications ------------------------------------------------------------
let notifyReady = false;
(async () => {
  try { notifyReady = (await isPermissionGranted()) || (await requestPermission()) === "granted"; } catch {}
})();
const lastState = new Map<string, string>();
function maybeNotify(e: { agent: string; session: string; state: string; project: string }) {
  const key = `${e.agent}:${e.session}`;
  const prev = lastState.get(key);
  lastState.set(key, e.state);
  if (e.state === prev) return;
  if (e.state !== "done" && e.state !== "waiting") return;
  if (!notifyReady || localStorage.getItem("ap_notify") === "0") return;
  const proj = (e.project ? e.project.split(/[\\/]/).pop() : "") || e.agent;
  const label = t(e.state === "done" ? "Done" : "Needs you");
  try { sendNotification({ title: `AgentPet , ${label}`, body: `${e.agent} · ${proj}` }); } catch {}
}

// --- agent events from the Rust listener -------------------------------------
listen<any>("agent-event", (e) => { maybeNotify(e.payload); store.update(e.payload); render(); });
listen<string>("agent-end", (e) => {
  for (const k of [...lastState.keys()]) if (k.endsWith(`:${e.payload}`)) lastState.delete(k);
  store.remove(e.payload);
  render();
});
// Pet changed from the Settings window.
listen<{ slug: string; url: string }>("set-pet", (e) => {
  pet.load(e.payload.url);
  saveSlug(e.payload.slug);
});
// Language changed from Settings , re-render the bubble in the new language.
listen<Lang>("lang-changed", (e) => { setLang(e.payload); render(); });
// Bubble theme / opacity / messages changed from Settings.
listen("bubble-changed", () => { applyBubble(); render(); });

// --- interactions ------------------------------------------------------------
// Drag the pet to reposition it. Settings/Quit live in the tray menu (the
// overlay is frameless, and starting an OS drag here would swallow clicks).
canvas.addEventListener("mousedown", async (e) => {
  if (e.button === 0) await getCurrentWindow().startDragging();
});

// Occasional idle chatter.
setInterval(() => {
  if (store.topState() === "idle") {
    bubble.textContent =
      customLine("idle", "idle") || t(IDLE_LINES[Math.floor(Date.now() / 1000) % IDLE_LINES.length]);
    bubble.hidden = false;
    setTimeout(() => { if (store.topState() === "idle") bubble.hidden = true; }, 4000);
  }
}, 30000);
