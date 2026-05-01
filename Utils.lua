--[[
================================================================================
  Chromatix (幻色龙) - Utils.lua
  General-purpose utility functions shared across all modules.

  Author : David W Zhang
  Version: 1.1
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...

----------------------------------------------------------------------
-- 1. Utils Module
----------------------------------------------------------------------

--- @class ChromatixUtils
local Utils = NS:NewModule("Utils")
NS.Utils = Utils

----------------------------------------------------------------------
-- 2. Table Utilities
----------------------------------------------------------------------

--- Perform a shallow copy of a table.
--- @param src table  Source table
--- @return table     New table with copied key-value pairs
function Utils:ShallowCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = v
    end
    return copy
end

--- Perform a deep copy of a table (recursive).
--- @param src table  Source table
--- @return table     Deep-cloned table
function Utils:DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = self:DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--- Count the number of entries in a hash-style table.
--- @param tbl table  Target table
--- @return number    Number of key-value pairs
function Utils:TableCount(tbl)
    if type(tbl) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

----------------------------------------------------------------------
-- 3. String Utilities
----------------------------------------------------------------------

--- Trim leading and trailing whitespace from a string.
--- @param str string  Input string
--- @return string     Trimmed string
function Utils:Trim(str)
    if type(str) ~= "string" then
        return ""
    end
    return str:match("^%s*(.-)%s*$") or ""
end

--- Check if a string is nil, empty, or whitespace-only.
--- @param str string|nil  Input string
--- @return boolean        true if string is blank
function Utils:IsBlank(str)
    if type(str) ~= "string" then
        return true
    end
    return self:Trim(str) == ""
end

--- Safely format a string, catching errors from mismatched tokens.
--- @param fmt string  Format pattern
--- @param ... any     Values to substitute
--- @return string     Formatted string, or the raw format on error
function Utils:SafeFormat(fmt, ...)
    if type(fmt) ~= "string" then
        return tostring(fmt)
    end
    local ok, result = pcall(string.format, fmt, ...)
    if ok then
        return result
    end
    return fmt
end

----------------------------------------------------------------------
-- 4. Safe API Call Wrapper
----------------------------------------------------------------------

--- Safely call a WoW API function and return results.
--- Uses a varargs handler to preserve nil holes in return values,
--- avoiding the fragile {pcall()} + table.remove + unpack pattern.
--- @param func    function  The API function to call
--- @param ...     any       Arguments to pass
--- @return boolean success  Whether the call succeeded
--- @return any    ...       Return values from the API, or error message
function Utils:SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, "Not a function"
    end
    --- Internal handler that receives pcall results as varargs,
    --- preserving nil holes without table intermediary.
    --- @param ok  boolean  pcall success flag
    --- @param ... any      Return values or error message
    local function handler(ok, ...)
        if not ok then
            local errMsg = ... or "Unknown error"
            return false, errMsg
        end
        return true, ...
    end
    return handler(pcall(func, ...))
end

----------------------------------------------------------------------
-- 5. Specialization Name API (Dynamic with fallback)
----------------------------------------------------------------------

--- Cache for English spec names (populated dynamically or from fallback)
local specEnglishNameCache = {}

--- Fallback English names (used when API unavailable or returns nil)
local ENGLISH_FALLBACK = {
    -- Death Knight
    [250] = "Blood", [251] = "Frost", [252] = "Unholy",
    -- Demon Hunter
    [577] = "Havoc", [581] = "Vengeance", [1480] = "Devourer",
    -- Druid
    [102] = "Balance", [103] = "Feral", [104] = "Guardian", [105] = "Restoration",
    -- Evoker
    [1467] = "Devastation", [1468] = "Preservation", [1473] = "Augmentation",
    -- Hunter
    [253] = "Beast Mastery", [254] = "Marksmanship", [255] = "Survival",
    -- Mage
    [62] = "Arcane", [63] = "Fire", [64] = "Frost",
    -- Monk
    [268] = "Brewmaster", [269] = "Windwalker", [270] = "Mistweaver",
    -- Paladin
    [65] = "Holy", [66] = "Protection", [70] = "Retribution",
    -- Priest
    [256] = "Discipline", [257] = "Holy", [258] = "Shadow",
    -- Rogue
    [259] = "Assassination", [260] = "Outlaw", [261] = "Subtlety",
    -- Shaman
    [262] = "Elemental", [263] = "Enhancement", [264] = "Restoration",
    -- Warlock
    [265] = "Affliction", [266] = "Demonology", [267] = "Destruction",
    -- Warrior
    [71] = "Arms", [72] = "Fury", [73] = "Protection",
}

--- Get specialization info safely using WoW API
--- @param specID number  Global specialization ID
--- @return string|nil name  Localized spec name
--- @return number|nil iconID  Spec icon texture ID
--- @return string|nil role  Role token (DAMAGER, TANK, HEALER)
function Utils:GetSpecInfoByID(specID)
    if type(specID) ~= "number" then
        return nil, nil, nil
    end

    -- Try C_SpecializationInfo API first (protected call)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID then
        local ok, info = self:SafeCall(C_SpecializationInfo.GetSpecializationInfoByID, specID)
        if ok and info then
            return info.name, info.iconID, info.role
        end
    end

    -- Fallback to GetSpecializationInfoByID
    if GetSpecializationInfoByID then
        local ok, id, name, desc, iconID, role = self:SafeCall(GetSpecializationInfoByID, specID)
        if ok and name then
            return name, iconID, role
        end
    end

    return nil, nil, nil
end

--- Get English specialization name for a given specID
--- Uses cache, then attempts API query, then falls back to static table
--- @param specID number  Global specialization ID
--- @return string|nil    English spec name
function Utils:GetEnglishSpecName(specID)
    if type(specID) ~= "number" then
        return nil
    end

    -- Check cache first
    if specEnglishNameCache[specID] then
        return specEnglishNameCache[specID]
    end

    -- Use fallback table (English names are static, API returns localized)
    local englishName = ENGLISH_FALLBACK[specID]
    if englishName then
        specEnglishNameCache[specID] = englishName
        return englishName
    end

    -- Last resort: get localized name
    local localName = self:GetSpecInfoByID(specID)
    return localName
end

--- Get localized specialization name for a given specID
--- @param specID number  Global specialization ID
--- @return string|nil    Localized spec name
function Utils:GetLocalizedSpecName(specID)
    if type(specID) ~= "number" then
        return nil
    end

    local name = self:GetSpecInfoByID(specID)
    return name
end

-- Keep SPEC_ID_TO_ENGLISH for backward compatibility (shallow copy)
Utils.SPEC_ID_TO_ENGLISH = Utils:ShallowCopy(ENGLISH_FALLBACK)

----------------------------------------------------------------------
-- 6. Icon Texture Helper
----------------------------------------------------------------------

--- Wrap a texture ID into an inline icon string for chat/UI display.
--- @param iconID   number|nil  Texture file ID
--- @param size     number|nil  Icon size in pixels (default 16)
--- @return string              Inline icon markup, or empty string
function Utils:GetIconString(iconID, size)
    if type(iconID) ~= "number" or iconID <= 0 then
        return ""
    end
    size = size or 16
    return string.format("|T%d:%d:%d|t", iconID, size, size)
end

----------------------------------------------------------------------
-- 7. Delayed Execution
----------------------------------------------------------------------

--- Execute a callback after a specified delay using C_Timer.
--- @param delay    number    Delay in seconds (minimum 0)
--- @param callback function  Function to execute
function Utils:After(delay, callback)
    if type(callback) ~= "function" then
        return
    end
    if type(delay) ~= "number" or delay < 0 then
        delay = 0
    end
    local ok, timer = self:SafeCall(C_Timer.After, delay, callback)
    if not ok then
        -- Immediate fallback if C_Timer fails
        callback()
    end
end

----------------------------------------------------------------------
-- 8. Color Formatting
----------------------------------------------------------------------

--- Wrap text in a WoW color escape sequence.
--- @param text  string  The text to color
--- @param hex   string  Six-character hex color code
--- @return string       Color-escaped string
function Utils:ColorText(text, hex)
    if type(text) ~= "string" then
        text = tostring(text)
    end
    if type(hex) ~= "string" or #hex ~= 6 then
        hex = "FFFFFF"
    end
    return "|cFF" .. hex .. text .. "|r"
end

--- Addon brand color for consistent UI output.
--- @param text string  Text to brand-colorize
--- @return string      Colored string (purple hue)
function Utils:BrandText(text)
    return self:ColorText(text, "8040FF")
end
