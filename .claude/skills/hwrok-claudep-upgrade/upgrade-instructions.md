# Upgrade claudep

Bring this clone from the commit it's on to a newer release, then apply every "Upgrading an existing install" step from the release notes in between to the user's claudep data.

Ground rules:

- Never run `claudep init --force`, or pick "Refresh" in `claudep init`. Both reset the default template to the shipped files and wipe customizations.
- Templates are shared: editing `templates/<name>/settings.json` changes every profile linked to it. This is intentional, don't belabor the point. Ejected items are real files in the profile and need the same edit applied separately, if at all.

## 1. Preflight

- Confirm you're in a claudep clone (`claudep.sh` exists) and find the remote pointing at `hwrok/claudep` - `<remote>` below. No such remote (e.g. a fork)? Ask which one holds releases.
- `git describe --tags --always --dirty` and `git rev-parse HEAD` - the starting version. Record both before anything moves HEAD.
- `readlink "$(command -v claudep)"` should resolve to this clone's `claudep.sh`. If it points at another clone, stop and tell the user.

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

- `assets/templates/default/` changes = template content the user may want to merge.
- `CLAUDEP_SHARED_ITEMS` in `lib/common.sh` changes = new or renamed shared items. New ones need `template fill` + `profile relink`; renamed or removed ones need care with existing links.
- `install.sh` changes = may need a re-run.

## 4. Inventory the user's setup

Read-only. Don't open `.claude.json`, `.credentials.json`, or history.

- Base path: contents of `$XDG_CONFIG_HOME/claudep/path`, falling back to `~/.config/claudep/path`.
- `claudep template list` and `claudep profile list`.
- For each template, diff against the shipped default at the **starting** version to tell user edits apart from stock files:

  ```bash
  git archive <start> assets/templates/default | tar -x -C "$(mktemp -d)"
  diff -r <extracted>/assets/templates/default <base>/templates/<name>
  ```

  Only the files the release steps touch matter. Ignore `.gitkeep` and user-added rules/skills/agents.

- For each profile, list ejected items the release steps would also apply to.

## 5. Present the plan, then ask

Show one plan, ordered as it'll run. For each step:

- What runs or changes, and on which paths (template, profiles, ejected copies).
- Which release asked for it.
- A tag: **safe** (additive or idempotent - `git pull --ff-only`, `template fill`, `profile relink`), **edits your files** (merges into an existing file), or **destructive** (overwrites or removes anything).

Call out separately:

- Spots where the user looks to have customized on purpose and a step would change it, e.g. a release adds `"syncClaudeAiSkills": false` but they've set it to `true`. Show both sides and recommend keep, merge, or take upstream.
- Steps that don't apply to their setup, and why.
- Optional steps.

Use AskUserQuestion for each customization conflict and any destructive step. Ask once for approval of the batch of safe steps. Don't run anything past step 4 until the user approves.

## 6. Execute

1. Update the code: `git pull --ff-only <remote> main` (or `git checkout <target>` if they're tracking tags). Re-run `./install.sh` only if a release or the `install.sh` diff calls for it.
2. Before editing any file under the base path, copy it to a fresh backup dir (`mktemp -d -t claudep-upgrade`) preserving its relative path.
3. Apply approved steps in plan order. Prefer claudep's own commands (`template fill`, `profile relink --all`) over hand-editing symlinks. For JSON edits, change only the keys in question and leave the rest of the file as-is.
4. If a step fails, stop and report. Don't improvise around it.

## 7. Verify and report

- `claudep --version` shows the target.
- `claudep profile list` shows no new dangling or missing items.
- `jq empty` on every `settings.json` you touched.
- Report: old version -> new version, steps applied, steps skipped (and why), backup path, and anything left to do by hand.
- Remind them that running Claude sessions keep the old config until restarted.
