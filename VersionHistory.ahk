; ============================================================
; MacroStudio - Macro Version History
; Snapshots, restore, compare, and manage macro versions.
; AutoHotkey v2
; ============================================================

VersionHistory_Initialize() {
    global MS_State, MS_Versions

    MS_Versions := Map(
        "ready", true,
        "macros", Map(),
        "maxVersions", 50,
        "autoSnapshot", true,
        "nextId", 1
    )

    MS_State["versionHistoryReady"] := true

    VersionHistory_Load()
    return true
}

; ------------------------------------------------------------
; Snapshot creation
; ------------------------------------------------------------

VersionHistory_CreateSnapshot(macroId, description := "") {
    global MS_Macros, MS_Versions

    if !MS_Macros.Has(macroId)
        return false

    macro := MS_Macros[macroId]
    snapshotId := VersionHistory_GenerateId()

    snapshot := Map(
        "id", snapshotId,
        "macroId", macroId,
        "macroName", macro.Get("name", "Untitled Macro"),
        "description", description,
        "createdAt", A_Now,
        "timestamp", A_TickCount,
        "data", Lib_Clone(macro)
    )

    if !MS_Versions["macros"].Has(macroId)
        MS_Versions["macros"][macroId] := []

    versions := MS_Versions["macros"][macroId]
    versions.Push(snapshot)

    VersionHistory_Trim(macroId)
    VersionHistory_Save()

    ExecutionConsole_Log(
        "Created version snapshot for " snapshot["macroName"],
        "INFO"
    )

    return snapshotId
}

VersionHistory_CreateAutomaticSnapshot(macroId) {
    global MS_Versions

    if !MS_Versions.Get("autoSnapshot", true)
        return false

    return VersionHistory_CreateSnapshot(
        macroId,
        "Automatic snapshot"
    )
}

VersionHistory_CreateNamedSnapshot(macroId, description) {
    if (description = "")
        return false

    return VersionHistory_CreateSnapshot(
        macroId,
        description
    )
}

; ------------------------------------------------------------
; Version retrieval
; ------------------------------------------------------------

VersionHistory_GetVersions(macroId) {
    global MS_Versions

    if !MS_Versions["macros"].Has(macroId)
        return []

    return MS_Versions["macros"][macroId]
}

VersionHistory_GetVersion(macroId, versionId) {
    versions := VersionHistory_GetVersions(macroId)

    for version in versions {
        if (version.Get("id", "") = versionId)
            return version
    }

    return ""
}

VersionHistory_GetLatest(macroId) {
    versions := VersionHistory_GetVersions(macroId)

    if (versions.Length = 0)
        return ""

    return versions[versions.Length]
}

VersionHistory_GetCount(macroId) {
    return VersionHistory_GetVersions(macroId).Length
}

VersionHistory_GetAllMacroIds() {
    global MS_Versions

    result := []

    for macroId, versions in MS_Versions["macros"]
        result.Push(macroId)

    return result
}

; ------------------------------------------------------------
; Restore versions
; ------------------------------------------------------------

VersionHistory_Restore(macroId, versionId) {
    global MS_Macros, MS_Versions, MS_ActiveMacro
    global MS_ActiveMacroId, MS_SelectedMacroId

    version := VersionHistory_GetVersion(macroId, versionId)

    if !IsObject(version)
        return false

    if !MS_Macros.Has(macroId)
        return false

    currentMacro := MS_Macros[macroId]

    ; Preserve the current state before replacing it.
    VersionHistory_CreateSnapshot(
        macroId,
        "Before restoring version"
    )

    restored := Lib_Clone(version["data"])

    if !IsObject(restored)
        return false

    MS_Macros[macroId] := restored

    if (MS_ActiveMacroId = macroId) {
        MS_ActiveMacro := restored

        if IsSet(Editor_LoadMacro)
            Editor_LoadMacro(macroId)
    }

    if (MS_SelectedMacroId = macroId)
        MS_SelectedMacroId := macroId

    Storage_SaveAll()

    ExecutionConsole_Log(
        "Restored version " versionId " for "
        restored.Get("name", macroId),
        "WARNING"
    )

    return true
}

VersionHistory_RestoreLatest(macroId) {
    versions := VersionHistory_GetVersions(macroId)

    if (versions.Length = 0)
        return false

    latest := versions[versions.Length]

    return VersionHistory_Restore(
        macroId,
        latest["id"]
    )
}

; ------------------------------------------------------------
; Delete and manage versions
; ------------------------------------------------------------

