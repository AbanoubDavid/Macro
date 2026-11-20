
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Logic.ahk
; Macro conditions, loops, branches and execution logic
; ============================================================

global MS_LogicInitialized := false
global MS_LogicLoopDepth := 0
global MS_LogicMaxLoopDepth := 20

; ============================================================
; INITIALIZATION
; ============================================================

Logic_Initialize() {
    global MS_LogicInitialized
    global MS_LogicLoopDepth

    if MS_LogicInitialized
        return true

    MS_LogicLoopDepth := 0
    MS_LogicInitialized := true

    return true
}

; ============================================================
; CONDITION EVALUATION
; ============================================================

Logic_EvaluateCondition(condition) {
    if !IsObject(condition)
        return false

    if !condition.Has("type")
        return false

    conditionType := condition["type"]

    switch conditionType {
        case "always":
            return true

        case "never":
            return false

        case "pixel":
            return Logic_EvaluatePixelCondition(condition)

        case "window":
            return Logic_EvaluateWindowCondition(condition)

        case "key":
            return Logic_EvaluateKeyCondition(condition)

        case "variable":
            return Logic_EvaluateVariableCondition(condition)

        case "and":
            return Logic_EvaluateAnd(condition)

        case "or":
            return Logic_EvaluateOr(condition)

        case "not":
            return Logic_EvaluateNot(condition)

        case "comparison":
            return Logic_EvaluateComparison(condition)

        default:
            return false
    }
}

; ============================================================
; PIXEL CONDITIONS
; ============================================================

Logic_EvaluatePixelCondition(condition) {
    if !condition.Has("x")
        || !condition.Has("y")
        || !condition.Has("color")
        return false

    pixelX := condition["x"]
    pixelY := condition["y"]
    expectedColor := condition["color"]

    tolerance := condition.Has("tolerance")
        ? condition["tolerance"]
        : 0

    try {
        actualColor := PixelGetColor(pixelX, pixelY, "RGB")
    }
    catch {
        return false
    }

    actualColor := Logic_NormalizeColor(actualColor)
    expectedColor := Logic_NormalizeColor(expectedColor)

    if actualColor = "" || expectedColor = ""
        return false

    return Logic_ColorsMatch(
        actualColor,
        expectedColor,
        tolerance
    )
}

Logic_NormalizeColor(color) {
    if IsNumber(color)
        return Format("{:06X}", color & 0xFFFFFF)

    if Type(color) != "String"
        return ""

    color := StrReplace(Trim(color), "#", "")
    color := StrReplace(color, "0x", "")
    color := StrUpper(color)

    if !RegExMatch(color, "^[0-9A-F]{6}$")
        return ""

    return color
}

Logic_ColorsMatch(colorA, colorB, tolerance := 0) {
    if tolerance < 0
        tolerance := 0

    if tolerance > 255
        tolerance := 255

    redA := Integer("0x" . SubStr(colorA, 1, 2))
    greenA := Integer("0x" . SubStr(colorA, 3, 2))
    blueA := Integer("0x" . SubStr(colorA, 5, 2))

    redB := Integer("0x" . SubStr(colorB, 1, 2))
    greenB := Integer("0x" . SubStr(colorB, 3, 2))
    blueB := Integer("0x" . SubStr(colorB, 5, 2))

    return Abs(redA - redB) <= tolerance
        && Abs(greenA - greenB) <= tolerance
        && Abs(blueA - blueB) <= tolerance
}

; ============================================================
; WINDOW CONDITIONS
; ============================================================

Logic_EvaluateWindowCondition(condition) {
    if !condition.Has("title")
        return false

    windowTitle := condition["title"]

    try {
        if condition.Has("mode")
            windowMode := condition["mode"]
        else
            windowMode := "active"

        switch windowMode {
            case "active":
                return WinActive(windowTitle) != 0

            case "exists":
                return WinExist(windowTitle) != 0

            case "notActive":
                return WinActive(windowTitle) = 0

            case "notExists":
                return WinExist(windowTitle) = 0

            default:
                return false
        }
    }
    catch {
        return false
    }
}

; ============================================================
; KEY CONDITIONS
; ============================================================

