# Coding-Done-Alert

[![License: MIT](https://img.shields.io/github/license/idonecc/Coding-Done-Alert?style=flat-square)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert/issues)
[![Repo size](https://img.shields.io/github/repo-size/idonecc/Coding-Done-Alert?style=flat-square)](https://github.com/idonecc/Coding-Done-Alert)
[![macOS](https://img.shields.io/badge/macOS-11%2B-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)

> macOS banner + applause + click-to-jump for long-running terminal tasks. Designed for Claude Code, Codex CLI, or any agentic CLI that wants to stop interrupting your flow.

[English](#english) · [中文](#中文)

## Demo

<!--
Drop a screenshot or short GIF showing the banner appearing and the click-to-jump
behaviour. Suggested capture: terminal in pane A → trigger a long task → switch
to Chrome on a different Space → banner pops → click → Ghostty pulled forward
across Spaces and zellij focused on pane A.

Recommended path: docs/screenshots/banner.png   (or banner.gif)
Reference here as: ![Demo](docs/screenshots/banner.png)
-->

> _Demo screenshot/GIF coming soon — drop yours at `docs/screenshots/banner.png` and update this section._

---

## English

### What it does

When a long-running task in your terminal finishes, Coding-Done-Alert:

1. **Plays a sound** — Hero by default, optional applause clip.
2. **Pops a persistent banner** — system notification with the pane title and the last assistant message.
3. **Click the banner → jump back** — automatically activates your terminal app **across macOS Spaces** and uses `zellij action focus-pane-id` to land on the exact pane that finished.

No more polling between the IDE and the browser, missing the moment a build finishes, or wondering which of five running agents is asking for input.

### Why this exists

If you've already tried `terminal-notifier`, you know macOS 26 (Tahoe) silently drops its banners. UNUserNotificationCenter requires an Apple Developer signature ($99/year). The legacy NSUserNotification API has been hollowed out. Hammerspoon — properly signed and actively maintained — is the only path to a working banner with a click callback that doesn't cost a year of indie-dev money.

This project bundles the workarounds:

- **`hs.execute` hangs on macOS 26** → the Lua callback uses `hs.task` instead.
- **`zellij action focus-pane-with-id` was renamed** → uses `focus-pane-id` (zellij 0.44+).
- **`osascript "tell ... to activate"` doesn't follow Spaces** → uses `hs.application:activate(true)`.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the long story.

### Requirements

| Component | Why | Install |
| --- | --- | --- |
| macOS 11+ (tested on 26 Tahoe) | Hammerspoon target | — |
| [Hammerspoon](https://www.hammerspoon.org/) | Banner + click callback | `brew install --cask hammerspoon` |
| [zellij](https://zellij.dev/) | Multiplex terminal panes | `brew install zellij` |
| Python 3.9+ | Hook runtime | `brew install python` |
| sox (optional) | Audio trimming for `extract_applause.sh` | `brew install sox` |

### Quick start

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert
bash install.sh
```

The installer:

1. Verifies and installs Hammerspoon and sox if missing.
2. Copies `notify.py` → `~/.local/bin/coding-done-alert`.
3. Drops the Lua module into `~/.hammerspoon/coding_done_alert.lua` and appends a `require()` to your `init.lua`.
4. Seeds `~/.config/coding-done-alert/config.json` from the example.
5. Reloads Hammerspoon.

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
    "file": "~/Library/Sounds/Applause.aiff"
  },
  "terminal": {
    "app_name": "Ghostty",
    "bundle_id": "com.mitchellh.ghostty"
  },
  "zellij": {
    "bin": "/opt/homebrew/bin/zellij"
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

(Or just edit the JSON in your editor — sed is for the lazy.)

**For a more festive applause clip**, you can extract one from your own iMovie installation:

```bash
bash bin/extract_applause.sh
```

This pulls a 3-second slice from the middle of `Stadium Crowd Applause.caf` (Apple's iLife Sound Effects, bundled with iMovie) and writes it to `~/Library/Sounds/Applause.aiff`. **Nothing copyrighted is shipped in this repo** — the script only operates on files already on your machine. After running it, point `sound.file` at the generated path.

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

### Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for the full table. Quick checks:

- **No banner**: System Settings → Notifications → Hammerspoon → enable, set "Alert style" to "Persistent".
- **No sound**: Check `~/.config/coding-done-alert/config.json` and verify the file at `sound.file` exists.
- **Click does nothing**: Look at `/tmp/coding_done_alert.log` for `CALLBACK` and `TASK_DONE` rows. If `TASK_DONE | exit=2`, run the click command manually — the log line right above shows the exact shell that was executed.

### License

MIT. See [LICENSE](LICENSE).

---

## 中文

### 这个工具做什么

Mac 上跑 Claude Code、Codex 这类长任务时，跳出去喝杯水回来都得满屏找哪个 pane 完成了。Coding-Done-Alert 解决这个：

1. **声音提醒** — 默认 Hero，可选体育场掌声。
2. **持续横幅** — 系统通知显示 pane 名 + 任务最后一句话，不会几秒就消失。
3. **点横幅一键跳回** — 自动跨 macOS 空间（Spaces）激活终端 + `zellij action focus-pane-id` 直接定位完成的那个 pane。

适合 Claude Code、Codex CLI，或任何带 lifecycle hook 的 CLI 工具。

### 为什么需要这个

terminal-notifier 在 macOS 26 上系统会接收但不渲染横幅；UNUserNotificationCenter 要 Apple Developer 正式签名（每年 $99）；NSUserNotification 旧 API 已实质失效。Hammerspoon 是合法签名 .app + 持续维护，是当前不付钱也能弹+点击的唯一路径。

本项目内置了三个隐蔽坑的修复：

- **`hs.execute` 在 macOS 26 上挂起** → Lua callback 用 `hs.task` 异步 spawn
- **`zellij action focus-pane-with-id` 已被改名** → 用 `focus-pane-id`（zellij 0.44+）
- **`osascript "tell ... activate"` 不切 Space** → 用 `hs.application:activate(true)`

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

### 系统要求

| 组件 | 用途 | 安装 |
| --- | --- | --- |
| macOS 11+（在 26 Tahoe 测过） | Hammerspoon 运行环境 | — |
| [Hammerspoon](https://www.hammerspoon.org/) | 横幅 + 点击回调 | `brew install --cask hammerspoon` |
| [zellij](https://zellij.dev/) | 多 pane 终端 | `brew install zellij` |
| Python 3.9+ | hook 运行时 | `brew install python` |
| sox（可选） | `extract_applause.sh` 截取掌声 | `brew install sox` |

### 快速开始

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert
bash install.sh
```

安装脚本会：

1. 检查 Hammerspoon 和 sox，缺什么装什么
2. 把 `notify.py` 装到 `~/.local/bin/coding-done-alert`
3. 把 Lua 模块复制到 `~/.hammerspoon/coding_done_alert.lua` 并在 `init.lua` 末尾追加 `require()`
4. 从 `examples/config.example.json` 生成 `~/.config/coding-done-alert/config.json`
5. 重新加载 Hammerspoon

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
    "file": "~/Library/Sounds/Applause.aiff"
  },
  "terminal": {
    "app_name": "Ghostty",
    "bundle_id": "com.mitchellh.ghostty"
  },
  "zellij": {
    "bin": "/opt/homebrew/bin/zellij"
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

（懒得敲 sed 也可以直接打开 JSON 改。）

**想要更有仪式感的「全场鼓掌」音效**，可以从你本机的 iMovie 提取一段：

```bash
bash bin/extract_applause.sh
```

脚本从 `Stadium Crowd Applause.caf`（Apple 在 iMovie 里附带的 iLife Sound Effects）截取中间最热烈的 3 秒，输出到 `~/Library/Sounds/Applause.aiff`。**仓库本身不携带任何版权素材**，脚本只操作你机器上已有的文件。生成后把 `sound.file` 指向那个路径即可。

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

会清除 hook 脚本 + Lua 模块 + init.lua 里的 require 行；保留用户配置文件，避免误删个人设置。

### 排错

完整对照表见 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)。常见三步：

- **没弹横幅**：系统设置 → 通知 → Hammerspoon → 打开通知，「提醒样式」选「持续」
- **没声音**：检查 `~/.config/coding-done-alert/config.json`，确认 `sound.file` 路径下有文件
- **点击没跳转**：看 `/tmp/coding_done_alert.log`，找 `CALLBACK` 和 `TASK_DONE` 行；如果 `TASK_DONE | exit=2`，把上面 `CALLBACK` 那条命令复制到终端跑一遍，看具体错误

### 许可证

MIT。详见 [LICENSE](LICENSE)。
