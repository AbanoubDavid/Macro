; ============================================================
; MacroStudio - Conditional Branching
; Executes different action sequences based on conditions.
; AutoHotkey v2
; ============================================================

ConditionalBranching_Initialize() {
    global MS_State

    MS_State["conditionalBranchingReady"] := true
    MS_State["branchDepth"] := 0
    MS_State["branchDepthLimit"] := 20
    MS_State["branchExecutionCount"] := 0

    return true
}

; ------------------------------------------------------------
; Branch execution
; ------------------------------------------------------------

ConditionalBranching_Execute(branch) {
    global MS_State

    if !MS_State.Get("conditionalBranchingReady", false)
        return false

    if !IsObject(branch)
        return false

    depth := MS_State.Get("branchDepth", 0)

    if (depth >= MS_State.Get("branchDepthLimit", 20)) {
        ExecutionConsole_Log(
            "Maximum conditional branch depth reached",
            "WARNING"
        )
        return false
    }

    condition := branch.Get("condition", Map())

    MS_State["branchDepth"] := depth + 1

    try {
        result := Logic_EvaluateCondition(condition)

        if result {
            actions := branch.Get("trueActions", [])
            branchName := "true"
        } else {
            actions := branch.Get("falseActions", [])
            branchName := "false"
        }

        MS_State["branchExecutionCount"] :=
            MS_State.Get("branchExecutionCount", 0) + 1

        ExecutionConsole_Log(
            "Conditional branch selected: " branchName,
            "INFO"
        )

        return ConditionalBranching_ExecuteActions(actions)
    } catch as error {
        ExecutionConsole_Log(
            "Conditional branch failed: " error.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["branchDepth"] := depth
    }
}

ConditionalBranching_ExecuteActions(actions) {
    if !IsObject(actions)
        return false

    for action in actions {
        if !ActionManager_CheckStop()
            return false

        if !IsObject(action)
            continue

        if !action.Get("enabled", true)
            continue

        if !ActionManager_Execute(action)
            return false
    }

    return true
}

; ------------------------------------------------------------
; Branch creation
; ------------------------------------------------------------

ConditionalBranching_Create(condition := unset) {
    return Map(
        "id", Lib_GenerateId("branch"),
        "type", "branch",
        "condition", IsSet(condition) && IsObject(condition)
            ? condition
            : Map(),
        "trueActions", [],
        "falseActions", [],
        "createdAt", Lib_GetTimestamp()
    )
}

ConditionalBranching_CreateCondition(
    conditionType,
    property := "",
    operator := "equals",
    value := ""
) {
    return Map(
        "type", conditionType,
        "property", property,
        "operator", operator,
        "value", value
    )
}

ConditionalBranching_CreateComparison(
    left,
    operator,
    right
) {
    return Map(
        "type", "comparison",
        "left", left,
        "operator", operator,
        "right", right
    )
}

ConditionalBranching_CreateLogical(
    operator,
    conditions
) {
    operator := StrLower(operator)

    if (operator != "and" && operator != "or")
        return false

    if !IsObject(conditions)
        return false

    return Map(
        "type", operator,
        "conditions", conditions
    )
}

ConditionalBranching_CreateNot(condition) {
    if !IsObject(condition)
        return false

    return Map(
        "type", "not",
        "condition", condition
    )
}

; ------------------------------------------------------------
; Branch action management
; ------------------------------------------------------------

ConditionalBranching_AddAction(branch, action, branchType := "true") {
    if !IsObject(branch) || !IsObject(action)
        return false

    branchType := StrLower(branchType)

    if (branchType = "true")
        key := "trueActions"
    else if (branchType = "false")
        key := "falseActions"
    else
        return false

    actions := branch.Get(key, [])

    if !IsObject(actions)
        actions := []

    actions.Push(action)
    branch[key] := actions

    return true
}

ConditionalBranching_RemoveAction(branch, index, branchType := "true") {
    if !IsObject(branch)
        return false

    branchType := StrLower(branchType)
    key := branchType = "true" ? "trueActions" : "falseActions"

    if (branchType != "true" && branchType != "false")
        return false

    actions := branch.Get(key, [])

    if !IsObject(actions)
        return false

    if (index < 1 || index > actions.Length)
        return false

    actions.RemoveAt(index)
    branch[key] := actions

    return true
}

ConditionalBranching_MoveAction(
    branch,
    sourceIndex,
    targetIndex,
    branchType := "true"
) {
    if !IsObject(branch)
        return false

    branchType := StrLower(branchType)
    key := branchType = "true" ? "trueActions" : "falseActions"

    if (branchType != "true" && branchType != "false")
        return false

    actions := branch.Get(key, [])

    if !IsObject(actions)
        return false

    if (sourceIndex < 1 || sourceIndex > actions.Length)
        return false

    if (targetIndex < 1 || targetIndex > actions.Length)
        return false

    if (sourceIndex = targetIndex)
        return true

    moved := actions.RemoveAt(sourceIndex)
    actions.InsertAt(targetIndex, moved)

    branch[key] := actions

    return true
}

ConditionalBranching_SetCondition(branch, condition) {
    if !IsObject(branch) || !IsObject(condition)
        return false

    branch["condition"] := condition
    return true
}

ConditionalBranching_GetActions(branch, branchType := "true") {
    if !IsObject(branch)
        return []

    branchType := StrLower(branchType)

    if (branchType = "true")
        return branch.Get("trueActions", [])

    if (branchType = "false")
        return branch.Get("falseActions", [])

    return []
}

; ------------------------------------------------------------
; Condition evaluation helpers
; ------------------------------------------------------------

ConditionalBranching_Evaluate(condition) {
    if !IsObject(condition)
        return false

    try {
        return Logic_EvaluateCondition(condition)
    } catch as error {
        ExecutionConsole_Log(
            "Condition evaluation failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

ConditionalBranching_EvaluateAll(conditions) {
    if !IsObject(conditions)
        return false

    for condition in conditions {
        if !ConditionalBranching_Evaluate(condition)
            return false
    }

    return true
}

ConditionalBranching_EvaluateAny(conditions) {
    if !IsObject(conditions)
        return false

    for condition in conditions {
        if ConditionalBranching_Evaluate(condition)
            return true
    }

    return false
}

ConditionalBranching_EvaluateNot(condition) {
    return !ConditionalBranching_Evaluate(condition)
}

; ------------------------------------------------------------
; Validation and statistics
; ------------------------------------------------------------

ConditionalBranching_Validate(branch) {
    if !IsObject(branch)
        return false

    if !branch.Has("condition")
        return false

    if !branch.Has("trueActions") || !branch.Has("falseActions")
        return false

    if !IsObject(branch["condition"])
        return false

    if !IsObject(branch["trueActions"])
        return false

    if !IsObject(branch["falseActions"])
        return false

    return true
}

ConditionalBranching_GetExecutionCount() {
    global MS_State
    return MS_State.Get("branchExecutionCount", 0)
}

ConditionalBranching_ResetStatistics() {
    global MS_State

    MS_State["branchExecutionCount"] := 0
    return true
}

ConditionalBranching_GetDepth() {
    global MS_State
    return MS_State.Get("branchDepth", 0)
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

ConditionalBranching_Shutdown() {
    global MS_State

    MS_State["conditionalBranchingReady"] := false
    MS_State["branchDepth"] := 0

    return true
}