# Output Curation Decisions

This repository's job is to produce auditable Fortran workflow outputs. A
separate downstream package may later curate those outputs for analysis or
distribution, but that package should not be created until the Fortran workflow
is stable.

## Authoritative Workflow Products

The authoritative cfneic products for a run identifier `IDENT` are:

- `out.cfneic_trig_IDENT`
- `out.cfneic_int_IDENT`
- `hypos_IDENT`
- `missed_events_IDENT`
- `log.cfneic_IDENT`

The authoritative rdGPS products are the generated `GPS.*` files used by
cfneic. `path*.xy` and `out.rdGPS*` are retained as diagnostics and plotting
support.

`neic.txt`, `dumgps`, `input_manifest.before`, `input_manifest.after`, and
`errors.log` are reproducibility and audit byproducts. They should be preserved
with each run, but they are not curated science products.

## Downstream Schema

A downstream curation package should parse the authoritative text files into
normalized tabular records keyed by run identifier, source product, event time,
station, and record class (`triggered`, `interpolated`, `hypothesis`, or
`missed`). It should expose typed columns for event coordinates, station
coordinates, depth, magnitude, travel-time fields, GPS-derived drift fields, and
location-error fields. The package should preserve the original text row and
source filename for traceability.

The downstream package should read existing products rather than wrap this
Fortran workflow directly. Direct Python wrapping remains deferred unless a
clear operational need appears.
