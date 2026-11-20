
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - PixelPicker.ahk
; Full-screen pixel picker and region selector
; ============================================================

global MS_PixelPicker := Map()
global MS_PixelPickerGui := 0
global MS_PixelPickerOverlay := 0
global MS_PixelPickerSelecting := false
global MS_PixelPickerStartX := 0
global MS_PixelPickerStartY := 0
global MS_PixelPickerCurrentX := 0
global MS_PixelPickerCurrentY := 0
global MS_PixelPickerMode := "single"
global MS_PixelPickerTimer := 0
global MS_PixelPickerResult := Map()

; ============================================================
; INITIALIZATION
; ============================================================

PixelPicker_Initialize() {
    global MS_PixelPicker
    global MS_PixelPickerResult

    MS_PixelPicker := Map(
        "active", false,
        "mode", "single",
        "startX", 0,
        "startY", 0,
        "endX", 0,
        "endY", 0,
        "region", Map(),
        "selectedColor", "",
        "selectedRGB", Map(),
        "selectedHEX", "",
        "samples", [],
        "tolerance", 10,
        "callback", 0
    )

    MS_PixelPickerResult := Map()

    return true
}

; ============================================================
; OPEN PICKER
; ============================================================

PixelPicker_Open(mode := "single", callback := 0) {
    global MS_PixelPicker
    global MS_PixelPickerGui
    global MS_PixelPickerOverlay
    global MS_PixelPickerSelecting
    global MS_PixelPickerMode

    if MS_PixelPicker["active"]
        PixelPicker_Close()

    if mode != "single" && mode != "region"
        mode := "single"

    MS_PixelPickerMode := mode
    MS_PixelPicker["mode"] := mode
    MS_PixelPicker["callback"] := callback
    MS_PixelPicker["active"] := true

    MS_PixelPickerSelecting := false

    try {
        MS_PixelPickerGui := Gui(
            "+AlwaysOnTop -Caption +ToolWindow"
        )

        MS_PixelPickerGui.BackColor := "101010"
        MS_PixelPickerGui.MarginX := 12
        MS_PixelPickerGui.MarginY := 10

        MS_PixelPickerGui.SetFont(
            "s10 cFFFFFF",
            "Segoe UI"
        )

        MS_PixelPickerGui.AddText(
            "w380",
            mode = "single"
                ? "PIXEL PICKER  |  Click anywhere to sample"
                : "REGION PICKER  |  Drag to select an area"
        )

        MS_PixelPickerGui.AddText(
            "w380 cAAAAAA",
            "Press ESC to cancel"
        )

        MS_PixelPickerGui.AddText(
            "w380 c777777",
            "The picker overlay will appear over your screen."
        )

        MS_PixelPickerGui.Show(
            "AutoSize Center"
        )

        MS_PixelPickerOverlay := Gui(
            "+AlwaysOnTop -Caption +ToolWindow"
        )

        MS_PixelPickerOverlay.BackColor := "000000"

        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight

        MS_PixelPickerOverlay.Show(
            "x0 y0 w" screenWidth
            " h" screenHeight
        )

        WinSetTransparent(
            35,
            MS_PixelPickerOverlay.Hwnd
        )

        MS_PixelPickerOverlay.OnEvent(
            "Escape",
            PixelPicker_Cancel
        )

        MS_PixelPickerOverlay.OnEvent(
            "Close",
            PixelPicker_Cancel
        )

        Hotkey(
            "LButton",
            PixelPicker_OnMouseDown,
            "On"
        )

        Hotkey(
            "LButton Up",
            PixelPicker_OnMouseUp,
            "On"
        )

        Hotkey(
            "Escape",
            PixelPicker_Cancel,
            "On"
        )

        PixelPicker_StartTracking()

        return true
    }
    catch as pickerError {
        PixelPicker_Close()

        try {
            ExecutionConsole_Log(
                "ERROR",
                "Could not open pixel picker: "
                . pickerError.Message
            )
        }

        return false
    }
}

; ============================================================
; SCREEN TRACKING
; ============================================================

PixelPicker_StartTracking() {
    global MS_PixelPickerTimer

    MS_PixelPickerTimer := PixelPicker_UpdateCursor.Bind()

    SetTimer(
        MS_PixelPickerTimer,
        30
    )

    return true
}

