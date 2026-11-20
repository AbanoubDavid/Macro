
; ============================================================
; MacroStudio - Globals.ahk
; Shared Application State and Global Configuration
; AutoHotkey v2
; ============================================================

#Requires AutoHotkey v2.0

; ============================================================
; 1. APPLICATION CONSTANTS
; ============================================================

global MS_CONSTANTS := Map(
    "APP_NAME", "MacroStudio",
    "APP_VERSION", "1.0.0",
    "APP_AUTHOR", "MacroStudio",
    "DEFAULT_RECORDING_HOTKEY", "F9",
    "DEFAULT_PANIC_HOTKEY", "F12",
    "DEFAULT_STOP_HOTKEY", "F10",
    "DEFAULT_PLAYBACK_SPEED", 1.0,
    "MIN_PLAYBACK_SPEED", 0.5,
    "MAX_PLAYBACK_SPEED", 2.0,
    "DEFAULT_COLOR_TOLERANCE", 10,
    "DEFAULT_PIXEL_TIMEOUT", 10000,
    "MAX_UNDO_HISTORY", 100,
    "MAX_VERSION_HISTORY", 50,
    "DEFAULT_WINDOW_WIDTH", 1280,
    "DEFAULT_WINDOW_HEIGHT", 800
)

; ============================================================
; 2. APPLICATION STATE
; ============================================================

global MS_State := Map()

; ============================================================
; 3. APPLICATION SETTINGS
; ============================================================

global MS_Settings := Map()

; ============================================================
; 4. MACRO DATABASE
; ============================================================

global MS_Macros := []

global MS_ActiveMacro := Map()

global MS_ActiveMacroId := ""

global MS_SelectedMacroId := ""

; ============================================================
; 5. PROFILE MANAGEMENT
; ============================================================

global MS_Profiles := []

global MS_CurrentProfileId := ""

global MS_DefaultProfileId := ""

; ============================================================
; 6. MACRO CHAINING
; ============================================================

global MS_Chains := []

global MS_ActiveChainId := ""

global MS_ChainExecutionState := Map()

; ============================================================
; 7. CONDITIONAL BRANCHING
; ============================================================

global MS_Conditions := []

global MS_ConditionVariables := Map()

global MS_ConditionEvaluationState := Map()

; ============================================================
; 8. MACRO RECORDER
; ============================================================

global MS_Recorder := Map()

; ============================================================
; 9. MACRO EXECUTION
; ============================================================

global MS_Execution := Map()

global MS_ExecutionQueue := []

global MS_ExecutionHistory := []

global MS_ExecutionVariables := Map()

; ============================================================
; 10. SANDBOX
; ============================================================

global MS_Sandbox := Map()

global MS_SandboxExecutionQueue := []

global MS_SandboxHistory := []

; ============================================================
; 11. PIXEL DETECTION
; ============================================================

global MS_Pixel := Map()

global MS_PixelMonitors := []

global MS_PixelDetectionResults := Map()

; ============================================================
; 12. PIXEL PICKER
; ============================================================

global MS_PixelPicker := Map()

; ============================================================
; 13. UNDO / REDO
; ============================================================

global MS_UndoRedo := Map()

; ============================================================
; 14. ACTION TEMPLATES
; ============================================================

global MS_Templates := []

global MS_SelectedTemplateId := ""

; ============================================================
; 15. VERSION HISTORY
; ============================================================

global MS_Versions := []

global MS_SelectedVersionId := ""

; ============================================================
; 16. INPUT HANDLING
; ============================================================

global MS_Input := Map()

global MS_RegisteredHotkeys := []

global MS_InputState := Map()

; ============================================================
; 17. TRIGGER MANAGEMENT
; ============================================================

global MS_Triggers := []

global MS_TriggerState := Map()

; ============================================================
; 18. EDITOR STATE
; ============================================================

global MS_Editor := Map()

global MS_SelectedActionIndex := 0

global MS_SelectedActionIndexes := []

global MS_ClipboardActions := []

; ============================================================
; 19. DRAG AND DROP
; ============================================================

global MS_DragDrop := Map()

; ============================================================
; 20. EXECUTION CONSOLE
; ============================================================

global MS_Console := Map()

global MS_ConsoleEntries := []

; ============================================================
; 21. USER INTERFACE
; ============================================================

global MS_UI := Map()

global MS_MainGui := ""

global MS_CurrentTab := "Dashboard"

global MS_Theme := Map()

; ============================================================
; 22. FILE SYSTEM PATHS
; ============================================================

