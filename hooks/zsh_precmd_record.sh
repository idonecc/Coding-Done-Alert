# Coding-Done-Alert · zsh precmd hook (v0.2.0+)
#
# Maintains a (zellij_session → yabai window id) mapping so that the click
# handler can pull the correct Ghostty/terminal window forward across Spaces
# via `yabai -m window --focus <id>`.
#
# How to enable:
#   1. Make sure yabai is installed and its scripting addition loaded
#      (see docs/INSTALL.md).
#   2. Source this file from your ~/.zshrc:
#          source /path/to/Coding-Done-Alert/hooks/zsh_precmd_record.sh
#      Or run install.sh which appends the line for you.
#   3. Open a new terminal window, attach a zellij session inside it, hit
#      Enter once. The mapping file /tmp/zellij_yabai/<session> appears.
#
# Why a precmd hook (not a one-shot at attach):
#   Ghostty windows can be closed and re-opened, yabai window ids change.
#   precmd refreshes the mapping every time you return to the prompt, so
#   stale ids self-heal without manual intervention.
#
# Why no OSC title path:
#   zellij intercepts OSC 0/2 by design (so individual panes don't fight over
#   the parent terminal title). Ghostty's AppleScript dictionary is read-only
#   for window names. A side-channel file is the only reliable way to
#   correlate (zellij session) ↔ (yabai window id) on macOS 26.

if [[ -n "$ZELLIJ_SESSION_NAME" ]] && command -v yabai >/dev/null 2>&1; then
  autoload -Uz add-zsh-hook
  _coding_done_alert_record_window() {
    local wid
    wid=$(yabai -m query --windows --window 2>/dev/null \
      | python3 -c 'import sys, json
try:
  w = json.load(sys.stdin)
  if w.get("app") in ("Ghostty", "iTerm2", "Terminal", "Alacritty", "WezTerm", "kitty"):
    print(w["id"])
except Exception:
  pass' 2>/dev/null)
    if [[ -n "$wid" ]]; then
      mkdir -p /tmp/zellij_yabai 2>/dev/null
      echo "$wid" > "/tmp/zellij_yabai/$ZELLIJ_SESSION_NAME"
    fi
  }
  add-zsh-hook precmd _coding_done_alert_record_window
fi
