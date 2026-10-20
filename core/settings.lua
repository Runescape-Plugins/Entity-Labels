local M = {}

local fonts = require("core/fonts")

local DEFAULT_RANGE = 30
local MIN_RANGE = 1
local MAX_RANGE = 40

local MIN_OFFSET = -40
local MAX_OFFSET = 60

local DEFAULT_INTERACTIVE_COLOUR = 0x66FF66
local DEFAULT_SELF_COLOUR = 0xFFFFFF
local DEFAULT_HOSTILE_COLOUR = 0xFF5555

local LEVEL_NEVER = 1
local LEVEL_HIGHER = 2
local LEVEL_ALWAYS = 3

M.LEVEL_NEVER = LEVEL_NEVER
M.LEVEL_HIGHER = LEVEL_HIGHER
M.LEVEL_ALWAYS = LEVEL_ALWAYS

M.LEVEL_MODES = {
    { id = LEVEL_NEVER, label = "Never" },
    { id = LEVEL_HIGHER, label = "Above my level" },
    { id = LEVEL_ALWAYS, label = "Always" },
}

local FADE_OFF = 1
local FADE_ON = 2

M.FADE_MODES = {
    { id = FADE_OFF, label = "Off" },
    { id = FADE_ON, label = "On" },
}

local DEFAULTS = {
    npc = { family = "bold", size = 12, offset = 6, colour = 0xFFFF00 },
    player = { family = "bold", size = 12, offset = 6, colour = 0x00E5FF },
}

M.MIN_RANGE = MIN_RANGE
M.MAX_RANGE = MAX_RANGE
M.MIN_OFFSET = MIN_OFFSET
M.MAX_OFFSET = MAX_OFFSET
M.MIN_SIZE = fonts.MIN_SIZE
M.MAX_SIZE = fonts.MAX_SIZE

local function bool(key, fallback)
    local stored = PersistentDB:GetBool(key)

    if stored == nil then
        return fallback
    end

    return stored
end

function M.enabled()
    return bool("labels.enabled", true)
end

function M.setEnabled(value)
    PersistentDB:SetBool("labels.enabled", value)
end

function M.players()
    return bool("labels.players", true)
end

function M.setPlayers(value)
    PersistentDB:SetBool("labels.players", value)
end

function M.showSelf()
    return bool("labels.self", true)
end

function M.setShowSelf(value)
    PersistentDB:SetBool("labels.self", value)
end

function M.fadeMode()
    local stored = PersistentDB:GetInt("labels.fade.mode")

    if stored ~= FADE_OFF and stored ~= FADE_ON then
        return FADE_ON
    end

    return stored
end

function M.setFadeMode(value)
    if value ~= FADE_OFF and value ~= FADE_ON then
        return
    end

    PersistentDB:SetInt("labels.fade.mode", value)
end

function M.fade()
    return M.fadeMode() == FADE_ON
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.blocked()
    local stored = PersistentDB:GetString("labels.blocked")

    if type(stored) ~= "string" then
        return ""
    end

    return stored
end

function M.setBlocked(value)
    PersistentDB:SetString("labels.blocked", type(value) == "string" and value or "")
end

function M.blockedSet()
    local set = {}

    for piece in M.blocked():gmatch("[^,]+") do
        local name = trim(piece):lower()

        if name ~= "" then
            set[name] = true
        end
    end

    return set
end

function M.block(name)
    if type(name) ~= "string" or name == "" then
        return
    end

    if M.blockedSet()[name:lower()] then
        return
    end

    local current = trim(M.blocked())

    if current == "" then
        M.setBlocked(name)
    else
        M.setBlocked(current .. ", " .. name)
    end
end

