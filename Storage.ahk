
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Storage.ahk
; JSON persistence, backups and data management
; ============================================================

global MS_StorageInitialized := false
global MS_StorageBusy := false
global MS_StorageLastSave := 0

; ============================================================
; INITIALIZATION
; ============================================================

Storage_Initialize() {
    global MS_StorageInitialized
    global MS_Paths

    if MS_StorageInitialized
        return true

    if !Storage_EnsureDirectories()
        return false

    Storage_EnsureFile(MS_Paths["macros"], '{"macros":[]}')
    Storage_EnsureFile(MS_Paths["settings"], '{}')
    Storage_EnsureFile(MS_Paths["profiles"], '{"profiles":[]}')
    Storage_EnsureFile(MS_Paths["templates"], '{"templates":[]}')
    Storage_EnsureFile(MS_Paths["chains"], '{"chains":[]}')
    Storage_EnsureFile(MS_Paths["versions"], '{"versions":[]}')

    MS_StorageInitialized := true
    return true
}

; ============================================================
; DIRECTORY MANAGEMENT
; ============================================================

Storage_EnsureDirectories() {
    global MS_Paths

    st_paths := [
        MS_Paths["data"],
        MS_Paths["backups"],
        MS_Paths["assets"],
        MS_Paths["icons"],
        MS_Paths["fonts"]
    ]

    for st_path in st_paths {
        if !DirExist(st_path) {
            try {
                DirCreate(st_path)
            } catch as st_error {
                ExecutionConsole_Log(
                    "ERROR",
                    "Could not create directory: " . st_path . " - " . st_error.Message
                )
                return false
            }
        }
    }

    return true
}

Storage_EnsureFile(st_path, st_defaultContent := "{}") {
    if FileExist(st_path)
        return true

    try {
        st_directory := RegExReplace(st_path, "\\[^\\]+$")

        if st_directory != "" && !DirExist(st_directory)
            DirCreate(st_directory)

        st_file := FileOpen(st_path, "w", "UTF-8")

        if !IsObject(st_file)
            return false

        st_file.Write(st_defaultContent)
        st_file.Close()

        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Could not create file: " . st_path . " - " . st_error.Message
        )
        return false
    }
}

; ============================================================
; JSON ENCODING
; ============================================================

Storage_EncodeJSON(st_value, st_indent := 2) {
    return JSON.Stringify(st_value, st_indent)
}

Storage_DecodeJSON(st_jsonText) {
    if Type(st_jsonText) != "String"
        throw TypeError("JSON input must be a string.")

    return JSON.Parse(st_jsonText)
}

; ============================================================
; FILE READING
; ============================================================

Storage_ReadFile(st_path, st_defaultValue := "") {
    if !FileExist(st_path)
        return st_defaultValue

    try {
        return FileRead(st_path, "UTF-8")
    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Could not read file: " . st_path . " - " . st_error.Message
        )
        return st_defaultValue
    }
}

; ============================================================
; SAFE FILE WRITING
; ============================================================

Storage_WriteFile(st_path, st_content) {
    global MS_StorageBusy

    if MS_StorageBusy
        return false

    MS_StorageBusy := true

    st_tempPath := st_path . ".tmp"
    st_file := ""

    try {
        st_directory := RegExReplace(st_path, "\\[^\\]+$")

        if st_directory != "" && !DirExist(st_directory)
            DirCreate(st_directory)

        st_file := FileOpen(st_tempPath, "w", "UTF-8")

        if !IsObject(st_file)
            throw Error("Unable to create temporary file.")

        st_file.Write(st_content)
        st_file.Close()
        st_file := ""

        FileMove(st_tempPath, st_path, 1)

        return true

    } catch as st_error {
        if IsObject(st_file) {
            try {
                st_file.Close()
            }
        }

        if FileExist(st_tempPath) {
            try {
                FileDelete(st_tempPath)
            }
        }

        ExecutionConsole_Log(
            "ERROR",
            "Could not write file: " . st_path . " - " . st_error.Message
        )

        return false

    } finally {
        MS_StorageBusy := false
    }
}

; ============================================================
; BACKUPS
; ============================================================

Storage_CreateBackup(st_path) {
    global MS_Paths

    if !FileExist(st_path)
        return false

    SplitPath(
        st_path,
        &st_fileName,
        &st_directory,
        &st_extension,
        &st_nameWithoutExtension
    )

    st_timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")

    st_backupName := st_nameWithoutExtension . "_" . st_timestamp . "." . st_extension
    st_backupPath := MS_Paths["backups"] . "\" . st_backupName

    try {
        FileCopy(st_path, st_backupPath, 1)
        Storage_CleanupBackups()
        return st_backupPath

    } catch as st_error {
        ExecutionConsole_Log(
            "WARNING",
            "Could not create backup: " . st_path . " - " . st_error.Message
        )
        return false
    }
}

