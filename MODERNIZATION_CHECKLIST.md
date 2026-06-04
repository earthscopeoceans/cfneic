# Modernization Checklist

Use this as a working checklist. Keep each step small enough to verify against the current successful run products in `/Users/jdsimon/mermaid/cfneic`.

## Baseline And Build

- [x] Capture a regression baseline from the current successful run: file counts, output checksums, and a few representative numeric comparisons.
- [x] Add a small build script or Makefile that preserves the current compile commands and source order.
- [x] Record the exact compiler/version and platform used for the baseline.

## Input Paths And Run Orchestration

- [x] Remove the hard-coded `rdGPS` root by accepting a CLI argument or environment variable.
- [x] Keep `/Users/jdsimon/mermaid/cfneic` available as a temporary default until the new flow is verified.
- [x] Add a run wrapper that accepts input root, output directory, and `ident`.
- [x] Make the wrapper run the current `rdGPS_all` behavior without requiring manual executable/data copying.
- [x] Handle empty GPS files explicitly, rather than requiring manual moves to `empty_gps`.
- [x] Keep output and temp files in predictable run-specific locations to avoid accidental overwrites.

## `geo_DET.csv` Parsing

- [x] Identify the exact required fields from `geo_DET.csv`: method, start time, station, latitude, longitude, and water pressure.
- [x] Replace positional `geo_DET.csv` parsing with header-name lookup.
- [x] Ignore extra columns such as `DataQuality` and `SampleCount`.
- [x] Validate required columns and fail with a useful error when missing.
- [x] Preserve output equivalence for known-good GeoCSV v2.2.0-1 inputs.
- [x] Add at least one fixture or copied sample representing the expanded `geo_DET.csv` layout.

## `cfneic` Inputs And Outputs

- [x] Document required `cfneic` inputs: `tomocat.txt`, `neic.csv`, `ehb.hdf`, and `GPS.*`.
- [ ] Preserve the current `run1` outputs as regression references.
- [ ] Confirm behavior when `neic.csv` has or lacks a header.
- [ ] Consider replacing shell-generated `neic.txt` and `dumgps` with direct Fortran or wrapper-managed files.
- [x] Make all generated filenames run-specific or output-directory-specific.

## Fragility Cleanup

- [ ] Replace shell `grep`/`sed -i` preprocessing in `rdGPS` or isolate it in a portable wrapper.
- [ ] Avoid relying on `line(13:15)` to identify measurement type.
- [ ] Review fixed-size strings and line lengths before expanded text files are introduced.
- [ ] Review fixed limits such as `NF=100` and `NS=600`.
- [ ] Review date limits in `timedel.f90` if future catalogs can exceed year 2099.

## Future Output Curation Package

- [ ] Decide what products are authoritative outputs of this workflow.
- [ ] Define the schema for curated downstream outputs.
- [ ] Decide whether the downstream package reads `out.cfneic_*`, `hypos_*`, `missed_events_*`, `log.cfneic_*`, or a new normalized output format.
- [ ] Defer direct Python wrapping of the Fortran workflow unless there is a clear need.
