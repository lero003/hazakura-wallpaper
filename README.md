# Hazakura Wallpaper

Hazakura Wallpaper is a small native macOS desktop overlay app by Hazakura Lab.
It lets sakura petals, hazakura leaves, breeze particles, fireflies, magic lights, and spark effects drift over the desktop from the menu bar.
The public repository and source package name is `hazakura-wallpaper`.

## Features

- Menu bar control for pause/resume
- Effect modes: SAKURA, Magic, Spark, Hazakura, Breeze, Hotaru
- Effect intensity: quiet, normal, play
- Optional night-sakura background
- Mouse-reactive wind and particle avoidance
- Respects macOS Reduce Motion by rendering at quiet intensity and lower timer cadence without changing saved settings
- Local setting persistence
- One-time import of legacy Tauri `settings.json` values when Swift settings are not present or unreadable
- Self-repair for corrupted Swift settings by rewriting safe defaults when no legacy settings can be imported
- Multi-display transparent overlays
- Native Swift/AppKit runtime without Tauri or WebView

## Development

Requirements:

- Xcode 26 or current Apple Swift toolchain
- macOS 14 or later
- Node/npm is optional; `package.json` only provides convenience aliases for the same checked-in shell scripts and has no runtime dependency install step.

Build and test:

```sh
swift build
swift test
```

In restricted automation shells where SwiftPM cannot start `sandbox-exec`, use
`swift build --disable-sandbox` and `swift test --disable-sandbox`.

Build the distributable app bundle:

```sh
./scripts/build_app.sh
```

`npm run build` is kept as a convenience alias for the same Swift/AppKit build path.
If npm is unavailable, use the checked-in shell scripts shown in this README directly.

The built app is generated at:

```text
dist/Hazakura Wallpaper.app
```

The build script prefers `SakuraSky.xcodeproj` so the distributable bundle is produced by Xcode. Set `HAZAKURA_WALLPAPER_USE_SWIFTPM_BUNDLE=1` only when diagnosing the fallback manual SwiftPM bundle path.
To build from Xcode directly, open `SakuraSky.xcodeproj` and select the shared `Hazakura Wallpaper` scheme.
The Xcode Release configuration is pinned to standard architectures with `ONLY_ACTIVE_ARCH=NO`, and the build script also passes `arm64 x86_64` so public artifacts stay Universal.
Swift-owned app icon assets live in `Resources/icon.icns` and `Resources/icon.png`.

Run locally:

```sh
./script/build_and_run.sh
```

Verify local launch:

```sh
./script/build_and_run.sh --verify
```

`--verify` uses the built app bundle executable for smoke mode so it can still prove the distributable executable starts in restricted automation environments where LaunchServices refuses to open freshly built local bundles.
Set `HAZAKURA_WALLPAPER_REQUIRE_BUNDLE_OPEN=1` to make LaunchServices bundle launch a required check in a normal user session.
Set `HAZAKURA_WALLPAPER_EXECUTABLE_SMOKE_TIMEOUT=<seconds>` to tune the direct executable smoke watchdog; the default is 5 seconds and the value must be a positive integer.
Use `./script/build_and_run.sh --telemetry` in a normal user session to build, launch, and stream Hazakura Wallpaper unified logs filtered to the app subsystem.
Use `./script/build_and_run.sh --logs` to stream broader process logs.

Generate visual preview PNGs:

```sh
./scripts/render_previews.sh
```

This includes single-mode previews plus `qa-matrix-day.png` and `qa-matrix-night.png` for mode/intensity review.
Preview rendering uses a fixed seed so release QA images are reproducible unless renderer or preview logic intentionally changes.
The release gate validates these PNGs, their expected dimensions, and their deterministic checksums before packaging.

Run the renderer tuning loop while adjusting glow or particle rendering:

```sh
npm run renderer:tune
```

The same loop is available as `./scripts/check_renderer_tuning_loop.sh`.
It runs Swift tests, preview rendering, preview artifact checks, preview determinism, renderer memory smoke, and `git diff --check`.
Pass `--full` when the change also needs to prove `dist/Hazakura Wallpaper.app` still builds.
The memory smoke portion accepts `HAZAKURA_WALLPAPER_MEMORY_SMOKE_FRAMES`, `HAZAKURA_WALLPAPER_MEMORY_SMOKE_WIDTH`, `HAZAKURA_WALLPAPER_MEMORY_SMOKE_HEIGHT`, and `HAZAKURA_WALLPAPER_MEMORY_SMOKE_MAX_RSS_BYTES` for heavier local performance passes.

Run the release verification gate:

```sh
./scripts/verify_release.sh
```

The same gate is available as `npm run verify`.

