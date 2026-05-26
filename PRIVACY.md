# Privacy

Hazakura Wallpaper is a local macOS desktop overlay app.

## Data Collection

The app does not collect analytics, telemetry, crash reports, or usage data for remote upload.

## Local Data

The app stores local settings such as effect mode, intensity, and night background preference using macOS user defaults. During first launch after migration, it may import legacy local Tauri settings from the user's Application Support folder when Swift settings are missing or unreadable.

The app intentionally does not persist the paused state; each launch starts with rendering enabled.

## Network Use

The app does not make background network requests. The menu item for Hazakura Lab opens the public site in the user's default browser.

## Logs

The app writes local unified logs for lifecycle, settings, overlay, and menu-bar diagnostics. These logs stay on the user's Mac unless the user chooses to share them.

## Distribution

Unsigned GitHub/DMG builds may require Gatekeeper bypass on other Macs. This does not change the app's data behavior; it only affects macOS launch approval.
