# Reproduce The Baseline Run From A Fresh Checkout

This guide verifies that a fresh checkout can build the Fortran programs and
produce the same outputs as the frozen legacy-output fixtures in
`tests/fixtures/legacy_outputs/`.

It intentionally does not use `testdata/`.

## 0. Choose Paths

Use paths that do not already exist, especially for `OUT`.

```sh
SOURCE=/Users/jdsimon/programs/cfneic
CLONE=/private/tmp/cfneic-clone-test
LEGACY_INPUT=/Users/jdsimon/mermaid/cfneic
BASELINE=$CLONE/tests/fixtures/legacy_outputs
OUT=/private/tmp/cfneic-clone-run1
INPUT=$OUT/inputs
RUN=$OUT/outputs
LOG=/private/tmp/cfneic-clone-run1.log
```

`LEGACY_INPUT` provides the real input catalog source. `BASELINE` is the frozen
fixture baseline checked into the source tree. `OUT` must be a new run root.
The wrapper reads flat catalogs from `OUT/inputs` and rewrites generated
products in `OUT/outputs`.

## 1. Clone Or Copy The Source

Preferred path, if current work has been committed:

```sh
git clone "$SOURCE" "$CLONE"
cd "$CLONE"
git checkout dev
```

If you need to test uncommitted local edits instead of committed history, use a
snapshot copy:

```sh
mkdir -p "$CLONE"
rsync -a --exclude .git --exclude build "$SOURCE"/ "$CLONE"/
cd "$CLONE"
```

## 2. Confirm The Checkout

```sh
pwd
git status --short --branch 2>/dev/null || true
git rev-parse --short HEAD 2>/dev/null || true
cat VERSION
```

For a committed clone, `git status --short --branch` should show branch `dev`
with no local modifications.

## 3. Confirm Toolchain

```sh
which gfortran
gfortran --version | head -n 1
uname -m
sw_vers
```

Expected baseline compiler/platform are recorded in `REGRESSION_BASELINE.md`.

## 4. Build

```sh
make clean
make
file build/cfneic build/rdGPS
```

Expected result:

- `make` compiles `build/cfneic`
- `make` compiles `build/rdGPS`
- both binaries are Mach-O arm64 executables on the baseline machine

## 5. Inspect Wrapper Help

```sh
./run_cfneic --help
```

The usage should read:

```text
Usage:
  run_cfneic --output-dir DIR [--input-root DIR]
             [--tomocat FILE] [--neic FILE] [--ehb FILE]

Options:
  -i, --input-root DIR   Flat input directory containing *geo*.csv, neic.csv,
                         ehb.hdf, and tomocat.txt.
                         Default: output-dir/inputs
  -o, --output-dir DIR   Run root containing inputs/ and outputs/ subdirs.
                         Generated files go directly to output-dir/outputs.
      --tomocat FILE     tomocat input file. Default: input-root/tomocat.txt
      --neic FILE        NEIC CSV file. Default: input-root/neic.csv
      --ehb FILE         ISC-EHB HDF file. Default: input-root/ehb.hdf
      --dry-run          Show resolved paths and input preflight, then exit.
  -h, --help             Show this help.
```

## 6. Prepare A Flat Input Directory

Create a flat input catalog directory from the known-good legacy tree:

```sh
mkdir -p "$INPUT"
cp "$LEGACY_INPUT"/neic.csv "$INPUT"/
cp "$LEGACY_INPUT"/ehb.hdf "$INPUT"/
cp "$LEGACY_INPUT"/tomocat.txt "$INPUT"/
for d in "$LEGACY_INPUT"/452*/; do
  base=${d%/}
  base=${base##*/}
  cp "$d"/geo_DET.csv "$INPUT"/"${base}_geo_DET.csv"
done
```

## 7. Run Into A New Output Directory

Make sure you do not keep anything except generated workflow products under
`$OUT/outputs`: every run removes and recreates that directory.

If you need to preserve old outputs, move or copy them outside `$OUT/outputs`
before running.

Run:

