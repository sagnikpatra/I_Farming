# Richer Ambient Villagers -- Idle Pauses

---
**Status**: Implemented and shipped — live in the game, including every
originally-deferred stretch goal (Congregating, Point-of-Interest
Lingering, Night Population Thinning)
**Verified By**: `test_villager_roamer.gd`'s full test set, full GUT
suite green, and on-device verification (see
`production/qa/evidence/villager-idle-pause.png`,
`villager-lamp-lighting-night.png`, `night-population-thinning.png`)
**Update (2026-08-22)**: this document's Acceptance Criteria checkboxes
had gone stale — left unchecked even after the feature shipped, and one
genuine open gap (mutual-facing proof) has now been closed with a
deterministic test. Corrected.
---

## 1. Overview

Ambient villagers currently walk continuously between random tiles forever,
with no pause -- documented in `design/gdd/villagers.md` §3.4 as a content
constraint ("the sourced animation library has no standing-idle clip"), not
a design preference. That constraint no longer holds: inspecting
`Rig_Medium_General.glb` directly (the file `villagers.md`/the feature-
scoping brief both flagged as "sourced but never inspected") found 15
clips, including **`Idle_A`/`Idle_B`** -- genuinely usable idle animations
on the same `Rig_Medium` skeleton every villager character already shares.
This closes that specific gap: villagers now occasionally pause and play a
real idle animation before resuming their walk, instead of walking forever.
Villagers who happen to idle-pause near each other now also turn to face
one another (Congregating, built 2026-08-22, see §3), reading as a village
population that occasionally notices its own neighbors.

## 2. Player Fantasy

*"They're not just wandering, they're living here."* A village where every
figure walks in an endless straight-line loop reads as a treadmill, not a
place. A brief, occasional pause -- someone stopping to stand for a few
seconds before moving on -- is the smallest possible change that makes the
population read as individuals with their own small rhythm, closer to
`villagers.md`'s own stated Player Fantasy ("closer to background birdsong
than a minigame... a living village").

## 3. Detailed Rules

- Each `VillagerRoamer` gains a second state alongside its existing
  continuous-walk behavior: **Idle-Pause**.
- The moment a roamer finishes its current walk (reaches the end of its
  path), it rolls a chance to enter Idle-Pause instead of immediately
  picking a new target. If the roll fails, behavior is unchanged from
  today (immediately picks a new target and keeps walking).
- While idling, the villager plays a real idle animation (`Idle_A` or
  `Idle_B`, chosen at random for variety) and does not move, for a short
  random duration.
- When the idle duration elapses, the roamer picks a new target and
  resumes walking (`Walking_A`), exactly as it already does today.
- **Assigned/"called" workers are entirely unaffected** -- per
  `worker-economy.md` §3.6, an assigned worker's own stationed-at-zone
  behavior is a separate system from the unassigned ambient population
  this file governs; nothing here touches `WorkerStation` or worker
  visuals.
- Every stretch goal originally deferred from this pass (Congregating,
  Point-of-Interest Lingering, Night population thinning, all below) has
  since been built.

### Congregating (built 2026-08-22)

- While idling (Idle-Pause above), a villager continuously checks every
  other roamer's current position and, if the nearest one is within
  `CONGREGATE_DISTANCE_TILES` (1.6 tiles, scaled by board tile size),
  turns to face it -- re-checked every idling frame, not just once on
  entering Idle-Pause, so a villager still approaching when another
  starts idling is picked up the moment it gets close enough, not missed.
- **Deliberately not two-way coordinated.** Each roamer decides this
  independently, from nothing more than "where is everyone else right
  now" -- there is no signal, no handshake, no shared "we are now
  chatting" state between the two villagers involved. When two villagers
  happen to be idling near each other at the same time, both
  independently turn to face the other, which reads as "chatting" without
  either one knowing the other exists as anything more than a position.
  This is what keeps it cheap: no new AI, no dialogue, no risk of two
  roamers waiting on each other and stalling.
