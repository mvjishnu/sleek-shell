--[[
Sleek Shell keybind layer.

Wraps hl.bind for the config files loaded after it (modules/keybinds.lua,
modules/shell_keys.lua, ...) so that every existing bind can be

  * disabled,
  * moved to another key combination,
  * labelled (the label shows up as the bind description in `hyprctl binds`),

from the Sleek Shell keybinding settings, WITHOUT editing those files. The user's choices live in
~/.config/sleek-shell/keybinds.json; the settings generate ~/.config/sleek-shell/hypr-binds.lua from it.
User-created binds are generated into ~/.config/hypr/custom_binds.lua and call M.orig directly,
so the overrides here never touch them.

If the overrides file is missing or broken, every bind is created exactly as written.
]]

local M = {}

local HOME = os.getenv("HOME") or ""
M.overrides_path = HOME .. "/.config/sleek-shell/hypr-binds.lua"

local MODS = {
    SUPER = "SUPER", MOD4 = "SUPER", WIN = "SUPER", META = "SUPER", LOGO = "SUPER",
    SHIFT = "SHIFT", CTRL = "CTRL", CONTROL = "CTRL", ALT = "ALT", MOD1 = "ALT",
}

-- "SUPER + SHIFT + W" -> "SHIFT+SUPER|w". Must match norm() in hypr/scripts/hypr-tools.py.
function M.norm(keys)
    local toks = {}
    for raw in tostring(keys):gmatch("[^+]+") do
        local t = raw:match("^%s*(.-)%s*$")
        if t ~= "" then toks[#toks + 1] = t end
    end
    local set, key = {}, ""
    for i, t in ipairs(toks) do
        local u = t:upper()
        if i < #toks and MODS[u] then set[MODS[u]] = true else key = t:lower() end
    end
    local mods = {}
    for m in pairs(set) do mods[#mods + 1] = m end
    table.sort(mods)
    return table.concat(mods, "+") .. "|" .. key
end

local ov = { disabled = {}, remap = {}, labels = {} }
do
    local ok, t = pcall(dofile, M.overrides_path)
    if ok and type(t) == "table" then
        if type(t.disabled) == "table" then
            for _, n in ipairs(t.disabled) do if type(n) == "string" then ov.disabled[n] = true end end
        end
        if type(t.remap) == "table" then
            for n, k in pairs(t.remap) do
                if type(n) == "string" and type(k) == "string" and k:match("^[%w%s%+_:%-%.]+$") then ov.remap[n] = k end
            end
        end
        if type(t.labels) == "table" then
            for n, l in pairs(t.labels) do if type(n) == "string" and type(l) == "string" then ov.labels[n] = l end end
        end
    end
end

local labels = {}
do
    local ok, t = pcall(require, "sleekshell.bind_labels")
    if ok and type(t) == "table" then labels = t end
end

local stub = {}
function stub.set_enabled() end
function stub.is_enabled() return false end
function stub.remove() end
function stub.unbind() end

M.orig = hl.bind
M.disabled = ov.disabled
M.remap = ov.remap

hl.bind = function(keys, dispatcher, opts)
    if type(keys) ~= "string" then return M.orig(keys, dispatcher, opts) end
    local n = M.norm(keys)
    if ov.disabled[n] then return setmetatable({}, { __index = stub }) end
    local label = ov.labels[n] or labels[n]
    if label then
        opts = opts or {}
        if opts.description == nil and opts.desc == nil then opts.description = label end
    end
    return M.orig(ov.remap[n] or keys, dispatcher, opts)
end

return M
