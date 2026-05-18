#!/bin/zsh

set -euo pipefail

if [[ -z "${PROJECT_DIR:-}" ]]; then
  PROJECT_DIR="$(cd -- "$(dirname "${(%):-%N}")/.." && pwd)"
fi

ARCH="$(uname -m)"
RUNTIME_DIR=""

case "$ARCH" in
  arm64)
    RUNTIME_DIR="$PROJECT_DIR/runtime/node-darwin-arm64"
    ;;
  x86_64)
    RUNTIME_DIR="$PROJECT_DIR/runtime/node-darwin-x64"
    ;;
esac

NODE_BIN=""
NPM_BIN=""

if [[ -n "$RUNTIME_DIR" && -x "$RUNTIME_DIR/bin/node" ]]; then
  NODE_BIN="$RUNTIME_DIR/bin/node"
  NPM_BIN="$RUNTIME_DIR/bin/npm"
else
  NODE_BIN="$(command -v node 2>/dev/null || true)"
  NPM_BIN="$(command -v npm 2>/dev/null || true)"
fi

if [[ -z "$NODE_BIN" || -z "$NPM_BIN" ]]; then
  if [[ -z "$RUNTIME_DIR" ]]; then
    printf '%s\n' "This Mac’s CPU is not supported for automatic Node install: $ARCH" >&2
    exit 1
  fi
  zsh "$PROJECT_DIR/scripts/ensure-node-runtime.sh" || exit $?
  NODE_BIN="$RUNTIME_DIR/bin/node"
  NPM_BIN="$RUNTIME_DIR/bin/npm"
fi

export PROJECT_DIR
export NODE_BIN
export NPM_BIN
