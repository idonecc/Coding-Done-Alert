# Architecture / 设计说明

## English

### Component diagram (v0.2.0)

```
┌──────────────────────────┐
│  AI/CLI tool finishes    │
│  (Claude Code Stop hook, │
│  Codex lifecycle, etc.)  │
└────────────┬─────────────┘
             │ stdin: {"last_assistant_message": "..."}
             │ env:   ZELLIJ_SESSION_NAME, ZELLIJ_PANE_ID
             ▼
┌──────────────────────────┐
│ ~/.local/bin/            │
│   coding-done-alert      │   ← Python 3.9+
│   (hooks/notify.py)      │   ← reads ~/.config/coding-done-alert/config.json
└────────────┬─────────────┘
             │ 1. afplay <sound.file>           (independent, ignores DND)
             │ 2. hs -c 'codingDoneAlert(...)'   (sync IPC, ≤8s timeout)
             │      └ clickCmd is composed here (zellij focus + optional yabai)
             ▼
┌──────────────────────────┐
│  Hammerspoon (signed     │
│  .app, persistent)       │
│  ~/.hammerspoon/         │
│    coding_done_alert.lua │
└────────────┬─────────────┘
             │ hs.notify.new(...) → banner
             │ on click:
             │   app:activate(true)             ← same-Space fallback
             │   hs.task.new("/bin/sh", clickCmd) ← async, captures stderr
             ▼
┌──────────────────────────────────────────────────────┐
│ /bin/sh -c clickCmd                                  │
│   WID=$(cat /tmp/zellij_yabai/<session>)             │
│   if WID present and yabai installed:                │
│     yabai -m window --focus "$WID"  ← cross-Space    │
│   zellij --session <s> action focus-pane-id <p>      │
└──────────────────────────────────────────────────────┘

Mapping side-channel maintained by zsh:
  ┌────────────────────────────────────────────────┐
  │ zsh in zellij (precmd hook)                    │
  │   on every prompt:                             │
  │     wid = yabai -m query --windows --window    │
  │     echo $wid > /tmp/zellij_yabai/<session>    │
  └────────────────────────────────────────────────┘
```

### Why yabai (and why everything else fails on macOS 26)

The earlier v0.1.0 design assumed `hs.application:activate(true)` would follow
the app to its Space. That stopped working when macOS 26 (Tahoe) tightened the
SkyLight private APIs. Every alternative was tried and ruled out:

| Tool | What we hoped | What actually happens on macOS 26 | Status |
| --- | --- | --- | --- |
| `hs.spaces.gotoSpace` / `moveWindowToSpace` | Switch desktops, drag windows across | Calls succeed but have no visual effect — entire `hs.spaces` module is functionally dead, even read-only `activeSpace()` returns `nil` | Dead |
| `hs.application:activate(true)` | Cross-Space app raise | Raises within current Space only; never switches Space | Dead for cross-Space, kept as same-Space fallback |
| `osascript "tell App to activate"` | Cross-Space app raise | Same as above; AppleScript activate doesn't follow Spaces | Dead |
| `osascript "set index of window N to 1"` (Ghostty) | Raise specific window | Ghostty's AppleScript dictionary is read-only — `set index` errors out | Dead |
| `osascript System Events AXRaise of window N` | Raise via Accessibility | AX cross-Space window enumeration is blocked; only the visible-Space window appears, so window 2 doesn't exist from AX's view | Dead |
| zsh `printf '\033]2;...'` to set Ghostty window title | Tag windows for matching | zellij intercepts OSC 0/2 by design (per-pane title isolation), the escape never reaches the parent terminal | Dead |
| Ghostty CLI / IPC | Programmatic window control | Ghostty has no `+activate-window`/`+focus-window` action; only `+new-window` | Dead |
| **yabai with scripting addition** | Cross-Space window control | Patches SkyLight at runtime, exposes `yabai -m window --focus <id>` that works correctly across Spaces | ✅ Used |

yabai itself requires:
- SIP disabled (`csrutil disable` from Recovery)
- On Apple Silicon: NVRAM `boot-args=-arm64e_preview_abi` + a reboot, otherwise
  `yabai --load-sa` errors with "missing required nvram boot-arg"
