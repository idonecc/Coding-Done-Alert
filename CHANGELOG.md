# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-05-10

### Added
- **Cross-Space click-to-jump via yabai.** The click handler now runs `yabai -m window --focus <id>` before the zellij focus, so the correct Ghostty/terminal window is pulled forward across macOS Spaces — not just within the visible Space.
- `hooks/zsh_precmd_record.sh` — zsh precmd hook that maintains a (zellij session → yabai window id) mapping in `/tmp/zellij_yabai/<session>`. Refreshes on every prompt so Ghostty restarts auto-heal.
- `install.sh` step 4: wires the zsh hook into `~/.zshrc` (with backup) when yabai is detected.
- `uninstall.sh`: cleans the zsh hook source line and `/tmp/zellij_yabai/`.
- `notify.py`: `cfg.yabai.{bin,window_map_dir}` configuration.
- Hammerspoon `TASK_DONE` log line now includes the full stderr/stdout (truncated to 300/200 chars) instead of just length, so failed yabai/zellij invocations are diagnosable without re-running the command.
- Documentation: `docs/INSTALL.md` step 0 covers the SIP / NVRAM `-arm64e_preview_abi` / yabai SA / sudoers / `--start-service` setup. `docs/ARCHITECTURE.md` rewritten with the new flow diagram and a complete table of macOS 26 dead-ends ruled out before settling on yabai. `docs/TROUBLESHOOTING.md` adds yabai diagnostics and the "exit=2 = success after yabai pull" note.

### Changed
- **BREAKING (effective behaviour, not API):** Cross-Space click-to-jump now requires yabai. Without yabai the click handler still works, but degrades to same-Space focus only — same as v0.1.0 in practice.
- `notify.py::build_click_command` now composes `WID=$(cat /tmp/zellij_yabai/<s>); [ -n "$WID" ] && [ -x yabai ] && yabai -m window --focus "$WID"; zellij action focus-pane-id <p>`. The yabai segment is fully guarded so missing yabai / missing mapping / stale id all degrade silently.
- `hammerspoon/coding_done_alert.lua` header comment updated to reflect that `app:activate(true)` is now a same-Space fallback only — real cross-Space pull is done by yabai inside the click cmd. Behaviour at runtime is unchanged for users on the visible Space.

### Removed
- The v0.1.0 README / docs claim that `hs.application:activate(true)` can follow apps across macOS Spaces. macOS 26 (Tahoe) made this untrue by tightening the SkyLight private APIs; the claim is replaced with an honest accounting of what works and what doesn't.

## [0.1.0] - 2026-05-08

### Added
- Initial public release.
- `hooks/notify.py` — Stop-hook entry point. Reads JSON from stdin, plays a sound via `afplay`, and triggers a Hammerspoon banner via `hs -c`.
- `hammerspoon/coding_done_alert.lua` — Lua module exposing a global `codingDoneAlert(title, body, clickCmd, terminalApp)` function. Banner click activates the terminal across macOS Spaces and runs the supplied shell command via `hs.task` (async-safe).
- `install.sh` / `uninstall.sh` — one-command install with dependency checks (Hammerspoon, sox).
- `bin/extract_applause.sh` — opt-in user-side extraction of a 3-second applause clip from iMovie's Stadium Crowd Applause.caf. No copyrighted material shipped in repo.
- `examples/claude-code-stop-hook.json` — drop-in snippet for Claude Code.
- `examples/codex-cli-hook.toml` — conceptual snippet for OpenAI Codex CLI.
- `examples/config.example.json` — default config seed (system-bundled `Hero.aiff` for out-of-box compatibility).
- `docs/ARCHITECTURE.md` — bilingual deep-dive into the macOS 26 (Tahoe) workarounds: `hs.execute` hangs → use `hs.task`; `zellij action focus-pane-with-id` was renamed to `focus-pane-id`; `osascript` activate doesn't follow Spaces → use `hs.application:activate(true)`.
- `docs/INSTALL.md` — bilingual manual installation walkthrough.
- `docs/TROUBLESHOOTING.md` — diagnostic recipe for the `/tmp/coding_done_alert.log` rows (NOTIFY/CALLBACK/ACTIVATE/TASK_DONE).
- Bilingual (English + Chinese) `README.md`.

[Unreleased]: https://github.com/idonecc/Coding-Done-Alert/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/idonecc/Coding-Done-Alert/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/idonecc/Coding-Done-Alert/releases/tag/v0.1.0
