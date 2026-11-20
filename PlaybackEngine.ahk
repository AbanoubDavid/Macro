
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - PlaybackEngine.ahk
; Macro execution, playback control and action scheduling
; ============================================================

global MS_Playback := Map()
global MS_PlaybackTimer := 0
global MS_PlaybackRunning := false
global MS_PlaybackPaused := false
global MS_PlaybackStopRequested := false
global MS_PlaybackCurrentIndex := 0
global MS_PlaybackCurrentActions := []
global MS_PlaybackStartTime := 0
global MS_PlaybackElapsedBeforePause := 0
global MS_PlaybackCurrentMacroId := ""
global MS_PlaybackExecutionId := 0
global MS_PlaybackLoopCount := 0

; ============================================================
; INITIALIZATION
; ============================================================

PlaybackEngine_Initialize() {
    global MS_Playback

    MS_Playback := Map(
        "initialized", true,
        "running", false,
        "paused", false,
        "stopRequested", false,
        "currentIndex", 0,
        "totalActions", 0,
        "currentMacroId", "",
        "startTime", 0,
        "elapsed", 0,
        "speed", 1.0,
        "loopCount", 0,
        "currentLoop", 0,
        "error", "",
        "lastAction", "",
        "executionId", 0
    )

    return true
}

; ============================================================
; START PLAYBACK
; ============================================================

PlaybackEngine_Start(macro, options := unset) {
    global MS_Playback
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStopRequested
    global MS_PlaybackCurrentIndex
    global MS_PlaybackCurrentActions
    global MS_PlaybackStartTime
    global MS_PlaybackElapsedBeforePause
    global MS_PlaybackCurrentMacroId
    global MS_PlaybackExecutionId
    global MS_PlaybackLoopCount
    global MS_State

    if MS_PlaybackRunning
        PlaybackEngine_Stop()

    if !IsObject(macro)
        return false

    if !macro.Has("actions") || !IsObject(macro["actions"])
        return false

    if !MS_State.Get("enabled", true)
        return false

    if macro["actions"].Length = 0
        return false

    settings := Map()

    if IsSet(options) && IsObject(options) {
        for key, value in options
            settings[key] := value
    }

    speed := settings.Has("speed")
        ? settings["speed"]
        : Settings_GetPlaybackSpeed()

    if !IsNumber(speed) || speed <= 0
        speed := 1.0

    repeatCount := settings.Has("repeatCount")
        ? settings["repeatCount"]
        : 1

    repeatCount := Max(
        1,
        Min(10000, Round(repeatCount))
    )

    if !PlaybackEngine_CheckWindowRestriction(macro)
        return false

    MS_PlaybackCurrentActions := Lib_Clone(
        macro["actions"]
    )

    MS_PlaybackCurrentIndex := 0
    MS_PlaybackRunning := true
    MS_PlaybackPaused := false
    MS_PlaybackStopRequested := false
    MS_PlaybackStartTime := A_TickCount
    MS_PlaybackElapsedBeforePause := 0
    MS_PlaybackLoopCount := 0
    MS_PlaybackCurrentMacroId := macro.Has("id")
        ? String(macro["id"])
        : ""

    MS_PlaybackExecutionId += 1

    MS_Playback["running"] := true
    MS_Playback["paused"] := false
    MS_Playback["stopRequested"] := false
    MS_Playback["currentIndex"] := 0
    MS_Playback["totalActions"] := MS_PlaybackCurrentActions.Length
    MS_Playback["currentMacroId"] := MS_PlaybackCurrentMacroId
    MS_Playback["startTime"] := MS_PlaybackStartTime
    MS_Playback["speed"] := speed
    MS_Playback["loopCount"] := repeatCount
    MS_Playback["currentLoop"] := 0
    MS_Playback["error"] := ""
    MS_Playback["executionId"] := MS_PlaybackExecutionId

    if MS_State.Has("stopRequested")
        MS_State["stopRequested"] := false

    try {
        ExecutionConsole_Log(
            "INFO",
            "Starting macro playback: "
            (macro.Has("name") ? macro["name"] : "Untitled")
        )
    }

    try {
        UI_SetStatus("Playing macro...")
    }

    try {
        PlaybackEngine_Run(repeatCount, MS_PlaybackExecutionId)
        return true
    }
    catch as playbackError {
        MS_Playback["error"] := playbackError.Message

        PlaybackEngine_Stop()

        try {
            ExecutionConsole_Log(
                "ERROR",
                "Playback failed: " . playbackError.Message
            )
        }

        return false
    }
}

