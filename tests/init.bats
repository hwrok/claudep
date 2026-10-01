load test_helper

@test "init creates the default template with every shared item" {
  run -0 claudep init
  [[ "$(cat "$T/.config/claudep/path")" == "$T/.claudep" ]]
  for item in agents rules skills commands workflows output-styles statusline CLAUDE.md \
    keybindings.json settings.json; do
    [ -e "$TPL/default/$item" ]
  done
  [ -x "$TPL/default/statusline/statusline.sh" ]
  [ -z "$(find "$TPL/default" -name .gitkeep)" ]
  [ -d "$P" ]
}

@test "init --path with a relative path saves it absolute" {
  cd "$T"
  run -0 claudep init --path "rel dir/claudep #1"
  # macOS: /var -> /private/var, and the saved path is the physical one
  [[ "$(cat "$T/.config/claudep/path")" == "$(pwd -P)/rel dir/claudep #1" ]]
  cd /
  run -0 claudep profile list
}

@test "init --path requires a value" {
  run -1 claudep init --path
  [[ "$output" == "Error: --path requires a value" ]]
}

@test "re-running init and aborting changes nothing" {
  init_default
  run -0 claudep init --path "$T/other" <<< 3
  [[ "$output" == *"no longer managed by claudep"* ]]
  [[ "$output" == *"Aborted."* ]]
  [[ "$(cat "$T/.config/claudep/path")" == "$T/.claudep" ]]
}

@test "init refresh resets shared items; fill keeps them" {
  init_default
  echo "my edits ✏️" > "$TPL/default/CLAUDE.md"
  rm -rf "$TPL/default/workflows"

  run -0 claudep init <<< 2
  [[ "$(cat "$TPL/default/CLAUDE.md")" == "my edits ✏️" ]]
  [ -d "$TPL/default/workflows" ]

  run -0 claudep init <<< 1
  [[ "$(cat "$TPL/default/CLAUDE.md")" != "my edits ✏️" ]]
}

@test "XDG_CONFIG_HOME (absolute) holds the pointer file" {
  export XDG_CONFIG_HOME="$T/xdg"
  run -0 claudep init
  [ -s "$T/xdg/claudep/path" ]
  [ ! -e "$T/.config/claudep" ]
  run -0 claudep profile list
}

@test "relative XDG_CONFIG_HOME is ignored" {
  cd "$T"
  export XDG_CONFIG_HOME="xdg"
  run -0 claudep init
  [ -s "$T/.config/claudep/path" ]
  [ ! -e "$T/xdg" ]
}

@test "legacy ~/.config/claudep is still read when XDG_CONFIG_HOME is set" {
  init_default
  claudep profile add legacy >/dev/null
  export XDG_CONFIG_HOME="$T/xdg"
  mkdir -p "$T/xdg/claudep"
  : > "$T/xdg/claudep/path"
  run -0 claudep profile list
  [[ "$output" == *legacy* ]]
}
