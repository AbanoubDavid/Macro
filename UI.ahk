
#Requires AutoHotkey v2.0

; ============================================================
; MacroStudio - UI.ahk
; Main Black Glass User Interface
; ============================================================

global MS_UI_Pages := Map()
global MS_UI_Navigation := Map()
global MS_UI_Controls := Map()
global MS_UI_Accent := "8B7CFF"

; ============================================================
; INITIALIZATION
; ============================================================

UI_Initialize() {
    global MS_MainGui
    global MS_UI
    global MS_UI_Pages
    global MS_UI_Navigation
    global MS_UI_Controls

    if MS_UI["initialized"]
        return true

    MS_MainGui := Gui(
        "+Resize +MinSize1000x650",
        "MacroStudio"
    )

    MS_MainGui.BackColor := "090A0D"
    MS_MainGui.MarginX := 0
    MS_MainGui.MarginY := 0

    MS_MainGui.SetFont("s10", "Segoe UI")

    MS_UI_BuildHeader()
    MS_UI_BuildSidebar()
    MS_UI_BuildPages()
    MS_UI_BuildFooter()

    MS_MainGui.OnEvent("Size", MS_UI_OnResize)
    MS_MainGui.OnEvent("Close", MS_UI_OnClose)
    MS_MainGui.OnEvent("Escape", MS_UI_OnEscape)

    MS_UI["initialized"] := true
    MS_UI["visible"] := true

    UI_ShowPage("Dashboard")

    MS_MainGui.Show("w1280 h800")

    return true
}

; ============================================================
; HEADER
; ============================================================

MS_UI_BuildHeader() {
    global MS_MainGui
    global MS_UI_Controls

    header := MS_MainGui.Add(
        "Text",
        "x0 y0 w1280 h65 Background101116"
    )

    title := MS_MainGui.Add(
        "Text",
        "x24 y17 w220 h30 cF3F3F5 BackgroundTrans",
        "MacroStudio"
    )

    title.SetFont("s19 Bold", "Segoe UI")

    version := MS_MainGui.Add(
        "Text",
        "x225 y24 w100 h20 c9296A3 BackgroundTrans",
        "v1.0.0"
    )

    status := MS_MainGui.Add(
        "Text",
        "x1010 y22 w250 h24 c69D6A0 BackgroundTrans",
        "● SYSTEM READY"
    )

    status.SetFont("s9 Bold")

    MS_UI_Controls["header"] := header
    MS_UI_Controls["title"] := title
    MS_UI_Controls["version"] := version
    MS_UI_Controls["status"] := status
}

; ============================================================
; SIDEBAR
; ============================================================

MS_UI_BuildSidebar() {
    global MS_MainGui
    global MS_UI_Navigation

    sidebar := MS_MainGui.Add(
        "Text",
        "x0 y65 w220 h735 Background101116"
    )

    sections := [
        {
            name: "WORKSPACE",
            items: [
                ["Dashboard", "⌂"],
                ["Macro Editor", "⌨"],
                ["Recorder", "●"]
            ]
        },
        {
            name: "AUTOMATION",
            items: [
                ["Profiles", "▤"],
                ["Macro Chaining", "⇄"],
                ["Conditions", "⑂"],
                ["Sandbox", "◈"],
                ["Pixel Detection", "◎"]
            ]
        },
        {
            name: "TOOLS",
            items: [
                ["Execution Console", ">_"],
                ["Templates", "▧"],
                ["Version History", "◷"]
            ]
        },
        {
            name: "APPLICATION",
            items: [
                ["Settings", "⚙"]
            ]
        }
    ]

    y := 90

    for section in sections {
        sectionLabel := MS_MainGui.Add(
            "Text",
            "x20 y" y " w180 h20 c777E8D BackgroundTrans",
            section.name
        )

        sectionLabel.SetFont("s8 Bold")

        y += 28

        for item in section.items {
            pageName := item[1]
            pageIcon := item[2]

            button := MS_MainGui.Add(
                "Button",
                "x12 y" y " w196 h36 Background101116 c9296A3",
                pageIcon "    " pageName
            )

            button.SetFont("s9", "Segoe UI")

            button.OnEvent(
                "Click",
                MS_UI_Navigate.Bind(pageName)
            )

            MS_UI_Navigation[pageName] := button

            y += 40
        }

        y += 14
    }
}

