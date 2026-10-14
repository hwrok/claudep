# Upgrade claudep

Bring this clone from the commit it's on to a newer release, then apply every "Upgrading an existing install" step from the release notes in between to the user's claudep data.

Ground rules:

- Never run `claudep init --force`, or pick "Refresh" in `claudep init`. Both reset the default template to the shipped files and wipe customizations.
- Templates are shared: editing `templates/<name>/settings.json` changes every profile linked to it. This is intentional, don't belabor the point. Ejected items are real files in the profile - for each ejected copy a step would touch, show its current value and ask.

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
- If HEAD already equals the target, the user probably pulled first. Find the pre-pull commit in `git reflog` and confirm the starting version with the user - the upgrade steps still need to run.
- Nothing between start and target? Say so and stop.

## 3. Read every release in the range

For each tag after start, up to and including target, oldest first:

```bash
gh release view <tag> --repo hwrok/claudep --json body -q .body
```

From each, pull out:

- `### Upgrading an existing install` - the manual steps.
- Changed defaults that touch template content (e.g. a new `settings.json` key). `init` and `template fill` never rewrite existing files, so these only reach existing installs by hand.
- Breaking or behavior changes worth telling the user about.

Cross-check against the code:

```bash
git diff <start>..<target> -- assets/templates/default lib/common.sh install.sh
```

- `assets/templates/default/` changes = template content the user may want to merge, including changes no release note mentions.
- Shared item set changed (`CLAUDEP_SHARED_ITEMS` in `lib/common.sh`, or the hardcoded list in older versions) = new or renamed shared items. New ones need `template fill` + `profile relink`; renamed or removed ones need care with existing links.
- `install.sh` changes = may need a re-run.

Plan with the commands the target version ships (`git show <target>:claudep.sh`), not the ones checked out now.

## 4. Inventory the user's setup

Read-only. Don't open `.claude.json`, `.credentials.json`, or history.

- Base path: contents of `$XDG_CONFIG_HOME/claudep/path`, falling back to `~/.config/claudep/path`.
- `claudep template list` and `claudep profile list`.
- Ejected items: shared items under `<base>/profiles/<name>/` that aren't symlinks (`[ ! -L ]`). Older `profile list` doesn't show them.
- Extract the shipped default at both the **starting** and **target** versions:

  ```bash
  git archive <ref> assets/templates/default | tar -x -C "$(mktemp -d)"
  ```

- For each file a step touches, in each template and ejected copy, classify it:
  - **already applied** - matches the target (the key already has the target value, or the file matches target stock). Skip it.
  - **stock** - matches the starting version's shipped file. Safe to update.
  - **customized** - neither. Conflict, ask.
- Compare `settings.json` by key with `jq`, never as text - key order and formatting don't count. Older `init` substituted `<CLAUDEP_BASE_DIR>` with the template's absolute path; treat that as stock.
- Ignore `.gitkeep` and user-added rules/skills/agents.

## 5. Present the plan, then ask

Show one plan, ordered as it'll run. For each step:

- What runs or changes, and on which paths (template, profiles, ejected copies).
- Which release asked for it, or "unannounced" if only the diff shows it.
- A tag: **safe** (additive, idempotent, or overwriting a stock file - `git pull --ff-only`, `template fill`, `profile relink`), **edits your files** (merges into an existing file), or **destructive** (overwrites or removes anything customized).

Call out separately:

- Spots where the user looks to have customized on purpose and a step would change it, e.g. a release adds `"syncClaudeAiSkills": false` but they've set it to `true`. Show both sides and recommend keep, merge, or take upstream.
- Steps already applied or that don't apply to their setup, and why. One line each.
- Optional steps.

Use AskUserQuestion for each customization conflict and any destructive step. Ask once for approval of the batch of safe steps. Don't run anything past step 4 until the user approves.

## 6. Execute

1. Update the code: `git pull --ff-only <remote> main`, or `git checkout <target>` if the user asked for a specific older tag. Re-run `./install.sh` only if a release or the `install.sh` diff calls for it.
2. Before editing any file under the base path, copy it to a fresh backup dir (`mktemp -d -t claudep-upgrade`) preserving its relative path.
3. Apply approved steps in plan order. Prefer claudep's own commands (`template fill`, `profile relink`) over hand-editing symlinks. Edit JSON with `jq` via a temp file, touching only the keys in question; its formatting is fine.
4. If a step fails, stop and report. Don't improvise around it.

## 7. Verify and report

- `claudep --version` shows the target, or `<target>-N-g<sha>` after pulling `main`.
- `claudep profile list` shows no new dangling or missing items.
- `jq empty` on every `settings.json` you touched.
- Report: old version -> new version, steps applied, steps skipped (and why), backup path, and anything left to do by hand.
- Remind them that running Claude sessions keep the old config until restarted.
