#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
source "$PROJECT_DIR/scripts/ensure-node-for-session.sh"
source "$PROJECT_DIR/scripts/instance-env.sh"

if [[ -z "$NODE_BIN" ]]; then
  printf '%s\n' "Node.js runtime was not found."
  exit 1
fi

INSTANCE_NAME="$(resolve_instance_name "${1:-}")"
DISCORD_BOT_INSTANCE_NAME="$INSTANCE_NAME" "$NODE_BIN" dist/manage-instance.js doctor "$INSTANCE_NAME"