- A sudoers rule so the launchd service can `--load-sa` automatically at login

This is a hard cost, but the trade-off is worth it for users who run multiple
zellij sessions across multiple Ghostty windows on different Spaces — the only
known software-only path to the desired UX.

### Three subtle bugs caught during development

1. **`hs.execute` hangs on macOS 26 Tahoe.** `hs -c 'hs.execute(...)'` returns
   "receive timeout" via the IPC port. All execution sites use
   `hs.task.new("/bin/sh", callback, {"-c", cmd}):start()` instead.

2. **`zellij action focus-pane-with-id` was renamed.** As of zellij 0.44.x the
   subcommand is `focus-pane-id`. Old name returns exit code 2 with "wasn't
   recognized". The error is silent under the click callback unless you log
   stderr explicitly (see the `TASK_DONE` log line — v0.2.0 captures stderr
   contents, not just length).

3. **`zellij ... action focus-pane-id N` returns exit 2 with "Pane Terminal(N)
   is already focused" when N is already the active pane.** This is _expected_
   after a successful `yabai -m window --focus`: the yabai segment moves you to
   the right window where zellij already has the right pane focused, so the
   zellij call is a no-op. Don't treat exit=2 here as failure.

### File layout

```
Coding-Done-Alert/
├── hooks/
│   ├── notify.py                      # Stop-hook entry point.
│   │                                  # Reads stdin + config, plays sound,
│   │                                  # composes clickCmd (yabai + zellij),
│   │                                  # calls Hammerspoon via `hs -c`.
│   └── zsh_precmd_record.sh           # zsh precmd snippet.
│                                      # Per-prompt: write current Ghostty
│                                      # yabai window id to
│                                      # /tmp/zellij_yabai/<session>.
├── hammerspoon/
│   └── coding_done_alert.lua          # Defines global codingDoneAlert(...).
│                                      # Maintains a bounded notification table
│                                      # to prevent GC of pending notifications.
├── bin/
│   └── extract_applause.sh            # User-side audio extraction. Never
│                                      # bundles copyrighted material.
├── examples/
│   ├── claude-code-stop-hook.json
│   ├── codex-cli-hook.toml
│   └── config.example.json
├── install.sh / uninstall.sh
└── docs/
    ├── ARCHITECTURE.md                # This file
    ├── INSTALL.md
    └── TROUBLESHOOTING.md
```

### Trade-offs

- **Hammerspoon + yabai dual dependency.** ~13 MB Hammerspoon + ~2 MB yabai.
  yabai requires SIP disable on Apple Silicon — a hard one-time cost. We
  considered but rejected: terminal-notifier (dead on Tahoe), custom .app +
  UNUserNotificationCenter ($99/yr signature), keyboard-simulation Space
  switching (fragile, conflicts with app shortcuts), and asking the user to
  switch desktops manually (defeats the purpose).
- **Side-channel mapping file** (`/tmp/zellij_yabai/<session>`). Lives in
  `/tmp` so it auto-clears on reboot, regenerated by zsh on first prompt.
  Cheap, race-free for our use case.
- **Synchronous IPC for the trigger.** `hs -c "..."` blocks until Hammerspoon
  ACKs (8s timeout). Acceptable for a hook that runs once per task end. The
  click cmd execution is fully async via `hs.task`.
- **No deduplication across simultaneous tasks.** Each notification owns its
  own closure carrying the click cmd. Sending 5 notifications from 5 panes
  works correctly; they don't overwrite each other.
- **Graceful degradation when yabai is missing.** The `clickCmd` shell guards
  the yabai call with `[ -n "$WID" ] && [ -x yabai_bin ]`, so without yabai
  the same-Space zellij focus still works (you just lose cross-Space pull).

---

## 中文

### 组件视图（v0.2.0）

