#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Apply locally reviewed Git changes. No remote code is fetched or executed implicitly.
exec bash "$project_dir/install.sh" --kind update "$@"
