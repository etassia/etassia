# spec/plantuml

PlantUML diagram sources (the declared kinds) extracted from PlantUML's
own test suite by `scripts/extract_plantuml_tests.rb`
(TODO.foundation/12, "Do" step 1). Layout mirrors `spec/mermaid/`:
`<type>/<case id>.puml` plus `<type>/<case id>.meta.json`.

## Provenance: upstream fixtures, NOT real-world files

Every case here is a fixture written by PlantUML's developers to test
PlantUML. **No case in this corpus has real-world provenance** (a diagram
a user wrote for their own documentation). Issue #2 asks for a corpus of
real-world files; this cohort does not satisfy that, and "100% of
oracle-valid" on it must not be read as if it did. Whether it satisfies
the criterion is the owner's decision. Each `.meta.json` carries
`"provenance": "upstream-fixture"`; a real-world case would carry a
different value and a source URL, and none exists yet.

## Selection rule

1. Source files: every `*.puml` under `src/test/resources/` and every
   `*.java` under `src/test/java/` of the pinned upstream checkout.
   `tools/perf-bench/` is a benchmark corpus, not test resources, and is
   excluded.
2. A case is one `@start<kind>` ... `@end<kind>` block. `@startuml` is the
   shared wrapper; its blocks classify through the marker rules below.
   A per-kind wrapper carries its kind directly: `@startgantt` → gantt,
   `@startmindmap` → mindmap, `@startnwdiag` → network. Wrappers whose
   kind is not carried (`@startwbs`, `@startjson`, `@startyaml`,
   `@startditaa`, `@startsalt`, `@startchen`, `@startcrash`,
   `@startpacketdiag`) are excluded — they are reference-gap candidates,
   not corpus types. `.puml` front matter (`expected-*` test directives)
   is dropped. In Java files only text inside `"""` blocks is read,
   verbatim; Java escape sequences are NOT processed
   (`origin: java-text-block` in the meta).
3. Inside an `@startuml` block, an *explicit marker* is an unambiguous
   declaration of one kind: activity (`:action;`, `start`/`stop`, `-> `,
   `partition`, `fork`/`split`/`repeat`, `if`/`while`/`switch`), state
   (`state X`, `[*] -->`), object (`object X`), usecase (`usecase X`,
   stadium `(X)` shapes), component (`component`/`node`/`cloud`/
   `artifact`/`folder`/`frame`/`storage`, `port`/`edge`), timing
   (`concise`/`robust`/`clock`), ebnf (`ebnf`), network (`network`/
   `server`/`router`), class (`class`, `interface`, `enum`, ...) and
   sequence (`participant`, `boundary`, `control`, `collections`,
   `activate`/`deactivate`, `autonumber`, `alt`/`loop`/`opt`/`par`/
   `critical`/`break`, `ref over`, `== divider ==`, `newpage`).
4. A *weak keyword* is an element declaration several kinds share:
   `actor`/`queue` (sequence participants), `entity`/`database`
   (entity rows and sequence participant types), `package` (class-diagram
   grouping and deployment element). A weak keyword decides the kind only
   when no explicit marker fired; beside an explicit marker it is an
   element inside that kind's diagram (a `database` line in a
   `participant`-bearing block is a sequence participant type, not an
   entity diagram).
5. A block classifies only when exactly one kind results. Blocks with
   markers of several kinds, or with neither an explicit nor a weak
   declaration, are excluded — bare message diagrams (`A -> B : hi` with
   no declaration) on purpose: PlantUML infers the type itself, and the
   same line is valid in several diagram types. This under-selects; it
   never mislabels one. The type is a heuristic, not an oracle verdict;
   step 2 may find a case PlantUML renders as a different type.
6. A fixture the pinned oracle cannot judge — not valid, not rejected:
   the pinned PlantUML crashes mid-export on it, so no verdict can exist —
   is excluded at extraction (`UNJUDGEABLE` in the extractor, each entry
   documenting the crash). Revisit when the pinned jar moves.

Result at the pinned SHA (cases, not files): 37 activity, 39 class,
6 component, 17 gantt, 4 mindmap, 42 state, 3 timing, 2 usecase — and
entity/network/ebnf/object stay empty: PlantUML's test resources carry no
`@startuml` text fixtures for them (its ER coverage lives behind the
uncarried `@startchen` wrapper). Three fixtures (one state, two timing)
are excluded by rule 6. The sequence directory also holds 16
`etassia.*` ledger cases (no `.meta.json`, so outside the manifest
checksum) that count in `pin.json` and the scoreboard. `!include`/
`!define` blocks are kept and flagged `uses_preprocessor: true`.

## Case IDs

