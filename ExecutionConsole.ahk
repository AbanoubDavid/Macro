
; ============================================================
; MacroStudio - Live Execution Console
; Logging, filtering, searching, exporting, and live updates.
; AutoHotkey v2
; ============================================================

ExecutionConsole_Initialize() {
    global MS_State, MS_ExecutionConsole

    MS_ExecutionConsole := Map(
        "ready", true,
        "entries", [],
        "maxEntries", 5000,
        "nextId", 1,
        "filter", "ALL",
        "search", "",
        "autoScroll", true,
        "paused", false,
        "visible", true,
        "gui", "",
        "edit", "",
        "statusText", "",
        "entryCount", 0,
        "errorCount", 0,
        "warningCount", 0
    )

    MS_State["executionConsoleReady"] := true
    return true
}

; ------------------------------------------------------------
; Logging
; ------------------------------------------------------------

ExecutionConsole_Log(message, level := "INFO", source := "MacroStudio") {
    global MS_ExecutionConsole

    if !IsObject(MS_ExecutionConsole)
        return false

    if MS_ExecutionConsole.Get("paused", false)
        return false

    level := StrUpper(level)

    if !ExecutionConsole_ValidateLevel(level)
        level := "INFO"

    entry := Map(
        "id", MS_ExecutionConsole["nextId"],
        "timestamp", FormatTime(, "yyyy-MM-dd HH:mm:ss"),
        "tick", A_TickCount,
        "level", level,
        "source", source,
        "message", message ""
    )

    MS_ExecutionConsole["nextId"] += 1
    MS_ExecutionConsole["entries"].Push(entry)
    MS_ExecutionConsole["entryCount"] += 1

    switch level {
        case "ERROR":
            MS_ExecutionConsole["errorCount"] += 1
        case "WARNING":
            MS_ExecutionConsole["warningCount"] += 1
    }

    ExecutionConsole_TrimEntries()
    ExecutionConsole_Refresh()

    return entry["id"]
}

ExecutionConsole_Info(message, source := "MacroStudio") {
    return ExecutionConsole_Log(message, "INFO", source)
}

ExecutionConsole_Warning(message, source := "MacroStudio") {
    return ExecutionConsole_Log(message, "WARNING", source)
}

ExecutionConsole_Error(message, source := "MacroStudio") {
    return ExecutionConsole_Log(message, "ERROR", source)
}

ExecutionConsole_Debug(message, source := "MacroStudio") {
    return ExecutionConsole_Log(message, "DEBUG", source)
}

ExecutionConsole_TrimEntries() {
    global MS_ExecutionConsole

    entries := MS_ExecutionConsole["entries"]
    maximum := MS_ExecutionConsole["maxEntries"]

    while (entries.Length > maximum)
        entries.RemoveAt(1)

    MS_ExecutionConsole["entryCount"] := entries.Length
    return true
}

; ------------------------------------------------------------
; Filtering and searching
; ------------------------------------------------------------

ExecutionConsole_SetFilter(level) {
    global MS_ExecutionConsole

    level := StrUpper(level)

    if (level != "ALL" && !ExecutionConsole_ValidateLevel(level))
        return false

    MS_ExecutionConsole["filter"] := level
    ExecutionConsole_Refresh()

    return true
}

ExecutionConsole_SetSearch(query) {
    global MS_ExecutionConsole

    MS_ExecutionConsole["search"] := query ""
    ExecutionConsole_Refresh()

    return true
}

ExecutionConsole_GetFilteredEntries() {
    global MS_ExecutionConsole

    filtered := []
    levelFilter := MS_ExecutionConsole["filter"]
    search := StrLower(MS_ExecutionConsole["search"])

    for entry in MS_ExecutionConsole["entries"] {
        if (levelFilter != "ALL" && entry["level"] != levelFilter)
            continue

        if (search != "") {
            content := entry["timestamp"] " "
                . entry["level"] " "
                . entry["source"] " "
                . entry["message"]

            if !InStr(content, search)
                continue
        }

        filtered.Push(entry)
    }

    return filtered
}

ExecutionConsole_ValidateLevel(level) {
    return (level = "INFO"
        || level = "WARNING"
        || level = "ERROR"
        || level = "DEBUG")
}

