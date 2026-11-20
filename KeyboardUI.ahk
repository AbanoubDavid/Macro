
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Keyboard Configuration UI
; Keyboard input configuration, key capture, and shortcuts.
; AutoHotkey v2
; ============================================================

KeyboardUI_Initialize() {
    global MS_State, MS_KeyboardUI

    MS_KeyboardUI := Map(
        "ready", true,
        "gui", "",
        "controls", Map(),
        "selectedKey", "",
        "captureActive", false,
        "captureCallback", "",
        "capturedKeys", [],
        "captureMode", "single",
        "lastKey", "",
        "lastKeyTime", 0,
        "repeatEnabled", false,
        "keyHistory", []
    )

    MS_State["keyboardUIReady"] := true

    return true
}

; ------------------------------------------------------------
; Main keyboard configuration window
; ------------------------------------------------------------

KeyboardUI_Create(parentGui := "") {
    global MS_KeyboardUI

    if IsObject(MS_KeyboardUI.Get("gui", "")) {
        try MS_KeyboardUI["gui"].Destroy()
    }

    keyboardGui := Gui("+Resize +MinSize420x350", "Keyboard Configuration")
    keyboardGui.BackColor := "151515"
    keyboardGui.SetFont("s10 cFFFFFF", "Segoe UI")

    keyboardGui.AddText("x15 y15 w380 h25", "Keyboard Configuration")

    keyboardGui.AddText("x15 y55 w100 h22", "Selected key")

    keyInput := keyboardGui.AddEdit(
        "x120 y52 w180 h25 ReadOnly",
        MS_KeyboardUI["selectedKey"]
    )

    captureButton := keyboardGui.AddButton(
        "x310 y52 w100 h25",
        "Capture Key"
    )

    captureButton.OnEvent(
        "Click",
        (*) => KeyboardUI_StartCapture()
    )

    keyboardGui.AddText("x15 y100 w100 h22", "Trigger mode")

    triggerMode := keyboardGui.AddDropDownList(
        "x120 y97 w180 Choose1",
        ["Press", "Hold", "Double Tap"]
    )

    keyboardGui.AddText("x15 y140 w100 h22", "Modifiers")

    modifiers := keyboardGui.AddEdit(
        "x120 y137 w290 h25",
        ""
    )

    keyboardGui.AddText("x15 y180 w380 h22", "Captured key combination")

    combination := keyboardGui.AddEdit(
        "x15 y205 w395 h60 ReadOnly"
    )

    saveButton := keyboardGui.AddButton(
        "x15 y280 w120 h30",
        "Save Configuration"
    )

    clearButton := keyboardGui.AddButton(
        "x145 y280 w100 h30",
        "Clear"
    )

    saveButton.OnEvent("Click", (*) => (
        KeyboardUI_SaveConfiguration(
            keyInput.Value,
            triggerMode.Text,
            modifiers.Value
        )
    ))

    clearButton.OnEvent("Click", (*) => (
        KeyboardUI_ClearSelection()
    ))

    keyboardGui.OnEvent("Close", (*) => KeyboardUI_Close())

    MS_KeyboardUI["gui"] := keyboardGui
    MS_KeyboardUI["controls"] := Map(
        "keyInput", keyInput,
        "triggerMode", triggerMode,
        "modifiers", modifiers,
        "combination", combination,
        "captureButton", captureButton,
        "saveButton", saveButton
    )

    keyboardGui.Show()

    return keyboardGui
}

KeyboardUI_Show() {
    global MS_KeyboardUI

    keyboardGui := MS_KeyboardUI.Get("gui", "")

    if !IsObject(keyboardGui)
        keyboardGui := KeyboardUI_Create()

    keyboardGui.Show()
    return true
}

KeyboardUI_Hide() {
    global MS_KeyboardUI

    keyboardGui := MS_KeyboardUI.Get("gui", "")

    if !IsObject(keyboardGui)
        return false

    keyboardGui.Hide()
    return true
}

KeyboardUI_Close() {
    global MS_KeyboardUI

    MS_KeyboardUI["captureActive"] := false

    keyboardGui := MS_KeyboardUI.Get("gui", "")

    if IsObject(keyboardGui) {
        try keyboardGui.Destroy()
    }

    MS_KeyboardUI["gui"] := ""
    return true
}

