; ============================================================
; MacroStudio - Action Template Manager
; Create, save, organize, import, and reuse action templates.
; AutoHotkey v2
; ============================================================

TemplateManager_Initialize() {
    global MS_State, MS_Templates

    MS_Templates := Map(
        "ready", true,
        "items", Map(),
        "categories", [
            "Keyboard",
            "Mouse",
            "Timing",
            "Pixel",
            "Logic",
            "Custom"
        ],
        "selectedId", "",
        "search", "",
        "nextId", 1
    )

    MS_State["templateManagerReady"] := true

    TemplateManager_Load()
    return true
}

; ------------------------------------------------------------
; Template creation
; ------------------------------------------------------------

TemplateManager_Create(
    name,
    action,
    category := "Custom",
    description := ""
) {
    global MS_Templates

    if (name = "" || !IsObject(action))
        return false

    if !TemplateManager_ValidateCategory(category)
        category := "Custom"

    id := TemplateManager_GenerateId()

    template := Map(
        "id", id,
        "name", name,
        "description", description,
        "category", category,
        "action", Lib_Clone(action),
        "createdAt", A_Now,
        "updatedAt", A_Now,
        "usageCount", 0,
        "favorite", false
    )

    MS_Templates["items"][id] := template

    TemplateManager_Save()

    ExecutionConsole_Log(
        "Created action template: " name,
        "INFO"
    )

    return id
}

TemplateManager_CreateFromAction(
    name,
    actionIndex,
    category := "Custom",
    description := ""
) {
    global MS_ActiveMacro

    if !IsObject(MS_ActiveMacro)
        return false

    actions := MS_ActiveMacro.Get("actions", [])

    if !IsObject(actions)
        return false

    if (actionIndex < 1 || actionIndex > actions.Length)
        return false

    return TemplateManager_Create(
        name,
        actions[actionIndex],
        category,
        description
    )
}

TemplateManager_Update(id, property, value) {
    global MS_Templates

    items := MS_Templates["items"]

    if !items.Has(id)
        return false

    allowed := [
        "name",
        "description",
        "category",
        "action",
        "favorite"
    ]

    valid := false

    for item in allowed {
        if (property = item) {
            valid := true
            break
        }
    }

    if !valid
        return false

    if (property = "name" && value = "")
        return false

    if (property = "category" && !TemplateManager_ValidateCategory(value))
        return false

    if (property = "action" && !IsObject(value))
        return false

    items[id][property] := property = "action"
        ? Lib_Clone(value)
        : value

    items[id]["updatedAt"] := A_Now

    TemplateManager_Save()
    return true
}

TemplateManager_Delete(id) {
    global MS_Templates

    if !MS_Templates["items"].Has(id)
        return false

    MS_Templates["items"].Delete(id)

    if (MS_Templates["selectedId"] = id)
        MS_Templates["selectedId"] := ""

    TemplateManager_Save()
    return true
}

TemplateManager_Duplicate(id, newName := "") {
    global MS_Templates

    template := TemplateManager_Get(id)

    if !IsObject(template)
        return false

    if (newName = "")
        newName := template["name"] " Copy"

    return TemplateManager_Create(
        newName,
        template["action"],
        template["category"],
        template["description"]
    )
}

; ------------------------------------------------------------
; Retrieval and organization
; ------------------------------------------------------------

TemplateManager_Get(id) {
    global MS_Templates

    if !MS_Templates["items"].Has(id)
        return ""

    return MS_Templates["items"][id]
}

TemplateManager_GetAll() {
    global MS_Templates

    result := []

    for id, template in MS_Templates["items"]
        result.Push(template)

    return result
}

TemplateManager_GetByCategory(category) {
    global MS_Templates

    result := []

    for id, template in MS_Templates["items"] {
        if (template["category"] = category)
            result.Push(template)
    }

    return result
}

TemplateManager_Search(query) {
    global MS_Templates

    query := StrLower(query)
    results := []

    for id, template in MS_Templates["items"] {
        searchable := StrLower(
            template["name"] " "
            template["description"] " "
            template["category"]
        )

        if InStr(searchable, query)
            results.Push(template)
    }

    return results
}

TemplateManager_GetFavorites() {
    global MS_Templates

    results := []

    for id, template in MS_Templates["items"] {
        if template.Get("favorite", false)
            results.Push(template)
    }

    return results
}

TemplateManager_SetFavorite(id, favorite := true) {
    return TemplateManager_Update(id, "favorite", !!favorite)
}