PixelPicker_StopTracking() {
    global MS_PixelPickerTimer

    if MS_PixelPickerTimer {
        try {
            SetTimer(
                MS_PixelPickerTimer,
                0
            )
        }

        MS_PixelPickerTimer := 0
    }

    return true
}

PixelPicker_UpdateCursor() {
    global MS_PixelPicker
    global MS_PixelPickerSelecting
    global MS_PixelPickerCurrentX
    global MS_PixelPickerCurrentY

    if !MS_PixelPicker["active"]
        return

    MouseGetPos(
        &mouseX,
        &mouseY
    )

    MS_PixelPickerCurrentX := mouseX
    MS_PixelPickerCurrentY := mouseY

    if MS_PixelPickerSelecting {
        MS_PixelPicker["endX"] := mouseX
        MS_PixelPicker["endY"] := mouseY
    }
}

; ============================================================
; MOUSE SELECTION
; ============================================================

PixelPicker_OnMouseDown(*) {
    global MS_PixelPicker
    global MS_PixelPickerSelecting
    global MS_PixelPickerStartX
    global MS_PixelPickerStartY
    global MS_PixelPickerMode

    if !MS_PixelPicker["active"]
        return

    MouseGetPos(
        &mouseX,
        &mouseY
    )

    if MS_PixelPickerMode = "single" {
        PixelPicker_SelectSingle(mouseX, mouseY)
        return
    }

    MS_PixelPickerSelecting := true

    MS_PixelPickerStartX := mouseX
    MS_PixelPickerStartY := mouseY

    MS_PixelPicker["startX"] := mouseX
    MS_PixelPicker["startY"] := mouseY
    MS_PixelPicker["endX"] := mouseX
    MS_PixelPicker["endY"] := mouseY
}

PixelPicker_OnMouseUp(*) {
    global MS_PixelPicker
    global MS_PixelPickerSelecting
    global MS_PixelPickerMode

    if !MS_PixelPicker["active"]
        return

    if !MS_PixelPickerSelecting
        return

    MS_PixelPickerSelecting := false

    MouseGetPos(
        &mouseX,
        &mouseY
    )

    MS_PixelPicker["endX"] := mouseX
    MS_PixelPicker["endY"] := mouseY

    if MS_PixelPickerMode = "region"
        PixelPicker_SelectRegion()
}

; ============================================================
; SINGLE PIXEL SELECTION
; ============================================================

PixelPicker_SelectSingle(x, y) {
    global MS_PixelPicker
    global MS_PixelPickerResult

    try {
        color := PixelGetColor(
            x,
            y,
            "RGB"
        )

        color := Format(
            "0x{:06X}",
            color & 0xFFFFFF
        )

        rgb := PixelPicker_HEXToRGB(color)

        result := Map(
            "type", "pixel",
            "x", x,
            "y", y,
            "color", color,
            "hex", color,
            "rgb", rgb,
            "r", rgb["r"],
            "g", rgb["g"],
            "b", rgb["b"]
        )

        MS_PixelPickerResult := result
        MS_PixelPicker["selectedColor"] := color
        MS_PixelPicker["selectedHEX"] := color
        MS_PixelPicker["selectedRGB"] := rgb

        PixelPicker_Complete(result)

        return result
    }
    catch as sampleError {
        try {
            ExecutionConsole_Log(
                "ERROR",
                "Pixel sampling failed: "
                . sampleError.Message
            )
        }

        return false
    }
}

; ============================================================
; REGION SELECTION
; ============================================================

PixelPicker_SelectRegion() {
    global MS_PixelPicker
    global MS_PixelPickerResult

    x1 := MS_PixelPicker["startX"]
    y1 := MS_PixelPicker["startY"]
    x2 := MS_PixelPicker["endX"]
    y2 := MS_PixelPicker["endY"]

    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    width := right - left
    height := bottom - top

    if width < 1 || height < 1
        return false

    region := Map(
        "x", left,
        "y", top,
        "width", width,
        "height", height,
        "right", right,
        "bottom", bottom
    )

    MS_PixelPicker["region"] := region

    result := Map(
        "type", "region",
        "x", left,
        "y", top,
        "width", width,
        "height", height,
        "right", right,
        "bottom", bottom
    )

    MS_PixelPickerResult := result

    PixelPicker_Complete(result)

    return result
}

