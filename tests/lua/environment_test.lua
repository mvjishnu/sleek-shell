-- modules/environment_variables.lua: NVIDIA variables only on NVIDIA-only systems; ~/.local/bin on PATH.
package.path = "./?.lua;" .. package.path
local function fail(msg) io.stderr:write("FAIL: " .. msg .. "\n"); os.exit(1) end

local home = os.getenv("HOME")
local function sysroot(name, vendors, nvidia_loaded)
    local root = home .. "/" .. name
    for i, v in ipairs(vendors) do
        local d = root .. "/sys/class/drm/card" .. i .. "/device"
        os.execute('mkdir -p "' .. d .. '"')
        local f = io.open(d .. "/vendor", "w"); f:write(v .. "\n"); f:close()
    end
    if nvidia_loaded then
        os.execute('mkdir -p "' .. root .. '/proc/driver/nvidia"')
        local f = io.open(root .. "/proc/driver/nvidia/version", "w"); f:write("NVRM\n"); f:close()
    end
    return root
end

local real_getenv = os.getenv
local function load(root, extra)
    local env = {}
    hl = { env = function(k, v) env[k] = v end }
    os.getenv = function(k)
        if k == "SLEEK_SYS_ROOT" then return root end
        if extra and extra[k] ~= nil then return extra[k] end
        return real_getenv(k)
    end
    package.loaded["modules.environment_variables"] = nil
    require("modules.environment_variables")
    os.getenv = real_getenv
    return env
end

local e = load(sysroot("hybrid", { "0x10de", "0x1002" }, true), { PATH = "/usr/bin" })
if e.LIBVA_DRIVER_NAME then fail("hybrid NVIDIA + AMD must not set LIBVA_DRIVER_NAME") end
if e.__GLX_VENDOR_LIBRARY_NAME then fail("hybrid must not set __GLX_VENDOR_LIBRARY_NAME") end
if e.PATH ~= home .. "/.local/bin:/usr/bin" then fail("PATH should start with ~/.local/bin, got " .. tostring(e.PATH)) end

e = load(sysroot("nvonly", { "0x10de" }, true))
if e.LIBVA_DRIVER_NAME ~= "nvidia" then fail("NVIDIA-only with the driver loaded should set LIBVA_DRIVER_NAME") end

e = load(sysroot("nvonly-nouveau", { "0x10de" }, false))
if e.LIBVA_DRIVER_NAME then fail("without the proprietary driver loaded nothing NVIDIA-specific is set") end

e = load(home .. "/hybrid", { SLEEK_NVIDIA_ENV = "1" })
if e.LIBVA_DRIVER_NAME ~= "nvidia" then fail("SLEEK_NVIDIA_ENV=1 forces the NVIDIA variables") end

e = load(home .. "/nvonly", { PATH = home .. "/.local/bin:/usr/bin" })
if e.PATH then fail("PATH already containing ~/.local/bin must not be changed") end
if e.XDG_MENU_PREFIX then fail("XDG_MENU_PREFIX must not be set without arch-applications.menu") end

local menu = home .. "/withmenu"
os.execute('mkdir -p "' .. menu .. '/etc/xdg/menus"')
local mf = io.open(menu .. "/etc/xdg/menus/arch-applications.menu", "w"); mf:write("<Menu/>\n"); mf:close()
e = load(menu, { XDG_MENU_PREFIX = false })
if e.XDG_MENU_PREFIX ~= "arch-" then fail("arch-applications.menu present: XDG_MENU_PREFIX should be arch-, got " .. tostring(e.XDG_MENU_PREFIX)) end
e = load(menu, { XDG_MENU_PREFIX = "plasma-" })
if e.XDG_MENU_PREFIX then fail("an XDG_MENU_PREFIX the user already has must be kept") end
print("ok")
