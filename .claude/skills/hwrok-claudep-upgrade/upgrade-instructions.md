# Upgrade claudep

Bring this clone from the commit it's on to a newer release, then apply every "Upgrading an existing install" step from the release notes in between to the user's claudep data.

Ground rules:

- Never run `claudep init --force`, or pick "Refresh" in `claudep init`. Both reset the default template to the shipped files and wipe customizations.
- Templates are shared: editing `templates/<name>/settings.json` changes every profile linked to it. This is intentional, don't belabor the point. Ejected items are real files in the profile. A release step aimed at "your template" also covers ejected copies of that item unless the release exempts them - show each copy's current value and ask.

## 1. Preflight

- Confirm you're in a claudep clone (`claudep.sh` exists) and find the remote pointing at `hwrok/claudep` - `<remote>` below. No such remote (e.g. a fork)? Ask which one holds releases.
- `git describe --tags --always --dirty` and `git rev-parse HEAD` - the starting version. Record both before anything moves HEAD.
- `readlink -f "$(command -v claudep)"` should resolve to this clone's `claudep.sh`. If it points at another clone, stop and tell the user.

Stop and ask if:

- `git status --porcelain` shows a dirty tree. Offer to stash, commit on a branch, or abort.
- The branch isn't `main`. Ask whether to move to `main` or check out the target tag.
- HEAD has commits not on `<remote>/main` (`git log <remote>/main..HEAD --oneline`).

## 2. Find the version range

```bash
git fetch --tags <remote>
```

- Target: the tag the user asked for, else the latest release - `gh release view --repo hwrok/claudep --json tagName -q .tagName`. Without `gh`, fetch https://github.com/hwrok/claudep/releases.
- Start: `git describe --tags --abbrev=0`.
- If HEAD is at or past the target (`git describe` shows `<target>` or `<target>-N-g<sha>`), the user probably pulled first. Find the pre-pull commit in `git reflog` and confirm the starting version with the user - the upgrade steps still need to run. Can't pin it? Ask.
- Nothing between the confirmed start and target? Say so and stop.
- If `<remote>/main` is ahead of the target, run `git diff --stat <target>..<remote>/main -- assets lib install.sh claudep.sh` and mention anything it shows - pulling `main` lands there.

## 3. Read every release in the range

For each tag after start, up to and including target, oldest first:

```bash
gh release view <tag> --repo hwrok/claudep --json body -q .body
```

From each, pull out:

- `### Upgrading an existing install` - the manual steps.
- Changed defaults that touch template content (e.g. a new `settings.json` key). `init` and `template fill` never rewrite existing files, so these only reach existing installs by hand.
- Breaking or behavior changes worth telling the user about.

Cross-check against the code. Extract the shipped default template at both the start and target versions (step 4 uses these too):

```bash
git archive <ref> assets/templates/default | tar -x -C "$(mktemp -d)"
git diff <start>..<target> -- assets/templates/default install.sh
```

- Template file changes = content the user may want to merge, including changes no release note mentions.
- Top-level entries differ between the two extracts (`ls -A`) = shared items added, renamed, or removed. New ones need `template fill` + `profile relink`; renamed or removed ones need care with existing links.
- `install.sh` changes = may need a re-run.

Plan with the commands the target version ships (`git show <target>:claudep.sh`), not the ones checked out now.

## 4. Inventory the user's setup

Read-only. Don't open `.claude.json`, `.credentials.json`, or history.

- Base path: contents of `$XDG_CONFIG_HOME/claudep/path`, falling back to `~/.config/claudep/path`.
- `claudep template list` and `claudep profile list`.
- Ejected items: shared items under `<base>/profiles/<name>/` that aren't symlinks (`[ ! -L ]`). Older `profile list` doesn't show them.
- Note templates no profile links to, and items every linked profile has ejected - changes there only affect new profiles.
- For each file a step touches, in each template and ejected copy, classify it against the start and target extracts:
  - **already applied** - matches target (the key already has the target value, or the file matches target stock). Skip it.
  - **stock** - matches start stock. Safe to update.
  - **behind** - matches neither, but every difference from target is something the start->target diff changed. No local edits; safe to update.
  - **customized** - has edits of the user's own. Conflict, ask.
- Compare `settings.json` by key with `jq`, never as text - key order and formatting don't count. Older versions rewrote `statusLine.command` to an absolute path under the base dir (template or profile); treat any such path as stock.
- Ignore `.gitkeep` and user-added rules/skills/agents.

## 5. Present the plan, then ask

Show one plan, ordered as it'll run. For each step:

- What runs or changes, and on which paths (template, profiles, ejected copies).
- Which release asked for it, or "unannounced" if only the diff shows it.
- A tag: **safe** (additive, idempotent, or updating a stock/behind file - `git pull --ff-only`, `template fill`, `profile relink`), **edits your files** (merges into an existing file), or **destructive** (overwrites or removes anything customized).

Call out separately:

- Spots where the user looks to have customized on purpose and a step would change it, e.g. a release adds `"syncClaudeAiSkills": false` but they've set it to `true`. Show both sides and recommend keep, merge, or take upstream.
- Steps already applied or that don't apply to their setup, and why. One line each.
- Optional steps. These are opt-in regardless of classification: keep them out of the safe batch and ask about each one, with a recommendation based on the release's reasoning and the user's setup.

Use AskUserQuestion for customization conflicts and destructive steps - one question per distinct conflict, listing every path that shares it (same step, same current value). Ask once for approval of the batch of safe steps. Don't run anything past step 4 until the user approves.

## 6. Execute

1. Update the code: `git pull --ff-only <remote> main`, or `git checkout <target>` if the user asked for a specific older tag. Re-run `./install.sh` only if a release or the `install.sh` diff calls for it.
2. Before editing any file under the base path, copy it to a fresh backup dir (`mktemp -d -t claudep-upgrade`) preserving its relative path.
3. Apply approved steps in plan order. Prefer claudep's own commands (`template fill`, `profile relink`) over hand-editing symlinks.
4. Edit JSON with `jq` into a temp file, then `cat tmp > file` - `mv` would replace a symlinked path and silently eject it. Touch only the keys in question; if that empties the parent object, drop it to match the target. jq's formatting is fine.
5. If a step fails, stop and report. Don't improvise around it.

## 7. Verify and report

- `claudep --version` shows the target, or `<target>-N-g<sha>` after pulling `main`.
- `claudep profile list` shows no new dangling or missing items.
- `jq empty` on every `settings.json` you touched.
- Report: old version -> new version, steps applied, steps skipped (and why), backup path, and anything left to do by hand.
- Remind them that running Claude sessions keep the old config until restarted.
