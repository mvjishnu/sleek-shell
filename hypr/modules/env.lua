-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/configuring/core/environment-variables/

-- Cursor theme/size chosen in Sleek Shell Settings > Fonts, icons & cursors.
-- The choice lives in ~/.config/sleek-shell/hypr-cursor.lua; applying it here (and not only
-- live via `hyprctl setcursor`) is what makes it survive a Hyprland restart / reboot.
local cursor_loaded, cursor = pcall(require, "sleekshell.cursor")
if cursor_loaded then
    cursor.apply()
else
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")
end

-- GUI toolkits
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1.25")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- Hybrid Intel/NVIDIA graphics: keep the desktop on the integrated GPU.
-- Per-app NVIDIA offload can be requested with prime-run.