; ------------------------------------------------------------
; Console GUI
; ------------------------------------------------------------

ExecutionConsole_CreateGUI(parentGui := "") {
    global MS_ExecutionConsole

    if IsObject(MS_ExecutionConsole.Get("gui", "")) {
        try MS_ExecutionConsole["gui"].Destroy()
    }

    gui := Gui("+Resize +MinSize600x300", "Execution Console")
    gui.BackColor := "151515"
    gui.SetFont("s9 cFFFFFF", "Segoe UI")

    gui.AddText("x12 y12 w100 h22", "Execution Log")

    filter := gui.AddDropDownList(
        "x120 y10 w120 Choose1",
        ["ALL", "INFO", "WARNING", "ERROR", "DEBUG"]
    )

    filter.OnEvent("Change", (*) => ExecutionConsole_SetFilter(filter.Text))

    search := gui.AddEdit(
        "x250 y10 w220 h24",
        MS_ExecutionConsole["search"]
    )

    search.OnEvent("Change", (*) => ExecutionConsole_SetSearch(search.Value))

    gui.AddButton("x480 y10 w75 h24", "Clear").OnEvent(
        "Click",
        (*) => ExecutionConsole_Clear()
    )

    gui.AddButton("x565 y10 w75 h24", "Export").OnEvent(
        "Click",
        (*) => ExecutionConsole_Export()
    )

    gui.AddButton("x650 y10 w75 h24", "Pause").OnEvent(
        "Click",
        (*) => ExecutionConsole_TogglePause()
    )

    edit := gui.AddEdit("x12 y45 w720 h390 ReadOnly -Wrap VScroll")

    status := gui.AddText("x12 y445 w720 h22", "Ready")

    gui.OnEvent("Size", ExecutionConsole_OnResize)
    gui.OnEvent("Close", ExecutionConsole_OnClose)

    MS_ExecutionConsole["gui"] := gui
    MS_ExecutionConsole["edit"] := edit
    MS_ExecutionConsole["statusText"] := status

    ExecutionConsole_Refresh()

    return gui
}

ExecutionConsole_Show() {
    global MS_ExecutionConsole

    gui := MS_ExecutionConsole.Get("gui", "")

    if !IsObject(gui)
        gui := ExecutionConsole_CreateGUI()

    gui.Show()
    MS_ExecutionConsole["visible"] := true

    return true
}

ExecutionConsole_Hide() {
    global MS_ExecutionConsole

    gui := MS_ExecutionConsole.Get("gui", "")

    if !IsObject(gui)
        return false

    gui.Hide()
    MS_ExecutionConsole["visible"] := false

    return true
}

ExecutionConsole_Toggle() {
    global MS_ExecutionConsole

    if MS_ExecutionConsole.Get("visible", false)
        return ExecutionConsole_Hide()

    return ExecutionConsole_Show()
}

ExecutionConsole_OnResize(gui, minMax, width, height) {
    global MS_ExecutionConsole

    if (minMax = -1)
        return

    edit := MS_ExecutionConsole.Get("edit", "")
    status := MS_ExecutionConsole.Get("statusText", "")

    if !IsObject(edit)
        return

    edit.Move(12, 45, Max(300, width - 24), Max(100, height - 80))

    if IsObject(status)
        status.Move(12, height - 25, Max(300, width - 24), 20)
}

ExecutionConsole_OnClose(gui) {
    global MS_ExecutionConsole

    MS_ExecutionConsole["visible"] := false
    gui.Hide()

    return true
}

; ------------------------------------------------------------
; Refresh and formatting
; ------------------------------------------------------------

ExecutionConsole_Refresh() {
    global MS_ExecutionConsole

    edit := MS_ExecutionConsole.Get("edit", "")

    if !IsObject(edit)
        return false

    if MS_ExecutionConsole.Get("paused", false)
        return false

    entries := ExecutionConsole_GetFilteredEntries()
    output := ""

    for entry in entries
        output .= ExecutionConsole_FormatEntry(entry) "`r`n"

    try {
        edit.Value := output

        if MS_ExecutionConsole.Get("autoScroll", true)
            SendMessage(0x115, 7, 0, edit.Hwnd)
    }

    ExecutionConsole_UpdateStatus()

    return true
}

