# Installation – WARDOGS Artillery Map Calculator

## Enthaltene Dateien

- `coordinate-distance-calculator.html` – eigenständige Rechner-App
- `wardogs-clipboard-monitor.ahk` – optionaler Windows-Clipboard-Monitor
- `README.md` – Funktionen, Berechnungen, Quellen und Bedienung
- `INSTALLATION.md` – diese Installationsanleitung

## 1. Rechner starten

Für die Grundfunktionen ist keine Installation erforderlich.

1. ZIP-Datei vollständig entpacken.
2. `coordinate-distance-calculator.html` doppelt anklicken.
3. Die App läuft lokal in einem aktuellen Browser wie Microsoft Edge, Chrome oder Firefox.

Entfernung, Azimut, Flugzeitberechnung, Fixed Position und das lokale Kartenraster funktionieren direkt. Die extern gehosteten Kartenbilder benötigen eine Internetverbindung; falls sie nicht erreichbar sind, verwendet die App automatisch das lokale Raster.

## 2. Optional: Clipboard-Automatik installieren

Für den Ein-Klick-Workflow wird **AutoHotkey v2** benötigt.

Offizieller Download:

https://www.autohotkey.com/

Wichtig: AutoHotkey **v2** installieren. Das beiliegende Skript ist nicht für AutoHotkey v1 geschrieben.

Danach:

1. `wardogs-clipboard-monitor.ahk` doppelt anklicken.
2. Das grüne AutoHotkey-Symbol erscheint im Windows-Infobereich.
3. Im Spiel einen Koordinatentext markieren und `Strg+C` drücken.
4. Der Rechner wird geöffnet oder fokussiert und übernimmt die Koordinaten.
5. Bei aktivierter **Fixed Position** wird ein kopiertes X/Y-Paar immer als Ziel verwendet.

Nach dem Import wird standardmäßig das zuvor aktive Fenster (zum Beispiel WARDOGS) wieder fokussiert. Über das Tray-Symbol kann **Return to previous window** ein- oder ausgeschaltet werden. Dort kann die Überwachung außerdem pausiert, fortgesetzt oder beendet werden.

## Sicherheit und Berechtigungen

Der Clipboard-Monitor verarbeitet ausschließlich Text, den der Benutzer selbst in die Windows-Zwischenablage kopiert. Er liest keinen Spielspeicher, keine Spieldateien und keinen Netzwerkverkehr.

Falls das Spiel mit Administratorrechten läuft, Windows die Rechner-App aber nicht fokussieren lässt, sollten beide Programme mit derselben Berechtigungsstufe ausgeführt werden. Standardmäßig sind keine Administratorrechte erforderlich.

Prüfe vor der Verwendung von Fenster- oder Clipboard-Automatisierung die jeweils aktuellen Spielregeln und Nutzungsbedingungen.

## Kartenmaterial

Die auswählbaren WARDOGS-Kartenbilder werden zur Laufzeit von `wardogs.zone` geladen und sind nicht im Archiv enthalten. Dadurch werden keine fremden Karten-Assets weiterverteilt. Der Rechner enthält immer ein lokales taktisches Fallback-Raster.
## F7/F8-Kurzablauf im Spiel

1. Die Funktion **Mark Coordinates** verwenden, sodass die Koordinaten in der Chatzeile stehen.
2. Sicherstellen, dass die Chatzeile aktiv und der Cursor am Zeilenende ist.
3. **F8** drücken.
4. Das Skript sendet bei F7 oder F8 `Shift+Pos1`, danach `Strg+C`, importiert und berechnet die Koordinaten und aktiviert anschließend WARDOGS erneut.

Der Hotkey ist für bessere Kompatibilität standardmäßig global aktiv. Optional kann oben im AHK-Skript `RestrictHotkeyToWardogs := true` gesetzt und `WardogsWindowTitle` an den tatsächlichen Fenstertitel angepasst werden.

### Tasten ändern

