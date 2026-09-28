# Hyprland Windows 8 dots

Metro desktop for this Arch Linux / Hyprland 0.55.4 Lua installation. Straight edges, solid colors, full-screen Start, horizontal tile groups and a left-aligned taskbar. Quickshell provides the UI; recovery uses Bash, Python 3 and coreutils without a graphical session.

## Screenshots

![Start Screen](docs/screenshots/start.png)

Screenshots are from the actual session. Wallpapers and the four-panel Start symbol are original procedural SVG designs. Application icons come from installed icon themes.

## Features

Start, 1×1/2×1/2×2 tiles, live clock/system/network/music/calendar, All Apps, search, running windows, pinned apps, per-monitor workspaces, status notifier tray, Charms, PipeWire volume and output selection, NetworkManager Wi-Fi, BlueZ devices, notifications/history/DND, OSD, hyprlock, power confirmation, clipboard history and screenshots. Battery and backlight controls appear only when available. Optional weather and external calendars are intentionally absent: no accounts or unreliable scraping are assumed.

The switcher uses titles instead of compositor previews. Select a window, press Enter or release Alt. Super+Tab opens the workspace selector. Semantic zoom changes tile density with the Groups button. Wallpapers fill each monitor separately. Overlays select the focused monitor.

## Dependencies

