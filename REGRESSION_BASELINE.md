# Regression Baseline

Baseline captured from the current successful run products in `/Users/jdsimon/mermaid/cfneic`.

- Capture date: 2026-06-04
- Repo branch: `dev`
- Repo commit at capture: `2c78b1c`
- Run identifier: `run1`
- Known-good run root: `/Users/jdsimon/mermaid/cfneic`

## Toolchain And Platform

Compiler:

```text
/opt/homebrew/bin/gfortran
GNU Fortran (Homebrew GCC 14.1.0_2) 14.1.0
```

Platform:

```text
ProductName:    macOS
ProductVersion: 14.8.7
BuildVersion:   23J520
Machine:        arm64
Kernel:         Darwin Kernel Version 23.6.0: Tue Apr 21 20:21:13 PDT 2026; root:xnu-10063.141.1.712.16~1/RELEASE_ARM64_T6031
```

## File Counts

Top-level run-root inventory:

- Float directories matching `452.*`: 45
- Float directories under `GeoCSV/` matching `452.*`: 45
- Active `GPS.*` files: 42
- Empty GPS files moved aside in `empty_gps/`: 3
- `path*.xy` files: 45
- `out.rdGPS*` files: 45

Empty GPS files:

- `empty_gps/GPS.03`
- `empty_gps/GPS.44`
- `empty_gps/GPS.45`

## Core Output Checksums

SHA-256 checksums:

```text
df26da29a150eda42ed160cf4833582de8df24a645365692bd358ff9a98a7d88  out.cfneic_trig_run1
1bf553012f6c8f6a247e5d54ae35dd34017ba4565e40f5fb180ef541e560271f  out.cfneic_int_run1
2488a40b8b2b6c69565e9917ad998db805de95d80dd4b7dbc32e885b6d2b026c  hypos_run1
59576fae8ad3dee0877af2d552cb85c47aa5a950149b0567ec1275ff73f8a672  missed_events_run1
9b5bfdaea0376cb00c49a2e6d558b011715bf1cab19648fc27bed332085c051a  log.cfneic_run1
595c9f1ea51ae298763d9d9f3250227517404c421324a41454482e9c6adef07a  neic.txt
a2a5db2d81e2f0fab8da4d86c9eef8d26cfc718e7cfce6492495b1dd0a009f31  dumgps
```

Line counts:

```text
3347  out.cfneic_trig_run1
3721  out.cfneic_int_run1
3995  hypos_run1
 360  missed_events_run1
  50  log.cfneic_run1
```

## Representative `rdGPS` Checksums

These are not the full GPS product set, but representative fingerprints for one long-running float and one shorter float.

```text
7c02a0b65b6b326b12dbad7b123d184d921a0d075a425d84e05373faa6f8d402  GPS.01
b6f82580896fb81e48e446ff1479bba4cdebc1b6c62b228983173e6bef38ddaa  GPS.47
4af9f9806c8421fbfb00fa7b952db8bf105e82c5f47706be417972b5c7a1d130  path01.xy
5f670405d43288082aa965c3a78d2885d8a10eff819b6d2c04b9a869ef62ad08  path47.xy
aedcdd884f5b89ee9a26f1eecbbb9f11caaa8768a21fcafc51146bfa92952122  out.rdGPS01
0d79eda0aea3833ba2e6a650ba877687d02219eaa9bc668bc68458c80e879add  out.rdGPS47
```

Line counts:

```text
274  GPS.01
 78  GPS.47
544  path01.xy
152  path47.xy
327  out.rdGPS01
 15  out.rdGPS47
```

## Representative Numeric Fingerprints

First three data rows of `out.cfneic_trig_run1`:

```text
2018 187 01 40 05 789  157.796   51.572  60.7   3.4   3.7 6.2  174.5 P0006 -179.507  -14.421   68.624  657.59   0.09   5.27      11  2416 -1512 0.056    0.46    0.59    0.02   -0.02    0.00 -0.0009
2018 187 01 40 05 789  157.796   51.572  60.7  53.1  30.7 6.2  194.7 P0007 -176.921  -13.234   68.173  655.53   0.14   5.21       7  4700 -1519 0.057    7.09    4.98   -0.31    0.24    0.25  0.0210
2018 193 06 51 20 860 -179.861  -23.477 551.0   3.7   0.9 5.6  209.2 P0006 -179.504  -14.386    9.049  127.80   0.09   5.23      10  2356 -1522-0.091    0.59    0.25   -0.07    0.04    0.06  0.0062
```

First three data rows of `out.cfneic_int_run1`:

```text
2018 194 09 46 48 490  169.090  -18.966 173.1   3.7   0.9 6.4  209.2 P0006 -179.504  -14.387   11.838  169.62   0.04  66.24      53  2356 -1532 0.116    0.59    0.25   -0.07    0.08    0.01 -0.0014
2018 194 09 46 48 490  169.090  -18.966 173.1  30.7  17.4 6.4  186.0 P0007 -177.247  -13.131   14.352  202.15   0.03  66.37     113  4223 -1522 0.111    4.98    4.78   -0.04    0.05    0.12 -0.0042
2018 194 17 05 52 840 -177.343  -15.007 388.2  30.7  17.4 4.1  186.0 P0007 -177.260  -13.128    1.869   52.92   0.05  59.09      31  4217 -1522-0.054    4.98    4.78   -0.04    0.06    0.14  0.0081
```

First three data rows of `GPS.01`:

```text
1545876913  1545961447   1.0   9.199  9.402  0.000    0.0    1.752 -146.208    1.673 -146.182  4    668  0.892 66.717 2018-12-28T02:27:00.000Z          1
1545964765  1546690553   8.4  47.813  5.692 -0.785  247.0    1.683 -146.196    1.644 -145.768  4    620  0.852 62.027 2019-01-05T12:58:47.000Z          2
1546693697  1547419623   8.4  52.584  6.259  0.067  232.7    1.653 -145.781    2.005 -145.462  4    947  1.289 94.627 2019-01-13T23:29:40.000Z          3
```

First three data rows of `GPS.47`:

```text
1566495483  1566579473   1.0   7.508  7.724  0.000    0.0  -25.989 -174.885  -26.045 -174.926  4    157  0.244 15.216 2019-08-23T17:50:10.000Z          1
1566582860  1567309632   8.4  45.058  5.357 -0.500  197.8  -26.047 -174.927  -26.439 -175.049  4    661  0.733 43.682 2019-09-01T04:46:49.000Z          2
1567313527  1568040028   8.4  47.654  5.667  0.037  145.1  -26.440 -175.061  -26.712 -175.432  5    990  0.593 35.505 2019-09-09T15:58:30.000Z          3
```

## Notes

- Some output rows have tightly adjacent fields, for example `-1522-0.091`, because of the legacy Fortran formatting. Treat exact output text as authoritative for checksum comparisons.
- This baseline is intended to protect behavior while modernizing parsing and run orchestration.
