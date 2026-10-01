load test_helper

setup() {
  common_setup
  init_default
}

NAME="dév ✨ #2"

@test "add copies from default or another template" {
  echo "custom 🛠️" > "$TPL/default/CLAUDE.md"
  run -0 claudep template add "$NAME"
  [[ "$(cat "$TPL/$NAME/CLAUDE.md")" == "custom 🛠️" ]]
  run -0 claudep template add second --template "$NAME"
  [ -d "$TPL/second" ]
  run -0 claudep template list
  [[ "$output" == *"$NAME"* && "$output" == *second* ]]
}

@test "add rejects invalid names and missing values" {
  for bad in "-h" ".x" "a/b"; do
    run -1 claudep template add "$bad"
  done
  run -1 claudep template add t --template
  [[ "$output" == "Error: --template requires a value" ]]
}

@test "remove refuses default and linked templates" {
  run -1 claudep template remove default
  claudep template add t >/dev/null
  claudep profile add p --template t >/dev/null
  run -1 claudep template remove t <<< y
  [[ "$output" == *"linked to this template"* ]]
  [ -d "$TPL/t" ]
}

@test "remove isn't blocked by a template that shares a name prefix" {
  claudep template add dev >/dev/null
  claudep template add dev2 >/dev/null
  claudep profile add p --template dev2 >/dev/null
  run -0 claudep template remove dev <<< y
  [ ! -e "$TPL/dev" ]
  run -1 claudep template remove dev2 <<< y
}

@test "fill adds missing top-level items and leaves existing ones" {
  claudep template add t >/dev/null
  rm -rf "$TPL/t/workflows"
  echo "keep me" > "$TPL/t/CLAUDE.md"
  run -0 claudep template fill t
  [ -d "$TPL/t/workflows" ]
  [[ "$(cat "$TPL/t/CLAUDE.md")" == "keep me" ]]
}

@test "fill --all covers every template" {
  claudep template add a >/dev/null
  claudep template add b >/dev/null
  rm -rf "$TPL/a/commands" "$TPL/b/output-styles"
  run -0 claudep template fill --all
  [ -d "$TPL/a/commands" ] && [ -d "$TPL/b/output-styles" ]
}
