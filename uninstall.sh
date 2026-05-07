#!/usr/bin/env bash
# Uninstall Coding-Done-Alert. Safe to run; preserves user config.
set -euo pipefail

INSTALL_BIN="${HOME}/.local/bin/coding-done-alert"
HS_DIR="${HOME}/.hammerspoon"
HS_INIT="${HS_DIR}/init.lua"
HS_MODULE_DST="${HS_DIR}/coding_done_alert.lua"

rm -f "$INSTALL_BIN" && echo "Removed $INSTALL_BIN"
rm -f "$HS_MODULE_DST" && echo "Removed $HS_MODULE_DST"

if [[ -f "$HS_INIT" ]]; then
  # Strip the require line and the comment header
  /usr/bin/sed -i '' '/-- Coding-Done-Alert/d; /require("coding_done_alert")/d' "$HS_INIT"
  echo "Cleaned require() from $HS_INIT"
fi

echo ""
echo "Config preserved at ~/.config/coding-done-alert/config.json (delete manually if desired)."
echo "Optional sound file at ~/Library/Sounds/Applause.aiff (delete manually if desired)."
echo "Hammerspoon and sox are not removed (other tools may use them)."
