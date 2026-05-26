# Security Policy

## Supported Distribution

The default public build is an ad-hoc signed macOS app for GitHub ZIP/DMG distribution. Users may need to bypass Gatekeeper with right-click Open or System Settings > Privacy & Security > Open Anyway.

Developer ID signing and notarization are optional for frictionless downloads. The notarization workflow uses a stored `notarytool` keychain profile through `NOTARYTOOL_PROFILE`; do not pass Apple ID, team ID, or signing secrets through command arguments or committed files.

## Security Boundaries

- The app is a local macOS menu-bar overlay.
- The app does not need cloud credentials.
- The app does not bundle private signing material.
- The unsigned release gate rejects entitlements in the public app bundle.
- Publish readiness scans source files for local paths, generated artifacts, credential-like filenames, private-key or certificate markers, token-like markers, and explicit notary credential arguments.
- Publish readiness scans runtime Swift sources for unexpected network clients, web views, Keychain/authentication APIs, external process spawning, pasteboard reads, screen/window capture APIs, broad user-directory scans, and insecure HTTP URLs.

## Reporting

Report security issues through the GitHub repository issue tracker or the repository security advisory feature if it is enabled. Do not include secrets, signing identities, credentials, or private local paths in public reports.

Please include:

- affected version or commit
- macOS version
- steps to reproduce
- whether the issue affects source, build artifacts, runtime behavior, or release evidence

## Release Checks

Before publishing an unsigned GitHub/DMG build, run:

```sh
./scripts/check_publish_readiness.sh
```

Before handing a DMG/ZIP to users, run the stricter normal-session gate:

```sh
npm run share:unsigned -- --operator "Operator Name" --reviewer "Reviewer Name" --accepted --checklist-complete
```

This records DMG, LaunchServices bundle-open, memory, and human visual QA evidence before `check_share_readiness.sh` can pass.
It does not rebuild the app or ZIP after visual acceptance, keeping the human evidence tied to the exact candidate on disk.
The share path runs `check_unsigned_share_prerequisites.sh --strict-normal-session` first so local tool or hdiutil session failures occur before release evidence is written.
