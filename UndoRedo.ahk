; ============================================================
; MacroStudio - Undo / Redo Manager
; Maintains action history and restores previous macro states.
; AutoHotkey v2
; ============================================================

UndoRedo_Initialize() {
    global MS_State

    MS_State["undoStacks"] := Map()
    MS_State["redoStacks"] := Map()
    MS_State["undoRedoReady"] := true
    MS_State["undoRedoBusy"] := false
    MS_State["undoRedoLimit"] := 100

    return true
}

; ------------------------------------------------------------
; History management
; ------------------------------------------------------------

UndoRedo_Record(macroId, description := "Edit macro") {
    global MS_State, MS_Macros

    if !MS_State.Get("undoRedoReady", false)
        return false

    if MS_State.Get("undoRedoBusy", false)
        return false

    if !MS_Macros.Has(macroId)
        return false

    snapshot := UndoRedo_CreateSnapshot(macroId)

    if !IsObject(snapshot)
        return false

    undoStacks := MS_State["undoStacks"]

    if !undoStacks.Has(macroId)
        undoStacks[macroId] := []

    stack := undoStacks[macroId]

    stack.Push(Map(
        "snapshot", snapshot,
        "description", description,
        "timestamp", A_Now
    ))

    limit := MS_State.Get("undoRedoLimit", 100)

    while (stack.Length > limit)
        stack.RemoveAt(1)

    ; A new edit invalidates the redo history.
    redoStacks := MS_State["redoStacks"]

    if redoStacks.Has(macroId)
        redoStacks[macroId] := []

    return true
}

UndoRedo_CreateSnapshot(macroId) {
    global MS_Macros

    if !MS_Macros.Has(macroId)
        return ""

    try {
        return Lib_Clone(MS_Macros[macroId])
    } catch {
        return ""
    }
}

UndoRedo_PushRedo(macroId, description := "Redo state") {
    global MS_State

    snapshot := UndoRedo_CreateSnapshot(macroId)

    if !IsObject(snapshot)
        return false

    redoStacks := MS_State["redoStacks"]

    if !redoStacks.Has(macroId)
        redoStacks[macroId] := []

    redoStacks[macroId].Push(Map(
        "snapshot", snapshot,
        "description", description,
        "timestamp", A_Now
    ))

    return true
}

; ------------------------------------------------------------
; Undo
; ------------------------------------------------------------

