-- Dynamic, hotplug-safe monitor manager.
--
-- Plug in / unplug / swap any monitor (HDMI, USB-C, docks) at any time, in any order.
--   * Every requested mode is checked against the modes the monitor actually reports, so
--     an unsupported refresh rate (stutter / black screen) can never be applied.
--   * Settings are tied to the physical monitor (its description), never just the port.
--   * Positions are NOT taken from a fixed saved layout. All active monitors are packed
--     left-to-right with no gaps (bottom-aligned) every time something changes. Order is
--     remembered per monitor; a monitor never seen before is added on the right.
--   * nwg-displays (~/.config/hypr/monitors.lua) and ~/.config/hypr/monitors_custom.lua
--     still supply mode / scale / rotation per monitor, and their left-to-right order is
--     used to seed the order whenever you save a new layout there.
--
-- Keys (act on the monitor under the mouse):
--   SUPER+ALT+Left / Right   move this monitor one place left / right in the row
--   SUPER+ALT+R              rotate this monitor 90°
--   SUPER+ALT+P              reset this monitor (native mode, auto scale, no rotation)
--   SUPER+ALT+M              cycle: extend -> mirror laptop -> external only -> laptop only
local home = os.getenv("HOME") or ""
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local state_dir = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/hypr"
local state_file = state_dir .. "/monitor-layout.lua"
local log = (hl and hl.print) or function() end

_G.__monmgr = _G.__monmgr or {}
local S = _G.__monmgr
S.rules = {}

local real_monitor = hl.monitor

-- Catch-all: anything without a rule gets its native mode, auto position, auto scale.
real_monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

------------------------------------------------------------------------------ state
local function load_state()
    local ok, t = pcall(dofile, state_file)
    t = (ok and type(t) == "table") and t or {}
    t.order = t.order or {}
    t.transform = t.transform or {}
    t.reset = t.reset or {}
    t.mode = t.mode or "extend"
    return t
end

