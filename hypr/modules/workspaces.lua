--[[
Independent workspace management for every connected monitor.

The allocation itself lives in workspace_state.lua; this file is the part that
talks to the compositor:

  * it applies the workspace rules (workspace -> monitor) so that Hyprland
    keeps every monitor on its own set of workspaces,
  * it reacts to monitors coming and going, so a display that is unplugged and
    plugged back in gets exactly the workspaces it had before,
  * it re-applies the rules after a config reload, because a reload throws away
    the rules that were added at runtime.

Everything is event driven: no timers, no polling, no extra processes.
]]

local state = require("modules.workspace_state")

local M = {}

-- Which rules are currently applied, as "monitor/id" -> isDefault.
-- Used so the same rule is not pushed over and over again.
local applied = {}

local function rule_key(monitor, id)
    return monitor .. "/" .. tostring(id)
end

-- Names of the monitors that are connected right now.
local function connected_monitors()
    local names = {}
    if hl and hl.get_monitors then
        for _, mon in ipairs(hl.get_monitors()) do names[#names + 1] = mon.name end
    end
    return names
end

-- Moves the workspaces that belong to `name` back onto it. Hyprland moves the
-- workspaces of a removed monitor onto the remaining ones; when the monitor
-- comes back we put its workspaces where they belong again, so the identity of
-- every workspace survives a reconnect.
local function restore_monitor(st, name)
    if not (hl and hl.get_workspace and hl.dispatch) then return end
    local m = st.monitors[name]
    if not m then return end
    for _, id in ipairs(m.workspaces) do
        local ws = hl.get_workspace(tostring(id))
        if ws and not ws.special and ws.monitor and ws.monitor.name ~= name then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = name }))
        end
    end
end

-- Brings the allocation and the compositor back in sync.
function M.reconcile()
    if not (hl and hl.get_monitors) then return end

    local st = state.load()

    -- A monitor we have never seen gets its own block of workspaces.
    for _, mon in ipairs(hl.get_monitors()) do
        if not st.monitors[mon.name] then
            state.ensure(st, mon.name, state.DEFAULT_PER_MONITOR)
            (hl.print or function() end)("[workspaces] new monitor " .. mon.name .. " with "
                .. table.concat(st.monitors[mon.name].workspaces, ","))
        end
    end

    -- Push the rules that are not in place yet.
    for _, name in ipairs(st.order) do
        local m = st.monitors[name]
        if m then
            for _, id in ipairs(m.workspaces) do
                local key = rule_key(name, id)
                local is_default = (id == m.default)
                if applied[key] ~= is_default then
                    state.apply_rule(id, name, is_default)
                    applied[key] = is_default
                end
            end
        end
    end

    state.write(st)
end

-- Re-applies every rule from scratch. Needed after a config reload, because
-- the rules that were added at runtime are gone then.
local function reapply_all()
    applied = {}
    M.reconcile()
end

if hl and hl.on then
    hl.on("hyprland.start", function() reapply_all() end)
    hl.on("config.reloaded", function() reapply_all() end)

    hl.on("monitor.added", function(mon)
        M.reconcile()
        local st = state.load()
        restore_monitor(st, mon.name)
    end)

    hl.on("monitor.removed", function(mon)
        -- The allocation of the monitor is kept, so it gets the same workspaces
        -- back when it is plugged in again. Hyprland itself moves its
        -- workspaces onto the remaining monitors in the meantime.
        M.reconcile()
    end)
end

-- First run: build the allocation and apply the rules.
M.reconcile()

return M
