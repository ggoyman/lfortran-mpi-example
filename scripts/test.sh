#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
case "${1:-}" in
    --help|-h)
        echo 'Usage: scripts/test.sh [--extended]'
        echo 'Default: three scalar interfaces and contiguous use-mpi arrays.'
        echo 'Extended: also test mpi_f08 arrays/sections (known failure at the pin).'
        exit 0 ;;
    ''|--extended) ;;
    *) die 'Usage: scripts/test.sh [--extended]' ;;
esac
load_setup
check_host
need timeout
status=0
run_logged smoke-tests run_toolchain bash "$PROJECT_ROOT/scripts/internal/test.sh" "$@" || status=$?
cat "$LOG_DIR/smoke-tests.log"
exit "$status"