```
┌──────────────────────────┐
│  AI/CLI 工具任务结束     │
│  (Claude Code Stop hook, │
│  Codex 生命周期 hook 等) │
└────────────┬─────────────┘
             │ stdin: {"last_assistant_message": "..."}
             │ env:   ZELLIJ_SESSION_NAME, ZELLIJ_PANE_ID
             ▼
┌──────────────────────────┐
│ ~/.local/bin/            │
│   coding-done-alert      │   ← Python 3.9+
│   (hooks/notify.py)      │   ← 读 ~/.config/coding-done-alert/config.json
└────────────┬─────────────┘
             │ 1. afplay <声音文件>            (独立链路，DND 也响)
             │ 2. hs -c 'codingDoneAlert(...)'  (同步 IPC，≤8s 超时)
             │      └ clickCmd 在这里编（zellij focus + 可选 yabai）
             ▼
┌──────────────────────────┐
│  Hammerspoon（签名 .app  │
│  常驻进程）              │
│  ~/.hammerspoon/         │
│    coding_done_alert.lua │
└────────────┬─────────────┘
             │ hs.notify.new(...) → 弹横幅
             │ 点击时:
             │   app:activate(true)              ← 同 Space 兜底
             │   hs.task.new("/bin/sh", clickCmd) ← 异步，捕获 stderr
             ▼
┌──────────────────────────────────────────────────────┐
│ /bin/sh -c clickCmd                                  │
│   WID=$(cat /tmp/zellij_yabai/<session>)             │
│   if WID 存在且 yabai 可执行:                        │
│     yabai -m window --focus "$WID"  ← 跨 Space       │
│   zellij --session <s> action focus-pane-id <p>      │
└──────────────────────────────────────────────────────┘

侧信道映射由 zsh 维护:
  ┌────────────────────────────────────────────────┐
  │ zellij 内部的 zsh (precmd hook)                │
  │   每次 prompt 显示前:                          │
  │     wid = yabai -m query --windows --window    │
  │     echo $wid > /tmp/zellij_yabai/<session>    │
  └────────────────────────────────────────────────┘
```

### 为什么走 yabai（其他方案在 macOS 26 全死）

v0.1.0 假设 `hs.application:activate(true)` 能跟随 App 切到它所在的 Space。
macOS 26 (Tahoe) 收紧 SkyLight 私有 API 后这个假设崩了。能试的都试了：

| 工具 | 想做什么 | macOS 26 实际行为 | 状态 |
| --- | --- | --- | --- |
| `hs.spaces.gotoSpace` / `moveWindowToSpace` | 切桌面、移窗口 | 调用成功但视觉无效 — 整个 `hs.spaces` 模块功能性死亡，连只读 `activeSpace()` 都返回 `nil` | 死 |
| `hs.application:activate(true)` | 跨 Space 拉前台 | 只在当前 Space 内拉前台；不切 Space | 跨 Space 死，留作同 Space 兜底 |
| `osascript "tell App to activate"` | 跨 Space 拉前台 | 同上；AppleScript activate 不跟随 Space | 死 |
| `osascript "set index of window N to 1"` (Ghostty) | 提升指定窗口 | Ghostty 的 AppleScript 字典只读 — `set index` 直接报错 | 死 |
| `osascript System Events AXRaise of window N` | 通过 AX 拉窗口 | AX 跨 Space 窗口枚举被屏蔽；只能看到当前可见 Space 的窗口，所以从 AX 视角根本不存在 window 2 | 死 |
| zsh `printf '\033]2;...'` 设 Ghostty 窗口标题 | 给窗口打标签便于匹配 | zellij 设计上拦截 OSC 0/2（每个 pane 标题独立隔离），escape 序列不会传到外层终端 | 死 |
| Ghostty CLI / IPC | 用命令行控窗口 | Ghostty 没有 `+activate-window`/`+focus-window` action，只有 `+new-window` | 死 |
| **yabai + scripting addition** | 跨 Space 窗口控制 | 运行时 patch SkyLight，提供 `yabai -m window --focus <id>` 跨 Space 真切 | ✅ 当前方案 |