global MS_Paths := Map()

; ============================================================
; 23. INITIALIZATION CONTROL
; ============================================================

global MS_GlobalsInitialized := false

; ============================================================
; 24. GLOBAL INITIALIZATION FUNCTION
; ============================================================

Globals_Initialize() {

    global MS_CONSTANTS
    global MS_State
    global MS_Settings

    global MS_Macros
    global MS_ActiveMacro
    global MS_ActiveMacroId
    global MS_SelectedMacroId

    global MS_Profiles
    global MS_CurrentProfileId
    global MS_DefaultProfileId

    global MS_Chains
    global MS_ActiveChainId
    global MS_ChainExecutionState

    global MS_Conditions
    global MS_ConditionVariables
    global MS_ConditionEvaluationState

    global MS_Recorder

    global MS_Execution
    global MS_ExecutionQueue
    global MS_ExecutionHistory
    global MS_ExecutionVariables

    global MS_Sandbox
    global MS_SandboxExecutionQueue
    global MS_SandboxHistory

    global MS_Pixel
    global MS_PixelMonitors
    global MS_PixelDetectionResults
    global MS_PixelPicker

    global MS_UndoRedo

    global MS_Templates
    global MS_SelectedTemplateId

    global MS_Versions
    global MS_SelectedVersionId

    global MS_Input
    global MS_RegisteredHotkeys
    global MS_InputState

    global MS_Triggers
    global MS_TriggerState

    global MS_Editor
    global MS_SelectedActionIndex
    global MS_SelectedActionIndexes
    global MS_ClipboardActions

    global MS_DragDrop

    global MS_Console
    global MS_ConsoleEntries

    global MS_UI
    global MS_MainGui
    global MS_CurrentTab
    global MS_Theme

    global MS_Paths
    global MS_GlobalsInitialized

    if MS_GlobalsInitialized
        return true

    ; --------------------------------------------------------
    ; APPLICATION STATE
    ; --------------------------------------------------------

    MS_State := Map(
        "initialized", false,
        "enabled", true,
        "paused", false,
        "shuttingDown", false,
        "busy", false,
        "startupTime", A_TickCount,
        "lastError", "",
        "lastActivity", A_TickCount
    )

    ; --------------------------------------------------------
    ; DEFAULT SETTINGS
    ; --------------------------------------------------------

    MS_Settings := Map(
        "hotkeys", Map(
            "panic", MS_CONSTANTS["DEFAULT_PANIC_HOTKEY"],
            "stop", MS_CONSTANTS["DEFAULT_STOP_HOTKEY"],
            "recordStop", MS_CONSTANTS["DEFAULT_RECORDING_HOTKEY"]
        ),

        "playback", Map(
            "speed", MS_CONSTANTS["DEFAULT_PLAYBACK_SPEED"],
            "randomDelay", false,
            "randomDelayMin", 0,
            "randomDelayMax", 0,
            "coordinateVariation", false,
            "coordinateVariationAmount", 0
        ),

        "recording", Map(
            "keyboard", true,
            "mouse", true,
            "movement", false,
            "delays", true
        ),

        "input", Map(
            "globalKeyDelay", 0,
            "preventRepeatedTriggers", true,
            "triggerCooldown", 100
        ),

        "pixel", Map(
            "defaultTolerance", MS_CONSTANTS["DEFAULT_COLOR_TOLERANCE"],
            "defaultTimeout", MS_CONSTANTS["DEFAULT_PIXEL_TIMEOUT"],
            "defaultTimeoutBehavior", "stop"
        ),

        "startup", Map(
            "startWithWindows", false,
            "minimizeToTray", false,
            "startMinimized", false
        ),

        "editor", Map(
            "autoSave", true,
            "showActionNumbers", true,
            "confirmDelete", true
        ),

        "appearance", Map(
            "theme", "BlackGlass",
            "accent", "#8B7CFF",
            "animations", true
        )
    )

    ; --------------------------------------------------------
    ; MACRO DATABASE
    ; --------------------------------------------------------

    MS_Macros := []

    MS_ActiveMacro := Map()

    MS_ActiveMacroId := ""

    MS_SelectedMacroId := ""

    ; --------------------------------------------------------
    ; PROFILES
    ; --------------------------------------------------------

    MS_Profiles := []

    MS_CurrentProfileId := ""

    MS_DefaultProfileId := ""

    ; --------------------------------------------------------
    ; MACRO CHAINING
    ; --------------------------------------------------------

    MS_Chains := []

    MS_ActiveChainId := ""

    MS_ChainExecutionState := Map(
        "running", false,
        "paused", false,
        "currentIndex", 0,
        "stopRequested", false
    )

    ; --------------------------------------------------------
    ; CONDITIONS
    ; --------------------------------------------------------

    MS_Conditions := []

    MS_ConditionVariables := Map()

    MS_ConditionEvaluationState := Map()

    ; --------------------------------------------------------
    ; RECORDER
    ; --------------------------------------------------------

    MS_Recorder := Map(
        "recording", false,
        "startedAt", 0,
        "duration", 0,
        "actions", [],
        "keyboardEnabled", true,
        "mouseEnabled", true,
        "movementEnabled", false,
        "delaysEnabled", true,
        "lastEventTime", 0,
        "stopHotkey", MS_CONSTANTS["DEFAULT_RECORDING_HOTKEY"]
    )

    ; --------------------------------------------------------
    ; EXECUTION ENGINE
    ; --------------------------------------------------------

    MS_Execution := Map(
        "running", false,
        "paused", false,
        "stopRequested", false,
        "currentMacroId", "",
        "currentActionIndex", 0,
        "playbackSpeed", MS_CONSTANTS["DEFAULT_PLAYBACK_SPEED"],
        "executionStartedAt", 0,
        "executionErrors", 0,
        "executionMode", "normal",
        "activeWindowRestriction", ""
    )

    MS_ExecutionQueue := []

    MS_ExecutionHistory := []

    MS_ExecutionVariables := Map()

    ; --------------------------------------------------------
    ; SANDBOX
    ; --------------------------------------------------------

    MS_Sandbox := Map(
        "active", false,
        "running", false,
        "paused", false,
        "stepMode", true,
        "currentStep", 0,
        "stopRequested", false,
        "testMacroId", "",
        "lastResult", "",
        "isolatedVariables", Map()
    )

    MS_SandboxExecutionQueue := []

    MS_SandboxHistory := []

    ; --------------------------------------------------------
    ; PIXEL DETECTION
    ; --------------------------------------------------------

    MS_Pixel := Map(
        "enabled", true,
        "monitoring", false,
        "defaultTolerance", MS_CONSTANTS["DEFAULT_COLOR_TOLERANCE"],
        "defaultTimeout", MS_CONSTANTS["DEFAULT_PIXEL_TIMEOUT"],
        "monitorInterval", 100,
        "activeMonitorCount", 0
    )

    MS_PixelMonitors := []

    MS_PixelDetectionResults := Map()

    ; --------------------------------------------------------
    ; PIXEL PICKER
    ; --------------------------------------------------------

    MS_PixelPicker := Map(
        "active", false,
        "selectingRegion", false,
        "selectedX", 0,
        "selectedY", 0,
        "regionX", 0,
        "regionY", 0,
        "regionWidth", 0,
        "regionHeight", 0,
        "selectedColor", "",
        "selectedRGB", Map(
            "r", 0,
            "g", 0,
            "b", 0
        )
    )

    ; --------------------------------------------------------
    ; UNDO / REDO
    ; --------------------------------------------------------

    MS_UndoRedo := Map(
        "undoStack", [],
        "redoStack", [],
        "maxHistory", MS_CONSTANTS["MAX_UNDO_HISTORY"],
        "isRestoring", false,
        "lastOperation", ""
    )

    ; --------------------------------------------------------
    ; TEMPLATES
    ; --------------------------------------------------------

    MS_Templates := []

    MS_SelectedTemplateId := ""

    ; --------------------------------------------------------
    ; VERSION HISTORY
    ; --------------------------------------------------------

    MS_Versions := []

    MS_SelectedVersionId := ""

    ; --------------------------------------------------------
    ; INPUT HANDLING
    ; --------------------------------------------------------

    MS_Input := Map(
        "initialized", false,
        "hooksEnabled", false,
        "panicEnabled", true,
        "lastInputTime", 0,
        "inputLocked", false
    )

    MS_RegisteredHotkeys := []

    MS_InputState := Map(
        "pressedKeys", Map(),
        "pressedMouseButtons", Map(),
        "lastTriggerTimes", Map()
    )

    ; --------------------------------------------------------
    ; TRIGGERS
    ; --------------------------------------------------------

    MS_Triggers := []

    MS_TriggerState := Map(
        "enabled", true,
        "processing", false,
        "activeTrigger", "",
        "lastTriggerTime", 0
    )

    ; --------------------------------------------------------
    ; EDITOR
    ; --------------------------------------------------------

    MS_Editor := Map(
        "modified", false,
        "loading", false,
        "dragging", false,
        "previewing", false,
        "currentActionCount", 0,
        "selectedActionType", ""
    )

    MS_SelectedActionIndex := 0

    MS_SelectedActionIndexes := []

    MS_ClipboardActions := []

    ; --------------------------------------------------------
    ; DRAG AND DROP
    ; --------------------------------------------------------

    MS_DragDrop := Map(
        "active", false,
        "sourceIndex", 0,
        "targetIndex", 0,
        "draggedAction", Map()
    )

    ; --------------------------------------------------------
    ; EXECUTION CONSOLE
    ; --------------------------------------------------------

    MS_Console := Map(
        "enabled", true,
        "autoScroll", true,
        "maxEntries", 5000,
        "showDebug", true,
        "showInfo", true,
        "showWarnings", true,
        "showErrors", true
    )

    MS_ConsoleEntries := []

    ; --------------------------------------------------------
    ; USER INTERFACE
    ; --------------------------------------------------------

    MS_UI := Map(
        "initialized", false,
        "visible", false,
        "minimized", false,
        "currentTab", "Dashboard",
        "activeDialog", "",
        "notifications", []
    )

    MS_MainGui := ""

    MS_CurrentTab := "Dashboard"

    MS_Theme := Map(
        "name", "BlackGlass",
        "background", "090A0D",
        "sidebar", "101116",
        "panel", "17191F",
        "secondaryPanel", "20232B",
        "border", "30333D",
        "text", "F3F3F5",
        "secondaryText", "9296A3",
        "accent", "8B7CFF",
        "success", "69D6A0",
        "danger", "F16D78",
        "warning", "E5B94B"
    )

    ; --------------------------------------------------------
    ; FILE PATHS
    ; --------------------------------------------------------

    base := A_ScriptDir

    MS_Paths := Map(
        "root", base,
        "data", base "\Data",
        "backups", base "\Data\Backups",
        "assets", base "\Assets",
        "icons", base "\Assets\Icons",
        "fonts", base "\Assets\Fonts",
        "macros", base "\Data\macros.json",
        "settings", base "\Data\settings.json",
        "profiles", base "\Data\profiles.json",
        "templates", base "\Data\templates.json",
        "chains", base "\Data\chains.json",
        "versions", base "\Data\versions.json"
    )

    ; --------------------------------------------------------
    ; INITIALIZATION COMPLETE
    ; --------------------------------------------------------

    MS_GlobalsInitialized := true

    return true
}

