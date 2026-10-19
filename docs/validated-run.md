# Validated runs

Validated on **2026-10-19**, Linux x86_64 (openSUSE Tumbleweed, glibc 2.43).
All source and dependency pins are unchanged from the original example.

| Component | Observed version |
| --- | --- |
| Pixi | 0.82.0 |
| C compiler | conda-forge GCC 15.3.0-7 |
| LFortran source | `d9048e2e6e15b753c3da5e15d55c80f614cdba39` |
| Installed LFortran | `0.67.0-965-gd9048e2e6e` |
| LLVM | 11.1.0 |
| C-only MPICH | 5.1.0a1, MPI ABI 1:0:0, `ch3:sock` |
| Standalone Fortran bindings | 5.1.0a1, static library |

## Simplified setup

The pinned compiler was rebuilt incrementally in its existing Pixi environment.
The C backend and Fortran bindings were built in fresh build directories and
installed into the new shared `.work/install/mpi/` prefix. Compiler preflight
and a C MPI standard-ABI reduction passed. The host's `/tmp` quota interrupted
the C build once; it resumed successfully with `TMPDIR` inside the checkout.

A second, initially empty work directory exercised the optional existing
compiler/backend mode. It reused the same installed LFortran and C backend,
downloaded only the standalone binding archive, and built a separate Fortran
installation. No LFortran or MPICH C-backend source checkout was created in
that work directory. The external backend was not installed into or modified.

| Normal test | Pinned setup, 2 ranks | Existing components, 2 ranks |
| --- | --- | --- |
| `mpifh` | PASS | PASS |
| `mpi` | PASS | PASS |
| `mpi_f08` | PASS | PASS |
| `mpi_arrays` | PASS | PASS |

The array test checks a contiguous broadcast and an elementwise reduction.
Programs validate their results; the runner also checks rank reports and
communicator size. The helper compiler/launcher commands were exercised after
unsetting `LFORTRAN` and `MPI_BACKEND`, confirming that the saved selection is
used. Invalid compiler identity and reuse of a work directory with another
toolchain mode were rejected without replacing the completed installation.

Finally, the complete `scripts/reproduce.sh` workflow was rerun successfully.
It rebuilt the compiler incrementally, reinstalled the backend into the merged
prefix, regenerated/rebuilt/reinstalled the bindings, and passed all four normal
tests again. This checks that rerunning the C installation preserves a usable
combined installation after the Fortran stage completes.

## Wrapper-flag experiments

These were tested sequentially against the original installed bindings:

| Change | Observed result |
| --- | --- |
| Remove user `--implicit-typing` | All three scalar interfaces pass |
| Also remove user `--implicit-interface` | `mpi_f08` passes; `mpif.h` and `use mpi` fail semantic analysis |
| Also remove user `--separate-compilation` | `mpi_f08` fails linking with duplicate module-global symbols |

The installed wrapper therefore supplies `--cpp --separate-compilation`.
Legacy examples request `--implicit-interface` explicitly. The full legacy
flag set remains internal to the binding build.

The new target-specific fixed-form assignment compiled `setbotf.f` successfully
without a command-line override of global `FFLAGS`. No upstream source patch
was applied. After prefix unification, `mpifort -show` has one library search
directory supplied by the wrapper, plus a correctly forwarded MPI rpath; the
former extra backend `-L` is gone in the default mode.

## Additional configuration probes

The working installation was left intact during these separate experiments.

| Change | Observed result | Decision |
| --- | --- | --- |
| Omit `--with-hwloc=embedded` | Configure passes and chooses embedded hwloc on this host | Keep explicit selection for the pinned recipe |
| Omit `--with-device=ch3:sock` | Configure passes and chooses `ch4:ofi` | Keep the backend already built and runtime-tested |
| Omit static-only binding options | Configure passes; shared-library link fails | Retain static Fortran bindings |

The first two probes covered configuration only, not backend build/runtime.
The default shared build failed when libtool passed driver options LFortran
does not accept:

```text
The following arguments were not expected:
-soname -rpath -rpath -rpath --no-whole-archive --whole-archive -shared
```

This does not establish that shared libraries are impossible with a different
link recipe; it explains why the example retains its tested static recipe.

## Known array-descriptor limitation

`test.sh --extended` recorded four passing normal tests and a compile PASS /
runtime FAIL for `mpi_f08_arrays`, then returned nonzero. The smaller
`reproducers/mpi_f08_bcast.f90` also compiled, passed with one rank, and crashed
with two ranks (exit 139). The same failure was observed with the original
installation before the refactor. See [the reproducer and stack trace](array-blocker.md).

Strided arguments through the legacy `use mpi` interface also failed an
exploratory check. Neither that case nor `mpi_f08` array descriptors are part
of the passing smoke-test claim. The full MPICH test suite, multi-node runs,
other operating systems, and other backend versions have not been validated.

## Reproduce the evidence

```bash
./scripts/setup.sh
./scripts/test.sh
./scripts/test.sh --extended
```

The last command intentionally includes an observed failure at the pin; it
does not classify that failure as a passing expected-failure test. Normal and
extended summaries are written separately to `.work/results/smoke.tsv` and
`.work/results/extended.tsv`. Versions and configuration are recorded in
`.work/results/versions.txt`; the wrapper command is in `mpifort.txt` there.
Phase logs and per-test compile/run output are in `.work/logs/`.

The original three-prefix workflow is preserved in Git at commit `d94338d`.
It was validated from an empty `.work/`: sources and dependencies were fetched,
all three components were built, and the three scalar interfaces passed with
two ranks. That original workflow was also rerun successfully. The current
`scripts/reproduce.sh` retains the one-command pinned setup-and-test interface.
