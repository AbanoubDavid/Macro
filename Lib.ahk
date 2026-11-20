
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - Lib.ahk
; Shared utility functions and JSON support
; ============================================================

global MS_LibInitialized := false

; ============================================================
; INITIALIZATION
; ============================================================

Lib_Initialize() {
    global MS_LibInitialized

    MS_LibInitialized := true

    return true
}

; ============================================================
; STRING UTILITIES
; ============================================================

Lib_Trim(value) {
    return Trim(String(value))
}

Lib_IsBlank(value) {
    return Trim(String(value)) = ""
}

Lib_Contains(haystack, needle, caseSensitive := false) {
    if caseSensitive
        return InStr(haystack, needle, true) != 0

    return InStr(haystack, needle) != 0
}

Lib_Replace(value, search, replacement) {
    return StrReplace(value, search, replacement)
}

Lib_Split(value, delimiter := ",") {
    return StrSplit(value, delimiter)
}

Lib_Join(values, delimiter := ",") {
    result := ""

    for index, value in values {
        if index > 1
            result .= delimiter

        result .= value
    }

    return result
}

Lib_Truncate(value, maximumLength := 100) {
    value := String(value)

    if StrLen(value) <= maximumLength
        return value

    if maximumLength <= 3
        return SubStr(value, 1, maximumLength)

    return SubStr(value, 1, maximumLength - 3) "..."
}

; ============================================================
; NUMBER UTILITIES
; ============================================================

Lib_Clamp(value, minimum, maximum) {
    return Max(minimum, Min(maximum, value))
}

Lib_Round(value, decimals := 0) {
    factor := 10 ** decimals

    return Round(value * factor) / factor
}

Lib_RandomFloat(minimum, maximum, decimals := 2) {
    factor := 10 ** decimals

    minimum := Round(minimum * factor)
    maximum := Round(maximum * factor)

    if minimum > maximum {
        temporary := minimum
        minimum := maximum
        maximum := temporary
    }

    return Random(minimum, maximum) / factor
}

Lib_IsInteger(value) {
    return IsNumber(value) && Mod(value, 1) = 0
}

Lib_ToInteger(value, defaultValue := 0) {
    try {
        return Integer(value)
    } catch {
        return defaultValue
    }
}

Lib_ToNumber(value, defaultValue := 0) {
    try {
        return Number(value)
    } catch {
        return defaultValue
    }
}

; ============================================================
; MAP / ARRAY UTILITIES
; ============================================================

Lib_MapHas(map, key) {
    return IsObject(map) && map is Map && map.Has(key)
}

Lib_MapGet(map, key, defaultValue := unset) {
    if IsObject(map) && map is Map && map.Has(key)
        return map[key]

    if IsSet(defaultValue)
        return defaultValue

    return ""
}

Lib_MapSet(map, key, value) {
    if !IsObject(map) || !(map is Map)
        return false

    map[key] := value

    return true
}

Lib_ArrayContains(array, value) {
    if !IsObject(array) || !(array is Array)
        return false

    for item in array {
        if item = value
            return true
    }

    return false
}

Lib_ArrayRemove(array, index) {
    if !IsObject(array) || !(array is Array)
        return false

    if index < 1 || index > array.Length
        return false

    array.RemoveAt(index)

    return true
}

Lib_Clone(value) {
    if !IsObject(value)
        return value

    if value is Map {
        result := Map()

        for key, item in value
            result[key] := Lib_Clone(item)

        return result
    }

    if value is Array {
        result := []

        for item in value
            result.Push(Lib_Clone(item))

        return result
    }

    return value
}

; ============================================================
; FILE UTILITIES
; ============================================================

Lib_EnsureDirectory(path) {
    if DirExist(path)
        return true

    try {
        DirCreate(path)
        return DirExist(path)
    } catch {
        return false
    }
}