; ------------------------------------------------------------
; Key capture
; ------------------------------------------------------------

KeyboardUI_StartCapture(callback := unset, mode := "single") {
    global MS_KeyboardUI

    if MS_KeyboardUI["captureActive"]
        KeyboardUI_StopCapture()

    MS_KeyboardUI["captureActive"] := true
    MS_KeyboardUI["capturedKeys"] := []
    MS_KeyboardUI["captureMode"] := mode

    if IsSet(callback)
        MS_KeyboardUI["captureCallback"] := callback
    else
        MS_KeyboardUI["captureCallback"] := ""

    KeyboardUI_UpdateCaptureButton("Press a key...")

    KeyboardUI_RegisterCaptureHotkeys()

    return true
}

KeyboardUI_RegisterCaptureHotkeys() {
    keys := [
        "a", "b", "c", "d", "e", "f", "g", "h",
        "i", "j", "k", "l", "m", "n", "o", "p",
        "q", "r", "s", "t", "u", "v", "w", "x",
        "y", "z",
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9",
        "F1", "F2", "F3", "F4", "F5", "F6",
        "F7", "F8", "F9", "F10", "F11", "F12",
        "Space", "Enter", "Tab", "Escape",
        "Backspace", "Delete", "Insert",
        "Home", "End", "PgUp", "PgDn",
        "Up", "Down", "Left", "Right",
        "LButton", "RButton", "MButton",
        "XButton1", "XButton2"
    ]

    for keyName in keys {
        try {
            Hotkey(
                "~*" keyName,
                KeyboardUI_CaptureKey.Bind(keyName),
                "On"
            )
        }
    }

    return true
}

KeyboardUI_CaptureKey(key, *) {
    global MS_KeyboardUI

    if !MS_KeyboardUI.Get("captureActive", false)
        return

    captureMode := MS_KeyboardUI["captureMode"]

    if (captureMode = "single") {
        KeyboardUI_StopCapture()
        KeyboardUI_SetSelectedKey(key)
        return
    }

    capturedKeys := MS_KeyboardUI["capturedKeys"]

    if !KeyboardUI_ArrayContains(capturedKeys, key)
        capturedKeys.Push(key)

    KeyboardUI_UpdateCombination()

    if (captureMode = "combination")
        return

    if (captureMode = "multiple")
        return
}

KeyboardUI_StopCapture() {
    global MS_KeyboardUI

    MS_KeyboardUI["captureActive"] := false

    KeyboardUI_UnregisterCaptureHotkeys()
    KeyboardUI_UpdateCaptureButton("Capture Key")

    captureCallback := MS_KeyboardUI.Get("captureCallback", "")

    if IsObject(captureCallback) {
        try captureCallback.Call(MS_KeyboardUI["capturedKeys"])
    }

    MS_KeyboardUI["captureCallback"] := ""

    return true
}

KeyboardUI_UnregisterCaptureHotkeys() {
    keys := [
        "a", "b", "c", "d", "e", "f", "g", "h",
        "i", "j", "k", "l", "m", "n", "o", "p",
        "q", "r", "s", "t", "u", "v", "w", "x",
        "y", "z",
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9",
        "F1", "F2", "F3", "F4", "F5", "F6",
        "F7", "F8", "F9", "F10", "F11", "F12",
        "Space", "Enter", "Tab", "Escape",
        "Backspace", "Delete", "Insert",
        "Home", "End", "PgUp", "PgDn",
        "Up", "Down", "Left", "Right",
        "LButton", "RButton", "MButton",
        "XButton1", "XButton2"
    ]

    for keyName in keys {
        try Hotkey("~*" keyName, "Off")
    }

    return true
}

; ------------------------------------------------------------
; Selected key and combination
; ------------------------------------------------------------

KeyboardUI_SetSelectedKey(key) {
    global MS_KeyboardUI

    if !KeyboardUI_ValidateKey(key)
        return false

    MS_KeyboardUI["selectedKey"] := key

    controls := MS_KeyboardUI["controls"]
    keyInput := controls.Get("keyInput", "")

    if IsObject(keyInput)
        keyInput.Value := key

    MS_KeyboardUI["keyHistory"].Push(key)

    return true
}

