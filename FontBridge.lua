local addonName, ns = ...
local L = ns.L
local FONT_DIR = [[Interface\AddOns\FontBridge\Fonts\]]
local initialized, tester

local function Trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

local function PathKey(path)
    return path:lower():gsub("/", "\\")
end

local function Media()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ns.Print(message)
    print("|cff66ccffFontBridge|r: " .. message)
end

function ns.GetDB()
    if type(FontBridgeDB) ~= "table" then FontBridgeDB = {} end
    if type(FontBridgeDB.fonts) ~= "table" then FontBridgeDB.fonts = {} end
    if type(FontBridgeDB.areas) ~= "table" then FontBridgeDB.areas = {} end
    if type(FontBridgeDB.styles) ~= "table" then FontBridgeDB.styles = {} end
    return FontBridgeDB
end

function ns.GetFontPath(name)
    local lsm = Media()
    return lsm and lsm:HashTable("font")[name]
end

local function Duplicate(name, path)
    for _, entry in ipairs(ns.GetDB().fonts) do
        if type(entry) == "table" then
            if entry.name == name then return L["같은 표시 이름이 이미 있습니다."] end
            if type(entry.path) == "string" and PathKey(entry.path) == PathKey(path) then
                return L["이 파일은 이미 목록에 있습니다."]
            end
        end
    end
    local registered = ns.GetFontPath(name)
    if registered and (type(registered) ~= "string" or PathKey(registered) ~= PathKey(path)) then
        return L["다른 폰트가 이미 사용하는 이름입니다. 다른 이름을 입력하세요."]
    end
end

function ns.AddFont(name, path)
    name, path = Trim(name), Trim(path):gsub("/", "\\")
    if name == "" or path == "" then return false, L["표시 이름과 폰트 파일명을 입력하세요."] end
    if not path:lower():match("%.ttf$") and not path:lower():match("%.otf$") then
        return false, L["폰트 파일은 .ttf 또는 .otf 형식이어야 합니다."]
    end
    if path:find("%.%.", 1) then return false, L["상위 폴더 경로는 사용할 수 없습니다."] end
    if not path:lower():match("^interface\\") then
        if path:find("[:\\]") then return false, L["전체 경로는 Interface\\ 로 시작해야 합니다."] end
        path = FONT_DIR .. path
    end
    local duplicate = Duplicate(name, path)
    if duplicate then return false, duplicate end
    tester = tester or CreateFont("FontBridgeFileTester")
    local ok, result = pcall(tester.SetFont, tester, path, 12, "")
    local got = ok and tester:GetFont()
    if not ok or result == false or type(got) ~= "string" or PathKey(got) ~= PathKey(path) then
        return false, L["폰트를 불러오지 못했습니다. 파일명과 경로를 확인하고 새 파일은 게임을 완전히 재시작하세요."]
    end
    table.insert(ns.GetDB().fonts, { name = name, path = path })
    ns.Refresh(false)
    return true, L["폰트를 추가했습니다. 모든 LSM 지원 애드온에서 선택할 수 있습니다."]
end


function ns.RemoveFont(index)
    local db = ns.GetDB()
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #db.fonts then
        return false, L["삭제할 폰트를 선택하세요."]
    end
    local entry = table.remove(db.fonts, index)
    if type(entry) == "table" then
        for key, name in pairs(db.areas) do
            if name == entry.name then db.areas[key] = nil end
        end
    end
    if ns.ApplyAreas then ns.ApplyAreas() end
    ns.Refresh(false)
    return true, L["목록에서 삭제했습니다. LSM 목록에서 완전히 제거하려면 /reload 하세요."]
end

