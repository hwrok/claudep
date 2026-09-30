#!/usr/bin/env zsh

cmd_template_add() {
  local template_name="${1:-}"

  if [[ -z "$template_name" ]]; then
    echo "Error: Template name required" >&2
    echo "Usage: claudep template add <name> [--template <source>]" >&2
    exit 1
  fi
  shift

  validate_name template "$template_name"

  if [[ "$template_name" == -* ]]; then
    echo "Error: Template name can't start with '-': '$template_name'" >&2
    exit 1
  fi

  local source_name="default"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template) source_name="$2"; shift 2 ;;
      *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  validate_name template "$source_name"

  local templates_dir
  templates_dir=$(get_templates_dir)

  local source_dir="$templates_dir/$source_name"
  local dest_dir="$templates_dir/$template_name"

  if [[ -d "$dest_dir" ]]; then
    echo "Error: Template already exists: $template_name" >&2
    exit 1
  fi

  if [[ ! -d "$source_dir" ]]; then
    echo "Error: Source template not found: $source_name ($source_dir)" >&2
    exit 1
  fi

  cp -r "$source_dir" "$dest_dir"

  # ensure statusline is executable
  [[ -f "$dest_dir/statusline/statusline.sh" ]] && \
    chmod +x "$dest_dir/statusline/statusline.sh"

  echo "✓ Created template: $template_name (from: $source_name)"
  echo "  Location: $dest_dir"
}
