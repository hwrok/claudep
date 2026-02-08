#!/usr/bin/env zsh
set -euo pipefail

# real path of script / follow symlinks
SCRIPT_PATH="${(%):-%x}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_PATH=$(readlink "$SCRIPT_PATH")
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/common.sh"

case "${1:-}" in
  init)
    source "$LIB_DIR/init.sh"; shift; cmd_init "$@" ;;

  start)
    source "$LIB_DIR/profile/start.sh"; shift; cmd_profile_start "$@" ;;

  profile)
    shift
    case "${1:-}" in
      add)    source "$LIB_DIR/profile/add.sh";    shift; cmd_profile_add "$@" ;;
      remove) source "$LIB_DIR/profile/remove.sh"; shift; cmd_profile_remove "$@" ;;
      list)   source "$LIB_DIR/profile/list.sh";   shift; cmd_profile_list "$@" ;;
      start)  source "$LIB_DIR/profile/start.sh";  shift; cmd_profile_start "$@" ;;
      eject)  source "$LIB_DIR/profile/eject.sh";  shift; cmd_profile_eject "$@" ;;
      *)
        echo "Usage: claudep profile {add|remove|list|start|eject} [args]" >&2
        exit 1
        ;;
    esac
    ;;

  template)
    shift
    case "${1:-}" in
      add)    source "$LIB_DIR/template/add.sh";    shift; cmd_template_add "$@" ;;
      remove) source "$LIB_DIR/template/remove.sh"; shift; cmd_template_remove "$@" ;;
      list)   source "$LIB_DIR/template/list.sh";   shift; cmd_template_list "$@" ;;
      *)
        echo "Usage: claudep template {add|remove|list} [args]" >&2
        exit 1
        ;;
    esac
    ;;

  uninstall)
    exec "$SCRIPT_DIR/uninstall.sh" "$@" ;;

  *)
    echo "Usage: claudep {init|start|profile|template|uninstall}" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  init                  Initialize claudep" >&2
    echo "  start <profile>      Launch claude with a profile" >&2
    echo "  profile <command>    Manage profiles (add|remove|list|start|eject)" >&2
    echo "  template <command>   Manage templates (add|remove|list)" >&2
    echo "  uninstall            Remove claudep" >&2
    exit 1
    ;;
esac