Logic_EvaluateKeyCondition(condition) {
    if !condition.Has("key")
        return false

    keyName := condition["key"]

    try {
        keyState := GetKeyState(keyName, "P")

        if condition.Has("expected")
            return keyState = !!condition["expected"]

        return keyState
    }
    catch {
        return false
    }
}

; ============================================================
; VARIABLE CONDITIONS
; ============================================================

Logic_EvaluateVariableCondition(condition) {
    global MS_State

    if !condition.Has("name")
        || !condition.Has("value")
        return false

    variableName := condition["name"]
    expectedValue := condition["value"]

    if Type(variableName) != "String"
        return false

    if !MS_State.Has("variables")
        MS_State["variables"] := Map()

    variables := MS_State["variables"]

    if !variables.Has(variableName)
        return false

    actualValue := variables[variableName]

    comparisonOperator := condition.Has("operator")
        ? condition["operator"]
        : "=="

    return Logic_Compare(
        actualValue,
        comparisonOperator,
        expectedValue
    )
}

; ============================================================
; BOOLEAN CONDITIONS
; ============================================================

Logic_EvaluateAnd(condition) {
    if !condition.Has("conditions")
        return false

    conditionList := condition["conditions"]

    if !IsObject(conditionList)
        return false

    for nestedCondition in conditionList {
        if !Logic_EvaluateCondition(nestedCondition)
            return false
    }

    return true
}

Logic_EvaluateOr(condition) {
    if !condition.Has("conditions")
        return false

    conditionList := condition["conditions"]

    if !IsObject(conditionList)
        return false

    for nestedCondition in conditionList {
        if Logic_EvaluateCondition(nestedCondition)
            return true
    }

    return false
}

Logic_EvaluateNot(condition) {
    if !condition.Has("condition")
        return false

    return !Logic_EvaluateCondition(
        condition["condition"]
    )
}

; ============================================================
; COMPARISON CONDITIONS
; ============================================================

Logic_EvaluateComparison(condition) {
    requiredKeys := ["left", "operator", "right"]

    for requiredKey in requiredKeys {
        if !condition.Has(requiredKey)
            return false
    }

    return Logic_Compare(
        condition["left"],
        condition["operator"],
        condition["right"]
    )
}

Logic_Compare(left, operator, right) {
    switch operator {
        case "==":
            return left = right

        case "!=":
            return left != right

        case ">":
            return left > right

        case "<":
            return left < right

        case ">=":
            return left >= right

        case "<=":
            return left <= right

        case "contains":
            return InStr(
                String(left),
                String(right)
            ) > 0

        case "startsWith":
            return SubStr(
                String(left),
                1,
                StrLen(String(right))
            ) = String(right)

        case "endsWith":
            leftText := String(left)
            rightText := String(right)

            if StrLen(rightText) > StrLen(leftText)
                return false

            return SubStr(
                leftText,
                -StrLen(rightText)
            ) = rightText

        default:
            return false
    }
}

; ============================================================
; WAIT UNTIL CONDITION
; ============================================================

Logic_WaitUntil(condition, timeout := 5000, interval := 25) {
    global MS_State

    startTime := A_TickCount

    if timeout < 0
        timeout := 0

    if interval < 1
        interval := 1

    loop {
        if Logic_EvaluateCondition(condition)
            return true

        if MS_State.Has("shutdown")
            && MS_State["shutdown"]
            return false

        if A_TickCount - startTime >= timeout
            return false

        Sleep(interval)
    }
}

; ============================================================
; CONDITIONAL BRANCHING
; ============================================================

Logic_ExecuteBranch(action) {
    if !IsObject(action)
        return false

    if !action.Has("data")
        return false

    actionData := action["data"]

    if !actionData.Has("condition")
        return false

    conditionResult := Logic_EvaluateCondition(
        actionData["condition"]
    )

    if conditionResult {
        if actionData.Has("trueActions")
            return Logic_ExecuteActionList(
                actionData["trueActions"]
            )
    } else {
        if actionData.Has("falseActions")
            return Logic_ExecuteActionList(
                actionData["falseActions"]
            )
    }

    return true
}

Logic_ExecuteActionList(actions) {
    if !IsObject(actions)
        return false

    for nestedAction in actions {
        if !Logic_ExecuteSingleAction(nestedAction)
            return false
    }

    return true
}

