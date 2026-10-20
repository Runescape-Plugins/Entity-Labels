local M = {}

local settings = require("core/settings")

local MAX_LABELS = 120
local CHARS_WIDE = 30

local ON_TOP = 1000000
local ON_BOTTOM = -1000000
local PLAYER_PRIORITY = ON_TOP * 2

local FALLBACK_HEIGHT = 512
local FINE_PER_TILE = 512
local FADE_BAND = FINE_PER_TILE * 2

local parent
local pool = {}
local shown = 0
local selected = {}

local function release()
    for _, text in ipairs(pool) do
        pcall(function()
            text:Destroy()
        end)
    end

    pool = {}
    parent = nil
    shown = 0
    selected = {}
end

local function gameView()
    if parent ~= nil then
        return parent
    end

    local ok, component = pcall(function()
        return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAMEVIEW_WINDOW_CONTENT)
            or ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    end)

    if not ok or component == nil then
        return nil
    end

    parent = component
    return parent
end

local function viewBounds()
    local ok, bounds = pcall(function()
        local origin = parent.xyGlobal

        return {
            x = origin.x,
            y = origin.y,
            width = parent.width,
            height = parent.height,
        }
    end)

    if not ok or bounds == nil or bounds.width == nil or bounds.width <= 0 then
        return nil
    end

    return bounds
end

local function labelAt(index)
    local existing = pool[index]

    if existing ~= nil then
        return existing
    end

    local ok, text = pcall(function()
        return ui.Text.new(parent)
    end)

    if not ok or text == nil then
        return nil
    end

    pcall(function()
        text.maxLines = 1
        text.isShadowed = true
        text.clickthrough = true
        text.alignHorizontal = ui.AlignMode.CENTRE
        text.alignVertical = ui.AlignMode.CENTRE
    end)

    pool[index] = text
    return text
end

local function hideFrom(index)
    for i = index, shown do
        local text = pool[i]

        if text ~= nil then
            pcall(function()
                text.hidden = true
            end)
        end
    end

    shown = math.max(0, index - 1)
end

local function headOf(entity, height)
    local ok, screen, base = pcall(function()
        local position = entity.position

        if height == nil then
            local box = entity.aabb
            height = box ~= nil and (box.maxY - position.y) or FALLBACK_HEIGHT
        end

        return ScreenConvert.Vector3ToScreen(position + Vector3.new(0, height, 0)), position
    end)

    if not ok then
        return nil
    end

    return screen, base
end

local function origin()
    local ok, position = pcall(function()
        if not Player.IsAvailable() then
            return nil
        end

        local entity = Player.GetEntity()
        return entity ~= nil and entity.position or nil
    end)

    if not ok then
        return nil
    end

    return position
end

local function fadeAt(from, base, edge)
    if from == nil or base == nil then
        return 1
    end

    local dx = base.x - from.x
    local dz = base.z - from.z
    local away = math.sqrt(dx * dx + dz * dz)

    if away >= edge then
        return 0
    end

    local into = (edge - away) / FADE_BAND

    if into >= 1 then
        return 1
    end

    return into
end

local function place(text, entry, screen, bounds, style, colour, alpha)
    local x = screen.x - bounds.x
    local y = screen.y - bounds.y

    if x < 0 or y < 0 or x > bounds.width or y > bounds.height then
        return false
    end

    local width = style.size * CHARS_WIDE
    local height = style.size * 2 + 6

    x = math.floor(x - width / 2 + 0.5)
    y = math.floor(y - height - style.offset + 0.5)

    local ok = pcall(function()
        if text.width ~= width or text.height ~= height then
            text:SetSize(width, height)
        end

        text.content = entry.name
        text.font = style.font
        text.rgb = colour
        text.alpha = alpha

        if x ~= text.x or y ~= text.y then
            text:SetPos(x, y)
        end

        text.hidden = false
    end)

    return ok
end

local function tileOf(entity)
    local ok, tile = pcall(function()
        local grid = entity.coordGrid

        return {
            x = grid.x,
            z = grid.z,
            level = grid.level,
        }
    end)

    if not ok then
        return nil
    end

    return tile
end

local UNKNOWN = { score = 0, interactive = true, hostile = false }