; ============================================================
; SAMPLE PIXELS INSIDE A REGION
; ============================================================

PixelPicker_SampleRegion(
    region,
    columns := 5,
    rows := 5
) {
    if !IsObject(region)
        return []

    if !region.Has("x")
        return []

    if !region.Has("y")
        return []

    if !region.Has("width")
        return []

    if !region.Has("height")
        return []

    columns := Max(1, Min(50, Round(columns)))
    rows := Max(1, Min(50, Round(rows)))

    samples := []

    stepX := region["width"] / columns
    stepY := region["height"] / rows

    loop rows {
        rowIndex := A_Index

        loop columns {
            columnIndex := A_Index

            sampleX := Round(
                region["x"] + ((columnIndex - 0.5) * stepX)
            )

            sampleY := Round(
                region["y"] + ((rowIndex - 0.5) * stepY)
            )

            try {
                color := PixelGetColor(
                    sampleX,
                    sampleY,
                    "RGB"
                )

                color := Format(
                    "0x{:06X}",
                    color & 0xFFFFFF
                )

                rgb := PixelPicker_HEXToRGB(color)

                samples.Push(
                    Map(
                        "x", sampleX,
                        "y", sampleY,
                        "color", color,
                        "rgb", rgb
                    )
                )
            }
        }
    }

    return samples
}

; ============================================================
; COLOR CONVERSION
; ============================================================

PixelPicker_HEXToRGB(hex) {
    hex := StrReplace(
        hex,
        "0x"
    )

    hex := StrReplace(
        hex,
        "#"
    )

    if !RegExMatch(
        hex,
        "i)^[0-9A-F]{6}$"
    )
        return Map(
            "r", 0,
            "g", 0,
            "b", 0
        )

    return Map(
        "r", Integer("0x" . SubStr(hex, 1, 2)),
        "g", Integer("0x" . SubStr(hex, 3, 2)),
        "b", Integer("0x" . SubStr(hex, 5, 2))
    )
}

PixelPicker_RGBToHEX(r, g, b) {
    red := Max(0, Min(255, Round(r)))
    green := Max(0, Min(255, Round(g)))
    blue := Max(0, Min(255, Round(b)))

    return Format(
        "0x{:02X}{:02X}{:02X}",
        red,
        green,
        blue
    )
}

PixelPicker_GetColorAt(x, y) {
    try {
        color := PixelGetColor(
            x,
            y,
            "RGB"
        )

        return Format(
            "0x{:06X}",
            color & 0xFFFFFF
        )
    }
    catch {
        return ""
    }
}

; ============================================================
; COLOR COMPARISON
; ============================================================

PixelPicker_ColorsMatch(
    colorA,
    colorB,
    tolerance := 10
) {
    rgbA := PixelPicker_HEXToRGB(colorA)
    rgbB := PixelPicker_HEXToRGB(colorB)

    tolerance := Max(
        0,
        Min(255, Round(tolerance))
    )

    return (
        Abs(rgbA["r"] - rgbB["r"]) <= tolerance
        && Abs(rgbA["g"] - rgbB["g"]) <= tolerance
        && Abs(rgbA["b"] - rgbB["b"]) <= tolerance
    )
}

; ============================================================
; REGION COLOR SEARCH
; ============================================================

PixelPicker_FindColorInRegion(
    region,
    targetColor,
    tolerance := 10,
    step := 2
) {
    if !IsObject(region)
        return false

    if !region.Has("x")
        return false

    if !region.Has("y")
        return false

    if !region.Has("width")
        return false

    if !region.Has("height")
        return false

    step := Max(
        1,
        Min(100, Round(step))
    )

    left := region["x"]
    top := region["y"]
    right := left + region["width"]
    bottom := top + region["height"]

    scanY := top

    while scanY <= bottom {
        scanX := left

        while scanX <= right {
            currentColor := PixelPicker_GetColorAt(
                scanX,
                scanY
            )

            if currentColor != "" {
                if PixelPicker_ColorsMatch(
                    currentColor,
                    targetColor,
                    tolerance
                ) {
                    return Map(
                        "found", true,
                        "x", scanX,
                        "y", scanY,
                        "color", currentColor
                    )
                }
            }

            scanX += step
        }

        scanY += step
    }

    return Map(
        "found", false,
        "x", -1,
        "y", -1,
        "color", ""
    )
}

