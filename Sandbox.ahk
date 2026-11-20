; ============================================================
; MacroStudio - Macro Sandbox
; Provides isolated macro testing and execution simulation.
; AutoHotkey v2
; ============================================================

Sandbox_Initialize() {
    global MS_State, MS_Sandbox

    if !IsObject(MS_Sandbox)
        MS_Sandbox := Map()

    MS_Sandbox := Map(
        "ready", true,
        "active", false,
        "macroId", "",
        "actions", [],
        "currentIndex", 0,
        "totalActions", 0,
        "results", [],
        "variables", Map(),
        "startTime", 0,
        "endTime", 0,
        "simulateInput", true,
        "simulateDelays", false,
        "simulateConditions", true,
        "stopOnError", false,
        "errors", 0,
        "warnings", 0
    )

    MS_State["sandboxReady"] := true
    MS_State["sandboxActive"] := false

    return true
}

; ------------------------------------------------------------
; Session management
; ------------------------------------------------------------

Sandbox_Start(macroId, options := unset) {
    global MS_State, MS_Macros, MS_Sandbox

    if !MS_State.Get("sandboxReady", false)
        return false

    if MS_Sandbox.Get("active", false)
        return false

    if !MS_Macros.Has(macroId)
        return false

    macro := MS_Macros[macroId]
    actions := macro.Get("actions", [])

    if !IsObject(actions)
        return false

    if IsSet(options) && IsObject(options) {
        for key, value in options {
            if MS_Sandbox.Has(key)
                MS_Sandbox[key] := value
        }
    }

    MS_Sandbox["active"] := true
    MS_Sandbox["macroId"] := macroId
    MS_Sandbox["actions"] := Lib_Clone(actions)
    MS_Sandbox["currentIndex"] := 0
    MS_Sandbox["totalActions"] := actions.Length
    MS_Sandbox["results"] := []
    MS_Sandbox["variables"] := Map()
    MS_Sandbox["startTime"] := A_TickCount
    MS_Sandbox["endTime"] := 0
    MS_Sandbox["errors"] := 0
    MS_Sandbox["warnings"] := 0

    MS_State["sandboxActive"] := true

    ExecutionConsole_Log(
        "Sandbox started for macro: " macro.Get("name", macroId),
        "INFO"
    )

    UI_SetStatus("Sandbox running")

    return true
}

Sandbox_Stop() {
    global MS_State, MS_Sandbox

    if !MS_Sandbox.Get("active", false)
        return false

    MS_Sandbox["active"] := false
    MS_Sandbox["endTime"] := A_TickCount

    MS_State["sandboxActive"] := false

    ExecutionConsole_Log(
        "Sandbox stopped",
        "WARNING"
    )

    UI_SetStatus("Sandbox stopped")

    return true
}

Sandbox_Reset() {
    global MS_State, MS_Sandbox

    if MS_Sandbox.Get("active", false)
        Sandbox_Stop()

    MS_Sandbox["macroId"] := ""
    MS_Sandbox["actions"] := []
    MS_Sandbox["currentIndex"] := 0
    MS_Sandbox["totalActions"] := 0
    MS_Sandbox["results"] := []
    MS_Sandbox["variables"] := Map()
    MS_Sandbox["startTime"] := 0
    MS_Sandbox["endTime"] := 0
    MS_Sandbox["errors"] := 0
    MS_Sandbox["warnings"] := 0

    MS_State["sandboxActive"] := false

    return true
}

; ------------------------------------------------------------
; Simulation engine
; ------------------------------------------------------------

Sandbox_Run() {
    global MS_Sandbox

    if !MS_Sandbox.Get("active", false)
        return false

    actions := MS_Sandbox["actions"]

    if !IsObject(actions)
        return false

    for index, action in actions {
        if !MS_Sandbox.Get("active", false)
            break

        MS_Sandbox["currentIndex"] := index

        result := Sandbox_SimulateAction(action, index)

        Sandbox_RecordResult(index, action, result)

        if !result.Get("success", false) {
            MS_Sandbox["errors"] += 1

            if MS_Sandbox.Get("stopOnError", false)
                break
        }
    }

    Sandbox_Finish()
    return true
}

