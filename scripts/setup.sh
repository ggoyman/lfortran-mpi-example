#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
case "${1:-}" in
    --help|-h)
        cat <<'EOF'
Usage: [JOBS=2] ./scripts/setup.sh
       LFORTRAN=/path/to/lfortran ./scripts/setup.sh

Default: build the pinned compiler with Pixi, then MPI and its Fortran bindings.
LFORTRAN: use an existing compiler and the C toolchain already active on PATH.
MPI_BACKEND=/prefix: optionally reuse a standard-ABI MPI backend (read-only).
MPI_WORK_DIR=/absolute/path: use separate generated state for another setup.
EOF
        exit 0 ;;
    '') ;;
    *) die 'Usage: scripts/setup.sh [--help]' ;;
esac
check_host
prepare_dirs
"$PROJECT_ROOT/scripts/internal/fetch.sh"
if [[ "$MODE" = pinned ]]; then
    if [[ -f "$LF_BUILD/CMakeCache.txt" ]]; then
        grep -Fqx "CMAKE_INSTALL_PREFIX:PATH=$LF_PREFIX" "$LF_BUILD/CMakeCache.txt" ||
            die 'Build prefix changed; use a fresh MPI_WORK_DIR.'
        run_logged lfortran-build pixi_run rebuild
    else
        run_logged lfortran-build pixi_run build "-DCMAKE_INSTALL_PREFIX=$LF_PREFIX"
    fi
    run_logged lfortran-install pixi_run cmake --install "$LF_BUILD"
fi
run_toolchain bash "$PROJECT_ROOT/scripts/internal/setup-mpi.sh"
echo 'Setup complete. Run ./scripts/test.sh to compile and launch the examples.'
