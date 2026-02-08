#!/usr/bin/env zsh

cmd_profile_list() {
  local profile_dir
  profile_dir="$(get_profile_dir)"

  local profiles=("$profile_dir"/*(N))

  local names=()
  for p in "${profiles[@]}"; do
    [[ -d "$p" ]] && names+=("$(basename "$p")")
  done

  if [[ ${#names[@]} -eq 0 ]]; then
    echo "No profiles found. Create one with: claudep profile add <name>"
  else
    echo "Available profiles:"
    printf "  %s\n" "${names[@]}" | sort
  fi
}
