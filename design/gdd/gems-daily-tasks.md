# Gems &amp; Daily Tasks

## 1. Overview

A secondary currency ("Gems") earned exclusively by completing a small,
real-calendar-day-anchored set of daily tasks. Three tasks are drawn each
local day from a template pool of five, each reusing an existing player
verb (harvest, sell, plant, worker-cycle) -- no new gameplay mechanics,
purely a reward wrapper around actions the player already takes. Gems have
exactly one spend this pass: rerolling today's task set before any of it
is completed. Deliberately walled off from the rupee economy -- no
gem-to-rupee or rupee-to-gem exchange, no path to buy power.

## 2. Player Fantasy

*"A short, easy win, every single day."* This is the game's first
calendar-day-anchored macro-loop hook -- every other recurring system
(Monsoon, Festival Pass, Chanda Visit) runs on a fixed wall-clock cycle
with no real-calendar awareness, so none of them give a genuine "come back
tomorrow" pull. Daily Tasks are meant to feel like the lightest possible
daily check-in: three small, already-familiar actions, a couple of gems
each, done in under a minute if the player was already going to play
anyway.

## 3. Detailed Rules

- Each **local calendar day** (device timezone, real midnight -- not a
  wall-clock-modulo cycle like every other LiveOps system in this
  project), 3 tasks are drawn from a 5-entry template pool
  (`GameData.DAILY_TASK_POOL`), deterministically seeded by the day itself
  (same date -> same 3 tasks, reproducible, no save-scumming randomness).