Logic_ExecuteSingleAction(action) {
    if !IsObject(action)
        return false

    if !action.Has("type")
        return false

    try {
        return ActionManager_Execute(action)
    }
    catch as logicError {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Conditional action failed: "
                . logicError.Message
            )
        }

        return false
    }
}

; ============================================================
; REPEAT / LOOP LOGIC
; ============================================================

Logic_ExecuteRepeat(action) {
    global MS_LogicLoopDepth
    global MS_LogicMaxLoopDepth
    global MS_State

    if !IsObject(action)
        return false

    if !action.Has("data")
        return false

    actionData := action["data"]

    if !actionData.Has("count")
        return false

    if !actionData.Has("actions")
        return false

    repeatCount := actionData["count"]

    if !IsNumber(repeatCount) || repeatCount < 1
        return false

    if repeatCount > 100000
        return false

    if MS_LogicLoopDepth >= MS_LogicMaxLoopDepth
        return false

    MS_LogicLoopDepth += 1

    try {
        loop repeatCount {
            if !Logic_ExecuteActionList(actionData["actions"])
                return false

            if MS_State.Has("stopRequested")
                && MS_State["stopRequested"]
                return false
        }

        return true
    }
    finally {
        MS_LogicLoopDepth -= 1
    }
}

; ============================================================
; RANDOMIZED TIMING
; ============================================================

Logic_GetRandomDelay(baseDelay, variation := 0) {
    if !IsNumber(baseDelay)
        baseDelay := 0

    if !IsNumber(variation)
        variation := 0

    if variation < 0
        variation := 0

    minimumDelay := Max(0, baseDelay - variation)
    maximumDelay := Max(minimumDelay, baseDelay + variation)

    return Random(
        Round(minimumDelay),
        Round(maximumDelay)
    )
}

; ============================================================
; RANDOMIZED COORDINATES
; ============================================================

Logic_GetRandomCoordinate(x, y, variation := 0) {
    if variation < 0
        variation := 0

    return Map(
        "x", x + Random(-variation, variation),
        "y", y + Random(-variation, variation)
    )
}

; ============================================================
; VARIABLE MANAGEMENT
; ============================================================

Logic_SetVariable(name, value) {
    global MS_State

    if Type(name) != "String" || !Trim(name)
        return false

    if !MS_State.Has("variables")
        MS_State["variables"] := Map()

    MS_State["variables"][name] := value

    return true
}

Logic_GetVariable(name, defaultValue := unset) {
    global MS_State

    if !MS_State.Has("variables")
        MS_State["variables"] := Map()

    if MS_State["variables"].Has(name)
        return MS_State["variables"][name]

    if IsSet(defaultValue)
        return defaultValue

    return ""
}

Logic_DeleteVariable(name) {
    global MS_State

    if !MS_State.Has("variables")
        return false

    if !MS_State["variables"].Has(name)
        return false

    MS_State["variables"].Delete(name)

    return true
}

Logic_ClearVariables() {
    global MS_State

    MS_State["variables"] := Map()

    return true
}

; ============================================================
; CONDITION BUILDERS
; ============================================================

Logic_CreatePixelCondition(x, y, color, tolerance := 0) {
    return Map(
        "type", "pixel",
        "x", x,
        "y", y,
        "color", color,
        "tolerance", tolerance
    )
}

Logic_CreateWindowCondition(title, mode := "active") {
    return Map(
        "type", "window",
        "title", title,
        "mode", mode
    )
}

Logic_CreateKeyCondition(key, expected := true) {
    return Map(
        "type", "key",
        "key", key,
        "expected", expected
    )
}

Logic_CreateComparison(left, operator, right) {
    return Map(
        "type", "comparison",
        "left", left,
        "operator", operator,
        "right", right
    )
}

Logic_CreateAnd(conditions) {
    return Map(
        "type", "and",
        "conditions", conditions
    )
}

Logic_CreateOr(conditions) {
    return Map(
        "type", "or",
        "conditions", conditions
    )
}

Logic_CreateNot(condition) {
    return Map(
        "type", "not",
        "condition", condition
    )
}

; ============================================================
; SHUTDOWN
; ============================================================

Logic_Shutdown() {
    global MS_LogicInitialized
    global MS_LogicLoopDepth

    MS_LogicLoopDepth := 0
    MS_LogicInitialized := false

    return true
}

; ============================================================
; END OF Logic.ahk
; ============================================================
