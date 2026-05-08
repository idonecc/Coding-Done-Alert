# Contributing

[English](#english) · [中文](#中文)

## English

Thanks for considering a contribution! This is a small, focused tool — bug reports, dev-setup polish, and integration recipes for other AI coding CLIs are especially welcome.

### Reporting bugs

Open an issue at <https://github.com/idonecc/Coding-Done-Alert/issues>. Include:

- macOS version (`sw_vers`)
- Hammerspoon version (menu bar icon → About)
- zellij version (`zellij --version`)
- Relevant excerpt from `/tmp/coding_done_alert.log`
- What you expected vs. what happened

### Requesting features

Open an issue with the `enhancement` label. Particularly interested in:

- Hooks for new AI coding tools (Cursor, Aider, OpenAI Codex CLI variants, etc.)
- Alternatives to Hammerspoon for users who don't want a menu-bar daemon
- Configurable click actions beyond `zellij focus-pane-id`

### Pull requests

1. Fork and create a topic branch: `feat/cursor-hook` or `fix/applause-sample-rate`.
2. Match the existing code style:
   - Python: stdlib only, no third-party deps in `hooks/notify.py`.
   - Lua: keep `hammerspoon/coding_done_alert.lua` self-contained — no extra requires.
3. Update `docs/ARCHITECTURE.md` if you change the runtime data flow.
4. Update `CHANGELOG.md` under `## [Unreleased]`.
5. Test on macOS 11+ (we target broad Hammerspoon compatibility, not just 26+).
6. Open the PR with a one-line summary and a "Test plan" checklist.

### Local development

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert

# Install in-place (links to the source tree if you want to iterate)
bash install.sh

# Edit hammerspoon/coding_done_alert.lua, then reload:
hs -c 'hs.reload()'

# Edit hooks/notify.py, then trigger via:
echo '{"last_assistant_message":"test"}' \
  | ZELLIJ_SESSION_NAME=$ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID=$ZELLIJ_PANE_ID \
  python3 hooks/notify.py

# Inspect logs:
tail -f /tmp/coding_done_alert.log
```

### License

By contributing you agree your work is licensed under the MIT License (see [LICENSE](LICENSE)).

---

## 中文

欢迎贡献。本工具体积小、聚焦明确，特别欢迎：bug 报告、安装/部署体验改善、其他 AI 编码 CLI 的接入示例。

### 报 bug

到 <https://github.com/idonecc/Coding-Done-Alert/issues> 开 issue，附上：

- macOS 版本（`sw_vers`）
- Hammerspoon 版本（菜单栏图标 → About）
- zellij 版本（`zellij --version`）
- `/tmp/coding_done_alert.log` 相关片段
- 期望行为 vs. 实际行为

### 提需求

加 `enhancement` label 的 issue。特别关注的方向：

- 新的 AI 编码工具接入（Cursor、Aider、OpenAI Codex CLI 各种变体等）
- 替代 Hammerspoon 的方案（针对不想常驻菜单栏的用户）
- `zellij focus-pane-id` 之外可配置的点击动作

### Pull Request

1. Fork 并建 topic 分支：`feat/cursor-hook` 或 `fix/applause-sample-rate`
2. 沿用现有代码风格：
   - Python：只用标准库，`hooks/notify.py` 不引第三方依赖
   - Lua：保持 `hammerspoon/coding_done_alert.lua` 自包含，不加额外 require
3. 改了运行时数据流就同步更新 `docs/ARCHITECTURE.md`
4. 在 `CHANGELOG.md` 的 `## [Unreleased]` 段加一条
5. 在 macOS 11+ 上测过（目标是宽 Hammerspoon 兼容，不只是 26+）
6. PR 描述写一行摘要 + Test plan 清单

### 本地开发

```bash
git clone https://github.com/idonecc/Coding-Done-Alert.git
cd Coding-Done-Alert

# 一键就地安装
bash install.sh

# 改 hammerspoon/coding_done_alert.lua 后重新加载：
hs -c 'hs.reload()'

# 改 hooks/notify.py 后手动触发：
echo '{"last_assistant_message":"test"}' \
  | ZELLIJ_SESSION_NAME=$ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID=$ZELLIJ_PANE_ID \
  python3 hooks/notify.py

# 看日志：
tail -f /tmp/coding_done_alert.log
```

### 许可证

提交贡献即表示你同意以 MIT License（[LICENSE](LICENSE)）授权你的代码。