; ============================================================
; 25. GLOBAL STATE HELPERS
; ============================================================

Globals_IsInitialized() {

    global MS_GlobalsInitialized

    return MS_GlobalsInitialized
}

Globals_GetState(key, defaultValue := "") {

    global MS_State

    if MS_State.Has(key)
        return MS_State[key]

    return defaultValue
}

Globals_SetState(key, value) {

    global MS_State

    MS_State[key] := value

    return value
}

Globals_GetPath(key) {

    global MS_Paths

    if !MS_Paths.Has(key)
        throw Error("Unknown application path: " key)

    return MS_Paths[key]
}

Globals_GetSetting(section, key, defaultValue := "") {

    global MS_Settings

    if !MS_Settings.Has(section)
        return defaultValue

    settingsSection := MS_Settings[section]

    if !settingsSection.Has(key)
        return defaultValue

    return settingsSection[key]
}

Globals_SetSetting(section, key, value) {

    global MS_Settings

    if !MS_Settings.Has(section)
        MS_Settings[section] := Map()

    MS_Settings[section][key] := value

    return value
}

Globals_GetThemeColor(key) {

    global MS_Theme

    if !MS_Theme.Has(key)
        throw Error("Unknown theme color: " key)

    return MS_Theme[key]
}

; ============================================================
; 26. GLOBAL VALIDATION
; ============================================================

Globals_Validate() {

    global MS_GlobalsInitialized
    global MS_Settings
    global MS_Paths
    global MS_State

    if !MS_GlobalsInitialized
        throw Error("Global state has not been initialized.")

    if !IsObject(MS_Settings)
        throw Error("Application settings are invalid.")

    if !IsObject(MS_Paths)
        throw Error("Application paths are invalid.")

    if !MS_Paths.Has("root")
        throw Error("Application root path is missing.")

    if !MS_Paths.Has("data")
        throw Error("Application data path is missing.")

    return true
}

; ============================================================
; END OF Globals.ahk
; ============================================================
