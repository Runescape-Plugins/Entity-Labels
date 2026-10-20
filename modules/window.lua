local fonts = require("core/fonts")
local settings = require("core/settings")

local M = {}

local LAYER_ID = "entityLabels:layer"
local SETTINGS_ID = "entityLabels:settings"
local LOGIC_ID = "entityLabels:panel"

local PADDING = 8
local FIELD_WIDTH = -(PADDING * 2)
local FIELD_ANCHOR = 1
local STYLE_CONTENT_HEIGHT = 430
local NPC_CONTENT_HEIGHT = 300
local SWATCH = 24
local NUMBER_WIDTH = 56
local NUMBER_HEIGHT = 24
local BOX_SIZE = 14
local ROW_HEIGHT = 22
local COMBO_WIDTH = 150
local COMBO_HEIGHT = 30
local DIVIDER_HEIGHT = 6

local SWITCH_HEIGHT = 24
local SWITCH_GAP = 4
local SWITCH_TOP = 10
local FALLBACK_PANEL_WIDTH = 300

local views = {}
local chips = {}
local hosts = {}
local pending = {}
local showing = {}

local render

local function teardown(key)
    local view = views[key]
    views[key] = nil

    if view ~= nil and view.root ~= nil then
        pcall(function()
            view:Destroy()
        end)
    end

    local row = chips[key]
    chips[key] = nil

    if row == nil then
        return
    end

    for _, button in ipairs(row) do
        pcall(function()
            button:Destroy()
        end)
    end
end

local function check(page, label, tip, read, write, colour)
    local width = FIELD_WIDTH

    if colour ~= nil then
        width = -(PADDING * 2 + SWATCH + 6)
    end

    local control = page:AddCheckboxButton({
        {
            text = label,
            value = label,
            selected = read(),
            tooltip = tip,
        },
    }, {
        marginTop = 4,
        x = PADDING,
        width = width,
        widthAnchor = FIELD_ANCHOR,
        onChange = function(_control, _values, _value, selected)
            write(selected)
        end,
    })

    pcall(function()
        for _, item in ipairs(control.items) do
            item.label:SetPos(0, 0)
            item.label:SetSize(-(BOX_SIZE + 6), ROW_HEIGHT, 1.0)
            item.box:SetPos(-BOX_SIZE, math.floor((ROW_HEIGHT - BOX_SIZE) / 2), 1.0)
        end
    end)

    if colour == nil then
        return
    end

    page:AddColourPicker({
        value = colour.read(),
        inline = true,
        x = -(SWATCH + PADDING),
        xAnchor = 1,
        buttonSize = SWATCH,
        windowTitle = colour.title,
        onChange = function(_picker, picked)
            colour.write(picked)
        end,
    })
end

local function dropdown(page, label, entries, selectedID, pick)
    page:AddText({
        text = label,
        height = COMBO_HEIGHT,
        maxLines = 1,
        x = PADDING,
        width = -(PADDING * 2 + COMBO_WIDTH + 6),
        widthAnchor = FIELD_ANCHOR,
    })

    page:AddComboBox({
        entries = entries,
        selectedID = selectedID,
        inline = true,
        x = -(COMBO_WIDTH + PADDING),
        xAnchor = 1,
        width = COMBO_WIDTH,
        height = COMBO_HEIGHT,
        onChange = function(_box, entryID)
            pick(entryID)
        end,
    })
end

