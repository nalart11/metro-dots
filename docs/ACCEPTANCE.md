# Acceptance report — 28 September 2026

Deployed on the existing Arch Linux / Hyprland 0.55.4 Lua session. Quickshell was chosen because this installed build exposes native NetworkManager, BlueZ, PipeWire, tray, notifications, Polkit and Hyprland models. Waybar would require a second implementation for the full-screen Start and Charms; AGS would replace an already installed and working runtime.

## Safety and recovery

- Verified original snapshot: `2026-09-28_18-25-33` (47,240 entries).
- Verified baseline immediately before first installation: `2026-09-28_18-44-08` (47,241 entries). `hypr-win8-rollback --latest` selects this snapshot after subsequent updates.
- Full home-relative copies, SHA256 files, entry manifests, package lists, symlink targets and modes retained. Kvantum's existing root-owned directory is unchanged; its original UID/GID are recorded separately because an unprivileged copy cannot acquire UID 0.
- Latest installed transaction `2026-09-28_19-48-55` completed PRECHECK through POSTCHECK; all 29 deployed file hashes match its manifest. Every deployment and update created a new verified snapshot before changing managed files.
- Standalone rollback was verified with graphical environment variables empty. Actual restore was exercised in an isolated fixture: original file contents, executable mode, directory mode and symlink returned; extra user files survived; a managed file from a later version was quarantined; current state was backed up first.
- No live full rollback, uninstall, reboot, shutdown or logout was executed. The graphical session and both original monitor modes/positions/scales remain intact.

## Functional checks

| Requirement | Result and evidence |
| --- | --- |
| Full-screen Start on Super; configurable Metro tiles | Passed real key input; 14 loaded tiles, battery tile hidden on this desktop |
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
