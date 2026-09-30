-- -----------------------------------------------------------------------------
-- HUDitorTools - stack player resource bars at a fixed width
-- Observed: PlayerAttributeBars.lua NORMAL_WIDTH 237, EXPANDED_WIDTH 323,
-- SHRUNK_WIDTH 141, ResizeToFitScreen, FRAME_OPTIONS key "Combine".
-- Pyramid matches LuiExtended UnitFrames.RepositionDefaultFrames
-- (_DefaultFrames.lua): magicka TOPRIGHT and stamina TOPLEFT on health BOTTOM.
-- Health stays CENTER of ZO_PlayerAttribute so HUD_MANAGER keeps the offset.
-- Bar widths stay the stock values. Siege uses the same CENTER offset as LuiExtended.
-- preventExpand sets ShrinkExpand expandedWidth to NORMAL_WIDTH 237.
-- Observed: ShrinkExpand.lua TryChangingState / OnValueChanged(bar, info, stat, instant).
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local STOCK_BAR_WIDTH = 237
local STOCK_EXPANDED_WIDTH = 323
local STOCK_SHRUNK_WIDTH = 141
local STOCK_SMALL_BAR_WIDTH = 228
local MIN_HEALTH_WIDTH = 200
local MAX_HEALTH_WIDTH = 1200

HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH = STOCK_BAR_WIDTH * 2

local groupedLayoutIsApplied = false
local resourceBarHooksInstalled = false

local function ClampHealthWidth(healthWidth)
    healthWidth = zo_floor(tonumber(healthWidth) or HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH)
    if healthWidth < MIN_HEALTH_WIDTH then
        return MIN_HEALTH_WIDTH
    end
    if healthWidth > MAX_HEALTH_WIDTH then
        return MAX_HEALTH_WIDTH
    end
    return healthWidth
end

function HT.CopyResourceBarGroup(sourceGroup)
    local healthWidth = HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH
    local enabled = false
    local preventExpand = false
    if type(sourceGroup) == "table" then
        enabled = sourceGroup.enabled == true
        healthWidth = ClampHealthWidth(sourceGroup.healthWidth)
        preventExpand = sourceGroup.preventExpand == true
    end
    return
    {
        enabled = enabled,
        healthWidth = healthWidth,
        preventExpand = preventExpand,
    }
end

local function GetResourceBarGroupSettings()
    local settings = HT.SV and HT.SV.resourceBarGroup
    if type(settings) ~= "table" then
        settings = HT.CopyResourceBarGroup(nil)
        if HT.SV then
            HT.SV.resourceBarGroup = settings
        end
    end
    settings.healthWidth = ClampHealthWidth(settings.healthWidth)
    settings.enabled = settings.enabled == true
    settings.preventExpand = settings.preventExpand == true
    return settings
end

function HT.IsResourceBarGroupEnabled()
    local settings = HT.SV and HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.enabled == true
end

function HT.IsResourceBarPreventExpand()
    local settings = HT.SV and HT.SV.resourceBarGroup
    return type(settings) == "table" and settings.preventExpand == true
end

function HT.GetResourceBarGroupedHealthWidth()
    return GetResourceBarGroupSettings().healthWidth
end

function HT.GetResourceBarGroupedWidth(stat)
    local healthWidth = HT.GetResourceBarGroupedHealthWidth()
    if stat == STAT_HEALTH_MAX then
        return healthWidth
    end
    if stat == STAT_MAGICKA_MAX or stat == STAT_STAMINA_MAX then
        return zo_floor((healthWidth - 2) / 2)
    end
    return nil
end

function HT.IsPlayerAttributeFrameSaveKey(saveKey)
    return saveKey == "ZO_PlayerAttribute"
end

function HT.IsPlayerResourceBarSaveKey(saveKey)
    return saveKey == "ZO_PlayerAttribute"
        or saveKey == "ZO_PlayerAttributeHealth"
        or saveKey == "ZO_PlayerAttributeMagicka"
        or saveKey == "ZO_PlayerAttributeStamina"
end

