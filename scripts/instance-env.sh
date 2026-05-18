#!/bin/zsh

set -euo pipefail

if [[ -z "${PROJECT_DIR:-}" ]]; then
  PROJECT_DIR="$(cd -- "$(dirname "${(%):-%N}")/.." && pwd)"
fi

INSTANCES_DIR="$PROJECT_DIR/instances"
INSTANCE_REGISTRY_FILE="$INSTANCES_DIR/instances.json"

list_instance_names() {
  local -a names
  local name

  names=()

  if [[ -f "$INSTANCE_REGISTRY_FILE" ]]; then
    while IFS= read -r name; do
      if [[ -n "$name" ]]; then
        names+=("$name")
      fi
    done < <(
      sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*,\{0,1\}[[:space:]]*$/\1/p' "$INSTANCE_REGISTRY_FILE"
    )
  fi

  if (( ${#names[@]} == 0 )) && [[ -d "$INSTANCES_DIR" ]]; then
    for env_file in "$INSTANCES_DIR"/*/.env(N); do
      names+=("${env_file:h:t}")
    done
  fi

  if (( ${#names[@]} > 0 )); then
    printf '%s\n' "${names[@]}" | sort -u
  fi
}

write_instance_registry() {
  mkdir -p "$INSTANCES_DIR"

  {
    printf '[\n'
    local index=1
    local count=$#
    local instance_name

    for instance_name in "$@"; do
      if [[ -z "$instance_name" ]]; then
        continue
      fi

      if (( index < count )); then
        printf '  "%s",\n' "$instance_name"
      else
        printf '  "%s"\n' "$instance_name"
      fi

      ((index++))
    done
    printf ']\n'
  } > "$INSTANCE_REGISTRY_FILE"
}

instance_dir_path() {
  printf '%s\n' "$INSTANCES_DIR/$1"
}

instance_env_file_path() {
  printf '%s\n' "$(instance_dir_path "$1")/.env"
}

# Read a single key from a .env file (Key=Value). Same key semantics as install.command read_env.
read_instance_env_key() {
  local env_file="$1"
  local key="$2"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$env_file"
}

# Full path to the guide file for an instance. Uses GUIDE_MESSAGE_FILE in that instance’s .env;
# if missing, defaults to guide-message.txt. Absolute paths in .env are returned as-is.
instance_guide_file_path() {
  local instance_name="$1"
  local inst_dir
  local env_file
  local rel
  inst_dir="$(instance_dir_path "$instance_name")"
  env_file="$inst_dir/.env"
  rel="$(read_instance_env_key "$env_file" "GUIDE_MESSAGE_FILE")"
  rel="${rel//$'\r'/}"
  if [[ -z "$rel" ]]; then
    rel="guide-message.txt"
  fi
  if [[ "$rel" = /* ]]; then
    printf '%s\n' "$rel"
  else
    printf '%s\n' "$inst_dir/$rel"
  fi
}

resolve_instance_name() {
  local requested_name="${1:-}"
  local -a raw_instance_names instance_names
  local instance_name

  raw_instance_names=("${(@f)$(list_instance_names)}")
  instance_names=()
  for instance_name in "${raw_instance_names[@]}"; do
    if [[ -n "$instance_name" ]]; then
      instance_names+=("$instance_name")
    fi
  done

  if (( ${#instance_names[@]} == 0 )); then
    printf '%s\n' "No configured instances were found in $INSTANCES_DIR" >&2
    exit 1
  fi

  if [[ -n "$requested_name" ]]; then
    for instance_name in "${instance_names[@]}"; do
      if [[ "$instance_name" == "$requested_name" ]]; then
        printf '%s\n' "$instance_name"
        return 0
      fi
    done

    printf 'Unknown instance: %s\n' "$requested_name" >&2
    printf '%s\n' "Available instances:" >&2
    printf '  %s\n' "${instance_names[@]}" >&2
    exit 1
  fi

  if (( ${#instance_names[@]} == 1 )); then
    printf '%s\n' "${instance_names[1]}"
    return 0
  fi

  printf '%s\n' "An instance name is required." >&2
  printf '%s\n' "Available instances:" >&2
  printf '  %s\n' "${instance_names[@]}" >&2
  exit 1
}
