
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Mouse Configuration UI
; Mouse buttons, movement, coordinates, and trigger settings.
; AutoHotkey v2
; ============================================================

MouseUI_Initialize() {
    global MS_State, MS_MouseUI

    MS_MouseUI := Map(
        "ready", true,
        "gui", "",
        "controls", Map(),
        "selectedButton", "Left",
        "selectedX", 0,
        "selectedY", 0,
        "captureActive", false,
        "captureCallback", "",
        "movementEnabled", true,
        "coordinateMode", "Screen",
        "lastPosition", Map("x", 0, "y", 0),
        "positionHistory", [],
        "buttons", [
            "Left",
            "Right",
            "Middle",
            "XButton1",
            "XButton2"
        ]
    )

    MS_State["mouseUIReady"] := true

    return true
}

; ------------------------------------------------------------
; Main configuration window
; ------------------------------------------------------------

MouseUI_Create(parentGui := "") {
    global MS_MouseUI

    if IsObject(MS_MouseUI.Get("gui", "")) {
        try MS_MouseUI["gui"].Destroy()
    }

    mouseGui := Gui("+Resize +MinSize450x400", "Mouse Configuration")
    mouseGui.BackColor := "151515"
    mouseGui.SetFont("s10 cFFFFFF", "Segoe UI")

    mouseGui.AddText("x15 y15 w400 h25", "Mouse Configuration")

    mouseGui.AddText("x15 y55 w100 h22", "Mouse button")

    buttonList := mouseGui.AddDropDownList(
        "x120 y52 w180 Choose1",
        MS_MouseUI["buttons"]
    )

    mouseGui.AddText("x15 y95 w100 h22", "Trigger mode")

    triggerMode := mouseGui.AddDropDownList(
        "x120 y92 w180 Choose1",
        ["Press", "Hold", "Double Tap"]
    )

    mouseGui.AddText("x15 y140 w100 h22", "Coordinate X")

    xInput := mouseGui.AddEdit(
        "x120 y137 w100 h25 Number",
        "0"
    )

    mouseGui.AddText("x240 y140 w80 h22", "Coordinate Y")

    yInput := mouseGui.AddEdit(
        "x320 y137 w100 h25 Number",
        "0"
    )

    captureButton := mouseGui.AddButton(
        "x15 y185 w130 h28",
        "Capture Position"
    )

    captureButton.OnEvent(
        "Click",
        (*) => MouseUI_StartPositionCapture()
    )

    currentButton := mouseGui.AddButton(
        "x155 y185 w130 h28",
        "Current Position"
    )

    currentButton.OnEvent(
        "Click",
        (*) => MouseUI_GetCurrentPosition()
    )

    mouseGui.AddText("x15 y235 w400 h22", "Coordinate mode")

    coordinateMode := mouseGui.AddDropDownList(
        "x15 y260 w180 Choose1",
        ["Screen", "Window", "Client"]
    )

    movementCheckbox := mouseGui.AddCheckbox(
        "x210 y263 w200 h22 Checked",
        "Enable mouse movement"
    )

    saveButton := mouseGui.AddButton(
        "x15 y320 w120 h30",
        "Save Settings"
    )

    clearButton := mouseGui.AddButton(
        "x145 y320 w100 h30",
        "Reset"
    )

    saveButton.OnEvent(
        "Click",
        (*) => MouseUI_SaveConfiguration(
            buttonList.Text,
            triggerMode.Text,
            xInput.Value,
            yInput.Value,
            coordinateMode.Text,
            movementCheckbox.Value
        )
    )

    clearButton.OnEvent(
        "Click",
        (*) => MouseUI_Reset()
    )

    mouseGui.OnEvent("Close", (*) => MouseUI_Close())

    MS_MouseUI["gui"] := mouseGui

    MS_MouseUI["controls"] := Map(
        "buttonList", buttonList,
        "triggerMode", triggerMode,
        "xInput", xInput,
        "yInput", yInput,
        "captureButton", captureButton,
        "currentButton", currentButton,
        "coordinateMode", coordinateMode,
        "movementCheckbox", movementCheckbox,
        "saveButton", saveButton
    )

    mouseGui.Show()

    return mouseGui
}

