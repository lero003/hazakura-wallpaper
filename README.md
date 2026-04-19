# Sakura Sky

Sakura Sky is a small macOS desktop overlay app by Hazakura Lab.
It lets sakura petals, hazakura leaves, magic lights, and spark effects drift over the desktop from the menu bar.

## Features

- Menu bar control for pause/resume
- Effect modes: SAKURA, Magic, Spark, Hazakura
- Effect intensity: quiet, normal, play
- Optional night-sakura background
- Mouse-reactive wind and particle avoidance
- Local setting persistence

## Development

Requirements:

- Node.js
- Rust
- Tauri prerequisites for macOS

Install dependencies:

```sh
npm install
```

Run checks:

```sh
node --check src/sakura.js
cargo fmt --manifest-path src-tauri/Cargo.toml --check
```

Build:

```sh
npm run build
```

The built app is generated at:

```text
src-tauri/target/release/bundle/macos/Sakura Sky.app
```

## Distribution Note

This app is currently distributed as an unsigned/ad-hoc-signed personal build.
On other Macs, Gatekeeper may block launch until the user explicitly allows it in macOS settings.
Full frictionless distribution requires Apple Developer ID signing and notarization.

## Brand

Developed by 葉桜ラボ / Hazakura Lab.
「とことんAIで遊ぶ研究所です」
