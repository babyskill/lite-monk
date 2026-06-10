# AgentPet for Windows

A desktop pet that floats on your screen and reacts in real time to your AI
coding agents (Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot). Windows
port of the macOS app, built with [Tauri](https://tauri.app) so it stays small
(~10 MB) and reuses the same pet catalog + hook model.

> Status: **early scaffold.** Code-complete first pass; needs a Windows machine
> (or CI) to build and test the `.msi`/`.exe`. Frontend + Rust compile on macOS
> for development.

## How it works

```
agent hook  ──(stdin JSON)──►  agentpet.exe hook --agent <kind>
                                      │  POST /event
                                      ▼
                          localhost:47628 (Rust listener in the running app)
                                      │  emit "agent-event"
                                      ▼
                          pet overlay window (Tauri webview, canvas sprite)
```

- The same binary doubles as the hook CLI: `agentpet hook --agent claude` reads
  the agent's hook payload on stdin and POSTs it to the running app. It always
  exits 0 so it never blocks an agent (Copilot PreToolUse is fail-closed).
- Hook configs are written to Windows paths (`%USERPROFILE%\.claude\settings.json`,
  `\.codex\hooks.json`, ...) , identical formats to the macOS app.
- Pets come from the public CDN (`pets.thenightwatcher.online/manifest.json`),
  rendered from the 8x9 spritesheet (8 frames per state row).

## Develop

```bash
cd windows
npm install
npm run tauri dev      # runs on macOS too (dev); target Windows for the real build
```

## Build (on Windows)

```bash
npm install
npm run tauri build    # produces an NSIS installer + MSI in src-tauri/target/release/bundle
```

Requires Rust + the Tauri prerequisites (WebView2 is preinstalled on Windows 10/11).

## Agents

| Agent          | Config file                                  | Notes |
|----------------|----------------------------------------------|-------|
| Claude Code    | `~/.claude/settings.json`                    | works once installed |
| Codex          | `~/.codex/hooks.json` + `config.toml`        | run `/hooks` → `t` once to trust |
| Gemini CLI     | `~/.gemini/settings.json`                    | |
| Cursor         | `~/.cursor/hooks.json`                        | |
| GitHub Copilot | `~/.copilot/hooks/agentpet.json`             | Copilot CLI |

## Build via CI (no Windows machine needed)

A GitHub Actions workflow (`.github/workflows/windows-build.yml`) builds the
installers on `windows-latest`:

- Run it manually from the **Actions** tab (workflow_dispatch) , the `.msi` and
  `.exe` are uploaded as artifacts.
- Push a tag like `win-v0.1.0` to also attach the installers to a GitHub release.

## TODO

- Pet picker / browser in Settings (currently a default pet; change via the
  catalog).
- Richer live-activity bubble text + i18n parity with the macOS app.
- Click-through on transparent areas of the overlay.