Lib_ReadText(path, encoding := "UTF-8") {
    if !FileExist(path)
        return ""

    try {
        return FileRead(path, encoding)
    } catch {
        return ""
    }
}

Lib_WriteText(path, content, encoding := "UTF-8") {
    try {
        directory := RegExReplace(path, "\\[^\\]+$")

        if directory != "" && !DirExist(directory)
            DirCreate(directory)

        temporaryPath := path ".tmp"

        if FileExist(temporaryPath)
            FileDelete(temporaryPath)

        FileAppend(content, temporaryPath, encoding)

        FileMove(temporaryPath, path, 1)

        return true
    } catch {
        return false
    }
}

Lib_DeleteFile(path) {
    if !FileExist(path)
        return true

    try {
        FileDelete(path)
        return true
    } catch {
        return false
    }
}

Lib_GetFileExtension(path) {
    SplitPath(path, , , &extension)
    return extension
}

Lib_GetFileName(path) {
    SplitPath(path, &fileName)
    return fileName
}

; ============================================================
; DATE / TIME UTILITIES
; ============================================================

Lib_Timestamp() {
    return FormatTime(, "yyyy-MM-dd HH:mm:ss")
}

Lib_DateStamp() {
    return FormatTime(, "yyyy-MM-dd")
}

Lib_TimeStampCompact() {
    return FormatTime(, "yyyyMMdd_HHmmss")
}

Lib_FormatDuration(milliseconds) {
    milliseconds := Max(0, Round(milliseconds))

    totalSeconds := Floor(milliseconds / 1000)

    hours := Floor(totalSeconds / 3600)
    minutes := Floor(Mod(totalSeconds, 3600) / 60)
    seconds := Mod(totalSeconds, 60)

    if hours > 0 {
        return Format(
            "{:02}:{:02}:{:02}",
            hours,
            minutes,
            seconds
        )
    }

    return Format(
        "{:02}:{:02}",
        minutes,
        seconds
    )
}

; ============================================================
; COLOR UTILITIES
; ============================================================

Lib_NormalizeColor(color) {
    color := Trim(String(color))

    color := RegExReplace(color, "i)^0x")
    color := StrReplace(color, "#")

    if !RegExMatch(color, "i)^[0-9A-F]{6}$")
        return ""

    return "0x" StrUpper(color)
}

Lib_ColorToRGB(color) {
    color := Lib_NormalizeColor(color)

    if color = "" {
        return Map(
            "r", 0,
            "g", 0,
            "b", 0
        )
    }

    return Map(
        "r", Integer("0x" SubStr(color, 3, 2)),
        "g", Integer("0x" SubStr(color, 5, 2)),
        "b", Integer("0x" SubStr(color, 7, 2))
    )
}

Lib_RGBToColor(r, g, b) {
    return Format(
        "0x{:02X}{:02X}{:02X}",
        Lib_Clamp(Round(r), 0, 255),
        Lib_Clamp(Round(g), 0, 255),
        Lib_Clamp(Round(b), 0, 255)
    )
}

; ============================================================
; JSON ENCODER
; ============================================================

class JSON {
    static Stringify(value, indent := 0) {
        return JSON._Encode(
            value,
            Max(0, Round(indent)),
            0
        )
    }

    static _Encode(value, indent, depth) {
        if depth > 100
            throw Error("JSON nesting limit exceeded.")

        if !IsObject(value) {
            if value = ""
                return '""'

            if IsNumber(value)
                return String(value)

            return JSON._Quote(String(value))
        }

        if value is Map
            return JSON._EncodeMap(value, indent, depth)

        if value is Array
            return JSON._EncodeArray(value, indent, depth)

        throw Error("Unsupported JSON object type.")
    }

