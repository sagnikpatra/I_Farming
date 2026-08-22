# ADR-0002: Godot Implementation Choices — Scripting Language &amp; Save Format

## Status

Accepted

## Date

2026-08-18

## Last Verified

2026-08-22 -- Validation Criteria synced against real EPIC-M2 completion
status (see that section's own 2026-08-22 update note)

## Decision Makers

Technical Director (analysis), project owner (final decision)

## Summary

Two foundational implementation choices for the Godot migration authorized
by ADR-0001: (1) GDScript over C# as the scripting language, and (2) a
clean Godot `Resource`-based save format rather than preserving compatibility
with the current LibGDX-era JSON schema. Both must be settled before EPIC-M0
(Godot Foundation &amp; Migration Preflight) completes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4 (specific point release to be pinned via `/setup-engine`, part of EPIC-M0) |
| **Domain** | Scripting, Core, Persistence |
| **Knowledge Risk** | LOW — GDScript and Godot's `Resource`/`ResourceSaver`/`ResourceLoader` APIs are stable, well-documented, within training data |
| **References Consulted** | The Godot migration roadmap (this session); ADR-0001 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond the version pin itself |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted) |
| **Enables** | EPIC-M2 (Economy &amp; State Core Port) — cannot start language-specific implementation without this decision |
| **Blocks** | Any GDScript/C# code being written |
| **Ordering Note** | Part of EPIC-M0's scope; recorded as its own ADR because both choices affect every subsequent epic, not just M0 itself |

## Context

### Problem Statement

ADR-0001 authorized the migration direction but explicitly deferred
implementation-level choices to the migration roadmap. The roadmap surfaced
two decisions that shape every downstream epic:

1. **Language**: GDScript has no sealed-class equivalent (the current
   `PlotState` sealed class needs a hand-rolled variant pattern), while C#
   would let the ~1,487-line economy port (`game/GameData.kt`,
   `GameModels.kt`, `GameViewModel.kt`, `GameRepository.kt`) translate far
   more mechanically — sealed classes, data classes, and `when` expressions
   all have direct C# analogues.
2. **Save format**: The current `GameRepository` writes a plain, stable JSON
   schema. Keeping that schema in Godot would enable a differential parity
   harness (feed identical JSON + action sequences into both the old LibGDX
   build and the new Godot build, diff the output) — a near-free mitigation
   for the migration's flagged "no test suite" risk, and would let existing
   device saves carry forward.

### Current State

Pre-decision: no Godot code exists yet (EPIC-M0 has not started). The
current app persists `GameState` via `GameRepository` to Android
`SharedPreferences` as hand-serialized JSON (`org.json`).

### Constraints

- Free/open-source only (both GDScript and C# in Godot satisfy this
  equally — licensing was not the differentiator for either decision)
