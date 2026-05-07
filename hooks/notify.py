#!/usr/bin/env python3
"""Coding-Done-Alert: macOS notification bridge for terminal/AI-coding task hooks.

Reads context from stdin (JSON), pulls config from
~/.config/coding-done-alert/config.json (or env overrides), and triggers a
Hammerspoon notification with click-to-focus zellij pane behaviour.

Designed to be called from Claude Code Stop hooks, Codex CLI lifecycle hooks,
or any custom script that wants a banner + applause + click-jump on completion.

Why Hammerspoon: macOS 26 (Tahoe) silently drops banners from terminal-notifier
(2017 build) and refuses UNUserNotificationCenter authorisation for ad-hoc
signed binaries. Hammerspoon.app is properly signed and exposes hs.notify with
a working click callback (when invoked via hs.task — hs.execute hangs).
See docs/ARCHITECTURE.md for the full rationale.
"""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

CONFIG_PATH = Path(os.environ.get(
    "CODING_DONE_ALERT_CONFIG",
    os.path.expanduser("~/.config/coding-done-alert/config.json"),
))

DEFAULT_CONFIG = {
    "sound": {
        "enabled": True,
        "file": "/System/Library/Sounds/Hero.aiff",
    },
    "terminal": {
        "app_name": "Ghostty",
        "bundle_id": "com.mitchellh.ghostty",
    },
    "zellij": {
        "bin": "/opt/homebrew/bin/zellij",
    },
    "hammerspoon": {
        "bin": "/opt/homebrew/bin/hs",
        "call_timeout_sec": 8,
    },
}

ZELLIJ_LIST_TIMEOUT = 5
SUMMARY_MAX_CHARS = 140


def deep_merge(base: dict, overlay: dict) -> dict:
    out = dict(base)
    for k, v in overlay.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def load_config() -> dict:
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))
    if CONFIG_PATH.exists():
        try:
            user_cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            cfg = deep_merge(cfg, user_cfg)
        except Exception as e:
            print(f"[coding-done-alert] config 解析失败: {e}", file=sys.stderr)
    # env overrides
    if os.environ.get("CODING_DONE_ALERT_SOUND") in ("0", "false", "off", "no"):
        cfg["sound"]["enabled"] = False
    if os.environ.get("CODING_DONE_ALERT_SOUND") in ("1", "true", "on", "yes"):
        cfg["sound"]["enabled"] = True
    if os.environ.get("CODING_DONE_ALERT_SOUND_FILE"):
        cfg["sound"]["file"] = os.environ["CODING_DONE_ALERT_SOUND_FILE"]
    if os.environ.get("CODING_DONE_ALERT_TERMINAL_APP"):
        cfg["terminal"]["app_name"] = os.environ["CODING_DONE_ALERT_TERMINAL_APP"]
    return cfg


def play_sound(cfg: dict) -> None:
    if not cfg["sound"]["enabled"]:
        return
    sound_file = os.path.expanduser(cfg["sound"]["file"])
    if not os.path.exists(sound_file):
        print(f"[coding-done-alert] 声音文件不存在: {sound_file}", file=sys.stderr)
        return
    subprocess.Popen(
        ["/usr/bin/afplay", sound_file],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def get_zellij_pane_title(cfg: dict, session: str, pane_id: str) -> str:
    if not session or not pane_id:
        return ""
    try:
        out = subprocess.run(
            [cfg["zellij"]["bin"], "--session", session, "action", "list-panes"],
            capture_output=True, text=True, timeout=ZELLIJ_LIST_TIMEOUT,
        )
        if out.returncode != 0:
            return ""
        target = f"terminal_{pane_id}"
        for line in out.stdout.splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3 and parts[0] == target:
                return parts[2].strip()
    except Exception:
        return ""
    return ""


def build_click_command(cfg: dict, session: str, pane_id: str) -> str:
    """The shell command that runs when user clicks the banner.

    Note: terminal app activation (and cross-Space switching) is handled by
    Hammerspoon's hs.application:activate(true) inside the Lua module — not
    here. This command only carries the zellij focus instruction.
    """
    if not session or not pane_id:
        return ""
    return (
        f"{cfg['zellij']['bin']} --session {shlex.quote(session)} "
        f"action focus-pane-id {shlex.quote(str(pane_id))}"
    )


def lua_str(s: str) -> str:
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def extract_summary() -> str:
    try:
        ctx = json.loads(sys.stdin.read() or "{}")
        last = ctx.get("last_assistant_message", "")
        if last:
            return last.strip().replace("\n", " ")[:SUMMARY_MAX_CHARS]
    except Exception:
        pass
    return ""


def send_notification(cfg: dict, title: str, message: str, click_cmd: str) -> None:
    lua = (
        f"return codingDoneAlert("
        f"{lua_str(title)}, {lua_str(message)}, {lua_str(click_cmd)}, "
        f"{lua_str(cfg['terminal']['app_name'])})"
    )
    try:
        subprocess.run(
            [cfg["hammerspoon"]["bin"], "-c", lua],
            timeout=cfg["hammerspoon"]["call_timeout_sec"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        print("[coding-done-alert] Hammerspoon 调用超时", file=sys.stderr)
    except FileNotFoundError:
        print(f"[coding-done-alert] 找不到 hs CLI: {cfg['hammerspoon']['bin']}", file=sys.stderr)
    except Exception as e:
        print(f"[coding-done-alert] hs 调用失败: {e}", file=sys.stderr)


def main() -> None:
    cfg = load_config()
    session = os.environ.get("ZELLIJ_SESSION_NAME", "")
    pane_id = os.environ.get("ZELLIJ_PANE_ID", "")

    summary = extract_summary()
    pane_title = get_zellij_pane_title(cfg, session, pane_id) or "Task done"

    title = f"✅ {pane_title}"
    message = summary or "Coding task complete"
    click_cmd = build_click_command(cfg, session, pane_id)

    play_sound(cfg)
    send_notification(cfg, title, message, click_cmd)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[coding-done-alert] 失败: {e}", file=sys.stderr)