UndoRedo_Undo(macroId := unset) {
    global MS_State, MS_Macros

    if !MS_State.Get("undoRedoReady", false)
        return false

    if MS_State.Get("undoRedoBusy", false)
        return false

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    if (macroId = "" || !MS_Macros.Has(macroId))
        return false

    undoStacks := MS_State["undoStacks"]

    if !undoStacks.Has(macroId)
        return false

    stack := undoStacks[macroId]

    if (stack.Length = 0)
        return false

    MS_State["undoRedoBusy"] := true

    try {
        ; Preserve the current state for redo.
        UndoRedo_PushRedo(macroId, "State before undo")

        entry := stack.Pop()

        if !IsObject(entry) || !entry.Has("snapshot")
            return false

        restored := Lib_Clone(entry["snapshot"])

        if !IsObject(restored)
            return false

        MS_Macros[macroId] := restored

        UndoRedo_RefreshEditor(macroId)

        ExecutionConsole_Log(
            "Undo: " entry.Get("description", "Edit macro"),
            "INFO"
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Undo failed: " error.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["undoRedoBusy"] := false
    }
}

; ------------------------------------------------------------
; Redo
; ------------------------------------------------------------

UndoRedo_Redo(macroId := unset) {
    global MS_State, MS_Macros

    if !MS_State.Get("undoRedoReady", false)
        return false

    if MS_State.Get("undoRedoBusy", false)
        return false

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    if (macroId = "" || !MS_Macros.Has(macroId))
        return false

    redoStacks := MS_State["redoStacks"]

    if !redoStacks.Has(macroId)
        return false

    stack := redoStacks[macroId]

    if (stack.Length = 0)
        return false

    MS_State["undoRedoBusy"] := true

    try {
        ; Preserve the current state for undo.
        undoStacks := MS_State["undoStacks"]

        if !undoStacks.Has(macroId)
            undoStacks[macroId] := []

        undoStacks[macroId].Push(Map(
            "snapshot", Lib_Clone(MS_Macros[macroId]),
            "description", "State before redo",
            "timestamp", A_Now
        ))

        entry := stack.Pop()

        if !IsObject(entry) || !entry.Has("snapshot")
            return false

        restored := Lib_Clone(entry["snapshot"])

        if !IsObject(restored)
            return false

        MS_Macros[macroId] := restored

        UndoRedo_RefreshEditor(macroId)

        ExecutionConsole_Log(
            "Redo: " entry.Get("description", "Edit macro"),
            "INFO"
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Redo failed: " error.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["undoRedoBusy"] := false
    }
}

; ------------------------------------------------------------
; History inspection
; ------------------------------------------------------------

UndoRedo_CanUndo(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    if (macroId = "")
        return false

    stacks := MS_State["undoStacks"]

    return stacks.Has(macroId) && stacks[macroId].Length > 0
}

UndoRedo_CanRedo(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    if (macroId = "")
        return false

    stacks := MS_State["redoStacks"]

    return stacks.Has(macroId) && stacks[macroId].Length > 0
}

UndoRedo_GetUndoCount(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    stacks := MS_State["undoStacks"]

    if !stacks.Has(macroId)
        return 0

    return stacks[macroId].Length
}

UndoRedo_GetRedoCount(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    stacks := MS_State["redoStacks"]

    if !stacks.Has(macroId)
        return 0

    return stacks[macroId].Length
}

UndoRedo_GetHistory(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    history := []

    if (macroId = "")
        return history

    undoStacks := MS_State["undoStacks"]

    if undoStacks.Has(macroId) {
        for entry in undoStacks[macroId] {
            history.Push(Map(
                "description", entry.Get("description", ""),
                "timestamp", entry.Get("timestamp", ""),
                "type", "undo"
            ))
        }
    }

    redoStacks := MS_State["redoStacks"]

    if redoStacks.Has(macroId) {
        for entry in redoStacks[macroId] {
            history.Push(Map(
                "description", entry.Get("description", ""),
                "timestamp", entry.Get("timestamp", ""),
                "type", "redo"
            ))
        }
    }

    return history
}

; ------------------------------------------------------------
; History controls
; ------------------------------------------------------------

UndoRedo_Clear(macroId := unset) {
    global MS_State

    if !IsSet(macroId)
        macroId := MS_State.Get("selectedMacroId", "")

    if (macroId = "")
        return false

    undoStacks := MS_State["undoStacks"]
    redoStacks := MS_State["redoStacks"]

    if undoStacks.Has(macroId)
        undoStacks[macroId] := []

    if redoStacks.Has(macroId)
        redoStacks[macroId] := []

    return true
}

UndoRedo_ClearAll() {
    global MS_State

    MS_State["undoStacks"] := Map()
    MS_State["redoStacks"] := Map()

    return true
}

UndoRedo_SetLimit(limit) {
    global MS_State

    limit := Max(1, Min(1000, limit))
    MS_State["undoRedoLimit"] := limit

    undoStacks := MS_State["undoStacks"]

    for macroId, stack in undoStacks {
        while (stack.Length > limit)
            stack.RemoveAt(1)
    }

    return true
}

; ------------------------------------------------------------
; Editor integration
; ------------------------------------------------------------

UndoRedo_RefreshEditor(macroId) {
    global MS_State

    MS_State["selectedMacroId"] := macroId

    try {
        Editor_LoadMacro(macroId)
    } catch as error {
        ExecutionConsole_Log(
            "Could not refresh editor after history operation: " error.Message,
            "WARNING"
        )
    }

    try {
        UI_SetStatus("Macro history restored")
    }

    return true
}

UndoRedo_BeginTransaction(macroId, description := "Edit macro") {
    return UndoRedo_Record(macroId, description)
}

UndoRedo_CommitTransaction(macroId) {
    return UndoRedo_CreateSnapshot(macroId)
}

UndoRedo_CancelTransaction(macroId) {
    return UndoRedo_Undo(macroId)
}

; ------------------------------------------------------------
; Keyboard shortcuts
; ------------------------------------------------------------

UndoRedo_RegisterHotkeys() {
    try Hotkey("^z", (*) => UndoRedo_Undo(), "On")
    try Hotkey("^y", (*) => UndoRedo_Redo(), "On")

    return true
}

UndoRedo_UnregisterHotkeys() {
    try Hotkey("^z", "Off")
    try Hotkey("^y", "Off")

    return true
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

UndoRedo_Shutdown() {
    global MS_State

    UndoRedo_UnregisterHotkeys()

    MS_State["undoRedoReady"] := false
    MS_State["undoRedoBusy"] := false

    return true
}