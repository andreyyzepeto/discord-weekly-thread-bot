#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
ENV_TEMPLATE_FILE="$PROJECT_DIR/.env.example"
GUIDE_MESSAGE_TEMPLATE_FILE="$PROJECT_DIR/guide-message.txt"
TIMEZONE_LIST_FILE="$PROJECT_DIR/recommended-timezones.txt"
APP_WRAPPER_SCRIPT="$PROJECT_DIR/scripts/create-app-wrappers.sh"
source "$PROJECT_DIR/scripts/instance-env.sh"

print_line() {
  printf '%s\n' "$1"
}

source "$PROJECT_DIR/scripts/ensure-node-for-session.sh"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print_line ""
    print_line "Missing required command: $1"
    exit 1
  fi
}

validate_timezone() {
  local timezone="$1"

  grep -Fxq "$timezone" "$TIMEZONE_LIST_FILE"
}

read_env_value() {
  local env_file="$1"
  local key="$2"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$env_file"
}

write_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"

  if [[ -f "$env_file" ]]; then
    awk -F= -v key="$key" -v value="$value" '
      $1 == key { print key "=" value; updated = 1; next }
      { print }
      END { if (!updated) print key "=" value }
    ' "$env_file" > "$tmp_file"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp_file"
  fi

  mv "$tmp_file" "$env_file"
}

choose_timezone() {
  local default_value="$1"
  local -a timezone_options
  local timezone_option
  local timezone_selection

  if [[ ! -s "$TIMEZONE_LIST_FILE" ]]; then
    print_line "recommended-timezones.txt must exist and contain at least one timezone."
    exit 1
  fi

  timezone_options=("${(@f)$(grep -v '^[[:space:]]*$' "$TIMEZONE_LIST_FILE")}")

  print_line ""
  print_line "Choose a timezone from the recommended list:"

  local index=1
  local label=""
  for timezone_option in "${timezone_options[@]}"; do
    label=""
    if [[ -n "$default_value" && "$timezone_option" == "$default_value" ]]; then
      label=" [current]"
    fi
    printf " %2d) %s%s\n" "$index" "$timezone_option" "$label"
    ((index++))
  done

  print_line ""
  printf "Timezone number: "
  read -r timezone_selection

  if [[ -z "$timezone_selection" ]]; then
    print_line "TIMEZONE selection cannot be empty."
    exit 1
  fi

  if [[ ! "$timezone_selection" =~ ^[0-9]+$ || "$timezone_selection" -lt 1 || "$timezone_selection" -gt "${#timezone_options[@]}" ]]; then
    print_line "Choose a valid timezone number from the list."
    exit 1
  fi

  REPLY="$timezone_options[$timezone_selection]"
}

choose_day() {
  local default_value="$1"
  local -a day_options
  local -a day_labels
  local day_selection
  local index
  local label

  day_options=("mon" "tue" "wed" "thu" "fri" "sat" "sun")
  day_labels=("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday")

  print_line ""
  print_line "Choose the weekly posting day:"

  index=1
  for day_code in "${day_options[@]}"; do
    label=""
    if [[ -n "$default_value" && "$day_code" == "$default_value" ]]; then
      label=" [current]"
    fi
    printf " %2d) %s (%s)%s\n" "$index" "$day_labels[$index]" "$day_code" "$label"
    ((index++))
  done

  print_line ""
  printf "Posting day number: "
  read -r day_selection

  if [[ -z "$day_selection" ]]; then
    print_line "DAY_OF_WEEK selection cannot be empty."
    exit 1
  fi

  if [[ ! "$day_selection" =~ ^[0-9]+$ || "$day_selection" -lt 1 || "$day_selection" -gt "${#day_options[@]}" ]]; then
    print_line "Choose a valid posting day number from the list."
    exit 1
  fi

  REPLY="$day_options[$day_selection]"
}

ensure_instance_files() {
  local instance_name="$1"
  local instance_dir
  local env_file
  local guide_file

  instance_dir="$(instance_dir_path "$instance_name")"
  env_file="$(instance_env_file_path "$instance_name")"
  guide_file="$(instance_guide_file_path "$instance_name")"

  mkdir -p "$instance_dir"

  if [[ ! -f "$env_file" ]]; then
    cp "$ENV_TEMPLATE_FILE" "$env_file"
  fi

  if [[ ! -f "$guide_file" ]]; then
    cp "$GUIDE_MESSAGE_TEMPLATE_FILE" "$guide_file"
  fi
}

