
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All

; ============================================================
; MacroStudio
; Main Application Entry Point
; AutoHotkey v2
; ============================================================

; ------------------------------------------------------------
; APPLICATION CONFIGURATION
; ------------------------------------------------------------

SetWorkingDir(A_ScriptDir)
SetTitleMatchMode(2)

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

SendMode("Input")

; ------------------------------------------------------------
; APPLICATION STATE
; ------------------------------------------------------------

global MS_AppVersion := "1.0.0"
global MS_AppName := "MacroStudio"
global MS_AppReady := false
global MS_AppShuttingDown := false

; ------------------------------------------------------------
; DIRECTORY INITIALIZATION
; ------------------------------------------------------------

MS_CreateDirectories()

; ------------------------------------------------------------
; CORE MODULES
; ------------------------------------------------------------

#Include Globals.ahk
#Include Lib.ahk
#Include Storage.ahk
#Include Settings.ahk

; ------------------------------------------------------------
; MAIN FUNCTIONAL MODULES
; ------------------------------------------------------------

#Include Editor.ahk
#Include Recorder.ahk
#Include Logic.ahk
#Include PixelPicker.ahk
#Include InputHandler.ahk

; ------------------------------------------------------------
; SPECIALIZED MODULES
; ------------------------------------------------------------

#Include Modules\KeyboardUI.ahk
#Include Modules\MouseUI.ahk
#Include Modules\TriggerManager.ahk
#Include Modules\PlaybackEngine.ahk
#Include Modules\ActionManager.ahk

; ------------------------------------------------------------
; ADVANCED FEATURES
; ------------------------------------------------------------

#Include Modules\UndoRedo.ahk
#Include Modules\ProfileManager.ahk
#Include Modules\DragDropManager.ahk
#Include Modules\MacroChaining.ahk
#Include Modules\ConditionalBranching.ahk
#Include Modules\Sandbox.ahk
#Include Modules\MultiPixelDetection.ahk
#Include Modules\ExecutionConsole.ahk
#Include Modules\TemplateManager.ahk
#Include Modules\VersionHistory.ahk

; ------------------------------------------------------------
; USER INTERFACE
; ------------------------------------------------------------

#Include UI.ahk

; ------------------------------------------------------------
; EXIT HANDLER
; ------------------------------------------------------------

OnExit(MS_HandleExit)

; ------------------------------------------------------------
; APPLICATION STARTUP
; ------------------------------------------------------------

try {
    MS_Initialize()
}
catch as err {
    MS_ShowStartupError(err)
    ExitApp(1)
}

; ============================================================
; DIRECTORY MANAGEMENT
; ============================================================

MS_CreateDirectories() {
    base := A_ScriptDir

    directories := [
        base "\Data",
        base "\Data\Backups",
        base "\Assets",
        base "\Assets\Icons",
        base "\Assets\Fonts",
        base "\Modules"
    ]

    for directory in directories {
        if !DirExist(directory)
            DirCreate(directory)
    }
}

; ============================================================
; APPLICATION INITIALIZATION
; ============================================================

MS_Initialize() {
    global MS_AppReady

    ; STEP 1: Initialize global application state
    Globals_Initialize()

    ; STEP 2: Initialize persistent storage
    Storage_Initialize()

    ; STEP 3: Load application settings
    Settings_Initialize()

    ; STEP 4: Initialize execution diagnostics
    ExecutionConsole_Initialize()

    ExecutionConsole_Log(
        "INFO",
        "Initializing MacroStudio..."
    )

    ; STEP 5: Initialize macro profiles
    ProfileManager_Initialize()

    ; STEP 6: Initialize macro editing systems
    UndoRedo_Initialize()
    ActionManager_Initialize()
    DragDropManager_Initialize()

    ; STEP 7: Initialize macro organization systems
    TemplateManager_Initialize()
    VersionHistory_Initialize()

    ; STEP 8: Initialize macro logic
    ConditionalBranching_Initialize()
    MacroChaining_Initialize()

    ; STEP 9: Initialize pixel detection
    MultiPixelDetection_Initialize()
    PixelPicker_Initialize()

    ; STEP 10: Initialize execution systems
    Sandbox_Initialize()
    TriggerManager_Initialize()
    PlaybackEngine_Initialize()

    ; STEP 11: Initialize recording and input handling
    Recorder_Initialize()
    InputHandler_Initialize()

    ; STEP 12: Initialize the graphical interface
    UI_Initialize()

    ; APPLICATION READY
    MS_AppReady := true

    ExecutionConsole_Log(
        "SUCCESS",
        "MacroStudio initialized successfully."
    )
}

; ============================================================
; STARTUP ERROR HANDLING
; ============================================================

MS_ShowStartupError(err) {
    errorMessage :=
        "MacroStudio encountered a startup error."
        . "`n`n"
        . "Error: " . err.Message
        . "`n"
        . "File: " . err.File
        . "`n"
        . "Line: " . err.Line
        . "`n`n"
        . "Please check the affected module."

    MsgBox(
        errorMessage,
        "MacroStudio - Startup Error",
        "Iconx"
    )
}

; ============================================================
; APPLICATION SHUTDOWN
; ============================================================

MS_HandleExit(exitReason, exitCode) {
    global MS_AppShuttingDown

    if MS_AppShuttingDown
        return

    MS_AppShuttingDown := true

    MS_Shutdown()
}

MS_Shutdown() {
    global MS_AppReady

    ; STEP 1: Stop active recording
    try {
        Recorder_Shutdown()
    }
    catch as err {
        OutputDebug(
            "MacroStudio: Recorder shutdown error: "
            . err.Message
        )
    }

    ; STEP 2: Stop active macro playback
    try {
        PlaybackEngine_Shutdown()
    }
    catch as err {
        OutputDebug(
            "MacroStudio: Playback shutdown error: "
            . err.Message
        )
    }

    ; STEP 3: Disable physical trigger handling
    try {
        TriggerManager_Shutdown()
    }
    catch as err {
        OutputDebug(
            "MacroStudio: Trigger shutdown error: "
            . err.Message
        )
    }

    ; STEP 4: Release input hooks and handlers
    try {
        InputHandler_Shutdown()
    }
    catch as err {
        OutputDebug(
            "MacroStudio: Input shutdown error: "
            . err.Message
        )
    }

    ; STEP 5: Save application data
    try {
        Storage_SaveAll()
    }
    catch as err {
        MsgBox(
            "Failed to save application data."
            . "`n`n"
            . err.Message,
            "MacroStudio - Save Error",
            "Icon!"
        )
    }

    ; STEP 6: Finalize shutdown
    MS_AppReady := false

    OutputDebug(
        "MacroStudio: Application shutdown complete."
    )
}
