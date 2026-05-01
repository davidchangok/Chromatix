--[[
================================================================================
  Chromatix (幻色龙) - Modules/SpecManager.lua
  Specialization detection, tracking, and name resolution.
  Listens to PLAYER_SPECIALIZATION_CHANGED and provides a clean API
  for other modules to query current spec info.

  Author : David W Zhang
  Version: 1.1
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

--- @class SpecManager
local SpecManager = NS:NewModule("SpecManager")
NS.SpecManager    = SpecManager

----------------------------------------------------------------------
-- 2. Internal State
----------------------------------------------------------------------

--- Cached specialization data, refreshed on every spec change.
--- @class SpecInfo
--- @field specIndex    number|nil  Active spec index (1-4)
--- @field specID       number|nil  Global spec ID (e.g. 70 = Retribution)
--- @field localName    string|nil  Localized spec name from the client
--- @field englishName  string|nil  English spec name from static lookup
--- @field iconID       number|nil  Spec icon texture file ID
--- @field role         string|nil  Role token: "DAMAGER", "TANK", "HEALER"
local currentSpec = {
    specIndex   = nil,
    specID      = nil,
    localName   = nil,
    englishName = nil,
    iconID      = nil,
    role        = nil,
}

----------------------------------------------------------------------
-- 3. Spec Data Query (Core Logic)
----------------------------------------------------------------------

--- Query the WoW API for the player's current specialization and
--- populate the internal cache. All values are validated before storage.
--- @return boolean  true if spec data was successfully retrieved
function SpecManager:RefreshSpecData()
    -- GetSpecialization() returns nil if no spec is selected (e.g. low level)
    local specIndex = GetSpecialization()
    if not specIndex or type(specIndex) ~= "number" or specIndex < 1 then
        NS:DebugPrint("SpecManager:RefreshSpecData — no active specialization.")
        self:ClearCache()
        return false
    end

    -- GetSpecializationInfo(specIndex)
    -- Returns: id, name, description, icon, role, primaryStat
    local ok, specID, localName, _, iconID, role = Utils:SafeCall(
        GetSpecializationInfo, specIndex
    )

    if not ok or not specID then
        NS:DebugPrint("SpecManager:RefreshSpecData — GetSpecializationInfo failed.")
        self:ClearCache()
        return false
    end

    -- Validate types defensively
    if type(specID) ~= "number" then
        NS:DebugPrint("SpecManager:RefreshSpecData — unexpected specID type:", type(specID))
        self:ClearCache()
        return false
    end

    -- Resolve English name using Utils (dynamic with fallback)
    local englishName = Utils:GetEnglishSpecName(specID)
    if not englishName then
        -- Fallback: use localized name if English name unavailable
        NS:DebugPrint("SpecManager:RefreshSpecData — no English mapping for specID:", specID)
        englishName = localName and tostring(localName) or "Unknown"
    end

    -- Store into cache
    currentSpec.specIndex   = specIndex
    currentSpec.specID      = specID
    currentSpec.localName   = localName and tostring(localName) or ""
    currentSpec.englishName = englishName
    currentSpec.iconID      = (type(iconID) == "number") and iconID or nil
    currentSpec.role        = (type(role) == "string") and role or nil

    NS:DebugPrint("SpecManager: cached spec —",
        "index:", currentSpec.specIndex,
        "id:", currentSpec.specID,
        "local:", currentSpec.localName,
        "en:", currentSpec.englishName,
        "icon:", tostring(currentSpec.iconID),
        "role:", tostring(currentSpec.role))

    return true
end

--- Clear the internal spec cache (used when no spec is active).
function SpecManager:ClearCache()
    currentSpec.specIndex   = nil
    currentSpec.specID      = nil
    currentSpec.localName   = nil
    currentSpec.englishName = nil
    currentSpec.iconID      = nil
    currentSpec.role        = nil
end

----------------------------------------------------------------------
-- 4. Public Accessors
----------------------------------------------------------------------

--- Get the full cached spec info table (shallow copy for safety).
--- @return SpecInfo  A copy of the current spec data
function SpecManager:GetSpecInfo()
    return Utils:ShallowCopy(currentSpec)
end

--- Get the active spec index (1-4), or nil.
--- @return number|nil
function SpecManager:GetSpecIndex()
    return currentSpec.specIndex
end

--- Get the global spec ID (e.g. 70 for Retribution), or nil.
--- @return number|nil
function SpecManager:GetSpecID()
    return currentSpec.specID
end

--- Get the spec icon texture ID, or nil.
--- @return number|nil
function SpecManager:GetSpecIcon()
    return currentSpec.iconID
end

--- Get the spec role token ("DAMAGER", "TANK", "HEALER"), or nil.
--- @return string|nil
function SpecManager:GetRole()
    return currentSpec.role
end

----------------------------------------------------------------------
-- 5. Spec Name Resolution
----------------------------------------------------------------------

--- Resolve the spec name based on the user's chosen naming mode.
--- @param overrideMode string|nil  Optional: force "english" or "localized"
--- @return string|nil              Resolved spec name, or nil if unavailable
function SpecManager:GetResolvedSpecName(overrideMode)
    if not currentSpec.specID then
        NS:DebugPrint("SpecManager:GetResolvedSpecName — no cached spec data.")
        return nil
    end

    local mode = overrideMode
    if not mode then
        -- Read from user settings
        if NS.db and NS.db.global then
            mode = NS.db.global.namingMode
        end
    end

    -- Default to English if mode is unrecognized
    if mode ~= NS.NAMING_MODE.LOCALIZED and mode ~= NS.NAMING_MODE.ENGLISH then
        mode = NS.NAMING_MODE.ENGLISH
    end

    if mode == NS.NAMING_MODE.LOCALIZED then
        return currentSpec.localName
    else
        return currentSpec.englishName
    end
end

--- Get both English and localized names as a pair.
--- Useful for UI display or migration between naming modes.
--- @return string|nil englishName
--- @return string|nil localName
function SpecManager:GetBothNames()
    return currentSpec.englishName, currentSpec.localName
end

----------------------------------------------------------------------
-- 6. Event Handling
----------------------------------------------------------------------

--- Handle specialization change events.
--- Refreshes spec cache and notifies EquipmentManager to swap gear.
--- @param event string  "PLAYER_SPECIALIZATION_CHANGED"
--- @param unit  string  Unit token (usually "player")
local function OnSpecChanged(event, unit)
    -- Only respond to the player's own spec change
    if unit and unit ~= "player" then
        return
    end

    NS:DebugPrint("SpecManager: PLAYER_SPECIALIZATION_CHANGED fired for player.")

    local success = SpecManager:RefreshSpecData()
    if not success then
        NS:Print(L["SPEC_QUERY_FAILED"])
        return
    end

    NS:Print(Utils:SafeFormat(L["SPEC_CHANGED"], SpecManager:GetResolvedSpecName()))

    -- Notify EquipmentManager to auto-swap if enabled
    local equipMod = NS:GetModule("EquipmentManager")
    if equipMod and type(equipMod.OnSpecChanged) == "function" then
        local ok, err = pcall(equipMod.OnSpecChanged, equipMod)
        if not ok then
            NS:DebugPrint("SpecManager: error notifying EquipmentManager:", tostring(err))
        end
    end
end

----------------------------------------------------------------------
-- 7. Module Lifecycle
----------------------------------------------------------------------

--- Called by EventManager when ADDON_LOADED fires for Chromatix.
--- Sets up event subscriptions.
function SpecManager:OnInitialize()
    NS:DebugPrint("SpecManager:OnInitialize")
    NS.EventManager:RegisterEvent(
        "PLAYER_SPECIALIZATION_CHANGED",
        OnSpecChanged,
        "SpecManager_SpecChanged"
    )
end

--- Called by EventManager on PLAYER_ENTERING_WORLD.
--- Performs the initial spec detection.
function SpecManager:OnEnable()
    NS:DebugPrint("SpecManager:OnEnable — performing initial spec refresh.")
    local success = self:RefreshSpecData()
    if success then
        NS:DebugPrint(Utils:SafeFormat(L["SPEC_DETECTED"],
            self:GetResolvedSpecName(), self:GetSpecID()))
    else
        NS:DebugPrint("SpecManager:OnEnable — no active spec at login.")
    end
end

----------------------------------------------------------------------
-- 8. Status Report
----------------------------------------------------------------------

--- Print a human-readable status summary to the chat frame.
--- Used by the /chromatix status command.
function SpecManager:PrintStatus()
    NS:Print(L["STATUS_HEADER"])

    if not currentSpec.specIndex then
        NS:Print(L["SPEC_NONE"])
        return
    end

    -- Spec info line
    local displayName = self:GetResolvedSpecName() or "?"
    NS:Print(Utils:SafeFormat(L["STATUS_SPEC"],
        displayName,
        currentSpec.specIndex,
        currentSpec.specID))

    -- Linked equipment set (delegate to EquipmentManager)
    local equipMod = NS:GetModule("EquipmentManager")
    if equipMod and type(equipMod.GetLinkedSetName) == "function" then
        local setName = equipMod:GetLinkedSetName()
        if setName then
            NS:Print(Utils:SafeFormat(L["STATUS_LINKED_SET"], setName))
        else
            NS:Print(L["STATUS_NO_LINK"])
        end
    end

    -- Naming mode
    local modeLabel
    if NS.db and NS.db.global then
        if NS.db.global.namingMode == NS.NAMING_MODE.ENGLISH then
            modeLabel = L["OPTIONS_NAMING_ENGLISH"]
        else
            modeLabel = L["OPTIONS_NAMING_LOCALIZED"]
        end
    else
        modeLabel = "?"
    end
    NS:Print(Utils:SafeFormat(L["STATUS_NAMING_MODE"], modeLabel))

    -- Debug state
    local debugState = (NS.db and NS.db.global and NS.db.global.debugMode)
                       and L["STATUS_ON"] or L["STATUS_OFF"]
    NS:Print(Utils:SafeFormat(L["STATUS_DEBUG"], debugState))
end