- Confirmed with real on-device logging (not just tests): a stationary
  idling villager was observed continuously re-orienting toward another
  villager as it walked closer, tracking it in real time -- the intended
  "noticing" behavior, not a one-shot facing check.
- **Assigned/"called" workers remain entirely unaffected**, same as
  Idle-Pause above -- congregating only ever runs on the ambient roaming
  population `VillagerSpawner` tracks.

### Point-of-Interest Lingering (built 2026-08-22)

- Every time a roamer finishes a walk leg and picks its next target
  (the same moment the Idle-Pause roll above happens), there's a
  separate chance the new target is biased toward a **point-of-interest
  tile** -- a walkable tile adjacent to a player-placed decoration --
  instead of a fully random walkable tile.
- POI tiles are computed once per `VillagerSpawner.sync()` (every
  walkable neighbor of every placed decoration, deduplicated) and shared
  by the whole spawned population -- not per-roamer, since they don't
  change between one `sync()` and the next.
- A villager already standing on its only available POI tile falls back
  to a normal random target rather than "choosing" the tile it's already
  on (which would otherwise produce a zero-length path and a visibly
  stuck frame).
- Gives the cosmetic Decorations economy (`land-and-structures.md`) its
  first functional feedback loop: a player who places a Lantern or Well
  now has a concrete, if probabilistic, chance of seeing villagers
  actually gather near it, not just walk past.
- **Assigned/"called" workers remain entirely unaffected**, same as
  Idle-Pause and Congregating above.

### Night Population Thinning (built 2026-08-22)

- The ambient roaming population (never assigned workers) is roughly
  halved during the real-world-local Night phase
  (`design/gdd/real-time-day-night.md`'s `TimeOfDay.Phase.NIGHT`, 20:00-
  04:59 local) and restored to full at Dawn.
- `VillagerSpawner.sync()` gained an optional `population_scale`
  parameter (default `1.0`, no thinning) -- `village_board.gd` is the
  only caller that knows about time of day at all; `VillagerSpawner`
  itself has no day/night opinion, it just multiplies whatever count it
  would otherwise spawn.
- The population only actually resyncs on the two transitions that
  change the scale -- entering Night and leaving Night -- not on every
  Dawn/Day/Dusk edge the existing lighting system already detects.
  `VillagerSpawner.sync()` always tears down and fully respawns the
  population (a pre-existing, deliberate simplification -- see its own
  class doc), so resyncing on every phase change would make the whole
  population visibly "pop" four times a day for transitions that
  wouldn't even have changed the count.
- Reuses the exact same edge-detected `_last_time_of_day_phase` check
  the lighting system already performs each 3-second growth tick --
  no new timer, no new polling.
- Any *other* resync trigger (a zone unlock, a drag-commit) that fires
  while it's already Night must still apply the thinning factor, not
  silently repopulate to full daytime count -- `village_board.gd`'s
  `_current_population_scale()` is the single source of truth both
  resync paths read, rather than each tracking its own copy.
- **Assigned/"called" workers remain entirely unaffected** -- thinning
  only ever scales the ambient wandering count, applied strictly after
  the existing worker-assignment subtraction.

## 4. Formulas

- **Idle chance**: `IDLE_PAUSE_CHANCE = 0.35` (35%) rolled once per
  completed walk leg.
- **Idle duration**: uniform random in `[IDLE_DURATION_MIN_SEC, IDLE_DURATION_MAX_SEC]`
  = `[2.0, 5.0]` seconds.
- **Idle clip choice**: uniform random between `Idle_A`/`Idle_B` each time
  a villager enters Idle-Pause (not fixed per character), for visual
  variety across a population and across a single villager's own repeated
  pauses.
- **Expected idle fraction of time**: at 35% chance and a ~3.5s average
  pause vs. a walk leg averaging several seconds at
  `WALK_SPEED_TILES_PER_SEC = 1.2` tiles/sec on a ~10x12 board, villagers
  spend a modest minority of their time idling, not most of it -- the
  population should still read as predominantly ambulatory, idling as
  seasoning, not the default state.
