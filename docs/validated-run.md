# Validated build

Validated on **2026-10-19**, on Linux x86_64 (openSUSE Tumbleweed, glibc 2.43).
The build used two parallel jobs and the pins committed in this repository.

| Component | Observed version |
| --- | --- |
| Pixi | 0.82.0 |
| C compiler from Pixi | conda-forge GCC 15.3.0-7 |
| LFortran source | `d9048e2e6e15b753c3da5e15d55c80f614cdba39` |
| Installed LFortran | `0.67.0-965-gd9048e2e6e` |
| LLVM | 11.1.0 |
| C-only MPICH | 5.1.0a1, MPI ABI 1:0:0, `ch3:sock` |
| Standalone MPICH Fortran bindings | 5.1.0a1, static library |

## What was exercised

Starting with an empty `.work/` directory, the scripts downloaded the pinned
sources, verified the archive and dependency-lock hashes, created a new Pixi
environment, and built and installed all three components. No previously built
LFortran or MPI installation was reused.

All three examples compiled and ran with two local MPI ranks. Each process
contributed its rank to `MPI_Allreduce`; both processes reported the expected
sum of 1. The runner also checked the number of rank reports and communicator
size.

| Fortran interface | Compile | Two-rank run |
| --- | --- | --- |
| `include 'mpif.h'` | PASS | PASS |
| `use mpi` | PASS | PASS |
| `use mpi_f08` | PASS | PASS |

After the initial build, the complete `scripts/reproduce.sh` workflow was rerun
successfully with the existing build directories. It exercised the incremental
LFortran build, backend installation, binding regeneration/build/installation,
and all three smoke tests.

The documented `bin/lfortran`, `bin/mpifort`, and `bin/mpiexec` helpers were also
checked: they reported the compiler version, compiled `examples/mpi_f08.f90`,
and ran it successfully with two ranks from the repository root.

## Reproduce the evidence

From a fresh checkout, with Pixi on PATH:

```bash
JOBS=2 ./scripts/reproduce.sh
```

The workflow records the actual compiler versions, backend configuration, and
`mpifort` command in `.work/results/versions.txt`. The machine-readable test
summary is `.work/results/smoke.tsv`. Full build and per-interface compile/run
logs are in `.work/logs/`.

This validates the configuration and these smoke programs on the recorded host.
It does not establish full MPI conformance, other backends, or multi-node
operation. The scripts apply no LFortran or MPICH source patches.
