-- Coding-Done-Alert · Hammerspoon module
--
-- Exposes a global function `codingDoneAlert(title, body, clickCmd, terminalApp)`
-- that pops a banner and, on click, activates the terminal app (cross-Space)
-- then fires `clickCmd` via `hs.task` (an async-safe replacement for
-- `hs.execute`, which hangs on macOS 26).
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

    -- Cross-Space activation: hs.application:activate(true) follows the app
    -- to its Space (osascript `tell ... activate` does not).
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
      hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        logTrace("TASK_DONE", "exit=" .. tostring(exitCode))
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
