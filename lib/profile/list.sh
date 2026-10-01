#!/usr/bin/env zsh

# one line of detail per profile: template(s) it links to, then anything unusual.
# template is inferred from symlinks the same way relink does it
_profile_summary() {
  local profile_dir="$1"
  local -A templates=()
  local -a ejected=() dangling=() missing=()
  local entry key item target link tdir

  for entry in "${CLAUDEP_SHARED_ITEMS[@]}"; do
    key="${entry%%:*}"
    item="${entry##*:}"
    target="$profile_dir/$item"

    if [[ -L "$target" ]]; then
      link=$(readlink "$target")
      # hand-made relative links resolve from the profile dir, not the cwd
      if [[ "$link" != /* ]]; then
        link="${${:-$profile_dir/$link}:a}"
      fi
      tdir="${link%/$item}"
      templates[$tdir]=1
      # a deleted template shows as "(missing)" below, so only flag dangling items in live ones
      if [[ ! -e "$target" && -d "$tdir" ]]; then
        dangling+=("$key")
      fi
    elif [[ -e "$target" ]]; then
      ejected+=("$key")
    else
      missing+=("$key")
    fi
  done

  local -a names=()
  for tdir in "${(@ko)templates}"; do
    if [[ -d "$tdir" ]]; then
      names+=("${tdir:t}")
    else
      names+=("${tdir:t} (missing)")
    fi
  done

  local -a details=()
  if (( ${#ejected} == ${#CLAUDEP_SHARED_ITEMS} )); then
    details+=("ejected: all")
  elif (( ${#ejected} )); then
    details+=("ejected: ${(j:, :)ejected}")
  fi
  if (( ${#dangling} )); then
    details+=("dangling: ${(j:, :)dangling}")
  fi
  if (( ${#missing} )); then
    details+=("missing: ${(j:, :)missing}")
  fi

  # template column, then details - tab-separated so the caller can align
  print -r -- "${(j:, :)names:--}"$'\t'"${(j:; :)details}"
}

cmd_profile_list() {
  local profile_dir
  profile_dir="$(get_profile_dir)"

  local -a names=()
  local p
  # -/ follows symlinked profile dirs
  for p in "$profile_dir"/*(N-/); do
    names+=("${p:t}")
  done

  if [[ ${#names[@]} -eq 0 ]]; then
    echo "No profiles found. Create one with: claudep profile add <name>"
    return
  fi

  local -a templates=() details=()
  local name line name_w=0 tpl_w=0
  for name in "${names[@]}"; do
    line=$(_profile_summary "$profile_dir/$name")
    templates+=("${line%%$'\t'*}")
    details+=("${line#*$'\t'}")
    if (( ${#name} > name_w )); then
      name_w=${#name}
    fi
    if (( ${#templates[-1]} > tpl_w )); then
      tpl_w=${#templates[-1]}
    fi
  done

  echo "Available profiles:"
  local i
  for (( i = 1; i <= ${#names}; i++ )); do
    if [[ -n "${details[i]}" ]]; then
      printf "  %-${name_w}s   %-${tpl_w}s   %s\n" "${names[i]}" "${templates[i]}" "${details[i]}"
    else
      printf "  %-${name_w}s   %s\n" "${names[i]}" "${templates[i]}"
    fi
  done
}