local function GetShrinkExpandModule()
    -- ZO_UnitAttributeVisualizer.visualModules is set in UnitAttributeVisualizer:New.
    -- PLAYER_ATTRIBUTE_BARS.attributeVisualizer is set in ZO_PlayerAttributeBars:New.
    local visualModules = PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules
    for visualModule in pairs(visualModules) do
        if visualModule.normalWidth and visualModule.expandedWidth and visualModule.barControls then
            return visualModule
        end
    end
    return nil
end

local function SetBarWidth(bar, width)
    -- bgContainer is assigned in ZO_PlayerAttributeContainer OnInitialized.
    bar:SetWidth(width)
    bar.bgContainer:SetWidth(width)
end

local function GetPlayerAttributeFrameElement()
    if IsInGamepadPreferredMode() then
        return HUD_MANAGER:GetGamepadElementForControl(ZO_PlayerAttribute)
    end
    return HUD_MANAGER:GetKeyboardElementForControl(ZO_PlayerAttribute)
end

local function IsPlayerAttributeFrameCombined()
    return GetPlayerAttributeFrameElement():GetCustomOptionValue("Combine") == true
end

local function SetResourceBarsCombined()
    local frameElement = GetPlayerAttributeFrameElement()
    if frameElement:GetCustomOptionValue("Combine") then
        return
    end
    frameElement:SetCustomOptionValue("Combine", nil, true)
end

local function ApplyStackedResourceBarLayout()
    local parent = ZO_PlayerAttribute
    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina

    health:ClearAnchors()
    health:SetAnchor(CENTER, parent, CENTER, 0, 0)

    -- LuiExtended UnitFrames.RepositionDefaultFrames
    magicka:ClearAnchors()
    magicka:SetAnchor(TOPRIGHT, health, BOTTOM, -1, 2)

    stamina:ClearAnchors()
    stamina:SetAnchor(TOPLEFT, health, BOTTOM, 1, 2)

    ZO_PlayerAttributeSiegeHealth:ClearAnchors()
    ZO_PlayerAttributeSiegeHealth:SetAnchor(CENTER, health, CENTER, 300, 0)
end

local function RestoreStockResourceBarLayout()
    local parent = ZO_PlayerAttribute
    local health = ZO_PlayerAttributeHealth
    local magicka = ZO_PlayerAttributeMagicka
    local stamina = ZO_PlayerAttributeStamina

    magicka:ClearAnchors()
    magicka:SetAnchor(RIGHT, parent, LEFT, STOCK_BAR_WIDTH, 0)
    health:ClearAnchors()
    health:SetAnchor(CENTER, parent, CENTER, 0, 0)
    stamina:ClearAnchors()
    stamina:SetAnchor(LEFT, parent, RIGHT, -STOCK_BAR_WIDTH, 0)

    ZO_PlayerAttributeSiegeHealth:ClearAnchors()
    ZO_PlayerAttributeSiegeHealth:SetAnchor(TOP, health, BOTTOM, 0, -1)
    ZO_PlayerAttributeSiegeHealth:SetWidth(STOCK_SMALL_BAR_WIDTH)
    ZO_PlayerAttributeWerewolf:SetWidth(STOCK_SMALL_BAR_WIDTH)
    ZO_PlayerAttributeMountStamina:SetWidth(STOCK_SMALL_BAR_WIDTH)

    local shrinkModule = GetShrinkExpandModule()
    if shrinkModule and shrinkModule.barInfo then
        for stat, info in pairs(shrinkModule.barInfo) do
            local bar = shrinkModule.barControls[stat]
            local width = STOCK_BAR_WIDTH
            if info.state == ATTRIBUTE_BAR_STATE_EXPANDED then
                width = STOCK_EXPANDED_WIDTH
            elseif info.state == ATTRIBUTE_BAR_STATE_SHRUNK then
                width = STOCK_SHRUNK_WIDTH
            end
            SetBarWidth(bar, width)
        end
    else
        SetBarWidth(health, STOCK_BAR_WIDTH)
        SetBarWidth(magicka, STOCK_BAR_WIDTH)
        SetBarWidth(stamina, STOCK_BAR_WIDTH)
    end

    PLAYER_ATTRIBUTE_BARS:ResizeToFitScreen()
