#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
check_host
prepare_dirs
require_sources
[[ -x "$FORTRAN_PREFIX/bin/mpifort" ]] || die 'Build the bindings first.'
[[ -x "$MPI_PREFIX/bin/mpiexec" ]] || die 'Build the C MPI backend first.'
need timeout
run_logged smoke-tests pixi_run bash "$PROJECT_ROOT/scripts/test-in-env.sh"
cat "$LOG_DIR/smoke-tests.log"
