# Architecture / 设计说明

## English

### Component diagram

```
┌──────────────────────────┐
│  AI/CLI tool finishes    │
│  (Claude Code Stop hook, │
│  Codex lifecycle, etc.)  │
└────────────┬─────────────┘
             │ stdin: {"last_assistant_message": "..."}
             ▼
┌──────────────────────────┐
│ ~/.local/bin/            │
│   coding-done-alert      │   ← Python 3.9+
│   (hooks/notify.py)      │   ← reads ~/.config/coding-done-alert/config.json
└────────────┬─────────────┘
             │ 1. afplay <sound.file>            (independent — works in DND)
             │ 2. hs -c 'codingDoneAlert(...)'   (sync IPC, ≤8s timeout)
             ▼
┌──────────────────────────┐
│  Hammerspoon (signed     │
│  .app, persistent)       │
│  ~/.hammerspoon/         │
│    coding_done_alert.lua │
└────────────┬─────────────┘
             │ hs.notify.new(...) → banner
             │ on click:
             │   hs.application:activate(true)   ← cross-Space
             │   hs.task.new("/bin/sh", ...)     ← async, no hang
             ▼
┌──────────────────────────┐
│  Ghostty (or any term)   │
│  + zellij action         │
│    focus-pane-id <N>     │
└──────────────────────────┘
```

### Why every other tool failed on macOS 26

| Tool | Problem | Status |
| --- | --- | --- |
| `terminal-notifier` 2.0.0 | 2017 build; macOS 26 accepts the notification but does not render a banner. Verified via `terminal-notifier -list ALL`: notifications appear in Notification Center but never on screen. | Dead on Tahoe |
| `osascript display notification` | Banner renders fine, but the API has no click-callback hook. Cannot trigger pane jump. | Visibility only |
| `osascript display alert` | Modal dialog. Steals focus, breaks flow. | Too intrusive |
| Custom `.app` using `UNUserNotificationCenter` | `requestAuthorization` is silently denied for ad-hoc signed `.app` bundles in macOS 26. Authorisation prompt never appears. Apple Developer signature ($99/yr) required. | Blocked by signing |
| Custom `.app` using `NSUserNotification` (legacy) | Compiles, runs, returns success. But macOS 26's notification daemon does not register the bundle as a notification source — banner never shown. | Empty no-op |
| Hammerspoon `hs.notify` + `hs.execute` | `hs.notify` works (Hammerspoon is properly signed). But `hs.execute(cmd, true)` hangs indefinitely on macOS 26 — blocks the Lua main thread, click callback returns but command never runs. | Partial |
| Hammerspoon `hs.notify` + `hs.task` | **Works.** `hs.task.new(...)` spawns processes asynchronously without blocking. | ✅ Used |

### Three subtle bugs caught during development

1. **`hs.execute` hangs on macOS 26 Tahoe.** `hs -c 'hs.execute(...)'` returns "receive timeout" via the IPC port. Verified by replacing all execution sites with `hs.task.new("/bin/sh", callback, {"-c", cmd}):start()`.

2. **`zellij action focus-pane-with-id` was renamed.** As of zellij 0.44.x the subcommand is `focus-pane-id`. Old name returns exit code 2 with "wasn't recognized". The error is silent under the click callback because stderr is dropped — must be inspected via `2>>logfile` or `hs.task` callback's third argument.

3. **`osascript 'tell App to activate'` does not follow Spaces.** Even with "When switching to an application, switch to a Space with open windows for the application" enabled, the AppleScript activate path is unreliable across desktops. `hs.application:activate(true)` (note `allWindows=true`) is the only thing that consistently raises and switches Space.

### File layout

```
Coding-Done-Alert/
├── hooks/notify.py                # Stop-hook entry point. Reads stdin + config,
│                                  # plays sound, calls Hammerspoon via `hs -c`.
├── hammerspoon/
│   └── coding_done_alert.lua      # Defines global codingDoneAlert(...).
│                                  # Maintains a bounded notification table to
│                                  # prevent GC of pending notifications.
├── bin/
│   └── extract_applause.sh        # User-side audio extraction. Never bundles
│                                  # copyrighted material.
├── examples/
│   ├── claude-code-stop-hook.json
│   ├── codex-cli-hook.toml
│   └── config.example.json
├── install.sh / uninstall.sh
└── docs/
    ├── ARCHITECTURE.md            # This file
    └── TROUBLESHOOTING.md
```

### Trade-offs

- **Hammerspoon dependency.** ~13 MB, but signed and stable. Alternatives (alerter, terminal-notifier, custom .app) all failed on macOS 26.
- **Synchronous IPC for the trigger.** `hs -c "..."` blocks until Hammerspoon ACKs (≤8s timeout in code). Acceptable for a hook that runs once per task end. The actual command execution inside the click callback is fully async via `hs.task`.
- **No deduplication across simultaneous tasks.** Each notification owns its own closure carrying the click cmd. Sending 5 notifications from 5 panes works correctly; they don't overwrite each other.

---

## 中文

### 组件视图