- Solo developer, no prior Godot experience
- No existing automated test suite (planned as non-negotiable in EPIC-M2
  regardless of this ADR's save-format outcome)

### Requirements

- Whichever language is chosen must support the full economy port (sealed
  state machines, deterministic formulas, seeded-random reproducibility
  for `demandModifierPercent`/`wasSandalwoodStolen`)
- The save format must support the full `GameState` shape (plots, inventory,
  zone layout, decorations, Mandi glut, LiveOps event-pass fields)

## Decision

### 1. Scripting language: GDScript

GDScript is chosen over C#. The deciding factor is ecosystem fit for a solo
developer with no existing Godot experience, not licensing (both are free)
and not raw port convenience (C# would win on that axis alone):

- GDScript has the overwhelming majority of Godot's official documentation,
  tutorials, and community Q&amp;A — the primary resource for debugging
  Android-export-specific issues as they arise
- No second toolchain (.NET/Mono) to install, debug, and keep in sync with
  Godot's own Android export pipeline
- Lighter APK — C# adds .NET runtime weight on top of Godot's own Android
  runtime, both already flagged in ADR-0001 as an APK-size concern
- The sealed-class gap (`PlotState`) is a one-time, bounded cost in EPIC-M2;
  the documentation/community/toolchain advantage is an ongoing cost across
  the entire multi-epic migration

### 2. Save format: clean Godot `Resource`-based serialization

The project starts a new, idiomatic Godot save format rather than
preserving the current JSON schema.

## Alternatives Considered

### Alternative 1 (language): C#

- **Pros**: Near-mechanical port of the 1,487-line economy layer — sealed
  classes, data classes, `when` expressions all have direct C# analogues
- **Cons**: Adds .NET runtime weight to the APK; thinner Godot-specific
  documentation and community coverage; a second toolchain to debug
- **Rejection Reason**: The ongoing documentation/tooling-support cost
  outweighs a one-time port convenience, for a solo developer with no
  existing Godot experience

### Alternative 2 (save format): Keep the JSON schema compatible

- **Pros**: Enables a differential parity-testing harness against the
  intact LibGDX build (identical input, diff the output) at near-zero cost;
  existing device saves carry forward automatically
- **Cons**: Slightly less idiomatic than native Godot serialization; more
  glue code to keep two schemas in sync during the migration
- **Rejection Reason**: Project owner's explicit choice, in favor of a
  clean, idiomatic Godot-native format. Accepted with the trade-off noted
  below.

## Consequences

### Positive

- GDScript keeps the team inside Godot's best-supported path for a project
  with no prior Godot experience
- Clean save format is more idiomatic Godot code, easier to extend as the
  economy grows (e.g. the worker-assignment wage fields planned for EPIC-M7)

### Negative

- Losing JSON-schema compatibility means **no automatic differential parity
  harness** — EPIC-M2's automated test suite (GUT/gdUnit4, planned
  regardless) is now the *primary* regression safety net for the economy
  port, not a supplement to a cheaper mechanism. This raises the bar on
  that test suite's coverage.
- **No existing device save carries forward** — players (currently just the
  developer, pre-launch) start over on the Godot build. Acceptable at this
  project's stage; would need an explicit migration tool if this decision
  were made post-launch.
- GDScript's lack of a sealed-class construct means `PlotState`
  (`Empty | Growing | ReadyToHarvest`) needs a deliberate, documented
  variant-pattern translation in EPIC-M2 — flag this as an implementation
  guideline for whoever picks up that epic.

### Neutral

- Both choices are reversible in principle before EPIC-M2 substantially
  progresses, but increasingly costly to reverse after — this ADR should be
  treated as settled going into M2, not revisited per-epic

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| EPIC-M2's test suite has gaps the parity harness would have caught | MEDIUM | MEDIUM | Prioritize coverage of every formula in `crop-economy.md` and its sibling docs; treat test-suite completeness as a hard EPIC-M2 exit criterion, not best-effort |
| GDScript's variant-pattern workaround for `PlotState` introduces subtle bugs the Kotlin sealed class prevented at compile time | LOW-MEDIUM | MEDIUM | Cover every `PlotState` transition explicitly in the EPIC-M2 test suite |

## Performance Implications

Not applicable — neither decision has a measurable runtime performance
effect on its own; both feed into EPIC-M0's baseline measurements.

## Migration Plan

Both decisions take effect at the start of EPIC-M0/M2 implementation work;
no migration of existing artifacts is required since no Godot code exists
yet.

**Rollback plan**: Since ADR-0001's rollback plan keeps the LibGDX/Compose
build intact, reversing either choice before EPIC-M2 substantially
progresses costs only the EPIC-M0 setup work, not any economy-layer code.

## Validation Criteria

**Update (2026-08-22)**: synced against real EPIC-M2 completion status
(`godot-migration-roadmap.md` shows M2 Complete) -- both items below are
done, not left silently unchecked.

- [x] EPIC-M2's `PlotState` variant-pattern translation documented and
      covered by tests -- `godot/scripts/economy/plot_state.gd` implements
      option (b) from this ADR's own analysis (a single tagged `Kind`-
      discriminant `Resource`, constructed only via its three static
      factories), documented inline with the full reasoning, and covered
      by `godot/tests/unit/test_plot_state.gd` plus 10 other test files
      that exercise real `PlotState` transitions.
- [x] EPIC-M2's automated test suite covers every formula in
      `design/gdd/crop-economy.md` (and its sibling docs once written),
      given it is now the primary regression safety net -- `crop-economy.md`
      exists and the economy layer's GUT coverage (545/545 passing as of
      the latest commit on this branch) is the project's sole regression
      safety net for it, per this ADR's own decision.

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables: EPIC-M2 (Economy &amp; State
Core Port) and every epic downstream of it.

## Related

- Depends on `docs/architecture/adr-0001-godot-engine-migration.md`
- Referenced by the Godot migration roadmap's EPIC-M0 and EPIC-M2 scope
  (this session's transcript; not yet written to a standalone roadmap file)
