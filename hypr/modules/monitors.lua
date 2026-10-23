------------------
---- MONITORS ----
------------------

-- nwg-displays saves your layout to ~/.config/hypr/monitors.lua. Use it when it exists,
-- otherwise fall back to "everything automatic at automatic scale".
local ok = pcall(require, "monitors")
if not ok then
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = "auto",
    })
end

-- Overrides saved by the Quickshell monitor settings (separate from the nwg-displays files).
pcall(require, "monitors_custom")
