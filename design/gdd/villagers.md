# Villagers — Design Document

---
**Status**: Implemented for its stated scope — live in the shipped game
**Source**: `v2.md`'s "living world" design pillar (line 89); `docs/architecture/godot-migration-roadmap.md`'s EPIC-M6 (Villager Asset Pipeline & Ambient Roaming)
**Date**: 2026-08-21
**Verified By**: 299/299 GUT tests, real-GPU windowed renders, and live on-device verification on the Medium_Phone AVD (see `production/session-state/active.md`'s 2026-08-21 entries)
**Implementation Status**: Fully implemented for the scope this document covers — asset sourcing, animation retargeting, visual pass (all 6 characters), GameState integration, roaming controller, population spawner, and live board wiring are all done. Open items are explicitly flagged inline (villager count ever reaching 0, and project-wide real-hardware/perf-budget work that isn't specific to villagers) — see Tuning Knobs and Edge Cases.
---

> **Scope note**: This document covers EPIC-M6 only — purely ambient,
> roaming villagers (now including the cosmetic tap greeting, rule 8).
> `v2.md` never describes villagers as having a gameplay-mechanical
> function on their own; the roadmap split that into a separate epic,
> **EPIC-M7 (Worker Assignment & Wage Economy)** — **update (2026-08-22):
> EPIC-M7 is complete**, not undesigned/out-of-scope as this note
> originally said; see `worker-economy.md` and the roadmap's own EPIC-M7
> section. Nothing in this document implies a *roaming* (unassigned)
> villager does anything but exist, walk, look alive, and now respond to
> a tap with flavor text — becoming a worker is a distinct scene/flow
> `worker-economy.md` owns.

---

## 1. Overview

Ambient, non-interactive villager NPCs that walk around the open ground of
the player's village board, so the farm reads as a lived-in place rather
than a static diorama of buildings and plots. This directly implements
`v2.md`'s original "living world" pillar: *"The environment must not feel
static; it requires continuous, ambient movement to create the illusion of
life... villagers going about their daily routines... will make the
village feel bustling and active."* Villagers have no economic function,
no player interaction, and no save-data footprint in this phase — they are
a rendering/presentation-layer feature only.

## 2. Player Fantasy

The player has built something real — a farmhouse, a market, a polyhouse
— and it should *feel* inhabited, not like an empty stage set the player
alone walks through. Seeing small figures moving between buildings while
the player manages crops and trades at the Mandi reinforces the sense that
this is a living village the player has grown, not just a spreadsheet of
timers. The fantasy is quiet and ambient, not a system the player is meant
to notice mechanically — closer to background birdsong than a minigame.

## 3. Detailed Rules

1. **v1 baseline (superseded 2026-08-22, kept as history)**: tapping a
   villager did nothing — no info card, no dialogue, no selection state.
   **Update**: this is no longer current — see rule 8 below and Tuning
   Knobs' "Tap interaction" row for the real, shipped shape (a read-only
   flavor-text greeting card, decided and built, not deferred any
   longer).
2. **No persistence.** Villagers are not part of `GameState` and are not
   saved. Positions/count re-randomize fresh each time the village board
   scene loads. This is a deliberate scope boundary, not an oversight — it
   keeps ADR-0002's clean-save-format surface from growing for a purely
   cosmetic system.
3. **Spawn area**: villagers only spawn on/walk across tiles that are
   *open ground* — not on a zone's building footprint, not on an occupied
   plot, not on a decoration's tile, not outside the board's fenced
   boundary. (`village_board.gd` already computes exactly this "reserved
   tiles" concept for zone-layout overlap validation via
   `VillageSnapshotMapper.max_reserved_tiles()` — the walkable-area
   calculation for roaming should reuse or mirror that, not invent a
   second occupancy system.)
4. **Movement is continuous.** A villager picks a random reachable open
   tile, walks to it at a fixed pace, and immediately picks another one —
   no standing-idle pauses in v1. This is a content constraint, not a
   design preference: the sourced animation library
   (`Rig_Medium_MovementBasic.glb`) has no natural standing-idle loop
   (only `T-Pose`, a rest bind pose, and `Jump_Idle`, which is a mid-air
   pose). This v1 constraint was later resolved: `Rig_Medium_General.glb`
   was inspected (2026-08-22) and does have real `Idle_A`/`Idle_B` clips,
   which `richer-ambient-villagers.md`'s Idle-Pause feature now uses —
   see that document, not this one, for the current standing-idle
   behavior (this section stays as the historical v1 baseline it was
   written against).
5. **Villagers ignore the player entirely, except the tap greeting in
   rule 8.** No pathing around the player's camera, no awareness of game
   economy state (a villager doesn't "go to" the Mandi when the player
   sells crops, etc.) — that broader kind of reactivity is still
   explicitly future scope. The one narrow exception is the read-only
   tap card (rule 8), which shows information but never changes a
   villager's behavior, path, or state — a villager tapped mid-walk
   keeps walking exactly as it would have, unaffected.
6. **Villagers survive a board rebuild.** `village_board.gd`'s `rebuild()`
   only touches `StaticLayer`; villagers live in the pre-existing
   `ActorLayer`, which `rebuild()` already documents as untouched. A
   villager's current walk target becomes stale if a zone the player just
   dragged now overlaps it mid-walk — see Edge Cases §5.
7. **Character roster**: all 6 KayKit characters spawn, each villager
   assigned a random character key for visual variety. Every fantasy prop
   (Knight's helmet/visor, Mage's hat, Barbarian's bear-hat,
   Rogue/Rogue_Hooded's mask, every character's cape) is hidden via a
   mesh-name keep-list — see `godot/scripts/village_board/villager.gd`'s
   `_KEEP_MESH_SUFFIXES` — leaving just body/head/arms/legs, then
   re-colored per Detailed Rules above. Visually confirmed 2026-08-21 (a
   side-by-side render of all 6, then live on the real production board).
   One accepted exception: `rogue_hooded`'s hood is sculpted into its
   Head mesh, not a separate prop, so it keeps a hooded silhouette —
   judged an acceptable look (a farmer wearing a hood), not a defect.
8. **Tap interaction (decided and built 2026-08-22)**: a roaming
   (unassigned) villager gets its own pickable `Area3D`, added as a
   sibling of its `Villager` child inside `VillagerRoamer` so it moves
   automatically with the villager (no manual repositioning needed,
   unlike the static zone/decoration `PickArea`s). Tapping it opens a
   small, read-only card — the same `BottomSheet` primitive every other
   info card/sheet in this project already uses, not a new UI
   primitive — showing the character's emoji, its class display name
   (`Villager.CHARACTER_DISPLAY_NAMES`, the same names
   `worker_assignment_row.gd` already shows for an *assigned* villager,
   moved to `Villager` itself so both files share one source instead of
   duplicating the dictionary), and a localized "Namaste! 🙏" greeting.
   No action button, no selection highlight (matches
   `decoration_info_card.gd`'s precedent: purely informational taps
   don't get the zone/plot footprint-highlight treatment). A villager
   currently stationed at a `WorkerStation` (an assigned worker) is a
   **different scene entirely**, not a `VillagerRoamer` — explicitly out
   of scope for this pass; tapping one falls through to whatever
   zone/plot is underneath, unchanged from before.

## 4. Formulas

| Formula | Expression | Purpose | Status |
|---|---|---|---|
| Villager count | `clamp(2 + floor(unlockedZoneCount × 0.75), 2, 6)` | Scales visible "life" with player progression — more unlocked structures reads as a bigger, busier village, reinforcing the player-fantasy sense of growth | 🔶 Proposed, not balance-tested |
| Walk speed | `1.2 tiles/second` (matches `TILE_SIZE = 1.0` in `village_board.gd`) | A natural, unhurried walking pace at the board's existing zoom level | 🔶 Proposed, needs on-device visual tuning |
| Repath interval | Immediately on arrival (no dwell) | Keeps movement continuous per Detailed Rules §4 | Follows from the no-idle-clip constraint above |
| Spawn/repath exclusion margin | `0.5 tiles` around any zone/plot/decoration footprint | Prevents a villager's walk path from visually clipping through a building or crop | 🔶 Proposed, needs on-device visual tuning |

`unlockedZoneCount` counts the player's unlocked structure zones
(Farmhouse and Mandi always count; Polyhouse/Agroforestry/Aquaculture/
Vertical Farm count once unlocked) — the same boolean flags
`land-and-structures.md` §2.3 already documents
(`hasPolyhouse`/`hasAgroforestry`/`hasAquaculture`/`hasVerticalFarm`).

**Worked example**: a player with just Farmhouse + Mandi unlocked
(`unlockedZoneCount = 2`) gets `clamp(2 + 1, 2, 6) = 3` villagers. A player
with all 6 zones unlocked gets `clamp(2 + 4, 2, 6) = 6` villagers (the cap).

## 5. Edge Cases

**Implemented (2026-08-21)**:
- A villager's walk target tile becomes occupied mid-walk (player just
  dragged a zone onto it): rather than a per-villager repath, the whole
  population resyncs whenever the board's walkable-tile set actually
  changes (`village_board.gd`'s `_sync_villagers_if_needed()`, triggered
  both by `persist_and_rebuild_if_dirty()` and directly by
  `try_commit_zone_move()` on a successful drag) — simpler than
  per-villager repathing and consistent with the "population changes are
  rare, simplicity wins" reasoning already used for population-count
  resyncs. Covered by a regression test
  (`test_try_commit_zone_move_resyncs_villagers_on_a_successful_move`).
- Confirmed numerically, not assumed: a fresh game (only Farmhouse +
  Mandi unlocked, the most conservative reservation state) has 63 of 120
  tiles (52%) walkable — comfortably enough room for the formula's 2-6
  villagers. See `docs/architecture/godot-migration-roadmap.md`'s EPIC-M6
  section for the check.
- A management sheet (`BottomSheet`) is open, covering most of the screen:
  villagers keep walking/animating underneath, unpaused — there's no
  reason to pause a purely cosmetic background system just because a UI
  panel is open.
- Board camera is panned/zoomed away from where a villager currently is:
  no special handling needed — they keep walking off-camera exactly as
  on-camera, same as any other Node3D.

**Unclear — needs a decision or more source material**:
- ❓ Should villager count ever go to 0 (e.g. a fresh save with nothing
  unlocked yet)? The formula's `clamp` floor of 2 says no — always at
  least 2 villagers visible from the very first Farmhouse+Mandi state.
  Confirm that's the intended earliest-game feel, not "the village should
  look truly empty until the player has built something."

## 6. Dependencies

**Technical Dependencies**:
- `godot/scripts/village_board/villager.gd` (`Villager` class) — already
  built and verified this session (character instancing, animation
  retargeting, toon-shading + accent recolor). This document's rules are
  what should drive a *new* roaming-controller component built on top of
  it, not a rewrite of it.
- `village_board.gd`'s `ActorLayer`, `_grid_to_world()`/`world_to_grid()`,
  and (for the exclusion-margin rule) `VillageSnapshotMapper.max_reserved_tiles()`
- Godot's `NavigationRegion3D`/`NavigationAgent3D` — **update**: not what
  actually shipped. The implementation deliberately deviated to a
  hand-rolled `WalkableGrid` BFS pathfinder instead (see that class's own
  doc comment) -- the board is a small, fixed 10×12 grid, so a
  headless-testable custom pathfinder was simpler and avoided a
  HIGH-knowledge-risk Godot 4.7 subsystem this project had never used,
  consistent with `technical-preferences.md`'s existing preference for
  lightweight hand-rolled systems over heavier engine subsystems.
- `Rig_Medium_General.glb` (sourced, sitting in `assets_3d/kaykit-adventurers/`)
  — **update**: inspected 2026-08-22 (see `villager.gd`'s own comment on
  its `IDLE_CLIP_NAMES` constant), found 15 real clips including
  `Idle_A`/`Idle_B`, both now in live use by the Idle-Pause feature.

**Design Dependencies**:
- `land-and-structures.md` — this doc's `unlockedZoneCount` formula input
  reads that doc's structure-unlock boolean flags directly (§2.3);
  `land-and-structures.md`'s own Dependents section already notes this
  (bidirectional-dependency rule satisfied, confirmed 2026-08-22).
- `docs/architecture/godot-migration-roadmap.md`'s EPIC-M6 section — the
  engineering-status source of truth this document's design should stay
  consistent with
- `worker-economy.md` (EPIC-M7) — reads/removes from this document's
  villager roster when a villager is assigned as a worker; an assigned
  villager is no longer part of the ambient-roaming population this
  document owns. This document has no dependency back on
  `worker-economy.md`'s wage/automation mechanics. See this doc's own
  **Dependents** entry below for the reverse direction.

**Dependents**:
- `worker-economy.md` — this document's entire worker roster *is*
  `villagers.md`'s villager roster; assigning a worker removes that
  character from `VillagerSpawner`'s ambient-roaming population this
  document owns. Confirmed present in `worker-economy.md`'s own
  Dependencies section too (2026-08-22).

**Content Dependencies**:
- `assets_3d/README.md`'s "Rigged characters" section — licensing/sourcing
  record for the KayKit Adventurers pack this whole system is built on
- **Update**: all 6 sourced characters (Barbarian/Knight/Mage/Ranger/
  Rogue/Rogue_Hooded) shipped in EPIC-M6 with visual variety, confirmed
  live in `villager.gd`'s `CHARACTER_SCENES` — matches Tuning Knobs §7's
  "Character roster size" row, which already reflects this correctly.

## 7. Tuning Knobs

| Knob | Safe Range | Affects | Notes |
|---|---|---|---|
| Villager count formula's cap | 2–6 (current proposal) | Visual density vs. performance | Measured 2026-08-21 on the AVD emulator: 6 villagers cost no detectable FPS/frame-time difference vs. zero (see roadmap's EPIC-M6 section). Real-hardware testing and a formally adopted project-wide performance budget (EPIC-M0) remain open, so treat this as a real but not final data point, not a closed question. |
| Walk speed | 0.8–2.0 tiles/sec | Player-fantasy "feel" (too slow reads as sluggish, too fast reads as frantic/unnatural for a farm) | Needs on-device visual tuning, not a formula-derived value |
| Exclusion margin | 0.3–0.7 tiles | Whether villagers visibly clip through buildings/crops vs. look like they're avoiding a wider berth than necessary | Needs on-device visual tuning |
| Character roster size | 6 (all sourced characters, current) | Visual variety | All 6 visually confirmed 2026-08-21 with prop-hiding + accent-recolor applied (side-by-side render, then live on the real board) — see `godot/scripts/village_board/villager.gd`'s `_KEEP_MESH_SUFFIXES`. Sourcing a 7th+ character remains open future work, not required. |
| Tap interaction | **On, cosmetic-only (2026-08-22)** | Whether villagers become an interactive system at all | **Decision made**: tapping a roaming (unassigned) villager shows a small, read-only greeting card — emoji + class display name + "Namaste! 🙏", localized (English/Hindi, per `docs/architecture/localization-pipeline.md`). Deliberately stays purely cosmetic, not mechanical: no reward, no new `GameState` field, nothing persisted, no action button — the same boundary EPIC-M7's worker system already exists on the other side of. A stationed `WorkerStation` villager is explicitly **not** in scope for this pass (a different node/scene entirely, not `VillagerRoamer`) — tapping one still falls through to whatever the underlying zone/plot resolves to, unchanged. See §3 Detailed Rules for the full shape. |

