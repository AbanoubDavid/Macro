
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Settings.ahk
; Application settings, preferences and configuration
; ============================================================

global MS_SettingsInitialized := false
global MS_SettingsDefaults := Map()
global MS_SettingsChanged := false

; ============================================================
; INITIALIZATION
; ============================================================

Settings_Initialize() {
    global MS_Settings
    global MS_SettingsDefaults
    global MS_SettingsInitialized
    global MS_SettingsChanged

    MS_SettingsDefaults := Settings_GetDefaults()

    if !IsObject(MS_Settings)
        MS_Settings := Map()

    Settings_ApplyDefaults()

    MS_SettingsInitialized := true
    MS_SettingsChanged := false

    return true
}

Settings_GetDefaults() {
    return Map(
        "theme", "dark",
        "accentColor", "8B5CF6",
        "fontSize", 10,
        "windowWidth", 1280,
        "windowHeight", 800,
        "windowMaximized", false,
        "minimizeToTray", false,
        "startMinimized", false,
        "startWithWindows", false,
        "confirmDelete", true,
        "confirmClear", true,
        "autoSave", true,
        "autoSaveInterval", 60,
        "createBackups", true,
        "maximumBackups", 20,
        "emergencyToggleHotkey", "F12",
        "emergencyStopHotkey", "F10",
        "recordingStopHotkey", "F9",
        "defaultPlaybackSpeed", 1.0,
        "randomizeTiming", false,
        "randomTimingMinimum", 0,
        "randomTimingMaximum", 15,
        "randomizeCoordinates", false,
        "coordinateVariation", 2,
        "pixelTolerance", 10,
        "pixelSearchStep", 2,
        "pixelTimeout", 5000,
        "defaultRepeatCount", 1,
        "maximumRepeatCount", 10000,
        "preventRecursiveTriggers", true,
        "ignoreInjectedInput", true,
        "restrictToActiveWindow", false,
        "showExecutionConsole", true,
        "consoleMaximumLines", 500,
        "showNotifications", true,
        "notificationDuration", 3,
        "recordKeyboard", true,
        "recordMouseButtons", true,
        "recordMouseMovement", true,
        "recordDelays", true,
        "mouseMovementPrecision", 5,
        "movementMinimumDistance", 3,
        "editorShowActionNumbers", true,
        "editorConfirmUnsavedChanges", true,
        "editorDefaultDelay", 100,
        "undoHistoryLimit", 100,
        "versionHistoryLimit", 50,
        "sandboxEnabled", true,
        "sandboxMaximumExecutionTime", 30000,
        "sandboxMaximumActions", 10000,
        "profileAutoSwitch", false,
        "profileDefault", "Default",
        "language", "en",
        "checkForUpdates", true,
        "debugMode", false
    )
}

Settings_ApplyDefaults() {
    global MS_Settings
    global MS_SettingsDefaults

    for st_key, st_value in MS_SettingsDefaults {
        if !MS_Settings.Has(st_key)
            MS_Settings[st_key] := st_value
    }

    return true
}

; ============================================================
; GET / SET
; ============================================================

Settings_Get(st_key, st_defaultValue := unset) {
    global MS_Settings

    if MS_Settings.Has(st_key)
        return MS_Settings[st_key]

    if IsSet(st_defaultValue)
        return st_defaultValue

    return ""
}

Settings_Set(st_key, st_value, st_save := false) {
    global MS_Settings
    global MS_SettingsChanged

    if !Settings_Validate(st_key, st_value)
        return false

    MS_Settings[st_key] := st_value
    MS_SettingsChanged := true

    if st_save
        return Settings_Save()

    return true
}

Settings_Reset(st_key) {
    global MS_Settings
    global MS_SettingsDefaults
    global MS_SettingsChanged

    if !MS_SettingsDefaults.Has(st_key)
        return false

    MS_Settings[st_key] := MS_SettingsDefaults[st_key]
    MS_SettingsChanged := true

    return true
}

Settings_ResetAll(st_save := false) {
    global MS_Settings
    global MS_SettingsDefaults
    global MS_SettingsChanged

    MS_Settings := Map()

    for st_key, st_value in MS_SettingsDefaults
        MS_Settings[st_key] := st_value

    MS_SettingsChanged := true

    if st_save
        return Settings_Save()

    return true
}

