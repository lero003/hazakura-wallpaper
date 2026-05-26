# Hazakura Wallpaper Release QA

Use this checklist before publishing a public build.

## Local Gate

- Run `./scripts/prepare_release_candidate.sh`.
- Confirm `dist/release-evidence/RELEASE_MANIFEST.md` and `dist/SHA256SUMS` were updated.
- Confirm `dist/release-evidence/preview-artifacts.txt` says the preview PNG dimension and visible-content checks passed.
- Confirm `dist/release-evidence/preview-artifacts.txt` says preview visual diversity checks passed so the mode previews have not collapsed into identical output.
- Confirm `dist/release-evidence/preview-determinism.txt` says the preview PNG checksums are stable across two render runs.
- Confirm `dist/release-evidence/renderer-memory-smoke.txt` says renderer memory smoke passed and stayed below the recorded RSS limit.
- Confirm `dist/release-evidence/icon-info.txt` says the app icon is a valid macOS icon and the status icon PNG is 1024x1024.
- Confirm `dist/release-evidence/macho-build.txt` says the app executable includes both `arm64` and `x86_64` architectures.
- Confirm `./scripts/check_app_lifecycle_safety.sh` passes, or rely on `./scripts/prepare_release_candidate.sh` which runs it through the release verification gate.
- Confirm `dist/release-evidence/zip-contents.txt` says the extracted ZIP app matches the current `dist/Hazakura Wallpaper.app` and that the ZIP has no unexpected app bundle entries, `__MACOSX`, AppleDouble, `.DS_Store`, source, docs, script, dependency, Xcode project, legacy Tauri, development metadata, editor state, local environment, debug-symbol, or build-output entries.
- Confirm `dist/release-evidence/release-evidence-check.txt` says the manifest, checksums, ZIP, preview evidence, preview determinism evidence, and ZIP content evidence agree.
- Confirm `dist/release-evidence/GITHUB_RELEASE_DRAFT.md` includes the current ZIP SHA-256, install guidance, Gatekeeper bypass note, publish/share commands, and privacy/security links.
- Confirm `dist/release-evidence/release-evidence-check.txt` says `Final notarized ZIP verified: no` and `Final-only evidence: absent` for the unsigned GitHub/DMG path.
- Confirm `dist/release-evidence/release-evidence-check.txt` says there are no release-evidence blockers and lists unsigned-distribution notes for Gatekeeper bypass, optional notarization, normal-session bundle-open, and human visual QA.
- Run `./scripts/check_publish_readiness.sh` and confirm it passes for unsigned GitHub/DMG distribution.
- Confirm `./scripts/check_github_release_notes.sh` passes, or rely on `./scripts/check_publish_readiness.sh` which runs it before accepting the candidate.
- Confirm `./scripts/check_public_source_hygiene.sh` passes, or rely on `./scripts/check_publish_readiness.sh` which runs it before accepting the candidate.
- Confirm `./scripts/check_public_git_history_hygiene.sh` passes, or rely on `./scripts/check_publish_readiness.sh` which runs it before accepting the candidate.
- Confirm `./scripts/prepare_release_candidate.sh` ran the pre-final release-evidence guard tests; they prove premature final-only evidence is rejected before notarization evidence exists.
- On GitHub, confirm the CI workflow passes for the commit being published and inspect the uploaded release-candidate artifact, including the generated ZIP, generated DMG, checksums, and public-safe release evidence, if reviewing remotely.
- Confirm preview checksums in `dist/SHA256SUMS` changed only when renderer or preview logic intentionally changed.
- Inspect `dist/previews/qa-matrix-day.png` and `dist/previews/qa-matrix-night.png` before opening the app.
- If normal-session launch or menu behavior needs diagnosis, run `./script/build_and_run.sh --telemetry` and confirm Lifecycle, Settings, Overlay, and MenuBar events are visible.

## Visual Pass

Open `dist/Hazakura Wallpaper.app` and inspect:

- SAKURA, Magic, Spark, Hazakura, Breeze, and Hotaru modes.
- quiet, normal, and play intensity in each mode.
- Pause and resume.
- Night-sakura background on and off.
- Reset behavior.
- Multiple displays, if available.
- Mouse-reactive wind and particle avoidance.
- macOS Reduce Motion enabled: effects render at quiet intensity without changing the saved menu intensity.
- Menu bar controls: About, site link, and Quit.

Record any visual issue before sharing the ZIP or creating the DMG.

## Unsigned GitHub / DMG Distribution

This is the default release path for this project.

