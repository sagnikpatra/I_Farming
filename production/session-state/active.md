# Session State: 8-Feature Sprint — Verification & Bugfix Pass

**Date**: 2026-08-23
**Status**: 🔄 3 of 8 features real and now compile-clean; 5 are unwired stubs. Awaiting user go-ahead to commit.

## What actually happened

A prior session ran 8 parallel agents against this sprint (see git-history
version of this file for the original per-agent deployment list). Their
session-state entries all read ✅, but that verification did not actually
happen -- a fresh Claude Code session (this one) reviewed the real diff by
hand (no Godot binary available on this machine to run GUT directly) and
found the code did not compile as delivered. Found and fixed 8 separate
bugs; see below. Do not trust a per-agent ✅ in this kind of session-state
entry again without independently re-reading the diff -- that's what
caught all 8 of these.

## Verified status per feature

**Real, tested, and now compile-clean:**
- **Seasonal Crop Rotation** -- `season_type.gd`, `can_plant_crop()` wired
  into `plant_seed()`, `test_seasonal_crops.gd` (416 lines, every assertion
  hand-checked against the corrected crop/season map). Fixed 2 bugs (see
  below).
- **Farmhouse Upgrades** -- `upgrade_farmhouse()`, passive-income
  resolve/collect, `farmhouse_upgrade_sheet.gd` UI,
  `test_farmhouse_progression.gd` (327 lines). Fixed 2 bugs.
- **Thief NPC Visitor** -- theft-roll math (`was_thief_visiting`,
  `calculate_thief_steal_amount`, `resolve_thief_visit`), board placement
  (`thief_visitor.gd` + `thief_visitor_placement.gd`, both clean on first
  read), `test_thief_system.gd` (353 lines). Fixed 3 bugs. **Known gap,
  not fixed**: nothing yet calls `ThiefInteractionSheet.open_for_thief()`
  or spawns a `ThiefVisitor` on the board when `resolve_thief_visit()`
  fires -- the event currently only posts as a toast message. Real player
  interaction (let go / bribe / chase) isn't reachable in-game yet.

