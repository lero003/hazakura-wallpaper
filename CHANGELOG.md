# Changelog

All notable changes to Hazakura Wallpaper are recorded here.

## Unreleased

- Reduced Magic and Hotaru glow sprite construction overhead by appending layer sprites into the existing frame buffer instead of creating per-particle temporary arrays.
- Cached Spark ray paths so repeated frames reuse immutable CoreGraphics paths without reducing Spark density or changing settings behavior.
- Added a renderer tuning loop for glow/particle changes that runs tests, deterministic previews, preview artifact checks, renderer memory smoke, optional app build, and whitespace validation from one command.
- Pending normal-session release evidence before handing a DMG/ZIP to users:
  DMG creation, LaunchServices bundle-open verification, `leaks --atExit`, and human visual QA acceptance.

## 1.0.0 - Pending

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
