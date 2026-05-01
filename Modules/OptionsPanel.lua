--[[
================================================================================
  Chromatix (幻色龙) - Modules/OptionsPanel.lua
  Settings panel using the modern Settings API (Interface 120000+).

  Author : David W Zhang
  Version: 1.1
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...
local L     = NS.L

----------------------------------------------------------------------
-- 1. Module Declaration
----------------------------------------------------------------------

--- @class OptionsPanel
local OptionsPanel = NS:NewModule("OptionsPanel")
NS.OptionsPanel    = OptionsPanel

----------------------------------------------------------------------
-- 2. Internal State
----------------------------------------------------------------------

--- Category ID for opening settings (number)
--- @type number|nil
local categoryID = nil

--- Whether the panel has been initialized yet.
--- @type boolean
local isInitialized = false

----------------------------------------------------------------------
-- 3. Panel Construction
----------------------------------------------------------------------

--- Build and register the options panel with the modern Settings API.
function OptionsPanel:BuildPanel()
    if isInitialized then
        NS:DebugPrint("OptionsPanel:BuildPanel — already initialized, skipping.")
        return
    end

    -- Guard: Settings API must exist
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        NS:DebugPrint("OptionsPanel:BuildPanel — Settings API not available.")
        return
    end

    ---------------------------------------------------------------------------
    -- 3.1 Create the canvas frame with VerticalLayoutFrame
    ---------------------------------------------------------------------------

    local optionsFrame = CreateFrame("Frame", "ChromatixOptionsFrame", nil, "VerticalLayoutFrame")
    optionsFrame.spacing = 8

    ---------------------------------------------------------------------------
    -- 3.2 Register with Settings API
    ---------------------------------------------------------------------------

    local ok, category, layout = pcall(Settings.RegisterCanvasLayoutCategory, optionsFrame, NS.ADDON_NAME)
    if not ok or not category then
        NS:DebugPrint("OptionsPanel:BuildPanel — Settings.RegisterCanvasLayoutCategory failed.")
        return
    end
    categoryID = category:GetID()
    pcall(Settings.RegisterAddOnCategory, category)

    NS:DebugPrint("OptionsPanel: registered with Settings API, categoryID:", categoryID)

    ---------------------------------------------------------------------------
    -- 3.3 Layout index helper
    ---------------------------------------------------------------------------

    local layoutIndex = 0
    local function GetLayoutIndex()
        layoutIndex = layoutIndex + 1
        return layoutIndex
    end

    ---------------------------------------------------------------------------
    -- 3.4 Header
    ---------------------------------------------------------------------------

    local header = CreateFrame("Frame", nil, optionsFrame)
    header:SetSize(400, 80)
    header.layoutIndex = GetLayoutIndex()

    local titleText = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 7, -16)
    titleText:SetText(L["OPTIONS_TITLE"])

    local versionText = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    versionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    versionText:SetText("v" .. NS.VERSION .. "  |cFF888888" .. NS.AUTHOR .. "|r")

    local descText = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    descText:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -8)
    descText:SetWidth(500)
    descText:SetJustifyH("LEFT")
    descText:SetText(L["ADDON_DESCRIPTION"])

    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("BOTTOMLEFT", 0, 0)

    ---------------------------------------------------------------------------
    -- 3.5 Naming mode section (only option)
    ---------------------------------------------------------------------------

    local namingFrame = CreateFrame("Frame", nil, optionsFrame)
    namingFrame:SetSize(400, 70)
    namingFrame.layoutIndex = GetLayoutIndex()

    local namingLabel = namingFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    namingLabel:SetPoint("TOPLEFT", 0, 0)
    namingLabel:SetText(L["OPTIONS_NAMING_MODE"])

    local namingDesc = namingFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    namingDesc:SetPoint("TOPLEFT", namingLabel, "BOTTOMLEFT", 0, -4)
    namingDesc:SetWidth(400)
    namingDesc:SetJustifyH("LEFT")
    namingDesc:SetText(L["OPTIONS_NAMING_DESC"])

    local btnEnglish = CreateFrame("CheckButton", nil, namingFrame, "UIRadioButtonTemplate")
    btnEnglish:SetPoint("TOPLEFT", namingDesc, "BOTTOMLEFT", 0, -8)
    local btnEnglishText = namingFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btnEnglishText:SetPoint("LEFT", btnEnglish, "RIGHT", 4, 0)
    btnEnglishText:SetText(L["OPTIONS_NAMING_ENGLISH"])

    local btnLocalized = CreateFrame("CheckButton", nil, namingFrame, "UIRadioButtonTemplate")
    btnLocalized:SetPoint("LEFT", btnEnglishText, "RIGHT", 20, 0)
    local btnLocalizedText = namingFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btnLocalizedText:SetPoint("LEFT", btnLocalized, "RIGHT", 4, 0)
    btnLocalizedText:SetText(L["OPTIONS_NAMING_LOCALIZED"])

    local function UpdateNamingMode()
        local mode = NS.NAMING_MODE.ENGLISH
        if NS.db and NS.db.global then
            mode = NS.db.global.namingMode or NS.NAMING_MODE.ENGLISH
        end
        btnEnglish:SetChecked(mode == NS.NAMING_MODE.ENGLISH)
        btnLocalized:SetChecked(mode == NS.NAMING_MODE.LOCALIZED)
    end

    btnEnglish:HookScript("OnClick", function(self)
        if self:GetChecked() then
            if NS.db and NS.db.global then
                NS.db.global.namingMode = NS.NAMING_MODE.ENGLISH
            end
            NS:DebugPrint("OptionsPanel: naming mode → english")
        end
    end)

    btnLocalized:HookScript("OnClick", function(self)
        if self:GetChecked() then
            if NS.db and NS.db.global then
                NS.db.global.namingMode = NS.NAMING_MODE.LOCALIZED
            end
            NS:DebugPrint("OptionsPanel: naming mode → localized")
        end
    end)

    namingFrame:SetScript("OnShow", UpdateNamingMode)

    ---------------------------------------------------------------------------
    -- 3.5a Auto Swap Checkbox
    ---------------------------------------------------------------------------

    local autoSwapFrame = CreateFrame("Frame", nil, optionsFrame)
    autoSwapFrame:SetSize(400, 30)
    autoSwapFrame.layoutIndex = GetLayoutIndex()
    autoSwapFrame.topPadding = 10

    local cbAutoSwap = CreateFrame("CheckButton", nil, autoSwapFrame, "SettingsCheckBoxTemplate")
    cbAutoSwap:SetPoint("TOPLEFT", 0, 0)
    cbAutoSwap:SetSize(26, 26)

    local cbAutoSwapText = autoSwapFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cbAutoSwapText:SetPoint("LEFT", cbAutoSwap, "RIGHT", 4, 0)
    cbAutoSwapText:SetText(L["OPTIONS_AUTO_SWAP"])

    local cbAutoSwapDesc = autoSwapFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbAutoSwapDesc:SetPoint("TOPLEFT", cbAutoSwap, "BOTTOMLEFT", 0, -2)
    cbAutoSwapDesc:SetText(L["OPTIONS_AUTO_SWAP_DESC"])

    cbAutoSwap:SetScript("OnClick", function(self)
        if NS.db and NS.db.global then
            NS.db.global.autoSwap = self:GetChecked()
        end
        NS:DebugPrint("OptionsPanel: autoSwap →", tostring(self:GetChecked()))
    end)

    autoSwapFrame:SetScript("OnShow", function()
        local val = true
        if NS.db and NS.db.global and NS.db.global.autoSwap == false then
            val = false
        end
        cbAutoSwap:SetChecked(val)
    end)

    ---------------------------------------------------------------------------
    -- 3.6 Debug Mode Checkbox
    ---------------------------------------------------------------------------

    local debugFrame = CreateFrame("Frame", nil, optionsFrame)
    debugFrame:SetSize(400, 30)
    debugFrame.layoutIndex = GetLayoutIndex()
    debugFrame.topPadding = 10

    local cbDebug = CreateFrame("CheckButton", nil, debugFrame, "SettingsCheckBoxTemplate")
    cbDebug:SetPoint("TOPLEFT", 0, 0)
    cbDebug:SetSize(26, 26)

    local cbDebugText = debugFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cbDebugText:SetPoint("LEFT", cbDebug, "RIGHT", 4, 0)
    cbDebugText:SetText(L["OPTIONS_DEBUG_MODE"])

    local cbDebugDesc = debugFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cbDebugDesc:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -2)
    cbDebugDesc:SetText(L["OPTIONS_DEBUG_DESC"])

    local function UpdateDebugMode()
        local debugOn = false
        if NS.db and NS.db.global then
            debugOn = NS.db.global.debugMode or false
        end
        cbDebug:SetChecked(debugOn)
    end

    cbDebug:SetScript("OnClick", function(self)
        if NS.db and NS.db.global then
            NS.db.global.debugMode = self:GetChecked()
        end
        NS:DebugPrint("OptionsPanel: debug mode →", tostring(self:GetChecked()))
    end)

    debugFrame:SetScript("OnShow", function()
        UpdateDebugMode()
        local textWidth = cbDebugText:GetStringWidth()
        if textWidth and textWidth > 0 then
            cbDebug:SetHitRectInsets(0, -textWidth - 4, 0, 0)
        end
    end)

    ---------------------------------------------------------------------------
    -- 3.7 Layout
    ---------------------------------------------------------------------------

    optionsFrame:Layout()

    isInitialized = true
end

----------------------------------------------------------------------
-- 4. Public API
----------------------------------------------------------------------

--- Open the Chromatix settings panel in the game's Settings window.
function OptionsPanel:Open()
    -- Combat check
    if InCombatLockdown() then
        NS:Print(L["ERR_PROTECTED_ACTION"])
        return
    end

    if not isInitialized then
        self:BuildPanel()
    end

    if categoryID then
        Settings.OpenToCategory(categoryID)
    else
        NS:DebugPrint("OptionsPanel:Open — categoryID not set.")
        if SettingsPanel then
            SettingsPanel:Show()
        end
    end
end

----------------------------------------------------------------------
-- 5. Module Lifecycle
----------------------------------------------------------------------

--- Called by EventManager when ADDON_LOADED fires for Chromatix.
function OptionsPanel:OnInitialize()
    NS:DebugPrint("OptionsPanel:OnInitialize")
    self:BuildPanel()
end

--- Called by EventManager on PLAYER_ENTERING_WORLD.
function OptionsPanel:OnEnable()
    NS:DebugPrint("OptionsPanel:OnEnable")
end
