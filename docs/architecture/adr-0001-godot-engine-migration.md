# ADR-0001: Migrate from LibGDX/Native-Android to Godot 4 (Full Rewrite)

## Status

Accepted

## Date

2026-08-18

## Last Verified

2026-08-18

## Decision Makers

Technical Director (analysis), project owner (final decision)

## Summary

The village board reads as too large and too naturalistic, and the project
wants ambient roaming villagers with a future worker-assignment mechanic. A
technical-director analysis found the scale/art complaint is caused by
specific, fixable layout/shader choices — not by an engine limitation — and
recommended a ~1-2 week in-place LibGDX fix instead of migration. **The
project owner overrode that recommendation** and chose a full migration to
Godot 4, on the stated grounds that the ambition is a substantially bigger
game (animated villagers, a livelier world, room to grow) rather than a
narrow fix for the current complaint. This ADR records that decision and its
consequences; it supersedes the project's LibGDX-only stack pinning in
`CLAUDE.md`/`technical-preferences.md`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4 (version to be pinned via `/setup-engine` before implementation begins) |
| **Domain** | Core, Rendering, UI, Navigation, Animation, Input |
| **Knowledge Risk** | MEDIUM — Godot 4's Android export and library-embedding paths are within training data as of this analysis, but no specific Godot 4.x point release has been pinned yet; `/setup-engine` must run before implementation to lock a version and populate `docs/engine-reference/godot/` |
| **References Consulted** | Godot Android export/library docs (see Related); the current LibGDX implementation (`core/village3d/`, `app/.../ui/gdx/`) as the migration source |
| **Post-Cutoff APIs Used** | None identified yet — re-verify once a specific Godot version is pinned |
| **Verification Required** | Full re-verification of every migrated interaction (tap/drag/rotate/flip/pinch-zoom/pan/decoration placement) on the target AVD; Compose→Control UI parity for every existing screen |

> **Note**: This ADR's Knowledge Risk is MEDIUM. It must be re-validated once
> `/setup-engine` pins a specific Godot version — treat this ADR as
> provisional on the engine-version question until that happens.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | The villager-AI / worker-assignment system (design already drafted, implementation now targets Godot); a future retroactive ADR for "why LibGDX was originally adopted" (documents what is now being superseded) |
| **Blocks** | All village-board and app-shell implementation work until a phased migration roadmap exists (see Migration Plan) |
| **Ordering Note** | Run `/setup-engine` to pin the Godot version before any implementation story starts. This ADR authorizes the migration direction; it does not itself constitute a migration plan — see Migration Plan below and the follow-up roadmap work. |

## Context

### Problem Statement