The release gate checks npm workflow aliases, script executable bits, text line-ending normalization, legacy Tauri source boundaries, Swift source safety patterns, AppKit lifecycle safety patterns for timers and observers, Swift-owned asset boundaries, release metadata consistency, app-target Xcode distributable Swift source membership without duplicate basenames or extra app-target Swift sources, tests, renderer memory smoke, bundle plist identity and base metadata, executable presence, app and status icon resources, Universal `arm64` / `x86_64` Mach-O architecture evidence, Mach-O minimum macOS metadata, codesign validity, hardened runtime, absence of entitlements, executable smoke launch, preview PNG dimensions, preview visible-content evidence, preview visual diversity, and preview determinism.

Check distribution readiness for the current app bundle:

```sh
./scripts/check_distribution_readiness.sh
```

Set `HAZAKURA_WALLPAPER_REQUIRE_DEVELOPER_ID=1` to fail this check unless the app is signed with a Developer ID Application identity.
This check also verifies that the bundle `LSMinimumSystemVersion` matches the Mach-O deployment target.

Prepare a local release candidate and verify the generated ZIP:

```sh
./scripts/prepare_release_candidate.sh
```

The same candidate gate is available as `npm run release:candidate`.

This also checks that `dist/SHA256SUMS`, `dist/release-evidence/RELEASE_MANIFEST.md`, preview evidence, preview determinism evidence, renderer memory smoke evidence, icon evidence, signing evidence, Mach-O evidence, Gatekeeper assessment evidence, entitlement evidence, and ZIP content evidence agree with the generated artifacts. Release evidence validation re-extracts the current ZIP and confirms its app still matches the current `dist/Hazakura Wallpaper.app`.
It also runs a privacy/security boundary check so the runtime app does not silently grow network clients, web views, Keychain/authentication APIs, external process spawning, pasteboard reads, screen/window capture APIs, broad user-directory scans, or insecure HTTP URLs.
ZIP content evidence extracts the archive, verifies the extracted app, confirms it matches the current `dist/Hazakura Wallpaper.app`, rejects entries outside `Hazakura Wallpaper.app`, permits only the expected minimal bundle entries, and prevents source, scripts, docs, dependency folders, Xcode project files, legacy Tauri files, development metadata, editor state, local environment files, debug symbols, or build outputs from being packaged into the public archive.
The candidate gate also writes `dist/release-evidence/GITHUB_RELEASE_DRAFT.md` with the current ZIP SHA-256, install notes, Gatekeeper wording, verification commands, and privacy/security links for use as GitHub Release text.
It also runs release-evidence guard tests that temporarily inject final-only evidence and confirm the candidate is rejected until final notarized ZIP verification is complete.
Signing evidence is canonical only under `dist/release-evidence/`; stale top-level `dist/codesign-*` files are removed during packaging and rejected by the evidence gate.
Those guard tests are pre-final checks and refuse to run after final notarization evidence is present.

## Continuous Integration

GitHub Actions runs `.github/workflows/ci.yml` on pushes to `main`, pull requests, and manual dispatch. The CI job checks shell syntax, script executable bits, text line-ending normalization, legacy Tauri source boundaries, public repository docs, public source hygiene, public Git history hygiene, public artifact hygiene, privacy/security boundaries, `npm run release:candidate`, unsigned publish readiness, unsigned DMG packaging, strict unsigned share preflight, and that the stricter share gate still waits for normal-session evidence. It uploads the generated ZIP, generated DMG, checksums, previews, and selected public-safe release evidence as a workflow artifact for inspection, with release-candidate artifact retention limited to 14 days. Local-path-bearing evidence such as signing, Gatekeeper, Mach-O, and icon tool output stays local and is intentionally excluded from uploaded CI artifacts.

## Distribution Note

The default public path is an ad-hoc-signed local artifact for GitHub distribution.
Users on other Macs may need to bypass Gatekeeper with right-click Open or System Settings > Privacy & Security > Open Anyway.
Developer ID signing and notarization are optional and only needed for a more frictionless public download.

See `docs/INSTALL.md` for DMG, ZIP, source build, Gatekeeper bypass, and uninstall instructions.
See `CHANGELOG.md` for user-visible changes and remaining pre-share evidence items.
See `CONTRIBUTING.md` for development, validation, release boundary, and secret-handling guidance.

Before uploading the default unsigned build, run:

```sh
./scripts/check_publish_readiness.sh
```

