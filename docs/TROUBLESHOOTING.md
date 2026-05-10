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
4. v0.2.0+ logs full stderr in the `TASK_DONE` line — read `stderr=[...]` directly instead of re-running by hand.
5. `Pane Terminal(N) is already focused` is success — see "exit=2 is expected after a yabai pull" below.

### Click works but doesn't switch Spaces (v0.2.0+, yabai path)

If the banner appears, click is registered (`CALLBACK` in log), but the wrong Space stays visible:

1. **Mapping file present?**
   ```bash
   cat /tmp/zellij_yabai/<session_name>
   ```
   Empty / missing → the zsh precmd hook hasn't written the mapping. Open the affected zellij session, hit Enter once at any zsh prompt, re-check.
2. **Hook actually loaded?** From a zsh prompt inside zellij:
   ```bash
   typeset -f _coding_done_alert_record_window
   ```
   Empty output → `~/.zshrc` doesn't `source hooks/zsh_precmd_record.sh`. Re-run `install.sh` or add it manually.
3. **yabai healthy?**
   ```bash
   yabai -m query --windows | head
   ```
   Errors here mean yabai itself is broken — see "yabai errors" below.
4. **Stale window id?** Ghostty was closed and reopened, but the mapping still points at the old id. Trigger a refresh: focus the affected zellij pane, press Enter at zsh, check the file mtime updated.

### Click works but doesn't switch Spaces (legacy, no yabai)

Without yabai cross-Space pull is impossible on macOS 26 — `hs.spaces` is dead and `app:activate(true)` doesn't switch desktops. The notifier degrades to a same-Space-only tool. If you need cross-Space, install yabai (see `docs/INSTALL.md` step 0).

### `TASK_DONE | exit=2 stderr=[Pane Terminal(N) is already focused ...]`

**This is success, not failure.** After a successful `yabai -m window --focus`, the zellij client at the target window already has the right pane focused, so the subsequent `zellij ... focus-pane-id N` is a no-op and zellij returns exit 2 to say "nothing to do". Don't treat this as an error.

### yabai errors

| Error | Cause | Fix |
| --- | --- | --- |
| `yabai: missing required nvram boot-arg '-arm64e_preview_abi'!` | NVRAM boot-arg not set or not yet in effect (Apple Silicon) | `sudo nvram boot-args=-arm64e_preview_abi` then **reboot** |
| `Could not load scripting addition payload` (after macOS minor update) | SA invalidated by system update | `sudo yabai --uninstall-sa && sudo yabai --load-sa` |
| `error: yabai is not running` | launchd service not started | `yabai --start-service` |
| Permission denied / no AX response | yabai missing Accessibility permission | System Settings → Privacy & Security → Accessibility → toggle yabai on |

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
4. v0.2.0+ 已经把完整 stderr 写进 `TASK_DONE` 行 — 直接看 `stderr=[...]`，不用再手动复跑命令
5. `Pane Terminal(N) is already focused` 是成功 — 见下面「yabai 拉窗口后 exit=2 是预期」

### 点击有效但不跨 Space（v0.2.0+，yabai 路径）

横幅弹了，点击被记录了（log 有 `CALLBACK`），但桌面没切：

1. **映射文件存在吗？**
   ```bash
   cat /tmp/zellij_yabai/<session 名>
   ```
   空 / 不存在 → zsh precmd hook 没写映射。打开受影响的 zellij session，在任何 zsh prompt 按一次回车，再次检查
2. **hook 真的加载了吗？** 在 zellij 里的 zsh prompt 跑：
   ```bash
   typeset -f _coding_done_alert_record_window
   ```
   输出为空 → `~/.zshrc` 里没 `source hooks/zsh_precmd_record.sh`。重跑 `install.sh` 或手动加
3. **yabai 健康吗？**
   ```bash
   yabai -m query --windows | head
   ```
   这里报错说明 yabai 本身坏了 — 见下面「yabai 错误」
4. **窗口 id stale？** Ghostty 被关了重开，但映射还指向旧 id。触发刷新：focus 受影响的 zellij pane，在 zsh 按回车，检查文件 mtime 是否更新

### 点击有效但不跨 Space（旧版，没装 yabai）

不装 yabai，跨 Space 在 macOS 26 上不可能 — `hs.spaces` 已死，`app:activate(true)` 也不切桌面。本工具会优雅降级为「只在当前可见 Space 内 focus」的工具。如果需要跨 Space，装 yabai（见 `docs/INSTALL.md` 步骤 0）。

### `TASK_DONE | exit=2 stderr=[Pane Terminal(N) is already focused ...]`

**这是成功，不是失败。** yabai 切完窗口后，目标窗口的 zellij client 已经在对的 pane 上，所以后续的 `zellij ... focus-pane-id N` 是 no-op，zellij 用 exit 2 表达「无事可做」。不要把这条当作错误。

### yabai 错误

| 错误 | 原因 | 修复 |
| --- | --- | --- |
| `yabai: missing required nvram boot-arg '-arm64e_preview_abi'!` | NVRAM boot-arg 没设或还没生效（Apple Silicon） | `sudo nvram boot-args=-arm64e_preview_abi` 然后**重启** |
| `Could not load scripting addition payload`（macOS 小版本升级后） | SA 被系统升级失效 | `sudo yabai --uninstall-sa && sudo yabai --load-sa` |
| `error: yabai is not running` | launchd 服务没起 | `yabai --start-service` |
| 权限被拒 / AX 不响应 | yabai 没拿到辅助功能权限 | 系统设置 → 隐私与安全性 → 辅助功能 → 勾上 yabai |

### `hs -c` 卡住

Hammerspoon 可能锁死。重启：

```bash
killall Hammerspoon
open -a Hammerspoon
```

如果改完 `init.lua` 后一直卡，说明 Lua 有语法错误。打开 Hammerspoon Console（菜单栏图标 → Console…）看报错。
