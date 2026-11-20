
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Recorder.ahk
; Keyboard and Mouse Input Recorder
; ============================================================

global MS_RecorderHooks := Map()
global MS_RecorderTimers := Map()
global MS_RecorderStartTime := 0
global MS_RecorderLastEvent := 0
global MS_RecorderStopRequested := false

; ============================================================
; INITIALIZATION
; ============================================================

Recorder_Initialize() {
    global MS_Recorder
    global MS_RecorderHooks
    global MS_RecorderTimers

    if MS_Recorder["initialized"]
        return true

    MS_Recorder["initialized"] := true
    MS_Recorder["recording"] := false
    MS_Recorder["actions"] := []
    MS_Recorder["duration"] := 0
    MS_Recorder["lastEventTime"] := 0

    MS_RecorderHooks := Map()
    MS_RecorderTimers := Map()

    Recorder_RegisterStopHotkey(
        MS_Recorder["stopHotkey"]
    )

    return true
}

; ============================================================
; RECORDING CONFIGURATION
; ============================================================

Recorder_SetOptions(
    keyboard := true,
    mouse := true,
    movement := false,
    delays := true
) {
    global MS_Recorder

    MS_Recorder["keyboardEnabled"] := !!keyboard
    MS_Recorder["mouseEnabled"] := !!mouse
    MS_Recorder["movementEnabled"] := !!movement
    MS_Recorder["delaysEnabled"] := !!delays

    return true
}

; ============================================================
; START RECORDING
; ============================================================

Recorder_Start() {
    global MS_Recorder
    global MS_State
    global MS_RecorderStartTime
    global MS_RecorderLastEvent
    global MS_RecorderStopRequested

    if MS_Recorder["recording"]
        return false

    if !MS_State["enabled"]
        return false

    MS_Recorder["actions"] := []
    MS_Recorder["recording"] := true
    MS_Recorder["startedAt"] := A_TickCount
    MS_Recorder["lastEventTime"] := A_TickCount
    MS_Recorder["duration"] := 0

    MS_RecorderStartTime := A_TickCount
    MS_RecorderLastEvent := A_TickCount
    MS_RecorderStopRequested := false

    if MS_Recorder["keyboardEnabled"]
        Recorder_InstallKeyboardHooks()

    if MS_Recorder["mouseEnabled"]
        Recorder_InstallMouseHooks()

    if MS_Recorder["movementEnabled"]
        Recorder_InstallMovementHooks()

    SetTimer(Recorder_UpdateDuration, 100)

    try {
        ExecutionConsole_Log(
            "INFO",
            "Recording started."
        )
    }

    return true
}

; ============================================================
; STOP RECORDING
; ============================================================

Recorder_Stop() {
    global MS_Recorder
    global MS_RecorderStopRequested

    if !MS_Recorder["recording"]
        return false

    MS_Recorder["recording"] := false
    MS_RecorderStopRequested := true

    SetTimer(Recorder_UpdateDuration, 0)

    Recorder_RemoveHooks()

    MS_Recorder["duration"] :=
        A_TickCount - MS_Recorder["startedAt"]

    Recorder_FinalizeActions()

    try {
        ExecutionConsole_Log(
            "SUCCESS",
            "Recording stopped. Captured "
            . MS_Recorder["actions"].Length
            . " actions."
        )
    }

    return true
}

; ============================================================
; RECORDING STATUS
; ============================================================

Recorder_IsRecording() {
    global MS_Recorder

    return MS_Recorder["recording"]
}

Recorder_GetDuration() {
    global MS_Recorder

    if !MS_Recorder["recording"]
        return MS_Recorder["duration"]

    return A_TickCount - MS_Recorder["startedAt"]
}

Recorder_UpdateDuration() {
    global MS_Recorder

    if !MS_Recorder["recording"] {
        SetTimer(Recorder_UpdateDuration, 0)
        return
    }

    MS_Recorder["duration"] :=
        A_TickCount - MS_Recorder["startedAt"]
}

; ============================================================
; RECORDING STOP HOTKEY
; ============================================================

Recorder_RegisterStopHotkey(stopKey) {
    global MS_Recorder
    global MS_RecorderHooks

    if !stopKey
        return false

    try {
        Hotkey(
            stopKey,
            Recorder_StopHotkey,
            "On"
        )

        MS_RecorderHooks["stop"] := stopKey

        return true
    }
    catch as recError {
        ExecutionConsole_Log(
            "ERROR",
            "Unable to register recording stop hotkey: "
            . recError.Message
        )

        return false
    }
}

Recorder_StopHotkey(*) {
    Recorder_Stop()
}

Recorder_SetStopHotkey(newHotkey) {
    global MS_Recorder
    global MS_RecorderHooks

    oldHotkey := MS_Recorder["stopHotkey"]

    if oldHotkey {
        try {
            Hotkey(oldHotkey, "Off")
        }
    }

    if !Recorder_RegisterStopHotkey(newHotkey)
        return false

    MS_Recorder["stopHotkey"] := newHotkey

    return true
}

