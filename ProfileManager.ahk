; ============================================================
; MacroStudio - Profile Manager
; Manages macro profiles and profile switching.
; AutoHotkey v2
; ============================================================

ProfileManager_Initialize() {
    global MS_State, MS_Profiles

    if !IsObject(MS_Profiles)
        MS_Profiles := Map()

    MS_State["profileManagerReady"] := true
    MS_State["activeProfileId"] := ""
    MS_State["profileSwitching"] := false

    ProfileManager_Load()
    ProfileManager_EnsureDefault()

    return true
}

; ------------------------------------------------------------
; Loading and saving
; ------------------------------------------------------------

ProfileManager_Load() {
    global MS_Profiles

    try {
        loaded := Storage_LoadProfiles()

        if IsObject(loaded) && (Type(loaded) = "Map")
            MS_Profiles := loaded

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Could not load profiles: " error.Message,
            "WARNING"
        )
        return false
    }
}

ProfileManager_Save() {
    global MS_Profiles

    try {
        return Storage_SaveProfiles()
    } catch as error {
        ExecutionConsole_Log(
            "Could not save profiles: " error.Message,
            "ERROR"
        )
        return false
    }
}

ProfileManager_EnsureDefault() {
    global MS_Profiles

    if (MS_Profiles.Count = 0) {
        ProfileManager_Create(
            "Default",
            "Default MacroStudio profile"
        )
    }

    return true
}

; ------------------------------------------------------------
; Profile creation and deletion
; ------------------------------------------------------------

ProfileManager_Create(name, description := "") {
    global MS_Profiles

    name := Trim(name)

    if (name = "")
        return false

    if ProfileManager_NameExists(name)
        return false

    profileId := Lib_GenerateId("profile")

    profile := Map(
        "id", profileId,
        "name", name,
        "description", description,
        "createdAt", Lib_GetTimestamp(),
        "updatedAt", Lib_GetTimestamp(),
        "enabled", true,
        "settings", Map(),
        "macroIds", [],
        "triggers", Map()
    )

    MS_Profiles[profileId] := profile

    ProfileManager_Save()

    ExecutionConsole_Log(
        "Created profile: " name,
        "INFO"
    )

    return profileId
}

ProfileManager_Delete(profileId) {
    global MS_Profiles, MS_State

    if !MS_Profiles.Has(profileId)
        return false

    if (MS_State.Get("activeProfileId", "") = profileId)
        MS_State["activeProfileId"] := ""

    MS_Profiles.Delete(profileId)

    ProfileManager_EnsureDefault()
    ProfileManager_Save()

    ExecutionConsole_Log(
        "Deleted profile: " profileId,
        "INFO"
    )

    return true
}

