-- -----------------------------------------------------------------------------
-- HUDitorTools - per-element scale, font, and label offset for HUD_MANAGER elements
-- Scale: Control:SetScale. Font: LabelControl:SetFont / GetFont.
-- Label offset: Control:GetAnchor / ClearAnchors / SetAnchor. Positive offsetY
-- moves text down. Reapply after ZO_HUDManager:PropagateSettings (hudmanager.lua)
-- and when the hud_editor_keyboard scene hides. SetScale is only on the HUD control.
-- The editor box stays the unscaled hudElementRef size from RefreshAnchors.
-- Anchor offsets and dimensions are reapplied as "Nui" so custom UI scale
-- does not interpret those GetDimensions / GetLeft numbers a second time.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

HT.APPEARANCE_SCALE_STEP = 0.01
HT.APPEARANCE_FONT_SIZE_DEFAULT = 18
HT.APPEARANCE_LABEL_OFFSET_Y_MIN = -32
HT.APPEARANCE_LABEL_OFFSET_Y_MAX = 32
HT.APPEARANCE_FONT_OUTLINE_WITH_MEDIA = "soft-shadow-thick"
HT.APPEARANCE_FONT_OUTLINE_GAME = "soft-shadow-thin"

HT.APPEARANCE_FONT_OUTLINES =
{
    "none",
    "outline",
    "thin-outline",
    "thick-outline",
    "shadow",
    "soft-shadow-thin",
    "soft-shadow-thick",
}

