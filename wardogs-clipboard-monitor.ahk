#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================================
; WARDOGS Clipboard Bridge
; ----------------------------------------------------------------------------
; This script is the "glue" between the WARDOGS game chat (where coordinates
; get typed/pasted) and the local HTML calculator
; (coordinate-distance-calculator.html). Its job, step by step:
;
;   1. Wait for a hotkey (default F7 = firing position, F8 = target).
;   2. Copy the coordinate text currently on the chat input line.
;   3. Tag that text with a hidden prefix (__WARDOGS_FIRING__ / __WARDOGS_TARGET__)
;      so the HTML side knows unambiguously which role the numbers have.
;   4. Paste it into the calculator window (opening it first if needed).
;   5. Jump focus back to WARDOGS so the player can keep playing.
;
; ENTRY POINTS (where the outside world hooks into this script):
;   - Hotkey(...) calls further down register the keyboard shortcuts.
;     Windows is the "caller" here: it invokes CaptureFiringCoordinates() /
;     CaptureTargetCoordinates() whenever the configured key is pressed,
;     no matter which window currently has focus.
;   - OnClipboardChange(ClipboardChanged) is a second, independent entry
;     point: it fires automatically whenever ANYTHING is copied anywhere on
;     the system, so a manual Ctrl+C of a coordinate pair is also picked up.
;
; EXIT POINT (where this script hands off to the OTHER file):
;   - DeliverClipboardToCalculator() is the function that leaves this
;     script's "world": it activates coordinate-distance-calculator.html and
;     sends it a paste (Ctrl+V). That HTML file has its own "paste" event
;     listener in its <script> section which reads the __WARDOGS_FIRING__ /
;     __WARDOGS_TARGET__ prefix and decides where the numbers belong.
;     That prefix string is the ONLY contract between this script and the
;     HTML file - if you rename it here, rename it there too.
;
; SETTINGS: every user-configurable option below (which key does what, which
; sound plays, how loud) is stored in wardogs-clipboard-monitor.ini, next to
; this script, so it survives restarts/updates. Change these from the tray
; icon menu (bottom-right of the taskbar) instead of editing this file.
; ============================================================================

SetTitleMatchMode(2)
CoordMode("Mouse", "Screen")

CalculatorPath := A_ScriptDir "\coordinate-distance-calculator.html"
WindowTitle := "WARDOGS Artillery Map Calculator"
LastText := ""
LastHandledAt := 0
MonitoringEnabled := true
ReturnFocusEnabled := true
ReturnFocusDelayMs := 180
LogPath := A_ScriptDir "\wardogs-clipboard-monitor.log"
SettingsPath := A_ScriptDir "\wardogs-clipboard-monitor.ini"
WardogsWindowTitle := "WARDOGS"
RestrictHotkeyToWardogs := false
HotkeyCaptureActive := false

; ----------------------------------------------------------------------------
; Persisted user settings (loaded once here, changed later only via the tray
; menu - see the "Tray menu" and "Sound"/"Shortcuts" sections below).
; ----------------------------------------------------------------------------

