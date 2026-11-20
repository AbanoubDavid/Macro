
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Editor.ahk
; Macro action editing and management
; ============================================================

global MS_EditorClipboard := []
global MS_EditorUndoSnapshot := []
global MS_EditorInitialized := false

; ============================================================
; INITIALIZATION
; ============================================================

Editor_Initialize() {
    global MS_Editor
    global MS_EditorInitialized

    if MS_EditorInitialized
        return true

    MS_Editor["modified"] := false
    MS_Editor["selectedAction"] := 0
    MS_Editor["currentActionCount"] := 0
    MS_Editor["speedMultiplier"] := 1.0
    MS_Editor["actions"] := []
    MS_Editor["clipboard"] := []

    MS_EditorInitialized := true

    return true
}

; ============================================================
; MACRO SELECTION
; ============================================================

Editor_LoadMacro(macroId) {
    global MS_Macros
    global MS_ActiveMacro
    global MS_ActiveMacroId
    global MS_SelectedMacroId
    global MS_Editor

    if !MS_Macros.Has(macroId)
        return false

    macro := MS_Macros[macroId]

    if !IsObject(macro)
        return false

    if !macro.Has("actions")
        return false

    MS_ActiveMacro := macro
    MS_ActiveMacroId := macroId
    MS_SelectedMacroId := macroId

    MS_Editor["actions"] := Editor_CloneActions(
        macro["actions"]
    )

    MS_Editor["selectedAction"] := 0
    MS_Editor["currentActionCount"] :=
        MS_Editor["actions"].Length

    MS_Editor["modified"] := false

    return true
}

Editor_NewMacro(name := "New Macro") {
    global MS_ActiveMacro
    global MS_ActiveMacroId
    global MS_Editor

    if !Trim(name)
        name := "New Macro"

    macroId := "macro_" . A_TickCount

    macro := Map(
        "id", macroId,
        "name", name,
        "actions", [],
        "createdAt", A_Now,
        "modifiedAt", A_Now,
        "enabled", true,
        "trigger", Map(
            "type", "none",
            "key", ""
        )
    )

    MS_ActiveMacro := macro
    MS_ActiveMacroId := macroId

    MS_Editor["actions"] := []
    MS_Editor["selectedAction"] := 0
    MS_Editor["currentActionCount"] := 0
    MS_Editor["modified"] := true

    return macroId
}

; ============================================================
; ACTION CREATION
; ============================================================

Editor_CreateAction(actionType, data := unset) {
    if !IsSet(data)
        data := Map()

    if !IsObject(data)
        throw TypeError("Action data must be an object.")

    action := Map(
        "id", "action_" . A_TickCount . "_" . Random(1000, 9999),
        "type", actionType,
        "data", Editor_CloneValue(data),
        "enabled", true
    )

    return action
}

Editor_AddAction(actionType, data := unset, position := 0) {
    global MS_Editor

    action := Editor_CreateAction(actionType, data)
    actions := MS_Editor["actions"]

    if position <= 0 || position > actions.Length
        actions.Push(action)
    else
        actions.InsertAt(position, action)

    Editor_MarkModified()

    MS_Editor["currentActionCount"] := actions.Length
    MS_Editor["selectedAction"] :=
        Editor_FindActionIndex(action["id"])

    Editor_NotifyUndoRedo("Add action")

    return action["id"]
}

Editor_AddDelay(milliseconds := 100) {
    if milliseconds < 0
        milliseconds := 0

    return Editor_AddAction(
        "delay",
        Map("duration", milliseconds)
    )
}

Editor_AddKeyPress(key, holdDuration := 0) {
    return Editor_AddAction(
        "keyPress",
        Map(
            "key", key,
            "holdDuration", holdDuration
        )
    )
}

Editor_AddKeyDown(key) {
    return Editor_AddAction(
        "keyDown",
        Map("key", key)
    )
}

