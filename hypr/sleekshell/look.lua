--[[
Sleek Shell compositor look.

Applies the user's appearance and motion settings (window borders, blur, rounding, gaps,
opacity, shadows, animation speed / reduced motion) on top of modules/decorations.lua.

Values come from ~/.config/sleek-shell/hypr-look.lua, which the Sleek Shell settings (Quickshell)
generate. Because decorations.lua calls apply() on every config load, the settings survive
`hyprctl reload`. The shell applies changes live with:

    hyprctl eval "require('sleekshell.look').apply()"

Every value is validated here; a missing or broken state file falls back to the defaults,
so this module can never take the config down.
]]

local M = {}

local HOME = os.getenv("HOME") or ""
M.state_path = HOME .. "/.config/sleek-shell/hypr-look.lua"

M.defaults = {
    border_width = 2, colorful = true,
    accent = "7c9cff", secondary = "b68cff", inactive = "66667888",
    blur_enabled = true, blur_size = 8, blur_passes = 3, blur_brightness = 1.0,
    rounding = 14, gaps_in = 3, gaps_out = 6,
    active_opacity = 0.88, inactive_opacity = 0.78,
    shadows = false,
    anim_enabled = true, anim_speed = 1.0,
}

-- leaf, speed (deciseconds, lower = faster), curve kind, curve, style
-- These are the original decorations.lua animations; anim_speed divides the duration.
M.animations = {
    { "global",        10,   "bezier", "default" },
    { "border",        5.39, "bezier", "easeOutQuint" },
    { "windows",       4.79, "spring", "easy" },
    { "windowsIn",     4.1,  "spring", "easy",         "popin 87%" },
    { "windowsOut",    1.49, "bezier", "linear",       "popin 87%" },
    { "fadeIn",        1.73, "bezier", "almostLinear" },
    { "fadeOut",       1.46, "bezier", "almostLinear" },
    { "fade",          3.03, "bezier", "quick" },
    { "layers",        3.81, "bezier", "easeOutQuint" },
    { "layersIn",      4,    "bezier", "easeOutQuint", "fade" },
    { "layersOut",     1.5,  "bezier", "linear",       "fade" },
    { "fadeLayersIn",  1.79, "bezier", "almostLinear" },
    { "fadeLayersOut", 1.39, "bezier", "almostLinear" },
    { "workspaces",    1.94, "bezier", "almostLinear", "fade" },
    { "workspacesIn",  1.21, "bezier", "almostLinear", "fade" },
    { "workspacesOut", 1.94, "bezier", "almostLinear", "fade" },
    { "zoomFactor",    7,    "bezier", "quick" },
}

local function num(v, lo, hi, d)
    v = tonumber(v)
    if not v or v ~= v then return d end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function hex(v, len, d)
    if type(v) == "string" and #v == len and v:match("^%x+$") then return v:lower() end
    return d
end
local function bool(v, d)
    if type(v) == "boolean" then return v end
    return d
end

function M.load()
    local d, s = M.defaults, {}
    local ok, t = pcall(dofile, M.state_path)
    if not ok or type(t) ~= "table" then t = {} end
    s.border_width     = math.floor(num(t.border_width, 0, 6, d.border_width))
    s.colorful         = bool(t.colorful, d.colorful)
    s.accent           = hex(t.accent, 6, d.accent)
    s.secondary        = hex(t.secondary, 6, d.secondary)
    s.inactive         = hex(t.inactive, 8, d.inactive)
    s.blur_enabled     = bool(t.blur_enabled, d.blur_enabled)
    s.blur_size        = math.floor(num(t.blur_size, 1, 24, d.blur_size))
    s.blur_passes      = math.floor(num(t.blur_passes, 1, 6, d.blur_passes))
    s.blur_brightness  = num(t.blur_brightness, 0.6, 1.6, d.blur_brightness)
    s.rounding         = math.floor(num(t.rounding, 0, 30, d.rounding))
    s.gaps_in          = math.floor(num(t.gaps_in, 0, 30, d.gaps_in))
    s.gaps_out         = math.floor(num(t.gaps_out, 0, 60, d.gaps_out))
    s.active_opacity   = num(t.active_opacity, 0.3, 1, d.active_opacity)
    s.inactive_opacity = num(t.inactive_opacity, 0.3, 1, d.inactive_opacity)
    s.shadows          = bool(t.shadows, d.shadows)
    s.anim_enabled     = bool(t.anim_enabled, d.anim_enabled)
    s.anim_speed       = num(t.anim_speed, 0.25, 3, d.anim_speed)
    if s.secondary == s.accent then s.secondary = d.secondary end
    return s
end

function M.apply()
    local s = M.load()

    local active, inactive
    if s.border_width == 0 then
        active, inactive = "rgba(00000000)", "rgba(00000000)"
    elseif s.colorful then
        active = { colors = { "rgba(" .. s.accent .. "ee)", "rgba(" .. s.secondary .. "aa)" }, angle = 45 }
        inactive = "rgba(" .. s.inactive .. ")"
    else
        active = "rgba(" .. s.accent .. "cc)"
        inactive = "rgba(" .. s.inactive .. ")"
    end

    hl.config({
        general = {
            border_size = s.border_width,
            gaps_in = s.gaps_in,
            gaps_out = s.gaps_out,
            col = { active_border = active, inactive_border = inactive },
        },
        decoration = {
            rounding = s.rounding,
            active_opacity = s.active_opacity,
            inactive_opacity = s.inactive_opacity,
            shadow = { enabled = s.shadows, range = 18, render_power = 3, color = "rgba(0000004d)" },
            blur = {
                enabled = s.blur_enabled,
                size = s.blur_size,
                passes = s.blur_passes,
                brightness = s.blur_brightness,
            },
        },
        animations = { enabled = s.anim_enabled },
    })

    if s.anim_enabled then
        for _, a in ipairs(M.animations) do
            local spec = { leaf = a[1], enabled = true, speed = math.max(0.1, a[2] / s.anim_speed) }
            spec[a[3]] = a[4]
            if a[5] then spec.style = a[5] end
            hl.animation(spec)
        end
    end
    return true
end

return M