Sandbox_SimulateAction(action, index := 0) {
    global MS_Sandbox

    result := Map(
        "index", index,
        "success", false,
        "type", "",
        "message", "",
        "simulated", true,
        "timestamp", A_TickCount
    )

    if !IsObject(action) {
        result["message"] := "Invalid action object"
        return result
    }

    actionType := StrLower(action.Get("type", "unknown"))
    result["type"] := actionType

    data := action.Get("data", Map())

    if !IsObject(data) {
        result["message"] := "Action data is invalid"
        return result
    }

    try {
        switch actionType {
            case "delay", "wait":
                success := Sandbox_SimulateDelay(data)

            case "key", "keypress", "keyboard":
                success := Sandbox_SimulateKey(data)

            case "key_down", "keydown", "press_key":
                success := Sandbox_SimulateKey(data)

            case "key_up", "keyup", "release_key":
                success := Sandbox_SimulateKey(data)

            case "key_combo", "combination", "hotkey":
                success := Sandbox_SimulateCombination(data)

            case "mouse", "mouse_click", "click":
                success := Sandbox_SimulateMouse(data)

            case "mouse_down", "mousedown":
                success := Sandbox_SimulateMouse(data)

            case "mouse_up", "mouseup":
                success := Sandbox_SimulateMouse(data)

            case "mouse_move", "mousemove", "move_to", "coordinate":
                success := Sandbox_SimulateMouseMove(data)

            case "condition", "if", "branch":
                success := Sandbox_SimulateCondition(data)

            case "pixel_condition", "pixel":
                success := Sandbox_SimulatePixel(data)

            case "wait_until":
                success := Sandbox_SimulateWaitUntil(data)

            case "repeat", "loop":
                success := Sandbox_SimulateRepeat(data)

            case "chain", "macro_chain":
                success := Sandbox_SimulateChain(data)

            case "comment", "label", "noop":
                success := true

            default:
                success := false
                result["message"] := "Unsupported action type"
        }

        result["success"] := success

        if (result["message"] = "")
            result["message"] := success
                ? "Action simulated successfully"
                : "Action simulation failed"

    } catch as error {
        result["success"] := false
        result["message"] := error.Message
    }

    return result
}

; ------------------------------------------------------------
; Individual action simulations
; ------------------------------------------------------------

Sandbox_SimulateDelay(data) {
    global MS_Sandbox

    duration := data.Get("duration", 0)
    duration := Max(0, Min(3600000, duration))

    if MS_Sandbox.Get("simulateDelays", false)
        Sleep(duration)

    return true
}

Sandbox_SimulateKey(data) {
    key := data.Get("key", "")

    if (key = "")
        return false

    return ActionManager_ValidateKey(key)
}

Sandbox_SimulateCombination(data) {
    keys := data.Get("keys", [])

    if !IsObject(keys) || keys.Length = 0
        return false

    for key in keys {
        if !ActionManager_ValidateKey(key)
            return false
    }

    return true
}

Sandbox_SimulateMouse(data) {
    button := data.Get("button", "Left")

    return ActionManager_ValidateMouseButton(button)
}

Sandbox_SimulateMouseMove(data) {
    x := data.Get("x", unset)
    y := data.Get("y", unset)

    if !IsSet(x) || !IsSet(y)
        return false

    return IsNumber(x) && IsNumber(y)
}

Sandbox_SimulateCondition(data) {
    global MS_Sandbox

    if !MS_Sandbox.Get("simulateConditions", true)
        return true

    condition := data.Get("condition", Map())

    return Logic_EvaluateCondition(condition)
}

Sandbox_SimulatePixel(data) {
    x := data.Get("x", unset)
    y := data.Get("y", unset)
    color := data.Get("color", "")

    if !IsSet(x) || !IsSet(y) || (color = "")
        return false

    return true
}

Sandbox_SimulateWaitUntil(data) {
    global MS_Sandbox

    condition := data.Get("condition", Map())

    if !MS_Sandbox.Get("simulateConditions", true)
        return true

    return IsObject(condition)
}

