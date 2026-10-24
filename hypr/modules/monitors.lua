------------------
---- MONITORS ----
------------------

-- nwg-displays saves your layout to ~/.config/hypr/monitors.lua. Use it when it exists. Otherwise every
-- output runs at its preferred mode; built-in laptop panels between 1920 and 2560 pixels wide get scale
-- 1.25 when that gives a whole-pixel desktop (1920x1080 -> 1536x864), everything else uses "auto".
-- Settings > Displays saves per-output overrides to monitors_custom.lua, loaded last.
local sysroot = os.getenv("SLEEK_SYS_ROOT") or ""

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local l = f:read("l")
    f:close()
    return l
end

-- scale 1.25 only when both logical dimensions are whole numbers and the panel is in the range where
-- 1.0 is too small and 1.5 too large
local function clean_scale(w, h)
    if w >= 1920 and w <= 2560 and h >= 1080 and (w * 4) % 5 == 0 and (h * 4) % 5 == 0 then return 1.25 end
    return nil
end

local function internal_panels()
    local out = {}
    local p = io.popen('ls -1 "' .. sysroot .. '/sys/class/drm" 2>/dev/null')
    if not p then return out end
    for entry in p:lines() do
        local conn = entry:match("^card%d+%-(.+)$")
        if conn and (conn:match("^eDP") or conn:match("^LVDS") or conn:match("^DSI")) then
            local dir = sysroot .. "/sys/class/drm/" .. entry
            if read_first_line(dir .. "/status") == "connected" then
                local w, h = (read_first_line(dir .. "/modes") or ""):match("^(%d+)x(%d+)")
                if w then out[#out + 1] = { name = conn, width = tonumber(w), height = tonumber(h) } end
            end
        end
    end
    p:close()
    return out
end

local M = { clean_scale = clean_scale, internal_panels = internal_panels, applied = {} }

local ok = pcall(require, "monitors")
if not ok then
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
    for _, mon in ipairs(internal_panels()) do
        local s = clean_scale(mon.width, mon.height)
        if s then
            hl.monitor({ output = mon.name, mode = "preferred", position = "auto", scale = s })
            M.applied[mon.name] = s
        end
    end
end

-- Overrides saved by the Quickshell monitor settings (separate from the nwg-displays files).
pcall(require, "monitors_custom")

return M