`<upstream path without src/test/ and extension, "/" as ".">[.<test>]--<first
12 hex of SHA-256 of the normalized source>`. Normalized means CRLF to LF,
trailing whitespace stripped, outer whitespace trimmed. There is no
ordinal, so inserting, removing or reordering fixtures upstream never
renames another case. Moving a file or editing a diagram changes that
case's ID, deliberately: it is a different case. Identical blocks from the
same file collapse into one case with `occurrences` counting them.

## Pin

`pin.json` holds the upstream SHA (the extractor refuses any other
checkout), the pinned PlantUML/Java/Graphviz oracle toolchain, the jar
checksum, and a checksum over the committed corpus
(`corpus.manifest_sha256`). The pinned PlantUML (1.2026.6) is older than
the upstream fixtures (1.2026.9beta4). The corpus still keeps all selected
fixtures: the oracle rejected two class and two sequence cases, and those
four cases stay recorded rather than disappearing from the source corpus.

## Regenerating

    git clone https://github.com/plantuml/plantuml.git <dir>
    git -C <dir> checkout <sha from pin.json>
    ruby scripts/extract_plantuml_tests.rb --upstream <dir>

The committed oracle verdicts are generated atomically with the pinned
toolchain first on `PATH` (the `tools/bin/plantuml` shim pins the jar;
Java and Graphviz come from the same pinned trio as `pin.json`):

    PATH="$HOME/src/etassia/tools/bin:$HOME/src/etassia/tools/graphviz-15.1.1/bin:$PATH" \
      mise exec java@26.0.2 -- ruby scripts/plantuml_oracle.rb \
      --write spec/plantuml/oracle-verdicts.yml spec/plantuml

## The ditaa ledger cohort

`ditaa/` is a LEDGER cohort: Etassia's own `etassia.*` cases, not upstream
fixtures — PlantUML's test resources carry no `@startditaa` text (the
wrapper was an excluded reference-gap candidate before Etassia implemented
the kind natively). Each case is hand-written to one ditaa feature (boxes,
nesting, colour codes, dashed lines, the seven markup shapes, arrowheads,
point markers, bullets, open connectors and the `-S -r -E -T scale=`
flags). They carry no `.meta.json`, so they sit outside the manifest
checksum like the sequence ledger cases, and count in `pin.json` and the
scoreboard.

The pinned jar renders ditaa as PNG bytes even under `--svg`, so the
oracle judges them through the raster lane of contract v2
(TODO.foundation/12): valid means "the binary accepted the source", and
the PNG dimensions recorded in the verdict reason are the canvas-parity
observable — Etassia's SVG canvas must equal the jar's PNG size for the
same source.

Scoreboard rows live in `scoreboard/plantuml.json`. `bundle exec rake plantuml`
measures them: a case passes when the committed oracle verdict is `valid` and
Etassia renders it to well-formed SVG. `bundle exec rake plantuml:check` fails
CI when the committed file differs from a fresh measurement. The current
counts live in that file; oracle-rejected cases are not in its denominators.

## The git ledger cohort

`git/` is a LEDGER cohort like `ditaa/`: Etassia's own hand-written cases,
not upstream fixtures — PlantUML's test resources carry no `@startgit`
text. Each case is one git-log drawing feature: a linear history, a fork,
a merge with the `\` rail switch, sequential branches, hash-style names,
a tag line, rails without commits, an empty body, a single commit and a
realistic `git log --graph` excerpt. They carry no `.meta.json`, so they
sit outside the manifest checksum like the ditaa and sequence ledger
cases, and count in `pin.json` and the scoreboard.

The pinned jar renders git as SVG (`data-diagram-type="GIT"`), so the
oracle judges them through the ordinary SVG lane. Two rails is the jar's
ceiling: its gitlog engine dies with a fatal-crash error image on any
three-rail graph, so no such case is in the cohort — a source the pinned
oracle cannot render cannot be oracle-valid.

Scoreboard rows live in `scoreboard/plantuml.json` and are measured the
same way as every other row: `bundle exec rake plantuml`, checked by
`bundle exec rake plantuml:check`.

## The archimate ledger cohort

`component/` also holds `archimate.*` LEDGER cases beside its upstream
fixtures — PlantUML's test resources carry no `@startuml` archimate text.
The `archimate` keyword rides the component notation, so the cases count
in the component row of `pin.json` and the scoreboard. Each case is one
archimate feature: a bare element, a six-colour spread, both display and
code orders, the business-actor, application-component and
technology-device icons, a labelled relation, the jar's
update-in-place behaviour for a repeated code, and a package-nested
pair.

The vocabulary itself is generated: `scripts/build_archimate_sprites.rb`
probes the pinned jar once per upstream sprite and commits the icon
paths verbatim, with their placement geometry, into
`node_graph/archimate_sprites.rb` (verified byte for byte at write
time). The jar takes real colours rather than the layer words, and the
bare stereotype name rather than its internal `$archimate/` prefixed
form, so the cohort uses the jar-true forms; Etassia's wider acceptance
of both stays pinned at the unit level.
