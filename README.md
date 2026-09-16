# WARDOGS Artillery Map Calculator

A dependency-free standalone 2D map calculator for the WARDOGS L81 Mortar and the SPH-2 vehicle's L52 cannon.

## Run

Double-click `coordinate-distance-calculator.html`. No installation or internet connection is required.

## Coordinates and fixed position

The paste importer accepts labels, spaces, decimal dots, decimal commas, and common separators.

- Normal mode: two-number pastes alternate between firing and target position; four values fill both.
- Fixed Position: X/Y is stored in browser local storage and locked. Every normal two-value paste is treated as the target.
- Select **Change Position** to unlock X/Y. Type the new position and select **Save Position**, or paste one pair to replace and save it immediately.
- A four-value paste in fixed mode keeps the fixed position and uses its last pair as the target. During Change Position mode, it updates both positions.

## Map calculation

- Easting delta: `A - X`
- Northing delta: `B - Y`
- Ground distance: `sqrt(deltaE^2 + deltaN^2)`
- Grid-north azimuth: `atan2(deltaE, deltaN)`, normalized to `0–360 degrees`
- Scale: `1 coordinate unit = 100 metres`
- Height and terrain are not included.

## Weapons and flight time

The selector uses the in-game/community names **L81 Mortar (81 mm)** and **SPH-2 L52 (155 mm)**. L81 is always High Arc. Selecting SPH-2 reveals a second selector for **Low Arc** or **High Arc**; the Airtime instrument shows only the selected trajectory. An unavailable selected arc displays `OUT OF RANGE`.

The standalone numerical model uses:

- Gravity: `9.8 m/s^2`
- Drag coefficient: `0.00026`
- L81 launch speed: `93.5 m/s`, sight range `120–950 mil`
- SPH-2 L52 launch speed: `220 m/s`, sight range `0–1400 mil`
- Simulation timestep: `0.02 s`

These are unofficial community parameters and should be treated as estimates. Sources consulted in September 2026:

- https://wardogs.zone/calculators/artillery
- https://wardogshub.gg/artillery-calculator/
- https://www.wardogsbuilder.com/artillery/
- https://clutchbase.app/wardogs/artillery-calculator

## Interface

Direct Ground Distance, Grid-North Azimuth, and Estimated Flight Time are the primary responsive instruments. Coordinate deltas and detailed telemetry remain secondary.
## One-copy clipboard workflow (Windows)

`wardogs-clipboard-monitor.ahk` is an optional AutoHotkey v2 companion.

1. Install AutoHotkey v2 from its official website.
2. Keep the `.ahk` file in the same folder as `coordinate-distance-calculator.html`.
3. Double-click `wardogs-clipboard-monitor.ahk`.
4. In WARDOGS chat, manually select a coordinate callout and press `Ctrl+C`.
5. The script recognizes plausible two- or four-number coordinate text, opens/focuses the calculator, and sends one paste operation.
6. With **Fixed Position** enabled, a copied X/Y pair is always imported as the target.

The HTML app has a global paste receiver, so the import works regardless of which calculator field was focused. The monitor reads only text placed in the Windows clipboard by the user; it does not inspect game memory, files, network traffic, or processes. Confirm that window/clipboard automation is permitted by the current game rules before use.

Use the tray icon to open the calculator, pause/resume monitoring, or exit the bridge.
## Tactical map imagery

The lower-right plot can load public WARDOGS region rasters for Bakurani, Ozeti, and Zestafona from `wardogs.zone`. The images remain hosted by their source and are not redistributed with this project. A visible source link is included in the interface. Firing/target markers, connecting line, grid, and calculations are drawn locally in a separate canvas overlay.

The map imagery requires internet access. If an image is unavailable, the calculator automatically retains the local coordinate-grid fallback. The coordinate overlay uses the published 163.84 by 163.84 game-coordinate extent; no terrain-height correction is applied.

## Enlarged map layout

The tactical map is arranged at full width directly below the three primary solution instruments. Auxiliary deltas and detailed telemetry follow beneath it so the map remains readable across flexible window sizes.
## V2 zoomable map

- Zoom with the mouse wheel while keeping the cursor position anchored.
- Drag the map with mouse, pen, or touch to pan.
- Use `+`, `-`, and **Reset** controls when a wheel is unavailable.
- Zoom range: `100%–800%`.
- Firing position, target, connecting line, and grid stay aligned with the map while navigating.
- Changing the selected map resets the view to `100%`.
## Automatic focus return

The AutoHotkey bridge remembers the active window before importing coordinates. After the calculator receives the paste, the bridge restores that previous window after a short delay, allowing WARDOGS to remain the working foreground application. The behavior is enabled by default and can be toggled through **Return to previous window** in the tray menu.

Exclusive-fullscreen games or mismatched privilege levels can prevent Windows from restoring focus. Borderless-windowed mode is recommended; the game and bridge should run at the same privilege level.
## F7/F8 chat-coordinate shortcuts

With the WARDOGS chat coordinate line active and the caret at its end, press **F8**. The bridge performs this sequence:

1. Sends `Shift+Home` to select the current chat line.
2. Sends `Ctrl+C` to copy it.
3. The clipboard monitor recognizes and imports the coordinates.
4. The calculator computes the solution.
5. Focus returns automatically to WARDOGS.

The hotkey is global and the window-title restriction is disabled by default for compatibility with varying game-window titles. Advanced users can change `TargetHotkey`, `FiringHotkey`, `WardogsWindowTitle`, or set `RestrictHotkeyToWardogs := true` near the top of `wardogs-clipboard-monitor.ahk`.
### F7/F8 diagnostics

The default window-title restriction is disabled because some WARDOGS builds expose a different title. F8 now uses explicit `SendEvent` key-down/up events and audible diagnostics:

- One high beep: the bridge received F8.
- Two higher beeps: coordinate text was recognized and delivery started.
- One low beep: F8 ran, but copying or coordinate recognition failed.

If there is no first beep, the updated AutoHotkey script is not running. Exit the old tray instance and start the new script. If the first beep is followed by a low beep, the WARDOGS chat input must be focused and the caret must be positioned directly after the coordinate text; rendered chat-history text may not be keyboard-selectable.
## Role-specific coordinate shortcuts

- **F7** selects and copies the current coordinate line as the **firing position**, enables Fixed Position, stores it, and computes with the current target.
- **F8** selects and copies the current coordinate line as the **target position** and computes against the stored firing position.
- Both shortcuts restore the previously active WARDOGS window after delivery.

The bridge adds a temporary internal role marker to the clipboard text so the calculator does not have to guess whether a two-number pair is firing or target data.
### Clipboard bridge log

The bridge writes `wardogs-clipboard-monitor.log` beside the script. It is recreated whenever the bridge starts and records whether F7/F8 was received, whether text was copied and recognized, and whether calculator delivery completed. This works even when Windows system beeps or notifications are disabled.