#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
for command in curl tar sha256sum; do need "$command"; done
prepare_dirs
mkdir -p "$WORK_DIR/downloads"
if [[ "$MODE" = pinned ]]; then
    need git
    need "$PIXI_BIN"
    verify_sha256 "$PROJECT_ROOT/config/pixi.lock" "$PIXI_LOCK_SHA256"
    if [[ ! -d "$LF_SOURCE/.git" ]]; then
        [[ ! -e "$LF_SOURCE" ]] || die "$LF_SOURCE exists but is not a Git checkout."
        run_logged fetch-lfortran git clone --no-checkout --single-branch --branch main \
            "$LFORTRAN_REPOSITORY" "$LF_SOURCE"
        run_logged checkout-lfortran git -C "$LF_SOURCE" checkout --detach "$LFORTRAN_COMMIT"
    else
        [[ "$(git -C "$LF_SOURCE" rev-parse HEAD)" = "$LFORTRAN_COMMIT" ]] ||
            die 'Existing LFortran checkout differs from the pin; use a fresh MPI_WORK_DIR.'
    fi
    cp "$PROJECT_ROOT/config/pixi.lock" "$LF_SOURCE/pixi.lock"
fi
download_source() {
    local name="$1" checksum="$2" archive
    archive="$WORK_DIR/downloads/$name.tar.gz"
    if [[ ! -f "$archive" ]]; then
        run_logged "download-$name" curl --fail --location --retry 3 \
            "https://www.mpich.org/static/downloads/$MPI_RELEASE/$name.tar.gz" --output "$archive.part"
        verify_sha256 "$archive.part" "$checksum"
        mv "$archive.part" "$archive"
    fi
    verify_sha256 "$archive" "$checksum"
    [[ -d "$SOURCE_DIR/$name" ]] || tar -xzf "$archive" -C "$SOURCE_DIR"
}
if [[ "$EXTERNAL_BACKEND" = 0 ]]; then download_source "mpich-$MPI_RELEASE" "$MPI_ARCHIVE_SHA256"; fi
download_source "mpich-fortran-$MPI_RELEASE" "$FORTRAN_ARCHIVE_SHA256"
