#!/usr/bin/env zsh

cmd_profile_add() {
  local profile_name="${1:-}"

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep profile add <profile-name> [--template <name>]" >&2
    exit 1
  fi
  shift

  # validate folder name (no slashes, no leading dots)
  if [[ "$profile_name" =~ [/\\] ]] || [[ "$profile_name" == .* ]]; then
    echo "Error: Invalid profile name: $profile_name" >&2
    echo "  Must be valid folder name, no slashes, no leading dots" >&2
    exit 1
  fi

  local template_name="default"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template) template_name="$2"; shift 2 ;;
      *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

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
  ln -s "$template_dir/agents" "$new_profile_dir/agents"
  ln -s "$template_dir/rules" "$new_profile_dir/rules"
  ln -s "$template_dir/skills" "$new_profile_dir/skills"
  ln -s "$template_dir/statusline" "$new_profile_dir/statusline"
  ln -s "$template_dir/CLAUDE.md" "$new_profile_dir/CLAUDE.md"
  # TODO: kr -> keybindings:enter - https://github.com/anthropics/claude-code/issues/25087
  ln -s "$template_dir/keybindings.json" "$new_profile_dir/keybindings.json"
  ln -s "$template_dir/settings.json" "$new_profile_dir/settings.json"

  echo "✓ Created profile: $profile_name (template: $template_name)"
  echo "  Location: $new_profile_dir"
}
