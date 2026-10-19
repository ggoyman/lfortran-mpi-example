# Upstream sources and dependency notes

- LFortran: <https://github.com/lfortran/lfortran>, BSD 3-Clause license.
  The recipe uses its own `pixi.toml` and build tasks at the pinned revision.
- MPICH: <https://www.mpich.org/>, distributed under its upstream BSD-style
  license. The two release archives are downloaded from the official server;
  their license and copyright files remain with those sources.
- Pixi: <https://github.com/prefix-dev/pixi>. Install Pixi before running the
  example; the scripts do not install it globally.
- `config/pixi.lock` is an unmodified generated lock snapshot from the tested
  LFortran workspace. It records exact package URLs and hashes, not vendored
  package binaries. Dependencies retain their respective licenses.

Source revisions and archive hashes are centralized in `config/versions.env`.
Fortran module files and built libraries are generated locally under `.work/`
and are excluded from version control.