; ============================================================
; PLAYBACK LOOP
; ============================================================

PlaybackEngine_Run(repeatCount, executionId) {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStopRequested
    global MS_PlaybackCurrentActions
    global MS_PlaybackCurrentIndex
    global MS_PlaybackLoopCount
    global MS_Playback

    loop repeatCount {
        if !PlaybackEngine_ShouldContinue(executionId)
            break

        MS_PlaybackLoopCount := A_Index
        MS_Playback["currentLoop"] := A_Index

        for index, action in MS_PlaybackCurrentActions {
            if !PlaybackEngine_ShouldContinue(executionId)
                break

            PlaybackEngine_WaitWhilePaused(executionId)

            if !PlaybackEngine_ShouldContinue(executionId)
                break

            MS_PlaybackCurrentIndex := index
            MS_Playback["currentIndex"] := index

            if !IsObject(action)
                continue

            if !PlaybackEngine_ExecuteAction(action) {
                if MS_Playback["stopRequested"]
                    break
            }

            Sleep(0)
        }
    }

    if executionId = MS_PlaybackExecutionId
        PlaybackEngine_Finish()
}

; ============================================================
; EXECUTE ACTION
; ============================================================

PlaybackEngine_ExecuteAction(action) {
    global MS_Playback
    global MS_PlaybackCurrentIndex

    if !IsObject(action)
        return false

    if !action.Has("type")
        return false

    actionType := String(action["type"])

    if !action.Has("data")
        action["data"] := Map()

    actionData := action["data"]

    if !IsObject(actionData)
        return false

    MS_Playback["lastAction"] := actionType

    try {
        if actionType = "delay" {
            duration := actionData.Has("duration")
                ? actionData["duration"]
                : 0

            return PlaybackEngine_Wait(duration)
        }

        if actionType = "condition"
            return Logic_ExecuteCondition(actionData)

        if actionType = "waitUntil"
            return Logic_WaitUntil(actionData)

        if actionType = "repeat"
            return Logic_ExecuteRepeat(actionData)

        if actionType = "branch"
            return Logic_ExecuteBranch(actionData)

        if actionType = "chain"
            return MacroChaining_Execute(actionData)

        if actionType = "pixel"
            return Logic_EvaluatePixelCondition(actionData)

        if actionType = "keyboard"
            return PlaybackEngine_ExecuteKeyboard(actionData)

        if actionType = "mouse"
            return PlaybackEngine_ExecuteMouse(actionData)

        if actionType = "mouseMove"
            return PlaybackEngine_ExecuteMouseMove(actionData)

        if actionType = "keyCombination"
            return PlaybackEngine_ExecuteCombination(actionData)

        if actionType = "custom"
            return ActionManager_Execute(action)

        return ActionManager_Execute(action)
    }
    catch as actionError {
        MS_Playback["error"] := actionError.Message

        try {
            ExecutionConsole_Log(
                "ERROR",
                "Action " . MS_PlaybackCurrentIndex
                . " failed: " . actionError.Message
            )
        }

        return false
    }
}

; ============================================================
; KEYBOARD ACTIONS
; ============================================================

PlaybackEngine_ExecuteKeyboard(data) {
    if !data.Has("key")
        return false

    key := data["key"]

    mode := data.Has("mode")
        ? data["mode"]
        : "press"

    return InputHandler_SendKey(
        key,
        mode
    )
}

PlaybackEngine_ExecuteCombination(data) {
    if !data.Has("keys")
        return false

    return InputHandler_SendCombination(
        data["keys"]
    )
}

; ============================================================
; MOUSE ACTIONS
; ============================================================