yabai 本身需要：
- 关 SIP（在 Recovery Mode 跑 `csrutil disable`）
- Apple Silicon 还要 NVRAM `boot-args=-arm64e_preview_abi` + 重启，否则
  `yabai --load-sa` 报 "missing required nvram boot-arg"
- 一条 sudoers 规则让 launchd service 开机自动 `--load-sa` 不弹密码

这是硬成本，但对在多个桌面跑多个 zellij session + 多个 Ghostty 窗口的用户
来说，trade-off 值 — 这是已知唯一软件层能实现需求体验的路径。

### 开发过程中踩到的三个隐蔽坑

1. **`hs.execute` 在 macOS 26 Tahoe 挂起。** `hs -c 'hs.execute(...)'` 通过 IPC
   端口返回 "receive timeout"。所有执行点改成
   `hs.task.new("/bin/sh", callback, {"-c", cmd}):start()`。

2. **`zellij action focus-pane-with-id` 被改名了。** zellij 0.44.x 起子命令叫
   `focus-pane-id`。旧名返回 exit code 2 + "wasn't recognized"。在 click
   callback 下这个错误是静默的（除非显式记 stderr）— v0.2.0 的 `TASK_DONE`
   日志已经把 stderr 内容记进去了，不用再手动复跑命令。

3. **`zellij ... action focus-pane-id N` 在 N 已经是当前 pane 时返回 exit 2 +
   "Pane Terminal(N) is already focused"。** 这在 yabai 切完窗口后是 _预期_
   行为：yabai 把你切到了对的窗口，那个窗口的 zellij 已经在对的 pane 上，所以
   zellij focus 是 no-op。**不要把这条 exit=2 当失败**。

### 目录布局

```
Coding-Done-Alert/
├── hooks/
│   ├── notify.py                      # Stop hook 入口
│   │                                  # 读 stdin + 配置，播声音
│   │                                  # 编 clickCmd（yabai + zellij）
│   │                                  # 通过 `hs -c` 调 Hammerspoon
│   └── zsh_precmd_record.sh           # zsh precmd 脚本
│                                      # 每次 prompt 把当前 Ghostty 的
│                                      # yabai 窗口 id 写到
│                                      # /tmp/zellij_yabai/<session>
├── hammerspoon/
│   └── coding_done_alert.lua          # 定义全局 codingDoneAlert(...)
│                                      # 维护一个有界通知表防 GC
├── bin/
│   └── extract_applause.sh            # 用户侧音频提取，不打包版权素材
├── examples/
│   ├── claude-code-stop-hook.json
│   ├── codex-cli-hook.toml
│   └── config.example.json
├── install.sh / uninstall.sh
└── docs/
    ├── ARCHITECTURE.md                # 本文档
    ├── INSTALL.md
    └── TROUBLESHOOTING.md
```

### 取舍

- **Hammerspoon + yabai 双依赖。** Hammerspoon ~13 MB + yabai ~2 MB。yabai 在
  Apple Silicon 上需要关 SIP — 一次性硬成本。考虑过但 reject 的：
  terminal-notifier（Tahoe 死）、自编 .app + UNUserNotificationCenter（$99/年
  签名）、模拟键盘快捷键切 Space（脆弱，跟 app 快捷键冲突）、让用户手动切
  桌面（违背工具初衷）
- **侧信道映射文件**（`/tmp/zellij_yabai/<session>`）。放 `/tmp` 是有意的 —
  重启自动清，zsh 在下一次 prompt 时再生。便宜、对当前用法无 race
- **触发用同步 IPC。** `hs -c "..."` 阻塞到 Hammerspoon ACK（8 秒超时）。对
  每次任务结束跑一次的 hook 来说可接受。click cmd 内部的命令执行是完全异步
  的（`hs.task`）
- **不做并发任务去重。** 每个通知用闭包独立持有 click cmd。5 个 pane 同时发
  5 个通知互不覆盖
- **没装 yabai 也能优雅降级。** `clickCmd` 用 `[ -n "$WID" ] && [ -x yabai_bin ]`
  保护 yabai 调用，没装 yabai 时同 Space 内的 zellij focus 仍然工作（只是失去
  跨 Space 拉窗口能力）