configure_instance() {
  local instance_name="$1"
  local env_file
  local guide_file
  local existing_channel_id
  local existing_token
  local existing_hour
  local existing_day
  local existing_timezone
  local existing_title_suffix
  local discord_token_input
  local channel_id_input
  local day_input
  local timezone_input
  local hour_input
  local title_suffix_input
  local should_edit_message
  local guide_message_file_input
  local existing_guide_message_file

  env_file="$(instance_env_file_path "$instance_name")"
  existing_channel_id="$(read_env_value "$env_file" "CHANNEL_ID")"
  existing_token="$(read_env_value "$env_file" "DISCORD_TOKEN")"
  existing_hour="$(read_env_value "$env_file" "HOUR")"
  existing_day="$(read_env_value "$env_file" "DAY_OF_WEEK")"
  existing_timezone="$(read_env_value "$env_file" "TIMEZONE")"
  existing_title_suffix="$(read_env_value "$env_file" "TITLE_SUFFIX")"
  existing_guide_message_file="$(read_env_value "$env_file" "GUIDE_MESSAGE_FILE")"
  if [[ -z "$existing_guide_message_file" ]]; then
    existing_guide_message_file="guide-message.txt"
  fi

  print_line ""
  print_line "Configuring $instance_name"

  printf "Discord bot token%s: " "${existing_token:+ [currently set]}"
  read -rs discord_token_input
  print_line ""

  if [[ -z "$discord_token_input" ]]; then
    print_line "DISCORD_TOKEN cannot be empty."
    exit 1
  fi

  printf "Discord channel ID%s: " "${existing_channel_id:+ [current: $existing_channel_id]}"
  read -r channel_id_input

  if [[ -z "$channel_id_input" ]]; then
    print_line "CHANNEL_ID cannot be empty."
    exit 1
  fi

  if [[ ! "$channel_id_input" =~ ^[0-9]+$ ]]; then
    print_line "CHANNEL_ID must contain digits only."
    exit 1
  fi

  if [[ -z "$existing_timezone" ]]; then
    existing_timezone="Asia/Seoul"
  fi

  if [[ -z "$existing_title_suffix" ]]; then
    existing_title_suffix="Feed Boosting Request"
  fi

  if [[ -z "$existing_day" ]]; then
    existing_day="mon"
  fi

  choose_timezone "$existing_timezone"
  timezone_input="$REPLY"

  if ! validate_timezone "$timezone_input"; then
    print_line "TIMEZONE must be a valid IANA timezone such as Asia/Seoul."
    exit 1
  fi

  choose_day "$existing_day"
  day_input="$REPLY"

  printf "Scheduled hour%s: " "${existing_hour:+ [current: $existing_hour]}"
  read -r hour_input

  if [[ -z "$hour_input" ]]; then
    print_line "HOUR cannot be empty."
    exit 1
  fi

  if [[ ! "$hour_input" =~ ^[0-9]+$ || "$hour_input" -lt 0 || "$hour_input" -gt 23 ]]; then
    print_line "HOUR must be an integer between 0 and 23."
    exit 1
  fi

  printf "Thread title suffix%s: " "${existing_title_suffix:+ [current: $existing_title_suffix]}"
  read -r title_suffix_input
  if [[ -z "$title_suffix_input" ]]; then
    title_suffix_input="$existing_title_suffix"
  fi

  if [[ -z "$title_suffix_input" ]]; then
    print_line "TITLE_SUFFIX cannot be empty."
    exit 1
  fi

  printf "Guide message file (relative to this instance folder, or an absolute path)%s: " "${existing_guide_message_file:+ [current: $existing_guide_message_file]}"
  read -r guide_message_file_input
  if [[ -z "$guide_message_file_input" ]]; then
    guide_message_file_input="$existing_guide_message_file"
  fi
  if [[ "$guide_message_file_input" == *'..'* ]]; then
    print_line "GUIDE_MESSAGE_FILE must not contain parent directory references (..)."
    exit 1
  fi

  if [[ "$guide_message_file_input" = /* ]]; then
    guide_file="$guide_message_file_input"
  else
    guide_file="$(instance_dir_path "$instance_name")/$guide_message_file_input"
  fi

  mkdir -p "${guide_file:h}"
  if [[ ! -f "$guide_file" ]]; then
    cp "$GUIDE_MESSAGE_TEMPLATE_FILE" "$guide_file"
  fi

  write_env_value "$env_file" "DISCORD_TOKEN" "$discord_token_input"
  write_env_value "$env_file" "CHANNEL_ID" "$channel_id_input"
  write_env_value "$env_file" "DAY_OF_WEEK" "$day_input"
  write_env_value "$env_file" "HOUR" "$hour_input"
  write_env_value "$env_file" "TIMEZONE" "$timezone_input"
  write_env_value "$env_file" "TITLE_SUFFIX" "$title_suffix_input"
  write_env_value "$env_file" "GUIDE_MESSAGE_FILE" "$guide_message_file_input"

  print_line ""
  printf "Edit the thread guide message for %s now? [y/N]: " "$instance_name"
  read -r should_edit_message

  if [[ "$should_edit_message" =~ ^[Yy]$ ]]; then
    if command -v open >/dev/null 2>&1; then
      open -W -t "$guide_file"
    else
      "${EDITOR:-nano}" "$guide_file"
    fi
  fi

  if [[ ! -s "$guide_file" ]]; then
    print_line "Guide message file must exist and cannot be empty: $guide_file"
    exit 1
  fi
}

print_line "Discord Weekly Thread Bot Multi-Instance Installer"
print_line ""

if [[ -z "$NODE_BIN" ]]; then
  print_line ""
  print_line "Node.js runtime was not found."
  exit 1
fi

if [[ -z "$NPM_BIN" ]]; then
  print_line ""
  print_line "npm was not found."
  exit 1
fi

if [[ ! -s "$TIMEZONE_LIST_FILE" ]]; then
  print_line "recommended-timezones.txt must exist and contain at least one timezone."
  exit 1
fi

if [[ ! -f "$APP_WRAPPER_SCRIPT" ]]; then
  print_line "create-app-wrappers.sh is missing."
  exit 1
fi

cd "$PROJECT_DIR"

typeset -a raw_instance_names current_instance_names desired_instance_names
raw_instance_names=("${(@f)$(list_instance_names)}")
current_instance_names=()
for instance_name in "${raw_instance_names[@]}"; do
  if [[ -n "$instance_name" ]]; then
    current_instance_names+=("$instance_name")
  fi
done

print_line "How many Discord bots do you want to configure in this app? (1-20)"
print_line "You will enter token, channel, timezone, posting day, hour, and guide file path once for each bot."
printf "Bot count%s: " "${current_instance_names:+ [currently active: ${#current_instance_names[@]}]}"
read -r instance_count

if [[ -z "$instance_count" ]]; then
  print_line "Bot count cannot be empty."
  exit 1
fi

if [[ ! "$instance_count" =~ ^[0-9]+$ || "$instance_count" -lt 1 || "$instance_count" -gt 20 ]]; then
  print_line "Bot count must be an integer between 1 and 20."
  exit 1
fi

desired_instance_names=()
for index in $(seq 1 "$instance_count"); do
  desired_instance_names+=("instance-$index")
done

write_instance_registry "${desired_instance_names[@]}"

for instance_name in "${desired_instance_names[@]}"; do
  ensure_instance_files "$instance_name"
  configure_instance "$instance_name"
done

print_line ""
print_line "Installing dependencies..."
"$NPM_BIN" install

print_line ""
print_line "Building project..."
"$NPM_BIN" run build

print_line ""
printf "Run Discord connection checks for all configured instances now? [Y/n]: "
read -r should_run_doctor

if [[ -z "$should_run_doctor" || "$should_run_doctor" =~ ^[Yy]$ ]]; then
  for instance_name in "${desired_instance_names[@]}"; do
    print_line ""
    print_line "Checking $instance_name..."
    DISCORD_BOT_INSTANCE_NAME="$instance_name" "$NODE_BIN" dist/manage-instance.js doctor "$instance_name" || true
  done
fi

print_line ""
print_line "Creating per-instance macOS app shortcuts..."
zsh "$APP_WRAPPER_SCRIPT" "$PROJECT_DIR"

print_line ""
print_line "Install complete."
print_line "Configured instances:"
printf '  %s\n' "${desired_instance_names[@]}"
print_line "Double-click Start <instance>.app, Test <instance>.app, or Check <instance>.app."
print_line "If macOS blocks shortcuts, use npm run start-instance, create-now, or doctor-instance instead."
print_line "This local install stays in: $PROJECT_DIR"