This gate requires the current `dist/Hazakura Wallpaper.zip`, manifest, checksums, app metadata, Universal Mach-O evidence, codesign validity, entitlements absence, preview evidence, preview determinism, ZIP content checks, and release-evidence guard tests to agree. It does not require Developer ID signing or notarization unless strict mode is requested.
It also requires the generated GitHub release draft to match the current artifact SHA and public install/security/privacy docs.
It also runs `./scripts/check_public_source_hygiene.sh` so publishable source files are rejected if they include local paths, generated artifacts, release archives, debug-symbol archives, backup files, credential-like filenames, private-key/certificate markers, token-like markers, or explicit notarytool credential arguments.
It also runs `./scripts/check_public_git_history_hygiene.sh` so the Git history intended for GitHub publication is rejected if past file paths, tracked file contents, or commit messages include local paths, credential-like filenames, private-key/certificate markers, token-like markers, or explicit notarytool credential arguments.
It also runs `./scripts/check_public_artifact_hygiene.sh` so CI/GitHub-uploadable release evidence is limited to selected public-safe files and rejected if local paths, local usernames, key/certificate/token-like markers, or explicit notarytool credential arguments appear.
It also runs `./scripts/check_privacy_security_boundaries.sh` to keep the app's runtime privacy/security surface aligned with `PRIVACY.md` and `SECURITY.md`.

In a normal macOS user session, record the unsigned bundle-open check and human visual acceptance before sharing the artifact:

```sh
npm run share:preflight:strict
HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh
./scripts/record_unsigned_bundle_open_verification.sh --operator "Operator Name"
./scripts/record_unsigned_memory_check.sh --operator "Operator Name"
./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"
./scripts/check_publish_readiness.sh
./scripts/check_share_readiness.sh
```

These unsigned evidence files are optional for the automated gate, but when present they are tied to the current bundle ID, version, build, architectures, CDHash, ZIP SHA-256, and release checklist checksum where applicable. Recreating the ZIP removes them because the human and memory checks belong to a specific artifact.
The DMG step is required by the stricter share gate. Use `HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1` after `npm run release:candidate` so the DMG is created from the already verified app/ZIP pair instead of changing the release candidate.
DMG packaging verifies the disk image, mounts it read-only, validates the mounted app, and records mounted app identity/CDHash evidence before `check_share_readiness.sh` can pass.

After the human visual pass is complete, the one-shot normal-session path is:

```sh
npm run share:unsigned -- --operator "Operator Name" --reviewer "Reviewer Name" --accepted --checklist-complete
```

Run `npm run release:candidate` before the visual pass. `npm run share:unsigned` does not rebuild the app or ZIP; it validates the existing candidate, creates the DMG from that candidate, records LaunchServices bundle-open evidence, records `leaks --atExit` memory evidence, records human visual QA acceptance, and then runs the stricter share gate. It refuses to run without explicit operator, reviewer, accepted, and checklist-complete arguments.
The one-shot path runs the strict normal-session preflight first; use `npm run share:preflight:strict` to check temporary DMG create/verify/mount/detach support before starting the full share flow.

Before handing a DMG/ZIP to users, run the stricter share gate:

```sh
./scripts/check_share_readiness.sh
```

This gate requires publish readiness plus a current DMG, DMG evidence, normal-session bundle-open evidence, normal-session `leaks --atExit` evidence, and human visual QA evidence. It is expected to fail in restricted automation shells until those normal-session checks are recorded.

For strict Developer ID / notarized distribution, run:

```sh
HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION=1 ./scripts/check_publish_readiness.sh
```

For a Developer ID build, provide a signing identity:

```sh
SIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" ./scripts/build_app.sh
```

The notarization path rejects ad-hoc, Apple Development, and other non-`Developer ID Application:` signing identities before build work starts.

Create a notarized public ZIP when a Developer ID identity and a stored notarytool keychain profile are available:

```sh
SIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" \
NOTARYTOOL_PROFILE="profile-name" \
./scripts/notarize_release_zip.sh
```

The notarization script verifies preview determinism and ZIP contents, submits the already-checked Developer ID app ZIP with `NOTARYTOOL_PROFILE`, records one submitted archive SHA-256, UTC submission time, sanitized submission command, submitted bundle ID, version, build, architectures, and app CDHash, and requires each of those submitted fields to be unique and match the current app before final evidence can pass. It then requires exactly one strict `status: Accepted` line from `notarytool`, exactly one stapler success line, and exactly one `path: accepted` Gatekeeper line, recreates the final ZIP as a staged archive, and re-extracts that staged final archive for `codesign`, `stapler`, `spctl`, bundle identity, architecture, and CDHash checks before promoting it to `dist/Hazakura Wallpaper.zip`. Final ZIP verification evidence must contain exactly one success marker, one codesign `valid on disk` line, one designated-requirement line, one stapler success line, and one Gatekeeper acceptance line. Canonical final evidence is written to `dist/release-evidence/` only after the full notarization and final ZIP verification path succeeds; if the final ZIP path starts but does not complete, the script removes the ZIP, manifest/checksum evidence, canonical final notarization evidence, and human final evidence. Failed attempts are kept under `.failed` evidence filenames for inspection, and release evidence checks reject those files until a fresh candidate/package cleanup removes them.
Explicit Apple ID and password environment variables are not accepted by the script; use a stored keychain profile so secrets are not passed through command arguments.
The release manifest only marks `Final notarized ZIP verified: yes` when the current ZIP archive path, ZIP SHA, Developer ID signing, unique strict `status: Accepted` notary evidence, unique exact stapler success evidence, unique strict `path: accepted` Gatekeeper evidence, and extracted final ZIP app identity, CDHash, success marker, codesign validity, stapler, and Gatekeeper verification all agree.

