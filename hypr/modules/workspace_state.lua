--[[
Independent per-monitor workspace allocation for Hyprland (0.55+ Lua config).

This module owns the mapping "which workspace IDs belong to which monitor and
in which order". It is deliberately free of side effects on load, so it can be
required from anywhere -- including `hyprctl eval`, which is how the Quickshell
overview asks for a new workspace without spawning a helper process.

The allocation lives in a tiny line based file so that both Lua (here) and QML
(the Quickshell overview) can read it without needing a JSON parser:

    v 1
    next 11
    m eDP-1 1            <- monitor name, its default workspace id
    m HDMI-A-1 6
    w eDP-1 1            <- one line per workspace, in display order
    w eDP-1 2
    w HDMI-A-1 6

Monitors are identified by their output *name* (eDP-1, HDMI-A-1, ...), never by
their position in an array, so a monitor keeps its workspaces when other
displays are plugged in or unplugged.

Rules that belong to the existing desktop config (the nwg-displays generated
workspaces.lua) are used as the seed, so the layout the user already has is
preserved exactly. Anything created afterwards is appended on top of that.
]]

local M = {}

-- How many workspaces a monitor gets when it shows up for the first time and
-- nothing else is known about it.
M.DEFAULT_PER_MONITOR = 5

local function xdg_dir(env, fallback)
    local v = os.getenv(env)
    if v and v ~= "" then return v end
    return fallback
end

local function home()
    local h = os.getenv("HOME")
    if h and h ~= "" then return h end
    return "/root"
end

M.state_path = xdg_dir("XDG_STATE_HOME", home() .. "/.local/state") .. "/hyprland/workspaces.txt"
M.hypr_dir = xdg_dir("XDG_CONFIG_HOME", home() .. "/.config") .. "/hypr"

--------------------------------------------------------------------------------------
-- state file
--------------------------------------------------------------------------------------

local function new_state()
    return { version = 1, next = 1, monitors = {}, order = {} }
end

