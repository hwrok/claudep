load test_helper

@test "install symlinks into the target dir" {
  run -0 "$REPO/install.sh" "$T/bin/claudep"
  [ -L "$T/bin/claudep" ]
  [[ "$(readlink "$T/bin/claudep")" == "$REPO/claudep.sh" ]]
}

@test "install fails clearly when the target dir doesn't exist" {
  run -1 "$REPO/install.sh" "$T/nope/claudep"
  [[ "$output" == *"Target directory does not exist"* ]]
}

@test "install warns (not crashes) when the target isn't on PATH" {
  mkdir -p "$T/offpath"
  PATH="/usr/bin:/bin" run -0 "$REPO/install.sh" "$T/offpath/claudep"
  [[ "$output" == *"Add $T/offpath to PATH"* ]]
}

@test "claudep uninstall removes the symlink and optionally the data" {
  "$REPO/install.sh" "$T/bin/claudep" >/dev/null
  init_default

  run -0 claudep uninstall "$T/bin/claudep" <<< n
  [ ! -e "$T/bin/claudep" ]
  [ -d "$T/.claudep" ]

  run -0 claudep uninstall "$T/bin/claudep" <<< y
  [ ! -e "$T/.claudep" ] && [ ! -e "$T/.config/claudep" ]
}

@test "uninstall.sh runs under bash and finds the XDG config" {
  export XDG_CONFIG_HOME="$T/xdg"
  init_default
  run -0 bash "$REPO/uninstall.sh" "$T/none" <<< y
  [[ "$output" == *"Config: $T/xdg/claudep"* ]]
  [ ! -e "$T/xdg/claudep" ]
}
