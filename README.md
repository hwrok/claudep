# claudep 🎭

**Profile manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).**

**[Why?](#why)** · **[Quick Start](#quick-start)** · **[How It Works](#how-it-works)** · **[Commands](#commands)** · **[Tips](#tips)** · **[Caveats](#known-caveats)**

## Why?

Claude Code stores everything — auth, history, settings, rules — in a single `~/.claude` directory. Great if you're one person with one life. Less great if you:

- Switch between personal and work accounts
- Use different [auth methods](https://code.claude.com/docs/en/setup#authentication) (OAuth vs AWS Bedrock vs API key)
- Want isolated chat histories per context
- Need different rules/skills/agents per project category
- Are just generally the kind of person who has opinions about config organization 🫠

claudep leverages Claude Code's officially supported [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/settings) env var to point at different config directories per profile. Profiles symlink to shared templates for common config, so you're not copy-pasting CLAUDE.md files around like an animal.

**This is user-level profile swapping.** Claude Code's settings hierarchy (project `settings.local.json` → project `settings.json` → user config) is fully respected — claudep just swaps which user config directory Claude sees.

Other typical `~/.claude` directories like `cache`, `debug`, `plugins`, `todos`, and `history` are auto-created by Claude Code per profile and stay fully isolated — no leakage between profiles. The only things shared are the dirs claudep explicitly manages via symlinks (settings, rules, agents, skills, statusline, CLAUDE.md). This does mean some light redundancy per profile as caches and plugins are downloaded independently. An acceptable tradeoff for now — a more pnpm-style content-addressable symlink approach may come later if it becomes painful. 📦

### How is this different?

Claude Code has no built-in profile management — Anthropic's [official stance](https://github.com/anthropics/claude-code/issues/261) is that `CLAUDE_CONFIG_DIR` is the answer. Fair enough.

There are a handful of third-party account switchers ([ccs](https://github.com/kaitranntt/ccs), [cc-account-switcher](https://github.com/ming86/cc-account-switcher), [claude-switch](https://github.com/rzkmak/claude-switch), etc.) that swap auth credentials between accounts. They solve the "which account am I logged into" problem.

claudep solves a different problem: **shared config management across profiles.** Rather than duplicating your rules, agents, skills, and instructions into every profile directory, claudep symlinks them from templates. Update a template, every linked profile gets the change. Need one profile to diverge? Eject just that item. The rest keeps inheriting. None of the existing tools do this — they're account switchers, not config managers.

That said, claudep *is* also an account switcher — each profile has its own isolated auth state, so switching profiles switches accounts. It just gets there as a side effect of managing entire config directories rather than swapping credentials directly. 🤝

## Quick Start

```bash
chmod +x ./install.sh

# install (creates symlink to /usr/local/bin/claudep) (may require sudo) (run once)
./install.sh

# initialize (~/.claudep with default template) (run once)
claudep init

# create a profile
claudep profile add personal

# launch claude with that profile
claudep start personal
```

That's it. You now have a `personal` profile that symlinks to the default template. Claude Code sees it as its config directory.

## How It Works

```
~/.claudep/
  templates/
    default/              ← shared config (rules, agents, skills, etc.)
      agents/
      rules/
      skills/
      statusline/
      CLAUDE.md
      settings.json
  profiles/
    personal/             ← symlinks → templates/default/*
    work/                 ← symlinks → templates/default/*
```

- **Templates** hold shared config. Every profile symlinks to a template.
- **Profiles** are what Claude Code actually runs against (`CLAUDE_CONFIG_DIR` points here).
- **Eject** breaks individual symlinks into independent copies when a profile needs to diverge.

Think of it as template inheritance, minus the inheritance. One level of symlinks. No magic. ✨

## Commands

### `claudep init`

Sets up claudep's directory structure and default template.

```bash
claudep init                   # defaults to ~/.claudep
claudep init --path ~/my-dir   # custom location
claudep init --force           # re-init, overwrite template (no prompt)
```

Re-running `init` on an existing install prompts you to refresh or fill missing files.

### `claudep start <profile> [...]`

Launch Claude Code with the given profile. Any additional args are passed through to `claude`.

```bash
claudep start work
claudep start work --resume
claudep start work -p "fix the tests"
```

Also available as `claudep profile start <profile>` if you enjoy typing.

---

### Profile Commands

Profiles represent distinct Claude Code environments — different accounts, auth methods, or project contexts. Each profile is its own `CLAUDE_CONFIG_DIR` with isolated history, auth state, and todos. Shared config (rules, agents, etc.) is symlinked from a template until you eject it.

#### `claudep profile add <name> [--template <name>]`

Create a new profile. Symlinks to the default template unless `--template` is specified.

```bash
claudep profile add personal
claudep profile add work --template corp
```

#### `claudep profile list`

List available profiles.

#### `claudep profile remove <name>`

Delete a profile (with confirmation). Just removes the profile directory — templates are untouched.

#### `claudep profile eject <name> --all | --items <list>`

Convert symlinked items to independent copies. For when a profile needs its own version of something.

```bash
# eject everything
claudep profile eject work --all

# eject specific items
claudep profile eject work --items settings,instructions
```

**Ejectable items:** `agents`, `rules`, `skills`, `statusline`, `instructions` (CLAUDE.md), `settings` (settings.json)

Eject resolves from wherever the symlink currently points — not hardcoded to default. So profiles extending custom templates eject correctly. 👍

---

### Template Commands

Templates are optional if you only need one shared config — `default` is created by `init` and most users never need another. They become useful when you want different base configurations for *categories* of work: a `dev` template with coding-focused agents and strict rules, a `research` template with exploratory skills, a `corp` template with your org's blessed settings. Profiles extend a template, so updating the template propagates to all linked profiles.

#### `claudep template add <name> [--template <source>]`

Create a new template by copying from an existing one (defaults to `default`).

```bash
claudep template add corp
claudep template add research --template dev
```

After creation, edit the template's files directly in `~/.claudep/templates/<name>/`.

#### `claudep template list`

List available templates.

#### `claudep template remove <name>`

Delete a template. Refuses to remove `default` (it's not a democracy 🗳️). Also refuses if any profiles are still linked to it — eject or remove them first.

---

### `claudep uninstall`

Removes the claudep symlink and optionally cleans up all data.

## Installation

**Requirements:** zsh, jq (for statusline only)

```bash
# clone/download, then:
chmod +x ./install.sh

./install.sh # may require sudo

# custom install location
./install.sh /path/to/bin/claudep
```

The installer creates a symlink — the actual scripts stay wherever you cloned them.

## Statusline

claudep includes a statusline script that displays the active profile and context window usage in Claude Code's status bar.

```
[claudep:personal | ctx: 84/200k | <current-dir>]
```

This is configured automatically via the template's `settings.json`. Uses `jq` to parse the context metrics Claude Code pipes to stdin. If you don't have `jq`, the statusline just won't work — everything else is fine.

## Eject Workflow

The typical lifecycle:

1. `claudep profile add work` — fresh profile, fully symlinked to template
2. Use it for a while, realize you need different settings for this profile
3. `claudep profile eject work --items settings` — settings.json is now an independent copy
4. Edit `~/.claudep/profiles/work/settings.json` directly
5. Everything else still inherits from the template

You can eject individual items incrementally. No need to go all-or-nothing unless you want to.

## Tips

### Customization

- **Do:** Edit template files directly in `~/.claudep/templates/<name>/`. Changes propagate to all profiles linked to that template.
- **Do:** Edit ejected files directly in `~/.claudep/profiles/<name>/`. They're independent copies — no side effects.
- **Don't:** Edit a profile's symlinked files. The symlink points back to the template, so you're actually editing the template — which silently affects every other profile using it. If you need a profile-specific change, `claudep profile eject` the item first.

### Auth Configurations

One of the more compelling reasons to use profiles: **per-profile AWS auth without polluting your global shell environment.**

The [Claude Code docs](https://code.claude.com/docs/en/amazon-bedrock#claude-code-on-amazon-bedrock) suggest exporting `AWS_PROFILE` and friends in your `.zshrc`. This works right up until you accidentally run a Bedrock request against your personal account because you forgot which profile was exported globally. 🙃

With claudep, each profile's `settings.json` scopes the env vars to that Claude session:

```jsonc
{
  // in ~/.claudep/profiles/work-bedrock/settings.json (after eject)
  "awsAuthRefresh": "aws sso login --profile my-corp-sso",
  "env": {
    "AWS_PROFILE": "my-corp-sso",
    "AWS_REGION": "us-east-2",
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "ANTHROPIC_MODEL": "sonnet",
    // models may ref arns, us.anthropic, etc -> check with your org for which to use
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "arn:aws:bedrock:us-east-2:...:application-inference-profile/...",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "arn:aws:bedrock:us-east-2:...:application-inference-profile/...",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "arn:aws:bedrock:us-east-2:...:application-inference-profile/..."
  }
}
```

**Workflow:**

1. `claudep profile add work-bedrock`
2. `claudep profile eject work-bedrock --items settings`
3. Edit the ejected `settings.json` with your Bedrock/SSO config
4. `claudep start work-bedrock` — AWS auth is scoped to this session only

Your personal profile keeps using OAuth (or whatever), your work profile uses Bedrock via SSO, and neither knows the other exists. No global env vars. No accidents. No "why is this billing to the wrong account" Slack messages at 2am. 🫡

## Known Caveats

- **JetBrains plugin / `/ide` command:** There's a [known Claude Code issue](https://github.com/anthropics/claude-code/issues/4739) where the `/ide` command and JetBrains plugin use hardcoded paths for lock files, which breaks when `CLAUDE_CONFIG_DIR` is set. This is a Claude Code bug, not a claudep bug. **Workaround:** use Claude Code from the IDE's built-in terminal (`claudep start <profile>`) rather than through the plugin. Works fine — you just don't get the plugin's UI integration.
- **Empty template directories:** Git doesn't track empty directories, so some directories (`agents/`, `rules/`, etc) in the default template use `.gitkeep` files to persist in the repo. These are automatically removed during initialization.