Editor_AddKeyUp(key) {
    return Editor_AddAction(
        "keyUp",
        Map("key", key)
    )
}

Editor_AddMouseClick(button := "LButton", x := unset, y := unset) {
    data := Map("button", button)

    if IsSet(x) && IsSet(y) {
        data["x"] := x
        data["y"] := y
        data["useCoordinates"] := true
    } else {
        data["useCoordinates"] := false
    }

    return Editor_AddAction("mouseClick", data)
}

Editor_AddMouseMove(x, y, duration := 0) {
    return Editor_AddAction(
        "mouseMove",
        Map(
            "x", x,
            "y", y,
            "duration", duration
        )
    )
}

Editor_AddPixelCondition(x, y, color, tolerance := 0) {
    return Editor_AddAction(
        "pixelCondition",
        Map(
            "x", x,
            "y", y,
            "color", color,
            "tolerance", tolerance
        )
    )
}

Editor_AddWaitUntil(condition, timeout := 5000) {
    return Editor_AddAction(
        "waitUntil",
        Map(
            "condition", condition,
            "timeout", timeout
        )
    )
}

Editor_AddRepeat(count := 2) {
    return Editor_AddAction(
        "repeat",
        Map("count", count)
    )
}

; ============================================================
; ACTION RETRIEVAL
; ============================================================

Editor_GetActions() {
    global MS_Editor

    return MS_Editor["actions"]
}

Editor_GetAction(index) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    return actions[index]
}

Editor_GetActionCount() {
    global MS_Editor

    return MS_Editor["actions"].Length
}

Editor_GetSelectedAction() {
    global MS_Editor

    index := MS_Editor["selectedAction"]

    if index < 1 || index > MS_Editor["actions"].Length
        return false

    return MS_Editor["actions"][index]
}

; ============================================================
; ACTION SELECTION
; ============================================================

Editor_SelectAction(index) {
    global MS_Editor

    if index < 1 || index > MS_Editor["actions"].Length
        return false

    MS_Editor["selectedAction"] := index

    return true
}

Editor_FindActionIndex(actionId) {
    global MS_Editor

    for index, action in MS_Editor["actions"] {
        if action.Has("id") && action["id"] = actionId
            return index
    }

    return 0
}

; ============================================================
; ACTION MODIFICATION
; ============================================================

Editor_UpdateAction(index, actionType := unset, data := unset) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    action := actions[index]

    if IsSet(actionType) {
        if !IsString(actionType) || !Trim(actionType)
            return false

        action["type"] := actionType
    }

    if IsSet(data) {
        if !IsObject(data)
            return false

        action["data"] := Editor_CloneValue(data)
    }

    actions[index] := action

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Update action")

    return true
}

Editor_UpdateActionData(index, key, value) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    action := actions[index]

    if !action.Has("data") || !IsObject(action["data"])
        action["data"] := Map()

    action["data"][key] := value
    actions[index] := action

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Update action data")

    return true
}

Editor_ToggleAction(index) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    action := actions[index]
    action["enabled"] := !action["enabled"]

    actions[index] := action

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Toggle action")

    return action["enabled"]
}

; ============================================================
; ACTION DELETION
; ============================================================

Editor_DeleteAction(index) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    actions.RemoveAt(index)

    MS_Editor["currentActionCount"] := actions.Length

    if MS_Editor["selectedAction"] > actions.Length
        MS_Editor["selectedAction"] := actions.Length

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Delete action")

    return true
}

Editor_DeleteSelectedAction() {
    global MS_Editor

    index := MS_Editor["selectedAction"]

    if index < 1
        return false

    return Editor_DeleteAction(index)
}

Editor_ClearActions() {
    global MS_Editor

    MS_Editor["actions"] := []
    MS_Editor["selectedAction"] := 0
    MS_Editor["currentActionCount"] := 0

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Clear actions")

    return true
}

