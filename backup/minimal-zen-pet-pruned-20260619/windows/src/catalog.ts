// Pulls the public pet catalog (same CDN the macOS app + web use). Open, no auth.

const MANIFEST = "https://pets.thenightwatcher.online/manifest.json";

export interface Pet {
  slug: string;
  name: string;
  spritesheetUrl: string;
  petJsonUrl?: string;
  kind: string;
}

export async function loadCatalog(): Promise<Pet[]> {
  try {
    const r = await fetch(MANIFEST);
    const j: any = await r.json();
    return (j.pets ?? []).map((p: any) => ({
      slug: p.slug,
      name: p.displayName ?? p.slug,
      spritesheetUrl: p.spritesheetUrl,
      petJsonUrl: p.petJsonUrl,
      kind: p.kind ?? "creature",
    }));
  } catch {
    return [];
  }
}

const KEY = "agentpet.petSlug";

export function savedSlug(): string | null {
  try { return localStorage.getItem(KEY); } catch { return null; }
}
export function saveSlug(slug: string) {
  try { localStorage.setItem(KEY, slug); } catch {}
}

// ---- Installed-pet library (the macOS ImagePetStore equivalent) -------------
// Pets the user "downloaded" (Get) or created. The Pet tab pager shows ONLY
// these; the full catalog lives in the Browse dialog.

export interface LibPet {
  slug: string;
  name: string;
  url: string;          // spritesheet URL (CDN) or data URL (created pets)
  petJsonUrl?: string;
  custom?: boolean;
}

const LIB_KEY = "ap_library";

export function getLibrary(): LibPet[] {
  try {
    const v = JSON.parse(localStorage.getItem(LIB_KEY) || "[]");
    return Array.isArray(v) ? v : [];
  } catch { return []; }
}

export function saveLibrary(lib: LibPet[]) {
  try { localStorage.setItem(LIB_KEY, JSON.stringify(lib)); } catch {}
}

export function addToLibrary(p: LibPet) {
  const lib = getLibrary().filter((x) => x.slug !== p.slug);
  lib.unshift(p);
  saveLibrary(lib);
}

export function removeFromLibrary(slug: string) {
  saveLibrary(getLibrary().filter((x) => x.slug !== slug));
}
