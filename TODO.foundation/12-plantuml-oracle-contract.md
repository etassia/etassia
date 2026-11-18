# PlantUML oracle contract (item 12, step 2)

Code: `scripts/plantuml_oracle.rb`. Specs: `spec/scripts/plantuml_oracle_spec.rb`.
Measured on PlantUML 1.2026.6, OpenJDK 21.0.2, Graphviz 15.1.1. Contract
version 2 (below) adds the raster lane.

## Command

`plantuml --svg --pipe --charset UTF-8`, source on stdin, SVG on stdout, stderr captured.
Binary name is a parameter. Exit codes: 0 rendered, 200 syntax error.

## Predicate (read the SVG, not just the exit code)

Every rendered diagram has a `data-diagram-type` attribute on `<svg>`; the error
image has none. Checked in this order:

| Observed | State |
|---|---|
| spawn failure, timeout, signal | infrastructure |
| stderr names OutOfMemoryError, StackOverflowError, `java.lang.`, IOException, "Cannot run program", "Cannot find Graphviz", missing jar | infrastructure |
| exit other than 0 or 200 | infrastructure |
| stdout starts with the PNG magic, exit 0 | **valid (raster)** — reason carries the PNG dimensions |
| stdout starts with the PNG magic, other exit | infrastructure |
| stdout is not a well-formed `<svg>` | infrastructure |
| `data-diagram-type` present and exit 0 | **valid** |
| `data-diagram-type` present and exit 200 | infrastructure (contradiction) |
| no `data-diagram-type` and (exit 200, or error text in the SVG) | **rejected** |
| anything else | infrastructure |

The raster lane (v2) exists for wrapped kinds whose engine is raster-only:
ditaa's ascii2image writes PNG bytes on stdout even under `--svg --pipe`
(measured on the pinned jar). The jar's judgment there is acceptance — a
ditaa crash also writes a report image with exit 0, so a raster verdict
says "the binary accepted the source", not "the content is the diagram".
`svg_sha256` carries the PNG bytes' digest; `reason` carries the
dimensions, which are the parity observable for the canvas.

Unknown shapes are never a verdict. Infrastructure failure is never written to a verdict file.
Not measured: an exit-0 error image (this version exits 200); the 0 + error-text rule is
defensive for other versions. A Graphviz path that does not exist falls back silently on this
build (exit 0, rendered), so missing Graphviz is detected through stderr and the version probe.

## Timeout

60 s default. On expiry the whole process group gets TERM, then KILL after 2 s, and the run
is infrastructure. Spec: `sh -c "sleep 30 & wait"` with a 1 s timeout returns in under 10 s.

## Canary

Before a refresh: a good source must be valid AND a bad source must be rejected. Either
failing raises `CanaryFailure` and no case is judged.

## Refresh

All-or-nothing. Any infrastructure failure, failed canary, or unreadable version aborts and
the verdict file is untouched (temp file + rename).

## Provenance, per record

`source_sha256`, `svg_sha256`, `plantuml`, `java`, `graphviz` versions, `command`,
`contract` version. A version that cannot be read aborts the refresh.
