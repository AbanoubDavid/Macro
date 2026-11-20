
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - InputHandler.ahk
; Global hotkeys, emergency controls and input safety
; ============================================================

global MS_InputHandlerInitialized := false
global MS_InputHotkeys := Map()
global MS_InputSuspended := false
global MS_InputEmergencyBusy := false

; ============================================================
; INITIALIZATION
; ============================================================

InputHandler_Initialize() {
    global MS_InputHandlerInitialized
    global MS_InputHotkeys
    global MS_InputSuspended
    global MS_InputEmergencyBusy

    if MS_InputHandlerInitialized
        return true

    MS_InputHotkeys := Map()
    MS_InputSuspended := false
    MS_InputEmergencyBusy := false

    InputHandler_RegisterEmergencyHotkeys()

    MS_InputHandlerInitialized := true

    return true
}

; ============================================================
; EMERGENCY HOTKEYS
; ============================================================

InputHandler_RegisterEmergencyHotkeys() {
    toggleHotkey := InputHandler_GetSetting(
        "emergencyToggleHotkey",
        "F12"
    )

    stopHotkey := InputHandler_GetSetting(
        "emergencyStopHotkey",
        "F10"
    )

    if toggleHotkey
        InputHandler_RegisterHotkey(
            "emergencyToggle",
            toggleHotkey,
            InputHandler_ToggleAll
        )

    if stopHotkey
        InputHandler_RegisterHotkey(
            "emergencyStop",
            stopHotkey,
            InputHandler_StopCurrent
        )

    return true
}

InputHandler_GetSetting(name, defaultValue) {
    global MS_Settings

    if IsObject(MS_Settings) && MS_Settings.Has(name)
        return MS_Settings[name]

    return defaultValue
}

; ============================================================
; HOTKEY REGISTRATION
; ============================================================

InputHandler_RegisterHotkey(name, hotkey, callback) {
    global MS_InputHotkeys

    if !IsString(hotkey) || !Trim(hotkey)
        return false

    try {
        if MS_InputHotkeys.Has(name)
            InputHandler_UnregisterHotkey(name)

        Hotkey(
            hotkey,
            callback,
            "On"
        )

        MS_InputHotkeys[name] := hotkey

        return true
    }
    catch as inputError {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Hotkey registration failed for "
                . hotkey . ": " . inputError.Message
            )
        }

        return false
    }
}

InputHandler_UnregisterHotkey(name) {
    global MS_InputHotkeys

    if !MS_InputHotkeys.Has(name)
        return false

    registeredHotkey := MS_InputHotkeys[name]

    try {
        Hotkey(registeredHotkey, "Off")
    }

    MS_InputHotkeys.Delete(name)

    return true
}

InputHandler_UnregisterAll() {
    global MS_InputHotkeys

    for hotkeyName, registeredHotkey in MS_InputHotkeys {
        try {
            Hotkey(registeredHotkey, "Off")
        }
    }

    MS_InputHotkeys.Clear()

    return true
}

; ============================================================
; EMERGENCY TOGGLE
; ============================================================

InputHandler_ToggleAll(*) {
    global MS_State
    global MS_InputEmergencyBusy

    if MS_InputEmergencyBusy
        return

    MS_InputEmergencyBusy := true

    try {
        currentState := MS_State.Has("enabled")
            ? MS_State["enabled"]
            : true

        newState := !currentState

        MS_State["enabled"] := newState

        if !newState {
            InputHandler_StopCurrent()
            TriggerManager_DisableAll()
        } else {
            TriggerManager_EnableAll()
        }

        try {
            ExecutionConsole_Log(
                newState ? "SUCCESS" : "WARNING",
                newState
                    ? "All macros enabled."
                    : "All macros disabled."
            )
        }

        try {
            UI_SetStatus(
                newState
                    ? "Macros enabled"
                    : "Macros disabled"
            )
        }
    }
    finally {
        MS_InputEmergencyBusy := false
    }
}

; ============================================================
; EMERGENCY STOP
; ============================================================

InputHandler_StopCurrent(*) {
    global MS_State

    MS_State["stopRequested"] := true

    try {
        PlaybackEngine_Stop()
    }

    try {
        MacroChaining_Stop()
    }

    try {
        Sandbox_Stop()
    }

    try {
        ExecutionConsole_Log(
            "WARNING",
            "Emergency stop requested."
        )
    }

    return true
}

; ============================================================
; INPUT SUSPENSION
; ============================================================

InputHandler_Suspend() {
    global MS_InputSuspended

    if MS_InputSuspended
        return true

    MS_InputSuspended := true

    try {
        Suspend(true)
    }

    return true
}

InputHandler_Resume() {
    global MS_InputSuspended

    if !MS_InputSuspended
        return true

    MS_InputSuspended := false

    try {
        Suspend(false)
    }

    return true
}

InputHandler_IsSuspended() {
    global MS_InputSuspended

    return MS_InputSuspended
}

; ============================================================
; MACRO ENABLE / DISABLE
; ============================================================

InputHandler_EnableMacros() {
    global MS_State

    MS_State["enabled"] := true

    try {
        TriggerManager_EnableAll()
    }

    return true
}

