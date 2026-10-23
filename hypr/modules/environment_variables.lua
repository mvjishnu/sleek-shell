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
-- (Hyprland already scales the screen, so no QT_AUTO_SCREEN_SCALE_FACTOR / QT_SCALE_FACTOR here)

-- micro editor: full colour theme
hl.env("MICRO_TRUECOLOR", "1")

-- NVIDIA: only when the proprietary driver is loaded. Hybrid laptops that render on the
-- integrated GPU can opt out with SLEEK_NO_NVIDIA_ENV=1.
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    if os.getenv("SLEEK_NO_NVIDIA_ENV") ~= "1" then
        hl.env("LIBVA_DRIVER_NAME", "nvidia")
        hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    end
end
