#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
if [[ -n "${LFORTRAN:-}" || -n "${MPI_BACKEND:-}" ]]; then
    echo 'For external components use setup.sh and test.sh; reproduce.sh uses the source pins.' >&2
    exit 1
fi
"$root/scripts/setup.sh"
"$root/scripts/test.sh"