; ============================================================
; VALIDATION
; ============================================================

Settings_Validate(st_key, st_value) {
    st_booleanSettings := [
        "randomizeTiming",
        "randomizeCoordinates",
        "minimizeToTray",
        "startMinimized",
        "startWithWindows",
        "confirmDelete",
        "confirmClear",
        "autoSave",
        "createBackups",
        "windowMaximized",
        "preventRecursiveTriggers",
        "ignoreInjectedInput",
        "restrictToActiveWindow",
        "showExecutionConsole",
        "showNotifications",
        "recordKeyboard",
        "recordMouseButtons",
        "recordMouseMovement",
        "recordDelays",
        "editorShowActionNumbers",
        "editorConfirmUnsavedChanges",
        "sandboxEnabled",
        "profileAutoSwitch",
        "checkForUpdates",
        "debugMode"
    ]

    for st_booleanKey in st_booleanSettings {
        if st_key = st_booleanKey
            return (st_value = true || st_value = false)
    }

    switch st_key {
        case "fontSize":
            return IsNumber(st_value) && st_value >= 7 && st_value <= 24

        case "windowWidth":
            return IsNumber(st_value) && st_value >= 800 && st_value <= 7680

        case "windowHeight":
            return IsNumber(st_value) && st_value >= 500 && st_value <= 4320

        case "autoSaveInterval":
            return IsNumber(st_value) && st_value >= 5 && st_value <= 3600

        case "maximumBackups":
            return IsNumber(st_value) && st_value >= 1 && st_value <= 500

        case "defaultPlaybackSpeed":
            return IsNumber(st_value)
                && st_value >= 0.1
                && st_value <= 10

        case "randomTimingMinimum":
            return IsNumber(st_value)
                && st_value >= 0
                && st_value <= 60000

        case "randomTimingMaximum":
            return IsNumber(st_value)
                && st_value >= 0
                && st_value <= 60000

        case "coordinateVariation":
            return IsNumber(st_value)
                && st_value >= 0
                && st_value <= 1000

        case "pixelTolerance":
            return IsNumber(st_value)
                && st_value >= 0
                && st_value <= 255

        case "pixelSearchStep":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 100

        case "pixelTimeout":
            return IsNumber(st_value)
                && st_value >= 100
                && st_value <= 600000

        case "defaultRepeatCount":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 10000

        case "maximumRepeatCount":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 1000000

        case "consoleMaximumLines":
            return IsNumber(st_value)
                && st_value >= 50
                && st_value <= 10000

        case "notificationDuration":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 60

        case "mouseMovementPrecision":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 100

        case "movementMinimumDistance":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 1000

        case "editorDefaultDelay":
            return IsNumber(st_value)
                && st_value >= 0
                && st_value <= 600000

        case "undoHistoryLimit":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 1000

        case "versionHistoryLimit":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 1000

        case "sandboxMaximumExecutionTime":
            return IsNumber(st_value)
                && st_value >= 100
                && st_value <= 600000

        case "sandboxMaximumActions":
            return IsNumber(st_value)
                && st_value >= 1
                && st_value <= 1000000

        case "accentColor":
            return Type(st_value) = "String"
                && RegExMatch(st_value, "i)^[0-9A-F]{6}$")

        case "theme":
            return st_value = "dark"
                || st_value = "light"
                || st_value = "system"

        case "emergencyToggleHotkey":
        case "emergencyStopHotkey":
        case "recordingStopHotkey":
            return Type(st_value) = "String" && Trim(st_value) != ""

        default:
            return true
    }
}

; ============================================================
; SAVE / LOAD
; ============================================================

Settings_Save() {
    global MS_SettingsChanged

    try {
        st_result := Storage_SaveSettings()

        if st_result
            MS_SettingsChanged := false

        return st_result

    } catch as st_error {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Settings save failed: " . st_error.Message
            )
        }

        return false
    }
}