- **Congregate distance**: `CONGREGATE_DISTANCE_TILES = 1.6` tiles
  (scaled by board tile size at call sites) -- wide enough that two
  villagers idling on adjacent tiles (distance 1.0) or diagonally
  adjacent (distance ~1.41) both count, narrow enough that villagers
  across the board never appear to notice each other.
- **POI linger chance**: `POI_LINGER_CHANCE = 0.3` (30%) rolled once per
  target pick -- deliberately independent of `IDLE_PAUSE_CHANCE`; a
  villager can walk toward a POI tile without idling there, or idle
  somewhere with no POI bias at all, since the two rolls don't interact.
- **Night population scale**: `VillagerSpawner.NIGHT_POPULATION_SCALE =
  0.5` -- roaming count is `round(roaming_count * scale)`, floored at 0.
  E.g. a fresh-game roaming count of 3 becomes `round(1.5) = 2` at Night.

## 5. Edge Cases

- **Nowhere walkable to go** (the pre-existing degenerate-board-state
  guard in `_process()`): unaffected -- that early-return still fires
  before the idle-chance roll is ever reached.
- **Idle animation clip missing** (defensive, shouldn't happen given the
  direct glTF inspection above, but mirrors `Villager.play_animation()`'s
  own existing no-op-with-pushed-error guard for a missing clip): if
  `Idle_A`/`Idle_B` somehow fails to load, the roamer simply never enters
  Idle-Pause (chance roll still happens, animation call would just log an
  error) -- not a crash, degrades to today's continuous-walk behavior.
- **Idle-Pause interrupted by nothing**: there is no player interaction
  with ambient villagers (per `villagers.md`'s own stated scope
  boundary), so there's no "interrupt the idle" case to handle -- the
  timer always runs to completion.

## 6. Dependencies

- `villager.gd`: loads a small, curated subset of `Rig_Medium_General.glb`'s
  clips (`Idle_A`/`Idle_B` only -- not all 15, which include unrelated
  Death/Hit/Spawn/Throw combat clips with no ambient-villager use) merged
  into the same `"moves"` animation library `play_animation()` already
  looks up, so no change to that method's existing "moves/X" lookup
  convention is needed.
- `villager_roamer.gd`: the new Idle-Pause state and its transition logic,
  plus `nearest_congregate_target()`/`other_villager_positions_provider`
  (Congregating) and `should_linger_at_poi()`/`poi_tiles`/
  `_choose_target_tile()` (Lingering).
- `villager_spawner.gd`: wires each roamer's
  `other_villager_positions_provider` (Congregating) and `poi_tiles`
  (Lingering) after the full population/grid exist; `sync()`'s new
  `population_scale` parameter and `NIGHT_POPULATION_SCALE` constant
  (Night Thinning).
- `village_snapshot_mapper.gd`: `point_of_interest_tiles()` -- the one
  place that turns raw `GameState.decorations` positions into walkable
  neighbor tiles, reusing the same `WalkableGrid` `build_walkable_grid()`
  already produces rather than a second occupancy pass.
