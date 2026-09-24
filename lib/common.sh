#!/usr/bin/env zsh

CONFIG_DIR="$HOME/.config/claudep"
CONFIG_PATH_FILE="$CONFIG_DIR/path"

CLAUDEP_BASE_DIR_NAME=".claudep"

DEFAULT_TEMPLATE="templates/default"

# canonical list of items a profile shares from its template
# format: <eject-key>:<path relative to template/profile root>
# TODO: kr -> keybindings:enter - https://github.com/anthropics/claude-code/issues/25087
CLAUDEP_SHARED_ITEMS=(
  "agents:agents"
  "rules:rules"
  "skills:skills"
  "commands:commands"
  "workflows:workflows"
  "output-styles:output-styles"
  "statusline:statusline"
  "instructions:CLAUDE.md"
  "keybindings:keybindings.json"
  "settings:settings.json"
)

# paths only, in declaration order
shared_item_paths() {
  local entry
  for entry in "${CLAUDEP_SHARED_ITEMS[@]}"; do
    echo "${entry##*:}"
  done
}

get_base_path() {
  if [[ ! -f "$CONFIG_PATH_FILE" ]]; then
    echo "Error: claudep not initialized. Run: claudep init" >&2
    exit 1
  fi
  cat "$CONFIG_PATH_FILE"
}

get_templates_dir() {
  echo "$(get_base_path)/templates"
}

get_default_template_dir() {
  echo "$(get_base_path)/$DEFAULT_TEMPLATE"
}

get_profile_dir() {
  echo "$(get_base_path)/profiles"
}