local function ser(v)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local key = type(k) == "number" and "" or ("[" .. string.format("%q", k) .. "]=")
            parts[#parts + 1] = key .. ser(x)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(v) == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end

local function save_state()
    os.execute("mkdir -p '" .. state_dir .. "'")
    local f = io.open(state_file, "w")
    if f then f:write("return " .. ser(S.state) .. "\n"); f:close() end
end

S.state = load_state()

------------------------------------------------------------------------------ rules
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a"); f:close()
    return s
end

local function collect(path)
    if not read_file(path) then return end
    hl.monitor = function(spec) S.rules[#S.rules + 1] = spec end
    local ok, err = pcall(dofile, path)
    hl.monitor = real_monitor
    if not ok then log("[monitors] could not load " .. path .. ": " .. tostring(err)) end
end
local nwg_path = config .. "/hypr/monitors.lua"
collect(nwg_path)                             -- owned by nwg-displays
collect(config .. "/hypr/monitors_custom.lua") -- your overrides (win over the above)

local function key(mon)
    return (mon.description and mon.description ~= "") and mon.description or mon.name
end
local function is_internal(name) return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI") end

local function find_rule(mon)
    local by_desc, by_port
    local d = mon.description or ""
    for _, r in ipairs(S.rules) do
        local out = r.output or ""
        if out:sub(1, 5) == "desc:" then
            local want = out:sub(6)
            if d == want or d:sub(1, #want) == want then by_desc = r end
        elseif out == mon.name then
            by_port = r
        end
    end
    return by_desc, by_port
end

-- When nwg-displays saves a new layout, seed the remembered order from its x positions.
do
    local content = read_file(nwg_path) or ""
    -- (nil and "" both mean "no layout yet": do not create a state file just for that)
    if content ~= (S.state.nwg_seen or "") then
        S.state.nwg_seen = content
        -- Port-based rules (nwg-displays "use desc" off) describe whatever is plugged in right
        -- now, since the file was just saved; translate them to that monitor's identity.
        local by_port = {}
        for _, m in ipairs(hl.get_monitors({ all = true }) or {}) do
            if m.name then by_port[m.name] = (m.description and m.description ~= "") and m.description or m.name end
        end
        local seeded = {}
        for _, r in ipairs(S.rules) do
            local out, x = r.output or "", tonumber(tostring(r.position or ""):match("^(-?%d+)x"))
            local k = out:sub(1, 5) == "desc:" and out:sub(6) or by_port[out]
            if k and x then seeded[#seeded + 1] = { k = k, x = x } end
        end
        if #seeded > 0 then
            table.sort(seeded, function(a, b) return a.x < b.x end)
            local order, seen = {}, {}
            for _, s in ipairs(seeded) do order[#order + 1] = s.k; seen[s.k] = true end
            for _, k in ipairs(S.state.order) do if not seen[k] then order[#order + 1] = k end end
            S.state.order = order
            S.state.reset = {}
            S.state.transform = {}
        end
        save_state()
    end
end

------------------------------------------------------------------------------ modes
local function modes_of(mon)
    local list = {}
    if type(mon.available_modes) == "table" then
        for _, m in pairs(mon.available_modes) do
            if type(m) == "table" and m.width then list[#list + 1] = m end
        end
    end
    return list
end

local function fmt(m) return string.format("%dx%d@%.3f", m.width, m.height, m.refresh_rate) end

-- A mode string the monitor really supports, or nil if that resolution doesn't exist on it.
local function validate_mode(mode, mon)
    if type(mode) ~= "string" or mode == "" then return "preferred" end
    local w, h, r = mode:match("^(%d+)x(%d+)@?([%d%.]*)")
    if not w then return mode end -- keywords: preferred / highrr / highres / maxwidth
    w, h, r = tonumber(w), tonumber(h), tonumber(r)
    local modes = modes_of(mon)
    if #modes == 0 then return "preferred" end
    local same = {}
    for _, m in ipairs(modes) do if m.width == w and m.height == h then same[#same + 1] = m end end
    if #same == 0 then return nil end
    if r then
        for _, m in ipairs(same) do if math.abs(m.refresh_rate - r) < 0.6 then return fmt(m) end end
    end
    local best
    for _, m in ipairs(same) do if m.preferred then best = m end end
    if not best then
        for _, m in ipairs(same) do
            if (not r or m.refresh_rate <= r) and (not best or m.refresh_rate > best.refresh_rate) then best = m end
        end
    end
    return fmt(best or same[1])
end

------------------------------------------------------------------------------ layout
local function physical_monitors()
    local list = {}
    for _, mon in ipairs(hl.get_monitors({ all = true }) or {}) do
        if mon.name and mon.name ~= "FALLBACK" and not mon.name:match("^HEADLESS") then list[#list + 1] = mon end
    end
    return list
end

local function base_spec(mon)
    local k = key(mon)
    local spec = { mode = "preferred", scale = "auto", transform = 0 }
    if not S.state.reset[k] then
        local by_desc, by_port = find_rule(mon)
        local rule = by_desc
        -- A port-only rule may belong to a different monitor that used this port before:
        -- trust it for the built-in panel, for external ports only if its resolution exists here.
        if not rule and by_port and (is_internal(mon.name) or validate_mode(by_port.mode, mon)) then
            rule = by_port
        end
        if rule then
            for f, v in pairs(rule) do
                if f ~= "output" and f ~= "position" and f ~= "mirror" and f ~= "disabled" then spec[f] = v end
            end
            spec.mode = validate_mode(rule.mode, mon) or "preferred"
        end
    end
    if S.state.transform[k] ~= nil then spec.transform = S.state.transform[k] end
    spec.output = (mon.description and mon.description ~= "") and ("desc:" .. mon.description) or mon.name
    spec.disabled = false
    spec.mirror = "" -- clears a previous mirror
    return spec
end

local function push(spec)
    local ok, err = pcall(real_monitor, spec)
    if not ok then
        log("[monitors] rule for " .. spec.output .. " failed: " .. tostring(err))
        pcall(real_monitor, { output = spec.output, mode = "preferred", position = "auto", scale = "auto" })
    end
end

local function order_index(k)
    for i, v in ipairs(S.state.order) do if v == k then return i end end
    S.state.order[#S.state.order + 1] = k -- never seen before: goes on the right
    save_state()
    return #S.state.order
end

-- Pass 2: pack active, non-mirrored monitors left-to-right using their real logical size.
local function place()
    local active = {}
    for _, mon in ipairs(physical_monitors()) do
        if mon.enabled and not mon.is_mirror then active[#active + 1] = mon end
    end
    table.sort(active, function(a, b) return order_index(key(a)) < order_index(key(b)) end)
    local sizes, maxh = {}, 0
    for i, mon in ipairs(active) do
        local w, h = mon.width or 1920, mon.height or 1080
        if (mon.transform or 0) % 2 == 1 then w, h = h, w end
        local sc = (mon.scale and mon.scale > 0) and mon.scale or 1
        sizes[i] = { w = math.floor(w / sc + 0.5), h = math.floor(h / sc + 0.5) }
        if sizes[i].h > maxh then maxh = sizes[i].h end
    end
    local x = 0
    for i, mon in ipairs(active) do
        local y = maxh - sizes[i].h
        if mon.x ~= x or mon.y ~= y then
            local spec = S.specs and S.specs[key(mon)] or base_spec(mon)
            spec.position = x .. "x" .. y
            push(spec)
        end
        x = x + sizes[i].w
    end
end

-- Pass 1: modes / scale / rotation / mirror / disable for every connected monitor.
local function layout()
    local mons = physical_monitors()
    local internal, externals = nil, {}
    for _, mon in ipairs(mons) do
        if is_internal(mon.name) then internal = internal or mon else externals[#externals + 1] = mon end
    end
    local mode = S.state.mode
    if not internal or #externals == 0 then mode = "extend" end

    S.specs = {}
    for _, mon in ipairs(mons) do
        local spec = base_spec(mon)
        local ext = not is_internal(mon.name)
        if mode == "mirror" and ext then
            spec.mirror = internal.name
        elseif mode == "external" and not ext then
            spec.disabled = true
        elseif mode == "internal" and ext then
            spec.disabled = true
        end
        -- Keep the current spot during the mode change; pass 2 moves it if needed.
        spec.position = (mon.enabled and mon.x) and (mon.x .. "x" .. mon.y) or "auto"
        S.specs[key(mon)] = spec
        push(spec)
    end

    -- Let Hyprland settle (auto scale, enable/disable), then pack the row. Nothing to place without
    -- monitors (e.g. `Hyprland --verify-config`, where hl.timer also crashes Hyprland 0.57).
    if #mons == 0 or not hl.timer then return end
    S.place_timer = hl.timer(function() pcall(place) end, { timeout = 400, type = "oneshot" })
end
S.layout = function() local ok, err = pcall(layout); if not ok then log("[monitors] " .. tostring(err)) end end

S.layout()

if not S.hooked and hl.on then
    S.hooked = true
    hl.on("monitor.added", function() S.layout() end)
    hl.on("monitor.removed", function() S.layout() end)
    hl.on("config.reloaded", function() S.layout() end)
end

------------------------------------------------------------------------------ keys
local function here() return hl.get_monitor_at_cursor() or hl.get_active_monitor() end
local function notify(msg) hl.exec_cmd("notify-send -a Displays -t 2000 'Displays' '" .. msg .. "'") end

local function move(dir)
    local mon = here()
    if not mon then return end
    -- Work on the order of currently active monitors only.
    local active = {}
    for _, m in ipairs(physical_monitors()) do
        if m.enabled and not m.is_mirror then active[#active + 1] = key(m) end
    end
    table.sort(active, function(a, b) return order_index(a) < order_index(b) end)
    local k, pos = key(mon), nil
    for i, v in ipairs(active) do if v == k then pos = i end end
    local other = pos and active[pos + dir]
    if not other then return end
    local i1, i2 = order_index(k), order_index(other)
    S.state.order[i1], S.state.order[i2] = other, k
    save_state()
    S.layout()
end

hl.bind("SUPER + ALT + Left", function() move(-1) end)
hl.bind("SUPER + ALT + Right", function() move(1) end)

hl.bind("SUPER + ALT + R", function()
    local mon = here()
    if not mon then return end
    S.state.transform[key(mon)] = ((mon.transform or 0) + 1) % 4
    save_state()
    S.layout()
end)

hl.bind("SUPER + ALT + P", function()
    local mon = here()
    if not mon then return end
    local k = key(mon)
    S.state.reset[k] = true
    S.state.transform[k] = nil
    save_state()
    S.layout()
    notify("Reset " .. mon.name .. " to its native mode")
end)

local cycle = { extend = "mirror", mirror = "external", external = "internal", internal = "extend" }
local labels = { extend = "Extend", mirror = "Mirror laptop screen", external = "External monitors only", internal = "Laptop screen only" }
hl.bind("SUPER + ALT + M", function()
    S.state.mode = cycle[S.state.mode] or "extend"
    save_state()
    S.layout()
    notify(labels[S.state.mode])
end)