Storage_CleanupBackups(st_maxBackups := 50) {
    global MS_Paths

    st_files := []

    Loop Files, MS_Paths["backups"] . "\*", "F" {
        st_files.Push({
            path: A_LoopFileFullPath,
            time: A_LoopFileTimeModified
        })
    }

    if st_files.Length <= st_maxBackups
        return true

    loop st_files.Length {
        loop st_files.Length - A_Index {
            st_index := A_Index

            if st_files[st_index].time > st_files[st_index + 1].time {
                st_temporary := st_files[st_index]
                st_files[st_index] := st_files[st_index + 1]
                st_files[st_index + 1] := st_temporary
            }
        }
    }

    st_deleteCount := st_files.Length - st_maxBackups

    loop st_deleteCount {
        try {
            FileDelete(st_files[A_Index].path)
        } catch {
            ; Continue cleaning remaining backups.
        }
    }

    return true
}

; ============================================================
; MACRO SERIALIZATION
; ============================================================

Storage_SaveMacros() {
    global MS_Macros
    global MS_Paths

    st_serialized := []

    for st_id, st_macro in MS_Macros
        st_serialized.Push(Storage_ObjectToMap(st_macro))

    st_data := Map(
        "version", 1,
        "savedAt", A_Now,
        "macros", st_serialized
    )

    st_json := Storage_EncodeJSON(st_data)

    Storage_CreateBackup(MS_Paths["macros"])

    return Storage_WriteFile(MS_Paths["macros"], st_json)
}

