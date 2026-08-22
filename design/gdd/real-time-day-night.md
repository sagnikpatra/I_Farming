# Real-Time Day/Night

---
**Status**: Implemented and shipped — live in the game
**Verified By**: `test_time_of_day.gd`'s full test set, full GUT suite
green, and on-device verification (see
`production/qa/evidence/time-of-day-forced-day.png`,
`time-of-day-natural.png`, `lamp-lighting-day-no-regression.png`)
**Update (2026-08-22)**: this document's Acceptance Criteria checkboxes
had gone stale — left unchecked even after the feature shipped. Corrected.
**Update (2026-08-22, cont'd)**: the last open "future stretch" (smooth
crossfade between phases) is now also decided and built — see Tuning
Knobs and the new "Smooth Crossfade" Acceptance Criteria section.
609/609 GUT tests passing, run twice non-flaky, boot-verified on a real
device.
---

## 1. Overview

The village board's lighting now reflects the player's actual real-world
local time of day -- sky color, ambient light, and directional ("sun")
light shift through 4 phases (Dawn/Day/Dusk/Night) keyed off the device's
real local hour. This is Option A from the original scoping brief
(`docs/architecture/feature-scoping-2026-08-22.md` item 3): purely cosmetic
presentation, touching zero gameplay math. Monsoon Season keeps its own
fully independent compressed wall-clock cycle exactly as documented today
-- this is a layer on top, never a modification of it. Option B (a loose
seasonal palette tint keyed off the real calendar month) was originally
deferred from this pass but has since been built -- see §3 below.

## 2. Player Fantasy

*"This is my farm, right now."* Every other LiveOps system in this project
runs on an abstracted in-game cycle (Monsoon's 6h/90min, Festival's 8h/1h,
Chanda's 12h/30min, Daily Tasks' real-calendar-day) -- none of them ground
the board in the player's own actual moment. Opening the app at night and
seeing the farm genuinely lit like night, or at sunrise and seeing warm
dawn light, is a small, quiet reinforcement that this is *your* farm you're
checking in on, not a screen that looks identical 24/7.

## 3. Detailed Rules

- The board's lighting is driven by the device's real **local hour**
  (0-23), computed the same way Gems & Daily Tasks' day boundary already
  is: a pure function of `(now_ms, timezone_offset_minutes)`, with the one
  real system-clock read (`Time.get_time_zone_from_system()`) kept to a
  single thin wrapper rather than threaded through unrelated signatures.
- The local hour maps to one of **4 phases**: Dawn, Day, Dusk, Night (see
  Formulas for exact hour ranges).
- Each phase has a fixed **preset**: sky/background color, ambient light
  color + energy, directional ("sun") light color + energy. The Day
  preset's values are the project's existing, already-art-directed
  defaults (`village_board.tscn`'s current `Environment`/`DirectionalLight3D`
  values) -- unchanged, so a player who only ever opens the app during
  daytime hours sees no visual regression at all.
- Applied at two points: once on `VillageBoard._ready()` (so the very
  first frame already shows the correct phase, not a flash of the Day
  default), and re-checked every 3s growth tick (same cadence
  `_sync_adaptive_ambience_if_needed()` already uses for Monsoon/Festival
  audio) -- but only actually reassigns the environment/light properties
  when the phase has genuinely changed since last applied, same
  edge-detection discipline that function already uses.
- No animated transition between phases this pass -- an instant swap the
  moment the tick after a phase boundary fires (at most a few seconds'
  latency after the real boundary, same latency Monsoon/Festival's own
  tick-driven checks already accept). A smooth crossfade is a tuning knob,
  not required for this pass.
- Does **not** touch Monsoon Season's own visual/gameplay effects (rain,
  flood risk, growth speed) -- those remain entirely independent and can
  layer with any day/night phase (e.g. a Monsoon-active Night looks like
  Night's lighting, Monsoon's own effects unchanged).

### Seasonal Palette (Option B, built 2026-08-22)

- The real calendar month maps to one of India's **3 broad seasons**
  (Monsoon/Winter/Summer -- exact boundaries in Formulas), each with a
  small multiplicative color tint layered on top of whichever phase
  preset is currently active.