MouseUI_Show() {
    global MS_MouseUI

    mouseGui := MS_MouseUI.Get("gui", "")

    if !IsObject(mouseGui)
        mouseGui := MouseUI_Create()

    mouseGui.Show()
    return true
}

MouseUI_Hide() {
    global MS_MouseUI

    mouseGui := MS_MouseUI.Get("gui", "")

    if !IsObject(mouseGui)
        return false

    mouseGui.Hide()
    return true
}

MouseUI_Close() {
    global MS_MouseUI

    if MS_MouseUI.Get("captureActive", false)
        MouseUI_StopPositionCapture()

    mouseGui := MS_MouseUI.Get("gui", "")

    if IsObject(mouseGui) {
        try mouseGui.Destroy()
    }

    MS_MouseUI["gui"] := ""

    return true
}

; ------------------------------------------------------------
; Mouse position
; ------------------------------------------------------------

MouseUI_GetCurrentPosition() {
    global MS_MouseUI

    try {
        MouseGetPos(&mouseX, &mouseY)

        MS_MouseUI["selectedX"] := mouseX
        MS_MouseUI["selectedY"] := mouseY

        MS_MouseUI["lastPosition"] := Map(
            "x", mouseX,
            "y", mouseY
        )

        MouseUI_UpdateCoordinateControls(mouseX, mouseY)
        MouseUI_RecordPosition(mouseX, mouseY)

        return Map("x", mouseX, "y", mouseY)

    } catch {
        return false
    }
}

MouseUI_SetPosition(x, y) {
    global MS_MouseUI

    if !IsNumber(x) || !IsNumber(y)
        return false

    MS_MouseUI["selectedX"] := Round(x)
    MS_MouseUI["selectedY"] := Round(y)

    MouseUI_UpdateCoordinateControls(
        Round(x),
        Round(y)
    )

    return true
}

MouseUI_GetPosition() {
    global MS_MouseUI

    return Map(
        "x", MS_MouseUI["selectedX"],
        "y", MS_MouseUI["selectedY"]
    )
}

MouseUI_UpdateCoordinateControls(x, y) {
    global MS_MouseUI

    controls := MS_MouseUI["controls"]

    xInput := controls.Get("xInput", "")
    yInput := controls.Get("yInput", "")

    if IsObject(xInput)
        xInput.Value := x

    if IsObject(yInput)
        yInput.Value := y

    return true
}

; ------------------------------------------------------------
; Position capture
; ------------------------------------------------------------

MouseUI_StartPositionCapture(callback := unset) {
    global MS_MouseUI

    if MS_MouseUI.Get("captureActive", false)
        MouseUI_StopPositionCapture()

    MS_MouseUI["captureActive"] := true

    if IsSet(callback)
        MS_MouseUI["captureCallback"] := callback
    else
        MS_MouseUI["captureCallback"] := ""

    MouseUI_UpdateCaptureButton("Press F8 to capture")

    try {
        Hotkey(
            "F8",
            MouseUI_CaptureCurrentPosition,
            "On"
        )
    } catch {
        MS_MouseUI["captureActive"] := false
        return false
    }

    return true
}

MouseUI_CaptureCurrentPosition(*) {
    global MS_MouseUI

    if !MS_MouseUI.Get("captureActive", false)
        return

    position := MouseUI_GetCurrentPosition()

    if !IsObject(position)
        return

    captureCallback := MS_MouseUI.Get("captureCallback", "")

    MouseUI_StopPositionCapture()

    if IsObject(captureCallback) {
        try captureCallback.Call(
            position["x"],
            position["y"]
        )
    }

    return
}

MouseUI_StopPositionCapture() {
    global MS_MouseUI

    MS_MouseUI["captureActive"] := false

    try Hotkey("F8", "Off")

    MS_MouseUI["captureCallback"] := ""

    MouseUI_UpdateCaptureButton("Capture Position")

    return true
}

