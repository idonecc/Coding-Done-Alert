#!/usr/bin/env bash
# Coding-Done-Alert installer (macOS).
#
# What it does:
#   1. Verifies macOS dependencies (brew, hammerspoon, sox, optional yabai)
#   2. Installs the notify.py hook to ~/.local/bin/coding-done-alert
#   3. Loads the Lua module from ~/.hammerspoon/init.lua
#   4. Wires the zsh precmd hook into ~/.zshrc (only when yabai is present)
#   5. Seeds ~/.config/coding-done-alert/config.json from the example
#   6. Reloads Hammerspoon
#   7. Prints next steps for wiring up Claude Code / Codex / your own hook
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="${HOME}/.local/bin/coding-done-alert"
HS_DIR="${HOME}/.hammerspoon"
HS_INIT="${HS_DIR}/init.lua"
HS_MODULE_DST="${HS_DIR}/coding_done_alert.lua"
CFG_DIR="${HOME}/.config/coding-done-alert"
CFG_FILE="${CFG_DIR}/config.json"
ZSHRC="${HOME}/.zshrc"
ZSH_HOOK_SRC="${REPO_ROOT}/hooks/zsh_precmd_record.sh"

green() { printf "\033[32m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  red "This installer only supports macOS."
  exit 1
fi

YABAI_PRESENT=0

# 1. Dependencies
echo "[1/6] Checking dependencies..."
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

if command -v yabai >/dev/null 2>&1; then
  green "  ✓ yabai installed (cross-Space click-to-jump enabled)"
  YABAI_PRESENT=1
else
  yellow "  ⚠ yabai not found — click-to-jump will work only on the visible Space"
  yellow "    For full cross-Space support see docs/INSTALL.md (requires SIP disable)"
fi

# 2. Hook script
echo "[2/6] Installing hook script..."
mkdir -p "$(dirname "$INSTALL_BIN")"
cp "$REPO_ROOT/hooks/notify.py" "$INSTALL_BIN"
chmod +x "$INSTALL_BIN"
green "  ✓ Installed: $INSTALL_BIN"

# 3. Hammerspoon Lua module
echo "[3/6] Installing Hammerspoon module..."
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

# 4. zsh precmd hook (cross-Space window mapping)
echo "[4/6] Wiring zsh precmd hook..."
if [[ "$YABAI_PRESENT" -eq 0 ]]; then
  yellow "  ⚠ yabai not installed; skipping zsh hook (no value without yabai)"
elif [[ ! -f "$ZSHRC" ]]; then
  yellow "  ⚠ ~/.zshrc not found; skipping. Source manually: source $ZSH_HOOK_SRC"
elif grep -Fq "$ZSH_HOOK_SRC" "$ZSHRC" 2>/dev/null; then
  green "  ✓ ~/.zshrc already sources the hook"
else
  cp "$ZSHRC" "${ZSHRC}.coding-done-alert.bak"
  echo "" >> "$ZSHRC"
  echo "# Coding-Done-Alert: refresh yabai window id mapping per prompt" >> "$ZSHRC"
  echo "source $ZSH_HOOK_SRC" >> "$ZSHRC"
  green "  ✓ Appended source line to $ZSHRC (backup at ${ZSHRC}.coding-done-alert.bak)"
fi

# 5. Config
echo "[5/6] Seeding config..."
mkdir -p "$CFG_DIR"
if [[ -f "$CFG_FILE" ]]; then
  yellow "  ✓ Config already exists: $CFG_FILE (not overwriting)"
else
  cp "$REPO_ROOT/examples/config.example.json" "$CFG_FILE"
  green "  ✓ Created: $CFG_FILE"
fi

# 6. Reload Hammerspoon
echo "[6/6] Reloading Hammerspoon..."
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

2. (For cross-Space click-to-jump) Confirm yabai is healthy:

       yabai -m query --windows | head

   If you see "yabai: missing required nvram boot-arg" or similar errors,
   read docs/INSTALL.md — full setup needs SIP disabled + an NVRAM boot-arg
   on Apple Silicon.

3. (Optional) Replace the default Hero sound with a richer applause clip
   extracted from your own iMovie installation:

       bash bin/extract_applause.sh

   This pulls the audio file from your local iMovie.app and writes
   ~/Library/Sounds/Applause.aiff. Nothing copyrighted is shipped in this
   repo — the script only operates on files already on your machine.

4. Wire it into your tool's lifecycle hook. For Claude Code, add to
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

5. Edit ~/.config/coding-done-alert/config.json to toggle the sound or
   point at a different audio file.

6. Open a new terminal session inside zellij and hit Enter once. You should
   see /tmp/zellij_yabai/<session_name> appear with the current Ghostty
   yabai window id — that's how the click handler finds the right window.
────────────────────────────────────────────────────────────────────────────
NEXT