Settings_Load() {
    global MS_SettingsChanged

    try {
        st_loaded := Storage_LoadSettings()

        if st_loaded
            Settings_ApplyDefaults()

        MS_SettingsChanged := false

        return st_loaded

    } catch as st_error {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Settings load failed: " . st_error.Message
            )
        }

        return false
    }
}

; ============================================================
; HOTKEY SETTINGS
; ============================================================

Settings_UpdateEmergencyHotkeys(
    st_toggleHotkey,
    st_stopHotkey,
    st_save := true
) {
    if !Settings_Validate(
        "emergencyToggleHotkey",
        st_toggleHotkey
    )
        return false

    if !Settings_Validate(
        "emergencyStopHotkey",
        st_stopHotkey
    )
        return false

    if StrLower(st_toggleHotkey) = StrLower(st_stopHotkey)
        return false

    Settings_Set("emergencyToggleHotkey", st_toggleHotkey)
    Settings_Set("emergencyStopHotkey", st_stopHotkey)

    try {
        InputHandler_UnregisterHotkey("emergencyToggle")
        InputHandler_UnregisterHotkey("emergencyStop")

        InputHandler_RegisterHotkey(
            "emergencyToggle",
            st_toggleHotkey,
            InputHandler_ToggleAll
        )

        InputHandler_RegisterHotkey(
            "emergencyStop",
            st_stopHotkey,
            InputHandler_StopCurrent
        )

    } catch as st_error {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Could not update emergency hotkeys: " . st_error.Message
            )
        }

        return false
    }

    if st_save
        return Settings_Save()

    return true
}

Settings_UpdateRecordingHotkey(st_hotkey, st_save := true) {
    if !Settings_Validate(
        "recordingStopHotkey",
        st_hotkey
    )
        return false

    Settings_Set("recordingStopHotkey", st_hotkey)

    try {
        Recorder_SetStopHotkey(st_hotkey)
    } catch {
        return false
    }

    if st_save
        return Settings_Save()

    return true
}

; ============================================================
; PLAYBACK SETTINGS
; ============================================================

Settings_SetPlaybackSpeed(st_speed, st_save := false) {
    if !Settings_Validate("defaultPlaybackSpeed", st_speed)
        return false

    Settings_Set("defaultPlaybackSpeed", st_speed)

    if st_save
        return Settings_Save()

    return true
}

Settings_GetPlaybackSpeed() {
    return Settings_Get("defaultPlaybackSpeed", 1.0)
}

; ============================================================
; PIXEL SETTINGS
; ============================================================

Settings_SetPixelTolerance(st_tolerance, st_save := false) {
    if !Settings_Validate("pixelTolerance", st_tolerance)
        return false

    Settings_Set("pixelTolerance", st_tolerance)

    if st_save
        return Settings_Save()

    return true
}

Settings_GetPixelTolerance() {
    return Settings_Get("pixelTolerance", 10)
}

; ============================================================
; AUTOSAVE
; ============================================================

Settings_StartAutoSave() {
    if !Settings_Get("autoSave", true)
        return false

    st_interval := Settings_Get("autoSaveInterval", 60)

    SetTimer(
        Settings_AutoSave,
        st_interval * 1000
    )

    return true
}

Settings_StopAutoSave() {
    SetTimer(Settings_AutoSave, 0)
    return true
}

Settings_AutoSave() {
    global MS_SettingsChanged

    if !Settings_Get("autoSave", true)
        return

    if MS_SettingsChanged
        Settings_Save()

    try {
        Editor_AutoSave()
    }
}

; ============================================================
; THEME
; ============================================================

Settings_ApplyTheme() {
    global MS_Theme

    st_theme := Settings_Get("theme", "dark")
    st_accent := Settings_Get("accentColor", "8B5CF6")

    if st_theme = "system"
        st_theme := "dark"

    if st_theme = "dark" {
        MS_Theme["background"] := "101014"
        MS_Theme["panel"] := "19191F"
        MS_Theme["panelAlt"] := "202027"
        MS_Theme["border"] := "303039"
        MS_Theme["text"] := "F4F4F5"
        MS_Theme["muted"] := "A1A1AA"
        MS_Theme["accent"] := st_accent

    } else if st_theme = "light" {
        MS_Theme["background"] := "F4F4F5"
        MS_Theme["panel"] := "FFFFFF"
        MS_Theme["panelAlt"] := "E4E4E7"
        MS_Theme["border"] := "D4D4D8"
        MS_Theme["text"] := "18181B"
        MS_Theme["muted"] := "71717A"
        MS_Theme["accent"] := st_accent
    }

    try {
        UI_RefreshTheme()
    }

    return true
}

