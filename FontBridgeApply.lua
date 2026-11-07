local _, ns = ...
local L = ns.L

ns.Areas = {
    { key = "ui", section = L["General"], label = L["General UI"], note = L["Applies to default menus, buttons, and messages."] },
    { key = "chat", section = L["Chat and information"], label = L["Chat"], note = L["Default chat windows and speech bubbles."] },
    { key = "tooltips", section = L["Chat and information"], label = L["Tooltips"], note = L["Default tooltip titles and body text."] },
    { key = "quests", section = L["Chat and information"], label = L["Quests"], note = L["Quest text, titles, and the objective tracker."] },
    { key = "unitframes", section = L["Characters and combat"], label = L["Default unit frames"], note = L["Default player, target, focus, and party frames. Configure SUF fonts in SUF."] },
    { key = "names", section = L["Characters and combat"], locked = { scale = true, outline = true, shadow = true }, label = L["Character names"], note = L["Default nameplates and overhead names. Size, outline, and shadow cannot be changed. Overhead names may require logging in again."] },
    { key = "combat", section = L["Characters and combat"], locked = { outline = true, shadow = true }, label = L["Combat text"], note = L["Size uses the combat text scale. Outline and shadow are unsupported. Font changes may require logging in again."] },
    { key = "actionbars", section = L["General"], label = L["Action bars"], note = L["Default keybinding labels and item counts."] },
    { key = "zone", section = L["World and alerts"], label = L["Zone text"], note = L["Zone names shown when entering an area."] },
    { key = "errors", section = L["World and alerts"], label = L["Error messages"], note = L["Default error messages shown in the center of the screen."] },
}

local cvarName = "worldTextScale"
local function ReadCombatScale()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not get or not set then return end
    local ok, value = pcall(get, cvarName)
    value = ok and tonumber(value)
    if value and value > 0 then return value end
end
if not ReadCombatScale() then
    for _, area in ipairs(ns.Areas) do
        if area.key == "combat" then
            area.locked.scale = true
            area.note = L["This client does not support combat text size, outline, or shadow settings. Font changes may require logging in again."]
        end
    end
end

