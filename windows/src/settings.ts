import { invoke } from "@tauri-apps/api/core";
import { emit } from "@tauri-apps/api/event";
import { enable, disable, isEnabled } from "@tauri-apps/plugin-autostart";
import { loadCatalog, savedSlug, saveSlug, type Pet } from "./catalog";

// ---------------------------------------------------------------- agents ----
interface AgentInfo {
  kind: string;
  display_name: string;
  installed: boolean;
  note: string | null;
}

const agentsRoot = document.getElementById("agents")!;

async function refreshAgents() {
  const agents = await invoke<AgentInfo[]>("list_agents");
  agentsRoot.innerHTML = "";
  for (const a of agents) {
    const row = document.createElement("div");
    row.className = "agent-row";

    const meta = document.createElement("div");
    meta.className = "meta";
    const status = a.note
      ? `<div class="note">${esc(a.note)}</div>`
      : a.installed
      ? `<div class="ok">Hook installed</div>`
      : "";
    meta.innerHTML = `<div class="name">${esc(a.display_name)}</div>${status}`;

    const btn = document.createElement("button");
    btn.textContent = a.installed ? "Remove" : "Install";
    if (a.installed) btn.classList.add("remove");
    btn.onclick = async () => {
      btn.disabled = true;
      try { await invoke("toggle_install", { kind: a.kind }); } catch (e) { alert(String(e)); }
      await refreshAgents();
    };

    row.appendChild(meta);
    row.appendChild(btn);
    agentsRoot.appendChild(row);
  }
}

// ------------------------------------------------------------------ pet ----
const current = document.getElementById("pet-current") as HTMLDivElement;
const search = document.getElementById("pet-search") as HTMLInputElement;
const random = document.getElementById("pet-random") as HTMLButtonElement;
const results = document.getElementById("pet-results") as HTMLDivElement;

let catalog: Pet[] = [];

async function pick(p: Pet) {
  saveSlug(p.slug);
  await emit("set-pet", { slug: p.slug, url: p.spritesheetUrl });
  showCurrent(p);
  results.innerHTML = "";
  search.value = "";
}

function showCurrent(p: Pet | undefined) {
  current.textContent = p ? `Showing: ${p.name}` : "Showing: (default)";
}

function renderResults(list: Pet[]) {
  results.innerHTML = "";
  for (const p of list.slice(0, 24)) {
    const item = document.createElement("button");
    item.className = "pet-item";
    item.textContent = p.name;
    item.onclick = () => pick(p);
    results.appendChild(item);
  }
}

async function initPet() {
  catalog = await loadCatalog();
  if (!catalog.length) {
    current.textContent = "Couldn't load pets , check your internet connection.";
    return;
  }
  const slug = savedSlug();
  showCurrent(catalog.find((p) => p.slug === slug));

  search.addEventListener("input", () => {
    const q = search.value.trim().toLowerCase();
    if (!q) { results.innerHTML = ""; return; }
    renderResults(catalog.filter((p) => p.name.toLowerCase().includes(q)));
  });
  random.addEventListener("click", () => {
    if (catalog.length) pick(catalog[Math.floor(Math.random() * catalog.length)]);
  });
}

function esc(s: string): string {
  return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c] || c));
}

// --------------------------------------------------------------- startup ----
async function initAutostart() {
  const box = document.getElementById("autostart") as HTMLInputElement;
  try { box.checked = await isEnabled(); } catch {}
  box.addEventListener("change", async () => {
    try { box.checked ? await enable() : await disable(); } catch (e) { alert(String(e)); }
  });
}

refreshAgents();
initPet();
initAutostart();