VersionHistory_Delete(macroId, versionId) {
    global MS_Versions

    if !MS_Versions["macros"].Has(macroId)
        return false

    versions := MS_Versions["macros"][macroId]

    for index, version in versions {
        if (version.Get("id", "") = versionId) {
            versions.RemoveAt(index)

            if (versions.Length = 0)
                MS_Versions["macros"].Delete(macroId)

            VersionHistory_Save()
            return true
        }
    }

    return false
}

VersionHistory_DeleteAll(macroId) {
    global MS_Versions

    if !MS_Versions["macros"].Has(macroId)
        return false

    MS_Versions["macros"].Delete(macroId)

    VersionHistory_Save()
    return true
}

VersionHistory_Trim(macroId) {
    global MS_Versions

    if !MS_Versions["macros"].Has(macroId)
        return false

    versions := MS_Versions["macros"][macroId]
    maximum := MS_Versions["maxVersions"]

    while (versions.Length > maximum)
        versions.RemoveAt(1)

    return true
}

VersionHistory_SetMaximum(maximum) {
    global MS_Versions

    if !IsNumber(maximum) || maximum < 1 || maximum > 1000
        return false

    MS_Versions["maxVersions"] := Round(maximum)

    for macroId, versions in MS_Versions["macros"]
        VersionHistory_Trim(macroId)

    VersionHistory_Save()
    return true
}

VersionHistory_SetAutoSnapshot(enabled) {
    global MS_Versions

    MS_Versions["autoSnapshot"] := !!enabled
    VersionHistory_Save()

    return true
}

; ------------------------------------------------------------
; Version comparison
; ------------------------------------------------------------

VersionHistory_Compare(macroId, firstVersionId, secondVersionId) {
    first := VersionHistory_GetVersion(
        macroId,
        firstVersionId
    )

    second := VersionHistory_GetVersion(
        macroId,
        secondVersionId
    )

    if !IsObject(first) || !IsObject(second)
        return false

    firstMacro := first["data"]
    secondMacro := second["data"]

    firstActions := firstMacro.Get("actions", [])
    secondActions := secondMacro.Get("actions", [])

    comparison := Map(
        "macroId", macroId,
        "firstVersion", firstVersionId,
        "secondVersion", secondVersionId,
        "added", [],
        "removed", [],
        "modified", [],
        "unchanged", 0,
        "firstActionCount", firstActions.Length,
        "secondActionCount", secondActions.Length
    )

    maxCount := Max(firstActions.Length, secondActions.Length)

    Loop maxCount {
        index := A_Index

        if (index > firstActions.Length) {
            comparison["added"].Push(Map(
                "index", index,
                "action", Lib_Clone(secondActions[index])
            ))
            continue
        }

        if (index > secondActions.Length) {
            comparison["removed"].Push(Map(
                "index", index,
                "action", Lib_Clone(firstActions[index])
            ))
            continue
        }

        firstAction := firstActions[index]
        secondAction := secondActions[index]

        if VersionHistory_ObjectsEqual(firstAction, secondAction) {
            comparison["unchanged"] += 1
        } else {
            comparison["modified"].Push(Map(
                "index", index,
                "before", Lib_Clone(firstAction),
                "after", Lib_Clone(secondAction)
            ))
        }
    }

    comparison["nameChanged"] :=
        firstMacro.Get("name", "") != secondMacro.Get("name", "")

    comparison["descriptionChanged"] :=
        firstMacro.Get("description", "")
        != secondMacro.Get("description", "")

    return comparison
}

VersionHistory_ObjectsEqual(first, second) {
    try {
        firstJson := JSON.Stringify(first)
        secondJson := JSON.Stringify(second)

        return firstJson = secondJson
    } catch {
        return false
    }
}

VersionHistory_GetComparisonSummary(comparison) {
    if !IsObject(comparison)
        return ""

    return Map(
        "added", comparison["added"].Length,
        "removed", comparison["removed"].Length,
        "modified", comparison["modified"].Length,
        "unchanged", comparison["unchanged"],
        "firstActionCount", comparison["firstActionCount"],
        "secondActionCount", comparison["secondActionCount"]
    )
}

; ------------------------------------------------------------
; Version labels and metadata
; ------------------------------------------------------------

VersionHistory_SetDescription(macroId, versionId, description) {
    global MS_Versions

    version := VersionHistory_GetVersion(macroId, versionId)

    if !IsObject(version)
        return false

    version["description"] := description ""
    VersionHistory_Save()

    return true
}

