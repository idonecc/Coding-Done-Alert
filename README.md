# Coding-Done-Alert

[![License: MIT](https://img.shields.io/github/license/idonecc/Coding-Done-Alert?style=flat-square)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert/issues)
[![Repo size](https://img.shields.io/github/repo-size/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert)
[![macOS](https://img.shields.io/badge/macOS-11%2B-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)

> macOS banner + applause + **cross-Space click-to-jump** for long-running terminal tasks. Designed for Claude Code, Codex CLI, or any agentic CLI that wants to stop interrupting your flow.

[English](#english) · [中文](#中文)

## Demo

> _Demo screenshot/GIF coming soon — drop yours at `docs/screenshots/banner.png` and update this section._

---

## English

### What it does

When a long-running task in your terminal finishes, Coding-Done-Alert:

1. **Plays a sound** — Hero by default, optional applause clip.
2. **Pops a persistent banner** — system notification with the pane title and the last assistant message.
3. **Click the banner → jump back** — pulls the right Ghostty/terminal window forward **across macOS Spaces** (via yabai) and uses `zellij action focus-pane-id` to land on the exact pane that finished.

No more polling between the IDE and the browser, missing the moment a build finishes, or wondering which of five running agents is asking for input.

### Why this exists

If you've already tried `terminal-notifier`, you know macOS 26 (Tahoe) silently drops its banners. UNUserNotificationCenter requires an Apple Developer signature ($99/year). The legacy NSUserNotification API has been hollowed out. Hammerspoon — properly signed and actively maintained — is the only path to a working banner with a click callback that doesn't cost a year of indie-dev money.

For the **cross-Space** part: macOS 26 also broke `hs.spaces.gotoSpace`, `hs.application:activate(true)`'s Space-following behaviour, and AX cross-Space window enumeration. The only known software-only path is yabai (which patches SkyLight at runtime — requires SIP disabled). v0.2.0 wires yabai into the click handler so the right window comes to you across desktops; without yabai the tool degrades gracefully to same-Space focus.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the long story including every dead-end ruled out before settling on yabai.

### Requirements

| Component | Required | Why | Install |
| --- | --- | --- | --- |
| macOS 11+ (tested on 26 Tahoe) | yes | Hammerspoon target | — |
| [Hammerspoon](https://www.hammerspoon.org/) | yes | Banner + click callback | `brew install --cask hammerspoon` |
| [zellij](https://zellij.dev/) | yes | Multiplex terminal panes | `brew install zellij` |
| Python 3.9+ | yes | Hook runtime | `brew install python` |
| [yabai](https://github.com/koekeishiya/yabai) | optional, **strongly recommended** | Cross-Space window pull | See [docs/INSTALL.md](docs/INSTALL.md) step 0 |
| sox | optional | Audio trimming for `extract_applause.sh` | `brew install sox` |

> ⚠️ **About yabai.** Cross-Space click-to-jump requires yabai, which itself requires disabling System Integrity Protection (SIP) and (on Apple Silicon) setting an NVRAM boot-arg. This is a one-time setup but **SIP disable is not reversible without a Recovery-Mode reboot**. Read [docs/INSTALL.md](docs/INSTALL.md) step 0 carefully before proceeding. **Without yabai the tool still works, just same-Space only.**

### Quick start

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert
bash install.sh
```

The installer:

1. Verifies dependencies (Hammerspoon, sox, optional yabai).
2. Copies `notify.py` → `~/.local/bin/coding-done-alert`.
3. Drops the Lua module into `~/.hammerspoon/coding_done_alert.lua` and appends a `require()` to your `init.lua`.
4. (If yabai is present) appends `source hooks/zsh_precmd_record.sh` to `~/.zshrc` for the window-id mapping side-channel.
5. Seeds `~/.config/coding-done-alert/config.json` from the example.
6. Reloads Hammerspoon.

For full cross-Space behaviour, do the yabai prereqs in [docs/INSTALL.md](docs/INSTALL.md) step 0 **first**, then run `install.sh`.

Then wire it into your tool's lifecycle. For Claude Code, append to `~/.claude/settings.json`:

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

(See [examples/](examples/) for ready-made snippets including Codex CLI.)

### Configuration

`~/.config/coding-done-alert/config.json`:

```json
{
  "sound": {
    "enabled": true,
    "file": "/System/Library/Sounds/Hero.aiff"
  },
  "terminal": {
    "app_name": "Ghostty",
    "bundle_id": "com.mitchellh.ghostty"
  },
  "zellij": {
    "bin": "/opt/homebrew/bin/zellij"
  },
  "yabai": {
    "bin": "/opt/homebrew/bin/yabai",
    "window_map_dir": "/tmp/zellij_yabai"
  },
  "hammerspoon": {
    "bin": "/opt/homebrew/bin/hs",
    "call_timeout_sec": 8
  }
}
```

Environment overrides (precedence: env > config file > defaults):

| Variable | Effect |
| --- | --- |
| `CODING_DONE_ALERT_SOUND` | `0`/`off` to mute, `1`/`on` to enable |
| `CODING_DONE_ALERT_SOUND_FILE` | Absolute path to a `.aiff`/`.wav`/`.caf` |
| `CODING_DONE_ALERT_TERMINAL_APP` | Override terminal app name |
| `CODING_DONE_ALERT_CONFIG` | Use a different config file path |

### Replacing the sound

The default config points at the system-bundled `Hero.aiff` so it works out of the box on any Mac. To use any other audio file, just edit `sound.file`. Any format `afplay` accepts works (`.aiff`, `.wav`, `.mp3`, `.caf`, `.m4a`).

**Drop in any mp3 / wav (3 lines):**

```bash
mkdir -p ~/Library/Sounds                                            # only needed once
cp /path/to/your-cue.mp3 ~/Library/Sounds/                           # any name, any format
sed -i '' 's|"file": ".*"|"file": "~/Library/Sounds/your-cue.mp3"|' \
    ~/.config/coding-done-alert/config.json
```

**For a more festive applause clip**, you can extract one from your own iMovie installation:

```bash
bash bin/extract_applause.sh
```

This pulls a 3-second slice from the middle of `Stadium Crowd Applause.caf` (Apple's iLife Sound Effects, bundled with iMovie) and writes it to `~/Library/Sounds/Applause.aiff`. **Nothing copyrighted is shipped in this repo** — the script only operates on files already on your machine.

### Disabling sound

```bash
# One-off:
CODING_DONE_ALERT_SOUND=off /opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert

# Permanent:
# Edit ~/.config/coding-done-alert/config.json and set sound.enabled = false
```

### Uninstall

```bash
bash uninstall.sh
```

Removes the hook script, Lua module, the `require()` line in `init.lua`, the `source` line in `~/.zshrc`, and `/tmp/zellij_yabai/`. **Preserves** your config file at `~/.config/coding-done-alert/`. Hammerspoon, sox, and yabai are not touched (other tools may use them).

### Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for the full table. Quick checks:

- **No banner**: System Settings → Notifications → Hammerspoon → enable, set "Alert style" to "Persistent".
- **No sound**: Check `~/.config/coding-done-alert/config.json` and verify the file at `sound.file` exists.
- **Click works but doesn't switch Spaces**: `cat /tmp/zellij_yabai/<session>` — empty means the zsh hook hasn't written the mapping yet. Open the affected zellij session and hit Enter once at zsh.
- **`TASK_DONE | exit=2 stderr=[Pane Terminal(N) is already focused ...]`**: This is **success after a yabai pull**, not failure. Don't worry about it.
- **`yabai: missing required nvram boot-arg`**: Apple Silicon needs `sudo nvram boot-args=-arm64e_preview_abi` then a reboot. Full setup in [docs/INSTALL.md](docs/INSTALL.md).

### License

MIT. See [LICENSE](LICENSE).

---

## 中文

### 这个工具做什么

Mac 上跑 Claude Code、Codex 这类长任务时，跳出去喝杯水回来都得满屏找哪个 pane 完成了。Coding-Done-Alert 解决这个：

1. **声音提醒** — 默认 Hero，可选体育场掌声。
2. **持续横幅** — 系统通知显示 pane 名 + 任务最后一句话，不会几秒就消失。
3. **点横幅一键跳回** — **跨 macOS 桌面（Spaces）** 把对应 Ghostty/终端窗口拉到眼前（用 yabai），然后 `zellij action focus-pane-id` 直接定位完成的那个 pane。

适合 Claude Code、Codex CLI，或任何带 lifecycle hook 的 CLI 工具。

### 为什么需要这个

terminal-notifier 在 macOS 26 上系统会接收但不渲染横幅；UNUserNotificationCenter 要 Apple Developer 正式签名（每年 $99）；NSUserNotification 旧 API 已实质失效。Hammerspoon 是合法签名 .app + 持续维护，是当前不付钱也能弹+点击的唯一路径。

至于**跨 Space**：macOS 26 同时把 `hs.spaces.gotoSpace`、`hs.application:activate(true)` 的跟随 Space 行为、AX 跨 Space 窗口枚举全废了。已知唯一软件层方案是 yabai（运行时 patch SkyLight，需要关 SIP）。v0.2.0 把 yabai 接进点击 handler，让对应窗口跨桌面来到你眼前；不装 yabai 时优雅降级为「只在当前可见 Space 内 focus」。

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)（包含选 yabai 之前排除的所有死路）。

### 系统要求

| 组件 | 必需 | 用途 | 安装 |
| --- | --- | --- | --- |
| macOS 11+（在 26 Tahoe 测过） | 是 | Hammerspoon 运行环境 | — |
| [Hammerspoon](https://www.hammerspoon.org/) | 是 | 横幅 + 点击回调 | `brew install --cask hammerspoon` |
| [zellij](https://zellij.dev/) | 是 | 多 pane 终端 | `brew install zellij` |
| Python 3.9+ | 是 | hook 运行时 | `brew install python` |
| [yabai](https://github.com/koekeishiya/yabai) | 可选，**强烈推荐** | 跨 Space 拉窗口 | 见 [docs/INSTALL.md](docs/INSTALL.md) 步骤 0 |
| sox | 可选 | `extract_applause.sh` 截取掌声 | `brew install sox` |

> ⚠️ **关于 yabai。** 跨 Space 点击跳转需要 yabai，yabai 自己需要关闭 SIP（System Integrity Protection），Apple Silicon 还要设 NVRAM boot-arg。这是一次性配置但**关 SIP 不可逆 — 想恢复要再次进 Recovery Mode 跑命令**。开始之前仔细看 [docs/INSTALL.md](docs/INSTALL.md) 步骤 0。**不装 yabai 工具照样能用，只是限同 Space 内。**

### 快速开始

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert
bash install.sh
```

安装脚本会：

1. 检查依赖（Hammerspoon、sox、可选的 yabai）
2. 把 `notify.py` 装到 `~/.local/bin/coding-done-alert`
3. 把 Lua 模块复制到 `~/.hammerspoon/coding_done_alert.lua` 并在 `init.lua` 末尾追加 `require()`
4. （检测到 yabai 时）在 `~/.zshrc` 追加 `source hooks/zsh_precmd_record.sh` 维护窗口 id 映射
5. 从 `examples/config.example.json` 生成 `~/.config/coding-done-alert/config.json`
6. 重新加载 Hammerspoon

要完整跨 Space 体验，**先**做 [docs/INSTALL.md](docs/INSTALL.md) 步骤 0 的 yabai 前置，再跑 `install.sh`。

接着到 `~/.claude/settings.json` 注册 Stop hook：

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

更多触发方式见 [examples/](examples/)。

### 配置

`~/.config/coding-done-alert/config.json`：

```json
{
  "sound": {
    "enabled": true,
    "file": "/System/Library/Sounds/Hero.aiff"
  },
  "terminal": {
    "app_name": "Ghostty",
    "bundle_id": "com.mitchellh.ghostty"
  },
  "zellij": {
    "bin": "/opt/homebrew/bin/zellij"
  },
  "yabai": {
    "bin": "/opt/homebrew/bin/yabai",
    "window_map_dir": "/tmp/zellij_yabai"
  },
  "hammerspoon": {
    "bin": "/opt/homebrew/bin/hs",
    "call_timeout_sec": 8
  }
}
```

环境变量（优先级：env > 配置文件 > 默认值）：

| 变量 | 作用 |
| --- | --- |
| `CODING_DONE_ALERT_SOUND` | `0`/`off` 关闭，`1`/`on` 开启 |
| `CODING_DONE_ALERT_SOUND_FILE` | 自定义声音文件绝对路径 |
| `CODING_DONE_ALERT_TERMINAL_APP` | 指定终端 app 名（默认 Ghostty） |
| `CODING_DONE_ALERT_CONFIG` | 用别的配置文件路径 |

### 换声音

默认配置指向系统自带的 `Hero.aiff`，开箱即用任何 Mac 都有。要换成别的声音，编辑 `sound.file` 指向任意 `.aiff/.wav/.mp3/.caf/.m4a`（afplay 支持的都行）。

**接进任意 mp3 / wav（三行）：**

```bash
mkdir -p ~/Library/Sounds                                            # 只需一次
cp /path/to/你的提示音.mp3 ~/Library/Sounds/                         # 任意名字、任意格式
sed -i '' 's|"file": ".*"|"file": "~/Library/Sounds/你的提示音.mp3"|' \
    ~/.config/coding-done-alert/config.json
```

**想要更有仪式感的「全场鼓掌」音效**，可以从你本机的 iMovie 提取一段：

```bash
bash bin/extract_applause.sh
```

脚本从 `Stadium Crowd Applause.caf`（Apple 在 iMovie 里附带的 iLife Sound Effects）截取中间最热烈的 3 秒，输出到 `~/Library/Sounds/Applause.aiff`。**仓库本身不携带任何版权素材**，脚本只操作你机器上已有的文件。

### 关声音

```bash
# 临时关一次：
CODING_DONE_ALERT_SOUND=off /opt/homebrew/bin/python3 ~/.local/bin/coding-done-alert

# 永久关：
# 改 ~/.config/coding-done-alert/config.json，把 sound.enabled 设为 false
```

### 卸载

```bash
bash uninstall.sh
```

移除 hook 脚本、Lua 模块、`init.lua` 里的 `require` 行、`~/.zshrc` 里的 `source` 行、以及 `/tmp/zellij_yabai/`。**保留** `~/.config/coding-done-alert/` 下的配置文件。Hammerspoon、sox、yabai 不动（其他工具可能在用）。

### 排错

完整对照表见 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)。常见检查：

- **没弹横幅**：系统设置 → 通知 → Hammerspoon → 打开通知，「提醒样式」选「持续」
- **没声音**：检查 `~/.config/coding-done-alert/config.json`，确认 `sound.file` 路径下有文件
- **点击有效但不跨 Space**：`cat /tmp/zellij_yabai/<session>` — 空就是 zsh hook 还没写映射。打开受影响的 zellij session 在 zsh 按一次回车
- **`TASK_DONE | exit=2 stderr=[Pane Terminal(N) is already focused ...]`**：这是 **yabai 拉窗口后的成功**，不是失败。不用管
- **`yabai: missing required nvram boot-arg`**：Apple Silicon 要 `sudo nvram boot-args=-arm64e_preview_abi` 然后重启。完整步骤见 [docs/INSTALL.md](docs/INSTALL.md)

### 许可证

MIT。详见 [LICENSE](LICENSE)。
