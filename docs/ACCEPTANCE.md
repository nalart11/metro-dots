# Acceptance report — 28 September 2026

Deployed on the existing Arch Linux / Hyprland 0.55.4 Lua session. Quickshell was chosen because this installed build exposes native NetworkManager, BlueZ, PipeWire, tray, notifications, Polkit and Hyprland models. Waybar would require a second implementation for the full-screen Start and Charms; AGS would replace an already installed and working runtime.

## Safety and recovery

- Verified original snapshot: `2026-09-28_18-25-33` (47,240 entries).
- Verified baseline immediately before first installation: `2026-09-28_18-44-08` (47,241 entries). `hypr-win8-rollback --latest` selects this snapshot after subsequent updates.
- Full home-relative copies, SHA256 files, entry manifests, package lists, symlink targets and modes retained. Kvantum's existing root-owned directory is unchanged; its original UID/GID are recorded separately because an unprivileged copy cannot acquire UID 0.
- Latest installed transaction `2026-09-28_22-13-59` completed PRECHECK through POSTCHECK; all 38 deployed files match installed or recorded runtime hashes. Every deployment and update created a new verified snapshot before changing managed files.
- Standalone rollback was verified with graphical environment variables empty. Actual restore was exercised in an isolated fixture: original file contents, executable mode, directory mode and symlink returned; extra user files survived; a managed file from a later version was quarantined; current state was backed up first.
- No live full rollback, uninstall, reboot, shutdown or logout was executed. The graphical session and both original monitor modes/positions/scales remain intact.

## Functional checks

| Requirement | Result and evidence |
| --- | --- |
| Full-screen Start on Super; configurable Metro tiles | Passed real key input; 15 loaded tiles (including the user’s IntelliJ pin), battery tile hidden on this desktop |
| All Apps and type-to-search | Passed; 113 visible installed desktop entries; native GIO catalog |
| Application launch and UI restart | Real terminal launched from All Apps and survived shell service restart |
| Taskbar, pins, windows, square workspaces, tray | Running on both screens; three status-notifier items |
| Charms, Search, Settings, workspace selector, Alt+Tab | Passed actual key events; Alt release finishes switcher |
| Audio and network | Real current PipeWire output/volume and NetworkManager connection shown; native controls implemented |
| Bluetooth | Real paired devices shown; native BlueZ power/discovery/device controls implemented |
| Notifications, history, Polkit | Native notification delivered and expired safely in history; auth agent registered |
| Battery/backlight | Conditional UI implemented; hidden because this machine has neither laptop battery nor backlight |
| Lockscreen and idle | hyprlock parsed successfully; independent lock scope; original no-auto-lock/no-auto-suspend policy retained |
| Power menu | Implemented with second-click confirmation for sleep/restart/shutdown/logout; destructive actions not exercised |
| Screenshots and clipboard | Actual slurp drag produced PNG; saved bytes match clipboard; cliphist decoding verified |
| Important original binds | Preserved original modules with documented migration table; editor moved to Super+Alt+C |
| Multi-monitor | Original modes, positions and scales match baseline; overlays choose focused monitor |
| Scaling and aspect ratios | All 12 synthetic viewport/Qt-scale combinations passed: 16:9, 16:10, 21:9 × 1, 1.25, 1.5, 2 |
| CPU usage | Ten-second idle sample: 0.5% of one core for shell and metrics process; not a long-term benchmark |
| Installer dry run | Lists saved/managed paths, packages and units without writes or runtime actions |
| Update/uninstall recovery | Fresh backup on update; uninstall preserves backup directory; recovery code fixture-tested |

Scaling tests used copies of the UI with constrained viewports and Qt scaling; physical monitor settings were not changed. Wi-Fi disconnection, Bluetooth power changes, display reconfiguration and password unlocking were not performed against the user's active session. These controls use real backends, but their disruptive hardware paths remain untested. Weather and external calendar events are optional and were not enabled.

Evidence: `smoke-results.json`, `layout-results.json`, `desktop-entry-results.json`, `region-results.json`, `deployment-results.json`, actual screenshots and `tests/restore.py`. Hyprland configuration validation, shell syntax and JSON parsing passed; the final runtime log contains no QML errors, type errors or binding loops.

## Settings and animation revision

The new seven-category Settings window was opened through every category and confirmed to be a floating native Wayland toplevel. Real left-clicks on Wi-Fi/Bluetooth tile bodies opened dedicated lists. Opening Wi-Fi preserved radio state. The actual Browse button opened a file dialog; entering a local filename with spaces and # applied the image. Original wallpaper/theme choices were restored after QA.

Start closing was observed to retain its surface while the reverse animation runs, then release it. Real taskbar and Start pins persisted through a shell restart. A disposable terminal confirmed Super+Q closes the focused window. Right-click in All Apps exposed the native Metro context menu. Hover tooltips were removed from shell taskbar/tray controls, and clock/notification/settings controls have fixed reserved widths. All 12 aspect/scale checks and the broader live smoke suite passed again. `tests/personalization.py` additionally verifies canonical desktop IDs, encoded image URLs and rejection of invalid image files in an isolated home. Additional evidence: `revision-results.json` and the Settings application screenshot.

## Wallpaper palette, languages and editable Start revision

Automatic wallpaper-derived dark/light palettes apply to Quickshell, Hyprland borders, GTK3/GTK4 including libadwaita, and Kitty. Isolated tests check minimum 4.5:1 body/muted/accent text contrast, ANSI foreground colors, preserved user CSS and Kitty keybinds/fonts/modes, unrestricted accent HEX values and rejection of invalid images. Generated CSS was parsed by the installed GTK3 and GTK4 providers before INSTALL. Settings offers a native free color picker; choosing manual colors disables automatic palette generation.

Actual left-button gestures moved a tile and resized it to each of 1×1, 2×1, 1×2 and 2×2. Stable tile IDs and all other tiles were retained. Mouse wheel over Start opens All Apps. The Daily label is hidden and the taskbar Start symbol is an original Linux penguin SVG. The position/size transitions run over 180 ms; Start retains its staggered Metro entrance and faster closing.

Every one of nine Settings categories opened successfully. Real language buttons changed the interface and floating-window title to English and back to Russian. Keyboard layout remains independent. Entering a local image path changed the lock background without changing desktop wallpaper and produced a valid hyprlock PNG. Choosing desktop wallpaper changed GTK/Kitty colors to the derived palette. The actual color button opened ColorDialog; an arbitrary #decade value applied through the HEX field. QA restored the user's wallpaper, tile positions, colors, language and lock image afterward.

The final full smoke suite passed, with both monitors unchanged, three tray items, 113 desktop entries, 15 configured tiles, registered Polkit/notifications and all user services active. Measured shell plus metrics idle load was 0.6% of one CPU core over a 10-second interval. Source/recovery tests include runtime-generated file history: these files are recognized and safely quarantined when restoring a pre-install snapshot. The original baseline restore.sh passed dry-run with display and Hyprland variables unset. New evidence: personalization-results.json, tests/palette_layout.py, tests/restore.py, and the language screenshot.

The isolated uninstall rehearsal also passed: generated GTK sections and the Kitty include were detached, later user font/keybind changes survived, owned files were quarantined, and all backups plus the emergency command remained.