end

local function ApplyPreventResourceBarExpand()
    local shrinkModule = GetShrinkExpandModule()
    if not shrinkModule or not shrinkModule.barInfo then
        return
    end
    local targetExpandedWidth = STOCK_EXPANDED_WIDTH
    if HT.IsResourceBarPreventExpand() then
        targetExpandedWidth = STOCK_BAR_WIDTH
    end
    shrinkModule.expandedWidth = targetExpandedWidth
    for stat, bar in pairs(shrinkModule.barControls) do
        local info = shrinkModule.barInfo[stat]
        if info and info.state == ATTRIBUTE_BAR_STATE_EXPANDED and zo_abs(bar:GetWidth() - targetExpandedWidth) > 0.5 then
            info.state = ATTRIBUTE_BAR_STATE_NORMAL
            shrinkModule:OnValueChanged(bar, info, stat, true)
        end
    end
end

function HT.ApplyResourceBarGroup()
    if not HT.SV then
        return
    end
    GetResourceBarGroupSettings()
    if HT.IsResourceBarGroupEnabled() and not IsPlayerAttributeFrameCombined() then
        GetResourceBarGroupSettings().enabled = false
    end
    if HT.IsResourceBarGroupEnabled() then
        ApplyStackedResourceBarLayout()
        groupedLayoutIsApplied = true
    elseif groupedLayoutIsApplied then
        RestoreStockResourceBarLayout()
        groupedLayoutIsApplied = false
    end
    ApplyPreventResourceBarExpand()
end

function HT.SetResourceBarPreventExpand(preventExpand)
    local settings = GetResourceBarGroupSettings()
    settings.preventExpand = preventExpand == true
    ApplyPreventResourceBarExpand()
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupEnabled(enabled)
    local settings = GetResourceBarGroupSettings()
    settings.enabled = enabled == true
    if settings.enabled then
        SetResourceBarsCombined()
    end
    HT.ApplyResourceBarGroup()
    if HUD_EDITOR_KEYBOARD:IsShowing() then
        HUD_EDITOR_KEYBOARD:RebuildAllElements()
    end
    HT.RefreshLayoutInfoBoxSection()
end

function HT.SetResourceBarGroupHealthWidth(healthWidth)
    local settings = GetResourceBarGroupSettings()
    settings.healthWidth = ClampHealthWidth(healthWidth)
    if settings.enabled then
        HT.ApplyResourceBarGroup()
        if HUD_EDITOR_KEYBOARD:IsShowing() then
            HUD_EDITOR_KEYBOARD:RebuildAllElements()
        end
    end
    HT.RefreshLayoutInfoBoxSection()
    return settings.healthWidth
end

-- While the original runs, the instance field points at the original so any
-- self:methodName() call inside it cannot re-enter this wrapper.
local function CreateGroupedLayoutMethodHook(attributeBars, methodName)
    local originalMethod = attributeBars[methodName]
    local groupedLayoutMethod
    groupedLayoutMethod = function (self, ...)
        self[methodName] = originalMethod
        originalMethod(self, ...)
        self[methodName] = groupedLayoutMethod
        if HT.IsResourceBarGroupEnabled() then
            ApplyStackedResourceBarLayout()
            groupedLayoutIsApplied = true
        end
        if methodName == "ApplyStyle" then
            HT.ApplyAllElementAppearances()
        end
    end
    attributeBars[methodName] = groupedLayoutMethod
end

function HT.InitializeResourceBarGroup()
    GetResourceBarGroupSettings()
    if not resourceBarHooksInstalled then
        resourceBarHooksInstalled = true
        CreateGroupedLayoutMethodHook(PLAYER_ATTRIBUTE_BARS, "ApplyStyle")
        CreateGroupedLayoutMethodHook(PLAYER_ATTRIBUTE_BARS, "OnScreenResized")
    end
    HT.ApplyResourceBarGroup()
end
