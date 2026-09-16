#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; WARDOGS clipboard bridge
; Watches only text explicitly copied into the Windows clipboard.

SetTitleMatchMode(2)
CoordMode("Mouse", "Screen")

CalculatorPath := A_ScriptDir "\coordinate-distance-calculator.html"
WindowTitle := "WARDOGS Artillery Map Calculator"
LastText := ""
LastHandledAt := 0
MonitoringEnabled := true
ReturnFocusEnabled := true
ReturnFocusDelayMs := 180
TargetHotkey := "F8"
FiringHotkey := "^F8"
WardogsWindowTitle := "WARDOGS"
RestrictHotkeyToWardogs := false
HotkeyCaptureActive := false

if !FileExist(CalculatorPath) {
    MsgBox("Calculator not found:`n" CalculatorPath, "WARDOGS Clipboard Bridge", "Iconx")
    ExitApp()
}

A_TrayMenu.Delete()
A_TrayMenu.Add("Open Calculator", OpenCalculator)
A_TrayMenu.Add("Capture target (F8)", CaptureTargetCoordinates)
A_TrayMenu.Add("Capture firing position (Ctrl+F8)", CaptureFiringCoordinates)
A_TrayMenu.Add("Pause Monitoring", ToggleMonitoring)
A_TrayMenu.Add("Return to previous window", ToggleReturnFocus)
A_TrayMenu.Check("Return to previous window")
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Open Calculator"
A_TrayMenu.ClickCount := 1

OnClipboardChange(ClipboardChanged)
Hotkey(TargetHotkey, CaptureTargetCoordinates)
Hotkey(FiringHotkey, CaptureFiringCoordinates)
TrayTip("Copy a WARDOGS X/Y pair to import it automatically.", "WARDOGS Clipboard Bridge")

CaptureTargetCoordinates(*) {
    CaptureCurrentChatLine("target")
}

CaptureFiringCoordinates(*) {
    CaptureCurrentChatLine("firing")
}

CaptureCurrentChatLine(role) {
    global WardogsWindowTitle, RestrictHotkeyToWardogs, HotkeyCaptureActive, LastText, LastHandledAt

    activeTitle := WinGetTitle("A")
    if RestrictHotkeyToWardogs && !InStr(StrUpper(activeTitle), StrUpper(WardogsWindowTitle)) {
        SoundBeep(500, 140)
        TrayTip("Coordinate shortcut ignored: active title is " activeTitle, "WARDOGS Clipboard Bridge")
        return
    }

    ; First beep confirms that AutoHotkey received the shortcut.
    SoundBeep(role = "firing" ? 900 : 1100, 70)
    HotkeyCaptureActive := true
    A_Clipboard := ""

    SendEvent("{Shift down}{Home down}")
    Sleep(90)
    SendEvent("{Home up}{Shift up}")
    Sleep(100)
    SendEvent("{Ctrl down}c{Ctrl up}")

    if !ClipWait(1.5) {
        HotkeyCaptureActive := false
        SoundBeep(420, 220)
        TrayTip("Shortcut worked, but no text was copied. Focus the chat input and keep the caret after the coordinates.", "WARDOGS Clipboard Bridge")
        return
    }

    text := Trim(A_Clipboard)
    if !LooksLikeCoordinates(text) {
        HotkeyCaptureActive := false
        SoundBeep(420, 220)
        TrayTip("Text was copied, but no valid coordinate pair was recognized.", "WARDOGS Clipboard Bridge")
        return
    }

    ; The prefix is consumed by the calculator and forces an unambiguous role.
    A_Clipboard := (role = "firing" ? "__WARDOGS_FIRING__ " : "__WARDOGS_TARGET__ ") text
    LastText := A_Clipboard
    LastHandledAt := A_TickCount
    SoundBeep(1450, 55)
    SoundBeep(1750, 55)
    DeliverClipboardToCalculator()
    HotkeyCaptureActive := false
}

ClipboardChanged(DataType) {
    global MonitoringEnabled, LastText, LastHandledAt, HotkeyCaptureActive
    if !MonitoringEnabled || HotkeyCaptureActive || DataType != 1
        return

    text := Trim(A_Clipboard)
    if text = "" || !LooksLikeCoordinates(text)
        return

    ; Suppress accidental duplicate notifications, but allow copying the
    ; same target again after a short delay.
    if text = LastText && A_TickCount - LastHandledAt < 1200
        return

    LastText := text
    LastHandledAt := A_TickCount
    DeliverClipboardToCalculator()
}

