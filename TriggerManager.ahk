
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Trigger Manager
; Manages physical keyboard and mouse triggers for macros.
; AutoHotkey v2
; ============================================================

TriggerManager_Initialize() {
    global MS_State, MS_Triggers, MS_Macros

    if !IsObject(MS_Triggers)
        MS_Triggers := Map()

    MS_State["triggersReady"] := true
    MS_State["triggersEnabled"] := true
    MS_State["triggerCallbacks"] := Map()
    MS_State["triggerCooldowns"] := Map()
    MS_State["triggerHeld"] := Map()
    MS_State["triggerRegistered"] := Map()
    MS_State["triggerProcessing"] := false

    TriggerManager_LoadFromMacros()
    return true
}

; ------------------------------------------------------------
; Loading and registering triggers
; ------------------------------------------------------------

TriggerManager_LoadFromMacros() {
    global MS_Macros, MS_Triggers

    MS_Triggers := Map()

    for macroId, macro in MS_Macros {
        if !IsObject(macro)
            continue

        if !macro.Has("trigger")
            continue

        trigger := macro["trigger"]

        if !IsObject(trigger)
            continue

        if !trigger.Has("key") || (trigger["key"] = "")
            continue

        MS_Triggers[macroId] := trigger
    }

    TriggerManager_RegisterAll()
    return MS_Triggers.Count
}

TriggerManager_RegisterAll() {
    global MS_Triggers

    TriggerManager_UnregisterAll()

    for macroId, trigger in MS_Triggers {
        if !IsObject(trigger)
            continue

        if !TriggerManager_IsTriggerEnabled(trigger)
            continue

        TriggerManager_Register(macroId, trigger)
    }

    return true
}

TriggerManager_Register(macroId, trigger) {
    global MS_State

    if !IsObject(trigger)
        return false

    key := TriggerManager_GetValue(trigger, "key", "")

    if (key = "")
        return false

    mode := StrLower(TriggerManager_GetValue(trigger, "mode", "press"))

    if !TriggerManager_ValidateMode(mode)
        return false

    if !TriggerManager_ValidateKey(key)
        return false

    hotkeyName := TriggerManager_BuildHotkey(key, mode)

    if (hotkeyName = "")
        return false

    callback := TriggerManager_CreateCallback(macroId, mode)

    try {
        Hotkey(hotkeyName, callback, "On")

        registered := MS_State["triggerRegistered"]

        if !registered.Has(macroId)
            registered[macroId] := []

        registered[macroId].Push(hotkeyName)

        callbacks := MS_State["triggerCallbacks"]
        callbacks[macroId] := callback

        return true
    } catch as triggerError {
        try {
            ExecutionConsole_Log(
                "Could not register trigger for macro "
                . macroId . ": " . triggerError.Message,
                "WARNING"
            )
        }

        return false
    }
}

TriggerManager_Unregister(macroId) {
    global MS_State

    registered := MS_State["triggerRegistered"]

    if !registered.Has(macroId)
        return true

    for hotkeyName in registered[macroId] {
        try Hotkey(hotkeyName, "Off")
    }

    registered.Delete(macroId)

    callbacks := MS_State["triggerCallbacks"]

    if callbacks.Has(macroId)
        callbacks.Delete(macroId)

    return true
}

TriggerManager_UnregisterAll() {
    global MS_State

    registered := MS_State.Get("triggerRegistered", Map())

    for macroId, hotkeys in registered {
        for hotkeyName in hotkeys {
            try Hotkey(hotkeyName, "Off")
        }
    }

    registered.Clear()
    MS_State["triggerCallbacks"] := Map()

    return true
}

; ------------------------------------------------------------
; Hotkey construction and callbacks
; ------------------------------------------------------------

TriggerManager_BuildHotkey(key, mode) {
    key := Trim(key)

    if (key = "")
        return ""

    if (mode = "double")
        return "~*" key

    if (mode = "hold")
        return "~*" key

    return "~*" key
}

TriggerManager_CreateCallback(macroId, mode) {
    return (*) => TriggerManager_OnHotkey(macroId, mode)
}

TriggerManager_OnHotkey(macroId, mode) {
    global MS_State

    if !TriggerManager_CanProcess()
        return false

    if (mode = "hold") {
        return TriggerManager_HandleHold(macroId)
    }

    if (mode = "double") {
        return TriggerManager_HandleDoubleTap(macroId)
    }

    return TriggerManager_ExecuteMacro(macroId)
}

; ------------------------------------------------------------
; Trigger modes
; ------------------------------------------------------------

TriggerManager_HandleHold(macroId) {
    global MS_State

    held := MS_State["triggerHeld"]

    if held.Get(macroId, false)
        return false

    held[macroId] := true

    try {
        return TriggerManager_ExecuteMacro(macroId)
    } finally {
        held[macroId] := false
    }
}

TriggerManager_HandleDoubleTap(macroId) {
    global MS_State

    cooldowns := MS_State["triggerCooldowns"]
    now := A_TickCount

    if cooldowns.Has(macroId) {
        previous := cooldowns[macroId]
        elapsed := now - previous

        if (elapsed <= 350) {
            cooldowns.Delete(macroId)
            return TriggerManager_ExecuteMacro(macroId)
        }
    }

    cooldowns[macroId] := now
    return true
}