; ============================================================
; ACTION DUPLICATION
; ============================================================

Editor_DuplicateAction(index) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    duplicate := Editor_CloneValue(actions[index])

    duplicate["id"] :=
        "action_" . A_TickCount . "_" . Random(1000, 9999)

    actions.InsertAt(index + 1, duplicate)

    MS_Editor["selectedAction"] := index + 1
    MS_Editor["currentActionCount"] := actions.Length

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Duplicate action")

    return true
}

; ============================================================
; ACTION REORDERING
; ============================================================

Editor_MoveAction(fromIndex, toIndex) {
    global MS_Editor

    actions := MS_Editor["actions"]

    if fromIndex < 1 || fromIndex > actions.Length
        return false

    if toIndex < 1 || toIndex > actions.Length
        return false

    if fromIndex = toIndex
        return true

    action := actions.RemoveAt(fromIndex)
    actions.InsertAt(toIndex, action)

    MS_Editor["selectedAction"] := toIndex

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Move action")

    return true
}

Editor_MoveActionUp(index) {
    if index <= 1
        return false

    return Editor_MoveAction(index, index - 1)
}

Editor_MoveActionDown(index) {
    global MS_Editor

    if index >= MS_Editor["actions"].Length
        return false

    return Editor_MoveAction(index, index + 1)
}

; ============================================================
; CLIPBOARD OPERATIONS
; ============================================================

Editor_CopyAction(index) {
    global MS_EditorClipboard
    global MS_Editor

    actions := MS_Editor["actions"]

    if index < 1 || index > actions.Length
        return false

    MS_EditorClipboard := [
        Editor_CloneValue(actions[index])
    ]

    return true
}

Editor_CutAction(index) {
    if !Editor_CopyAction(index)
        return false

    return Editor_DeleteAction(index)
}

Editor_PasteAction(position := 0) {
    global MS_EditorClipboard
    global MS_Editor

    if MS_EditorClipboard.Length = 0
        return false

    action := Editor_CloneValue(
        MS_EditorClipboard[1]
    )

    action["id"] :=
        "action_" . A_TickCount . "_" . Random(1000, 9999)

    actions := MS_Editor["actions"]

    if position <= 0 || position > actions.Length
        actions.Push(action)
    else
        actions.InsertAt(position, action)

    MS_Editor["currentActionCount"] := actions.Length

    Editor_MarkModified()
    Editor_NotifyUndoRedo("Paste action")

    return true
}

; ============================================================
; SPEED MULTIPLIER
; ============================================================

Editor_SetSpeedMultiplier(multiplier) {
    global MS_Editor

    allowed := [0.5, 0.75, 1, 1.25, 1.5, 2]

    valid := false

    for value in allowed {
        if multiplier = value {
            valid := true
            break
        }
    }

    if !valid
        return false

    MS_Editor["speedMultiplier"] := multiplier

    return true
}

Editor_GetSpeedMultiplier() {
    global MS_Editor

    return MS_Editor["speedMultiplier"]
}

Editor_GetAdjustedDelay(originalDelay) {
    global MS_Editor

    multiplier := MS_Editor["speedMultiplier"]

    if multiplier <= 0
        multiplier := 1

    return Max(
        0,
        Round(originalDelay / multiplier)
    )
}

; ============================================================
; VALIDATION
; ============================================================

Editor_ValidateAction(action) {
    if !IsObject(action)
        return false

    if !action.Has("type")
        return false

    if !action.Has("data")
        return false

    if !IsObject(action["data"])
        return false

    actionType := action["type"]
    actionData := action["data"]

    switch actionType {
        case "delay":
            return actionData.Has("duration")
                && IsNumber(actionData["duration"])
                && actionData["duration"] >= 0

        case "keyPress", "keyDown", "keyUp":
            return actionData.Has("key")
                && Type(actionData["key"]) = "String"
                && Trim(actionData["key"]) != ""

        case "mouseClick":
            return actionData.Has("button")

        case "mouseMove":
            return actionData.Has("x")
                && actionData.Has("y")
                && IsNumber(actionData["x"])
                && IsNumber(actionData["y"])

        case "pixelCondition":
            return actionData.Has("x")
                && actionData.Has("y")
                && actionData.Has("color")

        case "waitUntil":
            return actionData.Has("condition")

        case "repeat":
            return actionData.Has("count")
                && IsNumber(actionData["count"])
                && actionData["count"] >= 1

        default:
            return true
    }
}