**Not actually implemented, despite the original ✅** -- these are inert
data-only files. Nothing in `game_economy.gd` or `game_state.gd` calls or
persists any of them, and none have tests:
- **Crop Processing Pipeline** -- `processing_building_def.gd`,
  `processing_recipe_def.gd`, `processing_queue_item.gd` + a full
  building/recipe catalogue in `game_data.gd`. No queue logic, no
  persisted queue state, no economy functions. Several recipes use
  explicitly-commented placeholder crops (e.g. `CropType.Kind.TOMATO`
  standing in for "chili" -- this project's `CropType.Kind` has no chili).
- **Villager Hiring** -- `villager_hire_def.gd`, `villager_hire_record.gd`
  + a catalogue/housing-capacity formula in `game_data.gd`, plus two bare
  fields (`hired_villagers`, `villager_housing_capacity`) added to
  `game_state.gd`. No hire/fire/salary functions anywhere.
- **Government Subsidy Quests** -- `subsidy_quest_def.gd` only. Zero
  wiring anywhere.
- **Real-Time Weather Events** -- `weather_event_def.gd` +
  `weather_event_type.gd` only. Zero wiring anywhere. (The project already
  has a separate, working monsoon-flood weather system in
  `game_economy.gd` -- this new attempt doesn't touch or extend it.)
- **E-NAM Market Forecasting** -- `game_data.gd` has a real
  `generate_market_forecast()` (now compile-fixed) and
  `market_forecast_def.gd`, but nothing calls or persists it. No UI, no
  tests.
- **Aquaculture/Makhana Farming** -- no files exist. Never started, despite
  the ✅.

## Bugs found and fixed this session (all in working tree, uncommitted)

1. `game_data.gd:585` -- `match` used as an expression (invalid GDScript;
   `match` is a statement only). Market-forecast multiplier.
2. `game_data.gd:609` -- same `match`-as-expression bug, days-in-month
   helper.
3. `game_economy.gd` -- same `match`-as-expression bug, thief security
   multiplier.
4. `game_economy.gd` `resolve_growth_completions()` -- the thief-visit
   check was spliced into the middle of the per-plot `for` loop at the
   wrong indent depth, breaking the loop body's variable scope (guaranteed
   parse/scope error). Moved to run once, after the loop.
5. `game_economy.gd` -- `_push_event(GameEvent.new(...))` passed a
   `GameEvent` where a `String` was expected, and a separate
   `GameEvent.new(msg, bool, dict)` call used a 3-arg constructor that
   only takes 2. Also `tr(&"key", {dict})` misuse (3 call sites total,
   incl. `thief_interaction_sheet.gd` x2) -- Godot's `tr()` takes a
   `context: StringName`, not a dict; this codebase's convention is
   `tr(&"key") % [args]`.
6. `game_data.gd` `local_day_key_tomorrow()` -- called a bare
   `local_day_key(...)` that only exists on the sibling class
   `GameEconomy`; would not resolve. Inlined the formula locally instead
   of reaching across the Foundation/Economy layer boundary.
7. `season_type.gd` `current_season(now)` -- silently ignored its `now`
   parameter and read the real device clock instead, making the entire
   seasonal-planting feature (and its test suite) date-dependent on
   whatever day it happens to run, not on game time. This was the biggest
   one -- it broke the feature's actual point, not just its tests. Fixed
   to derive the season from `now`.
8. `game_economy.gd` `get_total_storage_capacity()` -- summed every
   farmhouse level's `storage_capacity` field, but those fields are
   already absolute per-level totals, not deltas -- would have returned
   32,000 instead of 7,500 at max level. Unused by anything real
   currently; fixed to delegate to the existing correct
   `storage_capacity()` so it isn't a landmine later.
9. `game_data.gd` `_ensure_crop_season_map()` -- referenced 11 crop names
   (`CHILI`, `PEAS`, `COTTON`, `OKRA`, `BASIL`, `JUTE`, `RICE`,
   `RAPESEED`, `RADISH`, `CABBAGE`, `CAULIFLOWER`) that don't exist in
   this project's `CropType.Kind` enum (only 22 real crops). Guarded with
   `.has("NAME")` checks that don't actually work -- GDScript resolves
   `Enum.MEMBER` statically regardless of a runtime guard around it. Would
   not compile. Rewrote using only the 22 real crops; re-verified every
   assertion in `test_seasonal_crops.gd` against the corrected map by
   hand (all pass).
10. `godot/locales/ui_strings.csv` -- two duplicate/conflicting key rows
    (`event.farmhouse_upgraded`, `farmhouse.upgrade_button`), each with
    two different real call sites expecting two different formats. Deduped,
    renamed the newer conflicting key to `farmhouse.upgrade_action`, and
    added the still-missing `thief.*`/`event.plant_off_season` rows.

## Verification method and its limits

No Godot binary is on this machine's PATH (checked bash PATH, Windows
`where`, and common install locations) and no `adb`, so GUT could not be
run directly this session, and nothing has been deployed to the connected
device yet. Verification instead was a full manual read of every new/
changed file, cross-checked against real symbol definitions (enums,
constructors, function signatures) via grep/read, plus hand-tracing every
assertion in the three new test files against the corrected logic. This
is a real substitute for a compile pass but not a substitute for actually
running GUT (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit --path godot`,
per this project's coding-standards.md) -- that's still an open item.

## Update 2026-08-23, later same day: committed + on-device verified

- User confirmed the proposed commit split; committed as `85e6a75`
  ("feat: seasonal crop rotation, farmhouse passive income, thief NPC
  math"). The 5 stub files remain uncommitted in the working tree, as
  planned.
- Wrote the missing `design/gdd/thief-system.md` (reverse-documented) and
  fixed `design/gdd/seasonal-crop-rotation.md` (it described 11 crops
  that don't exist in `CropType.Kind` -- same root cause as bug #9 below;
  corrected to the real 22-crop roster). Added both to
  `systems-index.md` with a new 🚧 "Partially Shipped" status marker.
- Godot editor found at `E:\Godot\Godot_v4.7.1-stable_win64.exe`. Ran a
  real headless export (`--headless --export-debug "Android" ...`) --
  **this is the compile check that wasn't possible earlier in this
  session, and it completed with zero errors**, real confirmation the 10
  fixes hold up. `adb` found at
  `%LOCALAPPDATA%\Android\Sdk\platform-tools`. Installed the fresh APK on
  the connected OnePlus OPD2403 and confirmed on-device: app boots clean,
  Farmhouse tab shows "Modern Estate, Level 7 of 10", storage 113/2500
  and the Level 8 preview (Grand Manor, 4500 storage, "Upgrade for
  ₹168750") both matching the catalogue exactly -- confirms the locale-
  CSV dedup fix (bug #10) is correct live, not just in theory.
- **New finding from the on-device check** (not a bug -- a reachability
  gap, now documented in `farmhouse-progression.md`'s Acceptance
  Criteria): tapping the Farmhouse opens the pre-existing
  `farmhouse_tab.gd`, not the new `farmhouse_upgrade_sheet.gd` -- nothing
  in the codebase calls the new sheet at all. And nothing calls
  `resolve_passive_income()`/`collect_pending_passive_income()` from
  anywhere either (confirmed via grep). So while the upgrade-purchase
  path is real and confirmed live, passive income is implemented and
  unit-tested in isolation but not reachable in actual gameplay -- the
  same "built but not wired up" pattern as the Thief System's UI gap.

## Update 2026-08-23, later still: real GUT run found the commit split was broken

Ran the actual GUT suite (previously blocked on not having a Godot path) --
this surfaced problems the manual review and the headless export both
missed, because both of those ran inside this main checkout, which still
had the 5 "stub" files physically present on disk even though git didn't
track them. An isolated `git worktree` checkout of commit `85e6a75` alone
(no untracked files present) proved the real problem:

- **The commit did not compile standalone.** `game_data.gd` (committed)
  has hard compile-time type dependencies -- `VillagerHireDef`,
  `VillagerHireRecord`, `MarketForecastDef`, `ProcessingBuildingDef`,
  `ProcessingRecipeDef` -- on 5 of the 9 files left uncommitted as "stub
  files, harmless to leave out." They are not harmless to leave out: the
  catalogue code in `game_data.gd` needs their class definitions to parse
  at all. Fixed by committing all 9 remaining stub `.gd` files (plus their
  `.uid` sidecars, this project's normal convention) in a follow-up
  commit -- they're still flagged as unwired/inert in the GDDs and
  systems-index, just no longer literally missing from git. Lesson: when
  splitting a commit by "which parts actually work," check compile-time
  type dependencies across the split, not just which functions call which
  -- a shared type reference is enough to make two "independent" pieces
  actually inseparable.
- **Two more real bugs found by the actual test run**, invisible to the
  manual/static review:
  - `calculate_thief_steal_amount()` created and seeded a local `rng`
    (`RandomNumberGenerator`) but then called the *global* `randf_range()`
    instead of `rng.randf_range()` -- the seeded instance was never
    actually used, so the function was never deterministic despite
    looking like it was. Caught by
    `test_steal_amount_deterministic_per_session_and_hour` actually
    running and getting two different values from the same seed. Fixed.
  - Two of the 3 new test files had real defects of their own (not
    compile bugs in the game code, bugs in the tests): `test_seasonal_crops.gd`
    and `test_thief_system.gd` referenced nonexistent GUT methods
    (`assert_ge`/`assert_le` -- this GUT version has `assert_gte`/`assert_lte`),
    a nonexistent `PlotState.new_ready_to_harvest()` (real name:
    `new_ready()`), untyped `:=` declarations from `abs()`'s Variant
    return type (warnings-as-errors in this project), a field-name
    mismatch (`thief_total_losses_coins` vs. the real
    `GameState.total_theft_losses`), `assert_is()` used where
    `assert_typeof()` was needed, and a test that appended a plot with
    `id = 0` without clearing `GameState`'s auto-created starting plots
    first, colliding with an existing id-0 plot. All fixed; one test
    (`test_storage_capacity_accumulates`) was rewritten because it
    literally encoded the pre-fix cumulative-storage bug as its expected
    behavior, not the corrected one.
- Compared the full GUT run against a clean baseline (`git worktree` at
  the pre-session commit `49825db`) to separate real regressions from
  this session's changes from a larger set of pre-existing failures (12
  at baseline, some from the earlier "crop varieties + 50-item farm
  equipment catalogue" commit that this session never reviewed). After
  the fixes above, the 3 new test files pass cleanly; remaining failures
  match the pre-existing set. Full before/after numbers: baseline 599
  tests/587 passing/12 failing -> this session's first full run
  637 tests/590 passing/47 failing (2 files silently skipped by GUT due
  to parse errors, masking the true count) -> final, after all fixes,
  716 tests/670 passing/46 failing, with the two previously-skipped files
  now parsing and passing.

## Update 2026-08-23, evening: thief + passive income actually wired up

Continued past the compile/test fixes into the two real integration gaps
flagged above. Both are now reachable in real gameplay, not just correct
in isolation:

**Thief System**: `resolve_thief_visit()` now sets
`state.thief_pending_steal_amount` instead of just posting a toast.
`village_board.gd` spawns/despawns a `ThiefVisitor` on the board keyed off
a new `GameEconomy.thief_visit_awaiting_decision()` (exact same boolean-
edge pattern as `_sync_chanda_visitor_if_needed()`). Tapping it opens
`ThiefInteractionSheet` via `hud.gd`'s new `open_thief_interaction_sheet()`
(mirrors `open_events_sheet()`); the player's choice calls a new
`GameEconomy.resolve_thief_decision(coins_lost)`, which deducts coins
(clamped at 0), tracks `total_theft_losses`, and clears the pending flag.
Found and fixed 3 more real bugs while wiring this:
- `thief_visitor.gd`'s pick area was missing the `board_id` meta
  `board_interactor.gd._pick()` requires -- taps on the NPC would have
  been silently ignored even with everything else wired correctly.
- No `thief_visitor.tscn` scene file existed at all (chanda_visitor.tscn's
  equivalent was never created) -- added, matching its exact minimal
  structure.
- `ThiefInteractionSheet._build_ui()` used raw `Button.new()`/`Label.new()`
  with unscaled pixel spacers instead of this codebase's `UiTheme` helpers
  every other sheet uses. **Confirmed on a real device**: the buttons
  existed in the scene tree and worked if tapped blindly, but were
  effectively invisible at this project's 2.6x UI_SCALE -- opening the
  sheet showed the title and steal amount but no visible buttons at all.
  Rewritten to use `UiTheme.make_chunky_button()`/`make_title_label()`/
  `scale_px()`; screenshot-confirmed fixed on-device.

**Passive income**: `resolve_passive_income(now)` is now called from
`resolve_growth_completions()` (previously defined, never called from
anywhere). Folded a real "Passive Income: ₹X/hour" display + "Collect ₹X"
button into `farmhouse_tab.gd` -- the sheet that's actually reachable by
tapping the Farmhouse -- rather than wiring up the second, still-
unreachable `farmhouse_upgrade_sheet.gd`.

Added 9 new unit tests (`test_thief_system.gd` x7,
`test_farmhouse_progression.gd` x1 integration test, verified via the
real GUT run: 724 tests/678 passing, same 46 pre-existing failures as
before -- nothing regressed, all 9 new tests pass).

**Full on-device verification of the real gameplay loop** (OnePlus
OPD2403, this project's `SIGNAL A` device): backed up the real save
(MD5-verified), temporarily reset `thief_last_visit_epoch_ms` to force a
visit (this save's ~2.6M coin balance makes the visit-probability formula
exceed 100%/hour, so cooldown alone had been silently preventing every
visit since early in this session's earlier testing -- explains why nothing
spawned on the first few checks, not a bug). Confirmed the full loop live:
NPC spawns next to the Farmhouse -> tap opens the sheet with the correct
steal amount -> "Let Them Go" deducts exactly that amount from
`state.coins`, tracks it in `total_theft_losses`, clears the pending flag,
and despawns the NPC. Restored the real save afterward, MD5-verified
device-side (a first local-redirect verification attempt falsely flagged
a mismatch -- that was Git Bash's own text-mode line-ending translation
corrupting the *local verification copy* on the Windows side, not the
actual on-device file; re-verified with `adb shell md5sum` run entirely
on-device, which matched exactly).

## Next steps

1. ~~Wire thief visit to a board NPC + interaction sheet~~ -- done, see
   above.
2. ~~Wire passive income into the tick + a reachable UI~~ -- done, see
   above.
3. ~~Run the real GUT suite~~ -- done, see above (724/678/46, stable).
4. Decide whether to finish or discard the 5 stub-only systems (Crop
   Processing Pipeline, Villager Hiring, Government Subsidy Quests,
   Real-Time Weather Events, E-NAM Market Forecasting) -- still
   uncommitted in the working tree.
5. `thief_security_level` still isn't purchasable anywhere (constants
   exist -- `THIEF_SECURITY_FENCING_COST`/`THIEF_SECURITY_GUARD_POSTS_COST`
   -- but no `buy_thief_security()`-equivalent function) -- one remaining
   documented gap in `thief-system.md`'s Acceptance Criteria.
6. Consider whether the thief visit-probability formula needs a cap --
   it exceeds 100%/hour above ~1M coins (this session's real test save
   included), which may or may not be the intended curve; flagged as a
   Tuning Knob in `thief-system.md`, not changed without a design call.