The stated complaint was narrow: *"The space looks very big it needs to be
small and cartoonish type. If you want you can use any engine."* combined
with a separate request for roaming villagers and a worker-assignment
mechanic. A technical-director analysis (full text preserved in this
session's history) found the scale/art complaint traces to four specific,
engine-independent causes in the current LibGDX code:

1. The board's content (18×25 tiles) is 2.4× wider than the default camera
   viewport (7.5 tiles) — no zoom level shows both a readable scale and the
   whole village.
2. The terrain plane is unbounded (87 tiles, no visible edge), producing a
   pannable area ~4× larger than the actual village.
3. Building models have no scale applied and cover only ~39% of their tile,
   with no footprint/plinth.
4. The terrain uses blurred per-pixel noise and smooth Lambert lighting —
   actively naturalistic choices that read as "3D render," not "cartoon."

The technical-director's recommendation was to fix these four causes
in-place (~1-2 weeks) and explicitly **not** migrate, since none of them are
caused by LibGDX and would recur identically in any new engine.

### Decision Override

The project owner chose full Godot migration anyway, selecting the option
whose own description read: *"8-14 weeks. Discards all ~5,650 lines
including the Compose UI. Only makes sense if the real ambition is a much
bigger game (VFX, cutscenes, lots of animated characters) — a vision call,
not a fix for this complaint."* This is recorded as a deliberate,
informed choice to treat the engine migration as a strategic investment in a
larger long-term ambition (a livelier, more animated, more expansive village
sim), not as the minimal fix for the original scale/art complaint. That
distinction matters for how this ADR should be read: the four root causes
above still need to be solved *inside* the new engine — migrating does not
solve them by itself, and the migration roadmap must budget time for them
alongside the rewrite.

### Current State

Native Android app (Kotlin, Jetpack Compose, Material3) with LibGDX 1.12.1
embedded via a Fragment for the 3D village board only:
- `app/` — ~1,900 lines of Compose UI (`FarmScreen`, sheets, dialogs, Mandi
  trading screen, events feed) + `GameViewModel`/`GameRepository`/`GameData`
  (~1,500 lines, the full farming economy) + `ui/gdx/` glue (~750 lines,
  `VillageSnapshotMapper` is engine-neutral and should survive the migration)
- `core/` — ~1,200 lines of LibGDX rendering (`village3d/` package):
  ray-picking, drag/rotate/flip, procedural terrain/tint/rangoli decal
  builders, camera rig
- 8 documented on-device bug fixes embedded as code comments across this
  code (hit-box tuning, shadow desync, black-silhouette models, zone
  overlap, z-fighting, texture filtering, MSAA/depth requirements, touch
  interception) — each is a *class* of problem likely to recur during
  reimplementation in Godot, not a LibGDX-specific defect
- 627 CC0 Kenney `.obj`/`.mtl` models sourced in `assets_3d/`, 31 currently
  bundled into the APK — these import into Godot natively, zero conversion

### Constraints

- Free/open-source only (hard constraint, unchanged) — Godot 4 is
  MIT-licensed, satisfies this
- Solo developer, Kotlin-only today — Godot uses GDScript and/or C#;
  language ramp-up is a real cost of this migration
- No test suite exists — all verification is manual on-device; regressions
  during a full rewrite will not be caught automatically
- Target: Android (minSdk 24, target/compileSdk 37), Android Emulator AVD
  verified so far, no physical hardware testing yet

### Requirements

- Every currently-working feature must be reachable again post-migration:
  full crop economy, land/structure tiers, Farmhouse progression, Mandi
  trading, Monsoon/Festival LiveOps, village board interaction (tap,
  long-press-drag, rotate, flip, pinch-zoom, pan), decorations
- Village board must additionally resolve the original scale/art complaint
  (bounded, compact, cartoonish) as part of the rewrite, not as a follow-up
- Villager AI (roaming + worker assignment, per the separately-drafted
  design brief) must be buildable on the new engine
- Free/open-source only

## Decision

Migrate the entire application — UI, game-state/economy logic, and the 3D
village board — to Godot 4. This supersedes the "None of Godot/Unity/Unreal"
stack pinning in `CLAUDE.md` and `.claude/docs/technical-preferences.md`,
both of which must be updated to name Godot as the engine going forward (see
Migration Plan step 1).

This ADR authorizes the *direction*. It deliberately does not attempt to
fully design the target Godot architecture, phase breakdown, or story-level
plan — that is significant enough to warrant its own dedicated planning pass
(technical-director + producer, per the chosen "full roadmap first"
approach), not to be compressed into this document. See Migration Plan for
what happens next.

### Architecture

```
CURRENT (superseded by this ADR):
  MainActivity (FragmentActivity)
    └── Compose tree ─── FarmScreen, sheets, HUD
          └── GdxVillageBoard (AndroidView) → GdxVillageFragment → Village3DStage (LibGDX)
  GameViewModel/GameRepository/GameData (StateFlow<GameState>)
        └── VillageSnapshotMapper → List<TileSnapshot> → Stage.rebuild()

TARGET (established by the follow-up roadmap, not this ADR):
  Godot 4 project
    └── Scene tree — UI screens as Control-node scenes (replacing Compose)
          └── Village board — Node3D scene (replacing Village3DStage)
    └── Game-state/economy logic — GDScript/C# (replacing GameViewModel/GameRepository/GameData)
    └── Villager actors — CharacterBody3D or Node2D billboards + NavigationAgent3D/grid AI
```

### Key Interfaces

None defined by this ADR — interface/contract design is deferred to the
migration roadmap and its epics/stories, where it can be scoped against a
pinned Godot version.

### Implementation Guidelines

Carried forward from the technical-director's analysis as things the new
implementation must still get right (migrating does not solve these
automatically):

- Compact village-board layout (target roughly 10×12 tiles, not 18×25) with
  a visible bounded edge (fence/hedge/treeline)
- Buildings must be scaled to fill their tile and have a visible footprint
- Flat/stylized shading and palette (avoid naturalistic noise textures and
  smooth specular lighting) to actually achieve "cartoonish," independent of
  engine
- Villager actor lifecycle must be a per-frame-updatable persistent list, not
  rebuilt wholesale on every state change (the current `rebuild()`-on-every-
  `GameState`-change pattern is correct for static structures, wrong for
  moving actors — this constraint carries over regardless of engine)
- Re-verify each of the 8 documented on-device bugs' *failure classes*
  (hit-box sizing vs. camera angle, shadow/entity ownership, black-silhouette
  models, zone-footprint overlap, z-fighting, texture filtering, MSAA/depth,
  touch-interception layering) against Godot's equivalent systems — expect
  new instances of the same classes of bugs, not immunity from them

## Alternatives Considered

### Alternative 1: Stay on LibGDX, fix the four measured causes in-place

- **Description**: Bound/compact the space, scale models to fill their
  tile, flatten terrain/lighting, optional cel-shader pass — four
  independently shippable, independently revertible steps.
- **Pros**: ~1-2 weeks; preserves ~2,000 lines of verified engine code and
  8 documented on-device fixes; preserves the Compose UI; every step
  reversible; layout/palette/proportion work would have ported to any future
  engine as design data regardless.
- **Cons**: No built-in navmesh/animation tooling (villager AI needs
  hand-rolled grid pathfinding); no scene editor.
- **Estimated Effort**: 1-2 weeks.
- **Rejection Reason**: This was the technical-director's recommendation.
  Rejected by the project owner in favor of treating the engine choice as a
  strategic investment in a larger future scope, not a minimal fix — see
  Decision Override above.

### Alternative 2: Godot 4 embedded as an Android library (AAR), keep Compose UI

- **Description**: Keep the Compose UI and Kotlin economy layer; replace
  only `GdxVillageFragment` with a `GodotFragment` for the village board.
- **Pros**: Preserves ~3,400 lines of Compose UI and game logic; full CC0
  asset reuse; gains Godot's navigation/animation tooling for just the
  board.
- **Cons**: The direct-Kotlin-call integration boundary (including the
  per-frame info-card screen-position tracking) becomes a JNI/plugin-
  marshalled boundary; adds tens of MB to APK size; this specific
  "Godot-as-library-inside-a-Compose-app" configuration is a thin,
  little-travelled path with sparse precedent to lean on when it breaks.
- **Estimated Effort**: 4-7 weeks.
- **Rejection Reason**: Rejected in favor of the full rewrite — the project
  owner's stated ambition (a livelier, more expansive game) argued for
  Godot owning the whole app rather than a hybrid boundary that would need
  revisiting again later if that ambition grows further.

### Alternative 3: Unity

- **Description**: Rebuild in Unity.
- **Pros**: Mature toolchain.
- **Cons**: Revenue-gated licensing violates the project's hard
  free/open-source constraint; heavier runtime; more constrained embedding
  story than Godot's.
- **Estimated Effort**: Comparable to Alternative 2.
- **Rejection Reason**: Disqualified by the free/open-source constraint.

## Consequences

### Positive

- Unlocks Godot's built-in navmesh (`NavigationRegion3D`/`NavigationAgent3D`)
  and animation tooling (`AnimationPlayer`/`AnimationTree`) for the
  villager-AI and worker-assignment system, without hand-rolling pathfinding
- Single coherent engine and scene-authoring workflow going forward, instead
  of a Compose-app-with-an-embedded-Fragment split
- All 627 sourced CC0 Kenney `.obj`/`.mtl` models import natively, no
  conversion step
- Removes the ceiling the technical-director flagged as LibGDX's eventual
  limit if the game's ambition grows (VFX authoring, terrain tooling,
  physics, many concurrent animated characters)

