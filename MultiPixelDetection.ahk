; ============================================================
; MacroStudio - Multi-Pixel Detection
; Supports multiple pixel checks, region scanning, and matching.
; AutoHotkey v2
; ============================================================

MultiPixelDetection_Initialize() {
    global MS_State, MS_MultiPixel

    MS_MultiPixel := Map(
        "ready", true,
        "groups", Map(),
        "lastResults", Map(),
        "activeGroup", "",
        "defaultTolerance", 10,
        "defaultMode", "all",
        "scanInterval", 100,
        "stopRequested", false
    )

    MS_State["multiPixelReady"] := true
    return true
}

; ------------------------------------------------------------
; Group management
; ------------------------------------------------------------

MultiPixelDetection_CreateGroup(name, mode := "all") {
    global MS_MultiPixel

    if (name = "" || MS_MultiPixel["groups"].Has(name))
        return false

    if !MultiPixelDetection_ValidateMode(mode)
        return false

    group := Map(
        "name", name,
        "mode", mode,
        "pixels", [],
        "enabled", true,
        "tolerance", MS_MultiPixel["defaultTolerance"],
        "createdAt", A_Now,
        "lastResult", false
    )

    MS_MultiPixel["groups"][name] := group
    return true
}

MultiPixelDetection_DeleteGroup(name) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(name)
        return false

    MS_MultiPixel["groups"].Delete(name)

    if (MS_MultiPixel["activeGroup"] = name)
        MS_MultiPixel["activeGroup"] := ""

    return true
}

MultiPixelDetection_RenameGroup(oldName, newName) {
    global MS_MultiPixel

    groups := MS_MultiPixel["groups"]

    if !groups.Has(oldName) || (newName = "") || groups.Has(newName)
        return false

    group := groups[oldName]
    group["name"] := newName

    groups.Delete(oldName)
    groups[newName] := group

    if (MS_MultiPixel["activeGroup"] = oldName)
        MS_MultiPixel["activeGroup"] := newName

    return true
}

MultiPixelDetection_GetGroup(name) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(name)
        return ""

    return MS_MultiPixel["groups"][name]
}

MultiPixelDetection_ListGroups() {
    global MS_MultiPixel

    names := []

    for name, group in MS_MultiPixel["groups"]
        names.Push(name)

    return names
}

MultiPixelDetection_SetGroupMode(name, mode) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(name)
        return false

    if !MultiPixelDetection_ValidateMode(mode)
        return false

    MS_MultiPixel["groups"][name]["mode"] := mode
    return true
}

MultiPixelDetection_SetGroupEnabled(name, enabled) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(name)
        return false

    MS_MultiPixel["groups"][name]["enabled"] := !!enabled
    return true
}

; ------------------------------------------------------------
; Pixel management
; ------------------------------------------------------------

MultiPixelDetection_AddPixel(groupName, x, y, color, tolerance := unset) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return false

    if !IsNumber(x) || !IsNumber(y)
        return false

    if !MultiPixelDetection_ValidateColor(color)
        return false

    group := MS_MultiPixel["groups"][groupName]

    if !IsSet(tolerance)
        tolerance := group.Get("tolerance", MS_MultiPixel["defaultTolerance"])

    if !IsNumber(tolerance) || tolerance < 0 || tolerance > 255
        return false

    pixel := Map(
        "id", MultiPixelDetection_GenerateId(),
        "x", Round(x),
        "y", Round(y),
        "color", MultiPixelDetection_NormalizeColor(color),
        "tolerance", tolerance,
        "enabled", true
    )

    group["pixels"].Push(pixel)
    return pixel["id"]
}

MultiPixelDetection_AddCurrentPixel(groupName, x, y, tolerance := unset) {
    try {
        color := PixelGetColor(x, y, "RGB")
        return MultiPixelDetection_AddPixel(
            groupName,
            x,
            y,
            color,
            tolerance
        )
    } catch {
        return false
    }
}

MultiPixelDetection_RemovePixel(groupName, pixelId) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return false

    pixels := MS_MultiPixel["groups"][groupName]["pixels"]

    for index, pixel in pixels {
        if (pixel.Get("id", "") = pixelId) {
            pixels.RemoveAt(index)
            return true
        }
    }

    return false
}

MultiPixelDetection_UpdatePixel(groupName, pixelId, property, value) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return false

    allowed := ["x", "y", "color", "tolerance", "enabled"]

    valid := false
    for item in allowed {
        if (property = item) {
            valid := true
            break
        }
    }

    if !valid
        return false

    pixels := MS_MultiPixel["groups"][groupName]["pixels"]

    for pixel in pixels {
        if (pixel.Get("id", "") != pixelId)
            continue

        switch property {
            case "x", "y":
                if !IsNumber(value)
                    return false
                value := Round(value)

            case "color":
                if !MultiPixelDetection_ValidateColor(value)
                    return false
                value := MultiPixelDetection_NormalizeColor(value)

            case "tolerance":
                if !IsNumber(value) || value < 0 || value > 255
                    return false

            case "enabled":
                value := !!value
        }

        pixel[property] := value
        return true
    }

    return false
}