ProfileManager_Rename(profileId, newName) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    newName := Trim(newName)

    if (newName = "")
        return false

    if ProfileManager_NameExists(newName, profileId)
        return false

    profile := MS_Profiles[profileId]
    profile["name"] := newName
    profile["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

ProfileManager_Duplicate(profileId, newName := "") {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    source := MS_Profiles[profileId]
    copy := Lib_Clone(source)

    if !IsObject(copy)
        return false

    copy["id"] := Lib_GenerateId("profile")

    if (newName = "")
        newName := source["name"] " Copy"

    if ProfileManager_NameExists(newName)
        return false

    copy["name"] := newName
    copy["createdAt"] := Lib_GetTimestamp()
    copy["updatedAt"] := Lib_GetTimestamp()

    MS_Profiles[copy["id"]] := copy

    ProfileManager_Save()

    return copy["id"]
}

; ------------------------------------------------------------
; Profile switching
; ------------------------------------------------------------

ProfileManager_Activate(profileId) {
    global MS_Profiles, MS_State, MS_Settings

    if !MS_Profiles.Has(profileId)
        return false

    if MS_State.Get("profileSwitching", false)
        return false

    profile := MS_Profiles[profileId]

    if !profile.Get("enabled", true)
        return false

    MS_State["profileSwitching"] := true

    try {
        previousId := MS_State.Get("activeProfileId", "")

        if (previousId != "")
            ProfileManager_SaveCurrentSettings(previousId)

        settings := profile.Get("settings", Map())

        if IsObject(settings) {
            for key, value in settings
                MS_Settings[key] := Lib_Clone(value)
        }

        MS_State["activeProfileId"] := profileId

        Settings_ApplyTheme()
        TriggerManager_LoadFromMacros()

        ProfileManager_Save()

        ExecutionConsole_Log(
            "Activated profile: " profile.Get("name", profileId),
            "INFO"
        )

        UI_SetStatus(
            "Active profile: " profile.Get("name", profileId)
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Profile activation failed: " error.Message,
            "ERROR"
        )
        return false
    } finally {
        MS_State["profileSwitching"] := false
    }
}

ProfileManager_Deactivate() {
    global MS_State

    profileId := MS_State.Get("activeProfileId", "")

    if (profileId = "")
        return true

    ProfileManager_SaveCurrentSettings(profileId)

    MS_State["activeProfileId"] := ""

    ProfileManager_Save()

    return true
}

ProfileManager_SaveCurrentSettings(profileId) {
    global MS_Profiles, MS_Settings

    if !MS_Profiles.Has(profileId)
        return false

    profile := MS_Profiles[profileId]
    profile["settings"] := Lib_Clone(MS_Settings)
    profile["updatedAt"] := Lib_GetTimestamp()

    return true
}

; ------------------------------------------------------------
; Profile settings
; ------------------------------------------------------------

ProfileManager_SetSetting(profileId, key, value) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    profile := MS_Profiles[profileId]

    if !IsObject(profile.Get("settings", ""))
        profile["settings"] := Map()

    profile["settings"][key] := value
    profile["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

ProfileManager_GetSetting(profileId, key, defaultValue := unset) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return IsSet(defaultValue) ? defaultValue : ""

    settings := MS_Profiles[profileId].Get("settings", Map())

    if IsObject(settings) && settings.Has(key)
        return settings[key]

    return IsSet(defaultValue) ? defaultValue : ""
}

ProfileManager_ResetSettings(profileId) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    MS_Profiles[profileId]["settings"] := Map()
    MS_Profiles[profileId]["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

; ------------------------------------------------------------
; Macro assignment
; ------------------------------------------------------------

ProfileManager_AddMacro(profileId, macroId) {
    global MS_Profiles, MS_Macros

    if !MS_Profiles.Has(profileId)
        return false

    if !MS_Macros.Has(macroId)
        return false

    profile := MS_Profiles[profileId]
    macroIds := profile.Get("macroIds", [])

    if !IsObject(macroIds)
        macroIds := []

    for existingId in macroIds {
        if (existingId = macroId)
            return true
    }

    macroIds.Push(macroId)

    profile["macroIds"] := macroIds
    profile["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

ProfileManager_RemoveMacro(profileId, macroId) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    profile := MS_Profiles[profileId]
    macroIds := profile.Get("macroIds", [])

    if !IsObject(macroIds)
        return false

    Loop macroIds.Length {
        index := macroIds.Length - A_Index + 1

        if (macroIds[index] = macroId)
            macroIds.RemoveAt(index)
    }

    profile["macroIds"] := macroIds
    profile["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

ProfileManager_GetMacros(profileId) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return []

    return MS_Profiles[profileId].Get("macroIds", [])
}

ProfileManager_GetMacroCount(profileId) {
    macroIds := ProfileManager_GetMacros(profileId)

    if !IsObject(macroIds)
        return 0

    return macroIds.Length
}

; ------------------------------------------------------------
; Profile triggers
; ------------------------------------------------------------

ProfileManager_SetTrigger(profileId, macroId, trigger) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    if !IsObject(trigger)
        return false

    profile := MS_Profiles[profileId]

    if !IsObject(profile.Get("triggers", ""))
        profile["triggers"] := Map()

    profile["triggers"][macroId] := Lib_Clone(trigger)
    profile["updatedAt"] := Lib_GetTimestamp()

    ProfileManager_Save()
    return true
}

ProfileManager_GetTrigger(profileId, macroId) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return ""

    triggers := MS_Profiles[profileId].Get("triggers", Map())

    if IsObject(triggers) && triggers.Has(macroId)
        return triggers[macroId]

    return ""
}

; ------------------------------------------------------------
; Profile information
; ------------------------------------------------------------

ProfileManager_Get(profileId) {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return ""

    return MS_Profiles[profileId]
}

ProfileManager_GetAll() {
    global MS_Profiles
    return MS_Profiles
}

ProfileManager_GetNames() {
    global MS_Profiles

    names := []

    for profileId, profile in MS_Profiles
        names.Push(profile.Get("name", profileId))

    return names
}

ProfileManager_GetActive() {
    global MS_State
    return MS_State.Get("activeProfileId", "")
}

ProfileManager_GetActiveName() {
    global MS_State, MS_Profiles

    profileId := MS_State.Get("activeProfileId", "")

    if (profileId = "" || !MS_Profiles.Has(profileId))
        return "None"

    return MS_Profiles[profileId].Get("name", "Unnamed")
}

ProfileManager_GetCount() {
    global MS_Profiles
    return MS_Profiles.Count
}

ProfileManager_NameExists(name, exceptId := "") {
    global MS_Profiles

    for profileId, profile in MS_Profiles {
        if (profileId = exceptId)
            continue

        if (StrLower(profile.Get("name", "")) = StrLower(name))
            return true
    }

    return false
}

; ------------------------------------------------------------
; Import and export
; ------------------------------------------------------------

ProfileManager_Export(profileId, path := "") {
    global MS_Profiles

    if !MS_Profiles.Has(profileId)
        return false

    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Profile",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        content := JSON.Stringify(
            MS_Profiles[profileId],
            true
        )

        Lib_WriteText(path, content)

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Profile export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

ProfileManager_Import(path := "") {
    global MS_Profiles

    if (path = "") {
        path := FileSelect(
            "1",
            A_ScriptDir "\Data",
            "Import Profile",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    if !FileExist(path)
        return false

    try {
        content := Lib_ReadText(path)
        profile := JSON.Parse(content)

        if !IsObject(profile)
            return false

        if !profile.Has("name")
            return false

        profileId := Lib_GenerateId("profile")

        profile["id"] := profileId

        if ProfileManager_NameExists(profile["name"])
            profile["name"] .= " Imported"

        profile["createdAt"] := Lib_GetTimestamp()
        profile["updatedAt"] := Lib_GetTimestamp()

        MS_Profiles[profileId] := profile

        ProfileManager_Save()

        return profileId
    } catch as error {
        ExecutionConsole_Log(
            "Profile import failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Shutdown
; ------------------------------------------------------------

ProfileManager_Shutdown() {
    global MS_State

    profileId := MS_State.Get("activeProfileId", "")

    if (profileId != "")
        ProfileManager_SaveCurrentSettings(profileId)

    ProfileManager_Save()

    MS_State["profileManagerReady"] := false

    return true
}