# Technical README — WARDOGS Artillery Map Calculator

Diese Datei erklärt, **wie das Projekt aufgebaut ist**, nicht wie man es
installiert (dafür: `INSTALLATION.md`) oder benutzt (dafür: `README.md`).
Zielgruppe: jemand, der den Code zum ersten Mal öffnet und verstehen will,
was wo passiert, bevor er etwas ändert.

## 1. Die zwei Dateien und ihre Aufgabenteilung

Das Projekt besteht bewusst aus **zwei unabhängigen Programmen**, die sich
nur über die Windows-Zwischenablage unterhalten — es gibt keine direkte
Code-Verbindung, keine gemeinsame Bibliothek, kein Netzwerk-Request.

```
┌─────────────────────────────┐         Zwischenablage        ┌──────────────────────────────────┐
│ wardogs-clipboard-monitor.ahk│ ───── (Ctrl+C, dann Ctrl+V) ──▶│ coordinate-distance-calculator.html│
│  (läuft im Hintergrund,      │                                 │  (läuft im Browser / Edge-App-    │
│   AutoHotkey v2)             │ ◀──────── Fokus zurück ──────── │   Fenster)                        │
└─────────────────────────────┘                                 └──────────────────────────────────┘
```

| Datei | Sprache/Laufzeit | Aufgabe |
|---|---|---|
| `wardogs-clipboard-monitor.ahk` | AutoHotkey v2 (Windows) | Hotkeys abfangen, Text aus dem WARDOGS-Chat kopieren, mit einem Rollen-Präfix versehen, in den Rechner einfügen, Fokus zurückgeben |
| `coordinate-distance-calculator.html` | HTML/CSS/JavaScript (Browser) | Distanz/Azimut/Flugzeit berechnen, Karte mit Zoom/Pan darstellen, feste Feuerposition merken |

## 2. Der einzige Vertrag zwischen beiden Dateien: das Präfix

Das AHK-Skript schreibt vor dem Einfügen eines der beiden Präfixe vor den
kopierten Text:

- `__WARDOGS_FIRING__ ` → soll als **Feuerposition** interpretiert werden
- `__WARDOGS_TARGET__ ` → soll als **Zielposition** interpretiert werden

Die HTML-Seite liest dieses Präfix in `importCoordinates()` per Regex aus
und entscheidet danach eindeutig, in welche Felder die Zahlen gehören —
sie muss also nicht raten, ob "zwei Zahlen im Klemmbrett" gerade Ziel oder
Feuerposition sind.

**Wichtig:** Wird dieser String in einer der beiden Dateien geändert, muss
er in der anderen exakt genauso geändert werden. Suche dazu nach
`__WARDOGS_` in beiden Dateien.

## 3. `wardogs-clipboard-monitor.ahk` — Ablauf im Detail

Einstiegspunkte (wer ruft was auf):

1. **Hotkeys** (`Hotkey(...)`, Standard F7/F9, über die Tray-Option
   "Shortcuts" änderbar) → `CaptureFiringCoordinates()` /
   `CaptureTargetCoordinates()` → gemeinsame Kernfunktion
   `CaptureCurrentChatLine(role)`.
2. **`OnClipboardChange(ClipboardChanged)`** — ein zweiter, unabhängiger
   Einstiegspunkt: reagiert auf *jedes* Kopieren im System (z. B. manuelles
   Ctrl+C), nicht nur auf die Hotkeys.

`CaptureCurrentChatLine(role)` macht (grob) Folgendes:

```
Zeile im Chat markieren (Shift+Pos1) → kopieren (Strg+C)
  → sieht der Text wie Koordinaten aus? (LooksLikeCoordinates)
  → Präfix anhängen → DeliverClipboardToCalculator()
```

`DeliverClipboardToCalculator()` ist der **Austrittspunkt** aus dem Skript:
Er aktiviert (oder öffnet) das Rechner-Fenster, klickt kurz in den
Dokumentbereich, sendet Strg+V und aktiviert danach wieder das vorherige
Fenster (WARDOGS).

### Einstellungen (Tray-Menü, rechte Maustaste auf das Icon)

Alle Optionen werden in `wardogs-clipboard-monitor.ini` (gleicher Ordner)
gespeichert und beim nächsten Start automatisch wieder geladen:

| Bereich | Tray-Menüpfad | Werte |
|---|---|---|
| Tasten | Shortcuts → Firing-Taste / Ziel-Taste | F5–F12 |
| Ton | Sound → Ton | Sanftes Ding / Weicher Klick / Kurzer Piepton / Kein Ton |
| Lautstärke | Sound → Lautstärke | Leise / Mittel / Laut (Systemlautstärke) |

