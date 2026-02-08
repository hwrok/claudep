#!/usr/bin/env zsh

cmd_profile_eject() {
  local profile_name="${1:-}"
  shift

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep profile eject <profile-name> --all | --items <item1,item2,...>" >&2
    exit 1
  fi

  local profile_dir
  profile_dir="$(get_profile_dir)/$profile_name"

  if [[ ! -d "$profile_dir" ]]; then
    echo "Error: Profile not found: $profile_name" >&2
    exit 1
  fi

  local -A eject_map=(
    [agents]="agents"
    [rules]="rules"
    [skills]="skills"
    [statusline]="statusline"
    [instructions]="CLAUDE.md"
    [settings]="settings.json"
  )

  local -a items_to_eject=()

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) items_to_eject=("${(@k)eject_map}"); shift ;;
      --items) IFS=',' read -rA items_to_eject <<< "$2"; shift 2 ;;
      --items=*) IFS=',' read -rA items_to_eject <<< "${1#*=}"; shift ;;
      *) echo "Error: Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  if [[ ${#items_to_eject[@]} -eq 0 ]]; then
    echo "Error: Specify --all or --items <list>" >&2
    exit 1
  fi

  for item_key in "${items_to_eject[@]}"; do
    local item_path="${eject_map[$item_key]}"

    if [[ -z "$item_path" ]]; then
      echo "⚠️  Unknown item: $item_key (skipping)" >&2
      continue
    fi

    local target="$profile_dir/$item_path"

    if [[ ! -L "$target" ]]; then
      echo "  $item_key: already ejected (not a symlink)"
      continue
    fi

    # resolve symlink source before removing
    local source
    source=$(readlink "$target")

    rm "$target"
    cp -r "$source" "$target"

    # handle settings.json -> update statusline path from whatever template it came from
    if [[ "$item_path" == "settings.json" ]]; then
      local source_dir
      source_dir=$(dirname "$source")
      sed -i.bak "s|$source_dir/statusline|$profile_dir/statusline|g" "$target"
      rm "$target.bak"
    fi

    # restore executable bit if needed
    if [[ "$item_path" == "statusline" ]]; then
      chmod +x "$target/statusline.sh"
    fi

    echo "✓ Ejected: $item_key"
  done

  echo ""
  echo "Profile '$profile_name' ejected items are now independent copies."
}
