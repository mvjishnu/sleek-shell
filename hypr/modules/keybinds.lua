---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
-- --single-instance: a new terminal window is delegated to the already-running kitty
-- process (~25 ms) instead of spawning a cold kitty (~120 ms).
local terminal    = "kitty --single-instance"
local fileManager = "thunar"
local menu        = "rofi -show drun"
local home        = os.getenv("HOME") or ""
local config      = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/configuring/core/binds/ for more
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(config .. "/hypr/scripts/wallpaper-next next"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(config .. "/hypr/scripts/wallpaper-next prev"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("quickshell ipc call lock lock"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
-- Tap the Super key by itself to open Rofi without stealing Super+key chords.
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(menu), { release = true })
-- Sleek Shell calculator / unit converter (Rofi mode).
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(home .. "/.local/bin/sleek-calc"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only

-- Monitor-local workspace navigation. Moving right from the last workspace
-- creates the next workspace on this monitor; moving left at the first stays put.
hl.bind(mainMod .. " + left",  hl.dsp.exec_cmd("quickshell ipc call ws step -1"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("quickshell ipc call ws step 1"))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.exec_cmd("if command -v quickshell >/dev/null 2>&1; then quickshell ipc call ws goto " .. i .. "; else hyprctl dispatch workspace " .. i .. "; fi"))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.exec_cmd("if command -v quickshell >/dev/null 2>&1; then quickshell ipc call ws move " .. i .. "; else hyprctl dispatch movetoworkspace " .. i .. "; fi"))
end

-- Example special workspace (scratchpad)
-- hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(config .. "/hypr/scripts/control-osd volume up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(config .. "/hypr/scripts/control-osd volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(config .. "/hypr/scripts/control-osd volume mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd(config .. "/hypr/scripts/control-osd brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd(config .. "/hypr/scripts/control-osd brightness down"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))

-- Screenshot shortcuts: save PNG and copy to clipboard
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png"))