See `docs/RELEASE_QA.md` for the full pre-publish checklist.
See `SECURITY.md` for supported distribution and reporting guidance.
See `PRIVACY.md` for local data, network, and logging behavior.

In notarization-required mode, the final gate rejects explicit Apple ID/password notarization environment variables, then requires Developer ID signing, notarization evidence with exactly one strict `status: Accepted`, exact stapler success, and strict `path: accepted` Gatekeeper result, live stapler and Gatekeeper validation, extracted final ZIP codesign/stapler/Gatekeeper evidence, matching checksums, and human visual QA acceptance with exact unique fields for the same bundle ID, version, build, architectures, CDHash, ZIP SHA-256, one UTC timestamp field, one reviewer field, checklist completion, checklist SHA-256, and recorder command.
It also requires normal-session bundle-open evidence with exact unique fields for the same verified archive path, bundle ID, version, build, architectures, CDHash, ZIP SHA-256, one UTC timestamp field, one operator field, app path, executable path, anchored process-match assertion, and recorder command; record it with `./scripts/record_bundle_open_verification.sh --operator "Operator Name"` after the final ZIP exists.
The bundle-open evidence command refuses to write until the manifest proves `Final notarized ZIP verified: yes` for the current ZIP.
It opens the existing app through LaunchServices and confirms the app's `Contents/MacOS/HazakuraWallpaper` process remains running with an anchored executable-path process match before writing evidence.
The manifest only lists final-only notarization, bundle-open, and visual QA evidence after final notarized ZIP verification is complete, and release evidence validation rejects those files if they appear earlier.
Set `HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS=<seconds>` only when the bundle-open check needs a longer positive launch settle period.
Use `./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"` after completing the human visual pass for the notarized final ZIP; the evidence records an explicit checklist-complete assertion and the current `docs/RELEASE_QA.md` checksum so the acceptance stays tied to the verified archive and checklist version that were reviewed.

Create a local DMG after verification:

```sh
./scripts/package_dmg.sh
```

The DMG script validates the current app without rewriting canonical distribution-readiness evidence, creates a compressed `UDZO` image, runs `hdiutil verify`, then records `dist/release-evidence/dmg-info.txt` and adds the DMG checksum to `dist/SHA256SUMS`. When it builds a fresh app itself, it first refreshes the ZIP from that same app so `dist/Hazakura Wallpaper.zip`, `dist/Hazakura Wallpaper.dmg`, `RELEASE_MANIFEST.md`, release evidence, and `GITHUB_RELEASE_DRAFT.md` stay aligned; using `HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1` preserves the existing app/ZIP pair and still fails if release evidence or the GitHub Release draft is inconsistent. If the final evidence or release-draft check fails, the script removes the DMG and DMG evidence instead of leaving an inconsistent release artifact behind.

After DMG creation and normal-session evidence recording, run `npm run share:check` to confirm the artifact is ready to hand to users.

If the current shell cannot create disk images, build a distributable ZIP:

```sh
./scripts/package_zip.sh
```

ZIP packaging stages the archive in `dist/`, validates its contents, then promotes it to `dist/Hazakura Wallpaper.zip` only after content checks pass. It also writes `dist/SHA256SUMS` and `dist/release-evidence/RELEASE_MANIFEST.md`; if archive validation or manifest generation fails, incomplete ZIP evidence is removed instead of leaving a broken release candidate behind.
Recreating the ZIP invalidates final-only notarization, bundle-open, visual QA, and DMG evidence for the previous artifact.

The previous Tauri implementation has been archived under `docs/legacy-tauri/` as migration reference.

## Brand

Developed by 葉桜ラボ / Hazakura Lab.
「とことんAIで遊ぶ研究所です」

## License

Hazakura Wallpaper is available under the MIT License. See `LICENSE`.
