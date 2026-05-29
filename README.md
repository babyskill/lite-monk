# AgentPet

A native macOS menu bar app with a desktop pet that reacts to the state of your running AI coding agents.

Run several agents at once (Claude Code, Codex, ...) and AgentPet tells you, at a glance, which one is working, which one is done, and which one is waiting for your input. The pet on your desktop reacts to it all: it works while they work, calls you when one needs input, and celebrates when they finish.

> Status: early development. See [`docs/specs/2026-05-29-agentpet-design.md`](docs/specs/2026-05-29-agentpet-design.md) for the design.

## Why

Running multiple coding agents in parallel means constantly tabbing between terminals to check who needs you. AgentPet surfaces that state in one place: a menu bar list for the details, and a desktop pet for a fun, ambient signal you can read without breaking focus.

## How it works

- A small CLI helper (`agentpet hook ...`) is called by each agent through its hook mechanism and reports state to the app over a local socket.
- For agents without hooks configured, AgentPet falls back to passive process detection (running / not running).
- The app aggregates session state and drives both the menu bar list and the pet's mood.

## Roadmap

- **v1 (MVP):** Claude Code hooks + passive fallback, 3 built-in pets, menu bar list, toggleable floating pet, native notifications, one-tap hook install, Homebrew cask.
- **v2:** Codex/Gemini support, open pet-pack format + community "dex", per-project pets, terminal focus.

## Platform

macOS 13+ (Swift / SwiftUI). macOS only by design.

## License

MIT, see [LICENSE](LICENSE).
