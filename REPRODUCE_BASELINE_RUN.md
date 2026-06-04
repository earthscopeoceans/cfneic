# Reproduce The Baseline Run From A Fresh Checkout

This guide verifies that a fresh checkout can build the Fortran programs and
produce the same `run1` outputs as the current known-good run in
`/Users/jdsimon/mermaid/cfneic`.

It intentionally does not use `testdata/`.

## 0. Choose Paths

Use paths that do not already exist, especially for `OUT`.

```sh
SOURCE=/Users/jdsimon/programs/cfneic
CLONE=/private/tmp/cfneic-clone-test
INPUT=/Users/jdsimon/mermaid/cfneic
OUT=/private/tmp/cfneic-clone-run1
LOG=/private/tmp/cfneic-clone-run1.log
```

`INPUT` is the existing known-good data/run root. `OUT` must be a new empty run
directory. The wrapper will create it.

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
  run_cfneic --output-dir DIR --ident IDENT [--input-root DIR]
             [--tomocat FILE] [--neic FILE] [--ehb FILE]

Options:
  -i, --input-root DIR   Input root containing 452*/ dirs, neic.csv, ehb.hdf,
                         and tomocat.txt. Default: /Users/jdsimon/mermaid/cfneic
  -o, --output-dir DIR   Empty run-specific output directory to create/use.
  -n, --ident IDENT      cfneic run identifier, e.g. run1.
      --tomocat FILE     tomocat input file. Default: input-root/tomocat.txt
      --neic FILE        NEIC CSV file. Default: input-root/neic.csv
      --ehb FILE         ISC-EHB HDF file. Default: input-root/ehb.hdf
  -h, --help             Show this help.
```

## 6. Run Into A New Output Directory

Make sure `OUT` is empty or does not exist:

```sh
test ! -e "$OUT" || find "$OUT" -mindepth 1 -maxdepth 1 -print -quit
```

If that prints anything, choose a different `OUT`.

Run:

```sh
./run_cfneic \
  --input-root "$INPUT" \
  --output-dir "$OUT" \
  --ident run1 2>&1 | tee "$LOG"
```

Expected messages may include:

- `Warning: single GPS ignored...`

Recoverable `rdGPS` and `cfneic` data issues are written to
`$OUT/errors.log`. The important success signal is:

```text
Run complete: <your output dir>
```

## 7. Check Output Inventory

```sh
find "$OUT" -maxdepth 1 -type f -name 'GPS.*' | wc -l
find "$OUT"/empty_gps -maxdepth 1 -type f -name 'GPS.*' -print | sort
find "$OUT" -maxdepth 1 -type f -name 'path*.xy' | wc -l
find "$OUT" -maxdepth 1 -type f -name 'out.rdGPS*' | wc -l
wc -l "$OUT/errors.log"
sed -n '1,20p' "$OUT/errors.log"
```

Expected:

```text
42 active GPS.* files
empty_gps/GPS.03
empty_gps/GPS.44
empty_gps/GPS.45
45 path*.xy files
45 out.rdGPS* files
errors.log present with recoverable data issues
```

## 8. Compare Core Outputs To Baseline

Compare exact files against the existing known-good run root:

```sh
cmp "$OUT/out.cfneic_trig_run1" "$INPUT/out.cfneic_trig_run1"
cmp "$OUT/out.cfneic_int_run1" "$INPUT/out.cfneic_int_run1"
cmp "$OUT/hypos_run1" "$INPUT/hypos_run1"
cmp "$OUT/missed_events_run1" "$INPUT/missed_events_run1"
cmp "$OUT/log.cfneic_run1" "$INPUT/log.cfneic_run1"
cmp "$OUT/neic.txt" "$INPUT/neic.txt"
cmp "$OUT/dumgps" "$INPUT/dumgps"
```

No output from `cmp` means the files match.

Check representative `rdGPS` products:

```sh
cmp "$OUT/GPS.01" "$INPUT/GPS.01"
cmp "$OUT/GPS.47" "$INPUT/GPS.47"
cmp "$OUT/path01.xy" "$INPUT/path01.xy"
cmp "$OUT/path47.xy" "$INPUT/path47.xy"
cmp "$OUT/out.rdGPS01" "$INPUT/out.rdGPS01"
cmp "$OUT/out.rdGPS47" "$INPUT/out.rdGPS47"
```

No output means they match.

## 9. Record Checksums

```sh
shasum -a 256 \
  "$OUT/out.cfneic_trig_run1" \
  "$OUT/out.cfneic_int_run1" \
  "$OUT/hypos_run1" \
  "$OUT/missed_events_run1" \
  "$OUT/log.cfneic_run1" \
  "$OUT/neic.txt" \
  "$OUT/dumgps"

shasum -a 256 \
  "$OUT/GPS.01" \
  "$OUT/GPS.47" \
  "$OUT/path01.xy" \
  "$OUT/path47.xy" \
  "$OUT/out.rdGPS01" \
  "$OUT/out.rdGPS47"
```

Expected checksum values are in `REGRESSION_BASELINE.md`.

## 10. Report Back

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