```
┌──────────────────────────┐
│  AI/CLI 工具任务结束     │
│  (Claude Code Stop hook, │
│  Codex 生命周期 hook等)  │
└────────────┬─────────────┘
             │ stdin: {"last_assistant_message": "..."}
             ▼
┌──────────────────────────┐
│ ~/.local/bin/            │
│   coding-done-alert      │   ← Python 3.9+
│   (hooks/notify.py)      │   ← 读 ~/.config/coding-done-alert/config.json
└────────────┬─────────────┘
             │ 1. afplay <声音文件>          (独立链路，DND 也响)
             │ 2. hs -c 'codingDoneAlert()'  (同步 IPC，最长 8 秒)
             ▼
┌──────────────────────────┐
│  Hammerspoon（签名 .app  │
│  常驻进程）              │
│  ~/.hammerspoon/         │
│    coding_done_alert.lua │
└────────────┬─────────────┘
             │ hs.notify.new(...) → 弹横幅
             │ 点击时:
             │   hs.application:activate(true)  ← 跨 Space
             │   hs.task.new("/bin/sh", ...)    ← 异步，不挂起
             ▼
┌──────────────────────────┐
│  Ghostty（或任意终端）+  │
│  zellij action           │
│  focus-pane-id <N>       │
└──────────────────────────┘
```

### 为什么其他工具在 macOS 26 都不行

| 工具 | 问题 | 状态 |
| --- | --- | --- |
| `terminal-notifier` 2.0.0 | 2017 年构建；macOS 26 接收通知但不渲染横幅。`-list ALL` 能看到记录，屏幕上始终不出现 | Tahoe 死 |
| `osascript display notification` | 横幅正常弹，但 API 没有点击回调钩子。无法触发跳转 | 可见但不可点 |
| `osascript display alert` | 模态对话框，抢焦点，打断流程 | 侵入性太强 |
| 自编 `.app` + `UNUserNotificationCenter` | `requestAuthorization` 在 ad-hoc 签名 .app 下被静默拒绝，连授权对话框都不弹。要 $99/年的 Apple Developer 签名 | 卡在签名 |
| 自编 `.app` + `NSUserNotification`（旧 API） | 能编译运行返回成功，但 macOS 26 的通知守护进程不把这个 bundle 注册为通知源，横幅根本不会显示 | 空操作 |
| Hammerspoon `hs.notify` + `hs.execute` | `hs.notify` 工作（Hammerspoon 是合法签名），但 `hs.execute(cmd, true)` 在 macOS 26 上无限挂起 — 阻塞 Lua 主线程，callback 返回但 cmd 永不执行 | 半成功 |
| Hammerspoon `hs.notify` + `hs.task` | **工作。** `hs.task.new(...)` 异步 spawn 进程不阻塞 | ✅ 当前方案 |

### 开发过程中踩到的三个隐蔽坑

1. **`hs.execute` 在 macOS 26 Tahoe 挂起。** `hs -c 'hs.execute(...)'` 通过 IPC 端口返回 "receive timeout"。把所有执行点换成 `hs.task.new("/bin/sh", callback, {"-c", cmd}):start()` 后才修复。

2. **`zellij action focus-pane-with-id` 被改名了。** zellij 0.44.x 起子命令叫 `focus-pane-id`。旧名返回 exit code 2 + "wasn't recognized"。在 click callback 下这个错误是静默的（stderr 被丢弃），必须用 `2>>logfile` 或 `hs.task` callback 的第三个参数才能看到。

3. **`osascript 'tell App to activate'` 不跨 Space。** 即使开了「切换 App 时切到有打开窗口的 Space」选项，AppleScript activate 路径在多桌面下也不可靠。只有 `hs.application:activate(true)`（注意 `allWindows=true`）能稳定地把 App 拉到当前 Space 或切到目标 Space。

### 目录布局

```
Coding-Done-Alert/
├── hooks/notify.py                # Stop hook 入口。读 stdin + 配置，
│                                  # 播声音，通过 `hs -c` 调用 Hammerspoon
├── hammerspoon/
│   └── coding_done_alert.lua      # 定义全局 codingDoneAlert(...)
│                                  # 维护一个有界通知表防 GC
├── bin/
│   └── extract_applause.sh        # 用户侧音频提取。永不打包版权素材
├── examples/
│   ├── claude-code-stop-hook.json
│   ├── codex-cli-hook.toml
│   └── config.example.json
├── install.sh / uninstall.sh
└── docs/
    ├── ARCHITECTURE.md            # 本文档
    └── TROUBLESHOOTING.md
```

### 取舍

- **依赖 Hammerspoon。** 约 13 MB，但是签名 + 稳定。其他方案（alerter、terminal-notifier、自编 .app）在 macOS 26 上都失败
- **触发用同步 IPC。** `hs -c "..."` 阻塞到 Hammerspoon ACK（代码里设了 8 秒超时）。对每次任务结束跑一次的 hook 来说可接受。点击 callback 内部的命令执行是完全异步的（`hs.task`）
- **不做并发任务去重。** 每个通知用闭包独立持有 click cmd。5 个 pane 同时发 5 个通知互不覆盖
