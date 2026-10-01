#!/usr/bin/env zsh

# distinct template dirs a profile's symlinks point at, one per line
# (readlink still resolves for broken links, so a dead template still shows up)
_profile_template_dirs() {
  local profile_dir="$1"
  local item target link
  local -A seen=()

  for item in $(shared_item_paths); do
    target="$profile_dir/$item"
    [[ -L "$target" ]] || continue

    link=$(readlink "$target")
    # hand-made relative links resolve from the profile dir, not the cwd
    if [[ "$link" != /* ]]; then
      link="${${:-$profile_dir/$link}:a}"
    fi
    seen[${link%/$item}]=1
  done

  print -l -- "${(@ko)seen}"
}

_relink_all() {
  if [[ $# -gt 0 ]]; then
    echo "Error: --all can't be combined with other flags; to use --template, relink a single profile" >&2
    exit 1
  fi

  local -a names=()
  local p
  # -/ follows symlinked profile dirs
  for p in "$(get_profile_dir)"/*(N-/); do
    names+=("${p:t}")
  done

  if (( ${#names} == 0 )); then
    echo "No profiles found. Create one with: claudep profile add <name>"
    return
  fi

  # each profile runs in a subshell so one that needs --template exits without stopping the rest.
  # errexit is off out here so we can read rc, and back on inside - a subshell in an `if` would
  # silently run with it off
  setopt localoptions noerrexit
  local -a failed=()
  local name rc
  for name in "${names[@]}"; do
    echo "== $name"
    # straight to the single-profile path, so a profile literally named `--all` can't recurse
    ( setopt errexit; _relink_profile "$name" )
    rc=$?
    if (( rc != 0 )); then
      failed+=("$name")
    fi
    echo ""
  done

  if (( ${#failed} > 0 )); then
    echo "Not relinked: ${failed[*]} - see errors above" >&2
    exit 1
  fi
}

cmd_profile_relink() {
  if [[ "${1:-}" == --all ]]; then
    shift
    _relink_all "$@"
  else
    _relink_profile "$@"
  fi
}

_relink_profile() {
  local profile_name="${1:-}"

  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: claudep profile relink <profile-name> [--template <name>] | --all" >&2
    exit 1
  fi
  shift

  local template_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template)   require_value "$@"; template_name="$2"; shift 2 ;;
      --template=*) require_value "${1%%=*}" "${1#*=}"; template_name="${1#*=}"; shift ;;
      *)            echo "Error: Unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  validate_name profile "$profile_name"
  if [[ -n "$template_name" ]]; then
    validate_name template "$template_name"
  fi

  local profile_dir
  profile_dir="$(get_profile_dir)/$profile_name"

  if [[ ! -d "$profile_dir" ]]; then
    echo "Error: Profile not found: $profile_name" >&2
    source "$LIB_DIR/profile/list.sh"
    cmd_profile_list >&2
    exit 1
  fi

  local template_dir
  if [[ -n "$template_name" ]]; then
    template_dir="$(get_templates_dir)/$template_name"
  else
    local -a found=("${(@f)$(_profile_template_dirs "$profile_dir")}")
    found=("${(@)found:#}")

    local -a live=() dead=()
    local dir
    for dir in "${found[@]}"; do
      if [[ -d "$dir" ]]; then
        live+=("$dir")
      else
        dead+=("$dir")
      fi
    done

    if (( ${#live} > 1 )); then
      echo "Error: Profile '$profile_name' links to more than one template:" >&2
      printf "    %s\n" "${live[@]##*/}" >&2
      echo "  Specify which one to link missing items from:" >&2
      echo "    claudep profile relink $profile_name --template <name>" >&2
      exit 1
    fi

    if (( ${#dead} > 0 )); then
      echo "Error: Profile '$profile_name' links to templates that no longer exist:" >&2
      printf "    %s\n" "${dead[@]}" >&2
      if (( ${#live} == 1 )); then
        echo "  Otherwise linked to: ${live[1]##*/}" >&2
      fi
      echo "  Specify which template to repair them from:" >&2
      echo "    claudep profile relink $profile_name --template <name>" >&2
      exit 1
    fi

    if (( ${#live} == 0 )); then
      echo "Error: Profile '$profile_name' has no symlinks left to infer a template from" >&2
      echo "  Specify one: claudep profile relink $profile_name --template <name>" >&2
      exit 1
    fi

    template_dir="${live[1]}"
  fi

  if [[ ! -d "$template_dir" ]]; then
    echo "Error: Template not found: $template_dir" >&2
    exit 1
  fi

  local linked=0 repaired=0 untouched=0
  local item target want current

  for item in $(shared_item_paths); do
    target="$profile_dir/$item"
    want="$template_dir/$item"

    if [[ -L "$target" ]]; then
      current=$(readlink "$target")
      if [[ "$current" != /* ]]; then
        current="${${:-$profile_dir/$current}:a}"
      fi

      # intact link: correct already, or deliberately pointed elsewhere
      if [[ -e "$target" ]]; then
        if [[ "$current" != "$want" ]]; then
          echo "  $item: linked to another template ($(dirname "$current")), left alone"
          untouched=$((untouched + 1))
        fi
        continue
      fi
    elif [[ -e "$target" ]]; then
      echo "  $item: ejected, left alone"
      untouched=$((untouched + 1))
      continue
    fi

    # absent, or a dangling symlink - either way it wants a fresh link
    if [[ ! -e "$want" ]]; then
      echo "⚠️  $item: missing from template $(basename "$template_dir") (skipping)" >&2
      untouched=$((untouched + 1))
      continue
    fi

    if [[ -L "$target" ]]; then
      rm "$target"
      ln -s "$want" "$target"
      echo "✓ Repaired: $item (was dangling -> $current)"
      repaired=$((repaired + 1))
    else
      ln -s "$want" "$target"
      echo "✓ Linked: $item"
      linked=$((linked + 1))
    fi
  done

  echo ""
  echo "Profile '$profile_name' (template: $(basename "$template_dir"))"
  echo "  $linked linked, $repaired repaired, $untouched left alone"
}