- Upload `dist/Hazakura Wallpaper.zip` for GitHub Release source/ZIP availability.
- Create `dist/Hazakura Wallpaper.dmg` with `HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh` in a normal macOS session before running the strict share gate.
- The DMG packaging script verifies the disk image, mounts it read-only, validates the mounted app, and records mounted app identity/CDHash evidence before the DMG is considered current.
- Tell users on other Macs that macOS Gatekeeper may require right-click Open or System Settings > Privacy & Security > Open Anyway.
- Keep `HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION` unset or `0` for this path.
- In a normal macOS session, record artifact-specific unsigned checks before sharing:

```sh
npm run share:preflight:strict
HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh
./scripts/record_unsigned_bundle_open_verification.sh --operator "Operator Name"
./scripts/record_unsigned_memory_check.sh --operator "Operator Name"
./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"
./scripts/check_publish_readiness.sh
./scripts/check_share_readiness.sh
```

The unsigned bundle-open command opens the existing app through LaunchServices and confirms the `Contents/MacOS/HazakuraWallpaper` process remains running. The unsigned memory command runs `leaks --atExit` against the distributable bundle executable in smoke mode and writes evidence only when the tool exits successfully and reports no leaked-byte diagnostics. The unsigned visual QA command records an explicit checklist-complete assertion. These evidence files are bound to the current bundle ID, version, build, architectures, CDHash, ZIP SHA-256, and checklist checksum where applicable, and are removed when the ZIP is recreated.
The DMG command is part of the individual manual path because `check_share_readiness.sh` is stricter than `check_publish_readiness.sh`: it requires a current DMG, matching DMG evidence, and those normal-session evidence files before the artifact is considered ready to hand to users. Use `HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1` after the release candidate exists so the DMG is created from the same already verified app/ZIP pair.

After the visual checklist is complete, the same unsigned path can be run as one command:

```sh
npm run share:unsigned -- --operator "Operator Name" --reviewer "Reviewer Name" --accepted --checklist-complete
```

Run `npm run release:candidate` before the visual pass. This command does not rebuild the app or ZIP after visual acceptance; it validates the existing candidate, creates the DMG from that candidate, records LaunchServices bundle-open evidence, records `leaks --atExit` memory evidence, records human visual QA acceptance, then runs the strict share gate. It intentionally refuses to run without explicit operator, reviewer, accepted, and checklist-complete arguments.
The one-shot command runs `./scripts/check_unsigned_share_prerequisites.sh --strict-normal-session` first. To diagnose the session before finalizing, run `npm run share:preflight:strict`; it creates, verifies, mounts, and detaches a tiny temporary DMG before touching the real artifact.

## Optional Public Signing

Use a Developer ID Application identity:

```sh
SIGN_IDENTITY="Developer ID Application: Team Name (TEAMID)" ./scripts/build_app.sh
HAZAKURA_WALLPAPER_REQUIRE_DEVELOPER_ID=1 ./scripts/check_distribution_readiness.sh
```

`./scripts/notarize_release_zip.sh` rejects ad-hoc, Apple Development, and other non-`Developer ID Application:` identities before build work starts.

Then notarize and package with a stored notarytool keychain profile:

```sh
SIGN_IDENTITY="Developer ID Application: Team Name (TEAMID)" \
NOTARYTOOL_PROFILE="profile-name" \
./scripts/notarize_release_zip.sh
```

The notarization script writes canonical final evidence under `dist/release-evidence/` only after every notarization and final ZIP verification step succeeds. `notarytool-submit.log` records exactly one submitted archive SHA-256, UTC submission time, sanitized submission command, submitted bundle ID, version, build, architectures, and app CDHash; release evidence checks require those fields to be unique and match the current app. `final-zip-verify.log` records exactly one verified archive path, the extracted final ZIP SHA-256, extracted app bundle ID, version, build, architectures, CDHash, success marker, codesign `valid on disk`, designated-requirement, stapler validation, and Gatekeeper assessment line. If a step fails, inspect the matching `.failed` evidence file instead of treating it as final release evidence; release evidence and publish-readiness checks reject stale `.attempt` / `.failed` notarization evidence until a fresh candidate/package cleanup removes it.
It accepts only `NOTARYTOOL_PROFILE`; do not pass Apple ID or password values through environment variables for this release path.
If `./scripts/package_zip.sh` is run again afterward, treat prior notarization, bundle-open verification, and visual QA acceptance as invalid and repeat the final publish gate.

## Notarized Publish Gate

After notarization creates the final ZIP, record the normal-session bundle-open pass and accepted human visual pass with the final verified archive path, bundle ID, version, build, architectures, CDHash, and ZIP SHA-256:

```sh
./scripts/record_bundle_open_verification.sh --operator "Operator Name"
./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"
```

