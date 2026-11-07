local _, ns = ...
local L = ns.L

ns.Areas = {
    { key = "ui", section = L["기본 화면"], label = L["일반 UI"], note = L["기본 메뉴·버튼·안내문에 적용합니다."] },
    { key = "chat", section = L["대화와 정보"], label = L["채팅"], note = L["기본 채팅 창과 말풍선 글꼴입니다."] },
    { key = "tooltips", section = L["대화와 정보"], label = L["툴팁"], note = L["기본 툴팁의 제목과 본문입니다."] },
    { key = "quests", section = L["대화와 정보"], label = L["퀘스트"], note = L["퀘스트 본문·제목·목표 추적 글꼴입니다."] },
    { key = "unitframes", section = L["캐릭터와 전투"], label = L["기본 유닛 프레임"], note = L["플레이어·대상·주시·파티의 기본 프레임입니다. SUF는 SUF에서 설정하세요."] },
    { key = "names", section = L["캐릭터와 전투"], locked = { scale = true, outline = true, shadow = true }, label = L["캐릭터 이름"], note = L["기본 이름표와 머리 위 이름입니다. 크기·외곽선·그림자는 변경할 수 없습니다. 머리 위 이름은 재접속이 필요할 수 있습니다."] },
    { key = "combat", section = L["캐릭터와 전투"], locked = { outline = true, shadow = true }, label = L["전투 숫자"], note = L["크기는 전투 문자 배율로 설정합니다. 외곽선·그림자는 지원하지 않으며 글꼴은 재접속이 필요할 수 있습니다."] },
    { key = "actionbars", section = L["기본 화면"], label = L["행동 단축바"], note = L["기본 단축키 표시와 수량 글꼴입니다."] },
    { key = "zone", section = L["세계와 알림"], label = L["지역 이름"], note = L["지역 진입 시 표시되는 이름입니다."] },
    { key = "errors", section = L["세계와 알림"], label = L["오류 메시지"], note = L["화면 중앙의 기본 오류 안내문입니다."] },
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
            area.note = L["이 클라이언트는 전투 숫자의 크기·외곽선·그림자 설정을 지원하지 않습니다. 글꼴은 재접속이 필요할 수 있습니다."]
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
        ns.applyMessage = L["FontManager가 켜져 있어 영역별 적용을 중지했습니다. FM을 비활성화하고 /reload 하세요. 폰트 공유는 유지됩니다."]
        return false, ns.applyMessage
    end
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        ns.applyMessage = L["설정을 저장했습니다. 전투가 끝나면 적용합니다."]
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
    ns.applyMessage = string.format(L["기본 UI 글꼴 적용 완료. 확인 대상 %d개, 적용 실패 %d개, 찾을 수 없는 폰트 %d개."], applied, failed, missing)
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