local function describe(npc)
    local ok, traits = pcall(function()
        local config = npc.config

        if config == nil then
            return nil
        end

        local offset = config.priorityOffset
        if type(offset) ~= "number" then
            offset = 0
        end

        local score = offset
        if config.isAlwaysOnTop then
            score = ON_TOP + offset
        elseif config.isAlwaysOnBottom then
            score = ON_BOTTOM + offset
        end

        local height = config.overlayHeight
        if type(height) ~= "number" or height < 0 then
            height = nil
        end

        local level = config.visibleCombatLevel
        if type(level) ~= "number" or level <= 0 then
            level = nil
        end

        local attack = config.attackOpIndex

        return {
            score = score,
            interactive = config.isExamineOnly ~= true and config.isActive ~= false,
            height = height,
            level = level,
            hostile = type(attack) == "number" and attack >= 0,
        }
    end)

    if not ok or traits == nil then
        return UNKNOWN
    end

    return traits
end

local function combatLevel()
    local ok, level = pcall(function()
        return Player.GetCombatLevel()
    end)

    if not ok or type(level) ~= "number" or level <= 0 then
        return nil
    end

    return level
end

local function gather(selfUID, ownLevel)
    local found = {}

    local okNpcs, npcs = pcall(function()
        return NPCList.All()
    end)

    if okNpcs and npcs ~= nil then
        local onlyInteractive = settings.interactiveOnly()
        local blocked = settings.blockedSet()

        for _, npc in ipairs(npcs) do
            local traits = describe(npc)

            if not onlyInteractive or traits.interactive then
                local known, name = pcall(function()
                    return npc.displayName
                end)

                local hidden = known and type(name) == "string" and blocked[name:lower()] == true

                if not hidden then
                    found[#found + 1] = {
                        entity = npc,
                        name = known and name or nil,
                        score = traits.score,
                        kind = "npc",
                        interactive = traits.interactive,
                        hostile = traits.hostile,
                        level = traits.level,
                        height = traits.height,
                    }
                end
            end
        end
    end

    local showOthers = settings.players()
    local showSelf = settings.showSelf()

    if not showOthers and not showSelf then
        return found
    end

    local okPlayers, players = pcall(function()
        return PlayerList.All()
    end)

    if okPlayers and players ~= nil then
        for _, player in ipairs(players) do
            local known, uid = pcall(function()
                return player.uid
            end)

            local isSelf = known and uid == selfUID
            local wanted = showOthers

            if isSelf then
                wanted = showSelf
            end

            if wanted then
                found[#found + 1] = {
                    entity = player,
                    score = PLAYER_PRIORITY,
                    kind = "player",
                    isSelf = isSelf,
                    level = isSelf and ownLevel or nil,
                }
            end
        end
    end

    return found
end

