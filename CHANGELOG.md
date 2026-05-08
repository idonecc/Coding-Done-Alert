# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/idonecc/Coding-Done-Alert/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/idonecc/Coding-Done-Alert/releases/tag/v0.1.0
