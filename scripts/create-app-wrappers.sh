#!/bin/zsh

set -euo pipefail

TARGET_DIR="${1:?Usage: create-app-wrappers.sh <target-dir>}"
TITLE="Discord Weekly Thread Bot"
PROJECT_DIR="$TARGET_DIR"
source "$TARGET_DIR/scripts/instance-env.sh"

if ! command -v osacompile >/dev/null 2>&1; then
  printf '%s\n' "osacompile was not found."
  exit 1
fi

create_sync_app() {
  local app_name="$1"
  local script_name="$2"
  local default_message="$3"
  local instance_name="$4"
  local script_path="$TARGET_DIR/$script_name"
  local app_path="$TARGET_DIR/$app_name.app"

  rm -rf "$app_path"

  osacompile -o "$app_path" <<APPLESCRIPT
on run
  set scriptPath to "$script_path"
  set instanceName to "$instance_name"
  try
    set commandOutput to do shell script (quoted form of scriptPath & space & quoted form of instanceName)
    if commandOutput is "" then set commandOutput to "$default_message"
    display dialog commandOutput with title "$TITLE - $instance_name" buttons {"OK"} default button "OK"
  on error errMsg number errNum
    display dialog (errMsg & return & "(Error " & errNum & ")") with title "$TITLE - $instance_name" buttons {"OK"} default button "OK" with icon stop
  end try
end run
APPLESCRIPT
}

create_terminal_app() {
  local app_name="$1"
  local script_name="$2"
  local instance_name="$3"
  local script_path="$TARGET_DIR/$script_name"
  local app_path="$TARGET_DIR/$app_name.app"

  rm -rf "$app_path"

  osacompile -o "$app_path" <<APPLESCRIPT
on run
  set scriptPath to "$script_path"
  set instanceName to "$instance_name"
  tell application "Terminal"
    activate
    do script (quoted form of scriptPath & space & quoted form of instanceName)
  end tell
end run
APPLESCRIPT
}

create_uninstall_app() {
  local app_name="Uninstall Discord Weekly Thread Bot"
  local script_path="$TARGET_DIR/uninstall.command"
  local app_path="$TARGET_DIR/$app_name.app"

  rm -rf "$app_path"

  osacompile -o "$app_path" <<APPLESCRIPT
on run
  set scriptPath to "$script_path"
  try
    do shell script quoted form of scriptPath
  on error errMsg number errNum
    display dialog (errMsg & return & "(Error " & errNum & ")") with title "$TITLE" buttons {"OK"} default button "OK" with icon stop
  end try
end run
APPLESCRIPT
}

for app_path in "$TARGET_DIR"/*.app(N); do
  app_name="${app_path:t}"

  case "$app_name" in
    "Test Now.app"|"Check Connection.app"|"Enable Scheduled Mode.app"|"Disable Scheduled Mode.app"|"Uninstall Discord Weekly Thread Bot.app"|Start\ *|Test\ *|Check\ *)
      rm -rf "$app_path"
      ;;
  esac
done

typeset -a raw_instance_names instance_names
raw_instance_names=("${(@f)$(list_instance_names)}")
instance_names=()
for instance_name in "${raw_instance_names[@]}"; do
  if [[ -n "$instance_name" ]]; then
    instance_names+=("$instance_name")
  fi
done

if (( ${#instance_names[@]} == 0 )); then
  exit 0
fi

for instance_name in "${instance_names[@]}"; do
  create_sync_app "Test ${instance_name}" "test-now.command" "Test run finished." "$instance_name"
  create_sync_app "Check ${instance_name}" "doctor.command" "Connection check finished." "$instance_name"
  create_terminal_app "Start ${instance_name}" "start.command" "$instance_name"
done

create_uninstall_app
