# claudep Environment

This environment uses claudep (https://github.com/hwrok/claudep) for Claude Code profile management.

- The active config dir is a claudep profile (`~/.claudep/profiles/<name>/`), not `~/.claude/`
- Shared config (rules, agents, skills, settings, CLAUDE.md) is symlinked from a template (`~/.claudep/templates/<name>/`)
- Editing a symlinked file edits the template, which affects all profiles using it
- Use `claudep profile eject <profile> --items <item>` to make a profile-local copy before diverging
- Unless ejected, assume config files are shared across profiles
- To steer a profile's claude.ai login to one organization, set `forceLoginMethod` and `forceLoginOrgUUID` in that profile's ejected `settings.json`, never in a shared template. From user-level settings this pre-selects the org at login but does not block other orgs
