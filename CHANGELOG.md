# Changelog

All notable changes to Hazakura Wallpaper are recorded here.

## Unreleased

- Reduced Magic glow reuse churn by keeping play-intensity glow images in cache and reusing per-particle glow image specs across alpha changes.
- Fixed GitHub Actions release checks on macOS runners that do not include `rg` by default.

## 1.0.1 - 2026-05-28

- Reduced Magic/Hotaru layer-backed compositor work by avoiding a redundant hide/apply cycle on glow-backed frames.
- Reduced Hotaru glow sprite setup overhead by reusing fixed normalized glow image specs across opacity changes.
- Reduced Spark ray cache hit overhead by replacing per-frame string cache keys with structured exact-dimension keys.
- Reduced glow cache lookup overhead by computing normalized color stops and cache keys in one pass for Magic/Hotaru glow sprites.
- Reduced CoreGraphics fallback allocation overhead for Magic and Hotaru glow sprites by drawing generated sprites directly instead of creating per-particle temporary arrays.
- Reduced Magic and Hotaru glow sprite construction overhead by appending layer sprites into the existing frame buffer instead of creating per-particle temporary arrays.
- Cached Spark ray paths so repeated frames reuse immutable CoreGraphics paths without reducing Spark density or changing settings behavior.
- Added a renderer tuning loop for glow/particle changes that runs tests, deterministic previews, preview artifact checks, renderer memory smoke, optional app build, and whitespace validation from one command.

## 1.0.0 - 2026-05-26

- Initial public release for normal-session unsigned DMG/ZIP distribution.
- Completed normal-session release evidence before handing the DMG/ZIP to users:
  DMG creation, LaunchServices bundle-open verification, `leaks --atExit`, and human visual QA acceptance.

- Rebuilt the former Sakura Sky / Tauri desktop overlay as a native Swift/AppKit menu-bar app.
- Renamed the public product to Hazakura Wallpaper and package surface to `hazakura-wallpaper`.
- Added six effect modes: SAKURA, Magic, Spark, Hazakura, Breeze, and Hotaru.
- Added quiet, normal, and play intensity controls.
- Added transparent multi-display overlays with mouse-reactive wind and particle avoidance.
- Added optional night-sakura background rendering.
- Added local settings persistence, legacy Tauri settings import, and corrupted settings self-repair.
- Added Reduce Motion handling that lowers runtime animation work without changing saved settings.
- Added deterministic preview generation and QA matrix images for release review.
- Added Swift source safety, AppKit lifecycle safety, renderer memory smoke, ZIP content, signing, entitlement, Mach-O, release-evidence, public-source hygiene, public-doc, and GitHub Release draft gates.
- Added unsigned GitHub/DMG distribution workflow with documented Gatekeeper bypass and stricter normal-session share readiness.
- Added optional Developer ID / notarization workflow that uses a stored `notarytool` keychain profile.