    static _EncodeMap(map, indent, depth) {
        if map.Count = 0
            return "{}"

        parts := []
        nextDepth := depth + 1

        for key, value in map {
            encodedKey := JSON._Quote(String(key))

            encodedValue := JSON._Encode(
                value,
                indent,
                nextDepth
            )

            if indent > 0 {
                part := JSON._Indent(nextDepth, indent)
                    . encodedKey
                    . ": "
                    . encodedValue

                parts.Push(part)
            } else {
                parts.Push(encodedKey ":" encodedValue)
            }
        }

        if indent > 0 {
            output := "{`n"
            output .= Lib_Join(parts, ",`n")
            output .= "`n"
            output .= JSON._Indent(depth, indent)
            output .= "}"

            return output
        }

        return "{" Lib_Join(parts, ",") "}"
    }

    static _EncodeArray(array, indent, depth) {
        if array.Length = 0
            return "[]"

        parts := []
        nextDepth := depth + 1

        for value in array {
            encodedValue := JSON._Encode(
                value,
                indent,
                nextDepth
            )

            if indent > 0 {
                parts.Push(
                    JSON._Indent(nextDepth, indent)
                    . encodedValue
                )
            } else {
                parts.Push(encodedValue)
            }
        }

        if indent > 0 {
            output := "[`n"
            output .= Lib_Join(parts, ",`n")
            output .= "`n"
            output .= JSON._Indent(depth, indent)
            output .= "]"

            return output
        }

        return "[" Lib_Join(parts, ",") "]"
    }

    static _Indent(depth, indent) {
        spaces := ""

        Loop (depth * indent)
            spaces .= " "

        return spaces
    }

    static _Quote(value) {
        output := '"'

        loop Parse value {
            character := A_LoopField
            code := Ord(character)

            switch code {
                case 34:
                    output .= Chr(92) '"'

                case 92:
                    output .= Chr(92) Chr(92)

                case 8:
                    output .= Chr(92) "b"

                case 9:
                    output .= Chr(92) "t"

                case 10:
                    output .= Chr(92) "n"

                case 12:
                    output .= Chr(92) "f"

                case 13:
                    output .= Chr(92) "r"

                default:
                    if code < 32 {
                        output .= Chr(92) "u"
                            . Format("{:04X}", code)
                    } else {
                        output .= character
                    }
            }
        }

        return output '"'
    }

    ; ========================================================
    ; JSON DECODER
    ; ========================================================

    static Parse(source) {
        if Type(source) != "String"
            throw Error("JSON input must be a string.")

        parser := {
            source: source,
            position: 1,
            length: StrLen(source)
        }

        JSON._SkipWhitespace(parser)

        result := JSON._ParseValue(parser)

        JSON._SkipWhitespace(parser)

        if parser.position <= parser.length
            throw Error("Unexpected characters after JSON value.")

        return result
    }

    static _SkipWhitespace(parser) {
        while parser.position <= parser.length {
            character := SubStr(
                parser.source,
                parser.position,
                1
            )

            if character != " "
                && character != "`t"
                && character != "`r"
                && character != "`n"
                break

            parser.position += 1
        }
    }

    static _ParseValue(parser) {
        JSON._SkipWhitespace(parser)

        if parser.position > parser.length
            throw Error("Unexpected end of JSON input.")

        character := SubStr(
            parser.source,
            parser.position,
            1
        )

        switch character {
            case "{":
                return JSON._ParseObject(parser)

            case "[":
                return JSON._ParseArray(parser)

            case '"':
                return JSON._ParseString(parser)

            case "t":
                JSON._ParseLiteral(parser, "true")
                return true

            case "f":
                JSON._ParseLiteral(parser, "false")
                return false

            case "n":
                JSON._ParseLiteral(parser, "null")
                return ""

            default:
                return JSON._ParseNumber(parser)
        }
    }

