#!/usr/bin/env zsh

cmd_profile_remove() {
  local profile_name="${1:-}"

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep profile remove <profile-name>" >&2
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

  echo -n "Remove profile '$profile_name'? (y/N): "
  read -r REPLY

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi

  rm -rf "$profile_dir"
  echo "✓ Removed profile: $profile_name"
}