ExecutionConsole_FormatEntry(entry) {
    return "[" . entry["timestamp"] . "] "
        . "[" . entry["level"] . "] "
        . "[" . entry["source"] . "] "
        . entry["message"]
}

ExecutionConsole_UpdateStatus() {
    global MS_ExecutionConsole

    status := MS_ExecutionConsole.Get("statusText", "")

    if !IsObject(status)
        return false

    status.Value := "Entries: " . MS_ExecutionConsole["entryCount"]
        . " | Errors: " . MS_ExecutionConsole["errorCount"]
        . " | Warnings: " . MS_ExecutionConsole["warningCount"]

    return true
}

; ------------------------------------------------------------
; Console controls
; ------------------------------------------------------------

ExecutionConsole_Clear() {
    global MS_ExecutionConsole

    MS_ExecutionConsole["entries"] := []
    MS_ExecutionConsole["entryCount"] := 0
    MS_ExecutionConsole["errorCount"] := 0
    MS_ExecutionConsole["warningCount"] := 0

    ExecutionConsole_Refresh()
    return true
}

ExecutionConsole_TogglePause() {
    global MS_ExecutionConsole

    MS_ExecutionConsole["paused"] := !MS_ExecutionConsole["paused"]

    if !MS_ExecutionConsole["paused"]
        ExecutionConsole_Refresh()

    return MS_ExecutionConsole["paused"]
}

ExecutionConsole_SetAutoScroll(enabled) {
    global MS_ExecutionConsole

    MS_ExecutionConsole["autoScroll"] := !!enabled
    return true
}

ExecutionConsole_SetMaxEntries(maximum) {
    global MS_ExecutionConsole

    if !IsNumber(maximum) || maximum < 100 || maximum > 50000
        return false

    MS_ExecutionConsole["maxEntries"] := Round(maximum)
    ExecutionConsole_TrimEntries()

    return true
}

; ------------------------------------------------------------
; Export
; ------------------------------------------------------------

ExecutionConsole_Export(path := "", format := "txt") {
    if (path = "") {
        extension := (format = "json")
            ? "JSON Files (*.json)"
            : "Text Files (*.txt)"

        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Execution Log",
            extension
        )
    }

    if (path = "")
        return false

    try {
        if (StrLower(format) = "json") {
            content := JSON.Stringify(
                ExecutionConsole_GetFilteredEntries(),
                true
            )
        } else {
            content := ""

            for entry in ExecutionConsole_GetFilteredEntries()
                content .= ExecutionConsole_FormatEntry(entry) "`r`n"
        }

        Lib_WriteText(path, content)
        return true

    } catch as error {
        ExecutionConsole_Log(
            "Console export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Statistics and queries
; ------------------------------------------------------------

ExecutionConsole_GetStatistics() {
    global MS_ExecutionConsole

    return Map(
        "total", MS_ExecutionConsole["entryCount"],
        "errors", MS_ExecutionConsole["errorCount"],
        "warnings", MS_ExecutionConsole["warningCount"],
        "maximum", MS_ExecutionConsole["maxEntries"],
        "paused", MS_ExecutionConsole["paused"]
    )
}

ExecutionConsole_GetRecent(count := 50) {
    global MS_ExecutionConsole

    results := []
    entries := MS_ExecutionConsole["entries"]

    count := Max(0, Min(count, entries.Length))
    start := entries.Length - count + 1

    Loop count
        results.Push(entries[start + A_Index - 1])

    return results
}

ExecutionConsole_FindById(id) {
    global MS_ExecutionConsole

    for entry in MS_ExecutionConsole["entries"] {
        if (entry["id"] = id)
            return entry
    }

    return ""
}

ExecutionConsole_FindErrors() {
    global MS_ExecutionConsole

    results := []

    for entry in MS_ExecutionConsole["entries"] {
        if (entry["level"] = "ERROR")
            results.Push(entry)
    }

    return results
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

ExecutionConsole_Shutdown() {
    global MS_State, MS_ExecutionConsole

    if !IsObject(MS_ExecutionConsole)
        return true

    gui := MS_ExecutionConsole.Get("gui", "")

    if IsObject(gui) {
        try gui.Destroy()
    }

    MS_ExecutionConsole["ready"] := false
    MS_State["executionConsoleReady"] := false

    return true
}
