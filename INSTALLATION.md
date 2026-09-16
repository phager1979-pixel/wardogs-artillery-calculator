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

Über das Tray-Symbol kann die Überwachung pausiert, fortgesetzt oder beendet werden.

## Sicherheit und Berechtigungen

Der Clipboard-Monitor verarbeitet ausschließlich Text, den der Benutzer selbst in die Windows-Zwischenablage kopiert. Er liest keinen Spielspeicher, keine Spieldateien und keinen Netzwerkverkehr.

Falls das Spiel mit Administratorrechten läuft, Windows die Rechner-App aber nicht fokussieren lässt, sollten beide Programme mit derselben Berechtigungsstufe ausgeführt werden. Standardmäßig sind keine Administratorrechte erforderlich.

Prüfe vor der Verwendung von Fenster- oder Clipboard-Automatisierung die jeweils aktuellen Spielregeln und Nutzungsbedingungen.

## Kartenmaterial

Die auswählbaren WARDOGS-Kartenbilder werden zur Laufzeit von `wardogs.zone` geladen und sind nicht im Archiv enthalten. Dadurch werden keine fremden Karten-Assets weiterverteilt. Der Rechner enthält immer ein lokales taktisches Fallback-Raster.