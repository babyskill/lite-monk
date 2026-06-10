// Tracks live agent sessions and derives the pet's current state + bubble line.
// Mirrors the macOS app: highest-priority state wins; done sessions linger
// briefly then drop so the pet returns to idle.

export interface Session {
  agent: string;
  state: string;
  project: string;
  message: string;
  updatedAt: number;
}

const PRIORITY: Record<string, number> = { working: 4, waiting: 3, done: 2, registered: 1, idle: 0 };
const DONE_LINGER_MS = 6000;

export class SessionStore {
  private sessions = new Map<string, Session>();

  update(e: { agent: string; state: string; session: string; project: string; message: string }) {
    const key = `${e.agent}:${e.session}`;
    this.sessions.set(key, {
      agent: e.agent, state: e.state, project: e.project,
      message: e.message, updatedAt: Date.now(),
    });
  }

  remove(session: string) {
    for (const k of [...this.sessions.keys()]) {
      if (k.endsWith(`:${session}`)) this.sessions.delete(k);
    }
  }

  /// Drop stale "done" sessions; returns the active list (highest priority first).
  active(): Session[] {
    const now = Date.now();
    for (const [k, s] of [...this.sessions]) {
      if (s.state === "done" && now - s.updatedAt > DONE_LINGER_MS) this.sessions.delete(k);
    }
    return [...this.sessions.values()].sort(
      (a, b) => (PRIORITY[b.state] ?? 0) - (PRIORITY[a.state] ?? 0) || b.updatedAt - a.updatedAt
    );
  }

  topState(): string {
    return this.active()[0]?.state ?? "idle";
  }
}