; ============================================================
; PAGE CONSTRUCTION
; ============================================================

MS_UI_BuildPages() {
    global MS_UI_Pages
    global MS_MainGui

    pages := [
        "Dashboard",
        "Macro Editor",
        "Recorder",
        "Profiles",
        "Macro Chaining",
        "Conditions",
        "Sandbox",
        "Pixel Detection",
        "Execution Console",
        "Templates",
        "Version History",
        "Settings"
    ]

    for pageName in pages {
        page := Gui(
            "+Parent" MS_MainGui.Hwnd " -Caption"
        )

        page.BackColor := "090A0D"
        page.MarginX := 0
        page.MarginY := 0

        MS_UI_Pages[pageName] := page

        MS_UI_BuildPageContent(pageName, page)
    }
}

; ============================================================
; PAGE CONTENT
; ============================================================

MS_UI_BuildPageContent(name, page) {
    switch name {
        case "Dashboard":
            MS_UI_BuildDashboard(page)

        case "Macro Editor":
            MS_UI_BuildEditor(page)

        case "Recorder":
            MS_UI_BuildRecorder(page)

        case "Profiles":
            MS_UI_BuildProfiles(page)

        case "Macro Chaining":
            MS_UI_BuildChaining(page)

        case "Conditions":
            MS_UI_BuildConditions(page)

        case "Sandbox":
            MS_UI_BuildSandbox(page)

        case "Pixel Detection":
            MS_UI_BuildPixel(page)

        case "Execution Console":
            MS_UI_BuildConsole(page)

        case "Templates":
            MS_UI_BuildTemplates(page)

        case "Version History":
            MS_UI_BuildVersions(page)

        case "Settings":
            MS_UI_BuildSettings(page)
    }
}

; ============================================================
; PAGE HEADER HELPER
; ============================================================

MS_UI_AddPageHeader(page, title, description) {
    heading := page.Add(
        "Text",
        "x30 y24 w900 h40 cF3F3F5 BackgroundTrans",
        title
    )

    heading.SetFont("s23 Bold")

    subtitle := page.Add(
        "Text",
        "x32 y68 w900 h25 c9296A3 BackgroundTrans",
        description
    )

    subtitle.SetFont("s9")

    return heading
}

; ============================================================
; PANEL HELPER
; ============================================================

MS_UI_AddPanel(page, x, y, w, h, title) {
    panel := page.Add(
        "Text",
        "x" x " y" y " w" w " h" h " Background17191F"
    )

    heading := page.Add(
        "Text",
        "x" (x + 18) " y" (y + 16) " w" (w - 36) " h24 cF3F3F5 BackgroundTrans",
        title
    )

    heading.SetFont("s11 Bold")

    return panel
}

; ============================================================
; DASHBOARD
; ============================================================

MS_UI_BuildDashboard(page) {
    global MS_Macros
    global MS_Profiles

    MS_UI_AddPageHeader(
        page,
        "Dashboard",
        "Your automation workspace at a glance."
    )

    MS_UI_AddPanel(page, 30, 120, 275, 125, "TOTAL MACROS")

    macroCount := page.Add(
        "Text",
        "x50 y165 w230 h55 cF3F3F5 BackgroundTrans",
        "0"
    )

    macroCount.SetFont("s30 Bold")

    MS_UI_AddPanel(page, 325, 120, 275, 125, "PROFILES")

    profileCount := page.Add(
        "Text",
        "x345 y165 w230 h55 cF3F3F5 BackgroundTrans",
        "0"
    )

    profileCount.SetFont("s30 Bold")

    MS_UI_AddPanel(page, 620, 120, 275, 125, "SYSTEM STATUS")

    systemStatus := page.Add(
        "Text",
        "x640 y165 w230 h55 c69D6A0 BackgroundTrans",
        "READY"
    )

    systemStatus.SetFont("s22 Bold")

    MS_UI_AddPanel(page, 30, 270, 865, 210, "QUICK ACCESS")

    buttons := [
        ["Open Editor", "Macro Editor"],
        ["Open Recorder", "Recorder"],
        ["Manage Profiles", "Profiles"],
        ["Open Sandbox", "Sandbox"]
    ]

    x := 50

    for item in buttons {
        button := page.Add(
            "Button",
            "x" x " y330 w185 h55 Background252832 cF3F3F5",
            item[1]
        )

        button.OnEvent(
            "Click",
            MS_UI_Navigate.Bind(item[2])
        )

        x += 205
    }

    dashboardInfo := page.Add(
        "Text",
        "x50 y420 w800 h25 c9296A3 BackgroundTrans",
        "Select a workspace from the sidebar to begin."
    )
}

