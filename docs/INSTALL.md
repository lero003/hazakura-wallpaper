# Install Hazakura Wallpaper

Hazakura Wallpaper is a native macOS menu-bar overlay app.

## Requirements

- macOS 14 or later
- Apple Silicon or Intel Mac

## Install From DMG

1. Download `Hazakura Wallpaper.dmg` from the GitHub Release.
2. Open the DMG.
3. Drag `Hazakura Wallpaper.app` to `Applications`.
4. Launch the app from `Applications`.

The default public build may be ad-hoc signed. If macOS blocks launch, use one of the standard Gatekeeper bypass paths:

- Control-click or right-click `Hazakura Wallpaper.app`, then choose Open.
- Or open System Settings > Privacy & Security, then choose Open Anyway for Hazakura Wallpaper.

## Install From ZIP

1. Download `Hazakura Wallpaper.zip` from the GitHub Release.
2. Double-click the ZIP to extract `Hazakura Wallpaper.app`.
3. Move the app to `Applications`.
4. Launch it from `Applications`.

Gatekeeper may require the same right-click Open or System Settings > Privacy & Security > Open Anyway approval as the DMG path.

## Build From Source

Requirements:

- Xcode 26 or current Apple Swift toolchain
- macOS 14 or later
- Node/npm is optional and only needed for `npm run ...` convenience aliases; the checked-in shell scripts work directly.

Clone the `hazakura-wallpaper` repository, then build the app bundle:

```sh
./scripts/build_app.sh
```

To build from Xcode directly, open `SakuraSky.xcodeproj` and choose the shared `Hazakura Wallpaper` scheme. Keep the committed project signing defaults as-is; pass local Developer ID signing only through the release scripts when needed.

The app is generated at:

```text
dist/Hazakura Wallpaper.app
```

Verify the release candidate before sharing:

```sh
./scripts/prepare_release_candidate.sh
./scripts/check_publish_readiness.sh
```

The same candidate gate is also available as `npm run release:candidate` when npm is available.

## Menu Bar Controls

Hazakura Wallpaper runs as a menu-bar app. Use the menu-bar icon to:

- pause or resume the overlay
- switch effect mode
- change intensity
- toggle night-sakura background
- reset settings
- quit the app

## Uninstall

1. Quit Hazakura Wallpaper from the menu-bar icon.
2. Delete `Hazakura Wallpaper.app` from `Applications`.

To remove local app settings as well:

```sh
defaults delete com.hazakuralab.hazakurawallpaper
```

The app does not install launch agents, background services, browser extensions, or cloud credentials.