Already installed: Hyprland, Quickshell (this machine's 0.2.1 fork with `Quickshell.Networking`), Qt Quick Controls, Python, python-gobject, coreutils, kitty, hyprlock, hypridle, PipeWire/WirePlumber, NetworkManager, BlueZ, blueman, hyprsunset, brightnessctl, cliphist, wl-clipboard, grim, slurp, libnotify. Git maintains only this new project. Adwaita Sans is the installed open-source sans-serif font; theme.json can select Inter if installed.

No packages were needed for the initial deployment. The installer checks commands before package installation and uses one explicit `sudo pacman -S --needed` operation if official dependencies are missing. AUR installation is never implicit. This project targets the installed Lua include topology and refuses unknown main-config structures or managed symlink paths.

## Installation

```bash
cd ~/.local/share/hypr-win8-dots
./install.sh --no-packages --restore-on-error
```

Stages: PRECHECK → BACKUP → VERIFY_BACKUP → GENERATE_CONFIG → VALIDATE_CONFIG → INSTALL → RELOAD → POSTCHECK. Generated configuration is validated in a new directory beneath `~/.cache/hypr-win8-build/`. Before INSTALL, existing dotfiles are untouched. After INSTALL, `--restore-on-error` restores the verified transaction snapshot automatically. Without that flag, an interactive terminal offers recovery and prints the standalone command. Packages, if needed, are outside the dotfile rollback; they are not automatically removed.

The original Hyprland files remain in place. Only the main Lua entrypoint changes its shell autostart and final appearance include; a new `win8` module applies overrides. Original monitors, NVIDIA environment, input, custom rules and window/workspace binds remain included. Services are started by the session autostart hook, without modifying global system services or terminating the current session.

## Dry run

```bash
./install.sh --dry-run
```

Lists backup paths, managed files, missing packages and user services. Creates no files, backups or logs and performs no package/service actions.

## Configuration

`~/.config/hypr-win8/theme.json` and `tiles.json` are watched live. `config/` is the source for installed UI files; use `update.sh` after editing project code. Personal theme/tiles edits survive updates. Main Lua config is generated from the current entrypoint, preserving later user changes.

Logs: `~/.local/state/hypr-win8/install.log` and `shell.log`. Diagnostics:

```bash
systemctl --user status hypr-win8-shell.service
journalctl --user -u hypr-win8-shell.service -b
quickshell -c win8 ipc call metro status
hyprctl configerrors
```

## Start Screen

Press Super or click the Start button. Start fills the active monitor. Type to search; Escape closes. All apps opens the desktop-entry catalog. Horizontal scrolling accommodates narrow/scaled monitors. Groups toggles a compact tile view. Launching closes the overlay. Live music tiles toggle playback when supported.

## Tiles

Each JSON tile contains `name`, `group`, `x`, `y`, `w`, `h`, `color` and optionally `icon`, `desktop`, `command` or `action`. Coordinates use grid units; supported sizes are 1×1, 2×1 and 2×2. `command` is an argument array, not a shell string. Desktop IDs use installed `.desktop` entries. `live` supports clock/system/network/music/calendar/battery. The installer rejects overlapping or unsupported tiles. Names, colors and layout are editable independently of the shell.

Applications use the Quickshell desktop catalog for Name/Icon/NoDisplay/Categories/search and Gio.DesktopAppInfo for actual launching. Terminal entries launch through kitty with parsed desktop-field substitutions. Raw Exec strings are never passed to a shell. The explicit `> command` search mode runs a user-entered shell command.

## Theme

`mode` is dark/light. Central keys: background, surface, surfaceSecondary, accent, foreground, muted, danger, success, font, wallpaper. Quick Settings exposes mode and six accent colors. Wallpapers: metro-blue.svg, metro-purple.svg and metro-green.svg under assets/wallpapers. Hyprlock uses the rendered metro-blue.png. Shell theme changes do not modify GTK/Kvantum or the existing terminal configuration.

## Keybinds

| Old bind/action | New bind/action | Reason |
| --- | --- | --- |
| Super: old search | Super: Start | Full-screen launcher |
| Super+C: editor | Super+C: Charms; Super+Shift+C: editor | Required Charms shortcut |
| Super+Q: close | Super+Q: Search; Alt+F4: close | Required search shortcut; conventional close |
| Super+I: old settings | Super+I: Metro Settings | Unified controls |
| Super+L: session lock | Super+L: hyprlock | Independent lockscreen |
| Super+Tab: old overview | Super+Tab: workspace selector | Metro integration |
| Alt+Tab | Alt+Tab: window selector | Stable title-based switching |
| Super+V: old clipboard | Super+V: clipboard history | Same workflow |
| Print: clipboard-only capture | Print: focused-monitor capture, save and copy | Persistent screenshots |
| Super+Shift+S | Same: region, save, copy, notify | Independent screenshot backend |
| Ctrl+Super+R: kill all shells | Restart only Win8 user service | Scoped restart |
| Super+N | Notification center | Same role |
| Ctrl+Alt+Delete | Power menu with confirmation | Same role |

Super+Enter/T, Ctrl+Alt+T, Super+E/W/X, media keys, arrows, numeric workspaces, scratchpad, floating/fullscreen, volume, microphone, custom DPMS and VM submap remain defined by the original modules. Old shell-specific AI/OCR/translation/recording/onscreen-keyboard/family-switch shortcuts are removed where they depend on the old UI. Super+A opens All Apps; Super+B Charms; Super+O workspaces; Super+M audio/settings. The complete original bind list and Lua include inventory live in the initial snapshot and docs/system-manifest.txt.

## Updating

```bash
cd ~/.local/share/hypr-win8-dots
./update.sh --no-packages --restore-on-error
```

Applies locally reviewed project changes, makes a fresh verified backup, stages/validates, installs and restarts. It does not fetch unreviewed code or execute a remote update automatically. Git records source changes independently of installed private dotfiles.

## Backup system

`~/.local/share/hypr-win8-backups/YYYY-MM-DD_HH-MM-SS/` contains backup/, manifest.txt, inventory.json, paths.json, checksums.sha256, package lists, standalone restore.sh, snapshot.py and README.txt. Every install/update uses a new snapshot. Failed, unverified snapshots are never eligible for restoration. Copies use cp -a, preserve symlinks, mode/executable bits and hidden files, and also save home-directory symlink targets. SHA256 checks every regular file; inventory checks structure/modes/link targets. The source inventory is compared again after copying.

A non-owned Kvantum directory cannot have its original UID/GID assigned to a user-created copy. The original ownership is recorded in inventory.json and ownership-differences.json. Its contents and permissions are verified; this desktop does not alter Kvantum. Ownership of an existing original directory is retained on recovery. No sudo is used to change ownership.

## Rollback

```bash
~/.local/bin/hypr-win8-rollback --latest
~/.local/bin/hypr-win8-rollback
```

`--latest` restores the most recent verified state **before Win8 was installed**, skipping snapshots that already contain its installed marker. Interactive mode lists all snapshots, including updates, prints the manifest and asks for RESTORE. Each snapshot also has its own recovery command:

```bash
bash ~/.local/share/hypr-win8-backups/2026-09-28_18-25-33/restore.sh
```

`restore.sh --dry-run` verifies without restoring. Actual recovery first makes a verified pre-rollback snapshot, stops Win8 services, copies original files without following target symlinks, restores modes/links and verifies original entries. User-added files remain. Newly installed, unchanged managed files are moved into the pre-rollback snapshot's quarantine; edited added files are retained. Directory conflicts and changed link types are quarantined. Backups are never removed. Original Quickshell, hypridle and clipboard watchers restart when a graphical session is running; from TTY the next session startup handles them.

## Recovery from broken Hyprland session

Press Ctrl+Alt+F3, log in and run:

```bash
~/.local/bin/hypr-win8-rollback --latest
```

Then start Hyprland again through your usual login method. Recovery needs Bash/Python/coreutils only; it does not require Quickshell, rofi, a user D-Bus session, or a running compositor. If the global command is unavailable, invoke the snapshot's restore.sh directly. `hyprctl reload` is attempted only when the session environment contains a Hyprland instance.

## Removing the rice

```bash
cd ~/.local/share/hypr-win8-dots
./uninstall.sh
```

Choose disable/quarantine Win8 files, restore the original configuration, or cancel. The first option restores the original main entrypoint and preserves current unrelated settings; only unchanged owned files are quarantined. Edited files, this Git project, recovery command and all backup snapshots remain. The second option runs complete rollback. User data and packages are never deleted automatically.
