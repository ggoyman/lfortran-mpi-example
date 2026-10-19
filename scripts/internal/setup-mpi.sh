#!/usr/bin/env bash
# Runs in the selected toolchain: pinned Pixi, or the caller's environment.
set -euo pipefail
source "$(dirname "$0")/../common.sh"
for command in make python3 sha256sum readlink cmp; do need "$command"; done
LF_EXE=$(resolve_executable "$LF_EXE")
if [[ "$MODE" = pinned ]]; then
    CC_EXE="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-cc"
else
    CC_EXE=$(resolve_executable "${CC:-cc}")
fi
prepare_dirs
source "$PROJECT_ROOT/scripts/internal/validate.sh"
run_logged compiler-check check_compiler
if [[ "$EXTERNAL_BACKEND" = 1 ]]; then
    [[ -d "$BACKEND_PREFIX" ]] || die "MPI_BACKEND does not exist: $BACKEND_PREFIX"
    BACKEND_PREFIX=$(cd "$BACKEND_PREFIX" && pwd -P)
    BACKEND_LIBDIR=''
    for directory in lib lib64; do
        if [[ -f "$BACKEND_PREFIX/$directory/libmpi_abi.so" ]]; then
            BACKEND_LIBDIR="$BACKEND_PREFIX/$directory"
            break
        fi
    done
    [[ -n "$BACKEND_LIBDIR" ]] || die 'MPI_BACKEND needs a shared libmpi_abi.so in lib/ or lib64/.'
else
    BACKEND_LIBDIR="$MPI_PREFIX/lib"
fi
save_configuration
rm -f "$WORK_DIR/setup-complete"

if [[ "$EXTERNAL_BACKEND" = 0 ]]; then
    mkdir -p "$BUILD_DIR/mpi-backend"
    cd "$BUILD_DIR/mpi-backend"
    if [[ ! -f Makefile ]]; then
        run_logged backend-configure "$MPI_SOURCE/configure" \
            --prefix="$MPI_PREFIX" --libdir="$MPI_PREFIX/lib" \
            --disable-fortran --disable-cxx --enable-mpi-abi \
            --with-device=ch3:sock --with-hwloc=embedded \
            CC="$CC_EXE" CFLAGS='-O2 -fPIC'
    fi
    run_logged backend-build make -j"$JOBS"
    run_logged backend-install make install
fi
run_logged backend-check check_backend
mkdir -p "$BUILD_DIR/mpi-bindings"
cd "$BUILD_DIR/mpi-bindings"
wrapper_ldflags="-Wl,-rpath,$BACKEND_LIBDIR"
if [[ "$BACKEND_PREFIX" != "$MPI_PREFIX" ]]; then
    wrapper_ldflags="-L$BACKEND_LIBDIR $wrapper_ldflags"
fi
run_logged bindings-configure env \
    main_top_srcdir="$FORTRAN_SOURCE" \
    MPICH_MPIFORT_FCFLAGS="$USER_FCFLAGS" \
    MPICH_MPIFORT_LDFLAGS="$wrapper_ldflags" \
    "$FORTRAN_SOURCE/configure" \
    --prefix="$MPI_PREFIX" --libdir="$MPI_PREFIX/lib" \
    --with-mpi="$BACKEND_PREFIX" --enable-mpi-abi --with-wrapper-dl-type=none \
    --disable-shared --enable-static \
    CC="$CC_EXE" FC="$LF_EXE" \
    CFLAGS='-O2 -fPIC' CPPFLAGS="-DMPI_ABI -I$LF_C_INCLUDE_DIR" \
    LDFLAGS="-L$BACKEND_LIBDIR -Wl,-rpath,$BACKEND_LIBDIR" FCFLAGS="$BUILD_FCFLAGS"

# Scope fixed-form parsing to the single legacy object, including during install.
printf '\nmpif_h/setbotf.lo: FFLAGS += --fixed-form\n' >> Makefile
run_logged bindings-build make -j"$JOBS"
run_logged bindings-install make install
"$MPI_PREFIX/bin/mpifort" -show > "$WORK_DIR/results/mpifort.txt"
touch "$WORK_DIR/setup-complete"
