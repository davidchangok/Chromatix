--[[
================================================================================
  Chromatix (幻色龙) - Modules/UIHook.lua
  Hooks into the Blizzard Equipment Manager UI (PaperDollFrame) to inject
  a "New Spec Set" (新的天赋方案) button below the existing "New Set" button.

  The injected button:
    - Matches the visual style of the native "New Set" button (green "+" icon)
    - On click: detects current spec → resolves name per naming mode →
      creates an equipment set with spec icon and current gear

  This module waits for the Blizzard PaperDollFrame to be available before
  attempting any UI modifications, ensuring safe load-order behavior.

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

--- @class UIHook
local UIHook = NS:NewModule("UIHook")
NS.UIHook    = UIHook

----------------------------------------------------------------------
-- 2. Internal State
----------------------------------------------------------------------

--- Whether the button has already been injected.
--- @type boolean
local isInjected = false

--- Reference to our custom button frame.
--- @type ChromatixSpecButton|nil
local specSetButton = nil

--- Whether CharacterFrame:OnShow has been hooked (prevents duplicate hooks).
--- @type boolean
local isCharFrameHooked = false

--- Whether EquipmentManagerPane:OnShow has been hooked (prevents duplicate hooks).
--- @type boolean
local isEqPaneHooked = false

----------------------------------------------------------------------
-- 3. Button Factory
----------------------------------------------------------------------

--- @class ChromatixSpecButton : Button
--- @field bgNormal Texture
--- @field bgPushed Texture
--- @field icon Texture
--- @field label FontString

--- Create the "New Spec Set" button styled to match the native
--- "New Set" (新的方案) button in the Equipment Manager pane.
---
--- The button is parented to the Equipment Manager pane and anchored
--- below the native "New Set" button (GearManagerPane.NewSetButton
--- or equivalent).
---
--- @param parentFrame Frame  The Equipment Manager pane frame
--- @param anchorBelow Frame  The native "New Set" button to anchor below
--- @return ChromatixSpecButton             The created button
local function CreateSpecSetButton(parentFrame, anchorBelow)
    --- Main button frame.
    --- @type ChromatixSpecButton
    local btn = CreateFrame("Button", "ChromatixNewSpecSetButton", parentFrame)
    btn:SetSize(anchorBelow:GetWidth(), anchorBelow:GetHeight())
    btn:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, -2)

    ---------------------------------------------------------------------------
    -- 3.1 Background / Highlight Textures (mimic native button style)
    ---------------------------------------------------------------------------

    --- Normal background: semi-transparent dark.
    --- @type Texture
    local bgNormal = btn:CreateTexture(nil, "BACKGROUND")
    bgNormal:SetAllPoints()
    bgNormal:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    btn.bgNormal = bgNormal

    --- Highlight background: lighter on mouseover.
    --- @type Texture
    local bgHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
    bgHighlight:SetAllPoints()
    bgHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    --- Pushed (pressed) background.
    --- @type Texture
    local bgPushed = btn:CreateTexture(nil, "BACKGROUND")
    bgPushed:SetAllPoints()
    bgPushed:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    bgPushed:Hide()
    btn.bgPushed = bgPushed

    ---------------------------------------------------------------------------
    -- 3.2 Green "+" Icon (matching the native button)
    ---------------------------------------------------------------------------

    --- The green plus icon on the left side of the button.
    --- Uses the same atlas/texture as the native "New Set" button.
    --- @type Texture
    local iconTexture = btn:CreateTexture(nil, "ARTWORK")
    iconTexture:SetSize(30, 30)
    iconTexture:SetPoint("LEFT", btn, "LEFT", 7, 0)

    -- Attempt to use the atlas used by the native button.
    -- Fallback: use the common green "+" icon texture.
    local atlasSet = false
    if iconTexture.SetAtlas then
        local ok = pcall(function()
            iconTexture:SetAtlas("communities-icon-addgroupplus")
        end)
        if ok then
            atlasSet = true
        end
    end
    if not atlasSet then
        -- Fallback: bright green circle with "+" feel via color tinting
        iconTexture:SetTexture(132284) -- Interface\\Icons\\Spell_ChargePositive
        iconTexture:SetVertexColor(0.2, 0.9, 0.2, 1.0)
    end
    btn.icon = iconTexture

    ---------------------------------------------------------------------------
    -- 3.3 Label Text
    ---------------------------------------------------------------------------

    --- Button label text (e.g. "New Spec Set" / "新的天赋方案").
    --- @type FontString
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", iconTexture, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(L["UI_NEW_SPEC_SET"])
    label:SetTextColor(0.2, 0.9, 0.2, 1.0)
    btn.label = label

    ---------------------------------------------------------------------------
    -- 3.4 Pressed State Visual Feedback
    ---------------------------------------------------------------------------

    btn:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            self.bgNormal:Hide()
            self.bgPushed:Show()
            self.label:SetPoint("LEFT", self.icon, "RIGHT", 7, -1)
        end
    end)

    btn:SetScript("OnMouseUp", function(self)
        self.bgPushed:Hide()
        self.bgNormal:Show()
        self.label:SetPoint("LEFT", self.icon, "RIGHT", 6, 0)
    end)

    ---------------------------------------------------------------------------
    -- 3.5 Tooltip
    ---------------------------------------------------------------------------

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_NEW_SPEC_SET"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_NEW_SPEC_SET_TOOLTIP"], nil, nil, nil, true)

        -- Show current spec info in tooltip for context
        local specMod = NS:GetModule("SpecManager")
        if specMod then
            specMod:RefreshSpecData()
            local info = specMod:GetSpecInfo()
            if info and info.specID then
                local resolvedName = specMod:GetResolvedSpecName() or "?"
                local iconStr = Utils:GetIconString(info.iconID, 14)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    iconStr .. " " .. resolvedName,
                    0.5, 0.8, 1.0
                )
            end
        end

        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ---------------------------------------------------------------------------
    -- 3.6 Click Handler
    ---------------------------------------------------------------------------

    btn:SetScript("OnClick", function()
        -- Combat guard
        if InCombatLockdown() then
            NS:Print(L["UI_BUTTON_CLICK_COMBAT"])
            return
        end

        NS:DebugPrint("UIHook: 'New Spec Set' button clicked.")

        local equipMod = NS:GetModule("EquipmentManager")
        if not equipMod then
            NS:Print(Utils:SafeFormat(L["ERR_MODULE_NOT_FOUND"], "EquipmentManager"))
            return
        end

        local success, message = equipMod:CreateSpecSet()
        if not success and message then
            NS:Print(message)
        end

        -- Refresh the parent equipment list if possible
        local pane = (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) or _G["PaperDollEquipmentManagerPane"]
        if pane and type(pane.Update) == "function" then
            local ok, err = pcall(pane.Update, pane)
            if not ok then
                NS:DebugPrint("UIHook: failed to refresh equipment pane:", tostring(err))
            end
        end
    end)

    NS:DebugPrint("UIHook: CreateSpecSetButton — button created and configured.")
    return btn
