# Real-Time Day/Night

## 1. Overview

The village board's lighting now reflects the player's actual real-world
local time of day -- sky color, ambient light, and directional ("sun")
light shift through 4 phases (Dawn/Day/Dusk/Night) keyed off the device's
real local hour. This is Option A from the original scoping brief
(`docs/architecture/feature-scoping-2026-08-22.md` item 3): purely cosmetic
presentation, touching zero gameplay math. Monsoon Season keeps its own
fully independent compressed wall-clock cycle exactly as documented today
-- this is a layer on top, never a modification of it.

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

## 6. Dependencies

- New file: `scripts/village_board/time_of_day.gd` (`TimeOfDay` class --
  `local_hour()`, `Phase` enum, `phase_for_hour()`, `preset_for_phase()`).
  Pure, no scene-tree dependency -- lives in the Presentation layer
  (village-board-specific), not `game_economy.gd`/Foundation, since this
  is purely a rendering concern with no economy-state involvement.
- `village_board.gd` (`_ready()` and `_on_growth_tick_timeout()` apply the
  current preset to the existing `WorldEnvironment`/`DirectionalLight3D`
  nodes already in `village_board.tscn` -- no new scene nodes needed).
- Does **not** depend on or modify `game_economy.gd`, `GameState`, or any
  Monsoon/Festival/Chanda/Daily-Tasks logic.

## 7. Tuning Knobs

- The exact preset RGB/energy values per phase, and the hour-range
  boundaries themselves -- all centralized in `time_of_day.gd`.
- **Future stretch, explicitly out of scope this pass** (per the original
  scoping brief's Option B): a loose seasonal palette shift keyed off the
  real calendar month (India's 3 broad seasons). Deferred to keep this
  pass at Option A's S-complexity, cosmetic-only scope.
- **Future stretch**: villager lamp-lighting (small light sources active
  near structures at Night) -- the original brief's own recommended path
  bundled this in, but it's a distinct content addition (new
  light-emitting objects, not just existing-light-property changes) with
  its own asset/placement questions, deliberately separated out here
  rather than silently expanded into.
- **Future stretch**: a smooth crossfade between phases instead of an
  instant swap on the next tick.

## 8. Acceptance Criteria

- [ ] `local_hour()` returns the correct hour for explicit
      `(now_ms, tz_offset_minutes)` inputs -- no real-clock dependency in
      tests, same discipline as `GameEconomy.local_day_key()`'s own tests.
- [ ] `phase_for_hour()` maps every hour 0-23 to exactly one of the 4
      phases per the table above, with the boundary hours verified
      explicitly (e.g. hour 6 is Dawn, hour 7 is Day).
- [ ] Day's preset values exactly match `village_board.tscn`'s existing
      `Environment`/`DirectionalLight3D` defaults (no drift).
- [ ] The board applies the correct phase immediately on `_ready()` (not
      a flash of Day before the first tick).
- [ ] The board only reassigns environment/light properties when the
      phase has actually changed, not every tick.
- [ ] Full GUT suite green.
- [ ] Verified on-device: forcing each of the 4 phases (via a temporary
      always-different-hour override, same instrument-then-delete method
      used elsewhere this session) shows a visibly distinct, correctly
      colored board with no crash, and Day's real value shows no
      difference from the pre-existing look.