LooksLikeCoordinates(text) {
    if StrLen(text) > 300
        return false

    pattern := "[-+]?(?:\d+(?:[.,]\d+)?|[.,]\d+)"
    count := 0
    startAt := 1

    while RegExMatch(text, pattern, &match, startAt) {
        count += 1
        startAt := match.Pos + match.Len
        if count >= 4
            return true
    }

    if count != 2
        return false

    ; For a two-number match, require a familiar coordinate cue to avoid
    ; reacting to arbitrary copied prose containing two unrelated numbers.
    hasLabel := RegExMatch(text, "i)\b(?:x|y|a|b)\b")
    hasSeparator := InStr(text, ",") || InStr(text, "-") || InStr(text, "–") || InStr(text, "—") || InStr(text, "`n")
    return hasLabel || hasSeparator
}

DeliverClipboardToCalculator() {
    global WindowTitle, ReturnFocusEnabled, ReturnFocusDelayMs
    previousHwnd := WinExist("A")
    hwnd := EnsureCalculatorWindow()
    if !hwnd {
        TrayTip("Calculator window could not be opened.", "WARDOGS Clipboard Bridge")
        return
    }

    WinActivate("ahk_id " hwnd)
    if !WinWaitActive("ahk_id " hwnd, , 4) {
        TrayTip("Calculator could not be focused.", "WARDOGS Clipboard Bridge")
        return
    }

    ; Click the document area so Ctrl+V reaches the page even if the browser's
    ; address bar was focused previously. Restore the pointer afterwards.
    MouseGetPos(&oldX, &oldY)
    try {
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)
        Click(clientX + Floor(clientW * 0.72), clientY + Floor(clientH * 0.55))
        Sleep(100)
        Send("^v")
        Sleep(80)
        MouseMove(oldX, oldY, 0)
        if ReturnFocusEnabled && previousHwnd && previousHwnd != hwnd && WinExist("ahk_id " previousHwnd) {
            Sleep(ReturnFocusDelayMs)
            WinActivate("ahk_id " previousHwnd)
            TrayTip("Coordinates imported; previous window restored.", "WARDOGS Clipboard Bridge")
        } else {
            TrayTip("Coordinates imported.", "WARDOGS Clipboard Bridge")
        }
    } catch Error as err {
        MouseMove(oldX, oldY, 0)
        TrayTip("Automatic paste failed: " err.Message, "WARDOGS Clipboard Bridge")
    }
}

EnsureCalculatorWindow() {
    global WindowTitle, CalculatorPath
    if hwnd := WinExist(WindowTitle)
        return hwnd

    edgePath := A_ProgramFiles "\Microsoft\Edge\Application\msedge.exe"
    if !FileExist(edgePath) && A_Is64bitOS
        edgePath := A_ProgramFiles " (x86)\Microsoft\Edge\Application\msedge.exe"

    if FileExist(edgePath) {
        fileUrl := "file:///" StrReplace(CalculatorPath, "\", "/")
        quote := Chr(34)
        Run(quote edgePath quote " --app=" quote fileUrl quote)
    } else {
        Run(CalculatorPath)
    }

    return WinWait(WindowTitle, , 8)
}

OpenCalculator(*) {
    hwnd := EnsureCalculatorWindow()
    if hwnd
        WinActivate("ahk_id " hwnd)
}

ToggleMonitoring(*) {
    global MonitoringEnabled
    MonitoringEnabled := !MonitoringEnabled
    A_TrayMenu.Rename(MonitoringEnabled ? "Resume Monitoring" : "Pause Monitoring", MonitoringEnabled ? "Pause Monitoring" : "Resume Monitoring")
    TrayTip(MonitoringEnabled ? "Clipboard monitoring active." : "Clipboard monitoring paused.", "WARDOGS Clipboard Bridge")
}
ToggleReturnFocus(*) {
    global ReturnFocusEnabled
    ReturnFocusEnabled := !ReturnFocusEnabled
    if ReturnFocusEnabled
        A_TrayMenu.Check("Return to previous window")
    else
        A_TrayMenu.Uncheck("Return to previous window")
    TrayTip(ReturnFocusEnabled ? "Previous-window focus restoration enabled." : "Calculator will remain in front after import.", "WARDOGS Clipboard Bridge")
}