F7 (Feuerposition) und F8 (Zielposition) sind nur die Standardwerte. Über
das Tray-Symbol → **Shortcuts** → **Firing-Taste** bzw. **Ziel-Taste** lässt
sich jede der beiden auf F5–F12 umstellen (kein Neustart nötig, die Wahl
wird in `wardogs-clipboard-monitor.ini` gespeichert und beim nächsten Start
automatisch wieder geladen).

### F7/F8-Diagnose

- Kein Ton beim reinen Tastendruck: normal, das Skript arbeitet still im Hintergrund.
- Angenehmer heller Quittungston ("Ding"): Koordinaten wurden erkannt und erfolgreich an den Rechner übergeben.
- Dezenter Hinweiston: F8/F7 lief, aber es wurde kein geeigneter Text kopiert oder erkannt.
- Gar kein Ton und keine Reaktion im Rechner: Das neue Skript läuft nicht. Die alte Tray-Instanz beenden und die aktualisierte AHK-Datei starten.

Beide Töne sind Windows-Standard-Systemtöne (kein SoundBeep mehr) und richten sich nach der in Windows eingestellten Lautstärke.

### Ton und Lautstärke anpassen

Über das Tray-Symbol → **Sound** lässt sich einstellen:

- **Ton**: Sanftes Ding / Weicher Klick / Kurzer Piepton / Kein Ton
- **Lautstärke**: Leise / Mittel / Laut (Systemlautstärke)

Bei "Leise"/"Mittel" senkt das Skript die System-Lautstärke nur für den
Bruchteil einer Sekunde des Tons und stellt sie danach sofort wieder her –
"Laut (Systemlautstärke)" rührt die Lautstärke gar nicht an. Eine Auswahl
wird sofort einmal vorgespielt und dauerhaft in
`wardogs-clipboard-monitor.ini` gespeichert.

Bei einem hohen und danach tiefen Ton muss die Chat-Eingabe aktiv sein und der Cursor direkt hinter dem Koordinatentext stehen. Reiner Text im nicht editierbaren Chatverlauf kann mit `Shift+Pos1` möglicherweise nicht markiert werden.
## Rollenbezogene Kurzbefehle

- **Firing-Taste (Standard F7):** aktuelle Koordinaten als Feuerposition übernehmen, Fixed Position aktivieren und speichern.
- **Ziel-Taste (Standard F8):** aktuelle Koordinaten als Zielposition übernehmen und sofort gegen die gespeicherte Feuerposition berechnen.
- Danach wird WARDOGS automatisch wieder aktiviert.
- Beide Tasten lassen sich wie oben beschrieben über das Tray-Menü ändern.

## Autozoom (im Rechner, nicht im AHK-Skript)

Oberhalb der Karte gibt es die Checkbox **Autozoom 80%**:

- Aktiviert und gültiges Ziel vorhanden: Die Karte zoomt automatisch so,
  dass die Strecke Feuerposition→Ziel rund 80 % der sichtbaren Fläche
  einnimmt.
- Aktiviert, aber (noch) kein gültiges Ziel: Es wird die volle Karte gezeigt.
- Deaktiviert: Verhalten wie bisher, keine automatischen Zoomänderungen.
- Manuelles Zoomen, Scrollen oder Ziehen auf der Karte schaltet Autozoom
  automatisch wieder aus, damit die eigene Ansicht nicht sofort wieder
  überschrieben wird. Die Einstellung wird im Browser gespeichert
  (localStorage) und bleibt bis zum erneuten Ändern erhalten.
### Diagnose ohne Piepton

Das Skript legt im selben Ordner `wardogs-clipboard-monitor.log` an. Die Datei wird bei jedem Start neu erstellt. Sie zeigt, ob F7/F8 empfangen wurde, welcher Text kopiert wurde und ob Erkennung und Übergabe erfolgreich waren. Fehlt die Logdatei vollständig, läuft das aktualisierte AHK-Skript nicht.