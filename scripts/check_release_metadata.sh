#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
PACKAGE_JSON="$ROOT_DIR/package.json"
XCODE_PROJECT="$ROOT_DIR/SakuraSky.xcodeproj/project.pbxproj"
XCODE_SCHEME="$ROOT_DIR/SakuraSky.xcodeproj/xcshareddata/xcschemes/Hazakura Wallpaper.xcscheme"

cd "$ROOT_DIR"

for path in "$INFO_PLIST" "$PACKAGE_JSON" "$XCODE_PROJECT" "$XCODE_SCHEME"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing release metadata source: $path" >&2
    exit 1
  fi
done

if ! command -v xmllint >/dev/null 2>&1; then
  echo "Missing xmllint; cannot validate the Xcode shared scheme XML." >&2
  exit 1
fi

if ! xmllint --noout "$XCODE_SCHEME" >/dev/null; then
  echo "Xcode shared scheme must be valid XML." >&2
  exit 1
fi

package_name="$(plutil -extract name raw "$PACKAGE_JSON")"
package_version="$(plutil -extract version raw "$PACKAGE_JSON")"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
plist_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
plist_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"

xcode_marketing_count="$(awk -F' = |;' '/MARKETING_VERSION = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_build_count="$(awk -F' = |;' '/CURRENT_PROJECT_VERSION = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_executable_count="$(awk -F' = |;' '/EXECUTABLE_NAME = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_code_sign_identity_count="$(awk -F' = |;' '/CODE_SIGN_IDENTITY = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_code_sign_style_count="$(awk -F' = |;' '/CODE_SIGN_STYLE = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_development_team_count="$(awk -F' = |;' '/DEVELOPMENT_TEAM = / { print $2 }' "$XCODE_PROJECT" | sort -u | wc -l | tr -d ' ')"
xcode_marketing_version="$(awk -F' = |;' '/MARKETING_VERSION = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_build="$(awk -F' = |;' '/CURRENT_PROJECT_VERSION = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_executable_name="$(awk -F' = |;' '/EXECUTABLE_NAME = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_code_sign_identity="$(awk -F' = |;' '/CODE_SIGN_IDENTITY = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_code_sign_style="$(awk -F' = |;' '/CODE_SIGN_STYLE = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_development_team="$(awk -F' = |;' '/DEVELOPMENT_TEAM = / { print $2 }' "$XCODE_PROJECT" | sort -u | head -n 1)"
xcode_release_archs="$(awk -F' = |;' '
  /\/\* Release \*\/ = \{/ { in_release = 1; next }
  in_release && /buildSettings = \{/ { in_settings = 1; next }
  in_release && in_settings && /^[[:space:]]*};/ { in_release = 0; in_settings = 0; next }
  in_release && in_settings && /ARCHS = / { print $2 }
' "$XCODE_PROJECT" | sort -u)"
xcode_release_only_active_arch="$(awk -F' = |;' '
  /\/\* Release \*\/ = \{/ { in_release = 1; next }
  in_release && /buildSettings = \{/ { in_settings = 1; next }
  in_release && in_settings && /^[[:space:]]*};/ { in_release = 0; in_settings = 0; next }
  in_release && in_settings && /ONLY_ACTIVE_ARCH = / { print $2 }
' "$XCODE_PROJECT" | sort -u)"
xcode_release_arch_count="$(awk '
  /\/\* Release \*\/ = \{/ { in_release = 1; next }
  in_release && /buildSettings = \{/ { in_settings = 1; next }
  in_release && in_settings && /^[[:space:]]*};/ { in_release = 0; in_settings = 0; next }
  in_release && in_settings && /ARCHS = / { count += 1 }
  END { print count + 0 }
' "$XCODE_PROJECT")"
xcode_release_only_active_arch_count="$(awk '
  /\/\* Release \*\/ = \{/ { in_release = 1; next }
  in_release && /buildSettings = \{/ { in_settings = 1; next }
  in_release && in_settings && /^[[:space:]]*};/ { in_release = 0; in_settings = 0; next }
  in_release && in_settings && /ONLY_ACTIVE_ARCH = / { count += 1 }
  END { print count + 0 }
' "$XCODE_PROJECT")"
app_sources_build_phase_id="$(awk '
  /\/\* Begin PBXNativeTarget section \*\// { in_targets = 1; next }
  /\/\* End PBXNativeTarget section \*\// { in_targets = 0 }
  in_targets && /^[[:space:]]*[0-9A-F]+ \/\* Hazakura Wallpaper \*\/ = \{/ { in_app_target = 1; next }
  in_app_target && /\/\* Sources \*\// { print $1; found = 1; exit }
  in_app_target && /^[[:space:]]*};/ { in_app_target = 0 }
' "$XCODE_PROJECT")"

if [[ -z "$app_sources_build_phase_id" ]]; then
  echo "Xcode app target Sources build phase is missing." >&2
  exit 1
fi

xcode_sources_build_phase="$(awk -v phase_id="$app_sources_build_phase_id" '
  $1 == phase_id && /\/\* Sources \*\/ = \{/ { in_sources = 1 }
  in_sources { print }
  in_sources && /^[[:space:]]*};/ { in_sources = 0 }
' "$XCODE_PROJECT")"

if [[ -z "$xcode_sources_build_phase" ]]; then
  echo "Xcode app target Sources build phase could not be read." >&2
  exit 1
fi

missing_xcode_sources=()
unexpected_xcode_sources=()
expected_xcode_source_names="$(mktemp)"
xcode_source_names="$(mktemp)"
trap 'rm -f "$expected_xcode_source_names" "$xcode_source_names"' EXIT

while IFS= read -r swift_source; do
  source_name="$(basename "$swift_source")"
  printf '%s\n' "$source_name" >>"$expected_xcode_source_names"
  if ! grep -Fq "/* $source_name in Sources */" <<<"$xcode_sources_build_phase"; then
    missing_xcode_sources+=("$swift_source")
  fi
done < <(
  find Sources/SakuraSky Sources/SakuraSkyCore Sources/SakuraSkyRenderer \
    -type f \
    -name '*.swift' \
    ! -name 'SakuraRenderSmoke.swift' \
    | sort
)

duplicate_xcode_source_names="$(sort "$expected_xcode_source_names" | uniq -d)"
if [[ -n "$duplicate_xcode_source_names" ]]; then
  echo "Distributable Swift source files must have unique basenames for Xcode membership checks:" >&2
  sed 's/^/  /' <<<"$duplicate_xcode_source_names" >&2
  exit 1
fi

sort -u "$expected_xcode_source_names" -o "$expected_xcode_source_names"

grep -Eo '/\* [^*]+[.]swift in Sources \*/' <<<"$xcode_sources_build_phase" |
  sed -E 's@/\* (.*[.]swift) in Sources \*/@\1@' |
  sort -u >"$xcode_source_names"

while IFS= read -r source_name; do
  [[ -z "$source_name" ]] && continue
  if ! grep -Fxq "$source_name" "$expected_xcode_source_names"; then
    unexpected_xcode_sources+=("$source_name")
  fi
done <"$xcode_source_names"

if [[ "${#missing_xcode_sources[@]}" -gt 0 ]]; then
  echo "Xcode project is missing distributable Swift source files:" >&2
  printf '  %s\n' "${missing_xcode_sources[@]}" >&2
  exit 1
fi

if [[ "${#unexpected_xcode_sources[@]}" -gt 0 ]]; then
  echo "Xcode project includes Swift source files outside the distributable app source set:" >&2
  printf '  %s\n' "${unexpected_xcode_sources[@]}" >&2
  exit 1
fi

if [[ "$xcode_marketing_count" != "1" ]]; then
  echo "Xcode MARKETING_VERSION must be identical across configurations." >&2
  exit 1
fi

if [[ "$xcode_build_count" != "1" ]]; then
  echo "Xcode CURRENT_PROJECT_VERSION must be identical across configurations." >&2
  exit 1
fi

if [[ "$xcode_executable_count" != "1" || "$xcode_executable_name" != "HazakuraWallpaper" ]]; then
  echo "Xcode EXECUTABLE_NAME must be HazakuraWallpaper across configurations." >&2
  exit 1
fi

if [[ "$xcode_code_sign_identity_count" != "1" || "$xcode_code_sign_identity" != '"-"' ]]; then
  echo 'Xcode CODE_SIGN_IDENTITY must stay "-" across configurations for ad-hoc public source builds.' >&2
  exit 1
fi

if [[ "$xcode_code_sign_style_count" != "1" || "$xcode_code_sign_style" != "Manual" ]]; then
  echo "Xcode CODE_SIGN_STYLE must stay Manual across configurations for reproducible public source builds." >&2
  exit 1
fi

if [[ "$xcode_development_team_count" != "1" || "$xcode_development_team" != '""' ]]; then
  echo "Xcode DEVELOPMENT_TEAM must stay empty across configurations; pass a local team at build time instead." >&2
  exit 1
fi

if grep -Eq 'PROVISIONING_PROFILE|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM = [A-Z0-9]+' "$XCODE_PROJECT"; then
  echo "Xcode project must not commit provisioning profiles or a concrete development team." >&2
  exit 1
fi

for required_scheme_text in \
  'BlueprintIdentifier = "500000000000000000000001"' \
  'BuildableName = "Hazakura Wallpaper.app"' \
  'BlueprintName = "Hazakura Wallpaper"' \
  'ReferencedContainer = "container:SakuraSky.xcodeproj"' \
  'buildConfiguration = "Release"'
do
  if ! grep -Fq "$required_scheme_text" "$XCODE_SCHEME"; then
    echo "Xcode shared scheme must reference the public Hazakura Wallpaper app target for builds, profiling, and archives." >&2
    exit 1
  fi
done

if [[ "$plist_executable" != "HazakuraWallpaper" ]]; then
  echo "CFBundleExecutable must be HazakuraWallpaper for the public app bundle." >&2
  exit 1
fi

if ! grep -Fq '.executable(name: "HazakuraWallpaper", targets: ["SakuraSky"])' "$ROOT_DIR/Package.swift"; then
  echo "Package.swift must expose the public executable product as HazakuraWallpaper while keeping the SakuraSky target." >&2
  exit 1
fi

if ! grep -Fq 'name: "hazakura-wallpaper"' "$ROOT_DIR/Package.swift"; then
  echo "Package.swift package name must be hazakura-wallpaper for public source distribution." >&2
  exit 1
fi

if [[ "$package_name" != "hazakura-wallpaper" ]]; then
  echo "package.json name must be hazakura-wallpaper for public source distribution." >&2
  exit 1
fi

if [[ "$xcode_release_arch_count" != "2" || "$xcode_release_archs" != '"$(ARCHS_STANDARD)"' ]]; then
  echo 'Xcode Release configurations must use ARCHS = "$(ARCHS_STANDARD)" for Universal public builds.' >&2
  exit 1
fi

if [[ "$xcode_release_only_active_arch_count" != "2" || "$xcode_release_only_active_arch" != "NO" ]]; then
  echo "Xcode Release configurations must set ONLY_ACTIVE_ARCH = NO for Universal public builds." >&2
  exit 1
fi

if [[ ! "$package_version" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "package.json version must be release-style semantic versioning, got '$package_version'." >&2
  exit 1
fi

if [[ ! "$plist_build" =~ ^[0-9]+$ ]]; then
  echo "CFBundleVersion must be a positive integer build number, got '$plist_build'." >&2
  exit 1
fi

if ! awk -v value="$plist_build" 'BEGIN { exit !(value > 0) }'; then
  echo "CFBundleVersion must be a positive integer build number, got '$plist_build'." >&2
  exit 1
fi

if [[ "$package_version" != "$plist_version" ||
  "$package_version" != "$xcode_marketing_version" ]]; then
  echo "Release version mismatch between package.json, Resources/Info.plist, and Xcode project." >&2
  echo "package.json: $package_version" >&2
  echo "Resources/Info.plist: $plist_version" >&2
  echo "Xcode MARKETING_VERSION: $xcode_marketing_version" >&2
  exit 1
fi

if [[ "$plist_build" != "$xcode_build" ]]; then
  echo "Release build number mismatch between Resources/Info.plist and Xcode project." >&2
  echo "Resources/Info.plist CFBundleVersion: $plist_build" >&2
  echo "Xcode CURRENT_PROJECT_VERSION: $xcode_build" >&2
  exit 1
fi

echo "Release metadata checks passed."
echo "Version: $package_version"
echo "Build: $plist_build"
