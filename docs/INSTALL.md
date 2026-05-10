# Detailed installation

## English

For most users `bash install.sh` is enough. This file walks through what each
step does and how to do it manually, plus the **yabai prerequisites** for
cross-Space click-to-jump (new in v0.2.0).

### Prerequisites

| Component | Required | Why |
| --- | --- | --- |
| macOS 11+ (tested on 26 Tahoe) | yes | Hammerspoon target |
| [Hammerspoon](https://www.hammerspoon.org/) | yes | Banner + click callback |
| [zellij](https://zellij.dev/) | yes | Pane id for click-to-jump |
| Python 3.9+ | yes | Hook runtime |
| sox | optional | Audio trimming for `extract_applause.sh` |
| **[yabai](https://github.com/koekeishiya/yabai)** | optional but **highly recommended** | Cross-Space window focus. Without it, click-to-jump only works on the visible Space. |

> **About yabai.** yabai patches macOS's private SkyLight APIs at runtime to
> control windows across Spaces. This requires disabling System Integrity
> Protection (SIP). **SIP disable is not reversible without a Recovery-Mode
> reboot** — read the section below carefully and decide if cross-Space
> click-to-jump is worth it for you. The same-Space behaviour works fine
> without yabai.

### 0. (Optional, for cross-Space) yabai prerequisites

This is a **one-time** setup. After completing it, future updates of yabai or
this project don't require re-doing these steps (except SA reload after macOS
minor version bumps — see Troubleshooting).

#### 0.1 Disable SIP (must do from Recovery)

1. Save all your work; this requires a reboot.
2. `sudo shutdown -h now`
3. **Press and hold** the power button (Apple Silicon) until "Loading startup
   options" appears. **Do not just press at boot** — Apple Silicon Macs only
   enter Recovery via long-press.
4. Choose Options → Continue → log in.
5. Top menu → Utilities → Terminal.
6. Run:
   ```
   csrutil disable
   ```
   Type `Y` to confirm, enter your macOS password.
7. Verify:
   ```
   csrutil status
   ```
   Should print `System Integrity Protection status: disabled.`
8. Top menu → Restart.

#### 0.2 (Apple Silicon only) Set arm64e_preview_abi NVRAM boot-arg

After SIP is disabled and you're back in normal macOS:

```bash
sudo nvram boot-args=-arm64e_preview_abi
```

Then reboot one more time so the boot-arg takes effect:

```bash
sudo shutdown -r now
```

> Without this, `yabai --load-sa` errors with "missing required nvram
> boot-arg '-arm64e_preview_abi'!". Intel Macs don't need this step.

#### 0.3 Install yabai + load scripting addition + start service

```bash
brew install koekeishiya/formulae/yabai

# install + load scripting addition (asks for sudo password)
sudo yabai --load-sa

# add a sudoers rule so launchd can --load-sa at login without prompting
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d ' ' -f 1) $(which yabai) --load-sa" \
  | sudo tee /etc/sudoers.d/yabai

# register yabai as a launchd-managed service
yabai --start-service
```

macOS will prompt you to grant **Accessibility** permission to yabai —
System Settings → Privacy & Security → Accessibility, toggle yabai on.

Verify:

```bash
yabai -m query --windows | head
```

If you see a JSON list of windows, yabai is healthy. If you see "missing
required nvram boot-arg", go back to step 0.2. If "permission denied" or
similar AX errors, recheck the Accessibility toggle.

> **macOS minor updates** (e.g. 26.4 → 26.5) usually invalidate the
> scripting addition. After such updates, run:
> ```
> sudo yabai --uninstall-sa && sudo yabai --load-sa
> ```

### 1. Hammerspoon

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Hammerspoon will appear in your menu bar. Click the icon → Preferences.
**Optional**: enable "Launch Hammerspoon at login" so the notifier survives
reboots without a manual nudge.

You do **not** need to grant Accessibility permission to Hammerspoon for
this project — the notifier only uses `hs.notify`, `hs.application:activate`,
and `hs.task`.

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

Then load it from `~/.hammerspoon/init.lua` (create the file if missing):

```lua
require("coding_done_alert")
```

Reload:

```bash
hs -c 'hs.reload()'
```

### 4. zsh precmd hook (only if you installed yabai)

The hook keeps a (zellij session → yabai window id) mapping in
`/tmp/zellij_yabai/<session>` so the click handler can pull the right window
across Spaces.

Append to `~/.zshrc`:

```bash
source /absolute/path/to/Coding-Done-Alert/hooks/zsh_precmd_record.sh
```

Then in any new zellij session, hit Enter once. Verify:

```bash
ls /tmp/zellij_yabai/
cat /tmp/zellij_yabai/<your_session_name>
```

You should see the yabai window id of the Ghostty window currently hosting
that zellij session.

### 5. Configuration

```bash
mkdir -p ~/.config/coding-done-alert
cp examples/config.example.json ~/.config/coding-done-alert/config.json
```

Edit to taste. See README.md for the full schema.

### 6. Wire up your tool

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

Codex's lifecycle hook syntax depends on version. Conceptually:

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

The notifier reads `last_assistant_message` from stdin (JSON). Title and pane
info are auto-detected from `ZELLIJ_SESSION_NAME` and `ZELLIJ_PANE_ID`
environment variables. Any tool that can pipe one JSON line and inherit those
env vars can drive it.

---

## 中文

绝大多数用户跑 `bash install.sh` 就完事了。这份文档说明每一步做了什么、怎么手工
做，以及 v0.2.0 新增的 **yabai 前置准备**（用于跨 Space 点击跳转）。

### 系统要求

| 组件 | 必需 | 用途 |
| --- | --- | --- |
| macOS 11+（在 26 Tahoe 测过） | 是 | Hammerspoon 运行环境 |
| [Hammerspoon](https://www.hammerspoon.org/) | 是 | 横幅 + 点击回调 |
| [zellij](https://zellij.dev/) | 是 | 提供 pane id 用于点击定位 |
| Python 3.9+ | 是 | hook 运行时 |
| sox | 可选 | `extract_applause.sh` 截取掌声 |
| **[yabai](https://github.com/koekeishiya/yabai)** | 可选但**强烈推荐** | 跨 Space 窗口 focus。没装的话点击跳转只在当前可见 Space 内有效。 |

> **关于 yabai。** yabai 通过运行时 patch macOS SkyLight 私有 API 来跨 Space
> 控制窗口，需要关闭 SIP（System Integrity Protection）。**关 SIP 不是可逆
> 操作 — 想恢复要再次进 Recovery Mode 跑命令** — 仔细看下面的章节，决定是否
> 值得为跨 Space 点击跳转付出这个成本。不装 yabai 同 Space 内的行为照样工作。

### 0.（可选，用于跨 Space）yabai 前置准备

这是**一次性**配置。装完之后 yabai 或本项目自身的版本升级不需要重做这些步骤
（除了 macOS 小版本升级后要重新 load SA — 见 Troubleshooting）。

#### 0.1 关 SIP（必须从 Recovery Mode 操作）

1. 保存所有未完成的工作，这步要重启
2. `sudo shutdown -h now`
3. **长按**电源键（Apple Silicon Mac）直到出现「正在加载启动选项」。**不是
   开机敲键** — Apple Silicon 只能通过长按电源进 Recovery
4. 选「选项」→ 继续 → 登录
5. 顶部菜单 → 实用工具 → 终端
6. 跑：
   ```
   csrutil disable
   ```
   输 `Y` 确认，输入你的 macOS 登录密码
7. 验证：
   ```
   csrutil status
   ```
   应该显示 `System Integrity Protection status: disabled.`
8. 顶部菜单 → 重新启动

#### 0.2（仅 Apple Silicon）设 arm64e_preview_abi NVRAM boot-arg

关 SIP 重启回到正常 macOS 后：

```bash
sudo nvram boot-args=-arm64e_preview_abi
```

然后再重启一次让 boot-arg 真正生效：

```bash
sudo shutdown -r now
```

> 不做这步，`yabai --load-sa` 会报 "missing required nvram boot-arg
> '-arm64e_preview_abi'!"。Intel Mac 不需要这步。

#### 0.3 装 yabai + 加载 scripting addition + 启动 service

```bash
brew install koekeishiya/formulae/yabai

# install + load scripting addition（要 sudo 密码）
sudo yabai --load-sa

# 加 sudoers 规则，让 launchd 开机自动 --load-sa 不再弹密码
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d ' ' -f 1) $(which yabai) --load-sa" \
  | sudo tee /etc/sudoers.d/yabai

# 把 yabai 注册成 launchd 管理的服务
yabai --start-service
```

macOS 会弹窗要给 yabai **辅助功能权限** — 系统设置 → 隐私与安全性 →
辅助功能，勾上 yabai。

验证：

```bash
yabai -m query --windows | head
```

看到窗口 JSON 列表就表示 yabai 健康。如果报 "missing required nvram
boot-arg" 回去做 0.2。如果报权限相关错误检查辅助功能开关。

> **macOS 小版本升级**（如 26.4 → 26.5）后通常要重装 scripting addition：
> ```
> sudo yabai --uninstall-sa && sudo yabai --load-sa
> ```

### 1. 装 Hammerspoon

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Hammerspoon 出现在菜单栏。点图标 → Preferences。**建议**勾选 "Launch
Hammerspoon at login"，重启后不用手动拉起。

本工具**不需要**给 Hammerspoon 辅助功能权限，只用 `hs.notify`、
`hs.application:activate`、`hs.task` 三个 API。

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

### 4. zsh precmd hook（只有装了 yabai 才需要）

这个 hook 维护 (zellij session → yabai window id) 的映射文件
`/tmp/zellij_yabai/<session>`，点击 handler 用它跨 Space 拉对应窗口。

`~/.zshrc` 末尾追加：

```bash
source /项目的绝对路径/Coding-Done-Alert/hooks/zsh_precmd_record.sh
```

然后在任何新 zellij session 里按一次回车。验证：

```bash
ls /tmp/zellij_yabai/
cat /tmp/zellij_yabai/<你的 session 名>
```

应该看到当前承载该 session 的 Ghostty 窗口的 yabai window id。

### 5. 配置

```bash
mkdir -p ~/.config/coding-done-alert
cp examples/config.example.json ~/.config/coding-done-alert/config.json
```

按需改。完整字段说明见 README.md。

### 6. 接入你的工具

#### Claude Code

`~/.claude/settings.json` 的 `hooks.Stop` 下追加：

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

工具从 stdin（JSON）读 `last_assistant_message` 字段；标题和 pane 信息从
`ZELLIJ_SESSION_NAME`、`ZELLIJ_PANE_ID` 两个环境变量自动取。任何能 pipe 一行
JSON + 继承这俩 env 的工具都能驱动它。
