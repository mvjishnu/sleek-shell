--[[
Sleek Shell mouse cursor.

Reads the cursor theme and size chosen in Sleek Shell Settings > Fonts, icons & cursors from
~/.config/sleek-shell/hypr-cursor.lua and exports them as XCURSOR_* / HYPRCURSOR_* so every app
started from Hyprland uses the same cursor. modules/environment_variables.lua calls apply() on each
config load; the shell switches the live cursor itself with `hyprctl setcursor THEME SIZE`.

Values are validated; a missing or broken state file keeps the defaults (system cursor, size 24).
]]

local M = {}

local HOME = os.getenv("HOME") or ""
M.state_path = HOME .. "/.config/sleek-shell/hypr-cursor.lua"
M.defaults = { theme = "", size = 24 }

function M.load()
    local s = { theme = M.defaults.theme, size = M.defaults.size }
    local ok, t = pcall(dofile, M.state_path)
    if not ok or type(t) ~= "table" then return s end
    if type(t.theme) == "string" and #t.theme > 0 and #t.theme < 100 and t.theme:match("^[%w%._%+%- ]+$") then
        s.theme = t.theme
    end
    local n = tonumber(t.size)
    if n and n == n then s.size = math.floor(math.max(16, math.min(96, n))) end
    return s
end

function M.apply()
    local s = M.load()
    hl.env("XCURSOR_SIZE", tostring(s.size))
    hl.env("HYPRCURSOR_SIZE", tostring(s.size))
    if s.theme ~= "" then
        hl.env("XCURSOR_THEME", s.theme)
        hl.env("HYPRCURSOR_THEME", s.theme)
    end
    return true
end

return M