; ============================================================
; REGION COLOR COLLECTION
; ============================================================

PixelPicker_GetUniqueColors(
    region,
    step := 5,
    maximum := 100
) {
    if !IsObject(region)
        return []

    if !region.Has("x")
        || !region.Has("y")
        || !region.Has("width")
        || !region.Has("height")
        return []

    colors := Map()
    results := []

    step := Max(1, Round(step))
    maximum := Max(1, Round(maximum))

    left := region["x"]
    top := region["y"]
    right := left + region["width"]
    bottom := top + region["height"]

    scanY := top

    while scanY <= bottom {
        scanX := left

        while scanX <= right {
            color := PixelPicker_GetColorAt(scanX, scanY)

            if color != "" && !colors.Has(color) {
                colors[color] := true

                results.Push(
                    Map(
                        "color", color,
                        "x", scanX,
                        "y", scanY
                    )
                )

                if results.Length >= maximum
                    return results
            }

            scanX += step
        }

        scanY += step
    }

    return results
}

; ============================================================
; COMPLETE / CANCEL
; ============================================================

PixelPicker_Complete(result) {
    global MS_PixelPicker

    callback := MS_PixelPicker["callback"]

    PixelPicker_Close()

    if IsObject(callback) {
        try {
            callback.Call(result)
        }
    }

    try {
        ExecutionConsole_Log(
            "SUCCESS",
            "Pixel selection completed."
        )
    }

    return true
}

PixelPicker_Cancel(*) {
    global MS_PixelPicker

    if !MS_PixelPicker["active"]
        return false

    PixelPicker_Close()

    try {
        ExecutionConsole_Log(
            "INFO",
            "Pixel selection cancelled."
        )
    }

    return true
}

; ============================================================
; CLOSE PICKER
; ============================================================

PixelPicker_Close() {
    global MS_PixelPicker
    global MS_PixelPickerGui
    global MS_PixelPickerOverlay
    global MS_PixelPickerSelecting

    PixelPicker_StopTracking()

    try {
        Hotkey(
            "LButton",
            "Off"
        )
    }

    try {
        Hotkey(
            "LButton Up",
            "Off"
        )
    }

    try {
        Hotkey(
            "Escape",
            "Off"
        )
    }

    if IsObject(MS_PixelPickerOverlay) {
        try {
            MS_PixelPickerOverlay.Destroy()
        }

        MS_PixelPickerOverlay := 0
    }

    if IsObject(MS_PixelPickerGui) {
        try {
            MS_PixelPickerGui.Destroy()
        }

        MS_PixelPickerGui := 0
    }

    MS_PixelPickerSelecting := false

    if IsObject(MS_PixelPicker)
        MS_PixelPicker["active"] := false

    return true
}

; ============================================================
; RESULT HELPERS
; ============================================================

PixelPicker_GetResult() {
    global MS_PixelPickerResult

    return MS_PixelPickerResult
}

PixelPicker_GetSelectedColor() {
    global MS_PixelPicker

    return MS_PixelPicker["selectedColor"]
}

PixelPicker_GetSelectedRegion() {
    global MS_PixelPicker

    return MS_PixelPicker["region"]
}

PixelPicker_IsActive() {
    global MS_PixelPicker

    return MS_PixelPicker["active"]
}

; ============================================================
; SHUTDOWN
; ============================================================

PixelPicker_Shutdown() {
    PixelPicker_Close()
    return true
}

; ============================================================
; END OF PixelPicker.ahk
; ============================================================


; Compatibility wrappers used by ActionManager.
PixelPicker_GetPixelColor(x, y) {
    return PixelPicker_GetColorAt(x, y)
}

PixelPicker_CompareColors(colorA, colorB, tolerance := 10) {
    return PixelPicker_ColorsMatch(colorA, colorB, tolerance)
}
