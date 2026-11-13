--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/configuring/core/rules/

-- Example window rules that are useful

-- Ignore maximize requests from all applications
hl.window_rule({
    name = "suppress-maximize-events",
    match = {
        class = ".*",
    },

    suppress_event = "maximize",
})

-- Fix XWayland dragging issues
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },

    no_focus = true,
})

-- Gazebo's Docker/XWayland windows should use the normal tiled layout.
hl.window_rule({
    name = "gazebo-docker-window",
    match = {
        class = "^(Gazebo GUI|Gazebo)$",
        xwayland = true,
    },

    float = false,
    focus_on_activate = true,
})

-- Fullscreen gaming
hl.window_rule({
    name = "fullscreen-games",
    match = {
        content = "game",
    },

    float = true,
    fullscreen = true,
})
