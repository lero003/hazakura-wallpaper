# Contributing

Hazakura Wallpaper is a native Swift/AppKit macOS menu-bar app.

## Development Setup

Requirements:

- macOS 14 or later
- Xcode 26 or current Apple Swift toolchain
- Node/npm is optional; npm scripts are convenience aliases for checked-in shell scripts and do not require dependency installation.

Build:

```sh
./scripts/build_app.sh
```

Run Swift tests:

```sh
swift test --disable-sandbox
```

Use `--disable-sandbox` only when the local automation shell cannot start SwiftPM's sandbox.

Renderer tuning loop:

```sh
npm run renderer:tune
```

Use this while adjusting glow, particle compositing, previews, or renderer memory behavior. Add `-- --full` before handoff when the app bundle build should be included in the same pass.

## Validation Before A Pull Request

Run the focused checks for your change, then run the release candidate gate when touching build, release, rendering, settings, packaging, or docs:

```sh
bash -n scripts/*.sh script/build_and_run.sh
./scripts/check_script_executable_bits.sh
./scripts/check_text_normalization.sh
./scripts/check_legacy_tauri_boundary.sh
./scripts/check_public_repository_docs.sh
./scripts/check_public_source_hygiene.sh
./scripts/check_public_git_history_hygiene.sh
./scripts/check_public_artifact_hygiene.sh
./scripts/check_privacy_security_boundaries.sh
npm run release:candidate
./scripts/check_publish_readiness.sh
```

If you only change docs, at minimum run:

```sh
./scripts/check_public_repository_docs.sh
git diff --check
```

## Release Boundaries

The default public distribution path is unsigned/ad-hoc GitHub ZIP or DMG. Do not claim frictionless installation unless Developer ID signing and notarization have been completed and verified.

Before handing an unsigned DMG/ZIP to users, run the normal-session share path:

```sh
npm run share:unsigned -- --operator "Operator Name" --reviewer "Reviewer Name" --accepted --checklist-complete
```

This records DMG, LaunchServices bundle-open, `leaks --atExit`, and human visual QA evidence before `check_share_readiness.sh` can pass.
It does not rebuild the app or ZIP, so run `npm run release:candidate` before the visual pass and inspect the current `dist/Hazakura Wallpaper.app`.
Use `npm run share:preflight:strict` to check local hdiutil and normal-session prerequisites before starting the full share path.

## Security And Secrets

- Do not commit signing certificates, private keys, keychain profiles, `.env` files, `.npmrc`, local paths, or generated release artifacts.
- Do not pass Apple ID or notary passwords through committed scripts or release notes.
- Use `NOTARYTOOL_PROFILE` with a stored keychain profile for notarization.
- Keep local agent metadata such as `.codex/` out of the public repository.

## Scope

Keep changes small and release-gate-backed. Avoid broad refactors unless they directly improve the Swift app, release safety, memory/lifecycle behavior, or public distribution readiness.
