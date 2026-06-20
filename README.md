# AgentPet

Minimal Zen Character is a small macOS menu bar companion: a floating character,
Dhammapada quotes, click reactions, and an optional mindfulness bell.

## Features

- Floating desktop character with adjustable size and always-on-top mode.
- Browse, install, create, select, and delete local character packs.
- Click the character to trigger hearts, a friendly reaction, and a short bounce.
- Show Dhammapada verses on the character and in the menu bar popover.
- **Multilingual Support**: Fully localized to Vietnamese and English (with Chinese and system locale fallbacks). Automatically fallbacks to English if a translation for the selected language is missing.
- **GitHub Live Updates**: Download, extract, and update Dhammapada data directly from a ZIP file hosted on GitHub containing language JSON sheets (`vi.json`, `en.json`, etc.).
- Rotate Dhammapada verses every five minutes.
- Manage Dhammapada data in Settings: add, edit, delete, search, and persist custom verses.
- Optional mindfulness bell with interval, volume, repeat count, sound choice, custom audio, quiet hours, and quote sync.
- Sparkle updater support.

## Build

To assemble the macOS application bundle:

```bash
awkit build -- -destination 'platform=macOS,arch=arm64'
```

Or build and package into a DMG:

```bash
./scripts/ci-dmg.sh
```

The built app is written to:

```text
build/AgentPet.app
build/AgentPet-*.dmg
```

## Test

```bash
swift test
```

## Data

- Bundled verses live in `Sources/App/Resources/Dhammapada.json`.
- Custom verses are stored under `~/.agentpet/dhammapada-custom.json`.
- Character packs are stored under `~/.agentpet/pets/`.
- Mindfulness bell custom sounds are stored under `~/.agentpet/sounds/`.

## Character Pack Format

Each character pack is a folder with:

- `pet.json`
- a spritesheet image referenced by `pet.json`

The app slices transparent-gutter spritesheets into animation clips and maps
clips to character moods through local bindings.