Sandbox_SimulateRepeat(data) {
    count := data.Get("count", 1)

    return IsNumber(count) && count >= 0
}

Sandbox_SimulateChain(data) {
    chainId := data.Get("chainId", "")

    if (chainId = "")
        return false

    return IsObject(MacroChaining_Get(chainId))
}

; ------------------------------------------------------------
; Results and reporting
; ------------------------------------------------------------

Sandbox_RecordResult(index, action, result) {
    global MS_Sandbox

    entry := Map(
        "index", index,
        "action", Lib_Clone(action),
        "success", result.Get("success", false),
        "type", result.Get("type", ""),
        "message", result.Get("message", ""),
        "timestamp", result.Get("timestamp", A_TickCount)
    )

    MS_Sandbox["results"].Push(entry)

    level := result.Get("success", false) ? "INFO" : "WARNING"

    ExecutionConsole_Log(
        "Sandbox action " index ": " result.Get("message", ""),
        level
    )

    return true
}

Sandbox_Finish() {
    global MS_State, MS_Sandbox

    MS_Sandbox["active"] := false
    MS_Sandbox["endTime"] := A_TickCount

    MS_State["sandboxActive"] := false

    ExecutionConsole_Log(
        "Sandbox finished. Errors: " MS_Sandbox["errors"]
        ", warnings: " MS_Sandbox["warnings"],
        "INFO"
    )

    UI_SetStatus("Sandbox finished")

    return true
}

Sandbox_GetResults() {
    global MS_Sandbox
    return MS_Sandbox.Get("results", [])
}

Sandbox_GetReport() {
    global MS_Sandbox

    elapsed := 0
    startTime := MS_Sandbox.Get("startTime", 0)
    endTime := MS_Sandbox.Get("endTime", 0)

    if (startTime > 0) {
        if (endTime > 0)
            elapsed := endTime - startTime
        else
            elapsed := A_TickCount - startTime
    }

    return Map(
        "macroId", MS_Sandbox.Get("macroId", ""),
        "totalActions", MS_Sandbox.Get("totalActions", 0),
        "completedActions", MS_Sandbox.Get("results", []).Length,
        "errors", MS_Sandbox.Get("errors", 0),
        "warnings", MS_Sandbox.Get("warnings", 0),
        "duration", elapsed,
        "results", MS_Sandbox.Get("results", [])
    )
}

Sandbox_ExportReport(path := "") {
    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Sandbox Report",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        report := Sandbox_GetReport()
        Lib_WriteText(path, JSON.Stringify(report, true))
        return true
    } catch as error {
        ExecutionConsole_Log(
            "Sandbox report export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Configuration
; ------------------------------------------------------------

Sandbox_SetOption(option, value) {
    global MS_Sandbox

    allowed := [
        "simulateInput",
        "simulateDelays",
        "simulateConditions",
        "stopOnError"
    ]

    valid := false

    for item in allowed {
        if (option = item) {
            valid := true
            break
        }
    }

    if !valid
        return false

    MS_Sandbox[option] := value
    return true
}

Sandbox_GetOption(option, defaultValue := unset) {
    global MS_Sandbox

    if MS_Sandbox.Has(option)
        return MS_Sandbox[option]

    return IsSet(defaultValue) ? defaultValue : ""
}

Sandbox_IsActive() {
    global MS_Sandbox
    return MS_Sandbox.Get("active", false)
}

Sandbox_GetProgress() {
    global MS_Sandbox

    current := MS_Sandbox.Get("currentIndex", 0)
    total := MS_Sandbox.Get("totalActions", 0)

    if (total <= 0)
        return 0

    return Round((current / total) * 100)
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

Sandbox_Shutdown() {
    global MS_State, MS_Sandbox

    if MS_Sandbox.Get("active", false)
        Sandbox_Stop()

    MS_Sandbox["ready"] := false
    MS_State["sandboxReady"] := false
    MS_State["sandboxActive"] := false

    return true
}