Editor_ValidateAllActions() {
    global MS_Editor

    for index, action in MS_Editor["actions"] {
        if !Editor_ValidateAction(action)
            return Map(
                "valid", false,
                "index", index,
                "message", "Invalid action at position " . index
            )
    }

    return Map(
        "valid", true,
        "index", 0,
        "message", "All actions are valid."
    )
}

; ============================================================
; SAVE EDITOR CONTENT
; ============================================================

Editor_Save() {
    global MS_Editor
    global MS_ActiveMacro
    global MS_ActiveMacroId
    global MS_Macros

    if !IsObject(MS_ActiveMacro)
        return false

    validation := Editor_ValidateAllActions()

    if !validation["valid"] {
        try {
            ExecutionConsole_Log(
                "ERROR",
                validation["message"]
            )
        }

        return false
    }

    MS_ActiveMacro["actions"] :=
        Editor_CloneActions(MS_Editor["actions"])

    MS_ActiveMacro["modifiedAt"] := A_Now

    if !MS_ActiveMacro.Has("id")
        MS_ActiveMacro["id"] := MS_ActiveMacroId

    MS_Macros[MS_ActiveMacroId] := MS_ActiveMacro

    MS_Editor["modified"] := false
    MS_Editor["currentActionCount"] :=
        MS_Editor["actions"].Length

    try {
        Storage_SaveAll()
    }

    try {
        VersionHistory_CreateSnapshot(
            MS_ActiveMacroId,
            "Manual save"
        )
    }

    return true
}

; ============================================================
; MODIFIED STATE
; ============================================================

Editor_MarkModified() {
    global MS_Editor

    MS_Editor["modified"] := true
    MS_Editor["currentActionCount"] :=
        MS_Editor["actions"].Length
}

Editor_IsModified() {
    global MS_Editor

    return MS_Editor["modified"]
}

; ============================================================
; UNDO / REDO INTEGRATION
; ============================================================

Editor_NotifyUndoRedo(description) {
    try {
        UndoRedo_Record(
            description,
            Editor_CloneActions(
                Editor_GetActions()
            )
        )
    }
}

; ============================================================
; CLONING HELPERS
; ============================================================

Editor_CloneActions(actions) {
    cloned := []

    for action in actions
        cloned.Push(Editor_CloneValue(action))

    return cloned
}

Editor_CloneValue(value) {
    if !IsObject(value)
        return value

    if value is Array {
        result := []

        for item in value
            result.Push(Editor_CloneValue(item))

        return result
    }

    if value is Map {
        result := Map()

        for key, item in value
            result[key] := Editor_CloneValue(item)

        return result
    }

    return value
}

; ============================================================
; SHUTDOWN
; ============================================================

Editor_Shutdown() {
    global MS_EditorInitialized

    MS_EditorInitialized := false

    return true
}

; ============================================================
; END OF Editor.ahk
; ============================================================


; Compatibility API for modules using the earlier editor contract.
Editor_SetModified(value := true) {
    global MS_Editor
    MS_Editor["modified"] := !!value
    MS_Editor["currentActionCount"] := MS_Editor["actions"].Length
    return true
}

Editor_AutoSave() {
    global MS_Editor
    if !IsObject(MS_Editor) || !MS_Editor.Get("modified", false)
        return true
    return Editor_Save()
}
