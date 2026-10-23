-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- let D-Bus / systemd-launched apps (file managers, portals) see the same theme
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME XCURSOR_THEME XCURSOR_SIZE")

    hl.exec_cmd("quickshell")      -- bar, dropdowns, notifications, lock screen
    hl.exec_cmd("awww-daemon")     -- wallpaper daemon
    hl.exec_cmd("~/.config/hypr/scripts/polkit-agent.sh")   -- admin password prompts (skips if one runs)

    -- Clipboard history (text and images, one watcher each)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
