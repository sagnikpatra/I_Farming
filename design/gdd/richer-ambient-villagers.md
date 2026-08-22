# Richer Ambient Villagers -- Idle Pauses

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
- Explicitly **not** in this pass (see Tuning Knobs for why it's
  deferred, not forgotten): day/night population thinning -- needs new
  spawn/despawn control this file's self-contained idle-pause change
  doesn't provide. Villager-to-villager congregating and point-of-
  interest lingering (both below) were originally deferred for a similar
  reason but have since been built.

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
  (Lingering) after the full population/grid exist.
- `village_snapshot_mapper.gd`: `point_of_interest_tiles()` -- the one
  place that turns raw `GameState.decorations` positions into walkable
  neighbor tiles, reusing the same `WalkableGrid` `build_walkable_grid()`
  already produces rather than a second occupancy pass.
- Does **not** touch `village_board.gd` or any economy/save code.

## 7. Tuning Knobs

- `IDLE_PAUSE_CHANCE`, `IDLE_DURATION_MIN_SEC`/`MAX_SEC`,
  `CONGREGATE_DISTANCE_TILES`, `POI_LINGER_CHANCE` -- all in
  `villager_roamer.gd`, easy to rebalance after on-device observation.
- **Future stretch**: day/night population thinning (fewer villagers
  outdoors at Night) -- real synergy with `design/gdd/real-time-day-night.md`
  (just built), but requires new spawn/despawn control in `VillagerSpawner`
  that doesn't exist yet.

## 8. Acceptance Criteria

- [ ] `Rig_Medium_General.glb` genuinely contains `Idle_A`/`Idle_B` clips
      on the same skeleton every character shares -- confirmed by direct
      glTF inspection (see this doc's Overview), not assumed.
- [ ] A villager occasionally stops walking, visibly plays an idle
      animation (not a T-pose or frozen-mid-stride glitch), then resumes
      walking on its own after a few seconds.
- [ ] The idle chance/duration are each independently unit-testable as
      pure logic, not coupled to real engine timing or `_process()`'s
      frame-delta accumulation directly.
- [ ] Assigned workers' own stationed behavior is unaffected -- verified
      by inspecting `worker_station.gd`/`WorkerAssignment` code paths
      untouched, not just by assumption.
- [ ] Full GUT suite green.
- [ ] Verified on-device: at least one villager observed genuinely
      idle-pausing (not just walking) during a real play session, no
      crash, no visual glitch (T-pose, frozen mid-stride, wrong
      orientation) during or after the idle animation.

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
- [ ] Two independently-idling villagers observed actually facing each
      other simultaneously (both sides of the "chat"), rather than only
      one tracking the other -- the logged evidence above confirms
      one-directional tracking works; catching the fully mutual case on
      video/screenshot is inherently probabilistic (needs two villagers
      idling within range at the same real moment) and wasn't separately
      captured. Not blocking: the shared pure function and per-roamer
      independence mean both sides run identical logic, so this is very
      likely already true, just not separately visually confirmed.

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
- [ ] Verified on-device that a villager actually walks toward and
      lingers near a real placed decoration -- **not captured**. The live
      save on the project owner's device had no decorations placed at
      verification time, and placing one would have needed a UI
      automation detour beyond this pass's scope; build/launch was
      confirmed clean (no crash, normal boot) the same way every other
      change this session was, and the wiring is covered end-to-end by
      the tests above through the real economy layer, but the specific
      "villager visibly gathers near a Lantern" visual moment is
      genuinely unconfirmed, not just unphotographed. Worth doing next
      time a save with decorations is available on-device.