InputHandler_DisableMacros() {
    global MS_State

    MS_State["enabled"] := false

    try {
        InputHandler_StopCurrent()
    }

    try {
        TriggerManager_DisableAll()
    }

    return true
}

InputHandler_AreMacrosEnabled() {
    global MS_State

    return MS_State.Has("enabled")
        && MS_State["enabled"]
}

; ============================================================
; SAFE INPUT HELPERS
; ============================================================

InputHandler_IsValidKey(key) {
    if !IsString(key) || !Trim(key)
        return false

    if StrLen(key) > 64
        return false

    return RegExMatch(
        key,
        "^[A-Za-z0-9_{}!+#^<>$*~]+$"
    ) != 0
}

InputHandler_IsValidMouseButton(button) {
    allowedButtons := [
        "LButton",
        "RButton",
        "MButton",
        "XButton1",
        "XButton2"
    ]

    for allowedButton in allowedButtons {
        if button = allowedButton
            return true
    }

    return false
}

InputHandler_ValidateCoordinates(x, y) {
    if !IsNumber(x) || !IsNumber(y)
        return false

    if x < -100000 || x > 100000
        return false

    if y < -100000 || y > 100000
        return false

    return true
}

; ============================================================
; SAFE KEYBOARD INPUT
; ============================================================

InputHandler_SendKey(key, mode := "press") {
    global MS_InputSuspended

    if !InputHandler_IsValidKey(key)
        return false

    if MS_InputSuspended
        return false

    try {
        switch mode {
            case "press":
                Send("{" key "}")

            case "down":
                Send("{" key " down}")

            case "up":
                Send("{" key " up}")

            default:
                return false
        }

        return true
    }
    catch as inputError {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Keyboard input failed: "
                . inputError.Message
            )
        }

        return false
    }
}

InputHandler_SendCombination(keys) {
    global MS_InputSuspended

    if !IsObject(keys) || keys.Length = 0
        return false

    for keyName in keys {
        if !InputHandler_IsValidKey(keyName)
            return false
    }

    if MS_InputSuspended
        return false

    try {
        combination := ""

        for keyName in keys
            combination .= "{" keyName " down}"

        Send(combination)

        reversedCombination := ""

        loop keys.Length {
            keyName := keys[keys.Length - A_Index + 1]
            reversedCombination .= "{" keyName " up}"
        }

        Send(reversedCombination)

        return true
    }
    catch {
        return false
    }
}

; ============================================================
; SAFE MOUSE INPUT
; ============================================================

InputHandler_MouseClick(button := "LButton") {
    global MS_InputSuspended

    if !InputHandler_IsValidMouseButton(button)
        return false

    if MS_InputSuspended
        return false

    try {
        Click(button)
        return true
    }
    catch {
        return false
    }
}

InputHandler_MouseDown(button := "LButton") {
    global MS_InputSuspended

    if !InputHandler_IsValidMouseButton(button)
        return false

    if MS_InputSuspended
        return false

    try {
        Send("{" button " down}")
        return true
    }
    catch {
        return false
    }
}

InputHandler_MouseUp(button := "LButton") {
    if !InputHandler_IsValidMouseButton(button)
        return false

    try {
        Send("{" button " up}")
        return true
    }
    catch {
        return false
    }
}

InputHandler_MouseMove(x, y, speed := 0) {
    global MS_InputSuspended

    if !InputHandler_ValidateCoordinates(x, y)
        return false

    if MS_InputSuspended
        return false

    try {
        MouseMove(
            Round(x),
            Round(y),
            speed
        )

        return true
    }
    catch {
        return false
    }
}

; ============================================================
; RELEASE STUCK INPUTS
; ============================================================

InputHandler_ReleaseCommonKeys() {
    keysToRelease := [
        "Shift",
        "Ctrl",
        "Alt",
        "LShift",
        "RShift",
        "LCtrl",
        "RCtrl",
        "LAlt",
        "RAlt"
    ]

    for keyName in keysToRelease {
        try {
            Send("{" keyName " up}")
        }
    }

    buttonsToRelease := [
        "LButton",
        "RButton",
        "MButton",
        "XButton1",
        "XButton2"
    ]

    for buttonName in buttonsToRelease {
        try {
            Send("{" buttonName " up}")
        }
    }

    return true
}

; ============================================================
; INPUT SAFETY STATUS
; ============================================================

InputHandler_GetStatus() {
    global MS_State
    global MS_InputSuspended
    global MS_InputEmergencyBusy
    global MS_InputHotkeys

    return Map(
        "enabled", MS_State["enabled"],
        "suspended", MS_InputSuspended,
        "emergencyBusy", MS_InputEmergencyBusy,
        "registeredHotkeys", MS_InputHotkeys.Count
    )
}

; ============================================================
; SHUTDOWN
; ============================================================

InputHandler_Shutdown() {
    global MS_InputHandlerInitialized

    InputHandler_StopCurrent()
    InputHandler_ReleaseCommonKeys()
    InputHandler_UnregisterAll()

    MS_InputHandlerInitialized := false

    return true
}

; ============================================================
; END OF InputHandler.ahk
; ============================================================