    static _ParseObject(parser) {
        result := Map()

        parser.position += 1

        JSON._SkipWhitespace(parser)

        if JSON._Current(parser) = "}" {
            parser.position += 1
            return result
        }

        loop {
            JSON._SkipWhitespace(parser)

            if JSON._Current(parser) != '"'
                throw Error("Expected a JSON object key.")

            key := JSON._ParseString(parser)

            JSON._SkipWhitespace(parser)

            if JSON._Current(parser) != ":"
                throw Error("Expected ':' after JSON object key.")

            parser.position += 1

            value := JSON._ParseValue(parser)

            result[key] := value

            JSON._SkipWhitespace(parser)

            character := JSON._Current(parser)

            if character = "}" {
                parser.position += 1
                break
            }

            if character != ","
                throw Error("Expected ',' or '}' in JSON object.")

            parser.position += 1
        }

        return result
    }

    static _ParseArray(parser) {
        result := []

        parser.position += 1

        JSON._SkipWhitespace(parser)

        if JSON._Current(parser) = "]" {
            parser.position += 1
            return result
        }

        loop {
            result.Push(JSON._ParseValue(parser))

            JSON._SkipWhitespace(parser)

            character := JSON._Current(parser)

            if character = "]" {
                parser.position += 1
                break
            }

            if character != ","
                throw Error("Expected ',' or ']' in JSON array.")

            parser.position += 1
        }

        return result
    }

    static _ParseString(parser) {
        if JSON._Current(parser) != '"'
            throw Error("Expected JSON string.")

        parser.position += 1
        output := ""

        while parser.position <= parser.length {
            character := JSON._Current(parser)
            parser.position += 1

            if character = '"'
                return output

            if character = Chr(92) {
                if parser.position > parser.length
                    throw Error("Invalid JSON escape sequence.")

                escaped := JSON._Current(parser)
                parser.position += 1

                if escaped = '"'
                    output .= '"'
                else if escaped = Chr(92)
                    output .= Chr(92)
                else if escaped = "/"
                    output .= "/"
                else if escaped = "b"
                    output .= Chr(8)
                else if escaped = "f"
                    output .= Chr(12)
                else if escaped = "n"
                    output .= "`n"
                else if escaped = "r"
                    output .= "`r"
                else if escaped = "t"
                    output .= "`t"
                else if escaped = "u" {
                    hex := SubStr(
                        parser.source,
                        parser.position,
                        4
                    )

                    if StrLen(hex) != 4
                        throw Error("Invalid Unicode escape.")

                    if !RegExMatch(hex, "i)^[0-9A-F]{4}$")
                        throw Error("Invalid Unicode escape.")

                    output .= Chr(Integer("0x" hex))
                    parser.position += 4
                } else {
                    throw Error("Unknown JSON escape sequence.")
                }
            } else {
                if Ord(character) < 32
                    throw Error("Unescaped control character in JSON.")

                output .= character
            }
        }

        throw Error("Unterminated JSON string.")
    }

    static _ParseNumber(parser) {
        remaining := SubStr(
            parser.source,
            parser.position
        )

        if !RegExMatch(
            remaining,
            "^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?",
            &match
        )
            throw Error("Invalid JSON value.")

        token := match[0]

        parser.position += StrLen(token)

        return Number(token)
    }

    static _ParseLiteral(parser, literal) {
        actual := SubStr(
            parser.source,
            parser.position,
            StrLen(literal)
        )

        if actual != literal
            throw Error("Invalid JSON literal.")

        parser.position += StrLen(literal)

        return true
    }

    static _Current(parser) {
        if parser.position > parser.length
            return ""

        return SubStr(
            parser.source,
            parser.position,
            1
        )
    }
}

; ============================================================
; LOGGING UTILITIES
; ============================================================

Lib_Log(level, message) {
    try {
        ExecutionConsole_Log(
            level,
            message
        )
    }
}

Lib_LogError(message) {
    Lib_Log("ERROR", message)
}

Lib_LogInfo(message) {
    Lib_Log("INFO", message)
}

Lib_LogWarning(message) {
    Lib_Log("WARNING", message)
}

; ============================================================
; END OF Lib.ahk
; ============================================================