Storage_LoadMacros() {
    global MS_Macros
    global MS_Paths

    st_json := Storage_ReadFile(MS_Paths["macros"], "")

    if st_json = ""
        return false

    try {
        st_data := Storage_DecodeJSON(st_json)

        if !(st_data is Map) || !st_data.Has("macros")
            return false

        st_loaded := Map()

        for st_macro in st_data["macros"] {
            if !(st_macro is Map)
                continue

            if !st_macro.Has("id")
                continue

            st_id := st_macro["id"]

            if st_id = ""
                continue

            if !st_macro.Has("actions")
                st_macro["actions"] := []

            st_loaded[st_id] := Storage_ObjectToMap(st_macro)
        }

        MS_Macros := st_loaded
        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Failed to load macros: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; SETTINGS SERIALIZATION
; ============================================================

Storage_SaveSettings() {
    global MS_Settings
    global MS_Paths

    st_data := Storage_ObjectToMap(MS_Settings)
    st_json := Storage_EncodeJSON(st_data)

    Storage_CreateBackup(MS_Paths["settings"])

    return Storage_WriteFile(MS_Paths["settings"], st_json)
}

Storage_LoadSettings() {
    global MS_Settings
    global MS_Paths

    st_json := Storage_ReadFile(MS_Paths["settings"], "")

    if st_json = ""
        return false

    try {
        st_data := Storage_DecodeJSON(st_json)

        if !(st_data is Map)
            return false

        for st_key, st_value in st_data
            MS_Settings[st_key] := st_value

        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Failed to load settings: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; PROFILE SERIALIZATION
; ============================================================

Storage_SaveProfiles() {
    global MS_Profiles
    global MS_Paths

    st_profiles := []

    for st_id, st_profile in MS_Profiles
        st_profiles.Push(Storage_ObjectToMap(st_profile))

    st_data := Map(
        "profiles", st_profiles,
        "savedAt", A_Now
    )

    Storage_CreateBackup(MS_Paths["profiles"])

    return Storage_WriteFile(
        MS_Paths["profiles"],
        Storage_EncodeJSON(st_data)
    )
}

Storage_LoadProfiles() {
    global MS_Profiles
    global MS_Paths

    st_json := Storage_ReadFile(MS_Paths["profiles"], "")

    if st_json = ""
        return false

    try {
        st_data := Storage_DecodeJSON(st_json)

        if !(st_data is Map) || !st_data.Has("profiles")
            return false

        st_loaded := Map()

        for st_profile in st_data["profiles"] {
            if !(st_profile is Map) || !st_profile.Has("id")
                continue

            st_loaded[st_profile["id"]] := Storage_ObjectToMap(st_profile)
        }

        MS_Profiles := st_loaded
        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Failed to load profiles: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; TEMPLATE SERIALIZATION
; ============================================================

Storage_SaveTemplates(data := unset) {
    global MS_Templates, MS_Paths
    st_source := IsSet(data) && IsObject(data) ? data : MS_Templates
    st_items := st_source.Has("items") && IsObject(st_source["items"])
        ? st_source["items"]
        : Map()
    st_templates := []
    for st_id, st_template in st_items
        st_templates.Push(Storage_ObjectToMap(st_template))
    st_data := Map(
        "templates", st_templates,
        "nextId", st_source.Get("nextId", 1),
        "savedAt", A_Now
    )
    Storage_CreateBackup(MS_Paths["templates"])
    return Storage_WriteFile(MS_Paths["templates"], Storage_EncodeJSON(st_data))
}

Storage_LoadTemplates() {
    global MS_Paths
    st_json := Storage_ReadFile(MS_Paths["templates"], "")
    if st_json = ""
        return Map("items", Map(), "nextId", 1)
    try {
        st_data := Storage_DecodeJSON(st_json)
        if !(st_data is Map) || !st_data.Has("templates")
            throw Error("Invalid template data.")
        st_loaded := Map()
        for st_template in st_data["templates"] {
            if !(st_template is Map) || !st_template.Has("id")
                continue
            st_loaded[st_template["id"]] := Storage_ObjectToMap(st_template)
        }
        return Map("items", st_loaded, "nextId", st_data.Get("nextId", st_loaded.Count + 1))
    } catch as st_error {
        ExecutionConsole_Log("ERROR", "Failed to load templates: " . st_error.Message)
        return Map("items", Map(), "nextId", 1)
    }
}

; ============================================================
; CHAIN SERIALIZATION
; ============================================================

Storage_SaveChains() {
    global MS_Chains
    global MS_Paths

    st_chains := []

    for st_id, st_chain in MS_Chains
        st_chains.Push(Storage_ObjectToMap(st_chain))

    st_data := Map(
        "chains", st_chains,
        "savedAt", A_Now
    )

    Storage_CreateBackup(MS_Paths["chains"])

    return Storage_WriteFile(
        MS_Paths["chains"],
        Storage_EncodeJSON(st_data)
    )
}

Storage_LoadChains() {
    global MS_Chains
    global MS_Paths

    st_json := Storage_ReadFile(MS_Paths["chains"], "")

    if st_json = ""
        return false

    try {
        st_data := Storage_DecodeJSON(st_json)

        if !(st_data is Map) || !st_data.Has("chains")
            return false

        st_loaded := Map()

        for st_chain in st_data["chains"] {
            if !(st_chain is Map) || !st_chain.Has("id")
                continue

            st_loaded[st_chain["id"]] := Storage_ObjectToMap(st_chain)
        }

        MS_Chains := st_loaded
        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Failed to load chains: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; VERSION HISTORY SERIALIZATION
; ============================================================

Storage_SaveVersions(data := unset) {
    global MS_Versions, MS_Paths
    st_source := IsSet(data) && IsObject(data) ? data : MS_Versions
    st_macroVersions := st_source.Get("macros", Map())
    st_versions := []
    for st_macroId, st_list in st_macroVersions {
        for st_version in st_list
            st_versions.Push(Storage_ObjectToMap(st_version))
    }
    st_data := Map(
        "versions", st_versions,
        "maxVersions", st_source.Get("maxVersions", 50),
        "autoSnapshot", st_source.Get("autoSnapshot", true),
        "nextId", st_source.Get("nextId", 1),
        "savedAt", A_Now
    )
    Storage_CreateBackup(MS_Paths["versions"])
    return Storage_WriteFile(MS_Paths["versions"], Storage_EncodeJSON(st_data))
}

Storage_LoadVersions() {
    global MS_Paths
    st_json := Storage_ReadFile(MS_Paths["versions"], "")
    if st_json = ""
        return Map("macros", Map(), "maxVersions", 50, "autoSnapshot", true, "nextId", 1)
    try {
        st_data := Storage_DecodeJSON(st_json)
        if !(st_data is Map) || !st_data.Has("versions")
            throw Error("Invalid version history data.")
        st_loaded := Map()
        for st_version in st_data["versions"] {
            if !(st_version is Map) || !st_version.Has("id")
                continue
            st_macroId := st_version.Get("macroId", "")
            if st_macroId = ""
                continue
            if !st_loaded.Has(st_macroId)
                st_loaded[st_macroId] := []
            st_loaded[st_macroId].Push(Storage_ObjectToMap(st_version))
        }
        return Map(
            "macros", st_loaded,
            "maxVersions", st_data.Get("maxVersions", 50),
            "autoSnapshot", st_data.Get("autoSnapshot", true),
            "nextId", st_data.Get("nextId", 1)
        )
    } catch as st_error {
        ExecutionConsole_Log("ERROR", "Failed to load versions: " . st_error.Message)
        return Map("macros", Map(), "maxVersions", 50, "autoSnapshot", true, "nextId", 1)
    }
}

; ============================================================
; SAVE ALL DATA
; ============================================================

Storage_SaveAll() {
    global MS_StorageLastSave

    st_results := []

    st_results.Push(Storage_SaveMacros())
    st_results.Push(Storage_SaveSettings())
    st_results.Push(Storage_SaveProfiles())
    st_results.Push(Storage_SaveTemplates())
    st_results.Push(Storage_SaveChains())
    st_results.Push(Storage_SaveVersions())

    st_success := true

    for st_result in st_results {
        if !st_result
            st_success := false
    }

    if st_success
        MS_StorageLastSave := A_TickCount

    return st_success
}

; ============================================================
; LOAD ALL DATA
; ============================================================

Storage_LoadAll() {
    st_results := []

    st_results.Push(Storage_LoadMacros())
    st_results.Push(Storage_LoadSettings())
    st_results.Push(Storage_LoadProfiles())
    st_results.Push(Storage_LoadTemplates())
    st_results.Push(Storage_LoadChains())
    st_results.Push(Storage_LoadVersions())

    st_success := true

    for st_result in st_results {
        if !st_result
            st_success := false
    }

    return st_success
}

; ============================================================
; OBJECT CONVERSION
; ============================================================

Storage_ObjectToMap(st_value) {
    if !IsObject(st_value)
        return st_value

    if st_value is Array {
        st_result := []

        for st_item in st_value
            st_result.Push(Storage_ObjectToMap(st_item))

        return st_result
    }

    if st_value is Map {
        st_result := Map()

        for st_key, st_item in st_value
            st_result[st_key] := Storage_ObjectToMap(st_item)

        return st_result
    }

    if st_value is Object {
        st_result := Map()

        for st_key, st_item in st_value.OwnProps()
            st_result[st_key] := Storage_ObjectToMap(st_item)

        return st_result
    }

    return st_value
}

; ============================================================
; IMPORT / EXPORT
; ============================================================

Storage_ExportMacros(st_path) {
    global MS_Macros

    st_data := Map(
        "version", 1,
        "exportedAt", A_Now,
        "macros", []
    )

    for st_id, st_macro in MS_Macros
        st_data["macros"].Push(Storage_ObjectToMap(st_macro))

    try {
        return Storage_WriteFile(
            st_path,
            Storage_EncodeJSON(st_data)
        )
    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Export failed: " . st_error.Message
        )
        return false
    }
}

Storage_ImportMacros(st_path, st_overwrite := false) {
    global MS_Macros

    if !FileExist(st_path)
        return false

    try {
        st_json := FileRead(st_path, "UTF-8")
        st_data := Storage_DecodeJSON(st_json)

        if !(st_data is Map) || !st_data.Has("macros")
            return false

        st_imported := 0

        for st_macro in st_data["macros"] {
            if !(st_macro is Map) || !st_macro.Has("id")
                continue

            st_id := st_macro["id"]

            if MS_Macros.Has(st_id) && !st_overwrite
                continue

            if !st_macro.Has("actions")
                st_macro["actions"] := []

            MS_Macros[st_id] := Storage_ObjectToMap(st_macro)
            st_imported += 1
        }

        Storage_SaveMacros()
        return st_imported

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Import failed: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; RESTORE BACKUP
; ============================================================

Storage_RestoreBackup(st_backupPath, st_destinationPath) {
    if !FileExist(st_backupPath)
        return false

    try {
        FileCopy(st_backupPath, st_destinationPath, 1)
        return true

    } catch as st_error {
        ExecutionConsole_Log(
            "ERROR",
            "Could not restore backup: " . st_error.Message
        )
        return false
    }
}

; ============================================================
; SHUTDOWN
; ============================================================

Storage_Shutdown() {
    global MS_StorageInitialized

    if MS_StorageInitialized
        Storage_SaveAll()

    MS_StorageInitialized := false
    return true
}

; ============================================================
; END OF Storage.ahk
; ============================================================
