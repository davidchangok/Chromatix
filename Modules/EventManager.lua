--[[
================================================================================
  Chromatix (幻色龙) - Modules/EventManager.lua
  Central event bus: registers, dispatches, and unregisters WoW events.
  All other modules subscribe through this manager rather than creating
  their own frames, keeping event handling consolidated and testable.

  Author : David W Zhang
  Version: 1.0.0
  License: MIT
  Repo   : https://github.com/davidchangok/Chromatix
================================================================================
--]]

local _, NS = ...
local L     = NS.L

----------------------------------------------------------------------
-- 1. Module Declaration
----------------------------------------------------------------------

--- @class EventManager
local EventManager = NS:NewModule("EventManager")
NS.EventManager    = EventManager

----------------------------------------------------------------------
-- 2. Internal State
----------------------------------------------------------------------

--- Hidden frame used solely for WoW event registration.
--- @type Frame
local eventFrame = CreateFrame("Frame", "ChromatixEventFrame", UIParent)

--- Registry: eventName → { [callbackID] = callbackFunc, ... }
--- @type table<string, table<string, function>>
local registry = {}

--- Auto-incrementing callback ID counter.
--- @type number
local nextCallbackID = 1

----------------------------------------------------------------------
-- 3. Internal Dispatcher
----------------------------------------------------------------------

--- Master OnEvent handler — routes every fired event to all
--- registered callbacks for that event.
--- @param self  Frame   The hidden event frame (unused)
--- @param event string  The WoW event name
--- @param ...   any     Event payload arguments
local function OnEvent(self, event, ...)
    local callbacks = registry[event]
    if not callbacks then
        return
    end

    for id, callback in pairs(callbacks) do
        -- Protect each callback so one failure does not block others
        local ok, err = pcall(callback, event, ...)
        if not ok then
            NS:DebugPrint("EventManager: error in callback [" .. id .. "] for " .. event .. ": " .. tostring(err))
        end
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

----------------------------------------------------------------------
-- 4. Public API
----------------------------------------------------------------------

--- Register a callback for a specific WoW event.
--- @param event    string    WoW event name (e.g. "PLAYER_ENTERING_WORLD")
--- @param callback function  Function to invoke: callback(event, ...)
--- @param tag      string|nil Optional human-readable tag for debugging
--- @return string             Unique callback ID (used to unregister)
function EventManager:RegisterEvent(event, callback, tag)
    -- Validate arguments
    if type(event) ~= "string" or event == "" then
        NS:DebugPrint("EventManager:RegisterEvent — invalid event name.")
        return ""
    end
    if type(callback) ~= "function" then
        NS:DebugPrint("EventManager:RegisterEvent — callback is not a function.")
        return ""
    end

    -- Ensure registry bucket exists
    if not registry[event] then
        registry[event] = {}
        -- First subscriber for this event: tell the frame to listen
        eventFrame:RegisterEvent(event)
        NS:DebugPrint("EventManager: now listening to event:", event)
    end

    -- Generate unique ID
    local id = tostring(nextCallbackID)
    if tag and type(tag) == "string" then
        id = tag .. "#" .. id
    end
    nextCallbackID = nextCallbackID + 1

    registry[event][id] = callback
    NS:DebugPrint("EventManager: registered callback [" .. id .. "] for", event)
    return id
end

--- Unregister a specific callback by its ID.
--- If no callbacks remain for an event, the frame stops listening to it.
--- @param event      string  WoW event name
--- @param callbackID string  The ID returned by RegisterEvent
--- @return boolean           true if the callback was found and removed
function EventManager:UnregisterEvent(event, callbackID)
    if type(event) ~= "string" or type(callbackID) ~= "string" then
        NS:DebugPrint("EventManager:UnregisterEvent — invalid arguments.")
        return false
    end

    local callbacks = registry[event]
    if not callbacks or not callbacks[callbackID] then
        NS:DebugPrint("EventManager:UnregisterEvent — callback [" .. callbackID .. "] not found for", event)
        return false
    end

    callbacks[callbackID] = nil
    NS:DebugPrint("EventManager: removed callback [" .. callbackID .. "] from", event)

    -- If no more callbacks for this event, stop listening entirely
    if next(callbacks) == nil then
        registry[event] = nil
        eventFrame:UnregisterEvent(event)
        NS:DebugPrint("EventManager: stopped listening to event:", event)
    end

    return true
