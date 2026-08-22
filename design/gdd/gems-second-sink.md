# Gems: Grow-Time Skip (Second Sink)

---
**Status**: Implemented and shipped — live in the game
**Verified By**: `test_gems_daily_tasks.gd` (8 tests) + `test_save_serializer.gd`
+ `test_growing_info_card.gd` (5 tests, including the real Skip button's
`pressed` signal end-to-end), full GUT suite green (536/536 at the time
this was built), and real on-device logcat verification of the economy-
layer state change
**Update (2026-08-22)**: this document was missing the standard status
header every other completed GDD carries — added for consistency; no
content change.
---

## 1. Overview

`design/gdd/gems-daily-tasks.md` shipped gems as a currency and its first
sink (`reroll_daily_tasks()`). `feature-scoping-2026-08-22.md` item 2
flagged a second sink as open, offering the original brief's own two
candidate shapes: "(a) gem-exclusive cosmetic decorations, (b) capped
convenience skips, e.g. one grow-time skip per day, hard-capped." This
doc covers the one built (2026-08-22): **(b)**, a capped grow-time skip.
(a) was not pursued -- a gem-exclusive decoration needs a new sourced 3D
asset, which this pass deliberately avoided (see Tuning Knobs).

## 2. Player Fantasy

*"My gems are worth spending, and spending them never feels required."*
One skip a day is a real, felt convenience on a session where the player
is impatient for a specific crop -- not a currency sink so large or
frequent it starts to feel like the intended way to play. Anti-pay-to-
win guardrail preserved exactly as `gems-daily-tasks.md` already
established: no rupee-to-gem or gem-to-rupee exchange, and this sink
buys *time*, never *risk immunity* (see Detailed Rules).

## 3. Detailed Rules

- One GROWING plot's remaining grow time can be skipped, once per real
  calendar day, for a flat gem cost.
- **Deliberately does not bypass weather/theft/flood risk.** `skip_
  grow_time()` never touches `resolve_growth_completions()`'s own risk
  rolls (Sandalwood theft, Monsoon flooding, weather damage) -- it
  rewinds the plot's `planted_at_epoch_ms` far enough into the past that
  the very next `resolve_growth_completions()` call (already driven by
  the existing 3s growth tick, or called immediately by the UI for a
  responsive feel -- see Dependencies) treats it as naturally complete
  and runs through that exact same risk logic unchanged. Paying gems
  buys instant time, not a safer harvest.
- The cap is a real calendar day (`GameEconomy.local_day_key()`, the
  same lazy-reset-on-read scheme `daily_task_day_key` already uses), not
  a rolling 24h window.
- Read-only availability (`can_skip_grow_time()`) never itself consumes
  the cap -- only the real action (`skip_grow_time()`) does, so the
  UI's own enabled/disabled check can run every frame without side
  effects.
- **Assigned/"called" workers are entirely unaffected** -- a worker's
  own stationed-at-zone auto-harvest/replant cycle (`worker-economy.md`)
  is a separate system; this skip only ever targets a specific
  player-selected GROWING plot the player taps.

## 4. Formulas

- **Cost**: `GameData.GROW_SKIP_COST_GEMS = 10` gems. Priced above
  `DAILY_TASK_REROLL_COST` (6) since a full grow-time skip is a
  stronger convenience than a task reroll, but still reachable within a
  few days of ordinary play -- a full day's 3 tasks + the all-3 bonus
  nets roughly 14-19 gems at most (see `gems-daily-tasks.md` §4).
