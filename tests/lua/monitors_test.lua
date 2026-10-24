-- modules/monitors.lua: built-in panels get scale 1.25 only when it is clean; external outputs and
-- configured layouts are left alone. Runs from hypr/ with HOME pointing at a scratch dir.
package.path = "./?.lua;" .. package.path
local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local root = os.getenv("HOME") .. "/sysroot"
local function connector(name, status, mode)
    local d = root .. "/sys/class/drm/" .. name
    os.execute('mkdir -p "' .. d .. '"')
    local f = io.open(d .. "/status", "w"); f:write(status .. "\n"); f:close()
    f = io.open(d .. "/modes", "w"); f:write(mode .. "\n1280x720\n"); f:close()
end
connector("card2-eDP-1", "connected", "1920x1080")
connector("card1-HDMI-A-1", "connected", "1920x1080")
connector("card2-DP-2", "disconnected", "2560x1440")

local real_getenv = os.getenv
os.getenv = function(k) if k == "SLEEK_SYS_ROOT" then return root end return real_getenv(k) end

local rules = {}
hl = { monitor = function(r) rules[#rules + 1] = r end }

local m = require("modules.monitors")

local cases = { { 1920, 1080, 1.25 }, { 2560, 1440, 1.25 }, { 2560, 1600, 1.25 }, { 1920, 1200, 1.25 },
                { 1366, 768, nil }, { 3840, 2160, nil }, { 2880, 1800, nil }, { 1921, 1080, nil }, { 1600, 900, nil } }
for _, c in ipairs(cases) do
    if m.clean_scale(c[1], c[2]) ~= c[3] then fail(("clean_scale(%d, %d) should be %s"):format(c[1], c[2], tostring(c[3]))) end
end

if rules[1].output ~= "" or rules[1].scale ~= "auto" then fail("first rule must be the automatic catch-all") end
local edp
for _, r in ipairs(rules) do
    if r.output == "HDMI-A-1" then fail("external outputs must not get a fixed scale") end
    if r.output == "eDP-1" then edp = r end
end
if not edp or edp.scale ~= 1.25 then fail("eDP-1 1920x1080 should be scaled 1.25") end
if #rules ~= 2 then fail("expected 2 monitor rules, got " .. #rules) end

-- a saved nwg-displays layout wins: no catch-all and no automatic scale
package.loaded["modules.monitors"] = nil
package.preload["monitors"] = function() return true end
rules = {}
require("modules.monitors")
if #rules ~= 0 then fail("with monitors.lua present no rules should be added, got " .. #rules) end
print("ok")