end

--- Unregister ALL callbacks for a specific event.
--- @param event string  WoW event name
function EventManager:UnregisterAllForEvent(event)
    if type(event) ~= "string" then
        return
    end
    if registry[event] then
        registry[event] = nil
        eventFrame:UnregisterEvent(event)
        NS:DebugPrint("EventManager: cleared all callbacks for", event)
    end
end

--- Check whether any callbacks are registered for an event.
--- @param event string  WoW event name
--- @return boolean      true if at least one callback is registered
function EventManager:HasCallbacks(event)
    if type(event) ~= "string" then
        return false
    end
    local callbacks = registry[event]
    return callbacks ~= nil and next(callbacks) ~= nil
end

--- Return a count of registered callbacks for a given event.
--- Useful for debugging and status reports.
--- @param event string  WoW event name
--- @return number       Number of registered callbacks
function EventManager:GetCallbackCount(event)
    if type(event) ~= "string" then
        return 0
    end
    local callbacks = registry[event]
    if not callbacks then
        return 0
    end
    local count = 0
    for _ in pairs(callbacks) do
        count = count + 1
    end
    return count
end

--- Return a list of all events currently being listened to.
--- @return table  Array of event name strings
function EventManager:GetRegisteredEvents()
    local events = {}
    for event in pairs(registry) do
        events[#events + 1] = event
    end
    table.sort(events)
    return events
end

----------------------------------------------------------------------
-- 5. Addon Lifecycle Bootstrap
----------------------------------------------------------------------

--- One-time ADDON_LOADED handler.
--- Initializes the DB and fires a custom "ready" signal to all modules.
--- @param event     string  "ADDON_LOADED"
--- @param addonName string  Name of the addon that finished loading
local function OnAddonLoaded(event, addonName)
    if addonName ~= NS.ADDON_NAME then
        return
    end

    -- Initialize SavedVariables
    NS:InitializeDB()
    NS:DebugPrint("Core DB initialized.")

    -- Notify all modules that have an :OnInitialize() method
    for name, mod in pairs(NS.modules) do
        if type(mod.OnInitialize) == "function" then
            local ok, err = pcall(mod.OnInitialize, mod)
            if not ok then
                NS:DebugPrint("Error initializing module [" .. name .. "]:", tostring(err))
            end
        end
    end

    -- Print welcome message
    NS:Print(NS.Utils:SafeFormat(L["ADDON_LOADED"], NS.VERSION))

    -- Unregister this one-shot handler
    EventManager:UnregisterEvent("ADDON_LOADED", addonLoadedID)
end

--- Store the callback ID so it can self-unregister.
--- @type string
addonLoadedID = EventManager:RegisterEvent("ADDON_LOADED", OnAddonLoaded, "Core_AddonLoaded")

----------------------------------------------------------------------
-- 6. PLAYER_ENTERING_WORLD Bootstrap
----------------------------------------------------------------------

--- Fires once (or on reload) when the player enters the world.
--- Used to trigger initial spec detection and gear check.
--- @param event        string   "PLAYER_ENTERING_WORLD"
--- @param isInitialLogin boolean true on first login
--- @param isReloadingUi boolean true on /reload
local function OnPlayerEnteringWorld(event, isInitialLogin, isReloadingUi)
    NS:DebugPrint("PLAYER_ENTERING_WORLD — initialLogin:", tostring(isInitialLogin),
                  "reload:", tostring(isReloadingUi))

    -- Notify all modules that have an :OnEnable() method
    for name, mod in pairs(NS.modules) do
        if type(mod.OnEnable) == "function" then
            local ok, err = pcall(mod.OnEnable, mod)
            if not ok then
                NS:DebugPrint("Error enabling module [" .. name .. "]:", tostring(err))
            end
        end
    end
end

EventManager:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, "Core_EnteringWorld")

