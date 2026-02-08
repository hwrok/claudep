#!/bin/bash

default_color=32

# optional --color=<desired_color>
# --items <space-separated list of strings to print"
colorize() {
  local color=$default_color
  local -a items=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --color) color="$2"; shift 2 ;;
      --color=*) color="${1#*=}"; shift ;;
      --items)
        shift
        while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
            items+=("$1")
            shift
        done
        ;;
      *) items+=("$1"); shift ;;
    esac
  done

  local output=""
  for i in "${!items[@]}"; do
    output+="\033[1;${color}m${items[$i]}\033[0m"
    if [ $i -lt $((${#items[@]} - 1)) ]; then
      output+=" | "
    fi
  done

  echo -e "[$output]"
}

input=$(cat)

CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')
DIR=$(basename "$(echo "$input" | jq -r '.cwd // empty')")
PROFILE="${CLAUDEP_PROFILE:-unknown}"

if [ "$USAGE" != "null" ]; then
  CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
  TOKENS_USED_K=$((CURRENT_TOKENS / 1000))
  TOKENS_TOTAL_K=$((CONTEXT_SIZE / 1000))
  colorize --items "$DIR" "claudep:$PROFILE" "ctx: ${PERCENT_USED}% ${TOKENS_USED_K}/${TOKENS_TOTAL_K}k"
else
  colorize --items "$DIR" "claudep:$PROFILE" "ctx: 0% 0/0k"
fi
