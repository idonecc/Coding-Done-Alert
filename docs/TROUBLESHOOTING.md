# Troubleshooting / 排错指南

## English

### Diagnostic logs

| File | When written | What to check |
| --- | --- | --- |
| `/tmp/coding_done_alert.log` | Every Hammerspoon callback | `NOTIFY` (sent), `CALLBACK` (clicked), `ACTIVATE` (terminal raised), `TASK_DONE` (cmd exit code) |
| stderr of `coding-done-alert` | When invoked via `Bash` directly | Sound file missing, hs CLI not found, IPC timeout |

Tail it while testing:

```bash
tail -f /tmp/coding_done_alert.log
```

### No banner appears

1. **Permission**: System Settings → Notifications → find **Hammerspoon** → enable; set "Alert style" to **Persistent** (so banners don't auto-dismiss before you can click).
2. **Hammerspoon running?** `pgrep -fl Hammerspoon`. If not: `open -a Hammerspoon`.
3. **Module loaded?** `hs -c 'return type(codingDoneAlert)'` should print `function`. If `nil`, your `init.lua` is missing `require("coding_done_alert")`.
4. **Reload after editing `init.lua`**: `hs -c 'hs.reload()'`. The `hammerspoon://reload` URL scheme has been observed to silently no-op on some macOS 26 builds.

### No sound

1. Confirm `~/.config/coding-done-alert/config.json` has `sound.enabled: true`.
2. Confirm the file at `sound.file` exists: `ls -la "$(jq -r .sound.file ~/.config/coding-done-alert/config.json | sed "s|~|$HOME|")"`.
3. Test the file directly: `afplay "$HOME/Library/Sounds/Applause.aiff"`.
4. macOS Focus modes can suppress notification sounds. The `afplay` path is independent and ignores DND, so if you hear nothing at all, it's the file path.

### Click does nothing

1. Tail the log while clicking: `tail -f /tmp/coding_done_alert.log`. You should see `CALLBACK` rows.
2. If you see `CALLBACK` but no `TASK_DONE`: the cmd is invalid. The log line directly above shows what was attempted.
3. If `TASK_DONE | exit=2` and your terminal is zellij, check the zellij version: `zellij --version`. Versions older than 0.44 use a different subcommand name.
4. Run the click cmd manually in any shell to see the real error:
   ```bash
   /opt/homebrew/bin/zellij --session "$ZELLIJ_SESSION_NAME" action focus-pane-id "$ZELLIJ_PANE_ID"
   ```
   `Pane Terminal(N) is already focused` is success when N is the current pane — it's just a no-op.

### Click works but doesn't switch Spaces

This was the original symptom that drove choosing `hs.application:activate(true)` over `osascript`. If you still hit it:

1. Verify `coding_done_alert.lua` contains `app:activate(true)` (with `true`).
2. The terminal app must already be running. If not, `hs.task.new("/usr/bin/open", nil, {"-a", terminalApp}):start()` is used as fallback, which honors macOS Space-switching settings.
3. Check System Settings → Desktop & Dock → Mission Control → ensure "When switching to an application, switch to a Space with open windows for the application" is **on** (it should be on by default).

### `hs -c` hangs

Hammerspoon may be locked up. Restart it:

```bash
killall Hammerspoon
open -a Hammerspoon
```

If it consistently hangs after editing `init.lua`, you have a Lua syntax error in your config. Open Hammerspoon's Console (menu bar icon → Console…) for the error message.

---

## 中文

### 诊断日志

| 文件 | 写入时机 | 看什么 |
| --- | --- | --- |
| `/tmp/coding_done_alert.log` | Hammerspoon 每次 callback | `NOTIFY`（发出）、`CALLBACK`（点击）、`ACTIVATE`（终端激活）、`TASK_DONE`（cmd 退出码） |
| `coding-done-alert` stderr | 直接 Bash 调用时 | 声音文件不存在、hs CLI 找不到、IPC 超时 |

实时跟踪：

```bash
tail -f /tmp/coding_done_alert.log
```

### 没弹横幅

1. **权限**：系统设置 → 通知 → 找 **Hammerspoon** → 打开通知；「提醒样式」选 **持续**（横幅不自动消失，给你时间点击）
2. **Hammerspoon 在跑吗？** `pgrep -fl Hammerspoon`。没跑：`open -a Hammerspoon`
3. **模块加载了吗？** `hs -c 'return type(codingDoneAlert)'` 应输出 `function`。如果 `nil`，你的 `init.lua` 没 `require("coding_done_alert")`
4. **改完 `init.lua` 必须重新加载**：`hs -c 'hs.reload()'`。`hammerspoon://reload` URL scheme 在某些 macOS 26 子版本上会静默无效

### 没声音

1. 确认 `~/.config/coding-done-alert/config.json` 里 `sound.enabled: true`
2. 确认 `sound.file` 路径下文件存在：`ls -la "$(jq -r .sound.file ~/.config/coding-done-alert/config.json | sed "s|~|$HOME|")"`
3. 直接测：`afplay "$HOME/Library/Sounds/Applause.aiff"`
4. macOS 专注模式会压制通知声音。但 `afplay` 这条独立链路不受 DND 影响 — 如果完全听不到声音，是文件路径错了

### 点击没反应

1. 边点边看日志：`tail -f /tmp/coding_done_alert.log`，应该看到 `CALLBACK` 行
2. 看到 `CALLBACK` 但没 `TASK_DONE`：cmd 无效。上面那条 log 显示尝试执行的内容
3. `TASK_DONE | exit=2` + 用 zellij：检查 zellij 版本 `zellij --version`。0.44 以下子命令名不一样
4. 在普通 shell 里手动跑一次 click cmd 看真实错误：
   ```bash
   /opt/homebrew/bin/zellij --session "$ZELLIJ_SESSION_NAME" action focus-pane-id "$ZELLIJ_PANE_ID"
   ```
   `Pane Terminal(N) is already focused` 是成功 — 只是当前已经在那个 pane，等价于 no-op

### 点击有效但不跨 Space

这正是当初放弃 `osascript` 选 `hs.application:activate(true)` 的核心原因。如果还是不切：

1. 确认 `coding_done_alert.lua` 里是 `app:activate(true)`（带 `true`）
2. 终端 app 必须已经在跑。没跑会 fallback 到 `open -a`，那条路径遵守 macOS 系统设置
3. 系统设置 → 桌面与程序坞 → 调度中心 → 确认「切换到某个应用时，切换到具有该应用打开窗口的空间」**打开**（默认开着）

### `hs -c` 卡住

Hammerspoon 可能锁死。重启：

```bash
killall Hammerspoon
open -a Hammerspoon
```

如果改完 `init.lua` 后一直卡，说明 Lua 有语法错误。打开 Hammerspoon Console（菜单栏图标 → Console…）看报错。
