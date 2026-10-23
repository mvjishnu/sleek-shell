--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Glass for the Quickshell bar, dropdowns and notifications, and for Rofi.
--
-- xray = true is the important part: it makes the blur sample ONLY the wallpaper
-- layer and ignore every window sitting behind the layer. Without xray the pills
-- would pick up the colours of whatever app happens to be underneath them, so the
-- shell would look different depending on the open windows. With xray the glass is
-- stable and wallpaper-only. ignore_alpha stops the invisible parts of the layer
-- (the gaps between pills) from being blurred at all.
hl.layer_rule({
    name  = "glass",
    match = { namespace = "^(quickshell|rofi)$" },
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.05,
    xray         = true,
})

-- The lock screen is a session-lock surface, not a normal layer, so it uses its
-- own option. This keeps the lock's backdrop wallpaper-only as well.
hl.config({
    misc = {
        session_lock_xray = true,
    },
})
