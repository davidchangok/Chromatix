--[[
================================================================================
  Chromatix (幻色龙) - Modules/EquipmentManager.lua
  Equipment set management: creation, lookup, and automatic swapping
  based on the player's active specialization.

  Key responsibilities:
    - Find existing equipment sets by name
    - Create new sets using current gear + spec icon
    - Automatically equip the linked set on spec change
    - Defer all protected actions until out of combat

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

--- @class EquipmentManager
local EquipmentManager = NS:NewModule("EquipmentManager")
NS.EquipmentManager    = EquipmentManager

----------------------------------------------------------------------
-- 2. Constants
----------------------------------------------------------------------

--- Maximum number of equipment sets allowed by the game client.
--- As of Interface 120000, the limit is 10.
--- @type number
local MAX_EQUIPMENT_SETS = 10

----------------------------------------------------------------------
-- 3. Equipment Set Query Helpers
----------------------------------------------------------------------

--- Retrieve a list of all equipment set IDs known to the client.
--- Wraps C_EquipmentSet.GetEquipmentSetIDs() with safety checks.
--- @return table  Array of numeric set IDs, or empty table on failure
function EquipmentManager:GetAllSetIDs()
    local ok, ids = Utils:SafeCall(C_EquipmentSet.GetEquipmentSetIDs)
    if not ok or type(ids) ~= "table" then
        NS:DebugPrint("EquipmentManager:GetAllSetIDs — API call failed or unexpected return.")
        return {}
    end
    return ids
end

--- Get the total number of existing equipment sets.
--- @return number  Count of equipment sets
function EquipmentManager:GetSetCount()
    return #self:GetAllSetIDs()
end

--- Check whether the maximum set limit has been reached.
--- @return boolean  true if no more sets can be created
function EquipmentManager:IsAtMaxSets()
    return self:GetSetCount() >= MAX_EQUIPMENT_SETS
end

--- Retrieve equipment set info by its numeric set ID.
--- @param setID number  Equipment set ID
--- @return table|nil    Info table { name, iconID, setID, isEquipped } or nil
function EquipmentManager:GetSetInfoByID(setID)
    if type(setID) ~= "number" then
        NS:DebugPrint("EquipmentManager:GetSetInfoByID — invalid setID type.")
        return nil
    end

    local ok, name, iconFileID, resultSetID, isEquipped, numItems,
          numEquipped, numInInventory, numLost, numIgnored =
          Utils:SafeCall(C_EquipmentSet.GetEquipmentSetInfo, setID)

    if not ok or not name then
        NS:DebugPrint("EquipmentManager:GetSetInfoByID — failed for setID:", setID)
        return nil
    end

    return {
        name           = name,
        iconID         = iconFileID,
        setID          = resultSetID or setID,
        isEquipped     = isEquipped or false,
        numItems       = numItems or 0,
        numEquipped    = numEquipped or 0,
        numInInventory = numInInventory or 0,
        numLost        = numLost or 0,
        numIgnored     = numIgnored or 0,
    }
end

--- Find an equipment set by its exact name.
--- @param targetName string  The set name to search for
--- @return table|nil         Info table if found, nil otherwise
function EquipmentManager:FindSetByName(targetName)
    if Utils:IsBlank(targetName) then
        return nil
    end

    local ids = self:GetAllSetIDs()
    for _, setID in ipairs(ids) do
        local info = self:GetSetInfoByID(setID)
        if info and info.name == targetName then
            return info
        end
    end

    return nil
end

--- Check whether an equipment set with the given name exists.
--- @param name string  Set name
--- @return boolean     true if a set with this name exists
function EquipmentManager:SetExists(name)
    return self:FindSetByName(name) ~= nil
end

----------------------------------------------------------------------
-- 4. Equipment Set Creation
----------------------------------------------------------------------

--- Create a new equipment set using the player's current gear.
--- The set is named according to the user's naming preference and
--- uses the current spec icon.
---
--- IMPORTANT: This calls C_EquipmentSet.CreateEquipmentSet(), which
--- is a protected function in some contexts. Always check combat state.
---
--- @param name   string      Desired set name
--- @param iconID number|nil  Texture file ID for the set icon (defaults to spec icon)
--- @return boolean           true if creation succeeded
--- @return string            Status message (success or error description)
function EquipmentManager:CreateSet(name, iconID)
    -- Validate name
    if Utils:IsBlank(name) then
        NS:DebugPrint("EquipmentManager:CreateSet — blank name provided.")
        return false, Utils:SafeFormat(L["ERR_INVALID_ARG"], "CreateSet")
    end

    -- Check combat lockdown
    if InCombatLockdown() then
        NS:DebugPrint("EquipmentManager:CreateSet — blocked by combat lockdown.")
        return false, L["ERR_PROTECTED_ACTION"]
    end

    -- Check max sets limit
    if self:IsAtMaxSets() then
        NS:DebugPrint("EquipmentManager:CreateSet — max sets reached.")
        return false, L["EQUIP_MAX_SETS"]
    end

    -- Check for duplicate name
    if self:SetExists(name) then
        NS:DebugPrint("EquipmentManager:CreateSet — set already exists:", name)
        return false, Utils:SafeFormat(L["EQUIP_SET_ALREADY_EXISTS"], name)
    end

    -- Default icon: use spec icon from SpecManager
    if type(iconID) ~= "number" or iconID <= 0 then
        local specMod = NS:GetModule("SpecManager")
        if specMod then
            iconID = specMod:GetSpecIcon()
        end
    end

    -- Final fallback icon (question mark)
    if type(iconID) ~= "number" or iconID <= 0 then
        iconID = 134400 -- INV_Misc_QuestionMark
    end

    -- Attempt creation
    local ok, err = Utils:SafeCall(C_EquipmentSet.CreateEquipmentSet, name, iconID)
    if not ok then
        NS:DebugPrint("EquipmentManager:CreateSet — API error:", tostring(err))
        return false, Utils:SafeFormat(L["EQUIP_SET_CREATE_FAILED"], name)
    end

    -- Verify creation by looking up the new set
    -- Small delay may be needed; we verify synchronously first
    local created = self:FindSetByName(name)
    if created then
        NS:DebugPrint("EquipmentManager:CreateSet — success:", name, "icon:", iconID)
        local iconStr = Utils:GetIconString(iconID)
        NS:Print(Utils:SafeFormat(L["EQUIP_SET_CREATED"], name, iconStr))
        return true, Utils:SafeFormat(L["EQUIP_SET_CREATED"], name, iconStr)
    end

    -- Rare case: API did not error but set was not found
    NS:DebugPrint("EquipmentManager:CreateSet — creation returned OK but set not found.")
    return false, Utils:SafeFormat(L["EQUIP_SET_CREATE_FAILED"], name)
end

----------------------------------------------------------------------
-- 5. Equipment Set Activation
----------------------------------------------------------------------

--- Equip (use) an equipment set by its name.
--- Protected action — will be deferred if in combat.
--- @param name string  The equipment set name to equip
--- @return boolean     true if equip was initiated (or deferred)
function EquipmentManager:EquipSetByName(name)
    if Utils:IsBlank(name) then
        NS:DebugPrint("EquipmentManager:EquipSetByName — blank name.")
        return false
    end

    local info = self:FindSetByName(name)
    if not info then
        NS:Print(Utils:SafeFormat(L["EQUIP_SET_NOT_FOUND"], name))
        return false
    end

    -- Already equipped — no action needed
    if info.isEquipped then
        NS:DebugPrint("EquipmentManager:EquipSetByName — set already equipped:", name)
        return true
    end

    -- Combat check: defer if locked
    if InCombatLockdown() then
        NS:Print(L["EQUIP_COMBAT_DEFERRED"])
        NS.EventManager:DeferUntilOutOfCombat(function()
            NS:Print(L["EQUIP_COMBAT_RESUMED"])
            self:EquipSetByName(name)
        end)
        return true -- deferred, not failed
    end

    -- Execute the equip action
    NS:Print(Utils:SafeFormat(L["EQUIP_SET_FOUND"], name))

    local ok, err = Utils:SafeCall(C_EquipmentSet.UseEquipmentSet, info.setID)
    if not ok then
        NS:DebugPrint("EquipmentManager:EquipSetByName — UseEquipmentSet failed:", tostring(err))
        NS:Print(L["ERR_EQUIPMENT_API"])
        return false
    end

    NS:Print(Utils:SafeFormat(L["EQUIP_SET_EQUIPPED"], name))
    return true
end

----------------------------------------------------------------------
-- 6. Spec-Based Automatic Swap
----------------------------------------------------------------------

--- Determine the expected set name for the current spec, based on
--- the user's naming mode, and equip it if it exists.
--- @return boolean  true if a set was found and equip was initiated
function EquipmentManager:SwapToCurrentSpec()
    local specMod = NS:GetModule("SpecManager")
    if not specMod then
        NS:DebugPrint("EquipmentManager:SwapToCurrentSpec — SpecManager not found.")
        return false
    end

    local specName = specMod:GetResolvedSpecName()
    if not specName then
        NS:Print(L["ERR_NO_SPEC"])
        return false
    end

    NS:DebugPrint("EquipmentManager:SwapToCurrentSpec — looking for set:", specName)

    -- Try the resolved name first
    if self:SetExists(specName) then
        return self:EquipSetByName(specName)
    end

    -- Fallback: try the alternative naming mode
    local altEnglish, altLocal = specMod:GetBothNames()
    local altName = (specName == altEnglish) and altLocal or altEnglish

    if altName and self:SetExists(altName) then
        NS:DebugPrint("EquipmentManager:SwapToCurrentSpec — fallback match:", altName)
        return self:EquipSetByName(altName)
    end

    -- No matching set found
    NS:Print(Utils:SafeFormat(L["EQUIP_SET_NOT_FOUND"], specName))
    return false
end

--- Called by SpecManager when the player's spec changes.
--- Checks user preference and triggers auto-swap if enabled.
function EquipmentManager:OnSpecChanged()
    NS:DebugPrint("EquipmentManager:OnSpecChanged triggered.")

    -- Check if auto-swap is enabled (default: true)
    local autoSwap = true
    if NS.db and NS.db.global then
        -- autoSwap is nil by default (not in DB_DEFAULTS), treat nil as true
        if NS.db.global.autoSwap == false then
            autoSwap = false
        end
    end

    if not autoSwap then
        NS:DebugPrint("EquipmentManager:OnSpecChanged — auto-swap is disabled.")
        return
    end

    self:SwapToCurrentSpec()
end

----------------------------------------------------------------------
-- 7. One-Click Spec Set Creation
----------------------------------------------------------------------

--- Create a new equipment set based on the player's current spec.
--- Designed to be called from the UIHook "New Spec Set" button.
---
--- Workflow:
---   1. Query current spec (refresh data)
---   2. Resolve name based on naming mode
---   3. Check for duplicates
---   4. Create set with spec icon and current equipped gear
---
--- @return boolean  true if set was created successfully
--- @return string   Status/error message
function EquipmentManager:CreateSpecSet()
    -- Refresh spec data to ensure accuracy
    local specMod = NS:GetModule("SpecManager")
    if not specMod then
        return false, L["ERR_MODULE_NOT_FOUND"]:format("SpecManager")
    end

    local refreshOK = specMod:RefreshSpecData()
    if not refreshOK then
        return false, L["ERR_NO_SPEC"]
    end

    local specName = specMod:GetResolvedSpecName()
    if not specName or Utils:IsBlank(specName) then
        return false, L["ERR_NO_SPEC"]
    end

    local iconID = specMod:GetSpecIcon()

    NS:DebugPrint("EquipmentManager:CreateSpecSet — name:", specName, "icon:", tostring(iconID))

    -- Delegate to CreateSet
    local success, message = self:CreateSet(specName, iconID)

    if success then
        -- Record the mapping in character DB
        local charDB = NS:GetCharacterDB()
        local specIndex = specMod:GetSpecIndex()
        if charDB and specIndex then
            charDB.specSets[specIndex] = specName
            NS:DebugPrint("EquipmentManager:CreateSpecSet — saved mapping: specIndex",
                specIndex, "→", specName)
        end
    end

    return success, message
end

----------------------------------------------------------------------
-- 8. Linked Set Query
----------------------------------------------------------------------

--- Get the equipment set name currently linked to the active spec
--- in the character's DB.
--- @return string|nil  Set name, or nil if no mapping exists
function EquipmentManager:GetLinkedSetName()
    local specMod = NS:GetModule("SpecManager")
    if not specMod then
        return nil
    end

    local specIndex = specMod:GetSpecIndex()
    if not specIndex then
        return nil
    end

    local charDB = NS:GetCharacterDB()
    if not charDB or not charDB.specSets then
        return nil
    end

    return charDB.specSets[specIndex]
end

----------------------------------------------------------------------
-- 9. Save / Update Existing Set
----------------------------------------------------------------------

--- Save (overwrite) an existing equipment set with the player's
--- current gear. The set must already exist.
--- @param name string  Set name to save/update
--- @return boolean     true if save succeeded
function EquipmentManager:SaveSet(name)
    if Utils:IsBlank(name) then
        return false
    end

    if InCombatLockdown() then
        NS:Print(L["ERR_PROTECTED_ACTION"])
        return false
    end

    local info = self:FindSetByName(name)
    if not info then
        NS:DebugPrint("EquipmentManager:SaveSet — set not found:", name)
        return false
    end

    local ok, err = Utils:SafeCall(
        C_EquipmentSet.SaveEquipmentSet, info.setID, info.iconID
    )

    if not ok then
        NS:DebugPrint("EquipmentManager:SaveSet — SaveEquipmentSet failed:", tostring(err))
        return false
    end

    NS:DebugPrint("EquipmentManager:SaveSet — set saved:", name)
    return true
end

----------------------------------------------------------------------
-- 10. Module Lifecycle
----------------------------------------------------------------------

--- Called by EventManager when ADDON_LOADED fires.
function EquipmentManager:OnInitialize()
    NS:DebugPrint("EquipmentManager:OnInitialize")
end

--- Called by EventManager on PLAYER_ENTERING_WORLD.
--- Performs initial gear check if auto-swap is enabled.
function EquipmentManager:OnEnable()
    NS:DebugPrint("EquipmentManager:OnEnable")
    -- Intentionally do NOT auto-swap on login/reload to avoid
    -- unexpected gear changes. The user triggers via spec change
    -- or manual /chromatix swap command.
end