; ============================================================
; MACRO EDITOR
; ============================================================

MS_UI_BuildEditor(page) {
    MS_UI_AddPageHeader(
        page,
        "Macro Editor",
        "Create, organize and edit automation sequences."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 110, "MACRO INFORMATION")

    page.Add(
        "Text",
        "x50 y170 w100 h24 c9296A3 BackgroundTrans",
        "Macro name"
    )

    page.Add(
        "Edit",
        "x150 y165 w300 h30 Background20232B cF3F3F5",
        ""
    )

    page.Add(
        "Text",
        "x500 y170 w100 h24 c9296A3 BackgroundTrans",
        "Trigger"
    )

    page.Add(
        "DropDownList",
        "x570 y165 w220 Background20232B cF3F3F5",
        ["None", "Keyboard", "Mouse", "Pixel"]
    )

    MS_UI_AddPanel(page, 30, 250, 865, 390, "ACTION SEQUENCE")

    page.Add(
        "Text",
        "x50 y300 w800 h25 c9296A3 BackgroundTrans",
        "Action management and sequence controls will appear here."
    )

    page.Add(
        "Text",
        "x50 y350 w800 h25 c777E8D BackgroundTrans",
        "Actions | Keyboard | Mouse | Delay | Conditions | Repeats"
    )
}

; ============================================================
; RECORDER
; ============================================================

MS_UI_BuildRecorder(page) {
    MS_UI_AddPageHeader(
        page,
        "Recorder",
        "Capture keyboard and mouse activity."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 200, "RECORDING CONFIGURATION")

    page.Add(
        "Checkbox",
        "x55 y170 BackgroundTrans cF3F3F5",
        "Keyboard Inputs"
    )

    page.Add(
        "Checkbox",
        "x55 y205 BackgroundTrans cF3F3F5",
        "Mouse Inputs"
    )

    page.Add(
        "Checkbox",
        "x300 y170 BackgroundTrans cF3F3F5",
        "Mouse Movement"
    )

    page.Add(
        "Checkbox",
        "x300 y205 BackgroundTrans cF3F3F5",
        "Record Delays"
    )

    page.Add(
        "Text",
        "x550 y170 w100 h25 c9296A3 BackgroundTrans",
        "Stop hotkey"
    )

    page.Add(
        "Edit",
        "x650 y165 w150 h30 Background20232B cF3F3F5",
        "F9"
    )

    MS_UI_AddPanel(page, 30, 340, 865, 150, "RECORDING STATUS")

    page.Add(
        "Text",
        "x55 y395 w300 h35 c69D6A0 BackgroundTrans",
        "● NOT RECORDING"
    )

    page.Add(
        "Text",
        "x55 y440 w500 h25 c9296A3 BackgroundTrans",
        "Duration: 00:00:00"
    )
}

; ============================================================
; PROFILES
; ============================================================

MS_UI_BuildProfiles(page) {
    MS_UI_AddPageHeader(
        page,
        "Macro Profiles",
        "Manage independent macro configurations."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "PROFILE LIBRARY")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Your saved profiles will appear in this workspace."
    )
}

; ============================================================
; MACRO CHAINING
; ============================================================

MS_UI_BuildChaining(page) {
    MS_UI_AddPageHeader(
        page,
        "Macro Chaining",
        "Connect multiple macros into sequential workflows."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "CHAIN WORKSPACE")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Configure macro order, transitions and execution behavior."
    )
}

; ============================================================
; CONDITIONAL BRANCHING
; ============================================================