-- Reads the allocation file. Returns nil when it does not exist yet.
function M.read()
    local f = io.open(M.state_path, "r")
    if not f then return nil end

    local st = new_state()
    local seen = {}
    for line in f:lines() do
        local t = {}
        for word in line:gmatch("%S+") do t[#t + 1] = word end
        local kind = t[1]
        if kind == "v" then
            st.version = tonumber(t[2]) or 1
        elseif kind == "next" then
            st.next = tonumber(t[2]) or 1
        elseif kind == "m" and t[2] then
            local name = t[2]
            if not st.monitors[name] then
                st.monitors[name] = { workspaces = {}, set = {}, default = nil }
                st.order[#st.order + 1] = name
            end
            st.monitors[name].default = tonumber(t[3])
        elseif kind == "w" and t[2] and t[3] then
            local name = t[2]
            local id = tonumber(t[3])
            if not st.monitors[name] then
                st.monitors[name] = { workspaces = {}, set = {}, default = nil }
                st.order[#st.order + 1] = name
            end
            local m = st.monitors[name]
            if id and not m.set[id] then
                m.set[id] = true
                m.workspaces[#m.workspaces + 1] = id
            end
        end
        seen[#seen + 1] = kind
    end
    f:close()

    -- keep the in-file order of the monitors
    local order = {}
    for _, name in ipairs(st.order) do order[#order + 1] = name end
    st.order = order

    return st
end

function M.write(st)
    local dir = M.state_path:match("^(.*)/[^/]+$")
    if dir then os.execute("mkdir -p '" .. dir .. "'") end

    local f = io.open(M.state_path, "w")
    if not f then return false end
    f:write("v ", tostring(st.version or 1), "\n")
    f:write("next ", tostring(st.next or 1), "\n")
    for _, name in ipairs(st.order) do
        local m = st.monitors[name]
        if m then
            f:write("m ", name, " ", tostring(m.default or (m.workspaces[1] or 1)), "\n")
            for _, id in ipairs(m.workspaces) do
                f:write("w ", name, " ", tostring(id), "\n")
            end
        end
    end
    f:close()
    return true
end

--------------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------------

function M.monitor_entry(st, name)
    local m = st.monitors[name]
    if not m then
        m = { workspaces = {}, set = {}, default = nil }
        st.monitors[name] = m
        st.order[#st.order + 1] = name
    end
    return m
end

-- Every workspace id that is currently in use by any monitor.
function M.used_ids(st)
    local used = {}
    for _, name in ipairs(st.order) do
        local m = st.monitors[name]
        if m then
            for _, id in ipairs(m.workspaces) do used[id] = true end
        end
    end
    return used
end

-- Lowest free positive workspace id at or above `from`.
local function next_free_id(st, from)
    local used = M.used_ids(st)
    local id = math.max(1, from or 1)
    while used[id] do id = id + 1 end
    return id
end

--------------------------------------------------------------------------------------
-- seeding
--------------------------------------------------------------------------------------

-- Parses the nwg-displays generated workspaces.lua so the allocation starts out
-- exactly like the layout the user already has.
function M.seed_from_static()
    local path = M.hypr_dir .. "/workspaces.lua"
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local map, order = {}, {}
    for block in content:gmatch("hl%.workspace_rule%(%s*{(.-)}%)") do
        local ws = block:match('workspace%s*=%s*"([^"]*)"')
        local mon = block:match('monitor%s*=%s*"([^"]*)"')
        local is_default = block:match("default%s*=%s*true") ~= nil
        if ws and mon and ws:match("^%d+$") then
            local id = tonumber(ws)
            if not map[mon] then
                map[mon] = { workspaces = {}, set = {}, default = nil }
                order[#order + 1] = mon
            end
            local m = map[mon]
            if not m.set[id] then
                m.set[id] = true
                m.workspaces[#m.workspaces + 1] = id
            end
            if is_default then m.default = id end
        end
    end

    if #order == 0 then return nil end
    return map, order
end

-- Builds the initial allocation: the static rules first, then anything the
-- live compositor already knows about.
function M.seed()
    local st = new_state()
    local map, order = M.seed_from_static()

    if map then
        for _, name in ipairs(order) do
            local src = map[name]
            local m = M.monitor_entry(st, name)
            for _, id in ipairs(src.workspaces) do
                m.set[id] = true
                m.workspaces[#m.workspaces + 1] = id
            end
            m.default = src.default or m.workspaces[1]
        end
    end

    -- Workspaces that Hyprland already has but that no rule covers (for example
    -- a workspace created before this manager existed) keep their monitor.
    if hl and hl.get_workspaces then
        for _, ws in ipairs(hl.get_workspaces()) do
            if not ws.special and ws.id and ws.id > 0 then
                local owner = nil
                for _, name in ipairs(st.order) do
                    if st.monitors[name].set[ws.id] then owner = name end
                end
                if not owner and ws.monitor and ws.monitor.name then
                    owner = ws.monitor.name
                    local m = M.monitor_entry(st, owner)
                    m.set[ws.id] = true
                    m.workspaces[#m.workspaces + 1] = ws.id
                    if not m.default then m.default = ws.id end
                end
            end
        end
    end

    -- Any monitor we do not know anything about yet gets a fresh block.
    if hl and hl.get_monitors then
        for _, mon in ipairs(hl.get_monitors()) do
            local m = st.monitors[mon.name]
            if not m then
                m = M.monitor_entry(st, mon.name)
                for i = 1, M.DEFAULT_PER_MONITOR do
                    local id = next_free_id(st, st.next)
                    st.next = id + 1
                    m.set[id] = true
                    m.workspaces[#m.workspaces + 1] = id
                end
                m.default = m.workspaces[1]
            end
        end
    end

    -- Normalise the "next id" counter so it is always above every used id.
    local max = 0
    for id in pairs(M.used_ids(st)) do if id > max then max = id end end
    if st.next <= max then st.next = max + 1 end

    return st
end

-- Reads the allocation, seeding it on the first run.
function M.load()
    local st = M.read()
    if not st then
        st = M.seed()
        M.write(st)
    end
    return st
end

--------------------------------------------------------------------------------------
-- allocation changes
--------------------------------------------------------------------------------------

-- Makes sure `name` has at least `count` workspaces and returns its entry.
function M.ensure(st, name, count)
    local m = M.monitor_entry(st, name)
    while #m.workspaces < count do
        local id = next_free_id(st, st.next)
        st.next = id + 1
        m.set[id] = true
        m.workspaces[#m.workspaces + 1] = id
    end
    if not m.default or not m.set[m.default] then m.default = m.workspaces[1] end
    return m
end

-- Allocates one more workspace on `name` and returns its id.
function M.create(st, name)
    local m = M.monitor_entry(st, name)
    local id = next_free_id(st, st.next)
    st.next = id + 1
    m.set[id] = true
    m.workspaces[#m.workspaces + 1] = id
    if not m.default then m.default = id end
    return id
end

-- Drops a workspace from a monitor. The default falls back to another one.
function M.remove(st, name, id)
    local m = st.monitors[name]
    if not m then return false end
    local kept, changed = {}, false
    for _, w in ipairs(m.workspaces) do
        if w == id then changed = true else kept[#kept + 1] = w end
    end
    if not changed then return false end
    m.workspaces = kept
    m.set = {}
    for _, w in ipairs(kept) do m.set[w] = true end
    if m.default == id or not m.set[m.default] then m.default = kept[1] end
    return true
end

function M.set_default(st, name, id)
    local m = st.monitors[name]
    if not m or not m.set[id] then return false end
    m.default = id
    return true
end

--------------------------------------------------------------------------------------
-- operations used from the outside (the Quickshell overview calls these through
-- `hyprctl eval`, so they have to be safe to run in a throw-away Lua state)
--------------------------------------------------------------------------------------

-- Creates a workspace on `name`, applies its rule, saves the allocation and
-- switches to it. Returns the new workspace id.
function M.create_and_focus(name)
    local st = M.load()
    local id = M.create(st, name)
    M.apply_rule(id, name, false)
    M.write(st)
    if hl and hl.dispatch then
        hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
    end
    return id
end

-- Switches to a workspace. The rule is (re)applied first, so the workspace
-- always ends up on the monitor it is allocated to.
function M.focus_ws(name, id)
    local st = M.load()
    local m = st.monitors[name]
    if m and not m.set[id] then
        -- not allocated yet: take it over for this monitor
        for other, om in pairs(st.monitors) do
            om.set[id] = nil
            local kept = {}
            for _, w in ipairs(om.workspaces) do if w ~= id then kept[#kept + 1] = w end end
            om.workspaces = kept
        end
        local target = M.monitor_entry(st, name)
        target.set[id] = true
        target.workspaces[#target.workspaces + 1] = id
        M.write(st)
    end
    M.apply_rule(id, name, false)
    if hl and hl.dispatch then
        hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
    end
    return id
end

-- Removes a workspace from a monitor. Workspaces that still hold windows are
-- left alone, so nothing gets lost.
function M.remove_ws(name, id)
    local st = M.load()
    if hl and hl.get_workspace then
        local ws = hl.get_workspace(tostring(id))
        if ws and not ws.special and ws.windows and ws.windows > 0 then return false end
    end
    if not M.remove(st, name, id) then return false end
    M.write(st)
    return true
end

-- Moves a window to a workspace of a monitor. Hyprland keeps the floating,
-- pinned and fullscreen state of the window while it travels.
function M.move_window(address, name, id)
    if not (hl and hl.dispatch) then return false end
    local st = M.load()
    local m = st.monitors[name]
    if m and not m.set[id] then
        M.focus_ws(name, id)
    end
    M.apply_rule(id, name, false)
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), window = address }))
    return true
end

-- The monitor a workspace id belongs to, according to the allocation.
function M.owner_of(st, id)
    for _, name in ipairs(st.order) do
        local m = st.monitors[name]
        if m and m.set[id] then return name end
    end
    return nil
end

--------------------------------------------------------------------------------------
-- applying the rules to Hyprland
--------------------------------------------------------------------------------------

-- Applies a single workspace rule.
function M.apply_rule(id, monitor, is_default)
    if not hl or not hl.workspace_rule then return false end
    local rule = { workspace = tostring(id), monitor = monitor }
    if is_default then rule.default = true end
    hl.workspace_rule(rule)
    return true
end

-- Applies the whole allocation as workspace rules. Rules are also applied for
-- monitors that are currently disconnected: Hyprland keeps them, so a monitor
-- that comes back gets exactly the workspaces it had before.
function M.apply_rules(st)
    for _, name in ipairs(st.order) do
        local m = st.monitors[name]
        if m then
            for _, id in ipairs(m.workspaces) do
                M.apply_rule(id, name, id == m.default)
            end
        end
    end
end

return M