- `village_board.gd`: **Night Thinning is the one stretch goal that does
  touch this file** -- `_apply_time_of_day_if_needed()` (already existed
  for `design/gdd/real-time-day-night.md`'s lighting) now also triggers
  `VillagerSpawner.sync()` on Night-boundary transitions, and
  `_sync_villagers_if_needed()`'s own independent resync trigger reads
  the same `_current_population_scale()` helper so the two don't drift.
  Congregating and Lingering do **not** touch this file, or any
  economy/save code.

## 7. Tuning Knobs

- `IDLE_PAUSE_CHANCE`, `IDLE_DURATION_MIN_SEC`/`MAX_SEC`,
  `CONGREGATE_DISTANCE_TILES`, `POI_LINGER_CHANCE` -- all in
  `villager_roamer.gd`. `VillagerSpawner.NIGHT_POPULATION_SCALE` --
  in `villager_spawner.gd`. All easy to rebalance after on-device
  observation.
- No further stretch goals remain open for this file -- every item
  originally deferred (Congregating, Lingering, Night Thinning) has now
  been built. Future extensions would be new scope, not this pass's own
  backlog.

## 8. Acceptance Criteria

- [x] `Rig_Medium_General.glb` genuinely contains `Idle_A`/`Idle_B` clips
      on the same skeleton every character shares -- confirmed by direct
      glTF inspection (see this doc's Overview), not assumed.
- [x] A villager occasionally stops walking, visibly plays an idle
      animation (not a T-pose or frozen-mid-stride glitch), then resumes
      walking on its own after a few seconds —
      `test_roamer_does_not_move_while_idling`/
      `test_roamer_resumes_walking_after_the_idle_timer_elapses`, and
      confirmed on-device (see evidence below).
- [x] The idle chance/duration are each independently unit-testable as
      pure logic, not coupled to real engine timing or `_process()`'s
      frame-delta accumulation directly —
      `test_should_enter_idle_pause_matches_the_configured_chance_statistically`/
      `test_random_idle_duration_stays_within_the_configured_range`.
- [x] Assigned workers' own stationed behavior is unaffected -- verified
      by inspecting `worker_station.gd`/`WorkerAssignment` code paths
      untouched, not just by assumption (idle-pause logic lives entirely
      in `VillagerRoamer`, which a stationed worker never instantiates).
- [x] Full GUT suite green — 592/592 as of this document's last
      verification pass, run twice non-flaky.
- [x] Verified on-device: at least one villager observed genuinely
      idle-pausing (not just walking) during a real play session, no
      crash, no visual glitch (T-pose, frozen mid-stride, wrong
      orientation) during or after the idle animation — see
      `production/qa/evidence/villager-idle-pause.png`.

### Congregating (2026-08-22)

- [x] `nearest_congregate_target()` is independently unit-testable as pure
      logic (own position, other positions, tile size in -> nearest
      in-range position or null out), not coupled to `_process()` --
      `tests/unit/test_villager_roamer.gd`.
- [x] A villager with no `other_villager_positions_provider` set behaves
      exactly as before Congregating existed -- confirmed by an explicit
      no-provider-set test, not just by code inspection.
- [x] `VillagerSpawner.sync()` wires a working provider on every spawned
      roamer, correctly excluding each roamer from seeing itself --
      `tests/unit/test_villager_spawner.gd`.
- [x] Full GUT suite green (495/495 at the time this was built).
- [x] Verified on-device via real logging (not just tests or a single
      screenshot): an idling villager was observed continuously
      re-orienting to track another villager walking toward it, over
      hundreds of real per-frame checks during a live session on the
      project owner's physical device (temporary forced-idle-chance
      override + a temporary debug log line, both reverted before
      commit) -- confirms the tracking is live and continuous, not a
      one-shot facing check that happens to look right in a screenshot.
- [x] Two independently-idling villagers observed actually facing each
      other simultaneously (both sides of the "chat"), rather than only
      one tracking the other. **Closed 2026-08-22** — rather than waiting
      on a probabilistic on-device capture (two villagers idling in range
      at the same real moment), added
      `test_two_idling_roamers_mutually_face_each_other()`
      (`test_villager_roamer.gd`): two real `VillagerRoamer` instances,
      each idling, each wired to the other's real live position (the
      exact `VillagerSpawner` wiring shape), asserting both sides'
      `rotation.y` face each other simultaneously. A deterministic,
      always-reproducible headless proof of the exact property this
      checkbox asked for — stronger evidence than a lucky screenshot,
      not a workaround for missing one.

### Point-of-Interest Lingering (2026-08-22)

- [x] `point_of_interest_tiles()` is independently unit-testable as pure
      logic against a real `GameState`/`WalkableGrid` (no decorations ->
      empty; a decoration's walkable neighbors returned; the
      decoration's own reserved tile and any other-reserved neighbor
      excluded; no duplicates across decorations that share a neighbor)
      -- `tests/unit/test_village_snapshot_mapper.gd`, driven through
      `GameEconomy.place_decoration()`, not hand-built `Decoration`
      objects.