## 8. Acceptance Criteria

**What Exists Today (2026-08-21)**:
- [x] At least 2, at most 6, villagers visible on the board at any time,
      per the count formula in §4 — `VillageSnapshotMapper.villager_count()`,
      wired live via `VillagerSpawner`
- [x] Villagers walk continuously between random open-ground tiles, never
      standing frozen and never walking through/inside a zone, plot, or
      decoration's footprint — `WalkableGrid` + `VillagerRoamer`, verified
      both headlessly (BFS pathfinding tests, including routing around an
      obstacle) and visually (real-GPU renders, live on-device)
- [x] Villagers survive a `village_board.gd` `rebuild()` without
      disappearing, duplicating, or crashing — `ActorLayer` is untouched
      by `rebuild()` by construction; population resyncs only when the
      walkable-tile set actually changes (§3.6/Edge Cases)
- [x] No new fields added to `GameState` or the save format for this
      system — `VillagerSpawner` re-randomizes fresh each `sync()`, no
      persistence anywhere in the chain
- [x] **Superseded 2026-08-22** — this criterion described the v1
      baseline (no `PickArea` registered at all). Tap interaction is now
      built (rule 8, §3) — see the new criteria immediately below for
      its own acceptance bar, which replaces this one rather than
      contradicting it.
