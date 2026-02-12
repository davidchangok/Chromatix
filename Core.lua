--[[
================================================================================
  Chromatix (幻色龙) - Core.lua
  Core namespace, addon initialization, and SavedVariables management.

  Author : David W Zhang
  Version: 1.0.0
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

----------------------------------------------------------------------
-- 1. Addon Namespace
----------------------------------------------------------------------

--- @type string   Addon folder name, always "Chromatix"
--- @type table    Private namespace shared across all files
local ADDON_NAME, NS = ...

--- Global reference for debugging (prefixed to avoid collisions)
--- @type table
ChromatixNS = NS

----------------------------------------------------------------------
-- 2. Addon Constants
----------------------------------------------------------------------

--- @class ChromatixConstants
NS.ADDON_NAME    = ADDON_NAME
NS.VERSION       = "1.0.0"
NS.INTERFACE     = 120000
NS.AUTHOR        = "David W Zhang"
NS.DB_VERSION    = 1

--- Equipment set name format tokens
--- @enum NamingMode
NS.NAMING_MODE = {
    LOCALIZED = "localized",   -- Use client locale spec name (e.g. "惩戒")
    ENGLISH   = "english",     -- Use English spec name (e.g. "Retribution")
}

----------------------------------------------------------------------
-- 3. Default SavedVariables
----------------------------------------------------------------------

--- Default structure for ChromatixDB (per-account saved variables)
--- @type table
local DB_DEFAULTS = {
    dbVersion   = NS.DB_VERSION,
    global = {
        namingMode = NS.NAMING_MODE.ENGLISH, -- default to English
        autoSwap   = true,                   -- default to enabled
        debugMode  = false,
    },
    --- Per-character settings keyed by "Name-Realm"
    --- Example: ["Arthas-Mograine"] = { specSets = { [1] = "Retribution", ... } }
    characters = {},
}

----------------------------------------------------------------------
-- 4. Localization Bootstrap
----------------------------------------------------------------------

--- Locale table — populated by Locales/*.lua files
--- Fallback: if a key is missing, return the key itself (English fallback)
--- @type table<string, string>
NS.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

--- Register a locale table.
--- @param locale   string   Locale code, e.g. "enUS", "zhCN"
--- @param entries  table    Key-value pairs of translations
--- @param isDefault boolean If true, entries are used as base/fallback
function NS:RegisterLocale(locale, entries, isDefault)
    if type(entries) ~= "table" then return end

    local currentLocale = GetLocale() or "enUS"

    if isDefault then
        -- Merge default (English) entries as base layer
        for k, v in pairs(entries) do
            if self.L[k] == nil or rawget(self.L, k) == nil then
                rawset(self.L, k, v)
            end
        end
    end

    if locale == currentLocale then
        -- Override with matched locale entries
        for k, v in pairs(entries) do
            rawset(self.L, k, v)
        end
    end
end

----------------------------------------------------------------------
-- 5. Character Identity Helper
----------------------------------------------------------------------

--- Build a unique character key: "Name-Realm"
--- @return string|nil  Character key or nil if data unavailable
function NS:GetCharacterKey()
    local name  = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then
        return nil
    end
    return name .. "-" .. realm
end

----------------------------------------------------------------------
-- 6. SavedVariables Initialization
----------------------------------------------------------------------

--- Deep-copy default values into target table (non-destructive).
--- Only fills in keys that are missing in the target.
--- @param target   table  Destination table
--- @param defaults table  Source defaults
--- @return table          The target table (modified in place)
local function MergeDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            MergeDefaults(target[k], v)
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
    return target
end

--- Initialize or migrate ChromatixDB.
--- Called once on ADDON_LOADED.
function NS:InitializeDB()
    -- Ensure global exists
    if type(ChromatixDB) ~= "table" then
        ChromatixDB = {}
    end

    -- Merge defaults (non-destructive)
    MergeDefaults(ChromatixDB, DB_DEFAULTS)

    -- DB version migration placeholder
    local storedVersion = ChromatixDB.dbVersion or 0
    if storedVersion < NS.DB_VERSION then
        -- Future: migration logic per version increment
        ChromatixDB.dbVersion = NS.DB_VERSION
    end

    -- Store convenient reference
    NS.db = ChromatixDB
end

--- Retrieve or create the current character's settings sub-table.
--- @return table  Character-specific settings table
function NS:GetCharacterDB()
    local key = self:GetCharacterKey()
    if not key then
        -- Fallback: return a transient table to avoid nil errors
        NS:DebugPrint("GetCharacterDB: character key unavailable, using transient table.")
        return {}
    end
    if not self.db.characters[key] then
        self.db.characters[key] = {
            specSets = {},  -- [specIndex] = equipmentSetName
        }
    end
    return self.db.characters[key]
end

----------------------------------------------------------------------
-- 7. Debug Utility
----------------------------------------------------------------------

--- Print a debug message to the chat frame (only when debugMode is on).
--- @param ... any  Values to print (concatenated with spaces)
function NS:DebugPrint(...)
    if self.db and self.db.global and self.db.global.debugMode then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        print("|cFF00CCFF[Chromatix Debug]|r " .. table.concat(parts, " "))
    end
end

--- Print a user-facing message to the default chat frame.
--- @param msg string  Message text (will be prefixed with addon name)
function NS:Print(msg)
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    print("|cFF8040FF[Chromatix]|r " .. msg)
end

----------------------------------------------------------------------
-- 8. Module Registry
----------------------------------------------------------------------

--- Module storage
--- @type table<string, table>
NS.modules = {}

--- Register a new module.
--- @param name string  Unique module name
--- @return table       Module table (to be populated by the caller)
function NS:NewModule(name)
    if type(name) ~= "string" or name == "" then
        error("Chromatix:NewModule() requires a non-empty string name.")
    end
    if self.modules[name] then
        error("Chromatix:NewModule() duplicate module name: " .. name)
    end
    local mod = {}
    mod.name = name
    self.modules[name] = mod
    return mod
end

--- Retrieve a registered module.
--- @param name string  Module name
--- @return table|nil   Module table, or nil if not found
function NS:GetModule(name)
    return self.modules[name]
end