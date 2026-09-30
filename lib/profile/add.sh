#!/usr/bin/env zsh

cmd_profile_add() {
  local profile_name="${1:-}"

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep profile add <profile-name> [--template <name>]" >&2
    exit 1
  fi
  shift

  validate_name profile "$profile_name"

  if [[ "$profile_name" == -* ]]; then
    echo "Error: Profile name can't start with '-': '$profile_name'" >&2
    exit 1
  fi

  local template_name="default"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template) template_name="$2"; shift 2 ;;
      *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  validate_name template "$template_name"

  local template_dir="$(get_templates_dir)/$template_name"

  local new_profile_dir
  new_profile_dir="$(get_profile_dir)/$profile_name"

  if [[ -d "$new_profile_dir" ]]; then
    echo "Error: Profile already exists: $profile_name" >&2
    exit 1
  fi

  if [[ ! -d "$template_dir" ]]; then
    echo "Error: Template not found: $template_name ($template_dir)" >&2
    exit 1
  fi

  mkdir -p "$new_profile_dir"

  # symlink shared resources from template
  local item
  for item in $(shared_item_paths); do
    ln -s "$template_dir/$item" "$new_profile_dir/$item"
  done

  echo "✓ Created profile: $profile_name (template: $template_name)"
  echo "  Location: $new_profile_dir"
}