local TARGETS = {
    ui = { "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
        "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightLarge", "GameFontDisable",
        "GameFontDisableSmall", "GameFontDisableLarge", "GameFontWhite", "GameFontBlack",
        "SystemFont_Small", "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Med3", "SystemFont_Large" },
    chat = { "ChatFontNormal", "ChatFontSmall", "ChatBubbleFont" },
    tooltips = { "GameTooltipHeader", "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall", "Tooltip_Med", "Tooltip_Small" },
    quests = { "QuestFont", "QuestFont_Large", "QuestFont_Huge", "QuestFont_Super_Huge", "QuestFont_Shadow_Small",
        "QuestFont_Shadow_Huge", "QuestFont_Enormous", "QuestFontNormalSmall", "QuestFontHighlight", "QuestFontLeft",
        "QuestTitleFont", "QuestTitleFontBlackShadow", "ObjectiveFont", "ObjectiveTrackerHeaderFont", "ObjectiveTrackerLineFont" },
    unitframes = { "TextStatusBarText", "TextStatusBarTextLarge" },
    names = { "SystemFont_NamePlate", "SystemFont_NamePlateFixed", "SystemFont_LargeNamePlate", "SystemFont_LargeNamePlateFixed", "SystemFont_NamePlateCastBar" },
    combat = { "CombatTextFont", "CombatTextFontOutline" },
    actionbars = { "NumberFontNormal", "NumberFontNormalSmall", "NumberFontNormalSmallGray", "NumberFontNormalLarge" },
    zone = { "ZoneTextFont", "SubZoneTextFont", "PVPInfoTextFont" },
    errors = { "ErrorFont" },
}
local UNIT_PATHS = {
    "PlayerName", "PlayerLevelText", "PetName", "TargetFrame.name", "TargetFrame.levelText", "FocusFrame.name", "FocusFrame.levelText",
    "TargetFrame.TargetFrameContent.TargetFrameContentMain.Name", "TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelText",
    "FocusFrame.TargetFrameContent.TargetFrameContentMain.Name", "FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelText",
    "TargetFrameTextureFrameName", "TargetFrameTextureFrameLevelText", "FocusFrameTextureFrameName", "FocusFrameTextureFrameLevelText",
    "TargetFrameToT.Name", "TargetFrameToT.name", "TargetFrameToTTextureFrameName", "FocusFrameToT.Name", "FocusFrameToT.name", "FocusFrameToTTextureFrameName",
}
for i = 1, 4 do
    UNIT_PATHS[#UNIT_PATHS + 1] = "PartyMemberFrame" .. i .. "Name"
    UNIT_PATHS[#UNIT_PATHS + 1] = "PartyFrame.Member" .. i .. ".name"
    UNIT_PATHS[#UNIT_PATHS + 1] = "PartyFrame.Member" .. i .. ".Name"
end
local GLOBALS = { STANDARD_TEXT_FONT = "ui", UNIT_NAME_FONT = "names", NAMEPLATE_FONT = "names", DAMAGE_TEXT_FONT = "combat" }
local originals = setmetatable({}, { __mode = "k" })
local written = setmetatable({}, { __mode = "k" })
local originalGlobals = {}
local pending = false

local function Resolve(path)
    local current = _G
    for part in path:gmatch("[^.]+") do
        if type(current) ~= "table" then return end
        current = current[part]
    end
    return current
end

local function CanUse(object)
    if not object or not object.GetFont or not object.SetFont then return false end
    if object.IsForbidden then
        local ok, forbidden = pcall(object.IsForbidden, object)
        if not ok or forbidden then return false end
    end
    return true
end

local function Capture(object)
    local ok, path, size, flags = pcall(object.GetFont, object)
    if not ok or type(path) ~= "string" or type(size) ~= "number" or size <= 0 then return end
    local state = { path = path, size = size, flags = flags or "" }
    if object.GetShadowOffset and object.GetShadowColor and object.SetShadowOffset and object.SetShadowColor then
        local offsetOK, x, y = pcall(object.GetShadowOffset, object)
        local colorOK, r, g, b, alpha = pcall(object.GetShadowColor, object)
        if offsetOK and colorOK and type(x) == "number" and type(y) == "number"
            and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            state.shadow = { x, y, r, g, b, alpha or 1 }
        end
    end
    return state
end

local function Outline(flags, choice)
    if choice == "DEFAULT" then return flags end
    local parts = {}
    for flag in flags:gmatch("[^,%s]+") do
        if flag ~= "OUTLINE" and flag ~= "THICKOUTLINE" then parts[#parts + 1] = flag end
    end
    if choice ~= "NONE" then parts[#parts + 1] = choice end
    return table.concat(parts, ",")
end

local function SetStyle(object, base, path, style)
    if not base.shadow and style.shadow ~= "DEFAULT" then return false end
    local target = path or base.path
    local size, flags = base.size * style.scale, Outline(base.flags, style.outline)
    local ok, current, currentSize, currentFlags = pcall(object.GetFont, object)
    if not ok then return false end
    if current ~= target or currentSize ~= size or (currentFlags or "") ~= flags then
        local changed, result = pcall(object.SetFont, object, target, size, flags)
        if not changed or result == false then return false end
    end
    if base.shadow then
        local shadow = base.shadow
        local x, y = shadow[1], shadow[2]
        local r, g, b, alpha = shadow[3], shadow[4], shadow[5], shadow[6]
        if style.shadow == "NONE" then x, y = 0, 0 end
        if style.shadow == "SHADOW" then x, y, r, g, b, alpha = 1, -1, 0, 0, 0, 1 end
        local offsetOK = pcall(object.SetShadowOffset, object, x, y)
        local colorOK = pcall(object.SetShadowColor, object, r, g, b, alpha)
        if not offsetOK or not colorOK then return false end
    end
    return true
end

local function CombatScale(scale)
    local db = ns.GetDB()
    if type(db.worldTextScaleOriginal) ~= "number" or not (db.worldTextScaleOriginal > 0) then
        db.worldTextScaleOriginal = nil
    end
    if scale == 1 and not db.worldTextScaleOriginal then return true end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not get or not set then return false end
    if not db.worldTextScaleOriginal then
        local ok, current = pcall(get, cvarName)
        current = ok and tonumber(current)
        if not current or current <= 0 then return false end
        db.worldTextScaleOriginal = current
    end
    local ok, result = pcall(set, cvarName, db.worldTextScaleOriginal * scale)
    if not ok or result == false then return false end
    if scale == 1 then db.worldTextScaleOriginal = nil end
    return true
end

function ns.ApplyAreas()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("FontManager") then
        ns.applyMessage = L["Area changes are paused while FontManager is loaded. Disable FM and use /reload. Font sharing remains active."]
        return false, ns.applyMessage
    end
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        ns.applyMessage = L["Settings saved. Changes will apply after combat."]
        return false, ns.applyMessage
    end
    pending = false
    local areas = ns.GetDB().areas
    local desired, paths, styles, missing = {}, {}, {}, 0
    for _, area in ipairs(ns.Areas) do
        local name = areas[area.key]
        styles[area.key] = ns.GetStyle(area.key)
        paths[area.key] = name and ns.GetFontPath(name) or nil
        if name and not paths[area.key] then missing = missing + 1 end
    end
    local function Add(object, key)
        if not CanUse(object) then return end
        local style = styles[key]
        local active = paths[key] or style.scale ~= 1 or style.outline ~= "DEFAULT" or style.shadow ~= "DEFAULT"
        if not active and not written[object] then return end
        if not originals[object] then originals[object] = Capture(object) end
        if not originals[object] then return end
        desired[object] = { path = paths[key], style = style, active = active }
    end
    for _, area in ipairs(ns.Areas) do
        for _, name in ipairs(TARGETS[area.key]) do Add(_G[name], area.key) end
    end
    for i = 1, NUM_CHAT_WINDOWS or 10 do Add(_G["ChatFrame" .. i], "chat") end
    for _, path in ipairs(UNIT_PATHS) do Add(Resolve(path), "unitframes") end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local valid, font = pcall(function()
                    if plate.IsForbidden and plate:IsForbidden() then return end
                    return plate.UnitFrame and plate.UnitFrame.name
                end)
                if valid then Add(font, "names") end
            end
        end
    end
    local applied, failed = 0, 0
    for object, choice in pairs(desired) do
        local style = choice.style
        written[object] = true
        if SetStyle(object, originals[object], choice.path, style) then
            written[object] = choice.active and true or nil
            if not choice.active then originals[object] = nil end
            applied = applied + 1
        else
            failed = failed + 1
        end
    end
    if not CombatScale(styles.combat.scale) then failed = failed + 1 end
    for name, key in pairs(GLOBALS) do
        if paths[key] then
            if not originalGlobals[name] then originalGlobals[name] = { value = _G[name] } end
            _G[name] = paths[key]
        elseif originalGlobals[name] then
            _G[name] = originalGlobals[name].value
            originalGlobals[name] = nil
        end
    end
    ns.applyMessage = string.format(L["Default UI fonts applied. %d objects processed, %d failed, %d fonts not found."], applied, failed, missing)
    return failed == 0 and missing == 0, ns.applyMessage
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(events.RegisterEvent, events, "NAME_PLATE_UNIT_ADDED")
events:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_ENABLED" or pending then
        ns.ApplyAreas()
        if ns.UpdateApplyStatus then ns.UpdateApplyStatus() end
    end
end)