MouseUI_UpdateCaptureButton(label) {
    global MS_MouseUI

    controls := MS_MouseUI["controls"]
    captureButton := controls.Get("captureButton", "")

    if IsObject(captureButton)
        captureButton.Text := label

    return true
}

; ------------------------------------------------------------
; Mouse buttons
; ------------------------------------------------------------

MouseUI_SetButton(button) {
    global MS_MouseUI

    if !MouseUI_ValidateButton(button)
        return false

    MS_MouseUI["selectedButton"] := button

    controls := MS_MouseUI["controls"]
    buttonList := controls.Get("buttonList", "")

    if IsObject(buttonList) {
        for buttonIndex, buttonName in MS_MouseUI["buttons"] {
            if (StrLower(buttonName) = StrLower(button)) {
                buttonList.Choose(buttonIndex)
                break
            }
        }
    }

    return true
}

MouseUI_GetButton() {
    global MS_MouseUI
    return MS_MouseUI["selectedButton"]
}

MouseUI_ValidateButton(button) {
    global MS_MouseUI

    for buttonName in MS_MouseUI["buttons"] {
        if (StrLower(buttonName) = StrLower(button))
            return true
    }

    return false
}

MouseUI_ClickButton(button := "") {
    global MS_MouseUI

    if (button = "")
        button := MS_MouseUI["selectedButton"]

    if !MouseUI_ValidateButton(button)
        return false

    try {
        switch StrLower(button) {
            case "left":
                Click("Left")

            case "right":
                Click("Right")

            case "middle":
                Click("Middle")

            case "xbutton1":
                Click("X1")

            case "xbutton2":
                Click("X2")
        }

        return true
    } catch {
        return false
    }
}

; ------------------------------------------------------------
; Mouse movement
; ------------------------------------------------------------

MouseUI_MoveTo(x, y, speed := 0) {
    global MS_MouseUI

    if !MS_MouseUI.Get("movementEnabled", true)
        return false

    if !IsNumber(x) || !IsNumber(y)
        return false

    try {
        MouseMove(
            Round(x),
            Round(y),
            Max(0, Min(100, speed))
        )

        MouseUI_SetPosition(x, y)

        return true

    } catch {
        return false
    }
}

MouseUI_SetMovementEnabled(enabled) {
    global MS_MouseUI

    MS_MouseUI["movementEnabled"] := !!enabled

    controls := MS_MouseUI["controls"]
    movementCheckbox := controls.Get("movementCheckbox", "")

    if IsObject(movementCheckbox)
        movementCheckbox.Value := !!enabled

    return true
}

MouseUI_IsMovementEnabled() {
    global MS_MouseUI
    return MS_MouseUI.Get("movementEnabled", true)
}

; ------------------------------------------------------------
; Coordinate mode
; ------------------------------------------------------------

MouseUI_SetCoordinateMode(mode) {
    global MS_MouseUI

    validModes := ["Screen", "Window", "Client"]

    if !MouseUI_ArrayContains(validModes, mode)
        return false

    MS_MouseUI["coordinateMode"] := mode

    switch mode {
        case "Screen":
            CoordMode("Mouse", "Screen")

        case "Window":
            CoordMode("Mouse", "Window")

        case "Client":
            CoordMode("Mouse", "Client")
    }

    controls := MS_MouseUI["controls"]
    coordinateDropdown := controls.Get("coordinateMode", "")

    if IsObject(coordinateDropdown) {
        for modeIndex, modeName in validModes {
            if (modeName = mode) {
                coordinateDropdown.Choose(modeIndex)
                break
            }
        }
    }

    return true
}

MouseUI_GetCoordinateMode() {
    global MS_MouseUI
    return MS_MouseUI["coordinateMode"]
}

; ------------------------------------------------------------
; Configuration persistence
; ------------------------------------------------------------