function M.unblock(name)
    if type(name) ~= "string" or name == "" then
        return
    end

    local target = name:lower()
    local kept = {}

    for piece in M.blocked():gmatch("[^,]+") do
        local entry = trim(piece)

        if entry ~= "" and entry:lower() ~= target then
            kept[#kept + 1] = entry
        end
    end

    M.setBlocked(table.concat(kept, ", "))
end

function M.hostile()
    return bool("labels.npc.hostile", true)
end

function M.setHostile(value)
    PersistentDB:SetBool("labels.npc.hostile", value)
end

function M.hostileColour()
    local stored = PersistentDB:GetInt("labels.npc.hostileColour")

    if type(stored) ~= "number" or stored < 0 then
        return DEFAULT_HOSTILE_COLOUR
    end

    return stored
end

function M.setHostileColour(value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt("labels.npc.hostileColour", math.floor(value / 0x100) % 0x1000000)
end

function M.hostilePickerColour()
    return M.hostileColour() * 0x100 + 0xFF
end

function M.levelMode(kind)
    local stored = PersistentDB:GetInt("labels." .. kind .. ".level")

    if stored ~= LEVEL_NEVER and stored ~= LEVEL_HIGHER and stored ~= LEVEL_ALWAYS then
        return LEVEL_ALWAYS
    end

    return stored
end

function M.setLevelMode(kind, value)
    if value ~= LEVEL_NEVER and value ~= LEVEL_HIGHER and value ~= LEVEL_ALWAYS then
        return
    end

    PersistentDB:SetInt("labels." .. kind .. ".level", value)
end

function M.interactiveOnly()
    return bool("labels.interactive", true)
end

function M.setInteractiveOnly(value)
    PersistentDB:SetBool("labels.interactive", value)
end

function M.range(kind)
    local stored = PersistentDB:GetInt("labels." .. kind .. ".range")

    if type(stored) ~= "number" or stored < MIN_RANGE then
        return DEFAULT_RANGE
    end

    return math.min(stored, MAX_RANGE)
end

function M.setRange(kind, value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt("labels." .. kind .. ".range",
        math.max(MIN_RANGE, math.min(MAX_RANGE, math.floor(value))))
end

local function styleKey(kind, field)
    return "labels." .. kind .. "." .. field
end

function M.family(kind)
    local stored = PersistentDB:GetString(styleKey(kind, "family"))

    if type(stored) ~= "string" or stored == "" then
        return DEFAULTS[kind].family
    end

    return stored
end

function M.setFamily(kind, value)
    PersistentDB:SetString(styleKey(kind, "family"), value)
end

function M.size(kind)
    local stored = PersistentDB:GetInt(styleKey(kind, "size"))

    if type(stored) ~= "number" or stored < fonts.MIN_SIZE then
        return DEFAULTS[kind].size
    end

    return math.min(stored, fonts.MAX_SIZE)
end

function M.setSize(kind, value)
    if type(value) ~= "number" then
        return
    end

    local clamped = math.max(fonts.MIN_SIZE, math.min(fonts.MAX_SIZE, math.floor(value)))
    PersistentDB:SetInt(styleKey(kind, "size"), clamped)
end

function M.offset(kind)
    local stored = PersistentDB:GetInt(styleKey(kind, "offset"))

    if type(stored) ~= "number" then
        return DEFAULTS[kind].offset
    end

    return math.max(MIN_OFFSET, math.min(MAX_OFFSET, stored))
end

function M.setOffset(kind, value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt(styleKey(kind, "offset"), math.max(MIN_OFFSET, math.min(MAX_OFFSET, math.floor(value))))
end

function M.colour(kind)
    local stored = PersistentDB:GetInt(styleKey(kind, "colour"))

    if type(stored) ~= "number" or stored < 0 then
        return DEFAULTS[kind].colour
    end

    return stored
end

function M.setColour(kind, value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt(styleKey(kind, "colour"), math.floor(value / 0x100) % 0x1000000)
end

function M.pickerColour(kind)
    return M.colour(kind) * 0x100 + 0xFF
end

function M.interactiveColour()
    local stored = PersistentDB:GetInt("labels.npc.interactiveColour")

    if type(stored) ~= "number" or stored < 0 then
        return DEFAULT_INTERACTIVE_COLOUR
    end

    return stored
end

function M.setInteractiveColour(value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt("labels.npc.interactiveColour", math.floor(value / 0x100) % 0x1000000)
end

function M.interactivePickerColour()
    return M.interactiveColour() * 0x100 + 0xFF
end

function M.selfColour()
    local stored = PersistentDB:GetInt("labels.player.selfColour")

    if type(stored) ~= "number" or stored < 0 then
        return DEFAULT_SELF_COLOUR
    end

    return stored
end

function M.setSelfColour(value)
    if type(value) ~= "number" then
        return
    end

    PersistentDB:SetInt("labels.player.selfColour", math.floor(value / 0x100) % 0x1000000)
end

function M.selfPickerColour()
    return M.selfColour() * 0x100 + 0xFF
end

local function forget(key)
    pcall(function()
        PersistentDB:Delete(key)
    end)
end

function M.resetPlayers()
    forget("labels.players")
    forget("labels.self")
    forget(styleKey("player", "colour"))
    forget("labels.player.selfColour")
    forget("labels.player.level")
    forget("labels.player.range")
end

function M.resetNpcs()
    forget("labels.enabled")
    forget("labels.interactive")
    forget("labels.npc.range")
    forget(styleKey("npc", "colour"))
    forget("labels.npc.interactiveColour")
    forget("labels.npc.hostile")
    forget("labels.npc.hostileColour")
    forget("labels.npc.level")
    forget("labels.blocked")
end

function M.resetStyle()
    for _, kind in ipairs({ "npc", "player" }) do
        forget(styleKey(kind, "family"))
        forget(styleKey(kind, "size"))
        forget(styleKey(kind, "offset"))
    end

    forget("labels.fade.mode")
end

function M.style(kind)
    return {
        font = fonts.resolve(M.family(kind), M.size(kind)),
        size = M.size(kind),
        offset = M.offset(kind),
        colour = M.colour(kind),
    }
end

return M
