# claudep 🎭

**Profile manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).**

**[Why?](#why)** · **[Quick Start](#quick-start)** · **[How It Works](#how-it-works)** · **[Commands](#commands)** · **[Auth](#auth)** · **[Tips](#tips)** · **[Caveats](#known-caveats)**

## Why?

Claude Code stores everything - auth, history, settings, rules - in a single `~/.claude` directory. Great if you're one person with one life. Less great if you:

- Switch between personal and work accounts
- Use different [auth methods](https://code.claude.com/docs/en/setup#authentication) (OAuth vs AWS Bedrock vs API key)
- Want isolated chat histories per context
- Need different rules/skills/agents per project category
- Are just generally the kind of person who has opinions about config organization 🫠

claudep uses Claude Code's officially supported [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/settings) env var to point at different config directories per profile. Profiles then symlink to shared templates for the common config, so you're not copy-pasting CLAUDE.md files around like an animal.

**This is user-level profile swapping.** Claude Code's settings hierarchy (project `settings.local.json` → project `settings.json` → user config) is fully respected - claudep just swaps which user config directory Claude sees.

Other typical `~/.claude` directories (`cache`, `debug`, `plugins`, `todos`, `history`, etc) are auto-created by Claude Code per profile and stay isolated, so no leakage between profiles. The only things shared are the dirs claudep explicitly manages via symlinks (settings, rules, agents, skills, statusline, CLAUDE.md). That does mean some light redundancy per profile since caches and plugins get downloaded independently - acceptable tradeoff for now, a more pnpm-style content-addressable symlink approach may come later if it ever becomes painful enough to care about. 📦

### How is this different?

Claude Code has no built-in profile management - Anthropic's [official stance](https://github.com/anthropics/claude-code/issues/261) is that `CLAUDE_CONFIG_DIR` is the answer, and fair enough.

There are a handful of third-party account switchers ([ccs](https://github.com/kaitranntt/ccs), [cc-account-switcher](https://github.com/ming86/cc-account-switcher), [claude-switch](https://github.com/rzkmak/claude-switch), etc) that swap auth credentials between accounts. They solve the "which account am I logged into" problem.

claudep solves a different (though related) problem: **shared config management across profiles.** Rather than duplicating rules, agents, skills, and instructions into every profile directory, claudep symlinks them from templates. Update a template, every linked profile gets the change. Need one profile to diverge? Eject just that item and the rest keeps inheriting. None of the existing tools do this - they're account switchers, not config managers.

That said, claudep *is* also an account switcher, ie each profile has its own isolated auth state, so switching profiles switches accounts. It just gets there as a side effect of managing entire config directories rather than swapping credentials directly. 🤝

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

Template inheritance, minus the inheritance. One level of symlinks, no magic. ✨

## Commands

### Top-level

| Command | Description |
|---|---|
| `claudep init [--path <dir>] [--force]` | Set up `~/.claudep` (or `--path`) with the default template. Re-running prompts to refresh/fill; `--force` skips the prompt. |
| `claudep start <profile> [...]` | Launch Claude Code with the given profile. Extra args pass through to `claude` (e.g. `--resume`, `-p "..."`). Also aliased as `claudep profile start`. |
| `claudep uninstall` | Remove the claudep symlink; optionally wipe all data. |

### Profiles

A profile is a distinct `CLAUDE_CONFIG_DIR` - isolated auth, history, and todos. Shared config (rules, agents, CLAUDE.md, etc.) is symlinked from a template until ejected.

| Command | Description |
|---|---|
| `claudep profile add <name> [--template <src>]` | Create a profile symlinked to `<src>` (defaults to `default`). |
| `claudep profile list` | List profiles. |
| `claudep profile remove <name>` | Delete a profile (confirmation required). Templates untouched. |
| `claudep profile eject <name> --all \| --items <list>` | Convert symlinked items into independent copies. |

**Ejectable items:** `agents`, `rules`, `skills`, `statusline`, `instructions` (CLAUDE.md), `settings` (settings.json)

```bash
claudep profile add work --template corp
claudep profile eject work --items settings,instructions
```

Eject resolves from wherever the symlink currently points - not hardcoded to `default`. Profiles extending custom templates eject correctly. 👍

### Templates

Templates are optional - `default` covers most cases. Useful when you want distinct *categories* of base config: a `dev` template with coding agents, a `research` template with exploratory skills, a `corp` template with org-blessed settings. Updating a template propagates to every profile linked to it.

| Command | Description |
|---|---|
| `claudep template add <name> [--template <src>]` | Create a template by copying from `<src>` (defaults to `default`). Edit files directly in `~/.claudep/templates/<name>/`. |
| `claudep template list` | List templates. |
| `claudep template remove <name>` | Delete a template. Refuses to remove `default` (it's not a democracy 🗳️) or any template still linked by a profile. |

## Auth

For standard Claude auth there's no claudep-specific step - `claudep start <profile>` and log in as you normally would on first run. Credentials are cached inside the profile's config dir, so:

- Each profile keeps its own independent login
- Auth persists across `/exit` and future `claudep start` runs
- You can use multiple profiles simultaneously in different terminal sessions (e.g. `claudep start work` in one tab, `claudep start personal` in another) without logging in and out
- Switching accounts = switching profiles

For Bedrock, API key, or other non-OAuth setups, eject the profile's `settings` and configure env vars there - see [Auth Configurations](#auth-configurations) below.

## Installation

**Requirements:** zsh, jq (for statusline only)

```bash
# clone/download, then:
chmod +x ./install.sh

./install.sh # may require sudo

# custom install location
./install.sh /path/to/bin/claudep
```

The installer creates a symlink - the actual scripts stay wherever you cloned them.

## Statusline

claudep includes a statusline script that displays the active profile and context window usage in Claude Code's status bar.

```
[claudep:personal | ctx: 84/200k | <current-dir>]
```

This is configured automatically via the template's `settings.json`. Uses `jq` to parse the context metrics Claude Code pipes to stdin. If you don't have `jq`, the statusline just won't work - everything else is fine.

## Eject Workflow

The typical lifecycle:

1. `claudep profile add work` - fresh profile, fully symlinked to template
2. Use it for a while, realize you need different settings for this profile
3. `claudep profile eject work --items settings` - settings.json is now an independent copy
4. Edit `~/.claudep/profiles/work/settings.json` directly
5. Everything else still inherits from the template

You can eject individual items incrementally. No need to go all-or-nothing unless you want to.

## Tips

### Customization

- **Do:** Edit template files directly in `~/.claudep/templates/<name>/`. Changes propagate to all profiles linked to that template.
- **Do:** Edit ejected files directly in `~/.claudep/profiles/<name>/`. They're independent copies - no side effects.
- **Don't:** Edit a profile's symlinked files. The symlink points back to the template, so you're actually editing the template - which silently affects every other profile using it. If you need a profile-specific change, `claudep profile eject` the item first.

The default template ships a `rules/_claudep.md` rule file that gives Claude ambient awareness of the claudep environment - config directory layout, symlink behavior, and the eject workflow.

### Auth Configurations

One of the more compelling reasons to use profiles: **per-profile AWS auth without polluting your global shell environment.**

The [Claude Code docs](https://code.claude.com/docs/en/amazon-bedrock#claude-code-on-amazon-bedrock) suggest exporting `AWS_PROFILE` and friends in your `.zshrc`, which works right up until you accidentally run a Bedrock request against the wrong account because you forgot which profile was exported globally. 🙃

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
4. `claudep start work-bedrock` - AWS auth is scoped to this session only

Personal profile keeps using OAuth (or whatever), work profile uses Bedrock via SSO, neither knows the other exists. No global env vars, no accidents, no "why is this billing to the wrong account" Slack messages at 2am. 🫡

## Known Caveats

- **JetBrains plugin / `/ide` command:** There's a [known Claude Code issue](https://github.com/anthropics/claude-code/issues/4739) where the `/ide` command and JetBrains plugin use hardcoded paths for lock files, which breaks when `CLAUDE_CONFIG_DIR` is set. This is a Claude Code bug, not a claudep bug. **Workaround:** use Claude Code from the IDE's built-in terminal (`claudep start <profile>`) rather than through the plugin. Works fine - you just don't get the plugin's UI integration.
- **Empty template directories:** Git doesn't track empty directories, so some directories (`agents/`, `rules/`, etc) in the default template use `.gitkeep` files to persist in the repo. These are automatically removed during initialization.
- **`keybindings.json` enter key:** There's a [known Claude Code bug](https://github.com/anthropics/claude-code/issues/25087) where `keybindings.json` is ignored for the `enter` key - setting `"enter": null` to unbind submit has no effect. Not a `claudep` issue.
