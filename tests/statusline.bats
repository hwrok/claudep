load test_helper

# not +x in the repo (init sets that when copying), so run it via bash
STATUSLINE="$BATS_TEST_DIRNAME/../assets/templates/default/statusline/statusline.sh"

setup() {
  common_setup
  if ! command -v jq >/dev/null; then
    skip "jq not installed"
  fi
}

payload() {
  cat <<EOF
{
  "model": { "display_name": "Opus 5.5" },
  "cwd": "/tmp/prøject #1",
  "workspace": { "current_dir": "/tmp/prøject #1" },
  "context_window": $1
}
EOF
}

@test "renders profile, model, context, and dir" {
  run -0 env CLAUDEP_PROFILE="wörk" bash "$STATUSLINE" <<< "$(payload '{
    "context_window_size": 1000000,
    "current_usage": { "input_tokens": 80000, "cache_creation_input_tokens": 2000,
      "cache_read_input_tokens": 3000 }
  }')"
  [[ "$output" == *"claudep:wörk"* ]]
  [[ "$output" == *"Opus 5.5"* ]]
  [[ "$output" == *"ctx: 85/1000k"* ]]
  [[ "$output" == *"prøject #1"* ]]
}

@test "doesn't fail when the context window size is missing" {
  run -0 bash "$STATUSLINE" <<< "$(payload '{
    "current_usage": { "input_tokens": 1, "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0 }
  }')"
}