MS_UI_BuildConditions(page) {
    MS_UI_AddPageHeader(
        page,
        "Conditional Branching",
        "Create IF, ELSE and nested execution conditions."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "CONDITION BUILDER")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Build conditional execution paths for your macros."
    )
}

; ============================================================
; SANDBOX
; ============================================================

MS_UI_BuildSandbox(page) {
    MS_UI_AddPageHeader(
        page,
        "Macro Sandbox",
        "Test macros with controlled execution and inspection."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "SANDBOX ENVIRONMENT")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Select a macro to prepare an isolated test session."
    )

    page.Add(
        "Text",
        "x55 y220 w800 h25 c9296A3 BackgroundTrans",
        "Step execution, condition inspection and test results."
    )
}

; ============================================================
; PIXEL DETECTION
; ============================================================

MS_UI_BuildPixel(page) {
    MS_UI_AddPageHeader(
        page,
        "Pixel Detection",
        "Monitor screen pixels, colors and selected regions."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "MONITOR CONFIGURATION")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Configure multiple pixel points and rectangular regions."
    )

    page.Add(
        "Text",
        "x55 y220 w800 h25 c9296A3 BackgroundTrans",
        "Color matching, tolerance and timeout configuration."
    )
}

; ============================================================
; EXECUTION CONSOLE
; ============================================================

MS_UI_BuildConsole(page) {
    global MS_UI_Controls

    MS_UI_AddPageHeader(
        page,
        "Execution Console",
        "Live application events, playback logs and diagnostics."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "LIVE LOG")

    console := page.Add(
        "Edit",
        "x50 y170 w825 h370 Background090A0D c69D6A0 ReadOnly Multi -Wrap VScroll"
    )

    console.SetFont("s9", "Consolas")

    MS_UI_Controls["console"] := console
}

; ============================================================
; TEMPLATES
; ============================================================

MS_UI_BuildTemplates(page) {
    MS_UI_AddPageHeader(
        page,
        "Action Templates",
        "Save and reuse frequently used action sequences."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "TEMPLATE LIBRARY")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Your saved action templates will appear here."
    )
}

; ============================================================
; VERSION HISTORY
; ============================================================

MS_UI_BuildVersions(page) {
    MS_UI_AddPageHeader(
        page,
        "Version History",
        "Inspect and restore previous macro versions."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "SAVED VERSIONS")

    page.Add(
        "Text",
        "x55 y175 w800 h25 c9296A3 BackgroundTrans",
        "Select a macro to inspect its saved versions."
    )
}

; ============================================================
; SETTINGS
; ============================================================

MS_UI_BuildSettings(page) {
    MS_UI_AddPageHeader(
        page,
        "Settings",
        "Configure MacroStudio behavior and appearance."
    )

    MS_UI_AddPanel(page, 30, 120, 865, 450, "GENERAL SETTINGS")

    page.Add(
        "Text",
        "x55 y175 w250 h25 cF3F3F5 BackgroundTrans",
        "Emergency controls"
    )

    page.Add(
        "Text",
        "x55 y220 w150 h25 c9296A3 BackgroundTrans",
        "Panic toggle"
    )

    page.Add(
        "Edit",
        "x210 y215 w120 h30 Background20232B cF3F3F5",
        "F12"
    )

    page.Add(
        "Text",
        "x55 y270 w150 h25 c9296A3 BackgroundTrans",
        "Stop macro"
    )

    page.Add(
        "Edit",
        "x210 y265 w120 h30 Background20232B cF3F3F5",
        "F10"
    )

    page.Add(
        "Text",
        "x55 y320 w150 h25 c9296A3 BackgroundTrans",
        "Stop recording"
    )

    page.Add(
        "Edit",
        "x210 y315 w120 h30 Background20232B cF3F3F5",
        "F9"
    )

    page.Add(
        "Text",
        "x55 y390 w500 h25 c9296A3 BackgroundTrans",
        "Appearance: Black Glass"
    )
}

; ============================================================
; PAGE NAVIGATION
; ============================================================

MS_UI_Navigate(pageName, *) {
    UI_ShowPage(pageName)
}

