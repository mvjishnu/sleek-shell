-- Sleek Shell greeter compositor. Run by greetd as the unprivileged "greeter" user:
--   command = "start-hyprland -- --config /etc/greetd/sleek-shell/hyprland.lua"
-- It only shows the Quickshell greeter; when the greeter quits (after a successful login, or if it
-- crashes) Hyprland exits and greetd starts the chosen session / restarts the greeter.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("XDG_CACHE_HOME", "/var/cache/sleek-shell-greeter")
hl.env("XDG_STATE_HOME", "/var/cache/sleek-shell-greeter")
hl.env("XDG_CONFIG_HOME", "/var/cache/sleek-shell-greeter")

-- unknown outputs: automatic; then the user's layout (copied from nwg-displays at install time)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
pcall(dofile, "/etc/greetd/sleek-shell/monitors.lua")

-- keyboard: the system layout (localectl), written by install.sh; "us" if there is none
local input = { kb_layout = "us", follow_mouse = 1, touchpad = { natural_scroll = true } }
local kb_ok, kb = pcall(dofile, "/etc/greetd/sleek-shell/keyboard.lua")
if kb_ok and type(kb) == "table" then
    for _, k in ipairs({ "kb_layout", "kb_variant", "kb_options", "kb_model" }) do
        if type(kb[k]) == "string" and kb[k] ~= "" then input[k] = kb[k] end
    end
end

hl.config({
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0, disable_splash_rendering = true },
    input = input,
    general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = true },
})

-- Escape hatch: restarts the greeter (greetd relaunches it). The TTY login on Ctrl+Alt+F2 always works too.
hl.bind("CTRL + ALT + BackSpace", hl.dsp.exit())

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p /etc/greetd/sleek-shell/greeter >/var/cache/sleek-shell-greeter/greeter.log 2>&1; hyprctl dispatch 'hl.dsp.exit()'")
end)