- Each task tracks progress toward a target count. Progress is driven by
  hooking the exact same action call sites other systems already hook
  (mirrors `_register_festival_sale()`'s precedent) -- no new player-facing
  verbs.
- **Gems are awarded automatically the instant a task's progress reaches
  its target** -- no separate "claim" button, matching the Festival Pass's
  own auto-award-on-threshold behavior (`_register_festival_sale()`), not
  a new claim-flow pattern.
- **All-3-complete bonus**: a modest additional gem bonus is auto-awarded
  the moment the 3rd task of the day completes.
- **Reroll**: spend a modest gem amount to discard today's 3 tasks and
  draw a fresh random 3 (not seeded -- a genuine reroll). **Only available
  while zero of today's 3 tasks are complete yet** -- once any task is
  fully complete (its gem reward already paid out), rerolling is disabled
  for the rest of the day. This is a hard simplifying rule so a reroll can
  never discard an already-earned reward. Partial (incomplete) progress on
  a task is NOT specially protected -- rerolling while a task is part-way
  done does discard that progress along with the task itself; only a
  *paid-out* reward is protected.
- A new day's rollover is lazy-reset-on-read, same pattern as
  `_with_fresh_event_occurrence()`: the first economy call of a new local
  day resets the task set, progress, and reroll-availability in place.
- Gems persist indefinitely (not reset daily) -- only the day's 3 tasks
  and their progress reset.

## 4. Formulas

**Local day key** (pure function of `now` + timezone offset, not a hidden
system-clock read -- keeps this testable the same way every other
`now`-driven `GameEconomy` method is):

```
local_day_key(now_ms, tz_offset_minutes):
    shifted_seconds = now_ms / 1000 + tz_offset_minutes * 60
    d = Time.get_datetime_dict_from_unix_time(shifted_seconds)
    return d.year * 10000 + d.month * 100 + d.day
```

The real timezone offset is read once, only at the actual UI/game entry
point (`Time.get_time_zone_from_system().bias`), exactly mirroring how
`now` itself is already always read at the call site and passed in as a
plain int -- never read a second time inside a pure economy function.

**Task selection**: `RandomNumberGenerator` seeded by `day_key` picks 3
distinct indices from the 5-entry pool -- deterministic per day, matches
`GameData.demand_modifier_percent()`'s existing seeded-RNG-for-determinism
precedent.

**Task pool** (`GameData.DAILY_TASK_POOL`, 5 entries, 3 drawn per day):

| Task | Target | Gem reward | Hooked at |
|---|---|---|---|
| Harvest 5 crops | 5 | 3 gems | `harvest_plot()` (reuses the existing `total_harvests` counter via a per-day baseline snapshot -- no new tracking) |
| Plant 5 seeds | 5 | 3 gems | `plant_seed()` |
| Sell crops 3 times | 3 | 4 gems | `sell_crop()` / `sell_all()` (each successful sale call counts once, not per-unit) |
| Complete 3 worker actions | 3 | 4 gems | `_resolve_worker_cycle()` |
| Earn ₹500 | 500 | 5 gems | Any positive coin gain from selling (same call sites as "Sell crops") |

**All-3-complete bonus**: 5 gems, auto-awarded once, the moment the 3rd
task of the day is completed.

**Reroll cost**: 6 gems (roughly one task's worth) -- a real cost, not
free, but not prohibitive for a player who's banked a few days' gems.

## 5. Edge Cases

- **Game not opened for several days**: the lazy-reset-on-read pattern
  handles this identically to every other cycle-based system here --
  whatever day it is now on the next open, that day's 3 tasks generate
  fresh. No "catch-up" rewards for missed days (matches this project's
  existing LiveOps precedent: Monsoon/Festival never award for missed
  cycles either).
- **Device clock/timezone changes mid-session**: `local_day_key()` is
  recomputed fresh on every call from the real current `now` + real
  current timezone offset, so a genuine day boundary crossing (including
  via timezone change) is detected correctly on the next economy call --
  same as how every other `now`-driven check in this file already behaves
  under a changing clock.
- **Reroll spam**: capped by the "disabled once any task is complete"
  rule -- a player can reroll repeatedly while all 3 are still at zero
  progress (each reroll costs gems, so this isn't free, but it's not
  further hard-capped beyond the gem cost itself and the all-progress-lost
  rule).
- **Insufficient gems for reroll**: button disabled (not silently
  failing), same established pattern as the Chanda/Premium Pass buttons.
- **A task's target action happens before today's tasks are generated**
  (e.g. a harvest at the exact moment of day rollover): the lazy-reset
  fires first (mirrors `_with_fresh_event_occurrence()`'s own ordering),
  so the action is always counted against the correct (already-fresh)
  day's tasks, never lost.

## 6. Dependencies

- `game_data.gd` (new `DailyTaskDef`, `DAILY_TASK_POOL`, tuning constants)
- `game_state.gd` (new fields: `gems`, `daily_task_day_key`,
  `daily_task_kinds` (today's 3 picks), `daily_task_progress`,
  `daily_task_claimed`, `daily_task_bonus_claimed`,
  `daily_task_harvest_baseline` (for the harvest task's counter-delta))
- `game_economy.gd` (day-rollover, the 4 new hook points, reroll)
- A new `DailyTasksCard` in the Events sheet (`events_tab.gd`) -- 4th card
  alongside Monsoon/Festival/Chanda, same visual language.
- Does **not** touch `village_board.gd` or any 3D rendering -- purely
  economy + Events-sheet UI, same shape as the Chanda Visit feature.

## 7. Tuning Knobs

- The 5-entry task pool, targets, and gem rewards -- all data-driven in
  `GameData.DAILY_TASK_POOL`, easy to rebalance or extend later.
- Reroll cost and the all-3-complete bonus amount.
- **Future stretch, explicitly out of scope this pass**: a second gem
  sink beyond Reroll (the original scoping brief floated gem-exclusive
  cosmetic decorations and a capped instant-grow skip) -- deferred to keep
  this pass's new UI surface to the single Events-sheet card, matching the
  brief's own M-complexity ("grind-only") estimate. Real-money gem
  purchases are explicitly and permanently out of scope for this pass --
  no billing integration exists in this project, and the brief calls this
  out as its own separate decision, not something to assume.

## 8. Acceptance Criteria

- [ ] `local_day_key()` returns a stable value within the same local day
      and a different value after a real day boundary, verified with
      explicit `now`/timezone-offset inputs (no real-clock dependency in
      tests).
- [ ] Today's 3 tasks are deterministic for a given day (same day -> same
      3 picks) and distinct from each other (no duplicate task in one day).
- [ ] Each task's progress increments correctly at its real hook point and
      nowhere else.
- [ ] Gems auto-award exactly once per task, the instant its target is
      reached -- never double-awarded on repeated over-target actions.
- [ ] The all-3-complete bonus awards exactly once per day.
- [ ] Reroll: succeeds and resets progress/kinds only while 0 tasks are
      complete; blocked (not silently failing) once any task is done or
      gems are insufficient.
- [ ] A new local day resets the task set/progress/reroll-availability,
      verified via `now` values spanning a day boundary.
- [ ] Full GUT suite green.
- [ ] Verified on-device: the Events sheet's Daily Tasks card renders
      correctly, at least one task's progress genuinely advances from a
      real in-game action, its gem reward is credited, and Reroll works
      before any task is completed and is disabled after.