VersionHistory_GetVersionLabel(version) {
    if !IsObject(version)
        return ""

    description := version.Get("description", "")

    if (description != "")
        return description

    return "Version " version.Get("id", "")
}

VersionHistory_GetTimeline(macroId) {
    versions := VersionHistory_GetVersions(macroId)
    timeline := []

    for version in versions {
        timeline.Push(Map(
            "id", version.Get("id", ""),
            "description", version.Get("description", ""),
            "createdAt", version.Get("createdAt", ""),
            "macroName", version.Get("macroName", ""),
            "actionCount", version.Get("data", Map())
                .Get("actions", []).Length
        ))
    }

    return timeline
}

; ------------------------------------------------------------
; Import and export
; ------------------------------------------------------------

VersionHistory_Export(macroId, versionId, path := "") {
    version := VersionHistory_GetVersion(
        macroId,
        versionId
    )

    if !IsObject(version)
        return false

    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Macro Version",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        Lib_WriteText(
            path,
            JSON.Stringify(version, true)
        )

        return true

    } catch as error {
        ExecutionConsole_Log(
            "Version export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

VersionHistory_Import(path, targetMacroId := "") {
    global MS_Versions, MS_Macros

    if !FileExist(path)
        return false

    try {
        version := JSON.Parse(Lib_ReadText(path))

        if !IsObject(version)
            return false

        required := ["id", "data"]

        for key in required {
            if !version.Has(key)
                return false
        }

        if !IsObject(version["data"])
            return false

        macroId := targetMacroId != ""
            ? targetMacroId
            : version.Get("macroId", "")

        if (macroId = "")
            return false

        if !MS_Macros.Has(macroId)
            return false

        if !MS_Versions["macros"].Has(macroId)
            MS_Versions["macros"][macroId] := []

        imported := Lib_Clone(version)
        imported["macroId"] := macroId
        imported["id"] := VersionHistory_GenerateId()
        imported["createdAt"] := A_Now

        MS_Versions["macros"][macroId].Push(imported)

        VersionHistory_Trim(macroId)
        VersionHistory_Save()

        return imported["id"]

    } catch as error {
        ExecutionConsole_Log(
            "Version import failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Persistence
; ------------------------------------------------------------

VersionHistory_Save() {
    global MS_Versions

    try {
        data := Map(
            "macros", MS_Versions["macros"],
            "maxVersions", MS_Versions["maxVersions"],
            "autoSnapshot", MS_Versions["autoSnapshot"],
            "nextId", MS_Versions["nextId"]
        )

        Storage_SaveVersions(data)
        return true

    } catch as error {
        ExecutionConsole_Log(
            "Version history save failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

VersionHistory_Load() {
    global MS_Versions

    try {
        loaded := Storage_LoadVersions()

        if !IsObject(loaded)
            return false

        if loaded.Has("macros") && IsObject(loaded["macros"])
            MS_Versions["macros"] := loaded["macros"]

        MS_Versions["maxVersions"] := loaded.Get(
            "maxVersions",
            MS_Versions["maxVersions"]
        )

        MS_Versions["autoSnapshot"] := loaded.Get(
            "autoSnapshot",
            MS_Versions["autoSnapshot"]
        )

        MS_Versions["nextId"] := loaded.Get(
            "nextId",
            MS_Versions["nextId"]
        )

        return true

    } catch as error {
        ExecutionConsole_Log(
            "Version history load failed: " error.Message,
            "WARNING"
        )
        return false
    }
}

; ------------------------------------------------------------
; Statistics and utilities
; ------------------------------------------------------------

VersionHistory_GenerateId() {
    global MS_Versions

    id := "version_" MS_Versions["nextId"]
    MS_Versions["nextId"] += 1

    return id
}

VersionHistory_GetStatistics() {
    global MS_Versions

    totalVersions := 0
    macroCount := 0

    for macroId, versions in MS_Versions["macros"] {
        macroCount += 1
        totalVersions += versions.Length
    }

    return Map(
        "macroCount", macroCount,
        "totalVersions", totalVersions,
        "maxVersionsPerMacro", MS_Versions["maxVersions"],
        "autoSnapshot", MS_Versions["autoSnapshot"]
    )
}

VersionHistory_Shutdown() {
    global MS_State, MS_Versions

    if !IsObject(MS_Versions)
        return true

    VersionHistory_Save()

    MS_Versions["ready"] := false
    MS_State["versionHistoryReady"] := false

    return true
}