Settings_SetTheme(st_theme, st_save := false) {
    if !Settings_Validate("theme", st_theme)
        return false

    Settings_Set("theme", st_theme)
    Settings_ApplyTheme()

    if st_save
        return Settings_Save()

    return true
}

Settings_SetAccentColor(st_color, st_save := false) {
    if !Settings_Validate("accentColor", st_color)
        return false

    Settings_Set("accentColor", st_color)
    Settings_ApplyTheme()

    if st_save
        return Settings_Save()

    return true
}

; ============================================================
; WINDOW SETTINGS
; ============================================================

Settings_SaveWindowSize(st_width, st_height) {
    if !Settings_Validate("windowWidth", st_width)
        return false

    if !Settings_Validate("windowHeight", st_height)
        return false

    Settings_Set("windowWidth", st_width)
    Settings_Set("windowHeight", st_height)

    return true
}

Settings_GetWindowSize() {
    return Map(
        "width", Settings_Get("windowWidth", 1280),
        "height", Settings_Get("windowHeight", 800)
    )
}

; ============================================================
; EXPORT / IMPORT
; ============================================================

Settings_Export(st_path) {
    global MS_Settings

    if Type(st_path) != "String" || Trim(st_path) = ""
        return false

    try {
        st_json := JSON.Stringify(MS_Settings, 4)

        if FileExist(st_path)
            FileDelete(st_path)

        FileAppend(st_json, st_path, "UTF-8")

        return true

    } catch as st_error {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Settings export failed: " . st_error.Message
            )
        }

        return false
    }
}

Settings_Import(st_path) {
    global MS_Settings
    global MS_SettingsChanged

    if !FileExist(st_path)
        return false

    try {
        st_json := FileRead(st_path, "UTF-8")
        st_imported := JSON.Parse(st_json)

        if !(st_imported is Map)
            return false

        for st_key, st_value in st_imported {
            if Settings_Validate(st_key, st_value)
                MS_Settings[st_key] := st_value
        }

        Settings_ApplyDefaults()
        Settings_ApplyTheme()

        MS_SettingsChanged := true

        return Settings_Save()

    } catch as st_error {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Settings import failed: " . st_error.Message
            )
        }

        return false
    }
}

; ============================================================
; WINDOWS STARTUP
; ============================================================

Settings_SetWindowsStartup(st_enabled) {
    st_startupPath := A_Startup . "\MacroStudio.lnk"

    if st_enabled {
        try {
            if FileExist(st_startupPath)
                FileDelete(st_startupPath)

            FileCreateShortcut(
                A_ScriptFullPath,
                st_startupPath,
                A_WorkingDir,
                "",
                "Launch MacroStudio"
            )

            Settings_Set("startWithWindows", true)

            return true

        } catch as st_error {
            try {
                ExecutionConsole_Log(
                    "ERROR",
                    "Could not enable Windows startup: " . st_error.Message
                )
            }

            return false
        }
    }

    try {
        if FileExist(st_startupPath)
            FileDelete(st_startupPath)

        Settings_Set("startWithWindows", false)

        return true

    } catch {
        return false
    }
}

; ============================================================
; SETTINGS STATUS
; ============================================================

Settings_IsDirty() {
    global MS_SettingsChanged
    return MS_SettingsChanged
}

Settings_GetAll() {
    global MS_Settings
    return MS_Settings.Clone()
}

Settings_GetDefaultsCopy() {
    global MS_SettingsDefaults
    return MS_SettingsDefaults.Clone()
}

; ============================================================
; SHUTDOWN
; ============================================================

Settings_Shutdown() {
    global MS_SettingsChanged

    Settings_StopAutoSave()

    if MS_SettingsChanged
        Settings_Save()

    return true
}

; ============================================================
; END OF Settings.ahk
; ============================================================
