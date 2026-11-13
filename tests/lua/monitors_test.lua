-- modules/monitors.lua: load the nwg-displays layout when it exists, otherwise apply one
-- safe preferred-mode fallback; then load the optional monitors_custom.lua override.
-- Runs from hypr/ with HOME pointing at a scratch dir.
package.path = "./?.lua;" .. package.path
local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local home = os.getenv("HOME")
local config = home .. "/.config/hypr"

local rules = {}
hl = {
    monitor = function(r) rules[#rules + 1] = r end,
    print = function() end,
}

-- No generated layout: exactly one catch-all, preferred mode, scale 1.25.
package.loaded["modules.monitors"] = nil
require("modules.monitors")
if #rules ~= 1 then fail("without a layout there should be one fallback rule, got " .. #rules) end
local r = rules[1]
if r.output ~= "" or r.mode ~= "preferred" or r.scale ~= "1.25" then
    fail("fallback should be preferred mode at scale 1.25")
end

-- A generated layout is executed and replaces the fallback.
os.execute('mkdir -p "' .. config .. '"')
local f = io.open(config .. "/monitors.lua", "w")
f:write('hl.monitor({ output = "eDP-1", mode = "1920x1080", position = "0x0", scale = 1.25 })\n')
f:close()
rules = {}
package.loaded["modules.monitors"] = nil
require("modules.monitors")
if #rules ~= 1 or rules[1].output ~= "eDP-1" then
    fail("the nwg-displays layout should be applied without a fallback, got " .. #rules .. " rule(s)")
end

-- monitors_custom.lua is applied after the generated layout.
f = io.open(config .. "/monitors_custom.lua", "w")
f:write('hl.monitor({ output = "HDMI-A-1", mode = "2560x1440", position = "1920x0", scale = 1 })\n')
f:close()
rules = {}
package.loaded["modules.monitors"] = nil
require("modules.monitors")
if #rules ~= 2 then fail("expected the generated layout plus the custom override, got " .. #rules) end
if rules[1].output ~= "eDP-1" or rules[2].output ~= "HDMI-A-1" then
    fail("monitors_custom.lua should be applied last")
end

-- A broken generated layout logs and falls back instead of aborting the config.
os.remove(config .. "/monitors_custom.lua")
f = io.open(config .. "/monitors.lua", "w")
f:write("this is not lua\n")
f:close()
rules = {}
package.loaded["modules.monitors"] = nil
require("modules.monitors")
if #rules ~= 1 or rules[1].output ~= "" then
    fail("a broken layout should fall back to the safe rule, got " .. #rules)
end

print("ok")
