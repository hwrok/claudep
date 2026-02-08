#!/usr/bin/env zsh
set -euo pipefail

INSTALL_TARGET="${1:-/usr/local/bin/claudep}"
CONFIG_DIR="$HOME/.config/claudep"
PROFILES_DIR_FILE="$CONFIG_DIR/path"

echo "Uninstalling claudep..."

# remove system symlink
if [[ -L "$INSTALL_TARGET" ]]; then
  rm "$INSTALL_TARGET"
  echo "✓ Removed symlink: $INSTALL_TARGET"
elif [[ -e "$INSTALL_TARGET" ]]; then
  echo "⚠️  $INSTALL_TARGET exists but is not a symlink (skipping)"
else
  echo "  No symlink found at: $INSTALL_TARGET"
fi

# optionally, remove profiles and config data
if [[ -f "$PROFILES_DIR_FILE" ]]; then
  profiles_dir=$(cat "$PROFILES_DIR_FILE")
  
  echo ""
  echo "Found claudep data:"
  echo "  Config: $CONFIG_DIR"
  echo "  Profiles: $profiles_dir"
  echo -n "Remove all data? (y/N): "
  read -r REPLY
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    rm -rf "$profiles_dir"
    echo "✓ Removed all claudep data"
  else
    echo "  Kept data (remove manually if needed)"
  fi
elif [[ -d "$CONFIG_DIR" ]]; then
  echo ""
  echo "Found config dir: $CONFIG_DIR"
  read -p "Remove config? (y/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    echo "✓ Removed config"
  fi
fi

echo ""
echo "Uninstall complete."
