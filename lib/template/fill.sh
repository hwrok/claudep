#!/usr/bin/env zsh

# _init_template lives in init.sh
source "$LIB_DIR/init.sh"

cmd_template_fill() {
  local templates_dir
  templates_dir=$(get_templates_dir)

  local -a targets=()

  case "${1:-}" in
    --all) shift; targets=("${(@f)$(cmd_template_names)}") ;;
    ""|-*)
      echo "Error: Template name required" >&2
      echo "Usage: claudep template fill <name> | --all" >&2
      exit 1
      ;;
    *) targets=("$1"); shift ;;
  esac

  if [[ $# -gt 0 ]]; then
    echo "Error: Unknown flag: $1" >&2
    exit 1
  fi

  targets=("${(@)targets:#}")

  if (( ${#targets} == 0 )); then
    echo "No templates found. Run: claudep init" >&2
    exit 1
  fi

  local assets_template="$SCRIPT_DIR/assets/$DEFAULT_TEMPLATE"
  local name template_dir item
  local -a added=()

  for name in "${targets[@]}"; do
    template_dir="$templates_dir/$name"

    if [[ ! -d "$template_dir" ]]; then
      echo "Error: Template not found: $name" >&2
      exit 1
    fi

    # note what's absent before filling, so we can report it afterwards
    added=()
    for item in $(shared_item_paths); do
      [[ -e "$template_dir/$item" ]] || added+=("$item")
    done

    _init_template "missing" "$template_dir" "$assets_template"

    if (( ${#added} == 0 )); then
      echo "  $name: already complete"
    else
      echo "✓ $name: added ${(j:, :)added}"
    fi
  done
}

cmd_template_names() {
  local t
  for t in "$(get_templates_dir)"/*(N); do
    [[ -d "$t" ]] && echo "$(basename "$t")"
  done
}
