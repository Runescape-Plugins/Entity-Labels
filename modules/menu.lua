local settings = require("core/settings")
local window = require("modules/window")

local M = {}

local MENU_ID = "entityLabels:menu"
local TAG = "<col=F2C66D>[Entity Labels]</col>"

local function shiftDown()
    local ok, down = pcall(function()
        return Keyboard.IsAvailable() and Keyboard.IsShiftDown()
    end)

    return ok and down == true
end

local function npcName(entry)
    local ok, name = pcall(function()
        if entry.actionEntryType ~= MiniMenuEntryType.NPC then
            return nil
        end

        local data = entry.npcData

        if data == nil or data.entity == nil then
            return nil
        end

        return data.entity.displayName
    end)

    if not ok or type(name) ~= "string" or name == "" then
        return nil
    end

    return name
end

local function onReady(event)
    if not shiftDown() then
        return
    end

    local menu = event.miniMenu

    if menu == nil then
        return
    end

    local seen = {}
    local blocked = settings.blockedSet()

    pcall(function()
        for _, entry in ipairs(menu.entries) do
            local name = npcName(entry)

            if name ~= nil and not seen[name] then
                seen[name] = true

                if blocked[name:lower()] then
                    menu:Add(TAG .. " Show Label", function()
                        settings.unblock(name)
                        window.refresh()
                    end)
                else
                    menu:Add(TAG .. " Hide Label", function()
                        settings.block(name)
                        window.refresh()
                    end)
                end
            end
        end
    end)
end

function M.init()
    Event.MiniMenuReady.Subscribe(MENU_ID, onReady)
end

function M.close()
    Event.MiniMenuReady.Unsubscribe(MENU_ID)
end

return M
