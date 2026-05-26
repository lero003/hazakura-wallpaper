#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

CHECK_PATHS=("$@")
using_default_paths=0
if [[ "${#CHECK_PATHS[@]}" -eq 0 ]]; then
  CHECK_PATHS=(Sources/SakuraSky Sources/SakuraSkyCore Sources/SakuraSkyRenderer)
  using_default_paths=1
fi

for path in "${CHECK_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing privacy/security boundary check path: $path" >&2
    exit 1
  fi
done

fail_if_matches() {
  local pattern="$1"
  local message="$2"
  local matches

  matches="$(rg -n -e "$pattern" "${CHECK_PATHS[@]}" || true)"
  if [[ -n "$matches" ]]; then
    echo "Privacy/security boundary check failed: $message" >&2
    echo "$matches" >&2
    exit 1
  fi
}

fail_if_matches \
  '\b(URLSession|NSURLConnection|URLRequest|URLResponse|HTTPURLResponse|HTTPCookieStorage|WKWebView|CFNetwork|NWConnection|NWListener|NWBrowser|NWPathMonitor|NWEndpoint|NWTCPConnection|NWUDPSession)\b' \
  "runtime source must not introduce network clients, web views, or background network APIs."

fail_if_matches \
  '\b(SecItemAdd|SecItemCopyMatching|SecItemUpdate|SecItemDelete|SecKeychain|AuthorizationCreate|AuthorizationExecuteWithPrivileges|LAContext|ASAuthorization[A-Za-z]*)\b' \
  "runtime source must not introduce Keychain, authentication, or privileged authorization APIs."

fail_if_matches \
  '\b(Process|NSTask)\s*\(|\b(posix_spawn|system|popen|dlopen)\s*\(' \
  "runtime source must not spawn external processes or dynamic loaders."

fail_if_matches \
  '\b(NSPasteboard|CGWindowList|CGDisplayStream|ScreenCaptureKit|SCStream|AVCaptureDevice|AVCaptureSession)\b' \
  "runtime source must not read pasteboard, capture screen/window contents, or access cameras."

fail_if_matches \
  '\bNSHomeDirectory\s*\(|homeDirectoryForCurrentUser|\.documentDirectory|\.desktopDirectory|\.downloadsDirectory|\.picturesDirectory|\.moviesDirectory|\.musicDirectory' \
  "runtime source must not scan broad user directories; keep file access scoped to app settings/assets."

fail_if_matches \
  'http://' \
  "runtime source must not use insecure HTTP URLs."

if [[ "$using_default_paths" -eq 1 ]]; then
  open_matches="$(rg -n -e 'NSWorkspace\.shared\.open\s*\(' Sources/SakuraSky Sources/SakuraSkyCore Sources/SakuraSkyRenderer || true)"
  open_count="$(printf '%s\n' "$open_matches" | grep -c 'NSWorkspace\.shared\.open' || true)"
  if [[ "$open_count" != "1" ]] || ! printf '%s\n' "$open_matches" | grep -Fq 'Sources/SakuraSky/StatusBarController.swift:'; then
    echo "Privacy/security boundary check failed: external URL opening must stay limited to the status menu lab-site action." >&2
    echo "$open_matches" >&2
    exit 1
  fi

  if ! grep -Fq 'public static let labSiteURLString = "https://hazakuralab.pages.dev"' Sources/SakuraSkyCore/AppExternalLinks.swift; then
    echo "Privacy/security boundary check failed: the only app-owned external URL must be the public Hazakura Lab HTTPS URL." >&2
    exit 1
  fi
fi

echo "Privacy/security boundary checks passed."