KeyboardUI_GetSelectedKey() {
    global MS_KeyboardUI
    return MS_KeyboardUI.Get("selectedKey", "")
}

KeyboardUI_SetCombination(keys) {
    global MS_KeyboardUI

    if !IsObject(keys)
        return false

    validatedKeys := []

    for keyName in keys {
        if !KeyboardUI_ValidateKey(keyName)
            return false

        if !KeyboardUI_ArrayContains(validatedKeys, keyName)
            validatedKeys.Push(keyName)
    }

    MS_KeyboardUI["capturedKeys"] := validatedKeys
    KeyboardUI_UpdateCombination()

    return true
}

KeyboardUI_GetCombination() {
    global MS_KeyboardUI
    return MS_KeyboardUI.Get("capturedKeys", [])
}

KeyboardUI_UpdateCombination() {
    global MS_KeyboardUI

    controls := MS_KeyboardUI["controls"]
    display := controls.Get("combination", "")

    if !IsObject(display)
        return false

    combinationText := ""

    for index, keyName in MS_KeyboardUI["capturedKeys"] {
        if (index > 1)
            combinationText .= " + "

        combinationText .= keyName
    }

    display.Value := combinationText
    return true
}

KeyboardUI_ClearSelection() {
    global MS_KeyboardUI

    MS_KeyboardUI["selectedKey"] := ""
    MS_KeyboardUI["capturedKeys"] := []

    controls := MS_KeyboardUI["controls"]

    for controlName in ["keyInput", "combination"] {
        control := controls.Get(controlName, "")

        if IsObject(control)
            control.Value := ""
    }

    return true
}

; ------------------------------------------------------------
; Configuration persistence
; ------------------------------------------------------------

KeyboardUI_SaveConfiguration(key, triggerMode, modifiers := "") {
    global MS_KeyboardUI, MS_Settings

    if !KeyboardUI_ValidateKey(key)
        return false

    validModes := ["Press", "Hold", "Double Tap"]

    if !KeyboardUI_ArrayContains(validModes, triggerMode)
        return false

    configuration := Map(
        "key", key,
        "triggerMode", triggerMode,
        "modifiers", modifiers,
        "updatedAt", A_Now
    )

    MS_Settings["keyboardConfiguration"] := configuration

    try Settings_Save()

    ExecutionConsole_Log(
        "Keyboard configuration saved: " . key,
        "INFO"
    )

    return true
}

KeyboardUI_GetConfiguration() {
    global MS_Settings

    return MS_Settings.Get(
        "keyboardConfiguration",
        Map(
            "key", "",
            "triggerMode", "Press",
            "modifiers", ""
        )
    )
}

; ------------------------------------------------------------
; Validation and utilities
; ------------------------------------------------------------

KeyboardUI_ValidateKey(key) {
    if !IsString(key) || (key = "")
        return false

    if (StrLen(key) > 40)
        return false

    return RegExMatch(
        key,
        "i)^[a-z0-9]+$|^(Space|Enter|Tab|Escape|Backspace|Delete|Insert|Home|End|PgUp|PgDn|Up|Down|Left|Right|F(?:[1-9]|1[0-9]|2[0-4])|LButton|RButton|MButton|XButton[12])$"
    )
}

KeyboardUI_ArrayContains(array, value) {
    if !IsObject(array)
        return false

    for item in array {
        if (item = value)
            return true
    }

    return false
}

KeyboardUI_UpdateCaptureButton(label) {
    global MS_KeyboardUI

    controls := MS_KeyboardUI["controls"]
    captureButton := controls.Get("captureButton", "")

    if IsObject(captureButton)
        captureButton.Text := label

    return true
}

KeyboardUI_GetKeyHistory() {
    global MS_KeyboardUI
    return MS_KeyboardUI["keyHistory"]
}

KeyboardUI_ClearHistory() {
    global MS_KeyboardUI

    MS_KeyboardUI["keyHistory"] := []
    return true
}

KeyboardUI_Shutdown() {
    global MS_State, MS_KeyboardUI

    if !IsObject(MS_KeyboardUI)
        return true

    if MS_KeyboardUI.Get("captureActive", false)
        KeyboardUI_StopCapture()

    KeyboardUI_Close()

    MS_KeyboardUI["ready"] := false
    MS_State["keyboardUIReady"] := false

    return true
}