end

----------------------------------------------------------------------
-- 4. Injection Logic
----------------------------------------------------------------------

--- Attempt to inject our custom button into the Equipment Manager pane.
---
--- WoW 12.0+: The pane is accessed via PaperDollFrame.EquipmentManagerPane
--- and we anchor next to the EquipSet button.
---
--- @return boolean  true if injection succeeded
local function TryInjectButton()
    if isInjected then
        return true
    end

    ---------------------------------------------------------------------------
    -- 4.1 Locate the Equipment Manager Pane (WoW 12.0+ structure)
    ---------------------------------------------------------------------------

    --- @type Frame|nil
    local eqPane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if not eqPane then
        NS:DebugPrint("UIHook:TryInjectButton — PaperDollFrame.EquipmentManagerPane not found.")
        return false
    end

    ---------------------------------------------------------------------------
    -- 4.2 Find the "New Set" button in ScrollTarget (last child)
    ---------------------------------------------------------------------------

    local scrollTarget = eqPane.ScrollBox and eqPane.ScrollBox.ScrollTarget
    if not scrollTarget then
        NS:DebugPrint("UIHook:TryInjectButton — ScrollTarget not found.")
        specSetButton = CreateSpecSetButton(eqPane, eqPane)
        specSetButton:ClearAllPoints()
        specSetButton:SetSize(169, 44)
        specSetButton:SetPoint("BOTTOMLEFT", eqPane, "BOTTOMLEFT", 4, 4)
        isInjected = true
        return true
    end

    ---------------------------------------------------------------------------
    -- 4.3 Create button and update position/size dynamically
    ---------------------------------------------------------------------------

    specSetButton = CreateSpecSetButton(scrollTarget, scrollTarget)

    -- Function to find "New Set" button and match its size/position
    local function UpdateButtonPosition()
        local children = {scrollTarget:GetChildren()}
        local newSetBtn = nil
        for i = #children, 1, -1 do
            local child = children[i]
            if child ~= specSetButton and child:IsShown() then
                newSetBtn = child
                break
            end
        end
        if newSetBtn then
            -- Match the system button's size dynamically
            local width, height = newSetBtn:GetSize()
            specSetButton:SetSize(width, height)
            specSetButton:ClearAllPoints()
            specSetButton:SetPoint("TOPLEFT", newSetBtn, "BOTTOMLEFT", 0, -2)
            NS:DebugPrint("UIHook: button size updated to", width, "x", height)
        end
    end

    -- Initial positioning
    UpdateButtonPosition()

    -- Hook ScrollTarget to reposition when children change
    scrollTarget:HookScript("OnShow", UpdateButtonPosition)
    if eqPane.ScrollBox.Update then
        hooksecurefunc(eqPane.ScrollBox, "Update", function()
            Utils:After(0.1, UpdateButtonPosition)
        end)
    end

    isInjected = true
    NS:DebugPrint("UIHook:TryInjectButton — injection successful below New Set button.")
    return true
