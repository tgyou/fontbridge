local addonName, ns = ...
local L = ns.L
local FONT_DIR = [[Interface\AddOns\FontBridge\Fonts\]]
local initialized, tester
local removedFonts = {}

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
    if type(FontBridgeDB.minimap) ~= "table" then FontBridgeDB.minimap = {} end
    if type(FontBridgeDB.minimap.hide) ~= "boolean" then FontBridgeDB.minimap.hide = false end
    if type(FontBridgeDB.minimap.minimapPos) ~= "number" then FontBridgeDB.minimap.minimapPos = 220 end
    return FontBridgeDB
end

function ns.GetFontPath(name)
    local lsm = Media()
    return lsm and lsm:HashTable("font")[name]
end

function ns.IsFontRemoved(name)
    return removedFonts[name] == true
end

local function Duplicate(name, path)
    for _, entry in ipairs(ns.GetDB().fonts) do
        if type(entry) == "table" then
            if entry.name == name then return L["A font with this display name already exists."] end
            if type(entry.path) == "string" and PathKey(entry.path) == PathKey(path) then
                return L["This file is already in the list."]
            end
        end
    end
    local registered = ns.GetFontPath(name)
    if registered and (type(registered) ~= "string" or PathKey(registered) ~= PathKey(path)) then
        return L["Another font already uses this name. Enter a different name."]
    end
end

function ns.AddFont(name, path)
    name, path = Trim(name), Trim(path):gsub("/", "\\")
    if name == "" or path == "" then return false, L["Enter a display name and font filename."] end
    if not path:lower():match("%.ttf$") and not path:lower():match("%.otf$") then
        return false, L["Font files must use the .ttf or .otf extension."]
    end
    if path:find("%.%.", 1) then return false, L["Parent folder paths are not allowed."] end
    if not path:lower():match("^interface\\") then
        if path:find("[:\\]") then return false, L["Full paths must start with Interface\\."] end
        path = FONT_DIR .. path
    end
    local duplicate = Duplicate(name, path)
    if duplicate then return false, duplicate end
    tester = tester or CreateFont("FontBridgeFileTester")
    local ok, result = pcall(tester.SetFont, tester, path, 12, "")
    local got = ok and tester:GetFont()
    if not ok or result == false or type(got) ~= "string" or PathKey(got) ~= PathKey(path) then
        return false, L["Could not load the font. Check the filename and path. Fully restart the game after adding new files."]
    end
    table.insert(ns.GetDB().fonts, { name = name, path = path })
    removedFonts[name] = nil
    ns.Refresh(false)
    return true, L["Font added. You can select it in any addon that supports LSM."]
end


function ns.RemoveFont(index)
    local db = ns.GetDB()
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #db.fonts then
        return false, L["Select a font to remove."]
    end
    local entry = table.remove(db.fonts, index)
    if type(entry) == "table" then
        removedFonts[entry.name] = true
        for key, name in pairs(db.areas) do
            if name == entry.name then db.areas[key] = nil end
        end
    end
    if ns.ApplyAreas then ns.ApplyAreas() end
    ns.Refresh(false)
    return true, L["Removed from the list. Use /reload to remove it from the LSM list."]
end

function ns.Refresh(report)
    local snapshot = { rows = {}, added = 0, existing = 0, conflicts = 0, rejected = 0, invalid = 0 }
    local lsm = Media()
    local fonts = lsm and lsm:HashTable("font") or {}
    if not lsm then snapshot.error = L["Could not load LibSharedMedia."] end
    for index, entry in ipairs(ns.GetDB().fonts) do
        local row = { index = index, name = L["Invalid entry"], file = "", status = "invalid" }
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
    table.sort(snapshot.rows, function(left, right)
        local leftName, rightName = left.name:lower(), right.name:lower()
        if leftName == rightName then return left.name < right.name end
        return leftName < rightName
    end)
    ns.snapshot = snapshot
    if ns.UpdateWindow then ns.UpdateWindow(snapshot) end
    if report then
        ns.Print(snapshot.error or string.format(L["%d added, %d registered, %d name conflicts, %d rejected, %d invalid entries."],
            snapshot.added, snapshot.existing, snapshot.conflicts, snapshot.rejected, snapshot.invalid))
    end
    return snapshot
end

function ns.SetArea(key, name)
    local known
    for _, area in ipairs(ns.Areas or {}) do if area.key == key then known = true break end end
    if not known then return false, L["Unknown display area."] end
    if name == "" then name = nil end
    if name ~= nil and (type(name) ~= "string" or not ns.GetFontPath(name)) then
        return false, L["Select a registered font."]
    end
    ns.GetDB().areas[key] = name
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["Settings saved."]
end

ns.StyleOptions = { scale = {}, outline = {
    { label = L["Game default"], value = "DEFAULT" }, { label = L["None"], value = "NONE" },
    { label = L["Thin"], value = "OUTLINE" }, { label = L["Thick"], value = "THICKOUTLINE" },
}, shadow = {
    { label = L["Game default"], value = "DEFAULT" }, { label = L["None"], value = "NONE" },
    { label = L["On"], value = "SHADOW" },
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
    if not area then return false, L["Unknown display area."] end
    if not ns.StyleOptions[field] then return false, L["Unknown detail setting."] end
    if area.locked and area.locked[field] then return false, L["The game does not support this setting for this area."] end
    if not ValidStyle(field, value) then return false, L["Select a supported setting value."] end
    local db = ns.GetDB()
    if type(db.styles[key]) ~= "table" then db.styles[key] = {} end
    db.styles[key][field] = value
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["Settings saved."]
end

function ns.ResetArea(key)
    if not Area(key) then return false, L["Unknown display area."] end
    local db = ns.GetDB()
    db.areas[key], db.styles[key] = nil, nil
    if ns.ApplyAreas then ns.ApplyAreas() end
    return true, ns.applyMessage or L["Area settings restored to defaults."]
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
    elseif command == "minimap" then
        ns.ToggleMinimapButton()
    elseif command == "minimap show" then
        ns.SetMinimapButtonHidden(false)
    elseif command == "minimap hide" then
        ns.SetMinimapButtonHidden(true)
    else
        ns.Print(L["/fontbridge or /fb opens the window; /fb refresh updates the font list. /fb minimap toggles its button; use /fb minimap show or hide to set it."])
    end
end
