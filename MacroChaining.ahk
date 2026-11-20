; ============================================================
; MacroStudio - Macro Chaining
; Creates and executes sequences of multiple macros.
; AutoHotkey v2
; ============================================================

MacroChaining_Initialize() {
    global MS_State, MS_Chains

    if !IsObject(MS_Chains)
        MS_Chains := Map()

    MS_State["macroChainingReady"] := true
    MS_State["activeChainId"] := ""
    MS_State["chainRunning"] := false
    MS_State["chainStopRequested"] := false
    MS_State["chainCurrentIndex"] := 0
    MS_State["chainTotal"] := 0

    MacroChaining_Load()
    return true
}

; ------------------------------------------------------------
; Storage
; ------------------------------------------------------------

MacroChaining_Load() {
    global MS_Chains

    try {
        loaded := Storage_LoadChains()

        if IsObject(loaded) && (Type(loaded) = "Map")
            MS_Chains := loaded

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Could not load macro chains: " error.Message,
            "WARNING"
        )
        return false
    }
}

MacroChaining_Save() {
    try {
        return Storage_SaveChains()
    } catch as error {
        ExecutionConsole_Log(
            "Could not save macro chains: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Chain creation and management
; ------------------------------------------------------------

MacroChaining_Create(name, description := "") {
    global MS_Chains

    name := Trim(name)

    if (name = "")
        return false

    if MacroChaining_NameExists(name)
        return false

    chainId := Lib_GenerateId("chain")

    chain := Map(
        "id", chainId,
        "name", name,
        "description", description,
        "macros", [],
        "enabled", true,
        "loop", false,
        "loopCount", 1,
        "stopOnFailure", true,
        "createdAt", Lib_GetTimestamp(),
        "updatedAt", Lib_GetTimestamp()
    )

    MS_Chains[chainId] := chain
    MacroChaining_Save()

    ExecutionConsole_Log(
        "Created chain: " name,
        "INFO"
    )

    return chainId
}

MacroChaining_Delete(chainId) {
    global MS_Chains, MS_State

    if !MS_Chains.Has(chainId)
        return false

    if (MS_State.Get("activeChainId", "") = chainId)
        MacroChaining_Stop()

    MS_Chains.Delete(chainId)
    MacroChaining_Save()

    return true
}

MacroChaining_Rename(chainId, newName) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    newName := Trim(newName)

    if (newName = "" || MacroChaining_NameExists(newName, chainId))
        return false

    chain := MS_Chains[chainId]
    chain["name"] := newName
    chain["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_Duplicate(chainId, newName := "") {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    copy := Lib_Clone(MS_Chains[chainId])

    if !IsObject(copy)
        return false

    if (newName = "")
        newName := copy["name"] " Copy"

    if MacroChaining_NameExists(newName)
        return false

    copy["id"] := Lib_GenerateId("chain")
    copy["name"] := newName
    copy["createdAt"] := Lib_GetTimestamp()
    copy["updatedAt"] := Lib_GetTimestamp()

    MS_Chains[copy["id"]] := copy
    MacroChaining_Save()

    return copy["id"]
}

; ------------------------------------------------------------
; Macro list management
; ------------------------------------------------------------

MacroChaining_AddMacro(chainId, macroId) {
    global MS_Chains, MS_Macros

    if !MS_Chains.Has(chainId) || !MS_Macros.Has(macroId)
        return false

    chain := MS_Chains[chainId]
    macros := chain.Get("macros", [])

    if !IsObject(macros)
        macros := []

    macros.Push(Map(
        "macroId", macroId,
        "enabled", true,
        "delayBefore", 0,
        "delayAfter", 0
    ))

    chain["macros"] := macros
    chain["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_RemoveMacro(chainId, index) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    macros := MS_Chains[chainId].Get("macros", [])

    if !IsObject(macros)
        return false

    if (index < 1 || index > macros.Length)
        return false

    macros.RemoveAt(index)

    MS_Chains[chainId]["macros"] := macros
    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_MoveMacro(chainId, sourceIndex, targetIndex) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    macros := MS_Chains[chainId].Get("macros", [])

    if !IsObject(macros)
        return false

    if (sourceIndex < 1 || sourceIndex > macros.Length)
        return false

    if (targetIndex < 1 || targetIndex > macros.Length)
        return false

    if (sourceIndex = targetIndex)
        return true

    moved := macros.RemoveAt(sourceIndex)
    macros.InsertAt(targetIndex, moved)

    MS_Chains[chainId]["macros"] := macros
    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_SetMacroDelay(chainId, index, before := unset, after := unset) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    macros := MS_Chains[chainId].Get("macros", [])

    if !IsObject(macros) || index < 1 || index > macros.Length
        return false

    entry := macros[index]

    if IsSet(before)
        entry["delayBefore"] := Max(0, Min(3600000, before))

    if IsSet(after)
        entry["delayAfter"] := Max(0, Min(3600000, after))

    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_EnableEntry(chainId, index, enabled := true) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    macros := MS_Chains[chainId].Get("macros", [])

    if !IsObject(macros) || index < 1 || index > macros.Length
        return false

    macros[index]["enabled"] := enabled

    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

; ------------------------------------------------------------
; Chain configuration
; ------------------------------------------------------------

MacroChaining_SetLoop(chainId, enabled, count := 1) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    chain := MS_Chains[chainId]
    chain["loop"] := enabled
    chain["loopCount"] := Max(1, Min(10000, count))
    chain["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_SetStopOnFailure(chainId, enabled) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    MS_Chains[chainId]["stopOnFailure"] := enabled
    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

MacroChaining_SetEnabled(chainId, enabled) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    MS_Chains[chainId]["enabled"] := enabled
    MS_Chains[chainId]["updatedAt"] := Lib_GetTimestamp()

    MacroChaining_Save()
    return true
}

; ------------------------------------------------------------
; Chain execution
; ------------------------------------------------------------

MacroChaining_Execute(chainId) {
    global MS_Chains, MS_Macros, MS_State

    if !MS_State.Get("macroChainingReady", false)
        return false

    if MS_State.Get("chainRunning", false)
        return false

    if !MS_Chains.Has(chainId)
        return false

    chain := MS_Chains[chainId]

    if !chain.Get("enabled", true)
        return false

    macros := chain.Get("macros", [])

    if !IsObject(macros) || macros.Length = 0
        return false

    MS_State["chainRunning"] := true
    MS_State["chainStopRequested"] := false
    MS_State["activeChainId"] := chainId
    MS_State["chainCurrentIndex"] := 0
    MS_State["chainTotal"] := macros.Length

    try {
        loopEnabled := chain.Get("loop", false)
        loopCount := loopEnabled ? chain.Get("loopCount", 1) : 1
        stopOnFailure := chain.Get("stopOnFailure", true)

        Loop loopCount {
            if MacroChaining_ShouldStop()
                break

            for index, entry in macros {
                if MacroChaining_ShouldStop()
                    break

                MS_State["chainCurrentIndex"] := index

                if !entry.Get("enabled", true)
                    continue

                macroId := entry.Get("macroId", "")

                if (macroId = "" || !MS_Macros.Has(macroId)) {
                    if stopOnFailure
                        return false
                    continue
                }

                delayBefore := entry.Get("delayBefore", 0)

                if (delayBefore > 0) {
                    if !MacroChaining_Wait(delayBefore)
                        break
                }

                if MacroChaining_ShouldStop()
                    break

                success := PlaybackEngine_Start(macroId)

                if !success && stopOnFailure
                    return false

                delayAfter := entry.Get("delayAfter", 0)

                if (delayAfter > 0) {
                    if !MacroChaining_Wait(delayAfter)
                        break
                }
            }
        }

        return !MacroChaining_ShouldStop()
    } catch as error {
        ExecutionConsole_Log(
            "Chain execution failed: " error.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["chainRunning"] := false
        MS_State["chainStopRequested"] := false
        MS_State["activeChainId"] := ""
        MS_State["chainCurrentIndex"] := 0
        MS_State["chainTotal"] := 0

        UI_SetStatus("Chain finished")
    }
}

MacroChaining_ShouldStop() {
    global MS_State

    return MS_State.Get("chainStopRequested", false)
        || MS_State.Get("stopRequested", false)
        || !MS_State.Get("enabled", true)
}

MacroChaining_Wait(duration) {
    remaining := Max(0, duration)

    while (remaining > 0) {
        if MacroChaining_ShouldStop()
            return false

        interval := Min(remaining, 25)
        Sleep(interval)
        remaining -= interval
    }

    return true
}

MacroChaining_Stop() {
    global MS_State

    if !MS_State.Get("chainRunning", false)
        return false

    MS_State["chainStopRequested"] := true

    PlaybackEngine_Stop()

    ExecutionConsole_Log(
        "Macro chain stop requested",
        "WARNING"
    )

    return true
}

; ------------------------------------------------------------
; Chain information
; ------------------------------------------------------------

MacroChaining_Get(chainId) {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return ""

    return MS_Chains[chainId]
}

MacroChaining_GetAll() {
    global MS_Chains
    return MS_Chains
}

MacroChaining_GetCount() {
    global MS_Chains
    return MS_Chains.Count
}

MacroChaining_GetActive() {
    global MS_State
    return MS_State.Get("activeChainId", "")
}

MacroChaining_GetProgress() {
    global MS_State

    current := MS_State.Get("chainCurrentIndex", 0)
    total := MS_State.Get("chainTotal", 0)

    if (total <= 0)
        return 0

    return Round((current / total) * 100)
}

MacroChaining_NameExists(name, exceptId := "") {
    global MS_Chains

    for chainId, chain in MS_Chains {
        if (chainId = exceptId)
            continue

        if (StrLower(chain.Get("name", "")) = StrLower(name))
            return true
    }

    return false
}

; ------------------------------------------------------------
; Validation
; ------------------------------------------------------------

MacroChaining_Validate(chain) {
    global MS_Macros

    if !IsObject(chain)
        return false

    if !chain.Has("name") || !chain.Has("macros")
        return false

    macros := chain["macros"]

    if !IsObject(macros)
        return false

    for entry in macros {
        if !IsObject(entry)
            return false

        macroId := entry.Get("macroId", "")

        if (macroId = "" || !MS_Macros.Has(macroId))
            return false
    }

    return true
}

; ------------------------------------------------------------
; Import and export
; ------------------------------------------------------------

MacroChaining_Export(chainId, path := "") {
    global MS_Chains

    if !MS_Chains.Has(chainId)
        return false

    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Macro Chain",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        content := JSON.Stringify(MS_Chains[chainId], true)
        Lib_WriteText(path, content)
        return true
    } catch as error {
        ExecutionConsole_Log(
            "Chain export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

MacroChaining_Import(path := "") {
    global MS_Chains

    if (path = "") {
        path := FileSelect(
            "1",
            A_ScriptDir "\Data",
            "Import Macro Chain",
            "JSON Files (*.json)"
        )
    }

    if (path = "" || !FileExist(path))
        return false

    try {
        chain := JSON.Parse(Lib_ReadText(path))

        if !IsObject(chain)
            return false

        if !chain.Has("name") || !chain.Has("macros")
            return false

        chainId := Lib_GenerateId("chain")

        chain["id"] := chainId

        if MacroChaining_NameExists(chain["name"])
            chain["name"] .= " Imported"

        chain["createdAt"] := Lib_GetTimestamp()
        chain["updatedAt"] := Lib_GetTimestamp()

        MS_Chains[chainId] := chain
        MacroChaining_Save()

        return chainId
    } catch as error {
        ExecutionConsole_Log(
            "Chain import failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

MacroChaining_Shutdown() {
    global MS_State

    if MS_State.Get("chainRunning", false)
        MacroChaining_Stop()

    MacroChaining_Save()

    MS_State["macroChainingReady"] := false

    return true
}