local function levelPicker(page, label, kind)
    local entries = {}

    for _, mode in ipairs(settings.LEVEL_MODES) do
        entries[#entries + 1] = { id = mode.id, label = mode.label }
    end

    dropdown(page, label, entries, settings.levelMode(kind), function(entryID)
        settings.setLevelMode(kind, entryID)
    end)
end

local function divider(page)
    local line = page:AddSprite(id.Sprite.RS3_PARENT_FRAME_TOP_TILE, {
        marginTop = 6,
        marginBottom = 0,
        x = PADDING,
        width = FIELD_WIDTH,
        widthAnchor = FIELD_ANCHOR,
        height = DIVIDER_HEIGHT,
    })

    pcall(function()
        line.root.spriteID = id.Sprite.RS3_PARENT_FRAME_TOP_TILE
        line.root.isTiling = true
    end)
end

local function heading(page, title, marginTop)
    page:AddTitle({
        text = title,
        maxLines = 1,
        marginTop = marginTop,
        marginBottom = 2,
        alignHorizontal = ui.AlignMode.CENTRE,
    })
end

local function numberField(page, label, value, min, max, write)
    local field

    page:AddText({
        text = label,
        height = NUMBER_HEIGHT,
        maxLines = 1,
        marginTop = 8,
        x = PADDING,
        width = -(PADDING * 2 + NUMBER_WIDTH + 6),
        widthAnchor = FIELD_ANCHOR,
    })

    field = page:AddTextField({
        text = tostring(value),
        filterMode = min < 0 and ui.InputFieldFilterMode.NONE or ui.InputFieldFilterMode.NUMERIC,
        maxLength = math.max(#tostring(min), #tostring(max)),
        inline = true,
        x = -(NUMBER_WIDTH + PADDING),
        xAnchor = 1,
        width = NUMBER_WIDTH,
        height = NUMBER_HEIGHT,
        onChange = function(_field, _reason, content)
            local entered = tonumber(content)

            if entered ~= nil and entered >= min and entered <= max then
                write(math.floor(entered))
            end
        end,
        onSubmit = function(field, content)
            local clamped = math.max(min, math.min(max, math.floor(tonumber(content) or min)))
            write(clamped)

            pcall(function()
                field:SetText(tostring(clamped))
            end)
        end,
    })

    pcall(function()
        field.root.text.alignVertical = ui.AlignMode.CENTRE
        field.root.text.alignHorizontal = ui.AlignMode.CENTRE
    end)
end

local function resetButton(page, key, tab, reset)
    local button = page:AddFancyButton("Reset to defaults", function()
        reset()
        pending[key] = tab
    end, {
        variant = "negative",
        marginTop = 10,
        x = PADDING,
    })

    pcall(function()
        button.root:SetSize(FIELD_WIDTH, button.root.height, FIELD_ANCHOR)
    end)
end

local function buildPlayers(page, key)
    levelPicker(page, "Combat Level", "player")

    check(page, "Show other player names", "Labels players other than yourself.",
        settings.players, settings.setPlayers, {
            title = "Other player colour",
            read = function()
                return settings.pickerColour("player")
            end,
            write = function(value)
                settings.setColour("player", value)
            end,
        })

    check(page, "Show my own name", "Labels your own character. Independent of the setting above.",
        settings.showSelf, settings.setShowSelf, {
            title = "Your own colour",
            read = settings.selfPickerColour,
            write = settings.setSelfColour,
        })

    numberField(page, "Range (tiles)", settings.range("player"),
        settings.MIN_RANGE, settings.MAX_RANGE, function(value)
            settings.setRange("player", value)
        end)

    resetButton(page, key, 1, settings.resetPlayers)
end

local function buildNpcs(page, key)
    levelPicker(page, "Combat Level", "npc")

    check(page, "Show NPC names", "Labels nearby NPCs.", settings.enabled, settings.setEnabled, {
        title = "NPC colour",
        read = function()
            return settings.pickerColour("npc")
        end,
        write = function(value)
            settings.setColour("npc", value)
        end,
    })

    check(page, "Interactive NPCs only",
        "Hides scenery NPCs that only offer Examine.",
        settings.interactiveOnly, settings.setInteractiveOnly, {
            title = "Interactive NPC colour",
            read = settings.interactivePickerColour,
            write = settings.setInteractiveColour,
        })

    check(page, "Colour attackable NPCs",
        "Gives NPCs with an Attack option their own colour.",
        settings.hostile, settings.setHostile, {
            title = "Attackable NPC colour",
            read = settings.hostilePickerColour,
            write = settings.setHostileColour,
        })

    numberField(page, "Range (tiles)", settings.range("npc"),
        settings.MIN_RANGE, settings.MAX_RANGE, function(value)
            settings.setRange("npc", value)
        end)

    page:AddText({
        text = "Hidden names, comma separated",
        height = NUMBER_HEIGHT,
        maxLines = 1,
        marginTop = 8,
        x = PADDING,
        width = FIELD_WIDTH,
        widthAnchor = FIELD_ANCHOR,
    })

    page:AddTextField({
        text = settings.blocked(),
        placeholder = "Shift + right-click an NPC to add it",
        marginTop = 2,
        x = PADDING,
        width = FIELD_WIDTH,
        widthAnchor = FIELD_ANCHOR,
        height = NUMBER_HEIGHT,
        onChange = function(_field, _reason, content)
            settings.setBlocked(content)
        end,
    })

    resetButton(page, key, 2, settings.resetNpcs)
end

local function buildStyleFor(page, kind, title, headingTop)
    heading(page, title, headingTop)

    local families = {}

    for index, family in ipairs(fonts.families) do
        families[#families + 1] = { id = index, label = family.label }
    end

    dropdown(page, "Font", families, fonts.indexOf(settings.family(kind)), function(entryID)
        settings.setFamily(kind, fonts.keyAt(entryID))
    end)

    local sizes = {}

    for size = settings.MIN_SIZE, settings.MAX_SIZE do
        sizes[#sizes + 1] = { id = size, label = tostring(size) }
    end

    dropdown(page, "Size", sizes, settings.size(kind), function(size)
        settings.setSize(kind, size)
    end)

    numberField(page, "Height above head", settings.offset(kind),
        settings.MIN_OFFSET, settings.MAX_OFFSET, function(value)
            settings.setOffset(kind, value)
        end)
end

local function buildStyle(page, key)
    heading(page, "Global", 4)

    local fades = {}

    for _, mode in ipairs(settings.FADE_MODES) do
        fades[#fades + 1] = { id = mode.id, label = mode.label }
    end

    dropdown(page, "Fade in and out", fades, settings.fadeMode(), settings.setFadeMode)

    divider(page)
    buildStyleFor(page, "npc", "NPCs", -6)
    divider(page)
    buildStyleFor(page, "player", "Players", -6)

    resetButton(page, key, 3, settings.resetStyle)
end

local SECTIONS = {
    { label = "Player", build = buildPlayers },
    { label = "NPCs", build = buildNpcs, scrollable = true, contentHeight = NPC_CONTENT_HEIGHT },
    { label = "Style", build = buildStyle, scrollable = true, contentHeight = STYLE_CONTENT_HEIGHT },
}

local function switcher(component, key, active)
    local total = component.width

    if type(total) ~= "number" or total <= 0 then
        total = FALLBACK_PANEL_WIDTH
    end

    local usable = total - PADDING * 2 - SWITCH_GAP * (#SECTIONS - 1)
    local span = math.max(32, math.floor(usable / #SECTIONS))
    local row = {}

    for index, section in ipairs(SECTIONS) do
        local ok, button = pcall(function()
            return prettyui.SimpleButton.new(component, section.label, function()
                pending[key] = index
            end, {
                x = PADDING + (index - 1) * (span + SWITCH_GAP),
                y = SWITCH_TOP,
                width = span,
                height = SWITCH_HEIGHT,
                active = index == active,
            })
        end)

        if ok and button ~= nil then
            row[#row + 1] = button
        end
    end

    chips[key] = row
end

local function build(panel, key, activeTab)
    local section = SECTIONS[activeTab] or SECTIONS[1]
    section.build(panel, key)
end

render = function(key, component, activeTab)
    if component == nil then
        return
    end

    teardown(key)
    hosts[key] = component

    local index = SECTIONS[activeTab] ~= nil and activeTab or 1
    local section = SECTIONS[index]
    local top = SWITCH_TOP + SWITCH_HEIGHT + SWITCH_GAP

    showing[key] = index

    pcall(switcher, component, key, index)

    local ok, view = pcall(function()
        return prettyui.SimpleView.new(component, {
            y = top,
            width = 0,
            height = -top,
            widthAnchor = 1,
            heightAnchor = 1,
            scrollable = section.scrollable == true,
            contentHeight = section.contentHeight,
            layout = {
                startY = 4,
                paddingLeft = PADDING,
                paddingRight = PADDING,
                paddingBottom = PADDING,
                rowGap = 4,
            },
        })
    end)

    if not ok or view == nil then
        print("[Entity Labels] SimpleView failed: " .. tostring(view))
        return
    end

    views[key] = view

    local built, err = pcall(build, view, key, index)

    if not built then
        print("[Entity Labels] panel build failed: " .. tostring(err))
        teardown(key)
    end
end

function M.refresh()
    for key in pairs(hosts) do
        pending[key] = showing[key] or 1
    end
end

local function onLogic()
    if next(pending) == nil then
        return
    end

    local due = pending
    pending = {}

    for key, tab in pairs(due) do
        render(key, hosts[key], tab)
    end
end

local function onContentLayer(event)
    render("content", event.component, 1)
end

local function onSettingsLayer(event)
    render("settings", event.component, 1)
end

function M.init()
    Event.ContentLayerReady.Subscribe(LAYER_ID, onContentLayer)
    Event.SettingsLayerReady.Subscribe(SETTINGS_ID, onSettingsLayer)
    Event.Logic.Subscribe(LOGIC_ID, onLogic)
end

function M.shutdown()
    pending = {}
    teardown("content")
    teardown("settings")
end

function M.close()
    Event.ContentLayerReady.Unsubscribe(LAYER_ID)
    Event.SettingsLayerReady.Unsubscribe(SETTINGS_ID)
    Event.Logic.Unsubscribe(LOGIC_ID)
    M.shutdown()
end

return M
