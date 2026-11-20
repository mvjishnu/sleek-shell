
-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/configuring/core/autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
local home = os.getenv("HOME") or ""
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

hl.on("hyprland.start", function ()
  -- Re-apply the cursor chosen in Sleek Shell Settings > Fonts, icons & cursors. Hyprland
  -- creates its own pointer before the config's XCURSOR_* values take effect, so the env vars
  -- alone only cover apps; this is the same call the settings app uses for live changes.
  local cursor_ok, cursor = pcall(require, "sleekshell.cursor")
  if cursor_ok then
    local s = cursor.load()
    if s.theme ~= "" then
      hl.exec_cmd("hyprctl setcursor '" .. s.theme .. "' " .. tostring(s.size))
    end
  end
  -- Sleek Shell owns the bar and notification service for this Hyprland session.
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE")
  hl.exec_cmd(config .. "/hypr/scripts/start-shell")
  hl.exec_cmd(config .. "/hypr/scripts/polkit-agent")
  -- Automount removable drives (USB sticks, external HDDs) and notify on insert.
  -- Skipped silently when udiskie is not installed (optional dependency).
  hl.exec_cmd("sh -c 'command -v udiskie >/dev/null && exec udiskie'")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("awww-daemon")
end)
