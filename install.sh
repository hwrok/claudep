#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
INSTALL_TARGET="${1:-/usr/local/bin/claudep}"

echo "Installing claudep..."

check_deps() {
  local missing=()
  
  for cmd in zsh readlink; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${missing[*]}" >&2
    exit 1
  fi
}

make_executable() {
  chmod +x "$SCRIPT_DIR/claudep.sh"
  chmod +x "$SCRIPT_DIR/uninstall.sh"
  chmod +x "$SCRIPT_DIR"/lib/*.sh
  echo "✓ Made scripts executable"
}

install_symlink() {
  local target_dir
  target_dir=$(dirname "$INSTALL_TARGET")
  
  if [[ ! -d "$target_dir" ]]; then
    echo "Error: Target directory does not exist: $target_dir" >&2
    echo "  Create it or specify different path: ./install.sh /path/to/bin/claudep" >&2
    exit 1
  fi
  
  if [[ ! -w "$target_dir" ]]; then
    echo "Error: No write permission to $target_dir" >&2
    echo "  Try: sudo ./install.sh" >&2
    exit 1
  fi
  
  ln -sf "$SCRIPT_DIR/claudep.sh" "$INSTALL_TARGET"
  echo "✓ Installed symlink: $INSTALL_TARGET -> $SCRIPT_DIR/claudep.sh"
}

verify() {
  if command -v claudep &>/dev/null; then
    echo "✓ claudep is in PATH"
    claudep 2>&1 | head -n1 || true
  else
    echo "⚠️  claudep not found in PATH. Add $target_dir to PATH or use full path: $INSTALL_TARGET"
  fi
}

# Run installation
check_deps
make_executable
install_symlink
verify

echo ""
echo "Installation complete!"
echo "Next step: claudep init [--path /custom/path]"
