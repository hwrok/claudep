load test_helper

setup() {
  common_setup
  init_default
}

NAME="wörk 👨‍👩‍👧‍👦 #1 & co"

@test "add, list, and start a profile with special characters in the name" {
  run -0 claudep profile add "$NAME"
  for item in agents rules skills commands workflows output-styles statusline CLAUDE.md \
    keybindings.json settings.json; do
    [ -L "$P/$NAME/$item" ]
    [[ "$(readlink "$P/$NAME/$item")" == "$TPL/default/$item" ]]
  done

  run -0 claudep profile list
  [[ "$output" == *"$NAME"*default* ]]

  run -0 claudep start "$NAME" --resume "a b"
  [[ "$output" == "fake-claude dir=$P/$NAME profile=$NAME args=--resume a b" ]]
}

@test "add rejects invalid names and creates nothing" {
  for bad in "-x" "--help" ".hidden" ".." "a/b" 'a\b'; do
    run -1 claudep profile add "$bad"
    [[ "$output" == Error:* ]]
  done
  [ -z "$(ls -A "$P")" ]
}

@test "add requires a --template value and an existing template" {
  run -1 claudep profile add p --template
  [[ "$output" == "Error: --template requires a value" ]]
  run -1 claudep profile add p --template nope
  [[ "$output" == *"Template not found"* ]]
  [ ! -e "$P/p" ]
}

@test "start and remove reject traversal" {
  run -1 claudep start ..
  run -1 claudep profile remove ..
  [ -d "$T/.claudep/templates/default" ]
}

@test "remove deletes after confirmation, keeps on no" {
  claudep profile add p >/dev/null
  run -0 claudep profile remove p <<< n
  [ -d "$P/p" ]
  run -0 claudep profile remove p <<< y
  [ ! -e "$P/p" ]
  [ -d "$TPL/default" ]
}

@test "eject copies items, tolerates spaces and stray commas, keeps statusline executable" {
  claudep profile add p >/dev/null
  run -0 claudep profile eject p --items " settings, statusline,,"
  [ -f "$P/p/settings.json" ] && [ ! -L "$P/p/settings.json" ]
  [ -d "$P/p/statusline" ] && [ ! -L "$P/p/statusline" ]
  [ -x "$P/p/statusline/statusline.sh" ]
  [[ "$output" != *"Unknown item"* ]]

  run -0 claudep profile list
  [[ "$output" == *"ejected: statusline, settings"* ]]
}

@test "eject --all shows as ejected: all" {
  claudep profile add p >/dev/null
  run -0 claudep profile eject p --all
  run -0 claudep profile list
  [[ "$output" == *"ejected: all"* ]]
}

@test "eject skips a dangling link instead of deleting it" {
  claudep template add t >/dev/null
  claudep profile add p --template t >/dev/null
  rm -rf "$TPL/t/rules"
  run -0 claudep profile eject p --items rules
  [[ "$output" == *"template source missing"* ]]
  [[ "$output" != *"independent copies"* ]]
  [ -L "$P/p/rules" ]
}

@test "eject requires --items value" {
  claudep profile add p >/dev/null
  run -1 claudep profile eject p --items
  run -1 claudep profile eject p --items=
}

@test "relink backfills missing items and repairs dangling ones" {
  claudep template add t >/dev/null
  claudep profile add p --template t >/dev/null
  rm "$P/p/workflows"
  rm "$P/p/rules" && ln -s "$TPL/gone/rules" "$P/p/rules"

  run -1 claudep profile relink p
  [[ "$output" == *"no longer exist"* ]]

  run -0 claudep profile relink p --template t
  [[ "$output" == *"Linked: workflows"* ]]
  [[ "$output" == *"Repaired: rules"* ]]
  [[ "$(readlink "$P/p/rules")" == "$TPL/t/rules" ]]
}

@test "relink refuses a profile linked to two templates" {
  claudep template add t >/dev/null
  claudep profile add p >/dev/null
  rm "$P/p/rules" && ln -s "$TPL/t/rules" "$P/p/rules"
  run -1 claudep profile relink p
  [[ "$output" == *"more than one template"* ]]
}

@test "relink --all relinks what it can, reports the rest, exits 1" {
  claudep template add t >/dev/null
  claudep profile add ok >/dev/null
  claudep profile add mixed >/dev/null
  rm "$P/ok/commands"
  rm "$P/mixed/rules" && ln -s "$TPL/t/rules" "$P/mixed/rules"

  run -1 claudep profile relink --all
  [[ "$output" == *"Linked: commands"* ]]
  [[ "$output" == *"Not relinked: mixed - see errors above"* ]]
  [ -L "$P/ok/commands" ]
}

@test "relink --all rejects other flags" {
  run -1 claudep profile relink --all --template default
  [[ "$output" == *"can't be combined"* ]]
}

@test "relink --all handles a profile literally named --all without recursing" {
  claudep profile add p >/dev/null
  cp -a "$P/p" "$P/--all"
  run -0 claudep profile relink --all
  [ "$(grep -c '^== ' <<< "$output")" -eq 2 ]
}

@test "symlinked profile dirs are listed and relinked" {
  claudep profile add p >/dev/null
  mv "$P/p" "$T/elsewhere"
  ln -s "$T/elsewhere" "$P/p"
  run -0 claudep profile list
  [[ "$output" == *"p   default"* ]]
  run -0 claudep profile relink --all
  [[ "$output" == *"== p"* ]]
}

@test "hand-made relative links resolve from the profile dir" {
  claudep profile add p >/dev/null
  rm "$P/p/agents" && ln -s ../../templates/default/agents "$P/p/agents"
  cd /
  run -0 claudep profile list
  [[ "$output" != *"(missing)"* ]]
  run -0 claudep profile relink p
  [[ "$output" == *"0 left alone"* ]]
  run -0 claudep profile eject p --items agents
  [ -d "$P/p/agents" ] && [ ! -L "$P/p/agents" ]
}

@test "profiles with a leading dash from older versions still work" {
  claudep profile add legacy >/dev/null
  mv "$P/legacy" "$P/-legacy"
  run -0 claudep start -legacy
  [[ "$output" == *"profile=-legacy"* ]]
  run -0 claudep profile relink -legacy
  run -0 claudep profile eject -legacy --items rules
  run -0 claudep profile remove -legacy <<< y
  [ ! -e "$P/-legacy" ]
}

@test "list shows dangling, missing, and deleted templates" {
  claudep template add t >/dev/null
  claudep template add gone >/dev/null
  claudep profile add a --template t >/dev/null
  claudep profile add b --template gone >/dev/null
  rm -rf "$TPL/t/workflows" "$TPL/gone"
  rm "$P/a/commands"
  run -0 claudep profile list
  [[ "$output" == *"dangling: workflows; missing: commands"* ]]
  [[ "$output" == *"gone (missing)"* ]]
}
