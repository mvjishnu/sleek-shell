--[[
Keys that talk to the Quickshell shell. This replaces the old modules/switcher.lua.

  ALT + Tab / ALT + SHIFT + Tab   application switcher (forward / backward)
  SUPER + Tab                     workspace overview (NOT an app switcher)
  SUPER + K                       keybind manager
  SUPER + H                       hide (minimise) the focused window; restore it from Alt+Tab
  SUPER + SHIFT + D               monitor settings
  SUPER + SHIFT + A               appearance panel on the focused monitor
  SUPER + I                       Sleek Shell settings

The shell registers these as global shortcuts (hyprland_global_shortcuts_v1) under the
app id "quickshell". Escape / Return are handled by the shell windows themselves while
they are open (they hold the keyboard), so no global Escape/Return bind exists any more.

SUPER+H is used for hiding because Ctrl+Tab is what browsers/editors use for their own
tabs. Change HIDE_KEY below to rebind it.
]]

local APPID = "quickshell"
local HIDE_KEY = "SUPER + H"

hl.bind("ALT + Tab",           hl.dsp.global(APPID .. ":switcher-next"))
hl.bind("ALT + SHIFT + Tab",   hl.dsp.global(APPID .. ":switcher-prev"))
hl.bind("SUPER + Tab",         hl.dsp.global(APPID .. ":overview-toggle"))
hl.bind("SUPER + K",           hl.dsp.global(APPID .. ":keybinds-toggle"))
hl.bind(HIDE_KEY,              hl.dsp.global(APPID .. ":minimize"))
hl.bind("SUPER + SHIFT + D",   hl.dsp.global(APPID .. ":monitors-toggle"))
hl.bind("SUPER + SHIFT + A",   hl.dsp.exec_cmd("quickshell ipc call appearance toggle"))
hl.bind("SUPER + I",           hl.dsp.global(APPID .. ":settings-toggle"))

-- Sleek Shell: while Settings > Keyboard records a new shortcut it enters this empty submap so that
-- combinations already bound (e.g. SUPER+T) reach the recorder instead of firing. The shell always
-- resets it when recording ends; SUPER + ALT + Escape is the manual way out.
hl.define_submap("sleekshell_capture", function()
    hl.bind("SUPER + ALT + Escape", hl.dsp.submap("reset"))
end)
