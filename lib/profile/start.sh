#!/usr/bin/env zsh

cmd_profile_start() {
  local profile_name="${1:-}"

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep start <profile-name>" >&2
    exit 1
  fi

  local profile_dir
  profile_dir="$(get_profile_dir)/$profile_name"

  if [[ ! -d "$profile_dir" ]]; then
    echo "Error: Profile not found: $profile_name" >&2
    source "$LIB_DIR/profile/list.sh"
    cmd_profile_list >&2
    exit 1
  fi

  shift
  export CLAUDE_CONFIG_DIR="$profile_dir"
  export CLAUDEP_PROFILE="$profile_name"
  exec claude "$@"
}
