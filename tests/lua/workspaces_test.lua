-- Regression: modules/workspaces.lua must handle a monitor it has never seen (fresh install) without
-- "attempt to call a table value", and must persist the allocation so the next reload is clean.
-- Run from the hypr/ directory with HOME / XDG_STATE_HOME pointing at a scratch dir.
package.path = "./?.lua;" .. package.path

local printed, rules, handlers = {}, {}, {}
local monitors = { { name = "eDP-1", width = 1920, height = 1080, scale = 1 } }
hl = {
    print = function(s) printed[#printed + 1] = s end,
    get_monitors = function() return monitors end,
    get_workspaces = function() return {} end,
    get_workspace = function() return nil end,
    workspace_rule = function(r) rules[#rules + 1] = r end,
    dispatch = function() end,
    dsp = { focus = function(t) return t end, workspace = { move = function(t) return t end },
            window = { move = function(t) return t end } },
    on = function(ev, fn) handlers[ev] = fn end,
}

local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local ok, err = pcall(require, "modules.workspaces")
if not ok then fail("first load on a fresh state: " .. tostring(err)) end
if #rules == 0 then fail("no workspace rules were applied") end

-- a monitor that is not in the saved allocation yet: this is the path that crashed
monitors[#monitors + 1] = { name = "HDMI-A-1", width = 2560, height = 1440, scale = 1 }
local okh, errh = pcall(handlers["monitor.added"], monitors[2])
if not okh then fail("monitor.added for an unknown monitor: " .. tostring(errh)) end
if #printed ~= 1 then fail("expected one 'new monitor' log line, got " .. #printed) end

local state = require("modules.workspace_state")
local f = io.open(state.state_path, "r")
if not f then fail("allocation was not saved to " .. state.state_path) end
local txt = f:read("a"); f:close()
if not txt:find("m eDP%-1") or not txt:find("m HDMI%-A%-1") then fail("allocation misses a monitor:\n" .. txt) end

for _, ev in ipairs({ "config.reloaded", "hyprland.start" }) do
    if not handlers[ev] then fail("no handler for " .. ev) end
    printed = {}
    local ok2, err2 = pcall(handlers[ev])
    if not ok2 then fail(ev .. ": " .. tostring(err2)) end
    if #printed ~= 0 then fail(ev .. " treated a known monitor as new") end
end
local ok3, err3 = pcall(handlers["monitor.added"], { name = "eDP-1" })
if not ok3 then fail("monitor.added: " .. tostring(err3)) end
print("ok")