; ============================================================
; KEYBOARD HOOKS
; ============================================================

Recorder_InstallKeyboardHooks() {
    global MS_RecorderHooks
    global MS_Recorder

    keys := [
        "a","b","c","d","e","f","g","h","i","j",
        "k","l","m","n","o","p","q","r","s","t",
        "u","v","w","x","y","z",

        "0","1","2","3","4","5","6","7","8","9",

        "Space","Enter","Tab","Escape","Backspace",
        "Delete","Insert","Home","End",
        "PgUp","PgDn",

        "Up","Down","Left","Right",

        "F1","F2","F3","F4","F5","F6",
        "F7","F8","F9","F10","F11","F12",

        "LShift","RShift","LCtrl","RCtrl",
        "LAlt","RAlt",

        "CapsLock","NumLock","ScrollLock",

        "Numpad0","Numpad1","Numpad2",
        "Numpad3","Numpad4","Numpad5",
        "Numpad6","Numpad7","Numpad8",
        "Numpad9","NumpadAdd","NumpadSub",
        "NumpadMult","NumpadDiv","NumpadDot"
    ]

    for keyName in keys {
        downKey := "~*" . keyName
        upKey := "~*" . keyName . " up"

        ; Do not record the stop hotkey itself.
        if MS_Recorder["stopHotkey"] = keyName
            || MS_Recorder["stopHotkey"] = "~*" . keyName
            continue

        try {
            downCallback := Recorder_KeyDown.Bind(keyName)
            upCallback := Recorder_KeyUp.Bind(keyName)

            Hotkey(
                downKey,
                downCallback,
                "On"
            )

            Hotkey(
                upKey,
                upCallback,
                "On"
            )

            MS_RecorderHooks["keyDown:" . keyName] := downKey
            MS_RecorderHooks["keyUp:" . keyName] := upKey
        }
        catch as recError {
            ExecutionConsole_Log(
                "WARNING",
                "Keyboard hook unavailable for "
                . keyName . ": " . recError.Message
            )
        }
    }
}

; ============================================================
; KEYBOARD EVENTS
; ============================================================

Recorder_KeyDown(keyName, *) {
    global MS_Recorder

    if !MS_Recorder["recording"]
        return

    if !MS_Recorder["keyboardEnabled"]
        return

    Recorder_RecordEvent(
        "keyDown",
        Map(
            "key", keyName
        )
    )
}

Recorder_KeyUp(keyName, *) {
    global MS_Recorder

    if !MS_Recorder["recording"]
        return

    if !MS_Recorder["keyboardEnabled"]
        return

    Recorder_RecordEvent(
        "keyUp",
        Map(
            "key", keyName
        )
    )
}

; ============================================================
; MOUSE HOOKS
; ============================================================

Recorder_InstallMouseHooks() {
    global MS_RecorderHooks

    buttons := [
        "LButton",
        "RButton",
        "MButton",
        "XButton1",
        "XButton2"
    ]

    for buttonName in buttons {
        downKey := "~*" . buttonName
        upKey := "~*" . buttonName . " up"

        try {
            downCallback := Recorder_MouseDown.Bind(buttonName)
            upCallback := Recorder_MouseUp.Bind(buttonName)

            Hotkey(
                downKey,
                downCallback,
                "On"
            )

            Hotkey(
                upKey,
                upCallback,
                "On"
            )

            MS_RecorderHooks["mouseDown:" . buttonName] := downKey
            MS_RecorderHooks["mouseUp:" . buttonName] := upKey
        }
        catch as recError {
            ExecutionConsole_Log(
                "WARNING",
                "Mouse hook unavailable for "
                . buttonName . ": " . recError.Message
            )
        }
    }
}

; ============================================================
; MOUSE EVENTS
; ============================================================

Recorder_MouseDown(buttonName, *) {
    global MS_Recorder

    if !MS_Recorder["recording"]
        return

    if !MS_Recorder["mouseEnabled"]
        return

    MouseGetPos(&mouseX, &mouseY)

    Recorder_RecordEvent(
        "mouseDown",
        Map(
            "button", buttonName,
            "x", mouseX,
            "y", mouseY
        )
    )
}

Recorder_MouseUp(buttonName, *) {
    global MS_Recorder

    if !MS_Recorder["recording"]
        return

    if !MS_Recorder["mouseEnabled"]
        return

    MouseGetPos(&mouseX, &mouseY)

    Recorder_RecordEvent(
        "mouseUp",
        Map(
            "button", buttonName,
            "x", mouseX,
            "y", mouseY
        )
    )
}

; ============================================================
; MOUSE MOVEMENT
; ============================================================

Recorder_InstallMovementHooks() {
    SetTimer(
        Recorder_CaptureMouseMovement,
        15
    )
}

