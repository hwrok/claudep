#!/usr/bin/env zsh

cmd_template_remove() {
  local template_name="${1:-}"

  if [[ -z "$template_name" ]]; then
    echo "Error: Template name required" >&2
    echo "Usage: claudep template remove <name>" >&2
    exit 1
  fi

  if [[ "$template_name" == "default" ]]; then
    echo "Error: Cannot remove the default template" >&2
    exit 1
  fi

  local templates_dir
  templates_dir=$(get_templates_dir)

  local template_dir="$templates_dir/$template_name"

  if [[ ! -d "$template_dir" ]]; then
    echo "Error: Template not found: $template_name" >&2
    source "$LIB_DIR/template/list.sh"
    cmd_template_list >&2
    exit 1
  fi

  # check if any profiles are using this template
  local profile_dir
  profile_dir=$(get_profile_dir)
  local -a linked_profiles=()

  for p in "$profile_dir"/*(N); do
    [[ ! -d "$p" ]] && continue
    for item in "$p"/*(-@N) "$p"/*(N@); do
      local link_target
      link_target=$(readlink "$item" 2>/dev/null || true)
      if [[ "$link_target" == "$template_dir"* ]]; then
        linked_profiles+=("$(basename "$p")")
        break
      fi
    done
  done

  if [[ ${#linked_profiles[@]} -gt 0 ]]; then
    echo "⚠️  The following profiles are linked to this template:" >&2
    printf "    %s\n" "${linked_profiles[@]}" >&2
    echo "  Eject or remove them first." >&2
    exit 1
  fi

  echo -n "Remove template '$template_name'? (y/N): "
  read -r REPLY

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi

  rm -rf "$template_dir"
  echo "✓ Removed template: $template_name"
}