PlaybackEngine_ExecuteMouse(data) {
    button := data.Has("button")
        ? data["button"]
        : "LButton"

    mode := data.Has("mode")
        ? data["mode"]
        : "click"

    switch mode {
        case "click":
            return InputHandler_MouseClick(button)

        case "down":
            return InputHandler_MouseDown(button)

        case "up":
            return InputHandler_MouseUp(button)

        default:
            return false
    }
}

PlaybackEngine_ExecuteMouseMove(data) {
    if !data.Has("x") || !data.Has("y")
        return false

    speed := data.Has("speed")
        ? data["speed"]
        : 0

    return InputHandler_MouseMove(
        data["x"],
        data["y"],
        speed
    )
}

; ============================================================
; TIMING
; ============================================================

PlaybackEngine_Wait(duration) {
    global MS_Playback

    if !IsNumber(duration)
        return false

    duration := Max(
        0,
        Min(600000, duration)
    )

    speed := MS_Playback["speed"]

    if speed <= 0
        speed := 1.0

    duration := duration / speed

    if Settings_Get("randomizeTiming", false) {
        minimum := Settings_Get(
            "randomTimingMinimum",
            0
        )

        maximum := Settings_Get(
            "randomTimingMaximum",
            15
        )

        if maximum < minimum {
            temporary := maximum
            maximum := minimum
            minimum := temporary
        }

        duration += Random(
            Round(minimum),
            Round(maximum)
        )
    }

    duration := Max(0, Round(duration))

    start := A_TickCount

    while A_TickCount - start < duration {
        if !PlaybackEngine_ShouldContinue()
            return false

        PlaybackEngine_WaitWhilePaused()

        Sleep(10)
    }

    return true
}

; ============================================================
; PAUSE / RESUME
; ============================================================

PlaybackEngine_Pause() {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStartTime
    global MS_PlaybackElapsedBeforePause
    global MS_Playback

    if !MS_PlaybackRunning || MS_PlaybackPaused
        return false

    MS_PlaybackPaused := true
    MS_Playback["paused"] := true

    MS_PlaybackElapsedBeforePause += (
        A_TickCount - MS_PlaybackStartTime
    )

    try {
        ExecutionConsole_Log(
            "INFO",
            "Playback paused."
        )
    }

    try {
        UI_SetStatus("Playback paused")
    }

    return true
}

PlaybackEngine_Resume() {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStartTime
    global MS_Playback

    if !MS_PlaybackRunning || !MS_PlaybackPaused
        return false

    MS_PlaybackPaused := false
    MS_Playback["paused"] := false

    MS_PlaybackStartTime := A_TickCount

    try {
        ExecutionConsole_Log(
            "INFO",
            "Playback resumed."
        )
    }

    try {
        UI_SetStatus("Playing macro...")
    }

    return true
}

PlaybackEngine_TogglePause() {
    global MS_PlaybackPaused

    if MS_PlaybackPaused
        return PlaybackEngine_Resume()

    return PlaybackEngine_Pause()
}

PlaybackEngine_WaitWhilePaused(executionId := unset) {
    global MS_PlaybackPaused
    global MS_PlaybackRunning
    global MS_PlaybackExecutionId

    while MS_PlaybackPaused {
        if !MS_PlaybackRunning
            return false

        if IsSet(executionId) {
            if executionId != MS_PlaybackExecutionId
                return false
        }

        Sleep(20)
    }

    return true
}

; ============================================================
; STOP
; ============================================================

PlaybackEngine_Stop() {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStopRequested
    global MS_Playback

    if !MS_PlaybackRunning
        return false

    MS_PlaybackStopRequested := true
    MS_PlaybackPaused := false

    MS_Playback["stopRequested"] := true
    MS_Playback["paused"] := false

    try {
        InputHandler_ReleaseCommonKeys()
    }

    try {
        ExecutionConsole_Log(
            "WARNING",
            "Playback stop requested."
        )
    }

    return true
}

