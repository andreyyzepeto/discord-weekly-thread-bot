#!/bin/zsh
# Download official Node.js LTS (darwin binary tarball) into PROJECT_DIR/runtime/
# if system node/npm is missing. No sudo, no .pkg. Requires network.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RUNTIME_NAME=""
FALLBACK_VERSION="v20.19.0"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s (install or update macOS command line tools)\n' "$1" >&2
    return 1
  fi
}

require_cmd curl
require_cmd tar
require_cmd python3

ARCH="$(uname -m)"
case "$ARCH" in
  arm64)
    RUNTIME_NAME="node-darwin-arm64"
    TAR_ARCH="arm64"
    ;;
  x86_64)
    RUNTIME_NAME="node-darwin-x64"
    TAR_ARCH="x64"
    ;;
  *)
    printf 'Unsupported machine architecture: %s\n' "$ARCH" >&2
    exit 1
    ;;
esac

RUNTIME_DIR="$PROJECT_DIR/runtime/$RUNTIME_NAME"

if [[ -x "$RUNTIME_DIR/bin/node" && -x "$RUNTIME_DIR/bin/npm" ]]; then
  exit 0
fi

resolve_lts_version() {
  if JSON="$(curl -fsSL --connect-timeout 30 "https://nodejs.org/dist/index.json" 2>/dev/null)"; then
    VER="$(printf '%s' "$JSON" | python3 -c "import json,sys
d=json.load(sys.stdin)
for x in d:
  if x.get('lts'):
    print(x['version'])
    break
" 2>/dev/null || true)"
    if [[ -n "$VER" && "$VER" == v* ]]; then
      printf '%s' "$VER"
      return 0
    fi
  fi
  printf '%s' "$FALLBACK_VERSION"
}

VERSION="$(resolve_lts_version)"
BASE_URL="https://nodejs.org/dist/${VERSION}"
# Tarball: node-v20.19.0-darwin-arm64.tar.gz
TAR_BASENAME="node-${VERSION}-darwin-${TAR_ARCH}.tar.gz"
TAR_URL="${BASE_URL}/${TAR_BASENAME}"

WORK="$(mktemp -d /tmp/ensure-node.XXXXXX)"
cleanup() { rm -rf "$WORK" }
trap cleanup EXIT

printf 'Fetching %s\n' "$TAR_URL"
curl -fSL --connect-timeout 30 --retry 2 -o "$WORK/archive.tar.gz" "$TAR_URL"
tar -xzf "$WORK/archive.tar.gz" -C "$WORK"

# Extracted folder: node-v20.19.0-darwin-arm64 (or -x64)
EXTRACTED="$(find "$WORK" -maxdepth 1 -name 'node-v*-darwin-*' -type d | head -1)"
if [[ -z "$EXTRACTED" || ! -d "$EXTRACTED" ]]; then
  printf 'Could not find extracted node directory in tarball\n' >&2
  exit 1
fi

if [[ ! -x "$EXTRACTED/bin/node" || ! -f "$EXTRACTED/bin/npm" ]]; then
  printf 'Invalid Node.js layout under %s\n' "$EXTRACTED" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/runtime"
if [[ -d "$RUNTIME_DIR" ]]; then
  rm -rf "$RUNTIME_DIR"
fi
mv "$EXTRACTED" "$RUNTIME_DIR"

# Reduce Gatekeeper friction on downloaded executables
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$RUNTIME_DIR" 2>/dev/null || true
fi

exit 0