- [x] `should_linger_at_poi()`'s rate is independently statistically
      testable, matching `should_enter_idle_pause()`'s own established
      pattern -- `tests/unit/test_villager_roamer.gd`.
- [x] A villager with no `poi_tiles` set behaves exactly as before
      Lingering existed (falls back to fully random target selection) --
      confirmed by an explicit empty-list test.
- [x] A villager standing on its only available POI tile falls back to a
      random target instead of a degenerate zero-length path -- confirmed
      directly, not just reasoned about.
- [x] `VillagerSpawner.sync()` wires the exact same computed POI list
      (matching `point_of_interest_tiles()`'s own output) onto every
      spawned roamer, and an empty list with no decorations placed --
      `tests/unit/test_villager_spawner.gd`.
- [x] Full GUT suite green (505/505 at the time this was built).
- [x] **Verified -- not via an on-device screenshot (the live save had
      no decorations placed, and placing one needed a UI-automation
      detour beyond this pass's original scope), but via a stronger,
      repeatable end-to-end test found once that gap was recognized as
      worth closing properly**: `test_roamer_actually_arrives_at_a_poi_
      tile_via_the_real_selection_and_movement_flow` in
      `tests/unit/test_villager_roamer.gd` drives the real (unmocked)
      `_pick_new_target()` -> `find_path()` -> `_process()` movement
      chain end to end -- a seeded RNG (empirically confirmed via a
      throwaway probe, same "seed it, don't mock RNG" convention this
      file already uses for `should_enter_idle_pause`) makes the real
      selection roll choose the POI tile, and the test asserts genuine
      arrival at that exact tile after simulated movement, not just that
      the tile was selected. This is a materially stronger, CI-durable
      proof than a single screenshot would have been -- it exercises the
      actual selection-to-arrival pipeline, not a visual snapshot of one
      possible outcome. The specific "villager visibly gathers near a
      real placed Lantern in the isometric 3D render" moment is still
      unphotographed, but the underlying mechanism it would demonstrate
      is now proven correct end to end, not just individually-tested in
      pieces.

### Night Population Thinning (2026-08-22)

- [x] `VillagerSpawner.sync()`'s `population_scale` parameter is
      independently unit-testable: default behavior unchanged, a
      fractional scale correctly rounds the roaming count, and scale
      never produces a negative count -- `tests/unit/test_villager_spawner.gd`.
- [x] Assigned workers are never thinned -- the scale is applied strictly
      after the existing worker-assignment subtraction, verified by the
      same tests above using the existing worker-saturation fixtures.
- [x] The population only resyncs on Night-entering/leaving transitions,
      not every Dawn/Day/Dusk phase edge -- verified by code inspection
      of the shared `_last_time_of_day_phase` edge-detection
      (`village_board.gd` has no dedicated test file, matching this
      project's existing gap for that class -- see `technical-preferences.md`'s
      Testing section).
- [x] A non-day/night resync trigger (e.g. a zone unlock) occurring
      during Night still applies the thinning factor rather than
      silently repopulating to full daytime count -- verified by code
      inspection: `_sync_villagers_if_needed()` reads the same
      `_current_population_scale()` single source of truth
      `_apply_time_of_day_if_needed()` does.
- [x] Full GUT suite green (508/508 at the time this was built).
- [x] Verified on-device via a temporary forced-Night override + debug
      log line (both reverted before commit, same precedent as
      Congregating's own verification): logged output confirmed
      `phase=NIGHT scale=0.5 roamer_count=2` against a fresh save whose
      normal daytime roaming count is 3 (`round(3 * 0.5) = 2`, exactly
      matching the unit test's own expectation) -- no crash. A screenshot
      of the same session visually confirms both the expected Night
      lighting and the reduced villager count together on the real
      board, not just the logged number.