Die Ton-Wiedergabe läuft über `PlayTone()` → `ApplyVolumeAndPlay()` →
`PlaySoundId()`. Da AutoHotkey keine Lautstärke pro einzelnem Sound setzen
kann, senkt `ApplyVolumeAndPlay()` bei "Leise"/"Mittel" kurz die
System-Lautstärke, spielt den Ton ab und stellt den vorherigen Wert sofort
wieder her — bei "Laut (Systemlautstärke)" bleibt die Lautstärke unangetastet.

### Diagnose

`WriteLog()` schreibt bei jedem wichtigen Schritt eine Zeile in
`wardogs-clipboard-monitor.log` (wird bei jedem Skriptstart neu angelegt).
Bei Problemen ist das die erste Anlaufstelle — siehe `INSTALLATION.md`.

## 4. `coordinate-distance-calculator.html` — Ablauf im Detail

Eine einzige Datei, kein Build-Prozess, kein Server nötig — einfach im
Browser öffnen. Grober Datenfluss:

```
Koordinaten-Inputs (#x #y #a #b)
   → calculate()  — rechnet Distanz/Azimut/Flugzeit
      → schreibt Ergebnisse in die Metrik-Kacheln
      → ruft autoFitMapView() → drawMap() — zeichnet F/T-Marker auf die Karte
```

Wichtige Funktionsgruppen (siehe auch den Kommentarblock direkt im Code
vor `extractCoordinates()`):

- **Import**: `extractCoordinates()`, `importCoordinates()` — lesen
  eingefügten/eingegebenen Text und erkennen Koordinatenpaare, auch ohne
  Präfix (z. B. bei manuellem Copy-Paste durch den Spieler selbst).
- **Fixed Position**: merkt sich eine Feuerposition dauerhaft
  (`localStorage`, Key `wardogs-fixed-position-v1`), sodass nur noch
  Zielkoordinaten importiert werden müssen.
- **Ballistik**: `simulateShot()` simuliert eine einzelne Schussbahn
  (einfache Physik-Simulation mit Luftwiderstand), `ballisticTable()`
  simuliert einmalig alle Mil-Einstellungen einer Waffe und cacht das
  Ergebnis, `interpolateArc()`/`flightSolution()` suchen darin die
  passende Flugzeit zur berechneten Distanz.
- **Karte**: `drawMap()` zeichnet Gitter, F/T-Marker und die Verbindungslinie
  auf ein `<canvas>`; Zoom/Pan wird in `mapView` gehalten und über
  `setMapZoom()`/`clampMapPan()`/`applyMapImageTransform()` verwaltet.
  **Autozoom** (`autoFitMapView()`, Checkbox "Autozoom 80%" über der Karte,
  gespeichert unter `wardogs-autozoom-v1`) zoomt automatisch so, dass die
  Strecke Feuerposition→Ziel rund 80 % der sichtbaren Fläche einnimmt,
  sobald ein gültiges Ziel gesetzt ist; ohne gültiges Ziel zeigt es die
  volle Karte. Jeder manuelle Zoom/Pan-Eingriff schaltet Autozoom wieder ab
  (`disableAutozoomFromManualInteraction()`), damit die App dem Spieler
  nicht ständig die selbst gewählte Ansicht wegzoomt.

## 5. Bekannte Grenzen / offene Ideen (Stand: dieser Commit)

- Kein Höhenmodell (2D-Distanz, keine Geländehöhe).
- Bewegliche Ziele, ein Radius-Overlay (Geschwindigkeit × Flugzeit) und
  Rechtsklick-Koordinaten-Erfassung direkt auf der Karte sind angedachte,
  aber noch **nicht** implementierte Ideen — siehe Diskussion im Chat-
  Verlauf/Issue-Tracker, bevor daran gebaut wird (u. a. offene Fragen zu
  Kartenauflösung und Straßen-Geodaten).
- Kartengrafiken werden live von `wardogs.zone` geladen (kein lokales
  Hosting) — Auflösung/Qualität liegt außerhalb der Kontrolle dieses
  Projekts.

## 6. Wenn du etwas änderst

- Präfix-Strings (`__WARDOGS_FIRING__` / `__WARDOGS_TARGET__`) nur in
  **beiden** Dateien gleichzeitig ändern.
- Neue Tray-Optionen im AHK-Skript: Muster aus "Sound"/"Shortcuts"
  übernehmen (Menu() bauen, `IniRead`/`IniWrite` für Persistenz,
  `RefresheMenuChecks()`-Funktion für die Häkchen).
- Neue Karten in der HTML-Datei: Eintrag im `MAPS`-Objekt ergänzen
  (`maxX`/`maxY` = Kartengröße in Koordinateneinheiten, `image` = URL).
