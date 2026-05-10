#!/usr/bin/env bash
# Uninstall Coding-Done-Alert. Safe to run; preserves user config.
set -euo pipefail

INSTALL_BIN="${HOME}/.local/bin/coding-done-alert"
HS_DIR="${HOME}/.hammerspoon"
HS_INIT="${HS_DIR}/init.lua"
HS_MODULE_DST="${HS_DIR}/coding_done_alert.lua"
ZSHRC="${HOME}/.zshrc"

rm -f "$INSTALL_BIN" && echo "Removed $INSTALL_BIN"
rm -f "$HS_MODULE_DST" && echo "Removed $HS_MODULE_DST"

if [[ -f "$HS_INIT" ]]; then
  /usr/bin/sed -i '' '/-- Coding-Done-Alert/d; /require("coding_done_alert")/d' "$HS_INIT"
  echo "Cleaned require() from $HS_INIT"
fi

if [[ -f "$ZSHRC" ]]; then
  /usr/bin/sed -i '' \
    '/# Coding-Done-Alert: refresh yabai window id mapping per prompt/d; \
     /source.*Coding-Done-Alert\/hooks\/zsh_precmd_record\.sh/d' \
    "$ZSHRC"
  echo "Cleaned zsh hook source line from $ZSHRC (backup at ${ZSHRC}.coding-done-alert.bak if install.sh made one)"
fi

# Window-id mapping is regenerated on demand; safe to drop.
rm -rf /tmp/zellij_yabai 2>/dev/null && echo "Removed /tmp/zellij_yabai/"

echo ""
echo "Config preserved at ~/.config/coding-done-alert/config.json (delete manually if desired)."
echo "Optional sound file at ~/Library/Sounds/Applause.aiff (delete manually if desired)."
echo "Hammerspoon, sox, and yabai are not removed (other tools may use them)."