PlaybackEngine_StopImmediately() {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStopRequested
    global MS_Playback

    MS_PlaybackStopRequested := true
    MS_PlaybackPaused := false
    MS_PlaybackRunning := false

    MS_Playback["stopRequested"] := true
    MS_Playback["paused"] := false
    MS_Playback["running"] := false

    try {
        InputHandler_ReleaseCommonKeys()
    }

    return true
}

; ============================================================
; CONTINUE CHECK
; ============================================================

PlaybackEngine_ShouldContinue(executionId := unset) {
    global MS_PlaybackRunning
    global MS_PlaybackStopRequested
    global MS_PlaybackExecutionId
    global MS_State

    if !MS_PlaybackRunning
        return false

    if MS_PlaybackStopRequested
        return false

    if MS_State.Has("stopRequested")
        && MS_State["stopRequested"]
        return false

    if IsSet(executionId) {
        if executionId != MS_PlaybackExecutionId
            return false
    }

    return true
}

; ============================================================
; WINDOW RESTRICTION
; ============================================================

PlaybackEngine_CheckWindowRestriction(macro) {
    if !Settings_Get(
        "restrictToActiveWindow",
        false
    )
        return true

    if !macro.Has("targetWindow")
        return true

    target := macro["targetWindow"]

    if target = ""
        return true

    try {
        return WinActive(target) != 0
    }
    catch {
        return false
    }
}

; ============================================================
; EXECUTION INFORMATION
; ============================================================

PlaybackEngine_GetProgress() {
    global MS_PlaybackCurrentIndex
    global MS_PlaybackCurrentActions

    total := MS_PlaybackCurrentActions.Length

    if total = 0
        return 0

    return Round(
        MS_PlaybackCurrentIndex / total * 100
    )
}

PlaybackEngine_GetElapsed() {
    global MS_PlaybackStartTime
    global MS_PlaybackElapsedBeforePause
    global MS_PlaybackPaused

    elapsed := MS_PlaybackElapsedBeforePause

    if !MS_PlaybackPaused && MS_PlaybackStartTime
        elapsed += A_TickCount - MS_PlaybackStartTime

    return elapsed
}

PlaybackEngine_GetStatus() {
    global MS_Playback

    status := Lib_Clone(MS_Playback)

    status["progress"] := PlaybackEngine_GetProgress()
    status["elapsed"] := PlaybackEngine_GetElapsed()

    return status
}

PlaybackEngine_IsRunning() {
    global MS_PlaybackRunning

    return MS_PlaybackRunning
}

PlaybackEngine_IsPaused() {
    global MS_PlaybackPaused

    return MS_PlaybackPaused
}

; ============================================================
; FINISH
; ============================================================

PlaybackEngine_Finish() {
    global MS_PlaybackRunning
    global MS_PlaybackPaused
    global MS_PlaybackStopRequested
    global MS_PlaybackCurrentIndex
    global MS_PlaybackCurrentActions
    global MS_Playback

    MS_PlaybackRunning := false
    MS_PlaybackPaused := false
    MS_PlaybackStopRequested := false

    MS_Playback["running"] := false
    MS_Playback["paused"] := false
    MS_Playback["stopRequested"] := false

    PlaybackEngine_StopTimer()

    try {
        InputHandler_ReleaseCommonKeys()
    }

    try {
        ExecutionConsole_Log(
            "SUCCESS",
            "Macro playback finished."
        )
    }

    try {
        UI_SetStatus("Ready")
    }

    return true
}

; ============================================================
; TIMER MANAGEMENT
; ============================================================

PlaybackEngine_StopTimer() {
    global MS_PlaybackTimer

    if MS_PlaybackTimer {
        try {
            SetTimer(
                MS_PlaybackTimer,
                0
            )
        }

        MS_PlaybackTimer := 0
    }

    return true
}

; ============================================================
; SHUTDOWN
; ============================================================

PlaybackEngine_Shutdown() {
    global MS_PlaybackRunning

    if MS_PlaybackRunning
        PlaybackEngine_StopImmediately()

    PlaybackEngine_StopTimer()

    return true
}

; ============================================================
; END OF PlaybackEngine.ahk
; ============================================================
