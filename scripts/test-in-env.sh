#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
: "${CONDA_PREFIX:?Run via scripts/test.sh, inside Pixi}"
ranks="${MPI_TEST_PROCS:-2}"
timeout_seconds="${MPI_TEST_TIMEOUT:-60}"
[[ "$ranks" =~ ^[1-9][0-9]*$ ]] || die 'MPI_TEST_PROCS must be positive.'
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || die 'MPI_TEST_TIMEOUT must be positive.'
export LD_LIBRARY_PATH="$MPI_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$BUILD_DIR/tests" "$WORK_DIR/results"
cd "$BUILD_DIR/tests"
{
    printf 'LFortran source: '
    git -C "$LF_SOURCE" rev-parse HEAD
    "$PIXI_BIN" --version
    "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-cc" --version | head -1
    "$LF_PREFIX/bin/lfortran" --version
    "$MPI_PREFIX/bin/mpichversion"
    "$FORTRAN_PREFIX/bin/mpifort" -show
} > "$WORK_DIR/results/versions.txt"
printf 'interface\tcompile\trun\tranks\n' > "$WORK_DIR/results/smoke.tsv"
for interface in mpifh mpi mpi_f08; do
    run_logged "smoke-$interface-compile" "$FORTRAN_PREFIX/bin/mpifort" \
        "$PROJECT_ROOT/examples/$interface.f90" -o "smoke-$interface"
    run_logged "smoke-$interface-run" timeout "$timeout_seconds" \
        "$MPI_PREFIX/bin/mpiexec" -n "$ranks" "./smoke-$interface"
    observed=$(grep -Ec "of[[:space:]]+$ranks[[:space:]]+sum" \
        "$LOG_DIR/smoke-$interface-run.log" || true)
    [[ "$observed" = "$ranks" ]] || die "Expected $ranks rank reports for $interface; found $observed."
    printf '%s\tPASS\tPASS\t%s\n' "$interface" "$ranks" >> "$WORK_DIR/results/smoke.tsv"
done
cat "$WORK_DIR/results/smoke.tsv"
echo 'All interfaces compiled and passed the MPI reduction check.'
