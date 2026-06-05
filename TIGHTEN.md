# Tightening Log

Goal: keep this as a small script-plus-Fortran legacy workflow that can be
pointed at an input catalog and regenerate the established
`/Users/jdsimon/mermaid/cfneic` outputs without changing the products.

## Ordered Work

- [x] Add a one-command regression target.
- [x] Make `run_cfneic` the only blessed run path.
- [x] Add wrapper preflight and dry-run.
- [x] Clarify and preserve `neic.csv` header behavior.
- [x] Remove `cfneic` shell `call system` dependencies carefully.
- [x] Improve `rdGPS` failure signaling.
- [x] Clean up fixed limits without changing algorithms.
- [x] Improve date-limit diagnostics.
- [x] Tighten `tomocat.txt` parsing assumptions.
- [x] Simplify the build surface.

## Log

- 2026-06-05: Starting from a clean `dev` worktree at version `0.3.3`.
- 2026-06-05: The governing constraint is byte-for-byte equivalence with the
  current regression references unless a change is only a diagnostic or
  documentation improvement.
- 2026-06-05: Added `verify_run1` plus `make verify-run1`. The script compares
  exact core products and representative rdGPS outputs; `out.rdGPS*` bodies are
  compared after line 1 because line 1 intentionally embeds the input path.
- 2026-06-05: Simplified README around the normal path: arrange flat inputs,
  run `make`, run `run_cfneic`, and use `make verify-run1`. `rdGPS_all` is now
  explicitly legacy context rather than a recommended path.
- 2026-06-05: Added `run_cfneic --dry-run` and an always-on preflight. Dry-run
  against `/Users/jdsimon/mermaid/cfneic/inputs` created no output directory.
- 2026-06-05: Preserved legacy NEIC first-line behavior. The baseline
  `neic.csv` has no header, but `cfneic` historically skips the first generated
  `neic.txt` row. Fixing that changes `log.cfneic_run1`, so this pass keeps the
  behavior and reports it during preflight.
- 2026-06-05: Preflight showed one intentional filename fallback:
  `452.112-N-03_geo_DET.csv` has no station value in the first usable
  measurement row and maps to `GPS.03` from the filename.
- 2026-06-05: Moved `neic.txt` and `dumgps` generation from `cfneic` to
  `run_cfneic`; `cfneic` now consumes wrapper-generated support files. The
  wrapper still uses the same `awk` field extraction for `neic.txt` to preserve
  exact baseline text.
- 2026-06-05: `rdGPS` now exits nonzero for fatal input errors. Header-only GPS
  files remain normal outputs so `run_cfneic` can keep moving them to
  `empty_gps/` as before.
- 2026-06-05: First `make verify-run1` showed `GPS.43` has a known blank
  station row. Treating that as fatal stops a baseline-equivalent run, so
  missing station rows remain recoverable diagnostics while missing files,
  missing headers, missing required columns, and numeric format errors stay
  fatal.
- 2026-06-05: Kept `MAX_FLOATS=100` and `MAX_SURFACINGS=600` to avoid an
  unnecessary capacity change, but gave the limits names and clearer diagnostics.
- 2026-06-05: Improved date-limit diagnostics in `timedel.f90` without changing
  date math. Future catalogs past 2037 still need a real date routine update.
- 2026-06-05: Added a `tomocat.txt` data-row length guard at 530 characters,
  matching the latest fixed column read (`line(519:530)`). Baseline rows are
  638 characters.
- 2026-06-05: Removed the Makefile `install` target. Normal operation is now
  `make`, `./run_cfneic`, and `make verify-run1`; binaries are not installed
  into the data root.
- 2026-06-05: `make verify-run1` passed after the `GPS.43` exit-status
  refinement. Verified exact core products, `neic.txt`, `dumgps`,
  representative `GPS/path` files, representative `out.rdGPS*` bodies, active
  GPS count, and absence of `rdgps_inputs`.
- 2026-06-05: Bumped patch version to `0.3.4` for the tightening pass.
