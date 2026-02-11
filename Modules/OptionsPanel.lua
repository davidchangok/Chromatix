--[[
================================================================================
  Chromatix (幻色龙) - Modules/OptionsPanel.lua
  Settings panel using the modern Settings API (Interface 120000+).
  Provides user-configurable options: naming mode, auto-swap, debug mode,
  and character reset.

  Uses Settings.RegisterAddOnCategory / Settings.RegisterCanvasLayoutCategory
  instead of the deprecated InterfaceOptions_AddCategory.

  Author : David W Zhang
  Version: 1.0.0
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...
local L     = NS.L
local Utils = NS.Utils

----------------------------------------------------------------------
-- 1. Module Declaration
----------------------------------------------------------------------

--- @class OptionsPanel
local OptionsPanel = NS:NewModule("OptionsPanel")
NS.OptionsPanel    = OptionsPanel

----------------------------------------------------------------------
-- 2. Internal State
----------------------------------------------------------------------

--- Reference to the registered Settings category (for opening later).
--- @type table|nil
local settingsCategory = nil

--- Whether the panel has been initialized yet.
--- @type boolean
local isInitialized = false

----------------------------------------------------------------------
-- 3. Panel Construction
----------------------------------------------------------------------

--- Build and register the options panel with the modern Settings API.
--- Called once during OnInitialize; idempotent.
function OptionsPanel:BuildPanel()
    if isInitialized then
        NS:DebugPrint("OptionsPanel:BuildPanel — already initialized, skipping.")
        return
    end

    -- Guard: Settings API must exist
    if not Settings or not Settings.RegisterAddOnCategory then
        NS:DebugPrint("OptionsPanel:BuildPanel — Settings API not available.")
        return
    end

    ---------------------------------------------------------------------------
    -- 3.1 Create the canvas frame
    ---------------------------------------------------------------------------

    --- The main options frame rendered inside the Settings window.
    --- @type Frame
    local frame = CreateFrame("Frame", "ChromatixOptionsFrame", UIParent)
    frame.name = NS.ADDON_NAME

    ---------------------------------------------------------------------------
    -- 3.2 Layout: title and description
    ---------------------------------------------------------------------------

    --- Title text at the top of the panel.
    --- @type FontString
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["OPTIONS_TITLE"])

    --- Addon version line below the title.
    --- @type FontString
    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("v" .. NS.VERSION .. "  |cFF888888" .. NS.AUTHOR .. "|r")

    --- Description text.
    --- @type FontString
    local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
    desc:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["ADDON_DESCRIPTION"])

    ---------------------------------------------------------------------------
    -- 3.3 Utility: Create a section header
    ---------------------------------------------------------------------------

    --- Create a section header FontString.
    --- @param parent  Frame       Parent frame
    --- @param anchor  Region      Anchor region to position below
    --- @param text    string      Header text
    --- @param offsetY number|nil  Vertical offset (default -20)
    --- @return FontString         The created header
    local function CreateSectionHeader(parent, anchor, text, offsetY)
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -20)
        header:SetText(text)
        return header
    end

    ---------------------------------------------------------------------------
    -- 3.4 Utility: Create a checkbox
    ---------------------------------------------------------------------------

    --- Create a standard checkbox with label and tooltip.
    --- @param parent   Frame     Parent frame
    --- @param anchor   Region    Anchor region to position below
    --- @param label    string    Checkbox label text
    --- @param tooltip  string    Tooltip description
    --- @param getFunc  function  Returns current boolean value
    --- @param setFunc  function  Called with new boolean value
    --- @param offsetY  number|nil Vertical offset (default -8)
    --- @return CheckButton        The created checkbox
    local function CreateCheckbox(parent, anchor, label, tooltip, getFunc, setFunc, offsetY)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8)

        -- Label
        local cbText = cb.Text or _G[cb:GetName() .. "Text"]
        if cbText then
            cbText:SetText(label)
            cbText:SetFontObject("GameFontHighlight")
        end

        -- Tooltip
        cb.tooltipText = label
        cb.tooltipRequirement = tooltip

        -- State synchronization
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getFunc())
        end)
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setFunc(checked)
            NS:DebugPrint("OptionsPanel: checkbox [" .. label .. "] →", tostring(checked))
        end)

        return cb
    end

    ---------------------------------------------------------------------------
    -- 3.5 Utility: Create a dropdown (naming mode selector)
    ---------------------------------------------------------------------------

    --- Create a naming mode dropdown using UIDropDownMenu.
    --- @param parent  Frame   Parent frame
    --- @param anchor  Region  Anchor region to position below
    --- @param offsetY number|nil Vertical offset
    --- @return Frame          The dropdown frame
    local function CreateNamingDropdown(parent, anchor, offsetY)
        local dropdown = CreateFrame("Frame", "ChromatixNamingDropdown", parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -16, offsetY or -8)

        --- Label above the dropdown
        --- @type FontString
        local ddLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        ddLabel:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 2)
        ddLabel:SetText(L["OPTIONS_NAMING_MODE"])

        --- Initialize the dropdown menu entries.
        --- @param self  Frame  The dropdown frame
        --- @param level number Menu level (always 1 for this simple menu)
        local function InitDropdown(self, level)
            if not level then return end

            local currentMode = NS.NAMING_MODE.ENGLISH
            if NS.db and NS.db.global then
                currentMode = NS.db.global.namingMode or NS.NAMING_MODE.ENGLISH
            end

            -- Option: English
            local infoEN = UIDropDownMenu_CreateInfo()
            infoEN.text     = L["OPTIONS_NAMING_ENGLISH"]
            infoEN.value    = NS.NAMING_MODE.ENGLISH
            infoEN.checked  = (currentMode == NS.NAMING_MODE.ENGLISH)
            infoEN.func     = function()
                if NS.db and NS.db.global then
                    NS.db.global.namingMode = NS.NAMING_MODE.ENGLISH
                end
                UIDropDownMenu_SetText(dropdown, L["OPTIONS_NAMING_ENGLISH"])
                CloseDropDownMenus()
                NS:DebugPrint("OptionsPanel: naming mode → english")
            end
            UIDropDownMenu_AddButton(infoEN, level)

            -- Option: Localized
            local infoLoc = UIDropDownMenu_CreateInfo()
            infoLoc.text    = L["OPTIONS_NAMING_LOCALIZED"]
            infoLoc.value   = NS.NAMING_MODE.LOCALIZED
            infoLoc.checked = (currentMode == NS.NAMING_MODE.LOCALIZED)
            infoLoc.func    = function()
                if NS.db and NS.db.global then
                    NS.db.global.namingMode = NS.NAMING_MODE.LOCALIZED
                end
                UIDropDownMenu_SetText(dropdown, L["OPTIONS_NAMING_LOCALIZED"])
                CloseDropDownMenus()
                NS:DebugPrint("OptionsPanel: naming mode → localized")
            end
            UIDropDownMenu_AddButton(infoLoc, level)
        end

        UIDropDownMenu_SetWidth(dropdown, 180)
        UIDropDownMenu_Initialize(dropdown, InitDropdown)

        -- Set initial display text
        dropdown:SetScript("OnShow", function()
            local currentMode = NS.NAMING_MODE.ENGLISH
            if NS.db and NS.db.global then
                currentMode = NS.db.global.namingMode or NS.NAMING_MODE.ENGLISH
            end
            if currentMode == NS.NAMING_MODE.LOCALIZED then
                UIDropDownMenu_SetText(dropdown, L["OPTIONS_NAMING_LOCALIZED"])
            else
                UIDropDownMenu_SetText(dropdown, L["OPTIONS_NAMING_ENGLISH"])
            end
        end)

        --- Description below the dropdown
        --- @type FontString
        local ddDesc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        ddDesc:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -2)
        ddDesc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
        ddDesc:SetJustifyH("LEFT")
        ddDesc:SetText(L["OPTIONS_NAMING_DESC"])

        return ddDesc -- return the lowest element for next anchor
    end

    ---------------------------------------------------------------------------
    -- 3.6 Assemble the Panel Layout
    ---------------------------------------------------------------------------

    -- Section: General
    local sectionGeneral = CreateSectionHeader(frame, desc, L["OPTIONS_GENERAL"], -20)

    -- Naming mode dropdown
    local namingBottom = CreateNamingDropdown(frame, sectionGeneral, -12)

    -- Auto-swap checkbox
    local cbAutoSwap = CreateCheckbox(
        frame, namingBottom,
        L["OPTIONS_AUTO_SWAP"],
        L["OPTIONS_AUTO_SWAP_DESC"],
        function()
            if NS.db and NS.db.global then
                -- nil defaults to true
                return NS.db.global.autoSwap ~= false
            end
            return true
        end,
        function(checked)
            if NS.db and NS.db.global then
                NS.db.global.autoSwap = checked
            end
        end,
        -12
    )

    -- Debug mode checkbox
    local cbDebug = CreateCheckbox(
        frame, cbAutoSwap,
        L["OPTIONS_DEBUG_MODE"],
        L["OPTIONS_DEBUG_DESC"],
        function()
            if NS.db and NS.db.global then
                return NS.db.global.debugMode or false
            end
            return false
        end,
        function(checked)
            if NS.db and NS.db.global then
                NS.db.global.debugMode = checked
            end
        end
    )

    ---------------------------------------------------------------------------
    -- 3.7 Reset Button
    ---------------------------------------------------------------------------

    --- Reset button: clears character-specific settings.
    --- @type Button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(180, 26)
    resetBtn:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -24)
    resetBtn:SetText(L["OPTIONS_RESET"])

    resetBtn:SetScript("OnClick", function()
        -- Confirmation via StaticPopup
        StaticPopupDialogs["CHROMATIX_RESET_CONFIRM"] = {
            text         = L["OPTIONS_RESET_CONFIRM"],
            button1      = L["CONFIRM_YES"],
            button2      = L["CONFIRM_NO"],
            OnAccept     = function()
                local key = NS:GetCharacterKey()
                if key and NS.db and NS.db.characters then
                    NS.db.characters[key] = nil
                    NS:Print(L["OPTIONS_RESET_DONE"])
                end
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("CHROMATIX_RESET_CONFIRM")
    end)

    --- Reset description text.
    --- @type FontString
    local resetDesc = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    resetDesc:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -4)
    resetDesc:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetText(L["OPTIONS_RESET_DESC"])

    ---------------------------------------------------------------------------
    -- 3.8 Register with Settings API
    ---------------------------------------------------------------------------

    local category = Settings.RegisterCanvasLayoutCategory(frame, L["OPTIONS_TITLE"])
    if category then
        category.ID = NS.ADDON_NAME
        Settings.RegisterAddOnCategory(category)
        settingsCategory = category
        NS:DebugPrint("OptionsPanel: registered with Settings API.")
    else
        NS:DebugPrint("OptionsPanel: RegisterCanvasLayoutCategory returned nil.")
    end

    isInitialized = true
end

----------------------------------------------------------------------
-- 4. Public API
----------------------------------------------------------------------

--- Open the Chromatix settings panel in the game's Settings window.
function OptionsPanel:Open()
    if not isInitialized then
        self:BuildPanel()
    end

    if settingsCategory then
        local ok, err = pcall(Settings.OpenToCategory, settingsCategory.ID)
        if not ok then
            NS:DebugPrint("OptionsPanel:Open — Settings.OpenToCategory error:", tostring(err))
        end
    else
        NS:DebugPrint("OptionsPanel:Open — settings category not registered.")
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
    -- Panel is already built during OnInitialize; nothing extra needed.
end