end

----------------------------------------------------------------------
-- 5. Deferred Injection via Frame Monitoring
----------------------------------------------------------------------

--- The PaperDollFrame (and its Equipment Manager pane) is loaded
--- on demand. We hook into it via multiple strategies:
---   a) Direct check on PLAYER_ENTERING_WORLD
---   b) Hook PaperDollFrame:Show() if available
---   c) Poll briefly with C_Timer if neither is ready yet

--- Strategy A: Direct attempt + hooking CharacterFrame events.
local function SetupInjectionHooks()
    -- WoW 12.0+: pane is accessed via PaperDollFrame.EquipmentManagerPane
    local eqPane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane

    -- If the pane already exists (e.g. /reload), inject immediately
    if eqPane then
        TryInjectButton()
    end

    -- Hook CharacterFrame:Show (or OnShow) to catch when the panel opens
    if CharacterFrame and not isCharFrameHooked then
        CharacterFrame:HookScript("OnShow", function()
            if not isInjected then
                -- Small delay to ensure children are fully initialized
                Utils:After(0.1, function()
                    TryInjectButton()
                end)
            end
        end)
        isCharFrameHooked = true
        NS:DebugPrint("UIHook: hooked CharacterFrame:OnShow.")
    end

    -- Hook the Equipment Manager pane's OnShow specifically
    eqPane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if eqPane and not isEqPaneHooked then
        eqPane:HookScript("OnShow", function()
            if not isInjected then
                TryInjectButton()
            end
            -- Ensure button visibility matches pane visibility
            if specSetButton then
                specSetButton:Show()
            end
        end)
        isEqPaneHooked = true
        NS:DebugPrint("UIHook: hooked PaperDollFrame.EquipmentManagerPane:OnShow.")
    end
end

--- Strategy B: Wait for Blizzard_CharacterUI addon to load (LoD addon).
--- Some UI addons/panels are loaded on demand.
--- @param event     string  "ADDON_LOADED"
--- @param addonName string  Name of the addon that just loaded
local function OnAddonLoaded(event, addonName)
    -- The character panel lives in Blizzard_CharacterUI (or Blizzard_GearManager)
    if addonName == "Blizzard_CharacterUI"
        or addonName == "Blizzard_GearManager"
        or addonName == "Blizzard_PaperDollUI" then

        NS:DebugPrint("UIHook: detected load of", addonName, "— attempting injection.")
        Utils:After(0.2, function()
            SetupInjectionHooks()
        end)
    end
end

--- Strategy C: Polling fallback (runs once with a short timer).
--- Only used if neither Strategy A nor B triggers within a reasonable window.
local function ScheduleFallbackInjection()
    local attempts = 0
    local maxAttempts = 10
    local interval = 0.5

    local function PollForPane()
        attempts = attempts + 1
        if isInjected then
            NS:DebugPrint("UIHook: fallback polling — already injected, stopping.")
            return
        end
        if (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) or _G["PaperDollEquipmentManagerPane"] then
            NS:DebugPrint("UIHook: fallback polling — pane found on attempt", attempts)
            SetupInjectionHooks()
            return
        end
        if attempts < maxAttempts then
            Utils:After(interval, PollForPane)
        else
            NS:DebugPrint("UIHook: fallback polling — pane not found after", maxAttempts, "attempts.")
        end
    end

    Utils:After(1.0, PollForPane)
end

----------------------------------------------------------------------
-- 6. Button Visibility Management
----------------------------------------------------------------------

--- Show or hide the injected button. Can be called externally if
--- the Equipment Manager pane visibility changes.
--- @param visible boolean  Whether to show the button
function UIHook:SetButtonVisible(visible)
    if specSetButton then
        if visible then
            specSetButton:Show()
        else
            specSetButton:Hide()
        end
    end
end

--- Refresh the button label text (e.g. after locale settings change).
function UIHook:RefreshButtonLabel()
    if specSetButton and specSetButton.label then
        specSetButton.label:SetText(L["UI_NEW_SPEC_SET"])
        NS:DebugPrint("UIHook:RefreshButtonLabel — label updated.")
    end
end

----------------------------------------------------------------------
-- 7. Module Lifecycle
----------------------------------------------------------------------

--- Called by EventManager when ADDON_LOADED fires for Chromatix.
function UIHook:OnInitialize()
    NS:DebugPrint("UIHook:OnInitialize")

    -- Register for other addon loads to catch Blizzard_CharacterUI
    NS.EventManager:RegisterEvent("ADDON_LOADED", OnAddonLoaded, "UIHook_AddonLoaded")
end

--- Called by EventManager on PLAYER_ENTERING_WORLD.
function UIHook:OnEnable()
    NS:DebugPrint("UIHook:OnEnable")

    -- Attempt immediate setup
    SetupInjectionHooks()

    -- Schedule fallback polling in case the pane is not yet loaded
    if not isInjected then
        ScheduleFallbackInjection()
    end
end