- **Deliberately loose, not a full re-tint** -- per the original scoping
  brief's own Option B description. Every tint channel stays within
  ±15% of neutral (1.0); day/night phase remains the dominant visual
  signal, season a secondary modifier riding on top of it.
- The tint is color-only (`sky_color`/`ambient_color`/`sun_color`) --
  `ambient_energy`/`sun_energy` are never touched by it.
- Read fresh on every actual phase change (reusing the exact same
  edge-detected `_last_time_of_day_phase` check above), not a separate
  timer -- since seasons change on the order of months, lagging by up to
  one phase-transition window (worst case a few hours) after a real
  season boundary is an acceptable tolerance for a loose cosmetic
  modifier, the same latency philosophy the phase system itself already
  accepts for Dawn/Day/Dusk/Night boundaries.
- **Deliberately unrelated to this project's existing Monsoon Season
  liveops event**, despite the name overlap -- that system is a fully
  abstracted wall-clock cycle with no tie to the real calendar (see this
  doc's own Overview); this is a real-calendar-month lookup with no
  connection to that cycle's state.
- `preset_for_phase()` itself is unchanged and still the exact function
  every pre-existing caller used -- season is opt-in via the new
  `preset_for_phase_and_season()`, which `village_board.gd` is the only
  caller of.

### Villager Lamp-Lighting (built 2026-08-22)

- Every structure (any zone with `has_building=true` -- Farmhouse,
  Polyhouse, Mandi, Agroforestry, Aquaculture, Vertical Farm; not the
  synthetic Open Field pseudo-zone, which has no building) gets one
  small warm light source, lit only at Night.
- **Resolves both open questions this stretch goal was originally
  separated out over**: placement reuses `_build_zone_structure()`'s own
  existing footprint/height math (a fixed corner offset from the
  structure, elevated partway up it) rather than needing a new design
  pass; there is no asset question at all, since Godot's built-in
  `OmniLight3D` needs no sourced 3D model.
- Energy, not visibility, is the day/night toggle -- the light node
  always exists once its structure is built, just at `0.0` energy
  outside Night, so toggling it is a single float write, never a
  scene-tree add/remove.
- **A real timing gap was found and fixed before it could ship as a
  bug**: `rebuild()` (which tears down and reconstructs every zone,
  including its lamp, far more often than an actual day/night phase
  changes -- any purchase or drag-commit triggers one) always creates a
  fresh lamp at `0.0` energy. Without an explicit fix, any `rebuild()`
  that wasn't itself the phase-change trigger would silently darken
  every lamp until the next real phase transition, possibly hours
  later. Fixed by unconditionally re-applying the already-known current
  phase's lamp state at the end of every `rebuild()`, not only on an
  actual phase-change edge.
- A dragged/repositioned structure's lamp moves with it -- the same
  `_reposition_zone_group()` that already repositions Plinth/Building/
  PickArea on every drag frame now repositions the lamp too, reading a
  stored offset the same way it already reads `building_top_y`.

## 4. Formulas

**Local hour** (pure function, mirrors `GameEconomy.local_day_key()`'s
exact shifting technique):

```
local_hour(now_ms, tz_offset_minutes):
    shifted_seconds = now_ms / 1000 + tz_offset_minutes * 60
    d = Time.get_datetime_dict_from_unix_time(shifted_seconds)
    return d.hour
```

**Phase boundaries**:

| Phase | Hours | Rationale |
|---|---|---|
| Dawn | 5-6 | Short, transitional |
| Day | 7-17 | The long, already-tuned default look |
| Dusk | 18-19 | Short, transitional |
| Night | 20-23, 0-4 | The long low-light window |

**Presets** (`TimeOfDay.preset_for_phase()`):

| Phase | Sky color | Ambient color / energy | Sun color / energy |
|---|---|---|---|
| Day (unchanged default) | `#A1C4DB` | `#FFF2D9` / 0.45 | `#FFED C7` (existing `light_color`) / 0.55 |
| Dawn | warm pink-orange | warm pink / 0.35 | soft orange / 0.4 |
| Dusk | warm red-orange | warm orange / 0.35 | deep orange / 0.4 |
| Night | deep blue | cool blue-violet / 0.25 | pale moonlight blue / 0.2 |

(Exact RGB values live in `time_of_day.gd` -- see Tuning Knobs. Day's
values are copied verbatim from `village_board.tscn`'s existing
`Environment`/`DirectionalLight3D` resources, not re-derived, so there's
no risk of subtly drifting the already-shipped daytime look.)

**Season boundaries** (`TimeOfDay.season_for_month()`):

| Season | Months | Tint |
|---|---|---|
| Monsoon | Jun-Sep (6-9) | `(0.90, 0.95, 1.00)` -- cool, slightly desaturated, overcast |
| Winter | Oct-Feb (10-12, 1-2) | `(0.95, 0.97, 1.00)` -- cool, pale/hazy |
| Summer | Mar-May (3-5) | `(1.05, 1.00, 0.92)` -- warm, golden |

`preset_for_phase_and_season(phase, season)` multiplies `sky_color`/
`ambient_color`/`sun_color` component-wise by the season's tint;
`ambient_energy`/`sun_energy` pass through unchanged.

**Lamp light** (`village_board.gd`'s `NIGHT_LAMP_ENERGY` constant): warm
color `(1.0, 0.75, 0.35)`, `omni_range` = the structure's own larger
footprint axis x1.2, `light_energy` = `1.5` at Night, `0.0` at every
other phase. Position offset from the structure's footprint center:
`(footprint.x * 0.4, building_top_y * 0.5, footprint.y * 0.4)`.

## 5. Edge Cases

- **Device clock/timezone changes mid-session**: recomputed fresh every
  tick from the real current `now` + real current timezone offset, same
  as Daily Tasks' day-key check -- a genuine change is picked up on the
  next tick.
- **App reopened after being closed for hours/days**: `_ready()` applies
  the correct current-moment phase immediately, no catch-up needed (this
  is a pure function of the current real time, not an accumulated state).
- **Extreme timezones / DST boundaries**: `Time.get_time_zone_from_system()`
  already reflects the OS's own DST-aware offset at query time, so no
  separate DST handling is needed here.
- **Phase boundary crossed exactly during a rebuild caused by something
  else** (e.g. a purchase mid-tick): no special handling needed -- the
  next 3s tick's own check catches it within one cycle either way.
- **A season boundary crossed without a phase boundary also being
  crossed nearby**: per Detailed Rules above, the seasonal tint is only
  re-read on an actual phase change, not its own timer -- worst case, up
  to one phase-transition window's latency after the real calendar
  boundary before the new season's tint appears. Accepted, not a defect.
- **A `rebuild()` fires during Night for a reason unrelated to day/night**
  (a purchase, a drag-commit): every structure's lamp would otherwise
  reset to its freshly-built default of off -- fixed, see Villager
  Lamp-Lighting above. Not a theoretical edge case; `rebuild()` genuinely
  fires far more often than an actual phase change.
- **A structure is dragged to a new position**: its lamp moves with it
  in the same frame, via the same `_reposition_zone_group()` call that
  already repositions the rest of the structure -- never lags a frame
  behind or gets left at the old position.

## 6. Dependencies

- New file: `scripts/village_board/time_of_day.gd` (`TimeOfDay` class --
  `local_hour()`, `Phase` enum, `phase_for_hour()`, `preset_for_phase()`,
  plus `local_month()`, `Season` enum, `season_for_month()`,
  `season_tint()`, `preset_for_phase_and_season()` for the Seasonal
  Palette stretch goal). Pure, no scene-tree dependency -- lives in the
  Presentation layer (village-board-specific), not `game_economy.gd`/
  Foundation, since this is purely a rendering concern with no
  economy-state involvement.
- `village_board.gd` (`_ready()` and `_on_growth_tick_timeout()` apply the
  current preset to the existing `WorldEnvironment`/`DirectionalLight3D`
  nodes already in `village_board.tscn` -- no new scene nodes needed).
  **Villager Lamp-Lighting is the one stretch goal that adds new scene
  nodes**: `_build_zone_structure()` creates one `OmniLight3D` per
  structure, `_reposition_zone_group()` keeps it correctly placed
  through a drag, and the new `_apply_night_lamps_to_current_state()`
  helper (called from both `_apply_time_of_day_if_needed()` and the end
  of `rebuild()`) is the single source of truth for every lamp's current
  energy.
- Does **not** depend on or modify `game_economy.gd`, `GameState`, or any
  Monsoon/Festival/Chanda/Daily-Tasks logic.

## 7. Tuning Knobs

- The exact preset RGB/energy values per phase, the hour-range
  boundaries, the season tint values, and the month-range boundaries --
  all centralized in `time_of_day.gd`. `NIGHT_LAMP_ENERGY` and the lamp
  offset/range formulas -- in `village_board.gd`.
- Every stretch goal originally deferred from this pass (Option B/the
  seasonal palette, villager lamp-lighting) has now been built.
- **Smooth crossfade — decided and built (2026-08-22)**: real phase
  transitions (Dawn→Day, Day→Dusk, etc.) now animate over
  `TIME_OF_DAY_CROSSFADE_SECONDS` (3.0s) via a parallel `Tween` on all 5
  properties (sky/ambient color+energy, sun color+energy), the same
  duration/pattern `AudioManager.AMBIENCE_CROSSFADE_SECONDS` already
  established as this project's precedent for cosmetic transitions. The
  very first application (board `_ready()`, nothing applied yet) still
  snaps instantly — crossfading from the scene's authored default would
  recreate the exact "flash of Day before the first tick" bug this
  function was originally written to prevent. Villager lamp energy is
  NOT crossfaded (an `OmniLight3D` popping on/off at Night reads as a
  lamp switching on, not a defect — see the Villager Lamp-Lighting
  stretch goal's own framing).

## 8. Acceptance Criteria

- [x] `local_hour()` returns the correct hour for explicit
      `(now_ms, tz_offset_minutes)` inputs -- no real-clock dependency in
      tests, same discipline as `GameEconomy.local_day_key()`'s own tests
      — `test_local_hour_reads_the_correct_utc_hour_at_zero_offset`/
      `test_local_hour_shifts_with_timezone_offset`.
- [x] `phase_for_hour()` maps every hour 0-23 to exactly one of the 4
      phases per the table above, with the boundary hours verified
      explicitly (e.g. hour 6 is Dawn, hour 7 is Day) —
      `test_phase_boundaries_are_exact` plus the per-phase-hours tests.
- [x] Day's preset values exactly match `village_board.tscn`'s existing
      `Environment`/`DirectionalLight3D` defaults (no drift) —
      `test_day_preset_matches_the_scenes_existing_defaults_exactly`.
- [x] The board applies the correct phase immediately on `_ready()` (not
      a flash of Day before the first tick) — `village_board.gd`'s
      `_last_time_of_day_phase` starts at `-1` ("never applied"), so
      `_apply_time_of_day_if_needed()`'s edge-detection guarantees the
      first real call always applies. Verified by code inspection, not a
      dedicated automated test (Node3D/Environment property assignment
      isn't unit-tested in this project — a "Visual/Feel" story type per
      `coding-standards.md`'s Testing Standards, ADVISORY not BLOCKING).
- [x] The board only reassigns environment/light properties when the
      phase has actually changed, not every tick — same
      `_apply_time_of_day_if_needed()` edge-detection guard
      (`if phase == _last_time_of_day_phase: return`), same
      verification caveat as above.
- [x] Full GUT suite green — 592/592 as of this document's last
      verification pass, run twice non-flaky.
- [x] Verified on-device: forcing each of the 4 phases (via a temporary
      always-different-hour override, same instrument-then-delete method
      used elsewhere this session) shows a visibly distinct, correctly
      colored board with no crash, and Day's real value shows no
      difference from the pre-existing look — see
      `production/qa/evidence/time-of-day-forced-day.png`,
      `time-of-day-natural.png`, and `lamp-lighting-day-no-regression.png`.

### Seasonal Palette (2026-08-22)

- [x] `local_month()` returns the correct real-calendar month for
      explicit `(now_ms, tz_offset_minutes)` inputs, including across a
      year boundary -- no real-clock dependency in tests, same
      discipline as `local_hour()`'s own tests.
- [x] `season_for_month()` maps every month 1-12 to exactly one of the 3
      seasons per the table above, with boundary months verified
      explicitly (month 5 is Summer, month 6 is Monsoon, etc.).
- [x] Every season's tint stays within the documented ±15% loose-shift
      bound on every color channel -- confirmed by an explicit bound
      check, not just eyeballing the chosen values.
- [x] `preset_for_phase_and_season()` applies the tint multiplicatively
      to `sky_color`/`ambient_color`/`sun_color` only, leaving
      `ambient_energy`/`sun_energy` untouched.
- [x] `preset_for_phase()` alone is unaffected by the new function
      existing -- confirmed by an explicit test, not just unchanged code.
- [x] Full GUT suite green (518/518 at the time this was built).
- [x] Verified on-device: exported, installed, and launched clean (no
      crash) with the real current month applied (August 2026 -> Monsoon
      tint); screenshot shows a plausible, non-broken board. A dedicated
      multi-season side-by-side comparison (forcing each of the 3
      seasons in turn) was **not** captured separately -- the tint is
      intentionally subtle by design, and the boundary math itself is
      what's actually load-bearing here, which the unit tests above
      cover completely.

### Villager Lamp-Lighting (2026-08-22)

- [x] Every structure (`has_building=true` zone) gets exactly one
      `NightLamp` -- confirmed by code inspection of
      `_build_zone_structure()`'s unconditional lamp creation within
      that branch. `village_board.gd`'s prior lack of any dedicated test
      file (matching this project's then-accepted gap -- see
      `technical-preferences.md`'s Testing section) is now partially
      closed: see `test_village_board.gd` below, though this specific
      per-zone lamp-creation bullet is still by inspection, not a
      dedicated test of its own.
- [x] Lamps are off (`light_energy = 0.0`) at every phase except Night --
      confirmed both by code inspection of
      `_apply_night_lamps_to_current_state()` and, for the Day case
      specifically, by `test_village_board.gd`'s
      `test_lamps_are_off_when_phase_is_explicitly_not_night`.
- [x] A `rebuild()` unrelated to a day/night phase change does not
      darken lamps that should still be lit -- the specific bug this
      pass found and fixed (see Detailed Rules/Edge Cases above); the
      on-device-verification gap this bullet used to flag is now closed
      -- `godot/tests/unit/test_village_board.gd` (the first-ever test
      file for `village_board.gd`) drives the real scene end-to-end:
      forces Night, confirms the lamp is genuinely lit, then triggers a
      real unrelated economy action (`buy_polyhouse()` +
      `persist_and_rebuild_if_dirty()`, the exact real-game trigger the
      bug was found from) and asserts the lamp is still lit after the
      real `rebuild()` this causes. A companion test forces Day and
      confirms the same rebuild path correctly leaves the lamp off,
      guarding the opposite direction too.
- [x] Full GUT suite green throughout (545/545, run twice in a row to
      confirm non-flaky -- `village_board.gd` now has its own dedicated
      coverage for this fix, not just zero-regression-elsewhere).
- [x] Verified on-device via a temporary forced-Night override (reverted
      before commit, same precedent as every other feature this
      session): screenshot shows multiple structures with a genuine warm
      light pooling on the ground near them, clearly distinct from the
      unlit board, no crash. A second screenshot after reverting
      confirms zero visual regression to the normal daytime look.

### Smooth Crossfade (2026-08-22)

- [x] The very first application (board `_ready()`) lands on the correct
      preset immediately, not mid-crossfade from the scene's authored
      default — `test_the_first_application_snaps_instantly_to_the_correct_preset`.
- [x] A real phase transition does not snap instantly — a `Tween` is
      started instead, verified by confirming the color hasn't reached
      its target within the same synchronous call (before the tween has
      processed a frame) — `test_a_real_phase_transition_does_not_snap_instantly`.
      Deliberately does not assert on the tween's actual frame-by-frame
      progress or exact visual smoothness — a "Feel"/timing quality this
      project's own coding-standards.md excludes from automation; only
      the logic decision (which code path ran) is tested.
- [x] Full GUT suite green — 609/609 (up from 607), run twice, non-flaky.
- [x] Verified on-device: fresh debug export installs and boots cleanly
      with the Tween-based crossfade active, no crash, no `Tween`-related
      errors in logcat. Capturing the crossfade mid-animation via a timed
      screenshot was not attempted — low value given the already-strong
      headless proof of correct branching plus a clean real-device boot,
      and inherently hard to time precisely through `adb screenshot`'s
      own latency against a 3-second window.