- **Rewind formula**: `planted_at_epoch_ms = now - effective_grow_seconds
  * 1000 - 1` -- one millisecond past the plot's own completion
  threshold, guaranteeing `resolve_growth_completions()`'s `elapsed_ms <
  effective_grow_seconds * 1000` check reads false on the very next call
  at the same `now`.
- **Cap**: exactly 1 per `local_day_key(now, tz_offset)`.

## 5. Edge Cases

- **No gems, or below the cost**: `skip_grow_time()` pushes an event and
  returns, no state changes -- confirmed by an explicit test.
- **Already used today**: same no-op-with-event behavior, confirmed
  separately from the insufficient-gems case.
- **Targeting a non-GROWING plot** (empty, already ready, or a stale
  `plot_id` from a race with a tick-driven rebuild): no-op, no gems
  spent -- mirrors `board_interactor.gd`'s own existing "stale pick"
  guard for opening the card at all.
- **A new calendar day arrives**: the cap resets lazily on the next
  `skip_grow_time()`/`can_skip_grow_time()` call, same pattern
  `daily_task_day_key` already uses -- no separate day-rollover job.
- **The skipped plot's crop would have failed a risk roll anyway** (e.g.
  Sandalwood theft): the player still loses the crop -- this is
  intentional, see Detailed Rules' "buys time, not risk immunity" rule.

## 6. Dependencies

- `game_state.gd`: two new fields, `grow_skip_day_key`/
  `grow_skip_used_today`, same shape as `daily_task_day_key`.
- `game_data.gd`: `GROW_SKIP_COST_GEMS` constant.
- `game_economy.gd`: `skip_grow_time(plot_id, now)`,
  `can_skip_grow_time(now)` (read-only).
- `save_serializer.gd`: both new fields added to `to_dict`/`from_dict`/
  `validate` -- required for every new `GameState` field per
  `adr-0003-cloud-save-and-player-accounts.md`'s Phase 0 discipline,
  confirmed via an explicit round-trip test, not just added and assumed
  correct.
- `growing_info_card.gd`/`board_interactor.gd`: the one UI surface --
  the existing GROWING-plot info card gains a "⏩ Skip (N gems)" button,
  shown/enabled via `can_skip_grow_time()`, following the exact
  Rotate/Flip/Remove button-row pattern `decoration_info_card.gd`
  already established (same `UiTheme.make_chunky_button()` chrome, same
  `_village_board.persist_and_rebuild_if_dirty()` + card
  repopulate/close flow).
- Does **not** touch `worker-economy.md`'s worker auto-harvest/replant
  cycle, Monsoon/weather risk logic itself, or any other gems sink.

## 7. Tuning Knobs

- `GameData.GROW_SKIP_COST_GEMS` -- easy to rebalance after real player
  data exists on how often it's actually used.
- **Not pursued this pass**: option (a) from the original brief,
  gem-exclusive cosmetic decorations. Every existing `DecorationType`
  entry maps to a real curated 3D model or emoji-based ground decal
  (`decoration_type_def.gd`); a genuinely new gem-exclusive item would
  need either a new sourced 3D asset (real content-creation scope this
  pass deliberately avoided, same reasoning `real-time-day-night.md`'s
  villager lamp-lighting and `land-and-structures.md`'s sub-upgrade
  tint both already used) or re-badging an existing coin-priced item as
  also gem-purchasable, which isn't "gem-exclusive" in the sense the
  brief meant. Worth a real design pass if pursued later, not a small
  extension of this one.

## 8. Acceptance Criteria

- [x] `skip_grow_time()`/`can_skip_grow_time()` are independently
      unit-tested: succeeds and costs gems, rewinds `planted_at_epoch_ms`
      so the plot genuinely resolves ready on the very next
      `resolve_growth_completions()` call (the real end-to-end proof,
      not just a state-flag check), blocked on insufficient gems,
      blocked after first use same day, resets on a new calendar day,
      no-ops for a non-GROWING plot, and the read-only check never
      itself consumes the cap -- `tests/unit/test_gems_daily_tasks.gd`
      (8 new tests).
- [x] The two new `GameState` fields round-trip through
      `SaveSerializer` -- `tests/unit/test_save_serializer.gd`.
- [x] Full GUT suite green (536/536 at the time this was built).
- [x] Confirmed via on-device logging that the economy-layer state
      change is genuinely correct: gems set, target plot planted, no
      crash -- verified through real logcat output, not assumed.
- [x] **The Skip button itself is verified -- not via an on-device
      screenshot, but via a stronger, repeatable alternative found after
      the screenshot attempt kept failing on real-device friction** (the
      device's screen lock interrupting a debug build mid-test twice,
      then genuine difficulty precisely tap-targeting the correct plot
      on the isometric board without a clear visual marker at the zoom
      level available). Rather than keep spending effort on pixel
      coordinates, wrote `tests/unit/test_growing_info_card.gd` (5 new
      tests): instantiates the real `GrowingInfoCard` scene against a
      real `VillageBoard`/`GameEconomy`/`BottomSheet`, and confirms the
      Button node actually exists with the real gem cost in its text,
      is enabled/disabled correctly across three real scenarios (enough
      gems, insufficient gems, cap already used), and -- the strongest
      check -- **emits the Button's own `pressed` signal** (the exact
      event a live tap fires) and confirms that genuinely spends gems,
      resolves the plot to `READY_TO_HARVEST`, and closes the sheet.
      This is a CI-durable regression guard a single screenshot never
      would have been, and it exercises the actual button-to-economy
      wiring end-to-end rather than the pattern-matching argument
      ("it follows an already-proven pattern") the Acceptance Criteria
      here originally had to fall back on. The one thing it still
      doesn't cover -- real touch-input hit-testing on the actual 3D
      board at real screen coordinates -- remains implicitly covered by
      every other tap-driven info card (`decoration_info_card.gd`,
      already live) using the identical `BottomSheet`/tap-dispatch
      mechanism this card reuses unmodified.
- [x] **A real process mistake was found and fully corrected during this
      feature's own verification, not swept aside**: an earlier session
      GDD entry (`land-and-structures.md`'s sub-upgrade tint) had
      claimed a debug override was safe because `_ready()` doesn't
      persist to disk. That claim was wrong -- discovered here, while
      setting up this feature's own on-device test, before further
      damage was done. The real on-device save had already been
      contaminated by that earlier claim being acted on; it was pulled,
      the exact falsified fields identified and corrected back to their
      known-good values, and pushed back, verified via a clean
      screenshot. See `land-and-structures.md`'s own correction note and
      this feature's session-state entry for the full account. Every
      debug override for the remainder of this session took an explicit
      save backup first, rather than repeating the original assumption.