The bundle-open command opens the existing `dist/Hazakura Wallpaper.app` without rebuilding, confirms its `Contents/MacOS/HazakuraWallpaper` process remains running through an anchored executable-path process match, requires final ZIP verification to identify `dist/Hazakura Wallpaper.zip` with exactly one matching archive, bundle ID, version, build, architecture, CDHash, and ZIP SHA-256 field, writes `bundle-open-verified.txt` with the current bundle ID, version, build, architectures, CDHash, ZIP SHA-256, UTC timestamp, app path, and executable path, refreshes the release manifest, and reruns release evidence checks.
It refuses to write until the manifest proves `Final notarized ZIP verified: yes` for the current ZIP.
Set `HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS=<seconds>` only when the app needs a longer normal-session launch settle period; the value must be a positive number.
The `--operator` and `--reviewer` values must be single-line, non-empty human identifiers.
The visual QA command refuses to write `visual-qa-accepted.txt` until the manifest and final ZIP verification evidence prove that the current ZIP is the notarized final ZIP and identify `dist/Hazakura Wallpaper.zip` as the verified archive with exactly one matching archive, bundle ID, version, build, architecture, CDHash, and ZIP SHA-256 field. It also requires `--checklist-complete` as an explicit human assertion that every applicable checklist item above was reviewed. When it writes evidence, it records the current `docs/RELEASE_QA.md` SHA-256, refreshes the release manifest, and reruns release evidence checks. Use `--dry-run --accepted --checklist-complete --reviewer "Reviewer Name"` only to preview the evidence format.

Run the strict fail-closed gate before uploading a notarized build:

```sh
HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION=1 ./scripts/check_publish_readiness.sh
```

Do not publish unless all are true:

- `NOTARYTOOL_APPLE_ID`, `NOTARYTOOL_TEAM_ID`, and `NOTARYTOOL_PASSWORD` are not set; this release path uses only a stored `NOTARYTOOL_PROFILE`.
- Developer ID signing passes.
- `dist/release-evidence/notarytool-submit.log` reports a strict `status: Accepted` line and records the UTC submission time, sanitized submission command, submitted app bundle ID, version, build, architectures, and CDHash that match the current app.
- `dist/release-evidence/stapler.log` reports the exact stapler success line, and live stapler validation succeeds for the current `dist/Hazakura Wallpaper.app`.
- `dist/release-evidence/spctl-after-notarization.txt` reports a strict `path: accepted` Gatekeeper assessment, and live Gatekeeper assessment passes for the current `dist/Hazakura Wallpaper.app`.
- `dist/release-evidence/final-zip-verify.log` says the extracted final ZIP passed and records exactly one verified archive path plus the final ZIP SHA-256, extracted app bundle ID, version, build, CDHash, success marker, codesign validity, designated requirement, stapler validation, and Gatekeeper assessment.
- `dist/release-evidence/macho-build.txt` and `dist/release-evidence/final-zip-verify.log` both prove the executable is Universal for `arm64` and `x86_64`.
- `dist/release-evidence/release-evidence-check.txt` says the manifest, checksums, ZIP, preview evidence, preview determinism evidence, icon evidence, live ZIP content re-extraction, extracted ZIP app identity, final ZIP verification evidence, and notarization evidence agree.
- `dist/release-evidence/release-evidence-check.txt` says `Final notarized ZIP verified: yes` and lists notarization, stapler, post-notarization Gatekeeper, and final ZIP verification evidence.
- `dist/release-evidence/release-evidence-check.txt` no longer lists release-evidence-derived publish-readiness blockers after bundle-open and visual QA evidence are recorded.
- `./scripts/check_publish_readiness.sh` rejects the build if `dist/release-evidence/release-evidence-check.txt` still lists any release-evidence-derived publish-readiness blockers.
- `dist/release-evidence/bundle-open-verified.txt` says the normal-session bundle-open check passed for the same bundle ID, version, build, architectures, CDHash, ZIP SHA-256, UTC timestamp, operator, app path, executable path, and anchored process match.
- `dist/release-evidence/visual-qa-accepted.txt` says the human visual pass is accepted for the same bundle ID, version, build, architectures, CDHash, ZIP SHA-256, UTC timestamp, reviewer, checklist path, explicit checklist-complete assertion, and current checklist SHA-256.
- `./scripts/check_release_evidence.sh` and `./scripts/check_publish_readiness.sh` accept only one `YYYY-MM-DDTHH:MM:SSZ` UTC timestamp field plus one single-line, non-empty operator or reviewer provenance field in those final evidence files, and require the recorder command line to be present.
- The release manifest lists final-only notarization, bundle-open, and visual QA evidence only after final notarized ZIP verification is complete; if those files exist earlier, `./scripts/check_release_evidence.sh` rejects them.
- `dist/SHA256SUMS` matches the final uploaded artifact.
