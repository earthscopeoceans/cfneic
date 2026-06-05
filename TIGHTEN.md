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
- 2026-06-05: Full modern rerun into
  `/Users/jdsimon/mermaid/cfneic/outputs/run1` matched all cfneic products,
  all active/empty `GPS.*` products, all `path*.xy` files, and input manifests,
  but found four rdGPS diagnostic-body mismatches.
- 2026-06-05: Fixed the diagnostic mismatches by initializing `gpst1/gpstn` for
  no-data rdGPS outputs (`out.rdGPS03`) and keeping recoverable missing-station
  details in `errors.log` rather than adding new lines to `out.rdGPS43`,
  `out.rdGPS44`, and `out.rdGPS45`.
- 2026-06-05: Expanded `verify_run1` to run the full audit comparison: exact
  cfneic products, exact `neic.txt` and `dumgps`, all active `GPS.*`, all
  `empty_gps/GPS.*`, all `path*.xy`, all `out.rdGPS*` bodies after path-bearing
  line 1, input manifest stability, and absence of `rdgps_inputs`.
- 2026-06-05: Final full rerun under
  `/Users/jdsimon/mermaid/cfneic/outputs/run1` passed 148 comparison checks
  against the legacy top-level references. The run directory contains 42 active
  `GPS.*` files and `empty_gps/GPS.03`, `GPS.44`, and `GPS.45`.
- 2026-06-05: Final `errors.log` catalogs 97 recoverable data issues: 3 missing
  station rows, 3 header-only GPS moves, and 91 P0043 records after the last
  usable GPS. These are diagnostics only; no compared generated product differs.
- 2026-06-05: Removed the user-facing ident/run flag and the `outputs/IDENT`
  layout. `run_cfneic` now writes directly to `<outdir>/outputs` while keeping
  the fixed legacy `run1` filename suffix internally so existing product names
  remain comparable.
- 2026-06-05: `run_cfneic` now removes and recreates `<outdir>/outputs` on
  every non-dry run. Decision: the workflow I/O is small enough that complete
  rewrite is simpler and safer than preserving existing product files. Treat
  `outputs/` as product-only; do not store external analysis, hand-edited files,
  or scratch artifacts there.
- 2026-06-05: Recreated `/Users/jdsimon/mermaid/cfneic/outputs` with the flat
  output layout. Full audit passed 149 checks against the legacy top-level
  references, including the new assertion that no nested `outputs/run1`
  directory remains.
- 2026-06-05: Bumped patch version to `0.3.6` for the no-ident direct-output
  run behavior.
