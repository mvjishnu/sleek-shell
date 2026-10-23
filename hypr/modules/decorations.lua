-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 6,
        border_size = 2,              -- subtle colorful focus outline (also exposed in Appearance)
        col = {
            active_border = { colors = { "rgba(7c9cffee)", "rgba(b68cffaa)" }, angle = 45 },
            inactive_border = "rgba(66667888)",
        },
        resize_on_border = false,
        allow_tearing = false,
    },

    decoration = {
        rounding       = 14,
        rounding_power = 2,

        -- focused window is MORE opaque than unfocused (it was the other way round before)
        active_opacity   = 0.88,
        inactive_opacity = 0.78,

        shadow = { enabled = false },

        -- glass: soft blur, a little noise and vibrancy. Lower size/passes = faster.
        blur = {
            enabled    = true,
            size       = 8,
            passes     = 3,
            noise      = 0.02,
            contrast   = 1.0,
            brightness = 1.0,
            vibrancy   = 0.17,
            popups     = true,
            new_optimizations = true,
        },
    },

    animations = { enabled = true },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- Animations and the user's look settings (borders, blur, rounding, gaps, opacity, motion speed /
-- reduced motion) are applied by sleekshell/look.lua from ~/.config/sleek-shell/hypr-look.lua, so they
-- survive `hyprctl reload`. The original animation table lives in sleekshell/look.lua unchanged.
local look_ok, look_err = pcall(function() require("sleekshell.look").apply() end)
if not look_ok then
    if hl.print then hl.print("[sleek-shell] look settings not applied: " .. tostring(look_err)) end
    hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
    hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
    hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
    hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
    hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
    hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
    hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
    hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
end
