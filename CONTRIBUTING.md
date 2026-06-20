# Contributing to LiteMonk

Thanks for improving LiteMonk. The current app is a Minimal Zen Character for macOS:
floating character, character packs, Dhammapada quotes, click reactions, and a
mindfulness bell.

## Getting Started

```bash
swift build
swift test
awkit build -- -destination 'platform=macOS,arch=arm64'
open build/LiteMonk.app
```

Requires macOS 13+ and a recent Swift toolchain.

## Project Layout

- `Sources/LiteMonkCore/` — small shared primitives.
- `Sources/App/` — macOS app, character window, settings, Dhammapada, bell, character packs.
- `Tests/LiteMonkAppTests/` — app-level logic tests.
- `scripts/` — packaging, release, icon/banner helpers.

## Guidelines

- Keep the app focused on character, Dhammapada, and mindfulness bell behavior.
- Avoid reintroducing background monitor, progression, account sync, or wrapper features.
- Match surrounding SwiftUI style and keep changes scoped.
- Add or update focused tests for behavior changes.
- Run `swift test` before handing off.

## Character Packs

Character packs use `pet.json` plus a spritesheet image. They are added at runtime via
Browse or Create, and stored under `~/.litemonk/pets/`.

## Issues

Include macOS version, app version or commit, steps to reproduce, expected
behavior, and actual behavior.
