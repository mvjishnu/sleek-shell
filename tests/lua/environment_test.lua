-- modules/env.lua: toolkit and Wayland variables, and the cursor state from
-- ~/.config/sleek-shell/hypr-cursor.lua (falling back to size 24).
package.path = "./?.lua;" .. package.path
local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local home = os.getenv("HOME")

local function load()
    local env = {}
    hl = { env = function(k, v) env[k] = v end }
    package.loaded["modules.env"] = nil
    package.loaded["sleekshell.cursor"] = nil
    require("modules.env")
    return env
end

-- No state file: defaults, and every toolkit/Wayland variable is set.
local e = load()
if e.XCURSOR_SIZE ~= "24" or e.HYPRCURSOR_SIZE ~= "24" then fail("default cursor size should be 24") end
if e.XCURSOR_THEME or e.HYPRCURSOR_THEME then fail("no theme should be exported without a state file") end
if e.GDK_BACKEND ~= "wayland,x11,*" then fail("GDK_BACKEND should prefer Wayland") end
if e.QT_QPA_PLATFORM ~= "wayland;xcb" then fail("QT_QPA_PLATFORM should prefer Wayland") end
if e.SDL_VIDEODRIVER ~= "wayland" then fail("SDL_VIDEODRIVER should be wayland") end
if e.XDG_CURRENT_DESKTOP ~= "Hyprland" or e.XDG_SESSION_TYPE ~= "wayland" then
    fail("XDG session variables should describe Hyprland on Wayland")
end
if e.QT_QPA_PLATFORMTHEME ~= "qt5ct" then fail("QT_QPA_PLATFORMTHEME should be qt5ct") end

-- A valid state file is exported as-is.
os.execute('mkdir -p "' .. home .. '/.config/sleek-shell"')
local f = io.open(home .. "/.config/sleek-shell/hypr-cursor.lua", "w")
f:write('return { theme = "Adwaita", size = 32 }\n')
f:close()
e = load()
if e.XCURSOR_THEME ~= "Adwaita" or e.HYPRCURSOR_THEME ~= "Adwaita" then fail("cursor theme should be exported") end
if e.XCURSOR_SIZE ~= "32" or e.HYPRCURSOR_SIZE ~= "32" then fail("cursor size should be exported") end

-- Broken or out-of-range values fall back instead of exporting garbage.
f = io.open(home .. "/.config/sleek-shell/hypr-cursor.lua", "w")
f:write('return { theme = "bad/theme", size = 999 }\n')
f:close()
e = load()
if e.XCURSOR_THEME then fail("an invalid theme must not be exported") end
if e.XCURSOR_SIZE ~= "96" then fail("size should be clamped to 96, got " .. tostring(e.XCURSOR_SIZE)) end

print("ok")