local GAME_FONT_FACE_CHOICES =
{
    { face = "$(MEDIUM_FONT)",         stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_MEDIUM"         },
    { face = "$(BOLD_FONT)",           stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_BOLD"           },
    { face = "$(ANTIQUE_FONT)",        stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_ANTIQUE"        },
    { face = "$(GAMEPAD_MEDIUM_FONT)", stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_GAMEPAD_MEDIUM" },
    { face = "$(GAMEPAD_BOLD_FONT)",   stringId = "SI_HUDITORTOOLS_APPEARANCE_FONT_GAMEPAD_BOLD"   },
}

local editorScaleHooksInstalled = false
local applyingAllAppearances = false
local saveKeysWithFontApplied = {}
local saveKeysWithLabelOffset = {}
local appliedFontLabelsBySaveKey = {}
local ANCHOR_OFFSET_MATCH_EPSILON = 0.01
local controlsApplyingAppearance = {}
local shownHookInstalled = {}

-- Labels already created on this element. Not a walk of every HUD control.
local MAX_FONT_LABEL_VISITS = 80

local function ReadScale(scale)
    scale = tonumber(scale)
    if scale == nil or scale <= 0 then
        return 1
    end
    return scale
end

local function ReadFontSize(fontSize)
    fontSize = tonumber(fontSize)
    if fontSize == nil then
        return HT.APPEARANCE_FONT_SIZE_DEFAULT
    end
    fontSize = zo_floor(fontSize)
    if fontSize < 1 then
        return 1
    end
    return fontSize
end

function HT.ClampAppearanceLabelOffsetY(labelOffsetY)
    labelOffsetY = tonumber(labelOffsetY)
    if labelOffsetY == nil then
        return 0
    end
    labelOffsetY = zo_floor(labelOffsetY)
    if labelOffsetY < HT.APPEARANCE_LABEL_OFFSET_Y_MIN then
        return HT.APPEARANCE_LABEL_OFFSET_Y_MIN
    end
    if labelOffsetY > HT.APPEARANCE_LABEL_OFFSET_Y_MAX then
        return HT.APPEARANCE_LABEL_OFFSET_Y_MAX
    end
    return labelOffsetY
end

function HT.GetAppearanceInputModeKey()
    if IsInGamepadPreferredMode() then
        return "gamepad"
    end
    return "keyboard"
end

function HT.GetDefaultFontOutline()
    if LibMediaProvider then
        return HT.APPEARANCE_FONT_OUTLINE_WITH_MEDIA
    end
    return HT.APPEARANCE_FONT_OUTLINE_GAME
end

function HT.CopyElementAppearance(sourceAppearance)
    local copiedAppearance =
    {
        keyboard = {},
        gamepad = {},
    }
    if type(sourceAppearance) ~= "table" then
        return copiedAppearance
    end
    for _, inputModeKey in ipairs({ "keyboard", "gamepad" }) do
        local sourceMap = sourceAppearance[inputModeKey]
        if type(sourceMap) == "table" then
            for saveKey, row in pairs(sourceMap) do
                if type(row) == "table" then
                    copiedAppearance[inputModeKey][saveKey] =
                    {
                        scale = tonumber(row.scale) or 1,
                        fontFace = row.fontFace or "",
                        fontSize = tonumber(row.fontSize) or HT.APPEARANCE_FONT_SIZE_DEFAULT,
                        fontOutline = row.fontOutline or "",
                        labelOffsetY = HT.ClampAppearanceLabelOffsetY(row.labelOffsetY),
                    }
                end
            end
        end
    end
    return copiedAppearance
end

local function GetAppearanceRoot()
    local appearance = HT.SV.elementAppearance
    if type(appearance) ~= "table" then
        appearance = HT.CopyElementAppearance(nil)
        HT.SV.elementAppearance = appearance
    end
    if type(appearance.keyboard) ~= "table" then
        appearance.keyboard = {}
    end
    if type(appearance.gamepad) ~= "table" then
        appearance.gamepad = {}
    end
    return appearance
end

function HT.GetAppearanceMap(inputModeKey)
    local appearance = GetAppearanceRoot()
    inputModeKey = inputModeKey or HT.GetAppearanceInputModeKey()
    return appearance[inputModeKey]
end

function HT.GetAppearanceRow(saveKey, inputModeKey)
    if not saveKey then
        return nil
    end
    return HT.GetAppearanceMap(inputModeKey)[saveKey]
end

function HT.IsAppearanceRowDefault(row)
    if type(row) ~= "table" then
        return true
    end
    local scale = tonumber(row.scale) or 1
    local fontFace = row.fontFace or ""
    if zo_abs(scale - 1) >= 0.001 then
        return false
    end
    if fontFace ~= "" then
        return false
    end
    if HT.ClampAppearanceLabelOffsetY(row.labelOffsetY) ~= 0 then
        return false
    end
    return true
end

function HT.SetAppearanceRow(saveKey, row, inputModeKey)
    if not saveKey then
        return
    end
    local modeMap = HT.GetAppearanceMap(inputModeKey)
    if HT.IsAppearanceRowDefault(row) then
        modeMap[saveKey] = nil
        return
    end
    modeMap[saveKey] =
    {
        scale = ReadScale(row.scale),
        fontFace = row.fontFace or "",
        fontSize = ReadFontSize(row.fontSize),
        fontOutline = row.fontOutline or HT.GetDefaultFontOutline(),
        labelOffsetY = HT.ClampAppearanceLabelOffsetY(row.labelOffsetY),
    }
end

function HT.BuildAppearanceFontString(fontFace, fontSize, fontOutline)
    if fontFace == nil or fontFace == "" then
        return nil
    end
    fontSize = ReadFontSize(fontSize)
    if LibMediaProvider and LibMediaProvider.Fetch then
        local fontPath = LibMediaProvider:Fetch("font", fontFace)
        if fontPath and fontPath ~= "" then
            local outline = fontOutline
            if outline == nil or outline == "" then
                outline = HT.APPEARANCE_FONT_OUTLINE_WITH_MEDIA
            end
            return string.format("%s|%d|%s", fontPath, fontSize, outline)
        end
    end
    if string.find(fontFace, "$(", 1, true) then
        return string.format("%s|%d|%s", fontFace, fontSize, HT.APPEARANCE_FONT_OUTLINE_GAME)
    end
    return nil
end

function HT.GetFontFaceChoices()
    local choices = {}
    local choiceLabels = {}
    choices[1] = ""
    choiceLabels[1] = GetString(SI_HUDITORTOOLS_APPEARANCE_FONT_DEFAULT)
    if LibMediaProvider and LibMediaProvider.List then
        local mediaNames = LibMediaProvider:List("font")
        if type(mediaNames) == "table" then
            local sortedNames = {}
            for _, mediaName in ipairs(mediaNames) do
                sortedNames[#sortedNames + 1] = mediaName
            end
            table.sort(sortedNames)
            for _, mediaName in ipairs(sortedNames) do
                choices[#choices + 1] = mediaName
                choiceLabels[#choiceLabels + 1] = mediaName
            end
        end
        return choices, choiceLabels
    end
    for _, gameFace in ipairs(GAME_FONT_FACE_CHOICES) do
        choices[#choices + 1] = gameFace.face
        choiceLabels[#choiceLabels + 1] = GetString(_G[gameFace.stringId])
    end
    return choices, choiceLabels
end

local function VisitLabels(control, onLabel)
    local pendingControls = { control }
    local visitedControls = {}
    local pendingCount = 1
    local visitedCount = 0
    while pendingCount > 0 and visitedCount < MAX_FONT_LABEL_VISITS do
        local currentControl = pendingControls[pendingCount]
        pendingControls[pendingCount] = nil
        pendingCount = pendingCount - 1
        if currentControl and not visitedControls[currentControl] then
            visitedControls[currentControl] = true
            visitedCount = visitedCount + 1
            if currentControl:GetType() == CT_LABEL then
                onLabel(currentControl)
            else
                local childCount = currentControl:GetNumChildren()
                if childCount > MAX_FONT_LABEL_VISITS then
                    childCount = MAX_FONT_LABEL_VISITS
                end
                for childIndex = 1, childCount do
                    if visitedCount + pendingCount >= MAX_FONT_LABEL_VISITS then
                        break
                    end
                    pendingCount = pendingCount + 1
                    pendingControls[pendingCount] = currentControl:GetChild(childIndex)
                end
            end
        end
    end
end

local function SetLabelFont(label, fontString)
    if not label.huditorToolsOriginalFont then
        label.huditorToolsOriginalFont = label:GetFont()
    end
    label:SetFont(fontString)
end

local function ApplyFontStringToLabels(control, fontString, saveKey)
    local knownLabels = appliedFontLabelsBySaveKey[saveKey]
    if knownLabels and #knownLabels > 0 then
        for labelIndex = 1, #knownLabels do
            knownLabels[labelIndex]:SetFont(fontString)
        end
        return
    end
    local foundLabels = {}
    VisitLabels(control, function (label)
        SetLabelFont(label, fontString)
        foundLabels[#foundLabels + 1] = label
    end)
    if #foundLabels > 0 then
        appliedFontLabelsBySaveKey[saveKey] = foundLabels
    end
end

local function RestoreFontStringOnLabels(control, saveKey)
    local knownLabels = appliedFontLabelsBySaveKey[saveKey]
    if knownLabels and #knownLabels > 0 then
        for labelIndex = 1, #knownLabels do
            local label = knownLabels[labelIndex]
            local originalFont = label.huditorToolsOriginalFont
            if originalFont then
                label:SetFont(originalFont)
            end
        end
        appliedFontLabelsBySaveKey[saveKey] = nil
        return
    end
    VisitLabels(control, function (label)
        local originalFont = label.huditorToolsOriginalFont
        if originalFont then
            label:SetFont(originalFont)
        end
    end)
end

-- GetAnchor(anchorIndex) returns isValidAnchor, point, relativeTo, relativePoint,
-- offsetX, offsetY, anchorConstrains. ESOUIDocumentation.txt Control methods.
local function CaptureLabelAnchors(label)
    local anchors = {}
    local anchorCount = label:GetNumAnchors()
    for anchorIndex = 0, anchorCount - 1 do
        local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY, anchorConstrains = label:GetAnchor(anchorIndex)
        if isValidAnchor then
            anchors[#anchors + 1] =
            {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX,
                offsetY = offsetY,
                anchorConstrains = anchorConstrains,
            }
        end
    end
    return anchors
end

local function AnchorsMatchAppliedOffset(currentAnchors, baseAnchors, appliedOffsetY)
    if #currentAnchors ~= #baseAnchors then
        return false
    end
    for anchorIndex = 1, #currentAnchors do
        local currentAnchor = currentAnchors[anchorIndex]
        local baseAnchor = baseAnchors[anchorIndex]
        if currentAnchor.point ~= baseAnchor.point
        or currentAnchor.relativeTo ~= baseAnchor.relativeTo
        or currentAnchor.relativePoint ~= baseAnchor.relativePoint
        or currentAnchor.anchorConstrains ~= baseAnchor.anchorConstrains then
            return false
        end
        if zo_abs(currentAnchor.offsetX - baseAnchor.offsetX) > ANCHOR_OFFSET_MATCH_EPSILON then
            return false
        end
        local expectedOffsetY = baseAnchor.offsetY + appliedOffsetY
        if zo_abs(currentAnchor.offsetY - expectedOffsetY) > ANCHOR_OFFSET_MATCH_EPSILON then
            return false
        end
    end
    return true
end

local function WriteLabelAnchors(label, baseAnchors, labelOffsetY)
    label:ClearAnchors()
    for anchorIndex = 1, #baseAnchors do
        local baseAnchor = baseAnchors[anchorIndex]
        local offsetY = baseAnchor.offsetY + labelOffsetY
        if baseAnchor.anchorConstrains ~= nil then
            label:SetAnchor(baseAnchor.point, baseAnchor.relativeTo, baseAnchor.relativePoint, baseAnchor.offsetX, offsetY, baseAnchor.anchorConstrains)
        else
            label:SetAnchor(baseAnchor.point, baseAnchor.relativeTo, baseAnchor.relativePoint, baseAnchor.offsetX, offsetY)
        end
    end
end

local function ApplyLabelOffsetY(label, labelOffsetY)
    local currentAnchors = CaptureLabelAnchors(label)
    if #currentAnchors == 0 then
        return
    end
    local baseAnchors = label.huditorToolsLabelAnchorBase
    local appliedOffsetY = label.huditorToolsAppliedLabelOffsetY or 0
    if not baseAnchors or not AnchorsMatchAppliedOffset(currentAnchors, baseAnchors, appliedOffsetY) then
        baseAnchors = currentAnchors
        label.huditorToolsLabelAnchorBase = baseAnchors
    end
    WriteLabelAnchors(label, baseAnchors, labelOffsetY)
    label.huditorToolsAppliedLabelOffsetY = labelOffsetY
end

local function ApplyLabelOffsetToControl(control, labelOffsetY)
    VisitLabels(control, function (label)
        if labelOffsetY ~= 0 or label.huditorToolsLabelAnchorBase then
            ApplyLabelOffsetY(label, labelOffsetY)
        end
    end)
end

local function InstallShownHook(control, element)
    local controlName = control:GetName()
    if controlName == "" or shownHookInstalled[controlName] then
        return
    end
    shownHookInstalled[controlName] = true
    ZO_PostHookHandler(control, "OnEffectivelyShown", function ()
        HT.ApplyElementAppearance(element)
    end)
end

function HT.ApplyElementAppearance(element)
    if not element then
        return
    end
    local control = element:GetControl()
    if controlsApplyingAppearance[control] then
        return
    end
    controlsApplyingAppearance[control] = true
    local saveKey = element:GetSaveKey()
    local row = HT.GetAppearanceRow(saveKey)
    local scale = 1
    local fontFace = ""
    local fontSize = HT.APPEARANCE_FONT_SIZE_DEFAULT
    local fontOutline = HT.GetDefaultFontOutline()
    local labelOffsetY = 0
    if row then
        scale = ReadScale(row.scale)
        fontFace = row.fontFace or ""
        fontSize = ReadFontSize(row.fontSize)
        fontOutline = row.fontOutline or fontOutline
        labelOffsetY = HT.ClampAppearanceLabelOffsetY(row.labelOffsetY)
    end
    local currentScale = control:GetScale() or 1
    if zo_abs(currentScale - scale) >= 0.001 then
        control:SetScale(scale)
    end
    if fontFace ~= "" then
        local fontString = HT.BuildAppearanceFontString(fontFace, fontSize, fontOutline)
        if fontString then
            ApplyFontStringToLabels(control, fontString, saveKey)
            saveKeysWithFontApplied[saveKey] = true
        end
    elseif saveKeysWithFontApplied[saveKey] then
        RestoreFontStringOnLabels(control, saveKey)
        saveKeysWithFontApplied[saveKey] = nil
    end
    if labelOffsetY ~= 0 then
        ApplyLabelOffsetToControl(control, labelOffsetY)
        saveKeysWithLabelOffset[saveKey] = true
    elseif saveKeysWithLabelOffset[saveKey] then
        ApplyLabelOffsetToControl(control, 0)
        saveKeysWithLabelOffset[saveKey] = nil
    end
    if row and not HT.IsAppearanceRowDefault(row) then
        InstallShownHook(control, element)
    end
    controlsApplyingAppearance[control] = nil
end

function HT.ApplyAllElementAppearances()
    if applyingAllAppearances or not HT.SV then
        return
    end
    applyingAllAppearances = true
    HT.ApplyResourceBarGroup()
    local modeMap = HT.GetAppearanceMap()
    local function ApplySavedAppearance(saveKey)
        local control = _G[saveKey]
        if type(control) ~= "userdata" then
            return
        end
        local element
        if IsInGamepadPreferredMode() then
            element = HUD_MANAGER:GetGamepadElementForControl(control)
        else
            element = HUD_MANAGER:GetKeyboardElementForControl(control)
        end
        if element then
            HT.ApplyElementAppearance(element)
        end
    end
    for saveKey, row in pairs(modeMap) do
        if not HT.IsAppearanceRowDefault(row) then
            ApplySavedAppearance(saveKey)
        end
    end
    local labelOffsetSaveKeys = {}
    for saveKey in pairs(saveKeysWithLabelOffset) do
        labelOffsetSaveKeys[#labelOffsetSaveKeys + 1] = saveKey
    end
    for saveKeyIndex = 1, #labelOffsetSaveKeys do
        local saveKey = labelOffsetSaveKeys[saveKeyIndex]
        if HT.IsAppearanceRowDefault(modeMap[saveKey]) then
            ApplySavedAppearance(saveKey)
        end
    end
    applyingAllAppearances = false
end

function HT.StepSelectedElementScale(editorElement, direction)
    -- ZO_HUDEditorElement_Keyboard:GetElementData (HUDEditor_Keyboard.lua)
    local elementData = editorElement:GetElementData()
    if not elementData then
        return
    end
    local saveKey = elementData:GetSaveKey()
    local row = HT.GetAppearanceRow(saveKey) or {}
    local scale = (tonumber(row.scale) or 1) + (direction * HT.APPEARANCE_SCALE_STEP)
    if scale <= 0 then
        scale = HT.APPEARANCE_SCALE_STEP
    end
    scale = zo_roundToNearest(scale, HT.APPEARANCE_SCALE_STEP)
    HT.SetAppearanceRow(saveKey,
                        {
                            scale = scale,
                            fontFace = row.fontFace,
                            fontSize = row.fontSize,
                            fontOutline = row.fontOutline,
                            labelOffsetY = row.labelOffsetY,
                        })
    HT.ApplyElementAppearance(elementData)
    editorElement:RefreshAnchors()
    HT.RefreshAppearanceInfoBox()
    HT.RefreshLayoutInfoBoxSection()
end

local function OnEditorElementMouseWheel(editorControl, delta)
    local editorElement = editorControl.object
    if not editorElement or HUD_EDITOR_KEYBOARD:GetSelectedElement() ~= editorElement then
        return
    end
    local direction = 1
    if delta < 0 then
        direction = -1
    end
    HT.StepSelectedElementScale(editorElement, direction)
end

function HT.InstallElementScaleMouseWheel(editor)
    -- ZO_HUDEditor_Keyboard.elementControls is created in :New and filled by PopulateElementControls.
    for _, elementControl in ipairs(editor.elementControls) do
        if not elementControl.huditorToolsScaleWheelInstalled then
            elementControl.huditorToolsScaleWheelInstalled = true
            if not elementControl:GetHandler("OnMouseWheel") then
                elementControl:SetHandler("OnMouseWheel", OnEditorElementMouseWheel)
            end
        end
    end
end

-- Same unit suffix as GridOverlay.FormatUiLayoutMeasurement ("%dui").
local function FormatUiLayoutMeasurement(layoutValue)
    return string.format("%dui", zo_round(layoutValue))
end

local function ApplyEditorPreviewUiUnits(editorElement)
    -- ZO_HUDEditorElement_Keyboard:RefreshAnchors (HUDEditor_Keyboard.lua)
    -- ZO_HUDManager_Element:GetConvertedRefControlAnchorInfo (HUDManager.lua)
    local primaryAnchorPoint, refOffsetX, refOffsetY, refWidth, refHeight = editorElement.elementData:GetConvertedRefControlAnchorInfo()
    local editorControl = editorElement.control
    editorControl:ClearAnchors()
    editorControl:SetAnchor(primaryAnchorPoint, nil, nil, FormatUiLayoutMeasurement(refOffsetX), FormatUiLayoutMeasurement(refOffsetY))
    editorControl:SetDimensions(FormatUiLayoutMeasurement(refWidth), FormatUiLayoutMeasurement(refHeight))
end

function HT.InstallElementAppearanceEditorHooks()
    if editorScaleHooksInstalled then
        return
    end
    editorScaleHooksInstalled = true
    SecurePostHook(ZO_HUDEditor_Keyboard, "PopulateElementControls", function (editor)
        HT.InstallElementScaleMouseWheel(editor)
    end)
    SecurePostHook(ZO_HUDEditorElement_Keyboard, "RefreshAnchors", function (editorElement)
        ApplyEditorPreviewUiUnits(editorElement)
    end)
end

function HT.NormalizeLayoutPayload(payload)
    payload = payload or {}
    local normalizedPayload =
    {
        keyboardElements = {},
        gamepadElements = {},
        elementAppearance = HT.CopyElementAppearance(payload.elementAppearance),
        resourceBarGroup = HT.CopyResourceBarGroup(payload.resourceBarGroup),
    }
    if type(payload.keyboardElements) == "table" then
        ZO_DeepTableCopy(payload.keyboardElements, normalizedPayload.keyboardElements)
    end
    if type(payload.gamepadElements) == "table" then
        ZO_DeepTableCopy(payload.gamepadElements, normalizedPayload.gamepadElements)
    end
    return normalizedPayload
end

function HT.InitializeElementAppearance()
    GetAppearanceRoot()
    HT.InstallElementAppearanceEditorHooks()
    -- ZO_HUDManager:RegisterCallback via ZO_InitializingCallbackObject (HUDManager.lua)
    HUD_MANAGER:RegisterCallback("PropagateSettings", function ()
        HT.ApplyAllElementAppearances()
    end)
    HT.ApplyAllElementAppearances()
    GetEventManager():RegisterForEvent(HT.eventName .. "_Appearance", EVENT_PLAYER_ACTIVATED, function ()
        zo_callLater(HT.ApplyAllElementAppearances, 0)
    end)
end