### Negative

- Discards ~2,000 lines of verified LibGDX rendering code and the Compose UI
  (~1,900 lines), plus the 8 documented on-device bug fixes embedded in that
  code — their *lessons* carry forward (see Implementation Guidelines), but
  the working code does not
- No test suite exists to catch regressions during an 8-14 week rewrite;
  every migrated feature needs fresh manual on-device verification
- Team ramp-up cost on GDScript/C# and Godot's scene/node model, where the
  team previously worked in Kotlin only
- Does not, by itself, fix the original scale/art complaint — the same four
  root causes (layout span, unbounded terrain, unscaled models, naturalistic
  shading) must be solved again inside the new engine, and must be budgeted
  explicitly in the migration roadmap rather than assumed to be solved by
  the platform switch
- All in-flight reverse-documentation GDD work describing the current
  implementation (e.g. `design/gdd/crop-economy.md`) documents *mechanics*
  that should survive the migration, but its "Current Implementation"/API
  references will need updating once the Godot equivalents exist

### Neutral

- `VillageSnapshotMapper`'s tile-snapshot data model is engine-neutral and
  can likely carry forward conceptually even though its concrete Kotlin type
  and LibGDX-facing methods will not
- The farming economy's formulas (`design/gdd/crop-economy.md` and the four
  sibling docs still to be written) are engine-independent design content —
  unaffected by this ADR

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Migration takes materially longer than 8-14 weeks given no test suite and a language ramp-up | MEDIUM-HIGH | HIGH | Phase the roadmap into independently shippable/verifiable epics (see Migration Plan); re-baseline the estimate after the first phase lands |
| The four original scale/art causes get re-introduced in Godot (since migrating doesn't fix them automatically) | MEDIUM | MEDIUM | Migration roadmap must include an explicit village-board layout/shading epic, not just a 1:1 port of current LibGDX values |
| Regressions in the 8 documented bug-fix classes go unnoticed without a test suite | HIGH | MEDIUM | Per-phase on-device screenshot/interaction evidence into `production/qa/evidence/`, same discipline recommended against the smaller LibGDX fix |
| Godot version drifts from what's pinned mid-project, invalidating engine-reference docs | LOW-MEDIUM | MEDIUM | Run `/setup-engine` immediately to pin a version before implementation; treat any later version bump as requiring this ADR's re-verification (see Engine Compatibility note) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | Unmeasured (no budgets exist yet) | Unmeasured until a Godot baseline is established | 16.7ms (60fps) on target AVD — first formal budget, to be confirmed during roadmap planning |
| Memory | Unmeasured | Unmeasured | To be set during roadmap planning |
| Load Time | Unmeasured | Unmeasured (Godot runtime adds APK weight vs. LibGDX's small `.so`) | To be set during roadmap planning |
| APK Size | Current baseline not recorded | Expected increase — Godot's Android runtime is materially larger than LibGDX's native libs | To be set during roadmap planning |

## Migration Plan

This ADR authorizes the migration direction; the detailed phase/epic/story
breakdown is explicitly deferred to a dedicated technical-director +
producer planning pass (per the project owner's "full roadmap first"
choice), not compressed into this document. At minimum, that roadmap must
cover:

1. Update `CLAUDE.md` and `.claude/docs/technical-preferences.md` to name
   Godot 4 as the engine (this ADR's immediate follow-up)
2. Run `/setup-engine` to pin a specific Godot 4 version and populate
   `docs/engine-reference/godot/`
3. Phase the rewrite (indicative, to be refined by the roadmap): engine
   setup & asset import pipeline → core economy/state layer port → UI port
   (Compose → Control nodes) → village board (with the scale/art fix baked
   in, not deferred) → villager AI/worker-assignment → QA pass across every
   existing feature
4. Establish performance baselines and the first formal frame/memory/APK
   budgets once a Godot build exists to measure

**Rollback plan**: The current LibGDX/Compose implementation remains intact
on its existing branch/commits until the Godot migration reaches feature
parity and is verified on-device; no destructive changes to the current
working app happen as part of accepting this ADR. If the migration stalls or
proves substantially more costly than estimated, reverting to Alternative 1
(in-place LibGDX fix) remains available since none of that implementation is
deleted by this decision alone.

## Validation Criteria

- [ ] `CLAUDE.md`/`technical-preferences.md` updated to name Godot 4
- [ ] Godot version pinned via `/setup-engine`
- [ ] Migration roadmap (epics/stories) exists and is approved
- [ ] Full feature parity reached and verified on-device (economy, village
      board interactions, decorations, LiveOps)
- [ ] The four original scale/art causes are resolved in the Godot
      implementation (bounded/compact layout, filled tiles, flat/cartoonish
      shading)
- [ ] Villager roaming + worker-assignment system implemented per its design
      brief
- [ ] First formal performance budgets established and met

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables: the village-board presentation
layer, the decorations economy's visual placement, and the villager-AI /
worker-assignment system (design brief drafted this session, not yet
written to a GDD file). Constrains: all future rendering/UI work must target
Godot 4 rather than LibGDX/Compose from this point forward.

## Related

- Supersedes the engine pinning in `CLAUDE.md` and
  `.claude/docs/technical-preferences.md` ("None of Godot/Unity/Unreal") —
  both to be updated as an immediate follow-up to this ADR
- Should be accompanied by a retroactive ADR documenting why LibGDX was
  originally adopted (flagged as missing before this decision, per
  `.claude/docs/technical-preferences.md`'s Architecture Decisions Log) —
  worth writing for historical record even though it is now superseded
- Full technical-director analysis (four root causes, alternatives, code
  references) preserved in this session's transcript; not duplicated in full
  here to keep this ADR at a reviewable length
- Code (current, pre-migration): `core/src/main/kotlin/com/zonkrik/ifarming/village3d/`, `app/src/main/java/com/zonkrik/ifarming/ui/gdx/`
- Godot Android docs: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_library.html, https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html, https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