TemplateManager_SetSelected(id) {
    global MS_Templates

    if !MS_Templates["items"].Has(id)
        return false

    MS_Templates["selectedId"] := id
    return true
}

TemplateManager_GetSelected() {
    global MS_Templates

    return TemplateManager_Get(
        MS_Templates.Get("selectedId", "")
    )
}

; ------------------------------------------------------------
; Applying templates
; ------------------------------------------------------------

TemplateManager_Apply(id) {
    global MS_Templates, MS_ActiveMacro

    template := TemplateManager_Get(id)

    if !IsObject(template)
        return false

    if !IsObject(MS_ActiveMacro)
        return false

    action := Lib_Clone(template["action"])

    if !IsObject(action)
        return false

    if !MS_ActiveMacro.Has("actions")
        MS_ActiveMacro["actions"] := []

    MS_ActiveMacro["actions"].Push(action)

    template["usageCount"] += 1
    template["updatedAt"] := A_Now

    Editor_SetModified(true)
    TemplateManager_Save()

    ExecutionConsole_Log(
        "Applied template: " template["name"],
        "INFO"
    )

    return true
}

TemplateManager_ApplyAt(id, index) {
    global MS_ActiveMacro

    template := TemplateManager_Get(id)

    if !IsObject(template) || !IsObject(MS_ActiveMacro)
        return false

    actions := MS_ActiveMacro.Get("actions", [])

    if !IsObject(actions)
        return false

    index := Max(1, Min(index, actions.Length + 1))

    actions.InsertAt(
        index,
        Lib_Clone(template["action"])
    )

    template["usageCount"] += 1
    template["updatedAt"] := A_Now

    Editor_SetModified(true)
    TemplateManager_Save()

    return true
}

TemplateManager_ApplyMultiple(ids) {
    global MS_ActiveMacro

    if !IsObject(ids) || !IsObject(MS_ActiveMacro)
        return false

    actions := MS_ActiveMacro.Get("actions", [])

    if !IsObject(actions)
        return false

    applied := 0

    for id in ids {
        template := TemplateManager_Get(id)

        if !IsObject(template)
            continue

        actions.Push(Lib_Clone(template["action"]))
        template["usageCount"] += 1
        template["updatedAt"] := A_Now
        applied += 1
    }

    if (applied > 0) {
        Editor_SetModified(true)
        TemplateManager_Save()
    }

    return applied
}

; ------------------------------------------------------------
; Built-in templates
; ------------------------------------------------------------

TemplateManager_CreateBuiltIns() {
    global MS_Templates

    builtIns := [
        Map(
            "name", "Basic Delay",
            "category", "Timing",
            "description", "Wait for a specified duration.",
            "action", Map(
                "type", "delay",
                "data", Map("duration", 1000)
            )
        ),
        Map(
            "name", "Left Click",
            "category", "Mouse",
            "description", "Perform a left mouse click.",
            "action", Map(
                "type", "mouse_click",
                "data", Map("button", "Left")
            )
        ),
        Map(
            "name", "Right Click",
            "category", "Mouse",
            "description", "Perform a right mouse click.",
            "action", Map(
                "type", "mouse_click",
                "data", Map("button", "Right")
            )
        ),
        Map(
            "name", "Press Enter",
            "category", "Keyboard",
            "description", "Press the Enter key.",
            "action", Map(
                "type", "key",
                "data", Map("key", "Enter")
            )
        ),
        Map(
            "name", "Press Space",
            "category", "Keyboard",
            "description", "Press the Space key.",
            "action", Map(
                "type", "key",
                "data", Map("key", "Space")
            )
        ),
        Map(
            "name", "Wait For Pixel",
            "category", "Pixel",
            "description", "Wait until a pixel matches a color.",
            "action", Map(
                "type", "pixel_condition",
                "data", Map(
                    "x", 0,
                    "y", 0,
                    "color", "FFFFFF",
                    "tolerance", 10
                )
            )
        ),
        Map(
            "name", "Repeat Three Times",
            "category", "Logic",
            "description", "Repeat an action sequence three times.",
            "action", Map(
                "type", "repeat",
                "data", Map(
                    "count", 3,
                    "actions", []
                )
            )
        )
    ]

    created := 0

    for item in builtIns {
        exists := false

        for id, template in MS_Templates["items"] {
            if (template["name"] = item["name"]) {
                exists := true
                break
            }
        }

        if exists
            continue

        TemplateManager_Create(
            item["name"],
            item["action"],
            item["category"],
            item["description"]
        )

        created += 1
    }

    return created
}