Recorder_CaptureMouseMovement() {
    global MS_Recorder

    if !MS_Recorder["recording"] {
        SetTimer(Recorder_CaptureMouseMovement, 0)
        return
    }

    if !MS_Recorder["movementEnabled"]
        return

    MouseGetPos(&mouseX, &mouseY)

    static previousX := -1
    static previousY := -1

    if mouseX = previousX && mouseY = previousY
        return

    previousX := mouseX
    previousY := mouseY

    Recorder_RecordEvent(
        "mouseMove",
        Map(
            "x", mouseX,
            "y", mouseY
        )
    )
}

; ============================================================
; EVENT RECORDING
; ============================================================

Recorder_RecordEvent(actionType, data) {
    global MS_Recorder
    global MS_RecorderLastEvent

    if !MS_Recorder["recording"]
        return false

    currentTime := A_TickCount

    elapsed :=
        currentTime - MS_RecorderLastEvent

    if MS_Recorder["delaysEnabled"] && elapsed > 0 {
        MS_Recorder["actions"].Push(
            Map(
                "type", "delay",
                "duration", elapsed,
                "timestamp", currentTime
            )
        )
    }

    action := Map(
        "type", actionType,
        "data", data,
        "timestamp", currentTime
    )

    MS_Recorder["actions"].Push(action)

    MS_RecorderLastEvent := currentTime
    MS_Recorder["lastEventTime"] := currentTime

    return true
}

; ============================================================
; FINALIZE ACTIONS
; ============================================================

Recorder_FinalizeActions() {
    global MS_Recorder

    recordedActions := MS_Recorder["actions"]

    for actionIndex, recordedAction in recordedActions {
        if !recordedAction.Has("type")
            throw Error(
                "Invalid recorded action at index " . actionIndex
            )

        if !recordedAction.Has("timestamp")
            throw Error(
                "Missing timestamp at index " . actionIndex
            )
    }

    return recordedActions
}

; ============================================================
; GET RECORDED ACTIONS
; ============================================================

Recorder_GetActions() {
    global MS_Recorder

    return MS_Recorder["actions"]
}

Recorder_GetActionCount() {
    global MS_Recorder

    return MS_Recorder["actions"].Length
}

; ============================================================
; CLEAR RECORDING
; ============================================================

Recorder_Clear() {
    global MS_Recorder

    if MS_Recorder["recording"]
        return false

    MS_Recorder["actions"] := []
    MS_Recorder["duration"] := 0

    return true
}

; ============================================================
; EXPORT RECORDING TO EDITOR
; ============================================================

Recorder_ExportToEditor() {
    global MS_Recorder
    global MS_ActiveMacro
    global MS_Editor

    if MS_Recorder["recording"]
        return false

    if MS_Recorder["actions"].Length = 0
        return false

    recordedActions := MS_Recorder["actions"]
    convertedActions := []

    for recordedAction in recordedActions {
        actionData := recordedAction.Has("data")
            ? recordedAction["data"]
            : Map("duration", recordedAction["duration"])

        convertedAction := Map(
            "type", recordedAction["type"],
            "data", actionData,
            "timestamp", recordedAction["timestamp"]
        )

        convertedActions.Push(convertedAction)
    }

    MS_ActiveMacro := Map(
        "id", "recorded_" . A_TickCount,
        "name", "Recorded Macro",
        "actions", convertedActions,
        "createdAt", A_Now,
        "modifiedAt", A_Now
    )

    MS_Editor["actions"] := convertedActions
    MS_Editor["selectedAction"] := 0
    MS_Editor["modified"] := true
    MS_Editor["currentActionCount"] := convertedActions.Length

    return true
}

; ============================================================
; REMOVE ALL RECORDING HOOKS
; ============================================================

Recorder_RemoveHooks() {
    global MS_RecorderHooks
    global MS_Recorder

    for hookName, registeredHotkey in MS_RecorderHooks {
        if hookName = "stop"
            continue

        try {
            Hotkey(registeredHotkey, "Off")
        }
    }

    ; Remove all recording hooks but preserve the stop hotkey.
    stopHotkey := MS_RecorderHooks.Has("stop")
        ? MS_RecorderHooks["stop"]
        : MS_Recorder["stopHotkey"]

    MS_RecorderHooks.Clear()

    if stopHotkey
        Recorder_RegisterStopHotkey(stopHotkey)

    SetTimer(
        Recorder_CaptureMouseMovement,
        0
    )

    return true
}

; ============================================================
; SHUTDOWN
; ============================================================

Recorder_Shutdown() {
    global MS_Recorder

    if !IsObject(MS_Recorder)
        return

    if MS_Recorder["recording"]
        Recorder_Stop()

    Recorder_RemoveHooks()

    try {
        Hotkey(
            MS_Recorder["stopHotkey"],
            "Off"
        )
    }

    MS_Recorder["initialized"] := false

    return true
}

; ============================================================
; END OF Recorder.ahk
; ============================================================
