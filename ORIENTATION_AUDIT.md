# Orientation Audit

Generated during the initial orientation pass for `/Users/jdsimon/programs/cfneic`.

## Repo Inventory

Tracked files:

- `README`
- `cfneic.f90`
- `rdGPS.f90`
- `mod_ttak135.f90`
- `timedel.f90`
- `rdGPS_all`
- `tobs.info`

Present but ignored or untracked:

- `.gitignore`
- `ttak135.mod`

`ttak135.mod` is a generated Fortran module artifact.

Main roles:

- `cfneic.f90`: main catalog-update program.
- `rdGPS.f90`: converts each float's `geo_DET.csv` into `GPS.NN`, `pathNN.xy`, and `out.rdGPSNN`.
- `mod_ttak135.f90`: `ttak135` module used by `cfneic`.
- `timedel.f90`: date/time/geodesy helper routines.
- `rdGPS_all`: zsh loop over `452*/` float directories.

## Compile Path

Compilation appears manual, from source comments:

- `cfneic`: `gfortran -g -o $root/cfneic mod_ttak135.f90 timedel.f90 cfneic.f90`
- `rdGPS`: `gfortran -g -o $root/rdGPS rdGPS.f90 timedel.f90`

There is no Makefile or build script. Existing run binaries in `/Users/jdsimon/mermaid/cfneic` are Mach-O arm64 executables.

## Current Run Process

The current workflow is centered on `/Users/jdsimon/mermaid/cfneic` as `$root`.

That directory contains 45 top-level float directories like `452.020-P-0047/geo_DET.csv`, plus a duplicate-looking `GeoCSV/` tree with 45 more `geo_DET.csv` directories. The current `rdGPS_all` loop uses only top-level `452*/`, not `GeoCSV/`.

Run sequence appears to be:

1. Compile/copy `rdGPS`, `cfneic`, and `rdGPS_all` into `$root`.
2. From `$root`, run `./rdGPS_all`.
3. From `$root`, run `./cfneic tomocat.txt run1`.

## Working-Directory Assumptions

Hard-coded or assumed files:

- `rdGPS.f90` hard-codes `root = '/Users/jdsimon/mermaid/cfneic/'`.
- `rdGPS` assumes `<root>/<dir>/geo_DET.csv`.
- `rdGPS` writes `dumpgps`, `GPS.NN`, `pathNN.xy`, and `out.rdGPSNN` in the current directory.
- `cfneic` assumes `neic.csv`, `ehb.hdf`, and `GPS.*` exist in the current directory.
- `cfneic` converts `neic.csv` to `neic.txt`, writes `dumgps`, and reads the tomocat file from argv.
- `cfneic` output names depend on `ident`: `out.cfneic_trig_<ident>`, `out.cfneic_int_<ident>`, `hypos_<ident>`, `missed_events_<ident>`, and `log.cfneic_<ident>`.

## Existing Products

In `/Users/jdsimon/mermaid/cfneic`:

- Inputs: `ehb.hdf`, `neic.csv`, `tomocat.txt`, and float `geo_DET.csv` directories.
- Generated GPS products: 42 active `GPS.*` files.
- Empty GPS files moved aside: `empty_gps/GPS.03`, `GPS.44`, `GPS.45`.
- `rdGPS` products: 45 `out.rdGPSNN` files and 45 `pathNN.xy` files.
- `cfneic run1` products: `out.cfneic_trig_run1`, `out.cfneic_int_run1`, `hypos_run1`, `missed_events_run1`, `log.cfneic_run1`, plus generated `neic.txt` and `dumgps`.
- Temporary or remnant files include `dumpgps`, `dumpgps-e`, and `fort.13`.

## Fragile Assumptions

Most fragile spots:

- `geo_DET.csv` parsing is positional and tied to GeoCSV v2.2.0-1. New columns like `DataQuality` and `SampleCount` will likely shift reads.
- `rdGPS` uses shell `grep` and `sed -i`; on macOS this leaves `dumpgps-e`, and behavior may differ elsewhere.
- `rdGPS` checks `line(13:15)` for `GPS` or `Pre`, assuming exact `Measurement:*` prefix placement.
- `cfneic` parses tomocat by fixed character offsets and fixed token counts.
- Catalogs must be chronological.
- Compile order is implicit: `mod_ttak135.f90` must precede `cfneic.f90`.
- Output and temp filenames are fixed in the working directory, so runs can overwrite each other.
- Several fixed limits exist: `NF=100`, `NS=600`, `ident*12`, `dataf*80`, `line*650`, and date routines reject years outside 1900-2099.
- `rdGPS_all` is zsh-specific and derives float id from the last two directory characters.

## Packaging Direction

The initial modernization notes included a possible Python package wrapper. Current preference is likely not to wrap this Fortran workflow directly in Python. A more likely future direction is to keep this workflow focused on producing trusted outputs, then build a separate package that curates, validates, and exposes those outputs.