MouseUI_SaveConfiguration(
    button,
    triggerMode,
    x,
    y,
    coordinateMode,
    movementEnabled
) {
    global MS_MouseUI, MS_Settings

    if !MouseUI_ValidateButton(button)
        return false

    if !MouseUI_ValidateTriggerMode(triggerMode)
        return false

    if !IsNumber(x) || !IsNumber(y)
        return false

    if !MouseUI_ArrayContains(
        ["Screen", "Window", "Client"],
        coordinateMode
    )
        return false

    configuration := Map(
        "button", button,
        "triggerMode", triggerMode,
        "x", Round(x),
        "y", Round(y),
        "coordinateMode", coordinateMode,
        "movementEnabled", !!movementEnabled,
        "updatedAt", A_Now
    )

    MS_Settings["mouseConfiguration"] := configuration

    MS_MouseUI["selectedButton"] := button
    MS_MouseUI["selectedX"] := Round(x)
    MS_MouseUI["selectedY"] := Round(y)
    MS_MouseUI["coordinateMode"] := coordinateMode
    MS_MouseUI["movementEnabled"] := !!movementEnabled

    MouseUI_SetCoordinateMode(coordinateMode)

    try Settings_Save()

    ExecutionConsole_Log(
        "Mouse configuration saved",
        "INFO"
    )

    return true
}

MouseUI_GetConfiguration() {
    global MS_Settings

    return MS_Settings.Get(
        "mouseConfiguration",
        Map(
            "button", "Left",
            "triggerMode", "Press",
            "x", 0,
            "y", 0,
            "coordinateMode", "Screen",
            "movementEnabled", true
        )
    )
}

; ------------------------------------------------------------
; Position history
; ------------------------------------------------------------

MouseUI_RecordPosition(x, y) {
    global MS_MouseUI

    MS_MouseUI["positionHistory"].Push(Map(
        "x", x,
        "y", y,
        "timestamp", A_TickCount
    ))

    while (MS_MouseUI["positionHistory"].Length > 100)
        MS_MouseUI["positionHistory"].RemoveAt(1)

    return true
}

MouseUI_GetPositionHistory() {
    global MS_MouseUI
    return MS_MouseUI["positionHistory"]
}

MouseUI_ClearPositionHistory() {
    global MS_MouseUI

    MS_MouseUI["positionHistory"] := []
    return true
}

; ------------------------------------------------------------
; Validation and utilities
; ------------------------------------------------------------

MouseUI_ValidateTriggerMode(mode) {
    return mode = "Press"
        || mode = "Hold"
        || mode = "Double Tap"
}

MouseUI_ArrayContains(array, value) {
    for item in array {
        if (item = value)
            return true
    }

    return false
}

MouseUI_Reset() {
    global MS_MouseUI

    MouseUI_SetButton("Left")
    MouseUI_SetPosition(0, 0)
    MouseUI_SetCoordinateMode("Screen")
    MouseUI_SetMovementEnabled(true)

    controls := MS_MouseUI["controls"]
    triggerDropdown := controls.Get("triggerMode", "")

    if IsObject(triggerDropdown)
        triggerDropdown.Choose(1)

    return true
}

MouseUI_GetStatistics() {
    global MS_MouseUI

    return Map(
        "selectedButton", MS_MouseUI["selectedButton"],
        "selectedX", MS_MouseUI["selectedX"],
        "selectedY", MS_MouseUI["selectedY"],
        "coordinateMode", MS_MouseUI["coordinateMode"],
        "movementEnabled", MS_MouseUI["movementEnabled"],
        "historyCount", MS_MouseUI["positionHistory"].Length
    )
}

MouseUI_Shutdown() {
    global MS_State, MS_MouseUI

    if !IsObject(MS_MouseUI)
        return true

    if MS_MouseUI.Get("captureActive", false)
        MouseUI_StopPositionCapture()

    MouseUI_Close()

    MS_MouseUI["ready"] := false
    MS_State["mouseUIReady"] := false

    return true
}