- [x] Tapping a roaming villager opens a real, localized greeting card
      (emoji + class name + "Namaste! 🙏"), verified via a real headless
      test that drives the actual `PickArea`/`BoardInteractor` dispatch
      path, not just the card's own construction in isolation
- [x] Tapping a villager never changes its walk state, target, or
      position — the greeting is purely informational
- [x] A `WorkerStation`-stationed (assigned) villager is unaffected —
      confirmed it's a different scene/node entirely, not routed through
      this new tap path at all
- [x] On-device frame time with the maximum villager count (6) measured:
      no detectable difference vs. zero villagers on the Medium_Phone AVD
      emulator (55-57 FPS either way). **Caveat, not fully closed**: this
      is the emulator, not real hardware, and no formal FPS/frame-time
      budget has ever been adopted project-wide (EPIC-M0) to grade this
      against — see `docs/architecture/godot-migration-roadmap.md`'s
      EPIC-M6 section for the full numbers and caveat.

**What Exists**: `Villager` (character instancing, animation retargeting,
toon-shading, prop-hiding, accent recolor — all 6 characters),
`WalkableGrid` (pure BFS pathfinding), `VillagerRoamer` (continuous
movement), `VillageSnapshotMapper.build_walkable_grid()`/
`villager_count()` (real GameState integration), `VillagerSpawner`
(population management), and live wiring into `village_board.gd`
(`_sync_villagers_if_needed()`, triggered by both routine state changes
and zone drags). 299/299 GUT tests passing.

---

**Next Steps**: This document's EPIC-M6 scope is complete. Two items
remain genuinely open, both flagged inline rather than silently assumed
resolved:
1. §5's "should villager count ever reach 0 early-game" question — still
   the user's call, not addressed by implementation (the formula's floor
   of 2 already answers it in practice; whether that's the *intended*
   answer is unconfirmed)
2. Real-hardware testing and a formally adopted performance budget — this
   is EPIC-M0 project-wide scope, not specific to villagers, and was
   never going to be resolved by this document's work

Beyond this document: EPIC-M7 (Worker Assignment & Wage Economy) is a
separate, unwritten GDD — see this document's own Scope note at the top.

**Related Skills**: `/design-review design/gdd/villagers.md`, `/balance-check` (once the count/speed formulas have real on-device data to tune against)

---

*Authored 2026-08-21 in response to "continue with the villager GDD", following EPIC-M6's asset-sourcing, animation-retargeting, and first-visual-pass work earlier the same session.*
