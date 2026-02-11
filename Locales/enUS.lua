--[[
================================================================================
  Chromatix (幻色龙) - Locales/enUS.lua
  English (United States) localization — serves as the default/fallback locale.
  All keys defined here MUST exist; other locale files override as needed.

  Author : David W Zhang
  Version: 1.0.0
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...

--- English is the default (fallback) locale.
--- The third argument `true` marks it as the base layer.
NS:RegisterLocale("enUS", {

    --------------------------------------------------------------------
    -- General / Addon Info
    --------------------------------------------------------------------
    ["ADDON_NAME"]              = "Chromatix",
    ["ADDON_LOADED"]            = "Chromatix v%s loaded. Type /chromatix for help.",
    ["ADDON_DESCRIPTION"]       = "Automatically equips gear sets based on your current specialization.",

    --------------------------------------------------------------------
    -- Slash Commands
    --------------------------------------------------------------------
    ["CMD_HELP_HEADER"]         = "Chromatix — Available Commands:",
    ["CMD_HELP_CONFIG"]         = "/chromatix config — Open settings panel.",
    ["CMD_HELP_STATUS"]         = "/chromatix status — Show current spec and linked set.",
    ["CMD_HELP_SWAP"]           = "/chromatix swap — Manually trigger gear swap for current spec.",
    ["CMD_HELP_DEBUG"]          = "/chromatix debug — Toggle debug mode.",
    ["CMD_HELP_RESET"]          = "/chromatix reset — Reset current character settings.",
    ["CMD_UNKNOWN"]             = "Unknown command: %s. Type /chromatix for help.",

    --------------------------------------------------------------------
    -- Spec Manager
    --------------------------------------------------------------------
    ["SPEC_DETECTED"]           = "Specialization detected: %s (ID: %d).",
    ["SPEC_CHANGED"]            = "Specialization changed to: %s.",
    ["SPEC_NONE"]               = "No specialization is currently active.",
    ["SPEC_QUERY_FAILED"]       = "Failed to query specialization info.",

    --------------------------------------------------------------------
    -- Equipment Manager
    --------------------------------------------------------------------
    ["EQUIP_SET_FOUND"]         = "Equipment set found: \"%s\". Equipping...",
    ["EQUIP_SET_EQUIPPED"]      = "Equipment set \"%s\" equipped successfully.",
    ["EQUIP_SET_NOT_FOUND"]     = "No equipment set found for specialization: %s.",
    ["EQUIP_SET_CREATED"]       = "New equipment set \"%s\" created with icon %s.",
    ["EQUIP_SET_CREATE_FAILED"] = "Failed to create equipment set \"%s\".",
    ["EQUIP_SET_ALREADY_EXISTS"]= "Equipment set \"%s\" already exists.",
    ["EQUIP_COMBAT_DEFERRED"]   = "In combat — gear swap deferred until combat ends.",
    ["EQUIP_COMBAT_RESUMED"]    = "Combat ended — applying deferred gear swap.",
    ["EQUIP_MAX_SETS"]          = "Maximum number of equipment sets reached. Cannot create a new set.",

    --------------------------------------------------------------------
    -- UI Hook (Equipment Flyout Button)
    --------------------------------------------------------------------
    ["UI_NEW_SPEC_SET"]         = "New Spec Set",
    ["UI_NEW_SPEC_SET_TOOLTIP"] = "Create a new equipment set named after your current specialization.",
    ["UI_BUTTON_CLICK_COMBAT"]  = "Cannot create equipment set while in combat.",

    --------------------------------------------------------------------
    -- Options Panel
    --------------------------------------------------------------------
    ["OPTIONS_TITLE"]           = "Chromatix Settings",
    ["OPTIONS_GENERAL"]         = "General",
    ["OPTIONS_NAMING_MODE"]     = "Set Naming Mode",
    ["OPTIONS_NAMING_DESC"]     = "Choose whether equipment set names use English spec names (e.g. \"Retribution\") or localized names (e.g. \"惩戒\").",
    ["OPTIONS_NAMING_ENGLISH"]  = "English",
    ["OPTIONS_NAMING_LOCALIZED"]= "Localized",
    ["OPTIONS_DEBUG_MODE"]      = "Debug Mode",
    ["OPTIONS_DEBUG_DESC"]      = "Enable verbose debug messages in the chat frame.",
    ["OPTIONS_AUTO_SWAP"]       = "Auto Swap on Spec Change",
    ["OPTIONS_AUTO_SWAP_DESC"]  = "Automatically equip the linked gear set when you change specializations.",
    ["OPTIONS_RESET"]           = "Reset Character Settings",
    ["OPTIONS_RESET_DESC"]      = "Clear all spec-to-set mappings for this character.",
    ["OPTIONS_RESET_CONFIRM"]   = "Are you sure you want to reset all Chromatix settings for this character?",
    ["OPTIONS_RESET_DONE"]      = "Character settings have been reset.",

    --------------------------------------------------------------------
    -- Status Messages
    --------------------------------------------------------------------
    ["STATUS_HEADER"]           = "Chromatix — Current Status:",
    ["STATUS_SPEC"]             = "Active Spec: %s (Index: %d, ID: %d)",
    ["STATUS_LINKED_SET"]       = "Linked Equipment Set: \"%s\"",
    ["STATUS_NO_LINK"]          = "No equipment set linked to this spec.",
    ["STATUS_NAMING_MODE"]      = "Naming Mode: %s",
    ["STATUS_DEBUG"]            = "Debug Mode: %s",
    ["STATUS_ON"]               = "ON",
    ["STATUS_OFF"]              = "OFF",

    --------------------------------------------------------------------
    -- Error / Warning Messages
    --------------------------------------------------------------------
    ["ERR_NO_SPEC"]             = "Unable to determine current specialization.",
    ["ERR_EQUIPMENT_API"]       = "Equipment set API returned an unexpected result.",
    ["ERR_PROTECTED_ACTION"]    = "Action blocked: protected function called during combat lockdown.",
    ["ERR_INVALID_ARG"]         = "Invalid argument supplied to %s.",
    ["ERR_MODULE_NOT_FOUND"]    = "Module \"%s\" not found.",

    --------------------------------------------------------------------
    -- Confirmation Dialogs
    --------------------------------------------------------------------
    ["CONFIRM_YES"]             = "Yes",
    ["CONFIRM_NO"]              = "No",
    ["CONFIRM_OK"]              = "OK",
    ["CONFIRM_CANCEL"]          = "Cancel",

}, true) -- true = default/fallback locale