; Which function keys are offered as choices in the tray "Shortcuts" menu.
AvailableKeys := ["F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
FiringHotkey := IniRead(SettingsPath, "Shortcuts", "FiringKey", "F7")
TargetHotkey := IniRead(SettingsPath, "Shortcuts", "TargetKey", "F8")

; Sound: which tone plays on a successful data hand-off, and how loud.
;   Tone:   "ding" | "soft" | "beep" | "off"
;   Volume: "low"  | "medium" | "system" ("system" = do not touch the volume)
ToneOptions := [["ding", "Sanftes Ding"], ["soft", "Weicher Klick"], ["beep", "Kurzer Piepton"], ["off", "Kein Ton"]]
VolumeOptions := [["low", "Leise"], ["medium", "Mittel"], ["system", "Laut (Systemlautstärke)"]]
SelectedTone := IniRead(SettingsPath, "Sound", "Tone", "ding")
SelectedVolume := IniRead(SettingsPath, "Sound", "Volume", "low")

WriteLog(message) {
    global LogPath
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " message "`n", LogPath, "UTF-8")
}

try FileDelete(LogPath)
WriteLog("Clipboard bridge started. Firing=" FiringHotkey ", Target=" TargetHotkey ", Tone=" SelectedTone ", Volume=" SelectedVolume)

if !FileExist(CalculatorPath) {
    MsgBox("Calculator not found:`n" CalculatorPath, "WARDOGS Clipboard Bridge", "Iconx")
    ExitApp()
}

; ----------------------------------------------------------------------------
; Tray menu (right-click the icon in the Windows taskbar's notification area)
; ----------------------------------------------------------------------------
A_TrayMenu.Delete()
A_TrayMenu.Add("Open Calculator", OpenCalculator)
A_TrayMenu.Add("Capture target", CaptureTargetCoordinates)
A_TrayMenu.Add("Capture firing position", CaptureFiringCoordinates)
A_TrayMenu.Add("Pause Monitoring", ToggleMonitoring)
A_TrayMenu.Add("Return to previous window", ToggleReturnFocus)
A_TrayMenu.Check("Return to previous window")
A_TrayMenu.Add()

; --- "Shortcuts" submenu: choose which function key triggers which capture.
; Each entry calls SetFiringKey()/SetTargetKey() with its own key name baked
; in via .Bind(), so one loop can build all eight menu items.
FiringKeyMenu := Menu()
for keyName in AvailableKeys
    FiringKeyMenu.Add(keyName, SetFiringKey.Bind(keyName))
TargetKeyMenu := Menu()
for keyName in AvailableKeys
    TargetKeyMenu.Add(keyName, SetTargetKey.Bind(keyName))
ShortcutsMenu := Menu()
ShortcutsMenu.Add("Firing-Taste", FiringKeyMenu)
ShortcutsMenu.Add("Ziel-Taste", TargetKeyMenu)
A_TrayMenu.Add("Shortcuts", ShortcutsMenu)

; --- "Sound" submenu: tone + volume. See PlayTone() further below for the
; actual playback logic.
ToneMenu := Menu()
for opt in ToneOptions
    ToneMenu.Add(opt[2], SetTone.Bind(opt[1]))
VolumeMenu := Menu()
for opt in VolumeOptions
    VolumeMenu.Add(opt[2], SetVolume.Bind(opt[1]))
SoundMenu := Menu()
SoundMenu.Add("Ton", ToneMenu)
SoundMenu.Add("Lautstärke", VolumeMenu)
A_TrayMenu.Add("Sound", SoundMenu)

A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Open Calculator"
A_TrayMenu.ClickCount := 1

; Put a checkmark next to whichever key/tone/volume is currently active.
RefreshShortcutMenuChecks()
RefreshSoundMenuChecks()

; ----------------------------------------------------------------------------
; ENTRY POINT 1: global hotkeys. Windows calls these functions on every
; keypress, no matter which window - including the game itself - has focus.
; ----------------------------------------------------------------------------
Hotkey(TargetHotkey, CaptureTargetCoordinates)
Hotkey(FiringHotkey, CaptureFiringCoordinates)

; ENTRY POINT 2: fires whenever ANYTHING is copied anywhere on the system.
OnClipboardChange(ClipboardChanged)

TrayTip("Copy a WARDOGS X/Y pair to import it automatically.", "WARDOGS Clipboard Bridge")

CaptureTargetCoordinates(*) {
    CaptureCurrentChatLine("target")
}

CaptureFiringCoordinates(*) {
    CaptureCurrentChatLine("firing")
}

; The core routine both hotkeys funnel into. "role" is either "firing" or
; "target" and decides which __WARDOGS_...__ prefix gets attached before the
; text is handed over to the calculator.
CaptureCurrentChatLine(role) {
    global WardogsWindowTitle, RestrictHotkeyToWardogs, HotkeyCaptureActive, LastText, LastHandledAt
    WriteLog("Hotkey received: " role)

    activeTitle := WinGetTitle("A")
    if RestrictHotkeyToWardogs && !InStr(StrUpper(activeTitle), StrUpper(WardogsWindowTitle)) {
        PlayTone("error")
        WriteLog("Blocked by window-title restriction. Active: " activeTitle)
        TrayTip("Coordinate shortcut ignored: active title is " activeTitle, "WARDOGS Clipboard Bridge")
        return
    }

    ; No sound on the keypress itself - the log file already records it, and
    ; a tone on every single press was reported as too intrusive. Audible
    ; feedback now only happens on success/failure further below.
    HotkeyCaptureActive := true
    A_Clipboard := ""

    ; Select from the caret back to the start of the line, then copy it.
    ; SendEvent (instead of SendInput) is used because some games only react
    ; to the slower, more "human-like" event-based key simulation.
    SendEvent("{Shift down}{Home down}")
    Sleep(90)
    SendEvent("{Home up}{Shift up}")
    Sleep(100)
    SendEvent("{Ctrl down}c{Ctrl up}")

    if !ClipWait(1.5) {
        HotkeyCaptureActive := false
        PlayTone("error")
        WriteLog("Copy failed: clipboard stayed empty")
        TrayTip("Shortcut worked, but no text was copied. Focus the chat input and keep the caret after the coordinates.", "WARDOGS Clipboard Bridge")
        return
    }

    text := Trim(A_Clipboard)
    WriteLog("Copied text: " text)
    if !LooksLikeCoordinates(text) {
        HotkeyCaptureActive := false
        PlayTone("error")
        WriteLog("Coordinate recognition failed")
        TrayTip("Text was copied, but no valid coordinate pair was recognized.", "WARDOGS Clipboard Bridge")
        return
    }

    ; The prefix is the hand-off contract with coordinate-distance-calculator.html
    ; (see its "paste" event listener) - it is consumed there and forces an
    ; unambiguous role instead of guessing from context.
    A_Clipboard := (role = "firing" ? "__WARDOGS_FIRING__ " : "__WARDOGS_TARGET__ ") text
    LastText := A_Clipboard
    LastHandledAt := A_TickCount
    PlayTone("success")
    WriteLog("Coordinates recognized; delivering as " role)
    DeliverClipboardToCalculator()
    HotkeyCaptureActive := false
}

; ----------------------------------------------------------------------------
; Sound: tone selection, volume, and the actual playback.
; ----------------------------------------------------------------------------

; Plays either the chosen "success" tone or a fixed, quieter "error" tone.
; Completely silent if the user picked "Kein Ton" in the tray menu.
PlayTone(kind) {
    global SelectedTone
    if SelectedTone = "off"
        return
    soundId := kind = "error" ? "beep-low" : SelectedTone
    ApplyVolumeAndPlay(soundId)
}

; Plays soundId at the volume level currently selected in the tray menu.
; "system" leaves the system volume untouched. "low"/"medium" briefly lower
; the system output volume just for the tone's duration and restore the
; previous value right afterwards - AutoHotkey has no way to set the volume
; of a single sound without touching the shared system mixer, so this is a
; short, intentional dip rather than a permanent change.
ApplyVolumeAndPlay(soundId) {
    global SelectedVolume
    if SelectedVolume = "system" {
        PlaySoundId(soundId)
        return
    }
    targetVolume := SelectedVolume = "low" ? 8 : 22
    previousVolume := ""
    try previousVolume := SoundGetVolume()
    try SoundSetVolume(targetVolume)
    PlaySoundId(soundId)
    Sleep(160)
    if previousVolume != ""
        try SoundSetVolume(previousVolume)
}

; Turns a sound id into an actual Windows sound. *NN ids are built-in Windows
; system sounds (the same ones used for notifications), which sound softer
; and more "normal" than a raw SoundBeep and automatically follow whatever
; sound scheme the user has chosen in Windows.
PlaySoundId(soundId) {
    switch soundId {
        case "ding":
            SoundPlay("*64")     ; Windows-Standard "Ding" (Asterisk/Notification)
        case "soft":
            SoundPlay("*32")     ; etwas weicherer, tieferer Systemton (Question)
        case "beep":
            SoundBeep(1200, 60)  ; kurzer, hoher klassischer Piepton
        case "beep-low":
            SoundPlay("*48")     ; dezenter Warnton, nur bei Fehlern
        default:
            SoundPlay("*64")
    }
}

SetTone(key, *) {
    global SelectedTone, SettingsPath
    SelectedTone := key
    try IniWrite(key, SettingsPath, "Sound", "Tone")
    RefreshSoundMenuChecks()
    PlayTone("success") ; sofort vorhören
}

SetVolume(key, *) {
    global SelectedVolume, SettingsPath
    SelectedVolume := key
    try IniWrite(key, SettingsPath, "Sound", "Volume")
    RefreshSoundMenuChecks()
    PlayTone("success") ; sofort vorhören
}

; Puts a checkmark next to the currently active tone/volume tray entries and
; removes it from every other entry in the same submenu.
RefreshSoundMenuChecks() {
    global ToneMenu, VolumeMenu, ToneOptions, VolumeOptions, SelectedTone, SelectedVolume
    for opt in ToneOptions {
        if opt[1] = SelectedTone
            ToneMenu.Check(opt[2])
        else
            ToneMenu.Uncheck(opt[2])
    }
    for opt in VolumeOptions {
        if opt[1] = SelectedVolume
            VolumeMenu.Check(opt[2])
        else
            VolumeMenu.Uncheck(opt[2])
    }
}

; ----------------------------------------------------------------------------
; Shortcuts: let the user reassign which function key does what, from the
; tray menu, without ever having to edit this file.
; ----------------------------------------------------------------------------

SetFiringKey(keyName, *) {
    global FiringHotkey, TargetHotkey, SettingsPath
    if keyName = TargetHotkey {
        TrayTip("Diese Taste ist bereits der Ziel-Hotkey.", "WARDOGS Clipboard Bridge")
        return
    }
    try Hotkey(FiringHotkey, CaptureFiringCoordinates, "Off") ; alte Bindung entfernen
    FiringHotkey := keyName
    Hotkey(FiringHotkey, CaptureFiringCoordinates, "On")      ; neue Bindung setzen
    try IniWrite(FiringHotkey, SettingsPath, "Shortcuts", "FiringKey")
    RefreshShortcutMenuChecks()
    WriteLog("Firing hotkey changed to " FiringHotkey)
    TrayTip("Feuerposition jetzt auf " FiringHotkey, "WARDOGS Clipboard Bridge")
}

SetTargetKey(keyName, *) {
    global FiringHotkey, TargetHotkey, SettingsPath
    if keyName = FiringHotkey {
        TrayTip("Diese Taste ist bereits der Feuer-Hotkey.", "WARDOGS Clipboard Bridge")
        return
    }
    try Hotkey(TargetHotkey, CaptureTargetCoordinates, "Off") ; alte Bindung entfernen
    TargetHotkey := keyName
    Hotkey(TargetHotkey, CaptureTargetCoordinates, "On")      ; neue Bindung setzen
    try IniWrite(TargetHotkey, SettingsPath, "Shortcuts", "TargetKey")
    RefreshShortcutMenuChecks()
    WriteLog("Target hotkey changed to " TargetHotkey)
    TrayTip("Zielposition jetzt auf " TargetHotkey, "WARDOGS Clipboard Bridge")
}

RefreshShortcutMenuChecks() {
    global FiringKeyMenu, TargetKeyMenu, AvailableKeys, FiringHotkey, TargetHotkey
    for keyName in AvailableKeys {
        if keyName = FiringHotkey
            FiringKeyMenu.Check(keyName)
        else
            FiringKeyMenu.Uncheck(keyName)
        if keyName = TargetHotkey
            TargetKeyMenu.Check(keyName)
        else
            TargetKeyMenu.Uncheck(keyName)
    }
}

; ----------------------------------------------------------------------------
; Passive clipboard watcher (ENTRY POINT 2, see header comment at the top)
; ----------------------------------------------------------------------------
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

; Very small heuristic: "does this text plausibly contain a coordinate pair?"
; Used both by the hotkey capture and the passive clipboard watcher above.
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

; ----------------------------------------------------------------------------
; EXIT POINT: hands the tagged coordinate text over to
; coordinate-distance-calculator.html by simulating a paste (Ctrl+V) into it.
; ----------------------------------------------------------------------------
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
            WriteLog("Import completed; previous window restored")
            TrayTip("Coordinates imported; previous window restored.", "WARDOGS Clipboard Bridge")
        } else {
            TrayTip("Coordinates imported.", "WARDOGS Clipboard Bridge")
        }
    } catch Error as err {
        MouseMove(oldX, oldY, 0)
        WriteLog("Automatic paste failed: " err.Message)
        TrayTip("Automatic paste failed: " err.Message, "WARDOGS Clipboard Bridge")
    }
}

; Finds the calculator window if it's already open, otherwise launches it -
; preferring a dedicated Edge "app window" so it doesn't get buried among
; the player's other regular browser tabs.
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