UI_ShowPage(pageName) {
    global MS_UI_Pages
    global MS_UI_Navigation
    global MS_CurrentTab
    global MS_UI

    if !MS_UI_Pages.Has(pageName)
        return false

    for name, page in MS_UI_Pages {
        page.Hide()
    }

    for name, button in MS_UI_Navigation {
        button.Opt("Background101116 c9296A3")
    }

    page := MS_UI_Pages[pageName]

    page.Show("x220 y65 w1060 h700")

    if MS_UI_Navigation.Has(pageName) {
        MS_UI_Navigation[pageName].Opt(
            "Background252832 cF3F3F5"
        )
    }

    MS_CurrentTab := pageName
    MS_UI["currentTab"] := pageName

    return true
}

; ============================================================
; FOOTER
; ============================================================

MS_UI_BuildFooter() {
    global MS_MainGui
    global MS_UI_Controls

    footer := MS_MainGui.Add(
        "Text",
        "x220 y765 w1060 h35 Background101116"
    )

    footerText := MS_MainGui.Add(
        "Text",
        "x240 y774 w600 h20 c777E8D BackgroundTrans",
        "MacroStudio  |  AutoHotkey v2  |  Black Glass UI"
    )

    footerText.SetFont("s8")

    MS_UI_Controls["footer"] := footer
    MS_UI_Controls["footerText"] := footerText
}

; ============================================================
; WINDOW RESIZING
; ============================================================

MS_UI_OnResize(gui, minMax, width, height) {
    global MS_UI_Pages
    global MS_CurrentTab

    if minMax = -1
        return

    pageWidth := Max(400, width - 220)
    pageHeight := Max(300, height - 100)

    if IsSet(MS_CurrentTab) && MS_UI_Pages.Has(MS_CurrentTab) {
        MS_UI_Pages[MS_CurrentTab].Show(
            "x220 y65 w" pageWidth " h" pageHeight
        )
    }

    MS_UI_ResizeHeader(width)
    MS_UI_ResizeFooter(width, height)
}

MS_UI_ResizeHeader(width) {
    global MS_UI_Controls

    if MS_UI_Controls.Has("header") {
        MS_UI_Controls["header"].Move(
            0, 0, width, 65
        )
    }

    if MS_UI_Controls.Has("status") {
        MS_UI_Controls["status"].Move(
            Max(500, width - 270),
            22
        )
    }
}

MS_UI_ResizeFooter(width, height) {
    global MS_UI_Controls

    if MS_UI_Controls.Has("footer") {
        MS_UI_Controls["footer"].Move(
            220,
            height - 35,
            Max(100, width - 220),
            35
        )
    }
}

; ============================================================
; WINDOW EVENTS
; ============================================================

MS_UI_OnClose(gui) {
    global MS_UI

    gui.Hide()
    MS_UI["visible"] := false

    return true
}

MS_UI_OnEscape(gui) {
    global MS_UI

    gui.Hide()
    MS_UI["visible"] := false
}

; ============================================================
; CONSOLE OUTPUT
; ============================================================

UI_ConsoleAppend(message) {
    global MS_UI_Controls

    if !MS_UI_Controls.Has("console")
        return false

    console := MS_UI_Controls["console"]

    timestamp := FormatTime(, "HH:mm:ss")

    console.Value .=
        "[" . timestamp . "] "
        . message
        . "`r`n"

    return true
}

; ============================================================
; STATUS UPDATES
; ============================================================

UI_SetStatus(message, color := "69D6A0") {
    global MS_UI_Controls

    if !MS_UI_Controls.Has("status")
        return false

    control := MS_UI_Controls["status"]

    control.Text := "● " . StrUpper(message)

    control.SetFont("c" . color)

    return true
}

; ============================================================
; APPLICATION VISIBILITY
; ============================================================

UI_Show() {
    global MS_MainGui
    global MS_UI

    if !IsObject(MS_MainGui)
        return false

    MS_MainGui.Show()

    MS_UI["visible"] := true

    return true
}

UI_Hide() {
    global MS_MainGui
    global MS_UI

    if !IsObject(MS_MainGui)
        return false

    MS_MainGui.Hide()

    MS_UI["visible"] := false

    return true
}

UI_Toggle() {
    global MS_UI

    if MS_UI["visible"]
        return UI_Hide()

    return UI_Show()
}

; ============================================================
; END OF UI.ahk
; ============================================================
