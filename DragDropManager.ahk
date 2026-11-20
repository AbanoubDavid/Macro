; ============================================================
; MacroStudio - Drag and Drop Manager
; Reorders macro actions through drag-and-drop interactions.
; AutoHotkey v2
; ============================================================

DragDropManager_Initialize() {
    global MS_State

    MS_State["dragDropReady"] := true
    MS_State["dragDropActive"] := false
    MS_State["dragDropSourceIndex"] := 0
    MS_State["dragDropTargetIndex"] := 0
    MS_State["dragDropMacroId"] := ""
    MS_State["dragDropStartY"] := 0
    MS_State["dragDropCurrentY"] := 0
    MS_State["dragDropThreshold"] := 8

    return true
}

; ------------------------------------------------------------
; Drag lifecycle
; ------------------------------------------------------------

DragDropManager_Begin(macroId, actionIndex, startY := 0) {
    global MS_State, MS_Macros

    if !MS_State.Get("dragDropReady", false)
        return false

    if MS_State.Get("dragDropActive", false)
        return false

    if !MS_Macros.Has(macroId)
        return false

    actions := MS_Macros[macroId].Get("actions", [])

    if !IsObject(actions)
        return false

    if (actionIndex < 1 || actionIndex > actions.Length)
        return false

    MS_State["dragDropActive"] := true
    MS_State["dragDropMacroId"] := macroId
    MS_State["dragDropSourceIndex"] := actionIndex
    MS_State["dragDropTargetIndex"] := actionIndex
    MS_State["dragDropStartY"] := startY
    MS_State["dragDropCurrentY"] := startY

    return true
}

DragDropManager_Update(targetIndex, currentY := unset) {
    global MS_State, MS_Macros

    if !MS_State.Get("dragDropActive", false)
        return false

    macroId := MS_State.Get("dragDropMacroId", "")

    if !MS_Macros.Has(macroId)
        return false

    actions := MS_Macros[macroId].Get("actions", [])

    if !IsObject(actions) || actions.Length = 0
        return false

    targetIndex := Max(1, Min(actions.Length, targetIndex))

    MS_State["dragDropTargetIndex"] := targetIndex

    if IsSet(currentY)
        MS_State["dragDropCurrentY"] := currentY

    return true
}

DragDropManager_Commit() {
    global MS_State

    if !MS_State.Get("dragDropActive", false)
        return false

    macroId := MS_State.Get("dragDropMacroId", "")
    sourceIndex := MS_State.Get("dragDropSourceIndex", 0)
    targetIndex := MS_State.Get("dragDropTargetIndex", 0)

    DragDropManager_Reset()

    if (macroId = "" || sourceIndex = targetIndex)
        return false

    return DragDropManager_MoveAction(
        macroId,
        sourceIndex,
        targetIndex
    )
}

DragDropManager_Cancel() {
    global MS_State

    if !MS_State.Get("dragDropActive", false)
        return false

    DragDropManager_Reset()
    return true
}

DragDropManager_Reset() {
    global MS_State

    MS_State["dragDropActive"] := false
    MS_State["dragDropSourceIndex"] := 0
    MS_State["dragDropTargetIndex"] := 0
    MS_State["dragDropMacroId"] := ""
    MS_State["dragDropStartY"] := 0
    MS_State["dragDropCurrentY"] := 0

    return true
}

; ------------------------------------------------------------
; Action movement
; ------------------------------------------------------------