MultiPixelDetection_GetPixel(groupName, pixelId) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return ""

    for pixel in MS_MultiPixel["groups"][groupName]["pixels"] {
        if (pixel.Get("id", "") = pixelId)
            return pixel
    }

    return ""
}

MultiPixelDetection_ClearPixels(groupName) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return false

    MS_MultiPixel["groups"][groupName]["pixels"] := []
    return true
}

; ------------------------------------------------------------
; Detection engine
; ------------------------------------------------------------

MultiPixelDetection_CheckGroup(groupName, mode := unset) {
    global MS_MultiPixel

    group := MultiPixelDetection_GetGroup(groupName)

    if !IsObject(group) || !group.Get("enabled", true)
        return false

    if !IsSet(mode)
        mode := group.Get("mode", "all")

    if !MultiPixelDetection_ValidateMode(mode)
        return false

    pixels := group.Get("pixels", [])
    enabledPixels := []

    for pixel in pixels {
        if pixel.Get("enabled", true)
            enabledPixels.Push(pixel)
    }

    if (enabledPixels.Length = 0)
        return false

    matched := 0
    checked := 0
    details := []

    for pixel in enabledPixels {
        result := MultiPixelDetection_CheckPixel(pixel)
        checked += 1

        if result["match"]
            matched += 1

        details.Push(result)
    }

    switch mode {
        case "all":
            success := matched = checked

        case "any":
            success := matched > 0

        case "none":
            success := matched = 0

        case "majority":
            success := matched > checked / 2

        default:
            success := false
    }

    output := Map(
        "success", success,
        "group", groupName,
        "mode", mode,
        "matched", matched,
        "checked", checked,
        "details", details,
        "timestamp", A_TickCount
    )

    group["lastResult"] := success
    MS_MultiPixel["lastResults"][groupName] := output

    return output
}

MultiPixelDetection_CheckPixel(pixel) {
    x := pixel.Get("x", 0)
    y := pixel.Get("y", 0)
    expected := pixel.Get("color", "000000")
    tolerance := pixel.Get("tolerance", 10)

    result := Map(
        "id", pixel.Get("id", ""),
        "x", x,
        "y", y,
        "expected", expected,
        "actual", "",
        "match", false
    )

    try {
        actual := PixelGetColor(x, y, "RGB")
        actual := MultiPixelDetection_NormalizeColor(actual)

        result["actual"] := actual
        result["match"] := Logic_ColorsMatch(
            expected,
            actual,
            tolerance
        )
    } catch {
        result["actual"] := "ERROR"
    }

    return result
}

MultiPixelDetection_CheckAll() {
    global MS_MultiPixel

    results := Map()

    for name, group in MS_MultiPixel["groups"] {
        if !group.Get("enabled", true)
            continue

        results[name] := MultiPixelDetection_CheckGroup(name)
    }

    return results
}

; ------------------------------------------------------------
; Region scanning
; ------------------------------------------------------------

MultiPixelDetection_FindColor(
    color,
    x1,
    y1,
    x2,
    y2,
    tolerance := 10,
    step := 1
) {
    if !MultiPixelDetection_ValidateColor(color)
        return []

    if !IsNumber(x1) || !IsNumber(y1)
        || !IsNumber(x2) || !IsNumber(y2)
        return []

    if !IsNumber(tolerance) || tolerance < 0 || tolerance > 255
        return []

    step := Max(1, Round(step))

    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    target := MultiPixelDetection_NormalizeColor(color)
    matches := []

    y := top
    while (y <= bottom) {
        x := left

        while (x <= right) {
            try {
                actual := PixelGetColor(x, y, "RGB")
                actual := MultiPixelDetection_NormalizeColor(actual)

                if Logic_ColorsMatch(target, actual, tolerance) {
                    matches.Push(Map(
                        "x", x,
                        "y", y,
                        "color", actual
                    ))
                }
            }

            x += step
        }

        y += step
    }

    return matches
}

MultiPixelDetection_FindFirstColor(
    color,
    x1,
    y1,
    x2,
    y2,
    tolerance := 10,
    step := 1
) {
    matches := MultiPixelDetection_FindColor(
        color,
        x1,
        y1,
        x2,
        y2,
        tolerance,
        step
    )

    return matches.Length > 0 ? matches[1] : ""
}

MultiPixelDetection_CountColor(
    color,
    x1,
    y1,
    x2,
    y2,
    tolerance := 10,
    step := 1
) {
    matches := MultiPixelDetection_FindColor(
        color,
        x1,
        y1,
        x2,
        y2,
        tolerance,
        step
    )

    return matches.Length
}