----------------------------------------------------------------------
-- 7. Combat State Tracking
----------------------------------------------------------------------

--- Deferred action queue — functions to run once combat ends.
--- @type table<number, function>
NS.deferredQueue = {}

--- Add an action to the deferred queue (executed after combat ends).
--- @param action function  The function to execute post-combat
function EventManager:DeferUntilOutOfCombat(action)
    if type(action) ~= "function" then
        NS:DebugPrint("EventManager:DeferUntilOutOfCombat — action is not a function.")
        return
    end

    if not InCombatLockdown() then
        -- Not in combat: execute immediately
        local ok, err = pcall(action)
        if not ok then
            NS:DebugPrint("Deferred action immediate execution error:", tostring(err))
        end
        return
    end

    -- Queue it
    NS.deferredQueue[#NS.deferredQueue + 1] = action
    NS:DebugPrint("EventManager: action deferred (queue size:", #NS.deferredQueue, ")")
end

--- Flush the deferred queue when combat ends.
--- @param event string  "PLAYER_REGEN_ENABLED"
local function OnRegenEnabled(event)
    NS:DebugPrint("PLAYER_REGEN_ENABLED — flushing deferred queue (" ..
                  #NS.deferredQueue .. " actions).")

    -- Copy and clear the queue to avoid re-entrant issues
    local queue = NS.deferredQueue
    NS.deferredQueue = {}

    for i, action in ipairs(queue) do
        local ok, err = pcall(action)
        if not ok then
            NS:DebugPrint("Deferred action [" .. i .. "] error:", tostring(err))
        end
    end
end

EventManager:RegisterEvent("PLAYER_REGEN_ENABLED", OnRegenEnabled, "Core_RegenEnabled")

----------------------------------------------------------------------
-- 8. Slash Command Router
----------------------------------------------------------------------

--- Register slash commands: /chromatix and /ctx
SLASH_CHROMATIX1 = "/chromatix"
SLASH_CHROMATIX2 = "/ctx"

--- Slash command handler — dispatches subcommands.
--- @param input string  Raw user input after the slash command
SlashCmdList["CHROMATIX"] = function(input)
    local cmd = NS.Utils:Trim(input):lower()

    if cmd == "" or cmd == "help" then
        NS:Print(L["CMD_HELP_HEADER"])
        NS:Print(L["CMD_HELP_CONFIG"])
        NS:Print(L["CMD_HELP_STATUS"])
        NS:Print(L["CMD_HELP_SWAP"])
        NS:Print(L["CMD_HELP_DEBUG"])
        NS:Print(L["CMD_HELP_RESET"])

    elseif cmd == "config" or cmd == "options" then
        -- Open the settings panel (handled by OptionsPanel module)
        local optionsMod = NS:GetModule("OptionsPanel")
        if optionsMod and type(optionsMod.Open) == "function" then
            optionsMod:Open()
        else
            NS:Print(L["ERR_MODULE_NOT_FOUND"]:format("OptionsPanel"))
        end

    elseif cmd == "status" then
        local specMod = NS:GetModule("SpecManager")
        if specMod and type(specMod.PrintStatus) == "function" then
            specMod:PrintStatus()
        end

    elseif cmd == "swap" then
        local equipMod = NS:GetModule("EquipmentManager")
        if equipMod and type(equipMod.SwapToCurrentSpec) == "function" then
            equipMod:SwapToCurrentSpec()
        end

    elseif cmd == "debug" then
        if NS.db and NS.db.global then
            NS.db.global.debugMode = not NS.db.global.debugMode
            local state = NS.db.global.debugMode and L["STATUS_ON"] or L["STATUS_OFF"]
            NS:Print(NS.Utils:SafeFormat(L["STATUS_DEBUG"], state))
        end

    elseif cmd == "reset" then
        local key = NS:GetCharacterKey()
        if key and NS.db and NS.db.characters then
            NS.db.characters[key] = nil
            NS:Print(L["OPTIONS_RESET_DONE"])
        end

    else
        NS:Print(NS.Utils:SafeFormat(L["CMD_UNKNOWN"], cmd))
    end
end