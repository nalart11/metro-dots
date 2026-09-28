#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
printf '%s\n' '1. Disable Win8 integration and quarantine unchanged installed files' '2. Restore latest pre-install configuration' '3. Cancel'
read -r -p 'Choose [3]: ' choice
case ${choice:-3} in
    1) exec python3 "$project_dir/scripts/uninstall.py" ;;
    2) exec bash "$project_dir/rollback.sh" --latest ;;
    *) exit 0 ;;
esac
