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
- Explicitly **not** in this pass (see Tuning Knobs for why each is
  deferred, not forgotten): villager-to-villager "congregating"/chatting,
  point-of-interest lingering near decorations, day/night population
  thinning. Each needs new cross-component data (other roamers' live
  positions, decoration tile positions, spawn/despawn control) that the
  self-contained idle-pause change here doesn't.

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
- `villager_roamer.gd`: the new Idle-Pause state and its transition logic.
- Does **not** touch `village_board.gd`, `VillagerSpawner`, `WalkableGrid`,
  or any `GameState`/economy code -- purely a self-contained roaming-
  controller + animation-loading change.

## 7. Tuning Knobs

- `IDLE_PAUSE_CHANCE`, `IDLE_DURATION_MIN_SEC`/`MAX_SEC` -- all in
  `villager_roamer.gd`, easy to rebalance after on-device observation.
- **Future stretch, explicitly out of scope this pass**: villager-to-
  villager "congregating" (two roamers pathing toward each other, both
  idle-pausing together as cheap readable "chatting") -- needs each
  `VillagerRoamer` to become aware of other roamers' live positions/state,
  which today's fully-independent-per-roamer architecture doesn't provide;
  a real architectural addition (a shared coordinator or roamer registry),
  not a small extension of this pass.
- **Future stretch**: point-of-interest lingering (biasing target
  selection toward tiles adjacent to player-placed decorations) -- needs
  decoration tile positions threaded from `village_board.gd`/
  `VillagerSpawner` down into `VillagerRoamer.setup()`, which isn't wired
  today; would give the cosmetic Decorations economy its first functional
  feedback loop, worth doing, just not bundled into this self-contained
  slice.
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
