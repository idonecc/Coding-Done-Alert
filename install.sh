#!/usr/bin/env bash
# Coding-Done-Alert installer (macOS).
#
# What it does:
#   1. Verifies macOS dependencies (brew, hammerspoon, sox)
#   2. Installs the notify.py hook to ~/.local/bin/coding-done-alert
#   3. Loads the Lua module from ~/.hammerspoon/init.lua
#   4. Seeds ~/.config/coding-done-alert/config.json from the example
#   5. Prints next steps for wiring up Claude Code / Codex / your own hook
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="${HOME}/.local/bin/coding-done-alert"
HS_DIR="${HOME}/.hammerspoon"
HS_INIT="${HS_DIR}/init.lua"
HS_MODULE_DST="${HS_DIR}/coding_done_alert.lua"
CFG_DIR="${HOME}/.config/coding-done-alert"
CFG_FILE="${CFG_DIR}/config.json"

green() { printf "\033[32m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  red "This installer only supports macOS."
  exit 1
fi

# 1. Dependencies
echo "[1/5] Checking dependencies..."
command -v brew >/dev/null 2>&1 || { red "Homebrew required: https://brew.sh"; exit 1; }

if ! [[ -d /Applications/Hammerspoon.app ]]; then
  yellow "Installing Hammerspoon..."
  brew install --cask hammerspoon
else
  green "  ✓ Hammerspoon installed"
fi

if ! command -v sox >/dev/null 2>&1; then
  yellow "Installing sox (for optional applause-sound extraction)..."
  brew install sox
else
  green "  ✓ sox installed"
fi

if ! command -v zellij >/dev/null 2>&1; then
  yellow "  ⚠ zellij not found — click-to-jump will not work"
  yellow "    Install with: brew install zellij"
fi

# 2. Hook script
echo "[2/5] Installing hook script..."
mkdir -p "$(dirname "$INSTALL_BIN")"
cp "$REPO_ROOT/hooks/notify.py" "$INSTALL_BIN"
chmod +x "$INSTALL_BIN"
green "  ✓ Installed: $INSTALL_BIN"

# 3. Hammerspoon Lua module
echo "[3/5] Installing Hammerspoon module..."
mkdir -p "$HS_DIR"
cp "$REPO_ROOT/hammerspoon/coding_done_alert.lua" "$HS_MODULE_DST"
green "  ✓ Module: $HS_MODULE_DST"

if [[ -f "$HS_INIT" ]] && grep -q "coding_done_alert" "$HS_INIT"; then
  green "  ✓ init.lua already loads the module"
else
  echo "" >> "$HS_INIT"
  echo "-- Coding-Done-Alert" >> "$HS_INIT"
  echo "require(\"coding_done_alert\")" >> "$HS_INIT"
  green "  ✓ Appended require() to $HS_INIT"
fi

# 4. Config
echo "[4/5] Seeding config..."
mkdir -p "$CFG_DIR"
if [[ -f "$CFG_FILE" ]]; then
  yellow "  ✓ Config already exists: $CFG_FILE (not overwriting)"
else
  cp "$REPO_ROOT/examples/config.example.json" "$CFG_FILE"
  green "  ✓ Created: $CFG_FILE"
fi

# 5. Reload Hammerspoon
echo "[5/5] Reloading Hammerspoon..."
if pgrep -x Hammerspoon >/dev/null 2>&1; then
  open -g "hammerspoon://reload"
  sleep 1
  green "  ✓ Reload requested"
else
  yellow "  ⚠ Hammerspoon not running. Launch it once to grant Accessibility permissions."
  open -a Hammerspoon
fi

cat <<'NEXT'

────────────────────────────────────────────────────────────────────────────
Installation complete. Next steps:

1. Open Hammerspoon once and (if prompted) grant the system permissions it
   asks for. Notification permissions are granted automatically.

2. (Optional) Replace the default Hero sound with a richer applause clip
   extracted from your own iMovie installation:

       bash bin/extract_applause.sh

   This pulls the audio file from your local iMovie.app and writes
   ~/Library/Sounds/Applause.aiff. Nothing copyrighted is shipped in this
   repo — the script only operates on files already on your machine.

3. Wire it into your tool's lifecycle hook. For Claude Code, add to
   ~/.claude/settings.json under hooks.Stop:

       {
         "hooks": {
           "Stop": [{
             "hooks": [{
               "type": "command",
               "command": "/opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert"
             }]
           }]
         }
       }

   See examples/ for ready-made snippets.

4. Edit ~/.config/coding-done-alert/config.json to toggle the sound or
   point at a different audio file.
────────────────────────────────────────────────────────────────────────────
NEXT