DragDropManager_MoveAction(macroId, sourceIndex, targetIndex) {
    global MS_Macros

    if !MS_Macros.Has(macroId)
        return false

    macro := MS_Macros[macroId]
    actions := macro.Get("actions", [])

    if !IsObject(actions)
        return false

    if (sourceIndex < 1 || sourceIndex > actions.Length)
        return false

    if (targetIndex < 1 || targetIndex > actions.Length)
        return false

    if (sourceIndex = targetIndex)
        return true

    try {
        UndoRedo_Record(macroId, "Reorder actions")

        movedAction := actions.RemoveAt(sourceIndex)
        actions.InsertAt(targetIndex, movedAction)

        macro["actions"] := actions

        if (MS_State.Get("selectedMacroId", "") = macroId)
            Editor_LoadMacro(macroId)

        Editor_SetModified(true)

        ExecutionConsole_Log(
            "Moved action from position " sourceIndex
            " to " targetIndex,
            "INFO"
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Action reorder failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

DragDropManager_MoveUp(macroId, actionIndex) {
    if (actionIndex <= 1)
        return false

    return DragDropManager_MoveAction(
        macroId,
        actionIndex,
        actionIndex - 1
    )
}

DragDropManager_MoveDown(macroId, actionIndex) {
    global MS_Macros

    if !MS_Macros.Has(macroId)
        return false

    actions := MS_Macros[macroId].Get("actions", [])

    if !IsObject(actions)
        return false

    if (actionIndex >= actions.Length)
        return false

    return DragDropManager_MoveAction(
        macroId,
        actionIndex,
        actionIndex + 1
    )
}

; ------------------------------------------------------------
; Position calculations
; ------------------------------------------------------------

DragDropManager_GetTargetIndex(mouseY, itemTop, itemHeight, itemCount) {
    if (itemCount <= 0 || itemHeight <= 0)
        return 0

    relativeY := mouseY - itemTop

    if (relativeY <= 0)
        return 1

    targetIndex := Floor(relativeY / itemHeight) + 1

    return Max(1, Min(itemCount, targetIndex))
}

DragDropManager_GetInsertionIndex(mouseY, itemTop, itemHeight, itemCount) {
    if (itemCount <= 0 || itemHeight <= 0)
        return 1

    relativeY := mouseY - itemTop

    targetIndex := Floor(relativeY / itemHeight) + 1

    if (Mod(relativeY, itemHeight) >= itemHeight / 2)
        targetIndex += 1

    return Max(1, Min(itemCount, targetIndex))
}

DragDropManager_GetDragState() {
    global MS_State

    return Map(
        "active", MS_State.Get("dragDropActive", false),
        "macroId", MS_State.Get("dragDropMacroId", ""),
        "sourceIndex", MS_State.Get("dragDropSourceIndex", 0),
        "targetIndex", MS_State.Get("dragDropTargetIndex", 0),
        "startY", MS_State.Get("dragDropStartY", 0),
        "currentY", MS_State.Get("dragDropCurrentY", 0)
    )
}

DragDropManager_IsDragging() {
    global MS_State
    return MS_State.Get("dragDropActive", false)
}

; ------------------------------------------------------------
; Editor integration
; ------------------------------------------------------------

DragDropManager_ReorderSelected(direction) {
    global MS_State

    macroId := MS_State.Get("selectedMacroId", "")
    actionIndex := MS_State.Get("selectedActionIndex", 0)

    if (macroId = "" || actionIndex <= 0)
        return false

    direction := StrLower(direction)

    switch direction {
        case "up":
            return DragDropManager_MoveUp(macroId, actionIndex)

        case "down":
            return DragDropManager_MoveDown(macroId, actionIndex)

        default:
            return false
    }
}

DragDropManager_MoveToPosition(macroId, actionId, targetIndex) {
    global MS_Macros

    if !MS_Macros.Has(macroId)
        return false

    actions := MS_Macros[macroId].Get("actions", [])

    if !IsObject(actions)
        return false

    sourceIndex := 0

    for index, action in actions {
        if !IsObject(action)
            continue

        if action.Get("id", "") = actionId {
            sourceIndex := index
            break
        }
    }

    if (sourceIndex = 0)
        return false

    return DragDropManager_MoveAction(
        macroId,
        sourceIndex,
        targetIndex
    )
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

DragDropManager_Shutdown() {
    global MS_State

    DragDropManager_Reset()

    MS_State["dragDropReady"] := false

    return true
}