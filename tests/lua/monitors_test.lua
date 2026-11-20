-- modules/monitors.lua: the dynamic monitor manager. Rules from nwg-displays' monitors.lua and the optional
-- monitors_custom.lua are validated against the modes each monitor reports, then active monitors are packed
-- left to right. Runs from hypr/ with HOME and XDG_STATE_HOME pointing at a scratch dir.
package.path = "./?.lua;" .. package.path
local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local home = os.getenv("HOME")
local config = home .. "/.config/hypr"
os.execute('mkdir -p "' .. config .. '"')

local function write(path, text)
    local f = assert(io.open(path, "w")); f:write(text); f:close()
end

local function mode(w, h, r, pref) return { width = w, height = h, refresh_rate = r, preferred = pref } end

local rules, binds, timers, monitors
local function load()
    rules, binds, timers = {}, {}, 0
    _G.__monmgr = nil
    hl = {
        monitor = function(r) rules[#rules + 1] = r end,
        print = function() end,
        get_monitors = function() return monitors end,
        timer = function(fn) timers = timers + 1; fn() end, -- run the packing pass immediately
        on = function() end,
        bind = function(keys) binds[#binds + 1] = keys end,
        exec_cmd = function() end,
        get_monitor_at_cursor = function() return monitors[1] end,
        get_active_monitor = function() return monitors[1] end,
    }
    package.loaded["modules.monitors"] = nil
    require("modules.monitors")
end

-- last rule pushed for an output
local function rule_for(out)
    local found
    for _, r in ipairs(rules) do if r.output == out then found = r end end
    return found
end

-- 1. No monitors (e.g. Hyprland --verify-config): only the catch-all, and no timer (hl.timer crashes there).
monitors = {}
load()
if #rules ~= 1 then fail("without monitors there should be only the catch-all rule, got " .. #rules) end
if rules[1].output ~= "" or rules[1].mode ~= "preferred" then fail("the catch-all should use the preferred mode") end
if timers ~= 0 then fail("no packing timer should be scheduled without monitors") end
if #binds ~= 5 then fail("expected the five SUPER+ALT monitor binds, got " .. #binds) end

-- 2. An unsupported refresh rate from a port-based nwg-displays rule is never applied.
write(config .. "/monitors.lua",
    'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "0x0", scale = 1 })\n')
monitors = {
    { name = "HDMI-A-1", description = "TXD Monitor", enabled = true, width = 1920, height = 1080, scale = 1,
      x = 0, y = 0, available_modes = { mode(1920, 1080, 100), mode(1920, 1080, 60), mode(1280, 720, 60) } },
}
load()
local r = rule_for("desc:TXD Monitor")
if not r then fail("the monitor rule should be keyed by its description") end
if r.mode ~= "1920x1080@100.000" then fail("144 Hz is not offered: expected the 100 Hz mode, got " .. tostring(r.mode)) end
if timers ~= 1 then fail("one packing pass should be scheduled, got " .. timers) end

-- 3. A port rule whose resolution the new monitor does not have is ignored.
write(config .. "/monitors.lua",
    'hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1 })\n')
load()
r = rule_for("desc:TXD Monitor")
if not r or r.mode ~= "preferred" then fail("a foreign port rule should fall back to preferred, got " .. tostring(r and r.mode)) end

-- 4. monitors_custom.lua with a desc: rule wins over the nwg-displays port rule.
write(config .. "/monitors_custom.lua", 'hl.monitor({ output = "desc:TXD Monitor", mode = "1280x720@60", scale = 1 })\n')
load()
r = rule_for("desc:TXD Monitor")
if not r or r.mode ~= "1280x720@60.000" then fail("the desc: override should apply 1280x720@60, got " .. tostring(r and r.mode)) end
os.remove(config .. "/monitors_custom.lua")

-- 5. Packing: laptop (1920x1080 at scale 1.25 = 1536x864 logical) then the external, bottom-aligned, no gaps.
os.remove(config .. "/monitors.lua")
os.execute('mkdir -p "' .. os.getenv("XDG_STATE_HOME") .. '/hypr"')
write(os.getenv("XDG_STATE_HOME") .. "/hypr/monitor-layout.lua",
    'return { order = { "Laptop Panel", "TXD Monitor" }, transform = {}, reset = {}, mode = "extend" }\n')
monitors = {
    { name = "eDP-1", description = "Laptop Panel", enabled = true, width = 1920, height = 1080, scale = 1.25,
      x = 500, y = 500, available_modes = { mode(1920, 1080, 60, true) } },
    { name = "HDMI-A-1", description = "TXD Monitor", enabled = true, width = 1920, height = 1080, scale = 1,
      x = 0, y = 0, available_modes = { mode(1920, 1080, 100, true) } },
}
load()
local lap, ext = rule_for("desc:Laptop Panel"), rule_for("desc:TXD Monitor")
if not lap or lap.position ~= "0x216" then fail("laptop should be at 0x216, got " .. tostring(lap and lap.position)) end
if not ext or ext.position ~= "1536x0" then fail("external should be packed at 1536x0, got " .. tostring(ext and ext.position)) end

-- 6. A broken nwg-displays file is logged, not fatal.
write(config .. "/monitors.lua", "this is not lua\n")
load()
if not rule_for("") then fail("a broken layout should still leave the catch-all rule") end
if not rule_for("desc:Laptop Panel") then fail("a broken layout should still configure the monitors") end

print("ok")
