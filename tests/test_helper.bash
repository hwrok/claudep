bats_require_minimum_version 1.5.0

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  common_setup
}

common_setup() {
  T="$(mktemp -d)"
  export HOME="$T"
  unset XDG_CONFIG_HOME CLAUDE_CONFIG_DIR CLAUDEP_PROFILE

  mkdir -p "$T/bin"
  cat > "$T/bin/claude" <<'EOF'
#!/bin/sh
echo "fake-claude dir=$CLAUDE_CONFIG_DIR profile=$CLAUDEP_PROFILE args=$*"
EOF
  chmod +x "$T/bin/claude"
  export PATH="$T/bin:$PATH"

  P="$T/.claudep/profiles"
  TPL="$T/.claudep/templates"
}

teardown() {
  # some tests chmod dirs read-only
  chmod -R u+w "$T" 2>/dev/null || true
  rm -rf "$T"
}

claudep() {
  "$REPO/claudep.sh" "$@"
}

init_default() {
  claudep init >/dev/null
}