local function nearestPerTile(entries, from, ranges)
    local best = {}
    local order = {}
    local reach = {
        npc = ranges.npc * ranges.npc,
        player = ranges.player * ranges.player,
    }

    for _, entry in ipairs(entries) do
        local tile = tileOf(entry.entity)

        if tile ~= nil and tile.level == from.level then
            local dx = tile.x - from.x
            local dz = tile.z - from.z
            local away = dx * dx + dz * dz
            local key = tostring(tile.x) .. ":" .. tostring(tile.z)

            if away <= (reach[entry.kind] or 0) then
                local current = best[key]

                if current == nil then
                    best[key] = {
                        entity = entry.entity,
                        score = entry.score,
                        away = away,
                        kind = entry.kind,
                        name = entry.name,
                        interactive = entry.interactive,
                        hostile = entry.hostile,
                        isSelf = entry.isSelf,
                        level = entry.level,
                        height = entry.height,
                    }
                    order[#order + 1] = key
                elseif entry.score > current.score then
                    current.entity = entry.entity
                    current.score = entry.score
                    current.kind = entry.kind
                    current.name = entry.name
                    current.interactive = entry.interactive
                    current.hostile = entry.hostile
                    current.isSelf = entry.isSelf
                    current.level = entry.level
                    current.height = entry.height
                end
            end
        end
    end

    local winners = {}

    for _, key in ipairs(order) do
        winners[#winners + 1] = best[key]
    end

    table.sort(winners, function(a, b)
        return a.away < b.away
    end)

    return winners
end

local function nearby(ownLevel)
    if not Player.IsAvailable() then
        return nil
    end

    local entity = Player.GetEntity()
    if entity == nil then
        return nil
    end

    local here = tileOf(entity)
    if here == nil then
        return nil
    end

    local uid = -1
    local known, value = pcall(function()
        return entity.uid
    end)

    if known then
        uid = value
    end

    local ranges = {
        npc = settings.range("npc"),
        player = settings.range("player"),
    }

    return nearestPerTile(gather(uid, ownLevel), here, ranges)
end

local function withLevel(name, level, mode, ownLevel)
    if level == nil or mode == settings.LEVEL_NEVER then
        return name
    end

    if mode == settings.LEVEL_HIGHER and (ownLevel == nil or level <= ownLevel) then
        return name
    end

    return name .. " (level-" .. tostring(level) .. ")"
end

local function onServerLogic()
    if not settings.enabled() then
        selected = {}
        return
    end

    local ownLevel = combatLevel()
    local found = nearby(ownLevel)

    if found == nil then
        selected = {}
        return
    end

    local modes = {
        npc = settings.levelMode("npc"),
        player = settings.levelMode("player"),
    }

    local picked = {}

    for _, entry in ipairs(found) do
        if #picked >= MAX_LABELS then
            break
        end

        local name = entry.name

        if name == nil then
            local readable, found = pcall(function()
                return entry.entity.displayName
            end)

            name = readable and found or nil
        end

        if type(name) == "string" and name ~= "" then
            picked[#picked + 1] = {
                entity = entry.entity,
                name = withLevel(name, entry.level, modes[entry.kind], ownLevel),
                kind = entry.kind,
                interactive = entry.interactive,
                hostile = entry.hostile,
                isSelf = entry.isSelf,
                height = entry.height,
            }
        end
    end

    selected = picked
end

local function onDraw()
    if not settings.enabled() or #selected == 0 then
        hideFrom(1)
        return
    end

    if gameView() == nil then
        return
    end

    local bounds = viewBounds()

    if bounds == nil then
        hideFrom(1)
        return
    end

    local styles = {
        npc = settings.style("npc"),
        player = settings.style("player"),
    }

    local interactiveColour = settings.interactiveColour()
    local selfColour = settings.selfColour()
    local hostileColour = settings.hostile() and settings.hostileColour() or nil

    local from = settings.fade() and origin() or nil
    local edges = from ~= nil and {
        npc = settings.range("npc") * FINE_PER_TILE,
        player = settings.range("player") * FINE_PER_TILE,
    } or nil

    local index = 0

    for _, entry in ipairs(selected) do
        local alive, valid = pcall(function()
            return entry.entity.isValid
        end)

        if alive and valid == true then
            local position, base = headOf(entry.entity, entry.height)

            if position ~= nil then
                local text = labelAt(index + 1)

                local style = styles[entry.kind]
                local colour = style.colour

                if hostileColour ~= nil and entry.hostile then
                    colour = hostileColour
                elseif entry.interactive then
                    colour = interactiveColour
                elseif entry.isSelf then
                    colour = selfColour
                end

                local alpha = 1

                if edges ~= nil then
                    alpha = fadeAt(from, base, edges[entry.kind] or 0)
                end

                if text ~= nil and place(text, entry, position, bounds, style, colour, alpha) then
                    index = index + 1
                end
            end
        end
    end

    hideFrom(index + 1)
    shown = index
end

local function onGameState(event)
    if event.newState ~= GameState.GAME then
        release()
    end
end

function M.init()
    Event.Draw.Subscribe("entityLabels:draw", onDraw)
    Event.ServerLogic.Subscribe("entityLabels:select", onServerLogic)
    Event.GameStateChanged.Subscribe("entityLabels:state", onGameState)
end

function M.shutdown()
    release()
end

function M.close()
    Event.Draw.Unsubscribe("entityLabels:draw")
    Event.ServerLogic.Unsubscribe("entityLabels:select")
    Event.GameStateChanged.Unsubscribe("entityLabels:state")
    M.shutdown()
end

return M
