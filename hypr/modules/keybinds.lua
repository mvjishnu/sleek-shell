---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use. Override them without editing this file by exporting
-- SLEEK_TERMINAL / SLEEK_FILE_MANAGER / SLEEK_BROWSER (e.g. in ~/.profile; see docs/KEYBINDS.md).
-- The defaults open your desktop's default apps (xdg-mime / xdg-settings).
local function app(env, fallback)
    local v = os.getenv(env)
    if v and v ~= "" then return v end
    return fallback
end
local terminal    = app("SLEEK_TERMINAL", "kitty")
local fileManager = app("SLEEK_FILE_MANAGER", "~/.config/hypr/scripts/open-default.sh files")
local menu = "rofi -show drun"
local browser     = app("SLEEK_BROWSER", "~/.config/hypr/scripts/open-default.sh browser")


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("pkill -x rofi || " .. menu), { release = true })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("bash ~/.config/quickshell/scripts/clipboard-history.sh"))  -- clipboard history in rofi
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("~/.local/bin/sleek-calc"))  -- calculator & unit converter in rofi
-- ALT + Tab (app switcher) and SUPER + Tab (workspace overview) live in modules/shell_keys.lua.
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))

-- Wallpapers (awww). Super+W cycles to the next image in ~/Pictures/Wallpapers;
-- Shift the modifier to step backwards.
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-next.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-next.sh prev"))

-- Screenshot shortcuts: save PNG and copy to clipboard
hl.bind("ALT + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png"))
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy --type image/png"))

-- Quickshell Lockscreen
hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc call lock lock"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
-- Monitor-scoped: key N is the Nth workspace of the monitor that has focus (via the shell, see WsControl.qml).
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.exec_cmd("quickshell ipc call ws goto " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("quickshell ipc call ws move " .. i))
end

-- -- Example special workspace (scratchpad)
-- hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("quickshell ipc call ws next"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("quickshell ipc call ws prev"))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && quickshell ipc call osd brightness"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && quickshell ipc call osd brightness"),                  { locked = true, repeating = true })

-- Media keys: playerctl when installed, otherwise the Sleek Shell talks to MPRIS players itself.
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next 2>/dev/null || quickshell ipc call media next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause 2>/dev/null || quickshell ipc call media playPause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause 2>/dev/null || quickshell ipc call media playPause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous 2>/dev/null || quickshell ipc call media previous"),   { locked = true })