; ------------------------------------------------------------
; Import and export
; ------------------------------------------------------------

TemplateManager_Export(id, path := "") {
    template := TemplateManager_Get(id)

    if !IsObject(template)
        return false

    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export Template",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        Lib_WriteText(
            path,
            JSON.Stringify(template, true)
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Template export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

TemplateManager_ExportAll(path := "") {
    if (path = "") {
        path := FileSelect(
            "S16",
            A_ScriptDir "\Data",
            "Export All Templates",
            "JSON Files (*.json)"
        )
    }

    if (path = "")
        return false

    try {
        Lib_WriteText(
            path,
            JSON.Stringify(TemplateManager_GetAll(), true)
        )

        return true
    } catch as error {
        ExecutionConsole_Log(
            "Template collection export failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

TemplateManager_Import(path, replaceExisting := false) {
    global MS_Templates

    if !FileExist(path)
        return false

    try {
        template := JSON.Parse(Lib_ReadText(path))

        if !IsObject(template)
            return false

        required := ["name", "action", "category"]

        for key in required {
            if !template.Has(key)
                return false
        }

        if !IsObject(template["action"])
            return false

        name := template["name"]
        category := template["category"]

        if !TemplateManager_ValidateCategory(category)
            category := "Custom"

        if (name = "")
            return false

        existingId := ""

        for id, existing in MS_Templates["items"] {
            if (existing["name"] = name) {
                existingId := id
                break
            }
        }

        if (existingId != "") {
            if !replaceExisting
                return false

            MS_Templates["items"].Delete(existingId)
        }

        id := TemplateManager_GenerateId()

        imported := Map(
            "id", id,
            "name", name,
            "description", template.Get("description", ""),
            "category", category,
            "action", Lib_Clone(template["action"]),
            "createdAt", template.Get("createdAt", A_Now),
            "updatedAt", A_Now,
            "usageCount", 0,
            "favorite", false
        )

        MS_Templates["items"][id] := imported

        TemplateManager_Save()
        return id

    } catch as error {
        ExecutionConsole_Log(
            "Template import failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

; ------------------------------------------------------------
; Persistence
; ------------------------------------------------------------

TemplateManager_Save() {
    global MS_Templates

    try {
        data := Map(
            "items", MS_Templates["items"],
            "nextId", MS_Templates["nextId"]
        )

        Storage_SaveTemplates(data)
        return true

    } catch as error {
        ExecutionConsole_Log(
            "Template save failed: " error.Message,
            "ERROR"
        )
        return false
    }
}

TemplateManager_Load() {
    global MS_Templates

    try {
        loaded := Storage_LoadTemplates()

        if !IsObject(loaded)
            return false

        if loaded.Has("items") && IsObject(loaded["items"])
            MS_Templates["items"] := loaded["items"]

        MS_Templates["nextId"] := loaded.Get(
            "nextId",
            MS_Templates["nextId"]
        )

        return true

    } catch as error {
        ExecutionConsole_Log(
            "Template loading failed: " error.Message,
            "WARNING"
        )
        return false
    }
}

; ------------------------------------------------------------
; Validation and utilities
; ------------------------------------------------------------

TemplateManager_ValidateCategory(category) {
    global MS_Templates

    for item in MS_Templates["categories"] {
        if (item = category)
            return true
    }

    return false
}

TemplateManager_GenerateId() {
    global MS_Templates

    id := "template_" MS_Templates["nextId"]
    MS_Templates["nextId"] += 1

    while MS_Templates["items"].Has(id) {
        id := "template_" MS_Templates["nextId"]
        MS_Templates["nextId"] += 1
    }

    return id
}

TemplateManager_GetStatistics() {
    global MS_Templates

    total := MS_Templates["items"].Count
    favorites := 0
    usage := 0
    categories := Map()

    for category in MS_Templates["categories"]
        categories[category] := 0

    for id, template in MS_Templates["items"] {
        if template.Get("favorite", false)
            favorites += 1

        usage += template.Get("usageCount", 0)

        category := template.Get("category", "Custom")

        if categories.Has(category)
            categories[category] += 1
    }

    return Map(
        "total", total,
        "favorites", favorites,
        "totalUsage", usage,
        "categories", categories
    )
}

TemplateManager_Shutdown() {
    global MS_State, MS_Templates

    if !IsObject(MS_Templates)
        return true

    TemplateManager_Save()

    MS_Templates["ready"] := false
    MS_State["templateManagerReady"] := false

    return true
}