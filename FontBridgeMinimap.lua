local addonName, ns = ...
local L = ns.L
local ICON_PATH = [[Interface\AddOns\FontBridge\assets\FontBridge-icon.tga]]
local icon

function ns.SetMinimapButtonHidden(hidden)
    local minimap = ns.GetDB().minimap
    minimap.hide = hidden == true
    if icon and icon:IsRegistered(addonName) then
        if minimap.hide then
            icon:Hide(addonName)
        else
            icon:Show(addonName)
        end
    end
end

function ns.ToggleMinimapButton()
    ns.SetMinimapButtonHidden(not ns.GetDB().minimap.hide)
end

local function Initialize()
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not broker or not icon then return end

    local object = broker:NewDataObject(addonName, {
        type = "launcher",
        text = addonName,
        icon = ICON_PATH,
        OnClick = function(_, button)
            if button == "LeftButton" then
                ns.ToggleWindow()
            elseif button == "RightButton" then
                ns.SetMinimapButtonHidden(true)
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(addonName)
            tooltip:AddLine(L["Left-click to open FontBridge. Drag to move. Right-click to hide."], 1, 1, 1, true)
        end,
    })
    icon:Register(addonName, object, ns.GetDB().minimap)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon == addonName then Initialize() end
end)
