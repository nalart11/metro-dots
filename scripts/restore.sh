#!/usr/bin/env bash
set -euo pipefail
snapshot_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -d "$snapshot_dir/backup" && -f "$snapshot_dir/inventory.json" ]] || { echo 'Backup missing' >&2; exit 1; }
exec python3 "$snapshot_dir/snapshot.py" restore "$snapshot_dir" "$@"
