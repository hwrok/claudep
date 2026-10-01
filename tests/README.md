# Tests

Black-box tests for the claudep CLI, written with [bats-core](https://github.com/bats-core/bats-core).

## Running

```bash
brew install bats-core shellcheck

tests/run              # all phases: syntax, lint, bats
tests/run syntax       # zsh -n on every zsh script, bash -n on the statusline
tests/run lint         # shellcheck - statusline only, shellcheck has no zsh support
tests/run bats         # tests only; extra args go to bats
tests/run bats --filter relink
```

## Isolation

`test_helper.bash` gives every test its own throwaway `HOME` (and unsets `XDG_CONFIG_HOME`, `CLAUDE_CONFIG_DIR`, `CLAUDEP_PROFILE`). A stub `claude` goes first on `PATH` and just echoes the config dir, profile, and args it was started with, so Claude Code is never launched.

Useful variables in tests:

- `$T` - the throwaway HOME
- `$P` - profiles dir
- `$TPL` - templates dir
- `$REPO` - repo root

## Writing tests

- Start each file with `load test_helper`. Use `run -0` / `run -1` to assert exit codes.
- A file that needs more setup (e.g. an initialized install) redefines `setup()` and calls `common_setup` first, then `init_default`.
- Use realistic names where the CLI allows them - unicode, emoji, spaces, `#`, `&` - so quoting regressions show up. Invalid names (`-x`, `..`, `a/b`) belong in rejection tests.