function ns.Refresh(report)
    local snapshot = { rows = {}, added = 0, existing = 0, conflicts = 0, rejected = 0, invalid = 0 }
    local lsm = Media()
    local fonts = lsm and lsm:HashTable("font") or {}
    if not lsm then snapshot.error = L["LibSharedMedia를 불러오지 못했습니다."] end
    for index, entry in ipairs(ns.GetDB().fonts) do
        local row = { index = index, name = L["잘못된 항목"], file = "", status = "invalid" }
        if type(entry) == "table" and Trim(entry.name) ~= "" and Trim(entry.path) ~= "" then
            row.name, row.path = entry.name, entry.path
            row.file = entry.path:match("[^\\/]+$") or entry.path
            local registered = fonts[row.name]
            if registered then
                row.status = type(registered) == "string" and PathKey(registered) == PathKey(row.path) and "existing" or "conflicts"
            elseif lsm and lsm:Register("font", row.name, row.path, lsm.LOCALE_BIT_koKR + lsm.LOCALE_BIT_western) then
                row.status = "added"
            else
                row.status = "rejected"
            end
        end
        snapshot[row.status] = snapshot[row.status] + 1
        snapshot.rows[#snapshot.rows + 1] = row
    end
    ns.snapshot = snapshot
    if ns.UpdateWindow then ns.UpdateWindow(snapshot) end
    if report then
        ns.Print(snapshot.error or string.format(L["%d개 추가, %d개 등록됨, 이름 충돌 %d개, 거절 %d개, 잘못된 항목 %d개."],
            snapshot.added, snapshot.existing, snapshot.conflicts, snapshot.rejected, snapshot.invalid))
    end
    return snapshot
end

function ns.SetArea(key, name)
    local known
    for _, area in ipairs(ns.Areas or {}) do if area.key == key then known = true break end end
    if not known then return false, L["알 수 없는 적용 영역입니다."] end
    if name == "" then name = nil end
    if name ~= nil and (type(name) ~= "string" or not ns.GetFontPath(name)) then
        return false, L["등록된 폰트를 선택하세요."]
    end
    ns.GetDB().areas[key] = name
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["설정을 저장했습니다."]
end

ns.StyleOptions = { scale = {}, outline = {
    { label = L["게임 기본값"], value = "DEFAULT" }, { label = L["없음"], value = "NONE" },
    { label = L["얇게"], value = "OUTLINE" }, { label = L["두껍게"], value = "THICKOUTLINE" },
}, shadow = {
    { label = L["게임 기본값"], value = "DEFAULT" }, { label = L["없음"], value = "NONE" },
    { label = L["사용"], value = "SHADOW" },
} }
for _, scale in ipairs({ 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }) do
    ns.StyleOptions.scale[#ns.StyleOptions.scale + 1] = { label = string.format("%d%%", scale * 100), value = scale }
end

local function Area(key)
    for _, area in ipairs(ns.Areas or {}) do if area.key == key then return area end end
end

local function ValidStyle(field, value)
    for _, option in ipairs(ns.StyleOptions[field] or {}) do if option.value == value then return true end end
    return false
end

function ns.GetStyle(key)
    local area = Area(key)
    local source = ns.GetDB().styles[key]
    if type(source) ~= "table" then source = {} end
    local style = { scale = 1, outline = "DEFAULT", shadow = "DEFAULT" }
    for field in pairs(style) do
        if not (area and area.locked and area.locked[field]) and ValidStyle(field, source[field]) then
            style[field] = source[field]
        end
    end
    return style
end

function ns.SetAreaStyle(key, field, value)
    local area = Area(key)
    if not area then return false, L["알 수 없는 적용 영역입니다."] end
    if not ns.StyleOptions[field] then return false, L["알 수 없는 세부 설정입니다."] end
    if area.locked and area.locked[field] then return false, L["이 영역은 게임에서 해당 설정을 지원하지 않습니다."] end
    if not ValidStyle(field, value) then return false, L["지원하는 설정 값을 선택하세요."] end
    local db = ns.GetDB()
    if type(db.styles[key]) ~= "table" then db.styles[key] = {} end
    db.styles[key][field] = value
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["설정을 저장했습니다."]
end

function ns.ResetArea(key)
    if not Area(key) then return false, L["알 수 없는 적용 영역입니다."] end
    local db = ns.GetDB()
    db.areas[key], db.styles[key] = nil, nil
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["영역 설정을 기본값으로 복원했습니다."]
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        initialized = true
        ns.GetDB()
    end
    if initialized then
        ns.Refresh(false)
        if ns.ApplyAreas then ns.ApplyAreas() end
    end
end)

SLASH_FONTBRIDGE1 = "/fontbridge"
SLASH_FONTBRIDGE2 = "/fb"
SlashCmdList.FONTBRIDGE = function(message)
    local command = Trim(message):lower()
    if command == "" then
        ns.ToggleWindow()
    elseif command == "refresh" then
        ns.Refresh(true)
    else
        ns.Print(L["/fontbridge 또는 /fb 관리 창, /fb refresh 새로고침"])
    end
end
