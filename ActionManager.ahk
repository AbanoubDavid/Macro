
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Action Manager
; Handles execution, validation, creation and management
; of individual macro actions.
; AutoHotkey v2
; ============================================================

ActionManager_Initialize() {
    global MS_State

    MS_State["actionManagerReady"] := true
    MS_State["actionExecutionCount"] := 0
    MS_State["lastExecutedAction"] := ""
    return true
}

; ------------------------------------------------------------
; Main execution dispatcher
; ------------------------------------------------------------

ActionManager_Execute(action, context := unset) {
    global MS_State

    if !IsObject(action)
        return false

    if !action.Has("type")
        return false

    actionType := StrLower(action["type"])
    data := action.Has("data") && IsObject(action["data"])
        ? action["data"]
        : Map()

    try {
        switch actionType {
            case "key", "keypress", "keyboard":
                result := ActionManager_ExecuteKey(data)

            case "key_down", "keydown", "press_key":
                result := ActionManager_KeyDown(data)

            case "key_up", "keyup", "release_key":
                result := ActionManager_KeyUp(data)

            case "key_combo", "combination", "hotkey":
                result := ActionManager_ExecuteCombination(data)

            case "mouse", "mouse_click", "click":
                result := ActionManager_ExecuteMouse(data)

            case "mouse_down", "mousedown":
                result := ActionManager_MouseDown(data)

            case "mouse_up", "mouseup":
                result := ActionManager_MouseUp(data)

            case "mouse_move", "mousemove":
                result := ActionManager_MouseMove(data)

            case "move_to", "coordinate":
                result := ActionManager_MoveTo(data)

            case "delay", "wait":
                result := ActionManager_ExecuteDelay(data)

            case "pixel_condition", "pixel":
                result := ActionManager_ExecutePixelCondition(data)

            case "wait_until":
                result := ActionManager_ExecuteWaitUntil(data)

            case "condition", "if":
                result := ActionManager_ExecuteCondition(data)

            case "branch":
                result := ActionManager_ExecuteBranch(data)

            case "repeat", "loop":
                result := ActionManager_ExecuteRepeat(data)

            case "chain", "macro_chain":
                result := ActionManager_ExecuteChain(data)

            case "comment", "label", "noop":
                result := true

            default:
                ExecutionConsole_Log(
                    "Unknown action type: " . actionType,
                    "WARNING"
                )
                return false
        }

        MS_State["actionExecutionCount"] :=
            MS_State.Get("actionExecutionCount", 0) + 1

        MS_State["lastExecutedAction"] := actionType

        return result
    }
    catch as actionError {
        ExecutionConsole_Log(
            "Action execution failed (" . actionType . "): " . actionError.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Keyboard actions
; ------------------------------------------------------------

ActionManager_ExecuteKey(data) {
    key := ActionManager_GetValue(data, "key", "")

    if (key = "")
        return false

    mode := StrLower(ActionManager_GetValue(data, "mode", "press"))

    switch mode {
        case "down", "hold":
            return ActionManager_KeyDown(data)

        case "up", "release":
            return ActionManager_KeyUp(data)

        default:
            return ActionManager_SendKey(key)
    }
}

ActionManager_KeyDown(data) {
    key := ActionManager_GetValue(data, "key", "")

    if (key = "")
        return false

    return ActionManager_SendKeyDown(key)
}

ActionManager_KeyUp(data) {
    key := ActionManager_GetValue(data, "key", "")

    if (key = "")
        return false

    return ActionManager_SendKeyUp(key)
}

ActionManager_ExecuteCombination(data) {
    keys := ActionManager_GetValue(data, "keys", [])

    if !IsObject(keys) || keys.Length = 0
        return false

    pressedKeys := []

    try {
        for key in keys {
            if (key = "")
                continue

            ActionManager_SendKeyDown(key)
            pressedKeys.Push(key)
        }

        duration := ActionManager_GetValue(data, "duration", 40)

        if (duration > 0)
            ActionManager_InterruptibleSleep(duration)

        return true
    } finally {
        Loop pressedKeys.Length {
            key := pressedKeys[pressedKeys.Length - A_Index + 1]

            try ActionManager_SendKeyUp(key)
        }
    }
}

ActionManager_SendKey(key) {
    if !ActionManager_ValidateKey(key)
        return false

    try {
        return InputHandler_SendKey(key)
    } catch {
        return false
    }
}

ActionManager_SendKeyDown(key) {
    if !ActionManager_ValidateKey(key)
        return false

    try {
        return InputHandler_SendKeyDown(key)
    } catch {
        return false
    }
}

ActionManager_SendKeyUp(key) {
    if !ActionManager_ValidateKey(key)
        return false

    try {
        return InputHandler_SendKeyUp(key)
    } catch {
        return false
    }
}

ActionManager_ValidateKey(key) {
    if !IsObject(key) && (key != "")
        return true

    return false
}

; ------------------------------------------------------------
; Mouse actions
; ------------------------------------------------------------

ActionManager_ExecuteMouse(data) {
    button := ActionManager_GetValue(data, "button", "Left")
    count := ActionManager_GetValue(data, "count", 1)
    x := ActionManager_GetValue(data, "x", unset)
    y := ActionManager_GetValue(data, "y", unset)

    if !ActionManager_ValidateMouseButton(button)
        return false

    if (IsSet(x) && IsSet(y))
        MouseMove(x, y, 0)

    count := Max(1, Min(100, count))

    Loop count {
        if !ActionManager_CheckStop()
            return false

        Click(button)
    }

    return true
}

ActionManager_MouseDown(data) {
    button := ActionManager_GetValue(data, "button", "Left")

    if !ActionManager_ValidateMouseButton(button)
        return false

    try {
        Click(button . " Down")
        return true
    } catch {
        return false
    }
}

ActionManager_MouseUp(data) {
    button := ActionManager_GetValue(data, "button", "Left")

    if !ActionManager_ValidateMouseButton(button)
        return false

    try {
        Click(button . " Up")
        return true
    } catch {
        return false
    }
}

ActionManager_MouseMove(data) {
    x := ActionManager_GetValue(data, "x", unset)
    y := ActionManager_GetValue(data, "y", unset)
    speed := ActionManager_GetValue(data, "speed", 0)

    if !IsSet(x) || !IsSet(y)
        return false

    return ActionManager_MoveTo(data, speed)
}

ActionManager_MoveTo(data, speed := unset) {
    x := ActionManager_GetValue(data, "x", unset)
    y := ActionManager_GetValue(data, "y", unset)

    if !IsSet(x) || !IsSet(y)
        return false

    if !IsSet(speed)
        speed := ActionManager_GetValue(data, "speed", 0)

    try {
        MouseMove(x, y, speed)
        return true
    } catch {
        return false
    }
}

ActionManager_ValidateMouseButton(button) {
    allowed := ["Left", "Right", "Middle", "X1", "X2"]

    for item in allowed {
        if (StrLower(button) = StrLower(item))
            return true
    }

    return false
}

; ------------------------------------------------------------
; Delay and waiting actions
; ------------------------------------------------------------

ActionManager_ExecuteDelay(data) {
    duration := ActionManager_GetValue(data, "duration", 100)

    duration := Max(0, Min(3600000, duration))

    return ActionManager_InterruptibleSleep(duration)
}

ActionManager_InterruptibleSleep(duration) {
    remaining := Max(0, duration)

    while (remaining > 0) {
        if !ActionManager_CheckStop()
            return false

        interval := Min(remaining, 25)
        Sleep(interval)
        remaining -= interval
    }

    return ActionManager_CheckStop()
}

ActionManager_ExecuteWaitUntil(data) {
    timeout := ActionManager_GetValue(data, "timeout", 10000)
    interval := ActionManager_GetValue(data, "interval", 50)
    condition := ActionManager_GetValue(data, "condition", Map())

    timeout := Max(1, Min(3600000, timeout))
    interval := Max(10, Min(5000, interval))

    startTime := A_TickCount

    while ((A_TickCount - startTime) < timeout) {
        if !ActionManager_CheckStop()
            return false

        if Logic_EvaluateCondition(condition)
            return true

        Sleep(interval)
    }

    return ActionManager_GetValue(data, "onTimeout", "continue") != "stop"
}

; ------------------------------------------------------------
; Pixel and condition actions
; ------------------------------------------------------------

ActionManager_ExecutePixelCondition(data) {
    x := ActionManager_GetValue(data, "x", unset)
    y := ActionManager_GetValue(data, "y", unset)
    expectedColor := ActionManager_GetValue(data, "color", "")
    tolerance := ActionManager_GetValue(data, "tolerance", 0)
    timeout := ActionManager_GetValue(data, "timeout", 5000)

    if !IsSet(x) || !IsSet(y) || (expectedColor = "")
        return false

    startTime := A_TickCount

    while ((A_TickCount - startTime) < timeout) {
        if !ActionManager_CheckStop()
            return false

        actualColor := PixelPicker_GetPixelColor(x, y)

        if PixelPicker_CompareColors(
            actualColor,
            expectedColor,
            tolerance
        )
            return true

        Sleep(50)
    }

    return ActionManager_GetValue(data, "onTimeout", "continue") != "stop"
}

ActionManager_ExecuteCondition(data) {
    condition := ActionManager_GetValue(data, "condition", Map())

    try {
        return Logic_EvaluateCondition(condition)
    } catch {
        return false
    }
}

ActionManager_ExecuteBranch(data) {
    return Logic_ExecuteBranch(data)
}

ActionManager_ExecuteRepeat(data) {
    return Logic_ExecuteRepeat(data)
}

ActionManager_ExecuteChain(data) {
    chainId := ActionManager_GetValue(data, "chainId", "")

    if (chainId = "")
        return false

    return MacroChaining_Execute(chainId)
}

; ------------------------------------------------------------
; Action construction
; ------------------------------------------------------------

ActionManager_Create(actionType, data := unset) {
    action := Map(
        "id", Lib_GenerateId("action"),
        "type", actionType,
        "data", IsSet(data) && IsObject(data) ? data : Map(),
        "enabled", true,
        "createdAt", Lib_GetTimestamp()
    )

    return action
}

ActionManager_CreateKey(key, mode := "press") {
    return ActionManager_Create(
        "key",
        Map(
            "key", key,
            "mode", mode
        )
    )
}

ActionManager_CreateCombination(keys, duration := 40) {
    return ActionManager_Create(
        "key_combo",
        Map(
            "keys", keys,
            "duration", duration
        )
    )
}

ActionManager_CreateMouse(button := "Left", x := unset, y := unset) {
    data := Map(
        "button", button,
        "count", 1
    )

    if IsSet(x) && IsSet(y) {
        data["x"] := x
        data["y"] := y
    }

    return ActionManager_Create("mouse", data)
}

ActionManager_CreateMouseMove(x, y, speed := 0) {
    return ActionManager_Create(
        "mouse_move",
        Map(
            "x", x,
            "y", y,
            "speed", speed
        )
    )
}

ActionManager_CreateDelay(duration) {
    return ActionManager_Create(
        "delay",
        Map("duration", duration)
    )
}

ActionManager_CreatePixelCondition(x, y, color, tolerance := 0) {
    return ActionManager_Create(
        "pixel_condition",
        Map(
            "x", x,
            "y", y,
            "color", color,
            "tolerance", tolerance
        )
    )
}

; ------------------------------------------------------------
; Validation and utility functions
; ------------------------------------------------------------

ActionManager_Validate(action) {
    if !IsObject(action)
        return false

    if !action.Has("type")
        return false

    if !action.Has("data") || !IsObject(action["data"])
        return false

    allowedTypes := [
        "key", "keypress", "keyboard",
        "key_down", "keydown", "press_key",
        "key_up", "keyup", "release_key",
        "key_combo", "combination", "hotkey",
        "mouse", "mouse_click", "click",
        "mouse_down", "mousedown",
        "mouse_up", "mouseup",
        "mouse_move", "mousemove",
        "move_to", "coordinate",
        "delay", "wait",
        "pixel_condition", "pixel",
        "wait_until", "condition", "if",
        "branch", "repeat", "loop",
        "chain", "macro_chain",
        "comment", "label", "noop"
    ]

    actionType := StrLower(action["type"])

    for allowedType in allowedTypes {
        if (actionType = allowedType)
            return true
    }

    return false
}

ActionManager_GetValue(data, key, defaultValue := unset) {
    if IsObject(data) && data.Has(key)
        return data[key]

    if IsSet(defaultValue)
        return defaultValue

    return ""
}

ActionManager_CheckStop() {
    global MS_State

    if MS_State.Get("stopRequested", false)
        return false

    if !MS_State.Get("enabled", true)
        return false

    return true
}

ActionManager_Clone(action) {
    return Lib_Clone(action)
}

ActionManager_GetExecutionCount() {
    global MS_State
    return MS_State.Get("actionExecutionCount", 0)
}

ActionManager_GetLastExecuted() {
    global MS_State
    return MS_State.Get("lastExecutedAction", "")
}

ActionManager_ResetStatistics() {
    global MS_State

    MS_State["actionExecutionCount"] := 0
    MS_State["lastExecutedAction"] := ""

    return true
}

ActionManager_Shutdown() {
    global MS_State

    MS_State["actionManagerReady"] := false
    return true
}
