load test_helper

@test "--help prints usage and exits 0" {
  run -0 claudep --help
  [[ "$output" == Usage:* ]]
  run -0 claudep -h
  [[ "$output" == Usage:* ]]
}

@test "no command prints usage and exits 1" {
  run -1 claudep
  [[ "$output" == Usage:* ]]
}

@test "unknown command prints usage and exits 1" {
  run -1 claudep bogus
  [[ "$output" == Usage:* ]]
}

@test "--version prints a version" {
  run -0 claudep --version
  [[ "$output" == "claudep "* ]]
}

@test "profile, template, and start require init" {
  for args in "profile list" "profile add x" "template list" "start x"; do
    run -1 claudep $args
    [[ "$output" == "Error: claudep not initialized. Run: claudep init" ]]
  done
}

@test "an empty pointer file counts as not initialized" {
  mkdir -p "$T/.config/claudep"
  : > "$T/.config/claudep/path"
  run -1 claudep profile list
  [[ "$output" == *"not initialized"* ]]
}
