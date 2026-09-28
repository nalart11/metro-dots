#!/usr/bin/env bash
set -euo pipefail
base="$HOME/.local/share/hypr-win8-backups"
mapfile -t snapshots < <(find "$base" -mindepth 2 -maxdepth 2 -name VERIFIED -printf '%h\n' | sort -r)
((${#snapshots[@]})) || { echo 'No verified backups found' >&2; exit 1; }
if [[ ${1:-} == --latest ]]; then
    chosen=''
    for s in "${snapshots[@]}"; do
        if [[ ! -f "$s/backup/.config/hypr-win8/installed" ]] && python3 -c 'import json,sys;sys.exit(json.load(open(sys.argv[1]))["kind"] not in ("original","install"))' "$s/paths.json"; then chosen=$s; break; fi
    done
    [[ -n $chosen ]] || { echo 'No pre-install backup found' >&2; exit 1; }
else
    for i in "${!snapshots[@]}"; do printf '%d  %s\n' "$((i+1))" "${snapshots[i]##*/}"; done
    read -r -p 'Snapshot number (0 cancels): ' number
    [[ $number =~ ^[1-9][0-9]*$ ]] && ((number<=${#snapshots[@]})) || exit 0
    chosen=${snapshots[number-1]}
    sed -n '1,/All saved entries:/p' "$chosen/manifest.txt"
    read -r -p "Restore ${chosen##*/}? Type RESTORE: " answer
    [[ $answer == RESTORE ]] || exit 0
fi
exec bash "$chosen/restore.sh" "${@:2}"
