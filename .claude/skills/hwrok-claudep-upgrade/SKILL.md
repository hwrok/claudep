---
name: hwrok-claudep-upgrade
description: Upgrade this claudep clone to the latest release and migrate the user's existing claudep setup (templates, profiles) through every release's manual upgrade steps. Use when the user asks to upgrade or update claudep from inside the claudep repo.
argument-hint: "[target tag, e.g. v1.8.0 - defaults to latest release]"
---

# Upgrade claudep (bootstrap)

Don't pull or check anything out first - the upgrade is easier if started from the clone's current version.

1. Find the remote pointing at `hwrok/claudep` (`git remote -v`) and `git fetch <remote> main`.
2. Read the instructions from that ref, not the working tree copy, which may be stale:

   ```bash
   git show <remote>/main:.claude/skills/hwrok-claudep-upgrade/upgrade-instructions.md
   ```

3. No such remote, or the fetch fails? Fetch https://raw.githubusercontent.com/hwrok/claudep/main/.claude/skills/hwrok-claudep-upgrade/upgrade-instructions.md instead.
4. Follow those instructions. Target tag, if the user gave one: `$ARGUMENTS`.
