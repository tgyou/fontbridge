local _, ns = ...
local L = ns.L
local window
local dropdownCount = 0
local STATUS = {
    added = { L["Shared"], 0.35, 0.9, 0.65 }, existing = { L["Shared"], 0.35, 0.9, 0.65 },
    conflicts = { L["Name conflict"], 1, 0.6, 0.3 }, rejected = { L["Rejected"], 1, 0.4, 0.4 },
    invalid = { L["Needs attention"], 1, 0.4, 0.4 },
}
local FIELDS = { { "scale", L["Size"] }, { "outline", L["Outline"] }, { "shadow", L["Shadow"] } }
local COLUMNS = {
    font = { x = 178, width = 260 }, scale = { x = 448, width = 104 },
    outline = { x = 562, width = 130 }, shadow = { x = 702, width = 140 },
}

local function Label(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Fill(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

local function Border(parent)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = parent:CreateTexture(nil, "BORDER")
        texture:SetColorTexture(0.2, 0.27, 0.34, 0.8)
        if side == "TOP" or side == "BOTTOM" then
            texture:SetHeight(1)
            texture:SetPoint(side .. "LEFT")
            texture:SetPoint(side .. "RIGHT")
        else
            texture:SetWidth(1)
            texture:SetPoint("TOP" .. side)
            texture:SetPoint("BOTTOM" .. side)
        end
    end
end

local function Panel(parent, title)
    local frame = CreateFrame("Frame", nil, parent)
    Fill(frame, 0.07, 0.09, 0.12)
    Border(frame)
    frame.title = Label(frame, title, "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 16, -15)
    return frame
end

local function Button(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 28)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Scroll(parent, left, top, right, bottom, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", left, top)
    scroll:SetPoint("BOTTOMRIGHT", -right, bottom)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)
    return content, scroll
end

local function Message(message)
    window.message:SetText(message or "")
end

local function CloseMenu()
    if UIDROPDOWNMENU_OPEN_MENU and UIDROPDOWNMENU_OPEN_MENU.fontBridge then CloseDropDownMenus() end
end

local function OptionLabel(field, value)
    for _, option in ipairs(ns.StyleOptions[field]) do
        if option.value == value then return option.label end
    end
    return L["Default"]
end

local function UpdateAreas()
    window.applyMessage:SetText(ns.applyMessage or L["Saves the selected settings and applies them to the default UI."])
    for _, row in ipairs(window.areaRows) do
        row.font:SetText(ns.GetDB().areas[row.area.key] or L["Game default"])
        local style = ns.GetStyle(row.area.key)
        for _, field in ipairs(FIELDS) do
            local key = field[1]
            row[key]:SetText(row.area.locked and row.area.locked[key] and L["Unavailable"] or OptionLabel(key, style[key]))
        end
    end
end

function ns.UpdateApplyStatus()
    if window and window:IsShown() then UpdateAreas() end
end

local function Select(parent, width, choices, selected, callback)
    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(width, 28)
    dropdownCount = dropdownCount + 1
    local dropdown = CreateFrame("Frame", "FontBridgeSelection" .. dropdownCount, control, "UIDropDownMenuTemplate")
    dropdown.fontBridge = true
    dropdown:SetPoint("TOPLEFT", -16, 3)
    UIDropDownMenu_SetWidth(dropdown, width - 30)
    function control:SetText(text)
        UIDropDownMenu_SetSelectedValue(dropdown, selected())
        UIDropDownMenu_SetText(dropdown, text)
    end
    function control:Disable()
        UIDropDownMenu_DisableDropDown(dropdown)
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, choice in ipairs(choices()) do
            local value = choice.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            info.value = value
            info.checked = selected() == value
            info.func = function()
                callback(value)
                UpdateAreas()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return control
end

local function FontChoices()
    local choices = { { label = L["Game default"] } }
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media then
        for _, name in ipairs(media:List("font")) do choices[#choices + 1] = { label = name, value = name } end
    end
    return choices
end

local function Preview(row)
    window.selected = row.path
    window.previewTitle:SetText(row.name)
    window.path:SetText(row.path or L["No file path"])
    window.preview:SetText("")
    local ok, result
    if row.path then ok, result = pcall(window.preview.SetFont, window.preview, row.path, 24, "") end
    if ok and result ~= false then
        window.preview:SetText(L["The quick brown fox\nABC abc\n1234567890"])
        window.previewState:SetText(L["Font loaded.\nCheck that the sample text is visible."])
    else
        window.previewState:SetText(L["Could not load the font.\nCheck the file path. Fully restart the game after adding new files."])
    end
    for _, button in ipairs(window.rows) do button.selected:SetShown(button.data and button.data.path == window.selected) end
end

function ns.UpdateWindow(snapshot)
    if not window or not window:IsShown() then return end
    window.summary:SetText(snapshot.error or string.format(L["%d installed  ·  %d shared  ·  %d need attention"],
        #snapshot.rows, snapshot.added + snapshot.existing, snapshot.conflicts + snapshot.rejected + snapshot.invalid))
    local selected
    for i, row in ipairs(snapshot.rows) do
        local button = window.rows[i]
        if not button then
            button = CreateFrame("Button", nil, window.content)
            button:SetSize(550, 56)
            button:SetPoint("TOPLEFT", 0, -(i - 1) * 58)
            Fill(button, 0.1, 0.13, 0.17, 0.65)
            button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
            button.selected = Fill(button, 0.13, 0.39, 0.55, 0.4)
            button.name = Label(button, "")
            button.name:SetPoint("TOPLEFT", 10, -9)
            button.name:SetWidth(370)
            button.file = Label(button, "", "GameFontDisableSmall")
            button.file:SetPoint("TOPLEFT", 10, -33)
            button.file:SetWidth(365)
            button.status = Label(button, "", "GameFontHighlightSmall")
            button.status:SetPoint("RIGHT", -80, 0)
            button.remove = Button(button, L["Delete"], 62, function(self)
                local _, message = ns.RemoveFont(self:GetParent().data.index)
                ns.Refresh(false)
                Message(message)
            end)
            button.remove:SetPoint("RIGHT", -8, 0)
            button:SetScript("OnClick", function(self) Preview(self.data) end)
            window.rows[i] = button
        end
        button.data = row
        button.name:SetText(row.name)
        button.file:SetText(row.file)
        local status = STATUS[row.status] or STATUS.invalid
        button.status:SetText(status[1])
        button.status:SetTextColor(status[2], status[3], status[4])
        button:Show()
        if row.path and row.path == window.selected then selected = row end
    end
    for i = #snapshot.rows + 1, #window.rows do window.rows[i]:Hide() window.rows[i].data = nil end
    window.content:SetHeight(math.max(1, #snapshot.rows * 58))
    window.empty:SetShown(#snapshot.rows == 0)
    if selected or snapshot.rows[1] then Preview(selected or snapshot.rows[1]) else
        window.selected = nil
        window.previewTitle:SetText(L["No font selected"])
        window.path:SetText("")
        window.preview:SetText("")
        window.previewState:SetText(L["Select a font from the list on the left, or add one below."])
    end
    UpdateAreas()
end

local function Edit(parent, width)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width, 28)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    return edit
end

local function AreaCard(parent, area, y)
    local card = Panel(parent, area.label)
    card:SetSize(948, 40)
    card:SetPoint("TOPLEFT", 0, -y)
    card.area = area
    card.title:ClearAllPoints()
    card.title:SetPoint("LEFT", 12, 0)
    card.title:SetSize(158, 30)
    card.title:SetWordWrap(true)
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(area.label)
        GameTooltip:AddLine(area.note or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local reset = Button(card, L["Reset"], 82, function()
        local _, message = ns.ResetArea(area.key)
        Message(message)
        UpdateAreas()
    end)
    reset:SetPoint("RIGHT", -12, 0)
    card.font = Select(card, COLUMNS.font.width, FontChoices, function()
        return ns.GetDB().areas[area.key]
    end, function(value)
        local _, message = ns.SetArea(area.key, value)
        Message(message)
    end)
    card.font:SetPoint("TOPLEFT", COLUMNS.font.x, -6)
    for _, field in ipairs(FIELDS) do
        local key = field[1]
        local column = COLUMNS[key]
        local control = Select(card, column.width, function()
            return ns.StyleOptions[key]
        end, function()
            return ns.GetStyle(area.key)[key]
        end, function(value)
            local _, message = ns.SetAreaStyle(area.key, key, value)
            Message(message)
        end)
        control:SetPoint("TOPLEFT", column.x, -6)
        if area.locked and area.locked[key] then control:Disable() end
        card[key] = control
    end
    return card
end

local function CreateWindow()
    local frame = CreateFrame("Frame", "FontBridgeWindow", UIParent)
    frame:Hide()
    frame:SetSize(1040, 760)
    local height, width = UIParent:GetHeight(), UIParent:GetWidth()
    frame:SetScale(math.min(1, (height - 32) / 760, (width - 32) / 1040))
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    Fill(frame, 0.035, 0.045, 0.065)
    Border(frame)
    local title = Label(frame, "FontBridge", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -23)
    local author = Label(frame, "Arthen Mithrill <LIGHTNING SPEED> KR PvP Horde", "GameFontDisableSmall")
    author:SetPoint("TOPRIGHT", -46, -25)
    author:SetWidth(570)
    author:SetJustifyH("RIGHT")
    local subtitle = Label(frame, L["Manage your font library and default UI fonts in one place."], "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", 24, -52)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    local fonts = CreateFrame("Frame", nil, frame)
    fonts:SetPoint("TOPLEFT", 24, -122)
    fonts:SetPoint("BOTTOMRIGHT", -24, 58)
    local areas = CreateFrame("Frame", nil, frame)
    areas:SetAllPoints(fonts)
    areas:Hide()
    local fontTab, areaTab
    local function Tab(showFonts)
        CloseMenu()
        fonts:SetShown(showFonts)
        areas:SetShown(not showFonts)
        fontTab:SetEnabled(not showFonts)
        areaTab:SetEnabled(showFonts)
        UpdateAreas()
    end
    fontTab = Button(frame, L["Fonts"], 136, function() Tab(true) end)
    fontTab:SetPoint("TOPLEFT", 24, -79)
    fontTab:Disable()
    areaTab = Button(frame, L["Area settings"], 136, function() Tab(false) end)
    areaTab:SetPoint("LEFT", fontTab, "RIGHT", 8, 0)

    local list = Panel(fonts, L["Installed fonts"])
    list:SetPoint("TOPLEFT")
    list:SetPoint("BOTTOMLEFT", 0, 184)
    list:SetWidth(600)
    frame.summary = Label(list, "", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 16, -40)
    frame.summary:SetWidth(440)
    local refresh = Button(list, L["Refresh"], 90, function() ns.Refresh(false) end)
    refresh:SetPoint("TOPRIGHT", -12, -11)
    frame.content = Scroll(list, 12, -67, 37, 52, 550)
    frame.rows = {}
    frame.empty = Label(list, L["No fonts are installed."], "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", 23, -86)
    local removalNote = Label(list, L["List removals take full effect after /reload."], "GameFontDisableSmall")
    removalNote:SetPoint("BOTTOMLEFT", 12, 16)
    removalNote:SetWidth(550)
    local preview = Panel(fonts, L["Preview"])
    preview:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
    preview:SetPoint("BOTTOMRIGHT", 0, 184)
    frame.previewTitle = Label(preview, "", "GameFontNormalLarge")
    frame.previewTitle:SetPoint("TOPLEFT", 18, -52)
    frame.previewTitle:SetWidth(330)
    frame.path = Label(preview, "", "GameFontHighlightSmall")
    frame.path:SetPoint("TOPLEFT", 18, -86)
    frame.path:SetSize(330, 64)
    frame.path:SetWordWrap(true)
    frame.preview = Label(preview, "")
    frame.preview:SetPoint("TOPLEFT", 18, -169)
    frame.preview:SetSize(330, 110)
    frame.preview:SetWordWrap(true)
    frame.previewState = Label(preview, "", "GameFontDisableSmall")
    frame.previewState:SetPoint("BOTTOMLEFT", 18, 18)
    frame.previewState:SetSize(330, 64)
    frame.previewState:SetWordWrap(true)
    local addPanel = Panel(fonts, L["Add a font"])
    addPanel:SetPoint("BOTTOMLEFT")
    addPanel:SetPoint("BOTTOMRIGHT")
    addPanel:SetHeight(170)
    local nameLabel = Label(addPanel, L["Display name"], "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 20, -47)
    local pathLabel = Label(addPanel, L["Filename or Interface path"], "GameFontNormalSmall")
    pathLabel:SetPoint("TOPLEFT", 248, -47)
    frame.nameInput = Edit(addPanel, 210)
    frame.nameInput:SetPoint("TOPLEFT", 22, -69)
    frame.pathInput = Edit(addPanel, 574)
    frame.pathInput:SetPoint("TOPLEFT", 250, -69)
    local add = Button(addPanel, L["Add"], 130, function()
        local ok, message = ns.AddFont(frame.nameInput:GetText(), frame.pathInput:GetText())
        if ok then
            frame.nameInput:SetText("") frame.pathInput:SetText("")
            frame.nameInput:ClearFocus() frame.pathInput:ClearFocus()
            ns.Refresh(false)
        end
        Message(message)
    end)
    add:SetPoint("TOPRIGHT", -18, -69)
    frame.nameInput:SetScript("OnTabPressed", function() frame.pathInput:SetFocus() end)
    frame.pathInput:SetScript("OnEnterPressed", function() add:Click() end)
    local hint = Label(addPanel, L["Place font files in FontBridge/Fonts and fully restart the game, then enter the filename including its extension."], "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, -114)
    hint:SetWidth(950)
    local note = Label(addPanel, L["Removing a list entry does not delete its file. Registered fonts are available to all addons that support LSM."], "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 18, -137)
    note:SetWidth(950)

    local state = Panel(areas, L["Area fonts and effects"])
    state:SetPoint("TOPLEFT") state:SetPoint("TOPRIGHT") state:SetHeight(62)
    frame.applyMessage = Label(state, "", "GameFontHighlightSmall")
    frame.applyMessage:SetPoint("TOPLEFT", 16, -30)
    frame.applyMessage:SetSize(956, 28)
    frame.applyMessage:SetWordWrap(true)
    local areaHeading = Label(areas, L["Area settings"], "GameFontNormalSmall")
    areaHeading:SetPoint("TOPLEFT", 12, -75)
    local fontHeading = Label(areas, L["Font"], "GameFontNormalSmall")
    fontHeading:SetPoint("TOPLEFT", COLUMNS.font.x, -75)
    for _, field in ipairs(FIELDS) do
        local heading = Label(areas, field[2], "GameFontNormalSmall")
        heading:SetPoint("TOPLEFT", COLUMNS[field[1]].x, -75)
    end
    local content = Scroll(areas, 0, -96, 30, 2, 948)
    frame.areaRows = {}
    local groups, ordered = {}, {}
    for _, area in ipairs(ns.Areas) do
        local section = area.section or L["Area settings"]
        if not groups[section] then groups[section] = {} ordered[#ordered + 1] = section end
        groups[section][#groups[section] + 1] = area
    end
    local y = 0
    for _, section in ipairs(ordered) do
        local heading = Label(content, section, "GameFontNormalSmall")
        heading:SetPoint("TOPLEFT", 4, -y - 3)
        y = y + 22
        for _, area in ipairs(groups[section]) do
            frame.areaRows[#frame.areaRows + 1] = AreaCard(content, area, y)
            y = y + 44
        end
        y = y + 8
    end
    content:SetHeight(y)
    frame.message = Label(frame, "", "GameFontHighlightSmall")
    frame.message:SetPoint("BOTTOMLEFT", 24, 14)
    frame.message:SetSize(992, 30)
    frame.message:SetWordWrap(true)
    UISpecialFrames[#UISpecialFrames + 1] = "FontBridgeWindow"
    frame:SetScript("OnShow", function() ns.Refresh(false) end)
    frame:SetScript("OnHide", CloseMenu)
    return frame
end

function ns.ToggleWindow()
    if not window then window = CreateWindow() end
    window:SetShown(not window:IsShown())
end
