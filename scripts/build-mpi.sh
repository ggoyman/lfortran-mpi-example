#!/usr/bin/env bash
# Internal entry point: scripts/build.sh runs this inside Pixi.
set -euo pipefail
source "$(dirname "$0")/common.sh"
: "${CONDA_PREFIX:?Run via scripts/build.sh, inside Pixi}"
cc="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-cc"
fcflags='--cpp --implicit-interface --implicit-typing --separate-compilation'
fflags="$fcflags --fixed-form"
prepare_dirs
case "${1:-}" in
    backend)
        mkdir -p "$BUILD_DIR/backend"
        cd "$BUILD_DIR/backend"
        if [[ ! -f Makefile ]]; then
            run_logged backend-configure "$MPI_SOURCE/configure" \
                --prefix="$MPI_PREFIX" --libdir="$MPI_PREFIX/lib" \
                --disable-fortran --disable-cxx --enable-mpi-abi --with-device=ch3:sock \
                --with-hwloc=embedded \
                CC="$cc" CFLAGS='-O2 -fPIC'
        fi
        run_logged backend-build make -j"$JOBS"
        run_logged backend-install make install
        ;;
    bindings)
        [[ -f "$MPI_PREFIX/lib/libmpi_abi.so" ]] || die 'Build the C MPI backend first.'
        mkdir -p "$BUILD_DIR/bindings"
        cd "$BUILD_DIR/bindings"
        run_logged bindings-configure env \
            main_top_srcdir="$FORTRAN_SOURCE" \
            MPICH_MPIFORT_FCFLAGS="$fcflags" \
            MPICH_MPIFORT_LDFLAGS="-L$MPI_PREFIX/lib -Wl,-rpath,$MPI_PREFIX/lib" \
            "$FORTRAN_SOURCE/configure" \
            --prefix="$FORTRAN_PREFIX" --libdir="$FORTRAN_PREFIX/lib" \
            --with-mpi="$MPI_PREFIX" --enable-mpi-abi --with-wrapper-dl-type=none \
            --disable-shared --enable-static \
            CC="$cc" FC="$LF_PREFIX/bin/lfortran" F77="$LF_PREFIX/bin/lfortran" \
            CFLAGS='-O2 -fPIC' CPPFLAGS="-DMPI_ABI -I$LF_PREFIX/include/lfortran" \
            LDFLAGS="-L$MPI_PREFIX/lib -Wl,-rpath,$MPI_PREFIX/lib" \
            FCFLAGS="$fcflags" FFLAGS="$fcflags"
        run_logged bindings-build make -j"$JOBS" "FFLAGS=$fflags"
        run_logged bindings-install make install "FFLAGS=$fflags"
        ;;
    *) die 'Internal usage: build-mpi.sh [backend|bindings]' ;;
esac
