# AgentPet — Codebase Map

> **Project Type:** Minimal Zen Character macOS app
> **Primary Stack:** Swift 6 + SwiftUI
> **Last Synced:** 2026-06-19

Read this file before searching the repo. Pick the target module first, then
search inside that scope.

## Directory Structure

```text
Sources/
├── AgentPetCore/          # Small shared primitives: paths and pet mood enum
└── App/                   # macOS app target, SwiftUI screens, character, quotes, bell

Tests/
└── AgentPetAppTests/      # App-level logic tests

Localizations/             # App strings by locale
scripts/                   # macOS build/release/icon scripts
assets/                    # README/release images
backup/                    # Removed legacy surfaces kept for manual review
```

## File Index

| Path | Purpose |
|------|---------|
| `Package.swift` | SwiftPM package manifest for the app and tests |
| `Sources/AgentPetCore/AgentPetPaths.swift` | Shared on-disk base path |
| `Sources/AgentPetCore/PetMood.swift` | Pet animation state enum |
| `Sources/App/AgentPetApp.swift` | App startup and controller bootstrapping |
| `Sources/App/PetController.swift` | Floating character state, quote rotation, click reactions |
| `Sources/App/PetView.swift` | Floating character view, quote bubble, tap interaction UI |
| `Sources/App/PetWindowController.swift` | Transparent floating character window |
| `Sources/App/StatusBarController.swift` | Menu bar item and popover lifecycle |
| `Sources/App/MenuBarContentView.swift` | Minimal menu bar controls and current quote |
| `Sources/App/SetupView.swift` | Settings: character controls, Dhammapada manager, bell controls |
| `Sources/App/DhammapadaStore.swift` | Bundled/custom Dhammapada storage and CRUD |
| `Sources/App/IdleBoost.swift` | Five-minute Dhammapada quote selection |
| `Sources/App/MindfulnessBellSettings.swift` | Mindfulness bell schedule, sound, quiet hours |
| `Sources/App/BundledSound.swift` | Bundled sound playback |
| `Sources/App/BrowsePetsView.swift` | Online character browser |
| `Sources/App/CreatePetView.swift` | Custom character import flow |
| `Sources/App/ImagePetStore.swift` | Installed character pack loading/deletion |
| `Sources/App/PetInstaller.swift` | Character pack download/import helpers |
| `Sources/App/SpriteSlicer.swift` | Spritesheet slicing for character packs |
| `Sources/App/PetBindings.swift` | Per-character mood-to-clip bindings |
| `Sources/App/Resources/Dhammapada.vi.json` | Bundled Vietnamese Dhammapada data |
| `Tests/AgentPetAppTests/IdleBoostTests.swift` | Dhammapada data and rotation tests |
| `Tests/AgentPetAppTests/PetControllerTests.swift` | Click-to-pet behavior tests |
| `Tests/AgentPetAppTests/SpriteSlicerTests.swift` | Pet pack slicing tests |

## Primary Flows

- Startup: `AgentPetApp` loads character packs, starts `PetController`, `MindfulnessBellSettings`, `PetWindowController`, status bar, and onboarding.
- Floating character: `PetWindowController` hosts `FloatingPetView`; tapping the character calls `PetController.petTap()`.
- Quote rotation: `PetController` schedules a five-minute timer and pulls text from `IdleBoost`.
- Dhammapada management: `SetupView` opens `DhammapadaVerseEditor`, then `DhammapadaStore.upsert` or `remove` persists custom data.
- Mindfulness bell: `MindfulnessBellSettings` schedules ticks, optionally syncs the quote, and plays bundled or custom audio.
- Character packs: Browse/import writes packs into `~/.agentpet/pets/`; `ImagePetStore` loads them on startup and settings refresh.

## Build And Test

```bash
swift test
awkit build -- -destination 'platform=macOS,arch=arm64'
```

## Notes

- Legacy surfaces removed from the active app are kept in `backup/` for manual review.
- SwiftPM is the source of truth for what builds.
- Legacy multi-surface material is no longer part of the active app.
