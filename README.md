# claudep 🎭

**Profile manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).**

**[Why?](#why)** · **[Quick Start](#quick-start)** · **[How It Works](#how-it-works)** · **[Commands](#commands)** · **[Auth](#auth)** · **[Upgrading](#upgrading)** · **[Tips](#tips)** · **[Caveats](#known-caveats)**

- **Last verified against:** Claude Code `2.1.280`
- **Recommended minimum:** Claude Code `2.1.247` - earlier builds had sandbox bugs that could refuse or delete symlinked config

claudep is maintained even if there are not recent commits. It does one small job against a `CLAUDE_CONFIG_DIR` contract that rarely changes, so a long gap between "releases" usually means there's nothing to fix.

## Why?

Claude Code stores everything - auth, history, settings, rules - in a single `~/.claude` directory. Great if you're one person with one life. Less great if you:

- Switch between personal and work accounts
- Use different [auth methods](https://code.claude.com/docs/en/setup#authentication) (OAuth vs AWS Bedrock vs API key)
- Want isolated chat histories per context
- Need different rules/skills/agents per project category
- Are just generally the kind of person who has opinions about config organization 🫠

claudep uses Claude Code's officially supported [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/settings) env var to point at different config directories per profile. Profiles then symlink to shared templates for the common config, so you're not copy-pasting CLAUDE.md files around like an animal.

**This is user-level profile swapping.** Claude Code's settings hierarchy (project `settings.local.json` → project `settings.json` → user config) is fully respected - claudep just swaps which user config directory Claude sees.

Other typical `~/.claude` directories (`cache`, `debug`, `plugins`, `todos`, `history`, etc) are auto-created by Claude Code per profile and stay isolated, so no leakage between profiles. The only things shared are the dirs claudep explicitly manages via symlinks (settings, rules, agents, skills, commands, workflows, output styles, keybindings, statusline, CLAUDE.md). `plugins` stays deliberately per-profile - plugin sources are often private or org-specific, and sharing a plugin cache across profiles invites concurrent-write races. That does mean some light redundancy per profile since caches and plugins get downloaded independently - acceptable tradeoff for now, a more pnpm-style content-addressable symlink approach may come later if it ever becomes painful enough to care about. 📦

### How is this different?

Claude Code has no built-in profile management - Anthropic's [official stance](https://github.com/anthropics/claude-code/issues/261) is that `CLAUDE_CONFIG_DIR` is the answer, and fair enough.

There are a handful of third-party account switchers ([ccs](https://github.com/kaitranntt/ccs), [cc-account-switcher](https://github.com/ming86/cc-account-switcher), [claude-switch](https://github.com/rzkmak/claude-switch), etc) that swap auth credentials between accounts. They solve the "which account am I logged into" problem.

claudep solves a different (though related) problem: **shared config management across profiles.** Rather than duplicating rules, agents, skills, and instructions into every profile directory, claudep symlinks them from templates. Update a template, every linked profile gets the change. Need one profile to diverge? Eject just that item and the rest keeps inheriting. None of the existing tools do this - they're account switchers, not config managers.

That said, claudep _is_ also an account switcher, ie each profile has its own isolated auth state, so switching profiles switches accounts. It just gets there as a side effect of managing entire config directories rather than swapping credentials directly. 🤝

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
      commands/
      workflows/
      output-styles/
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

| Command                                 | Description                                                                                                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `claudep init [--path <dir>] [--force]` | Set up `~/.claudep` (or `--path`) with the default template. Re-running prompts to refresh/fill; `--force` skips the prompt.                           |
| `claudep start <profile> [...]`         | Launch Claude Code with the given profile. Extra args pass through to `claude` (e.g. `--resume`, `-p "..."`). Also aliased as `claudep profile start`. |
| `claudep uninstall`                     | Remove the claudep symlink; optionally wipe all data.                                                                                                  |

### Profiles

A profile is a distinct `CLAUDE_CONFIG_DIR` - isolated auth, history, and todos. Shared config (rules, agents, CLAUDE.md, etc.) is symlinked from a template until ejected.

| Command                                                | Description                                                                  |
| ------------------------------------------------------ | ---------------------------------------------------------------------------- |
| `claudep profile add <name> [--template <src>]`        | Create a profile symlinked to `<src>` (defaults to `default`).               |
| `claudep profile list`                                 | List profiles.                                                               |
| `claudep profile remove <name>`                        | Delete a profile (confirmation required). Templates untouched.               |
| `claudep profile eject <name> --all \| --items <list>` | Convert symlinked items into independent copies.                             |
| `claudep profile relink <name> [--template <src>]`     | Add missing symlinks and repair dangling ones. Ejected items are left alone. |

**Ejectable items:** `agents`, `rules`, `skills`, `commands`, `workflows`, `output-styles`, `statusline`, `keybindings` (keybindings.json), `instructions` (CLAUDE.md), `settings` (settings.json)

```bash
claudep profile add work --template corp
claudep profile eject work --items settings,instructions
```

Eject resolves from wherever the symlink currently points - not hardcoded to `default`. Profiles extending custom templates eject correctly. 👍

### Relink

Claude Code grows new config directories over time, and profiles created before claudep knew about one won't have it symlinked. `relink` backfills:

```bash
claudep profile relink work
```

It only touches what's missing or broken - adds absent symlinks, repoints dangling ones, and leaves ejected items and links to other templates alone. Safe to re-run; a no-op if everything is already in place.

The template comes from the profile's existing symlinks, and only when unambiguous. `relink` refuses and asks for an explicit `--template <src>` if the profile links to more than one template, points at a template that no longer exists, or has been fully ejected.

### Templates

Templates are optional - `default` covers most cases. Useful when you want distinct _categories_ of base config: a `dev` template with coding agents, a `research` template with exploratory skills, a `corp` template with org-blessed settings. Updating a template propagates to every profile linked to it.

| Command                                          | Description                                                                                                               |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `claudep template add <name> [--template <src>]` | Create a template by copying from `<src>` (defaults to `default`). Edit files directly in `~/.claudep/templates/<name>/`. |
| `claudep template list`                          | List templates.                                                                                                           |
| `claudep template remove <name>`                 | Delete a template. Refuses to remove `default` (it's not a democracy 🗳️) or any template still linked by a profile.       |
| `claudep template fill <name> \| --all`          | Add any shared items the template is missing. Only fills gaps - existing files are never touched.                         |

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

## Upgrading

When claudep adds a new config directory to accomadate Claude Code updates, existing installs have to pick it up in two places: the templates, then each profile.

```bash
# git pull if you cloned the claudep repo, otherwise grab the latest release
git pull && ./install.sh

# add new shared items to every template
claudep template fill --all

# backfill the symlinks into each existing profile
claudep profile relink <profile>
```

Both only add what's missing - `fill` never touches an existing file, `relink` leaves ejected items and links to other templates alone. Safe to re-run, and a no-op if you're current.

Order matters: `fill` first. `relink` can only link an item the template has, and will tell you which ones it skipped if run early.

Neither command rewrites an existing `settings.json`, so new default settings never reach an existing template or profile. Add these by hand:

- `"syncClaudeAiSkills": false` - see [Known Caveats](#known-caveats) for why claudep prefers it disabled

> ⚠️ `claudep init --force` is not an upgrade path. That's refresh mode and it overwrites the default template, customizations included.

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

### Keybindings

The shipped `keybindings.json` is deliberately empty - claudep doesn't impose bindings. If you're after the common one (Enter inserts a newline, something else sends), the following works on Claude Code `2.1.280` in macOS Terminal.app:

```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "enter": "chat:newline",
        "option+enter": "chat:submit"
      }
    }
  ]
}
```

- **`enter` → `chat:newline`** - works. Rebinding `enter` in the `Chat` context is supported, contrary to older reports that it was ignored.
- **`option+enter` → `chat:submit`** - works in Terminal.app when _Use Option as Meta_ is set under Settings → Profiles → Keyboard.
- **`shift+enter`** - no binding of its own. With Terminal.app's _Shift Return sends Meta Return_ checked it follows the `option+enter` binding; unchecked, it sends a plain CR and follows `enter`.
- **`cmd+enter`** - doesn't work in Terminal.app, which never sends the Super modifier. Only terminals speaking the Kitty keyboard protocol (Ghostty, Kitty, WezTerm, iTerm2) deliver it.
- **`ctrl+x ctrl+s`** - bound to `chat:sendNow` by default, and documented as working in any terminal. Dependable fallback, and a useful escape hatch while experimenting.

The choice of terminal decides most of this, so results will differ - and submit/newline is a tiny corner of the [available actions](https://code.claude.com/docs/en/keybindings). Try another terminal, or invent your own.

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
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "arn:aws:bedrock:us-east-2:...:application-inference-profile/...",
  },
}
```

**Workflow:**

1. `claudep profile add work-bedrock`
2. `claudep profile eject work-bedrock --items settings`
3. Edit the ejected `settings.json` with your Bedrock/SSO config
4. `claudep start work-bedrock` - AWS auth is scoped to this session only

Personal profile keeps using OAuth (or whatever), work profile uses Bedrock via SSO, neither knows the other exists. No global env vars, no accidents, no "why is this billing to the wrong account" Slack messages at 2am. 🫡

## Known Caveats

- **Nonessential traffic is off by default:** the default template's `env` block sets `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` and `DISABLE_TELEMETRY=1`. Either one alone also turns off Claude Code's feature-flag fetching, which gates a number of features. That set grows and changes release to release, so it isn't enumerated here - Anthropic maintains it under [features that need feature-flag fetching](https://code.claude.com/docs/en/env-vars#features-that-need-feature-flag-fetching). If you want any of it, drop both entries from your template's `env`.
- **JetBrains plugin / `/ide` command:** There's a [known Claude Code issue](https://github.com/anthropics/claude-code/issues/4739) where the `/ide` command and JetBrains plugin use hardcoded paths for lock files, which breaks when `CLAUDE_CONFIG_DIR` is set. This is a Claude Code bug, not a claudep bug. **Workaround:** use Claude Code from the IDE's built-in terminal (`claudep start <profile>`) rather than through the plugin. Works fine - you just don't get the plugin's UI integration.
- **Empty template directories:** Git doesn't track empty directories, so some directories (`agents/`, `rules/`, etc) in the default template use `.gitkeep` files to persist in the repo. These are automatically removed during initialization.
- **claude.ai skill sync is off by default:** Claude Code syncs skills enabled on a claude.ai account into `<config-dir>/skills/synced/` (on by default since 2.1.275). Under claudep that path resolves through the symlink into the _shared_ template, so one profile's hosted-account-level skills land in every profile that shares the same template. The default template ships `"syncClaudeAiSkills": false` for that reason. Turning it back on is a per-template decision rather than a global one: enable it in a template and every profile on that template pools those synced skills, which is what you want for one account across profiles for different purposes, or for two accounts you'd rather share a skill set. Anything that should stay separate goes on its own template, or ejects its `settings`. Plugins need no equivalent - `plugins` is already per-profile.