; ------------------------------------------------------------
; Macro execution
; ------------------------------------------------------------

TriggerManager_ExecuteMacro(macroId) {
    global MS_Macros, MS_State

    if !TriggerManager_CanProcess()
        return false

    if !MS_Macros.Has(macroId)
        return false

    macro := MS_Macros[macroId]

    if !IsObject(macro)
        return false

    if !macro.Get("enabled", true)
        return false

    if !TriggerManager_CheckMacroRestrictions(macro)
        return false

    if MS_State.Get("triggerProcessing", false)
        return false

    MS_State["triggerProcessing"] := true

    try {
        return PlaybackEngine_Start(macroId)
    } catch as triggerError {
        ExecutionConsole_Log(
            "Trigger execution failed: " . triggerError.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["triggerProcessing"] := false
    }
}

TriggerManager_CheckMacroRestrictions(macro) {
    if !IsObject(macro)
        return false

    activeOnly := macro.Get("activeWindowOnly", false)

    if !activeOnly
        return true

    targetWindow := macro.Get("targetWindow", "")

    if (targetWindow = "")
        return false

    try {
        return WinActive(targetWindow) != 0
    } catch {
        return false
    }
}

; ------------------------------------------------------------
; Dynamic trigger management
; ------------------------------------------------------------

TriggerManager_SetTrigger(macroId, key, mode := "press") {
    global MS_Macros, MS_Triggers

    if !MS_Macros.Has(macroId)
        return false

    if !TriggerManager_ValidateKey(key)
        return false

    if !TriggerManager_ValidateMode(mode)
        return false

    trigger := Map(
        "key", key,
        "mode", mode,
        "enabled", true
    )

    macro := MS_Macros[macroId]
    macro["trigger"] := trigger

    TriggerManager_Unregister(macroId)

    MS_Triggers[macroId] := trigger

    return TriggerManager_Register(macroId, trigger)
}

TriggerManager_RemoveTrigger(macroId) {
    global MS_Macros, MS_Triggers

    TriggerManager_Unregister(macroId)

    if MS_Triggers.Has(macroId)
        MS_Triggers.Delete(macroId)

    if MS_Macros.Has(macroId) {
        macro := MS_Macros[macroId]

        if macro.Has("trigger")
            macro.Delete("trigger")
    }

    return true
}

TriggerManager_EnableTrigger(macroId) {
    global MS_Triggers

    if !MS_Triggers.Has(macroId)
        return false

    trigger := MS_Triggers[macroId]
    trigger["enabled"] := true

    return TriggerManager_Register(macroId, trigger)
}

TriggerManager_DisableTrigger(macroId) {
    global MS_Triggers

    TriggerManager_Unregister(macroId)

    if MS_Triggers.Has(macroId)
        MS_Triggers[macroId]["enabled"] := false

    return true
}

TriggerManager_EnableAll() {
    global MS_State

    MS_State["triggersEnabled"] := true
    return TriggerManager_RegisterAll()
}

TriggerManager_DisableAll() {
    global MS_State

    MS_State["triggersEnabled"] := false
    return TriggerManager_UnregisterAll()
}

; ------------------------------------------------------------
; Validation
; ------------------------------------------------------------

TriggerManager_ValidateMode(mode) {
    mode := StrLower(mode)

    return mode = "press"
        || mode = "hold"
        || mode = "double"
}

TriggerManager_ValidateKey(key) {
    if !IsObject(key)
        return Trim(key) != ""

    return false
}

TriggerManager_IsTriggerEnabled(trigger) {
    global MS_State

    if !MS_State.Get("triggersEnabled", true)
        return false

    return trigger.Get("enabled", true)
}

TriggerManager_CanProcess() {
    global MS_State

    if !MS_State.Get("triggersReady", false)
        return false

    if !MS_State.Get("triggersEnabled", true)
        return false

    if !MS_State.Get("enabled", true)
        return false

    if MS_State.Get("shuttingDown", false)
        return false

    return true
}

; ------------------------------------------------------------
; Trigger information
; ------------------------------------------------------------

TriggerManager_GetTrigger(macroId) {
    global MS_Triggers

    if !MS_Triggers.Has(macroId)
        return ""

    return MS_Triggers[macroId]
}

TriggerManager_GetAll() {
    global MS_Triggers
    return MS_Triggers
}

TriggerManager_GetCount() {
    global MS_Triggers
    return MS_Triggers.Count
}

TriggerManager_HasTrigger(macroId) {
    global MS_Triggers
    return MS_Triggers.Has(macroId)
}

TriggerManager_GetValue(data, key, defaultValue := unset) {
    if IsObject(data) && data.Has(key)
        return data[key]

    if IsSet(defaultValue)
        return defaultValue

    return ""
}

; ------------------------------------------------------------
; Refresh and shutdown
; ------------------------------------------------------------

TriggerManager_Refresh() {
    return TriggerManager_LoadFromMacros()
}

TriggerManager_Shutdown() {
    global MS_State

    TriggerManager_UnregisterAll()

    MS_State["triggersReady"] := false
    MS_State["triggersEnabled"] := false
    MS_State["triggerProcessing"] := false

    return true
}
