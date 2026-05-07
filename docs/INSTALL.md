# Detailed installation

## English

For most users `bash install.sh` is enough. This file walks through what each step does and how to do it manually.

### 1. Hammerspoon

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Hammerspoon will appear in your menu bar. Click the icon → Preferences. **Optional**: enable "Launch Hammerspoon at login" so the notifier survives reboots without a manual nudge.

You do **not** need to grant Accessibility permission unless you plan to extend this with hotkeys/window management. The notifier itself only uses `hs.notify`, `hs.application:activate`, and `hs.task` — none of which require Accessibility.

### 2. Hook script

```bash
mkdir -p ~/.local/bin
cp hooks/notify.py ~/.local/bin/coding-done-alert
chmod +x ~/.local/bin/coding-done-alert
```

Make sure `~/.local/bin` is in your PATH. zsh users can add to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 3. Hammerspoon module

```bash
mkdir -p ~/.hammerspoon
cp hammerspoon/coding_done_alert.lua ~/.hammerspoon/coding_done_alert.lua
```

Then load it from `~/.hammerspoon/init.lua` (create the file if it doesn't exist):

```lua
require("coding_done_alert")
```

Reload:

```bash
hs -c 'hs.reload()'
```

### 4. Configuration

```bash
mkdir -p ~/.config/coding-done-alert
cp examples/config.example.json ~/.config/coding-done-alert/config.json
```

Edit to taste. See README.md for the full schema.

### 5. Wire up your tool

#### Claude Code

Append to `~/.claude/settings.json` under `hooks.Stop`:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/opt/homebrew/bin/python3 /Users/YOUR_USERNAME/.local/bin/coding-done-alert"
      }]
    }]
  }
}
```

#### Codex CLI

Codex's lifecycle hook syntax depends on the version you have. Conceptually you want:

```bash
codex run --on-task-end "/opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert"
```

Or wrap the notifier in a shell script that pipes a custom summary to it:

```bash
#!/bin/sh
# /usr/local/bin/notify-task-done
SUMMARY="$1"
echo "{\"last_assistant_message\":\"$SUMMARY\"}" | /opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert
```

#### Anything else

The notifier reads `last_assistant_message` from stdin (JSON). Title and pane info are auto-detected from `ZELLIJ_SESSION_NAME` and `ZELLIJ_PANE_ID` environment variables. Any tool that can pipe one JSON line and inherit those env vars can drive it.

---

## 中文

绝大多数用户跑 `bash install.sh` 就完事了。这份文档说明每一步做了什么、怎么手工做。

### 1. 装 Hammerspoon

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Hammerspoon 会出现在菜单栏。点图标 → Preferences。**建议**勾选 "Launch Hammerspoon at login"，重启后不用手动拉起。

**不需要**给辅助功能权限（除非你想扩展用全局热键 / 窗口管理）。本工具只用 `hs.notify`、`hs.application:activate`、`hs.task`，这三个都不需要辅助功能权限。

### 2. 装 hook 脚本

```bash
mkdir -p ~/.local/bin
cp hooks/notify.py ~/.local/bin/coding-done-alert
chmod +x ~/.local/bin/coding-done-alert
```

确保 `~/.local/bin` 在 PATH 里。zsh 用户可在 `~/.zshrc` 加：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 3. 装 Hammerspoon 模块

```bash
mkdir -p ~/.hammerspoon
cp hammerspoon/coding_done_alert.lua ~/.hammerspoon/coding_done_alert.lua
```

在 `~/.hammerspoon/init.lua`（没有就建）追加：

```lua
require("coding_done_alert")
```

重新加载：

```bash
hs -c 'hs.reload()'
```

### 4. 配置

```bash
mkdir -p ~/.config/coding-done-alert
cp examples/config.example.json ~/.config/coding-done-alert/config.json
```

按需改。完整字段说明见 README.md。

### 5. 接入你的工具

#### Claude Code

在 `~/.claude/settings.json` 的 `hooks.Stop` 下追加：

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/opt/homebrew/bin/python3 /Users/你的用户名/.local/bin/coding-done-alert"
      }]
    }]
  }
}
```

#### Codex CLI

Codex 的生命周期 hook 语法因版本而异。原理上：

```bash
codex run --on-task-end "/opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert"
```

或者用一个壳脚本把自定义摘要 pipe 进去：

```bash
#!/bin/sh
# /usr/local/bin/notify-task-done
SUMMARY="$1"
echo "{\"last_assistant_message\":\"$SUMMARY\"}" | /opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert
```

#### 任意其他工具

工具从 stdin（JSON）读 `last_assistant_message` 字段；标题和 pane 信息从 `ZELLIJ_SESSION_NAME`、`ZELLIJ_PANE_ID` 两个环境变量自动取。任何能 pipe 一行 JSON + 继承这俩 env 的工具都能驱动它。
