#!/usr/bin/env zsh

_copy_item() {
  local src="$1" dst="$2"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
    # remove .gitkeep files if present (used to persist empty dirs in git)
    [[ -f "$dst/.gitkeep" ]] && rm "$dst/.gitkeep"
  else
    cp "$src" "$dst"
  fi
}

_copy_settings() {
  local src="$1" dst="$2" template_dir="$3"
  sed "s|<CLAUDEP_BASE_DIR>|$template_dir|g" "$src" > "$dst"
}

_init_template() {
  local mode="$1" template_dir="$2" assets_template="$3"

  local -a items=(agents rules skills statusline CLAUDE.md)

  for item in "${items[@]}"; do
    local src="$assets_template/$item"
    local dst="$template_dir/$item"

    if [[ "$mode" != "refresh" ]] && [[ -e "$dst" || -L "$dst" ]]; then
      continue
    fi

    _copy_item "$src" "$dst"
  done

  # statusline needs +x
  [[ -f "$template_dir/statusline/statusline.sh" ]] && \
    chmod +x "$template_dir/statusline/statusline.sh"

  # settings.json handled separately (template substitution)
  local settings_dst="$template_dir/settings.json"
  if [[ "$mode" == "refresh" || "$mode" == "init" ]] || [[ ! -e "$settings_dst" ]]; then
    _copy_settings "$assets_template/settings.json" "$settings_dst" "$template_dir"
  fi
}

cmd_init() {
  local base_path="$HOME/$CLAUDEP_BASE_DIR_NAME"
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) base_path="$2"; shift 2 ;;
      --force) force=true; shift ;;
      *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  base_path="${base_path/#\~/$HOME}"

  local template_dir="$base_path/$DEFAULT_TEMPLATE"
  local assets_template="$SCRIPT_DIR/assets/$DEFAULT_TEMPLATE"
  local mode="init"

  # check for existing init — only prompt if the actual template dir exists
  if [[ -f "$CONFIG_PATH_FILE" ]]; then
    local existing_path
    existing_path=$(cat "$CONFIG_PATH_FILE")

    if [[ -d "$existing_path/$DEFAULT_TEMPLATE" ]]; then
      if [[ "$existing_path" != "$base_path" ]]; then
        echo "⚠️  Already initialized at: $existing_path"
        echo "   New path requested: $base_path"
      else
        echo "⚠️  Already initialized at: $base_path"
      fi

      if [[ "$force" == true ]]; then
        mode="refresh"
      else
        echo ""
        echo "  1) Refresh — overwrite default template"
        echo "  2) Fill missing — only add files that don't exist"
        echo "  3) Abort"
        echo -n "Choose [1-3]: "
        read -r choice

        case "$choice" in
          1) mode="refresh" ;;
          2) mode="missing" ;;
          *) echo "Aborted."; exit 0 ;;
        esac
      fi
    else
      echo "Config exists but template dir missing — reinitializing..."
    fi
  fi

  mkdir -p "$CONFIG_DIR"
  echo "$base_path" > "$CONFIG_PATH_FILE"

  mkdir -p "$template_dir"
  _init_template "$mode" "$template_dir" "$assets_template"

  local profile_dir
  profile_dir=$(get_profile_dir)
  mkdir -p "$profile_dir"

  echo "✓ Initialized claudep at: $base_path (${mode})"
  echo "  Template: $template_dir"
  echo "  Profiles: $profile_dir"
}
