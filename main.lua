local labels = require("modules/labels")
local window = require("modules/window")
local menu = require("modules/menu")

local MODULES = { labels, window, menu }

local function guard(fn)
    if fn ~= nil then
        pcall(fn)
    end
end

PluginShutdown = function()
    for i = #MODULES, 1, -1 do
        local module = MODULES[i]
        guard(module.close or module.shutdown)
    end
end

for _, module in ipairs(MODULES) do
    guard(module.init)
end
