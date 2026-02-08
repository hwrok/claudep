#!/usr/bin/env zsh

cmd_template_list() {
  local templates_dir
  templates_dir=$(get_templates_dir)

  local templates=("$templates_dir"/*(N))

  local names=()
  for t in "${templates[@]}"; do
    [[ -d "$t" ]] && names+=("$(basename "$t")")
  done

  if [[ ${#names[@]} -eq 0 ]]; then
    echo "No templates found. Run: claudep init"
  else
    echo "Available templates:"
    printf "  %s\n" "${names[@]}" | sort
  fi
}