```sh
./run_cfneic \
  --input-root "$INPUT" \
  --output-dir "$OUT" \
  --dry-run

./run_cfneic \
  --input-root "$INPUT" \
  --output-dir "$OUT" 2>&1 | tee "$LOG"
```

Expected messages may include:

- `Warning: single GPS ignored...`

Recoverable `rdGPS` and `cfneic` data issues are written to
`$RUN/errors.log`. The important success signal is:

```text
Run complete: <your run output dir>
```

## 8. Check Output Inventory

```sh
find "$RUN" -maxdepth 1 -type f -name 'GPS.*' | wc -l
find "$RUN"/empty_gps -maxdepth 1 -type f -name 'GPS.*' -print | sort
find "$RUN" -maxdepth 1 -type f -name 'path*.xy' | wc -l
find "$RUN" -maxdepth 1 -type f -name 'out.rdGPS*' | wc -l
test ! -e "$RUN/rdgps_inputs"
wc -l "$RUN/errors.log"
sed -n '1,20p' "$RUN/errors.log"
```

Expected:

```text
42 active GPS.* files
empty_gps/GPS.03
empty_gps/GPS.44
empty_gps/GPS.45
45 path*.xy files
45 out.rdGPS* files
no rdgps_inputs compatibility directory
errors.log present with recoverable data issues
```

## 9. Compare Core Outputs To Baseline

Compare exact files against the frozen fixture baseline:

```sh
cmp "$RUN/out.cfneic_trig_run1" "$BASELINE/out.cfneic_trig_run1"
cmp "$RUN/out.cfneic_int_run1" "$BASELINE/out.cfneic_int_run1"
cmp "$RUN/hypos_run1" "$BASELINE/hypos_run1"
cmp "$RUN/missed_events_run1" "$BASELINE/missed_events_run1"
cmp "$RUN/log.cfneic_run1" "$BASELINE/log.cfneic_run1"
cmp "$RUN/neic.txt" "$BASELINE/neic.txt"
cmp "$RUN/dumgps" "$BASELINE/dumgps"
```

No output from `cmp` means the files match.

Check representative `rdGPS` products:

```sh
cmp "$RUN/GPS.01" "$BASELINE/GPS.01"
cmp "$RUN/GPS.47" "$BASELINE/GPS.47"
cmp "$RUN/path01.xy" "$BASELINE/path01.xy"
cmp "$RUN/path47.xy" "$BASELINE/path47.xy"
```

No output means they match. `out.rdGPS*` embeds the input path on the first
line, so compare the behavior-bearing diagnostics after that line:

```sh
tail -n +2 "$RUN/out.rdGPS01" > /tmp/out.rdGPS01.new
tail -n +2 "$BASELINE/out.rdGPS01" > /tmp/out.rdGPS01.old
cmp /tmp/out.rdGPS01.new /tmp/out.rdGPS01.old

tail -n +2 "$RUN/out.rdGPS47" > /tmp/out.rdGPS47.new
tail -n +2 "$BASELINE/out.rdGPS47" > /tmp/out.rdGPS47.old
cmp /tmp/out.rdGPS47.new /tmp/out.rdGPS47.old
```

## 10. Record Checksums

```sh
shasum -a 256 \
  "$RUN/out.cfneic_trig_run1" \
  "$RUN/out.cfneic_int_run1" \
  "$RUN/hypos_run1" \
  "$RUN/missed_events_run1" \
  "$RUN/log.cfneic_run1" \
  "$RUN/neic.txt" \
  "$RUN/dumgps"

shasum -a 256 \
  "$RUN/GPS.01" \
  "$RUN/GPS.47" \
  "$RUN/path01.xy" \
  "$RUN/path47.xy"
```

Expected checksum values are in `REGRESSION_BASELINE.md`.

## 11. Report Back

Please report:

- Whether `make` succeeded.
- Whether `./run_cfneic` ended with `Run complete`.
- The value of `OUT`.
- Any `cmp` command that printed output or failed.
- The first error message if the run failed.
- The output of:

```sh
git rev-parse --short HEAD 2>/dev/null || true
cat VERSION
gfortran --version | head -n 1
```
