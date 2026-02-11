--[[
================================================================================
  Chromatix (幻色龙) - Utils.lua
  General-purpose utility functions shared across all modules.

  Author : David W Zhang
  Version: 1.0.0
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
--- Handles nested tables; does NOT handle metatables or circular refs.
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
--- Returns nil on error instead of propagating the exception.
--- @param func    function  The API function to call
--- @param ...     any       Arguments to pass
--- @return boolean success  Whether the call succeeded
--- @return any    ...       Return values from the API, or error message
function Utils:SafeCall(func, ...)
    if type(func) ~= "function" then
        NS:DebugPrint("SafeCall: provided value is not a function.")
        return false, "Not a function"
    end
    local results = { pcall(func, ...) }
    local ok = table.remove(results, 1)
    if not ok then
        local errMsg = results[1] or "Unknown error"
        NS:DebugPrint("SafeCall error:", errMsg)
        return false, errMsg
    end
    return true, unpack(results)
end

----------------------------------------------------------------------
-- 5. Combat State Helper
----------------------------------------------------------------------

--- Check whether the player is currently in combat lockdown.
--- During combat lockdown, protected functions (like EquipmentManager
--- operations that modify the UI) may be restricted.
--- @return boolean  true if in combat lockdown
function Utils:IsInCombatLockdown()
    return InCombatLockdown()
end

----------------------------------------------------------------------
-- 6. Specialization English Name Map
----------------------------------------------------------------------

--- Static lookup table: specID → English specialization name.
--- This avoids relying on locale-dependent GetSpecializationInfo
--- when the user selects "English" naming mode.
--- Covers all classes and specs as of Interface 120000 (The War Within).
--- @type table<number, string>
Utils.SPEC_ID_TO_ENGLISH = {
    -- Death Knight
    [250] = "Blood",
    [251] = "Frost",
    [252] = "Unholy",
    -- Demon Hunter
    [577] = "Havoc",
    [581] = "Vengeance",
    -- Druid
    [102] = "Balance",
    [103] = "Feral",
    [104] = "Guardian",
    [105] = "Restoration",
    -- Evoker
    [1467] = "Devastation",
    [1468] = "Preservation",
    [1473] = "Augmentation",
    -- Hunter
    [253] = "Beast Mastery",
    [254] = "Marksmanship",
    [255] = "Survival",
    -- Mage
    [62]  = "Arcane",
    [63]  = "Fire",
    [64]  = "Frost",
    -- Monk
    [268] = "Brewmaster",
    [270] = "Mistweaver",
    [269] = "Windwalker",
    -- Paladin
    [65]  = "Holy",
    [66]  = "Protection",
    [70]  = "Retribution",
    -- Priest
    [256] = "Discipline",
    [257] = "Holy",
    [258] = "Shadow",
    -- Rogue
    [259] = "Assassination",
    [260] = "Outlaw",
    [261] = "Subtlety",
    -- Shaman
    [262] = "Elemental",
    [263] = "Enhancement",
    [264] = "Restoration",
    -- Warlock
    [265] = "Affliction",
    [266] = "Demonology",
    [267] = "Destruction",
    -- Warrior
    [71]  = "Arms",
    [72]  = "Fury",
    [73]  = "Protection",
}

----------------------------------------------------------------------
-- 7. Icon Texture Helper
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
-- 8. Delayed Execution
----------------------------------------------------------------------

--- Execute a callback after a specified delay using C_Timer.
--- @param delay    number    Delay in seconds (minimum 0)
--- @param callback function  Function to execute
function Utils:After(delay, callback)
    if type(callback) ~= "function" then
        NS:DebugPrint("Utils:After - callback is not a function.")
        return
    end
    if type(delay) ~= "number" or delay < 0 then
        delay = 0
    end
    C_Timer.After(delay, callback)
end

----------------------------------------------------------------------
-- 9. Color Formatting
----------------------------------------------------------------------

--- Wrap text in a WoW color escape sequence.
--- @param text  string  The text to color
--- @param hex   string  Six-character hex color code (e.g. "FF8040")
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