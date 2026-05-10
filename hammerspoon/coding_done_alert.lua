-- Coding-Done-Alert · Hammerspoon module
--
-- Exposes a global function `codingDoneAlert(title, body, clickCmd, terminalApp)`
-- that pops a banner and, on click, fires `clickCmd` via `hs.task`
-- (an async-safe replacement for `hs.execute`, which hangs on macOS 26).
--
-- Cross-Space click-to-jump (v0.2.0+):
--   * Real cross-Space window pull is done by yabai inside `clickCmd`
--     (see hooks/notify.py::build_click_command) — Hammerspoon can no longer
--     pull windows across Spaces on macOS 26 because the underlying SkyLight
--     APIs (hs.spaces, AX cross-Space window enumeration) are blocked.
--   * `app:activate(true)` is kept as a same-Space fallback: harmless if
--     yabai already pulled the right window forward; useful if yabai isn't
--     installed and the target window is already on the visible Space.
--
-- Usage from a shell:
--   hs -c 'codingDoneAlert("✅ Build", "passed in 3.2s", "zellij action focus-pane-id 5", "Ghostty")'
--
-- Usage from your own init.lua:
--   require("coding_done_alert")  -- assuming this file is in ~/.hammerspoon/
require("hs.ipc")
hs.ipc.cliInstall()

-- Notifications kept alive across GC; bounded to avoid leaks.
_codingDoneAlertNotifications = _codingDoneAlertNotifications or {}

local function logTrace(label, info)
  local f = io.open("/tmp/coding_done_alert.log", "a")
  if f then
    f:write(string.format("[%s] %s | %s\n", os.date("%H:%M:%S"), label, info or ""))
    f:close()
  end
end

function codingDoneAlert(title, body, clickCmd, terminalApp)
  title = title or "Coding-Done-Alert"
  body = body or "Task complete"
  clickCmd = clickCmd or ""
  terminalApp = terminalApp or "Terminal"

  local capturedTitle = title
  local capturedCmd = clickCmd
  local capturedTerm = terminalApp

  local n
  n = hs.notify.new(function(notification)
    local at = tostring(notification:activationType())
    logTrace("CALLBACK", "title=" .. capturedTitle .. " activationType=" .. at)

    -- Same-Space fallback: app:activate(true) raises the terminal if it's
    -- already on the visible Space. On macOS 26 this no longer follows the
    -- app to its own Space (SkyLight changes), so the real cross-Space pull
    -- is done by yabai inside capturedCmd. Harmless to keep — if yabai
    -- already pulled the right window forward, this is a no-op.
    local app = hs.application.find(capturedTerm)
    if app then
      app:activate(true)
      logTrace("ACTIVATE", capturedTerm .. " pid=" .. tostring(app:pid()))
    else
      logTrace("ACTIVATE", capturedTerm .. " not found, fallback to open -a")
      hs.task.new("/usr/bin/open", nil, {"-a", capturedTerm}):start()
    end

    if capturedCmd ~= "" then
      -- hs.task is mandatory: hs.execute hangs on macOS 26.
      -- Capture stderr/stdout fully (truncated) so failed yabai/zellij
      -- invocations are visible in /tmp/coding_done_alert.log without
      -- needing to re-run the command by hand.
      hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        local err = (stdErr or ""):gsub("\n", " "):sub(1, 300)
        local out = (stdOut or ""):gsub("\n", " "):sub(1, 200)
        logTrace("TASK_DONE", "exit=" .. tostring(exitCode) ..
          " stderr=[" .. err .. "]" ..
          " stdout=[" .. out .. "]")
      end, {"-c", capturedCmd}):start()
    end
  end, {
    title = title,
    informativeText = body,
    soundName = "default",
    autoWithdraw = false,
    hasActionButton = false,
    withdrawAfter = 0,
  })

  table.insert(_codingDoneAlertNotifications, n)
  if #_codingDoneAlertNotifications > 30 then
    table.remove(_codingDoneAlertNotifications, 1)
  end

  n:send()
  logTrace("NOTIFY", "title=" .. title .. " cmd_len=" .. #clickCmd)
  return "ok"
end

return {
  codingDoneAlert = codingDoneAlert,
}
