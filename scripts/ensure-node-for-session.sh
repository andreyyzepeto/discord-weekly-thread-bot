#!/bin/zsh
# Source from bot-files tools after: PROJECT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
#   source "$PROJECT_DIR/scripts/ensure-node-for-session.sh"
set -euo pipefail

if [[ -z "${PROJECT_DIR:-}" || ! -d "$PROJECT_DIR" ]]; then
  printf '%s\n' "ensure-node-for-session.sh: set PROJECT_DIR to the bot-files directory first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROJECT_DIR/scripts/runtime-env.sh"

if [[ -z "$NODE_BIN" || -z "$NPM_BIN" ]]; then
  printf '\n'
  printf '%s\n' "Node.js was not found. Downloading the official Node.js LTS into this project (one time, network required)..."
  if ! zsh "$PROJECT_DIR/scripts/ensure-node-runtime.sh"; then
    printf '\n'
    printf '%s\n' "Automatic Node.js install failed. Install Node.js LTS from https://nodejs.org/ and run this again."
    exit 1
  fi
  source "$PROJECT_DIR/scripts/runtime-env.sh"
fi
