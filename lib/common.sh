#!/usr/bin/env zsh

CONFIG_DIR="$HOME/.config/claudep"
CONFIG_PATH_FILE="$CONFIG_DIR/path"

CLAUDEP_BASE_DIR_NAME=".claudep"

DEFAULT_TEMPLATE="templates/default"

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

verify_claude_cli() {
  if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' command not found in PATH" >&2
    echo "  Install Claude Code CLI or ensure it's in your PATH" >&2
    exit 1
  fi
}
