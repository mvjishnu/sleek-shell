-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- cursor theme + size from Sleek Shell Settings > Fonts, icons & cursors (overrides the two lines above)
pcall(function() require("sleekshell.cursor").apply() end)

-- GUI toolkits
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt: read the KDE colour scheme (kdeglobals) so KDE/Qt apps match
-- (only when the KDE platform theme plugin is installed; otherwise Qt would fail to load it)
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end; return false end
for _, d in ipairs({ "/usr/lib/qt6/plugins", "/usr/lib64/qt6/plugins", "/usr/lib/x86_64-linux-gnu/qt6/plugins", "/usr/lib/aarch64-linux-gnu/qt6/plugins" }) do
    if exists(d .. "/platformthemes/KDEPlasmaPlatformTheme6.so") then
        hl.env("QT_QPA_PLATFORMTHEME", "kde")
        break
    end
end
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- KDE apps (Dolphin "Open with", file associations) need an applications menu outside Plasma:
-- archlinux-xdg-menu ships one as arch-applications.menu
if not os.getenv("XDG_MENU_PREFIX") and exists((os.getenv("SLEEK_SYS_ROOT") or "") .. "/etc/xdg/menus/arch-applications.menu") then
    hl.env("XDG_MENU_PREFIX", "arch-")
end
-- (Hyprland already scales the screen, so no QT_AUTO_SCREEN_SCALE_FACTOR / QT_SCALE_FACTOR here)

-- micro editor: full colour theme
hl.env("MICRO_TRUECOLOR", "1")

-- ~/.local/bin (sleek-calc and other user tools) for everything started from the desktop
local home = os.getenv("HOME") or ""
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if home ~= "" and not (":" .. path .. ":"):find(":" .. home .. "/.local/bin:", 1, true) then
    hl.env("PATH", home .. "/.local/bin:" .. path)
end

-- NVIDIA: only when the proprietary driver is loaded AND the NVIDIA card is the only GPU. On hybrid
-- laptops the desktop renders on the integrated GPU, and these variables would push every app onto
-- the NVIDIA card (or break VA-API). Use prime-run for single apps there. Force with SLEEK_NVIDIA_ENV=1.
local sysroot = os.getenv("SLEEK_SYS_ROOT") or ""
local function only_nvidia_gpus()
    local p = io.popen('cat "' .. sysroot .. '"/sys/class/drm/card[0-9]*/device/vendor 2>/dev/null')
    if not p then return false end
    local seen, other = false, false
    for v in p:lines() do
        seen = true
        if v ~= "0x10de" then other = true end
    end
    p:close()
    return seen and not other
end
local nv = io.open(sysroot .. "/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    local force = os.getenv("SLEEK_NVIDIA_ENV")
    if force == "1" or (force ~= "0" and os.getenv("SLEEK_NO_NVIDIA_ENV") ~= "1" and only_nvidia_gpus()) then
        hl.env("LIBVA_DRIVER_NAME", "nvidia")
        hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    end
end