; ------------------------------------------------------------
; Waiting and monitoring
; ------------------------------------------------------------

MultiPixelDetection_WaitForGroup(
    groupName,
    timeout := 5000,
    interval := unset
) {
    global MS_MultiPixel

    if !MS_MultiPixel["groups"].Has(groupName)
        return false

    if !IsSet(interval)
        interval := MS_MultiPixel["scanInterval"]

    timeout := Max(0, timeout)
    interval := Max(10, interval)

    started := A_TickCount

    while ((A_TickCount - started) <= timeout) {
        if MS_MultiPixel["stopRequested"]
            return false

        result := MultiPixelDetection_CheckGroup(groupName)

        if IsObject(result) && result.Get("success", false)
            return true

        Sleep(interval)
    }

    return false
}

MultiPixelDetection_StopWaiting() {
    global MS_MultiPixel

    MS_MultiPixel["stopRequested"] := true
    return true
}

MultiPixelDetection_ResetStop() {
    global MS_MultiPixel

    MS_MultiPixel["stopRequested"] := false
    return true
}

; ------------------------------------------------------------
; Result access
; ------------------------------------------------------------

MultiPixelDetection_GetLastResult(groupName) {
    global MS_MultiPixel

    if !MS_MultiPixel["lastResults"].Has(groupName)
        return ""

    return MS_MultiPixel["lastResults"][groupName]
}

MultiPixelDetection_GetMatchedPixels(groupName) {
    result := MultiPixelDetection_GetLastResult(groupName)

    if !IsObject(result)
        return []

    matched := []

    for detail in result.Get("details", []) {
        if detail.Get("match", false)
            matched.Push(detail)
    }

    return matched
}

MultiPixelDetection_GetFailedPixels(groupName) {
    result := MultiPixelDetection_GetLastResult(groupName)

    if !IsObject(result)
        return []

    failed := []

    for detail in result.Get("details", []) {
        if !detail.Get("match", false)
            failed.Push(detail)
    }

    return failed
}

; ------------------------------------------------------------
; Import and export
; ------------------------------------------------------------

MultiPixelDetection_ExportGroup(groupName, path := "") {
    global MS_MultiPixel

    group := MultiPixelDetection_GetGroup(groupName)

    if !IsObject(group)
        return false

    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Pixel Group",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        Lib_WriteText(path, JSON.Stringify(group, true))
        return true
    } catch as error {
        ExecutionConsole_Log(
            "Pixel group export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

MultiPixelDetection_ImportGroup(path, newName := "") {
    global MS_MultiPixel

    if !FileExist(path)
        return false

    try {
        group := JSON.Parse(Lib_ReadText(path))

        if !IsObject(group)
            return false

        name := newName != ""
            ? newName
            : group.Get("name", "Imported Group")

        if MS_MultiPixel["groups"].Has(name)
            return false

        mode := group.Get("mode", "all")

        if !MultiPixelDetection_ValidateMode(mode)
            return false

        pixels := group.Get("pixels", [])

        if !IsObject(pixels)
            return false

        for pixel in pixels {
            if !IsObject(pixel)
                return false

            if !pixel.Has("x") || !pixel.Has("y")
                || !pixel.Has("color")
                return false

            if !MultiPixelDetection_ValidateColor(pixel["color"])
                return false
        }

        group["name"] := name
        MS_MultiPixel["groups"][name] := group

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Pixel group import failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Validation and utilities
; ------------------------------------------------------------

MultiPixelDetection_ValidateMode(mode) {
    return mode = "all"
        || mode = "any"
        || mode = "none"
        || mode = "majority"
}

MultiPixelDetection_ValidateColor(color) {
    if !IsString(color)
        && !IsNumber(color)
        return false

    value := StrReplace(color "", "#")
    value := StrReplace(value, "0x")

    return RegExMatch(value, "i)^[0-9a-f]{6}$")
}

MultiPixelDetection_NormalizeColor(color) {
    value := StrReplace(color "", "#")
    value := StrReplace(value, "0x")

    return Format("{:06X}", Integer("0x" value))
}

MultiPixelDetection_GenerateId() {
    return "pixel_" A_TickCount "_" Random(1000, 9999)
}

MultiPixelDetection_SetDefaultTolerance(tolerance) {
    global MS_MultiPixel

    if !IsNumber(tolerance) || tolerance < 0 || tolerance > 255
        return false

    MS_MultiPixel["defaultTolerance"] := tolerance
    return true
}

MultiPixelDetection_SetScanInterval(interval) {
    global MS_MultiPixel

    if !IsNumber(interval) || interval < 10 || interval > 10000
        return false

    MS_MultiPixel["scanInterval"] := interval
    return true
}

MultiPixelDetection_Shutdown() {
    global MS_State, MS_MultiPixel

    MS_MultiPixel["stopRequested"] := true
    MS_MultiPixel["ready"] := false

    MS_State["multiPixelReady"] := false

    return true
}