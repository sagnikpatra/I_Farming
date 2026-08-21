# Festival Visiting NPCs — "Chanda" Events

## 1. Overview

A recurring, low-stakes visiting-NPC event: periodically, a neighbor from
the village stops by the Farmhouse to collect a small **chanda** (community
donation) for an upcoming festival. Giving grants a modest, time-limited
blessing (a small sell-price bonus); declining is entirely neutral. The
event rotates across four major Indian festivals — **Durga Puja, Eid,
Christmas, and Baisakhi** — representing the real religious plurality of a
rural Indian village, not any single community. This is a companion system
to the existing Festival Event Pass (`festival_def.gd`), layered alongside
it, never replacing it.

## 2. Player Fantasy

*"My neighbors know me, and I look out for them too."* This is a small,
warm beat of belonging — the game briefly stepping outside the
player-vs-economy loop to acknowledge that the farm sits inside a real
community with its own calendar of celebrations. It should feel like a
knock at the door from someone you know, not a transaction screen. Giving
should feel generous, not obligatory; declining should never feel like a
punishment or a missed trade.

## 3. Detailed Rules

- A **Chanda Visit** becomes active on a fixed recurring cycle
  (`GameData.CHANDA_CYCLE_MS`), independent of the Festival Event Pass's own
  cycle — the two systems share no state and can overlap freely.
- While a visit is active, the Events sheet's `ChandaCard` shows which
  festival is being collected for (name + emoji), the ask amount, and two
  buttons: **Give** and **Not this time**.
- **Give**: deducts the ask amount from `state.coins` (if affordable — see
  Edge Cases), starts a blessing buff (`state.chanda_blessing_active_until`),
  and shows a warm, festival-specific acknowledgment line.
- **Not this time**: no coin change, no buff, a neutral warm flavor line
  (never guilt-tripping, never worse than doing nothing).
- Both actions resolve the *current occurrence* — `state.chanda_last_resolved_cycle_index`
  is set to the current cycle index either way, so the same visit can't be
  given-to or declined twice, and a fresh visit next cycle is untouched by
  the previous occurrence's choice.
- The blessing buff, while active, multiplies into the existing farm-wide
  sell-price multiplier chain (alongside the Farmhouse level bonus) — no new
  multiplier machinery, reuses `_sell_price_multiplier()`'s existing
  composition point.
- The four festivals rotate in a fixed order by cycle index (same
  `index % rotation.size()` pattern as `GameData.festival_def()`), so every
  festival appears equally often — no festival is ever favored or skipped.

## 4. Formulas

- **Ask amount**: `CHANDA_BASE_ASK + state.farmhouse_level * CHANDA_ASK_PER_LEVEL`
  — scales lightly with progression so it stays a minor, affordable ask at
  every stage (never a meaningful economy sink or gate).
- **Cycle index**: `now / GameData.CHANDA_CYCLE_MS` (integer division, ms
  epoch time) — same pattern as `current_festival()`.
- **Active window**: `posmod(now, CHANDA_CYCLE_MS) < CHANDA_ACTIVE_DURATION_MS`
  — same pattern as `is_festival_active()`.
- **Festival selection**: `GameData.chanda_festival_def(cycle_index)` →
  `_chanda_festivals[cycle_index % _chanda_festivals.size()]`.
- **Blessing multiplier**: `CHANDA_BLESSING_MULTIPLIER` (flat, e.g. 1.08)
  while `now < state.chanda_blessing_active_until`, else `1.0`. Composed
  multiplicatively with the existing Farmhouse sell multiplier.
- **Blessing duration**: `CHANDA_BLESSING_DURATION_MS` from the moment of
  giving (`state.chanda_blessing_active_until = now + CHANDA_BLESSING_DURATION_MS`).

## 5. Edge Cases

- **Can't afford the ask**: Give is disabled (not silently failing) —
  mirrors the Premium Pass button's own established §2.4 disabled-state
  fix (`events_tab.gd`'s `_build_premium_pass_button()`), not a new pattern.
- **Visit already resolved this cycle**: the card shows "next visit in
  [time]" instead of Give/Decline, reusing `festival_phase_remaining_ms()`'s
  countdown-formatting pattern (`format_duration()`).
- **Game reopened mid-visit, already resolved**: `chanda_last_resolved_cycle_index`
  is checked against the *current* cycle index, so a stale resolution from
  a previous occurrence never blocks a fresh one — same lazy-reset shape as
  `_with_fresh_event_occurrence()`.
- **Blessing active when a new visit starts**: unaffected — the blessing is
  purely a sell-multiplier timer, independent of visit-resolution state; a
  new visit can start and be given-to while a previous blessing is still
  running (stacking is NOT allowed — a second Give simply resets the same
  `active_until` timer forward, never adds a second multiplier).
- **Farmhouse level changes mid-cycle**: ask amount is computed live at
  render/give time from the *current* `farmhouse_level`, not cached from
  when the visit started.

## 6. Dependencies

- `game_data.gd` (new constants + `ChandaFestivalDef` rotation table,
  mirrors `FestivalDef`/`festival_def()` exactly)
- `game_state.gd` (2 new `@export` fields)
- `game_economy.gd` (`is_chanda_visit_active()`, `current_chanda_festival()`,
  `chanda_visit_phase_remaining_ms()`, `give_chanda()`, `decline_chanda()`,
  blessing multiplier folded into `_sell_price_multiplier()`'s composition)
- `events_tab.gd` (new `ChandaCard`, alongside the existing
  `MonsoonCard`/`FestivalCard` — same sheet, no new UI surface)
- Does **not** touch `village_board.gd`/`board_interactor.gd` — no new 3D
  board NPC or tap-interaction this pass (see Tuning Knobs); the visit is
  presented entirely through the existing Events sheet.

## 7. Tuning Knobs

- `CHANDA_CYCLE_MS` / `CHANDA_ACTIVE_DURATION_MS` — visit frequency and
  window length.
- `CHANDA_BASE_ASK` / `CHANDA_ASK_PER_LEVEL` — ask amount scaling.
- `CHANDA_BLESSING_MULTIPLIER` / `CHANDA_BLESSING_DURATION_MS` — reward
  strength and duration.
- The 4-festival rotation order/list itself — data-driven via
  `GameData._chanda_festivals`, same shape as `_festivals`.
- **Future stretch, explicitly out of scope this pass**: a real 3D visiting
  NPC on the village board (reusing the villager rendering pipeline, per
  the original scoping brief) instead of a sheet-only presentation. Flagged
  here rather than silently expanded into, since it touches
  `board_interactor.gd`'s gesture system and is materially larger scope.

## 8. Acceptance Criteria

- [ ] A Chanda Visit becomes active/inactive on schedule, verified via unit
      tests at cycle boundaries (mirrors `is_festival_active()`'s own test
      coverage shape).
- [ ] The 4 festivals rotate in a fixed, even order — no festival ever
      appears 0% or disproportionately often across cycle indices.
- [ ] Give deducts the correct ask amount, starts the blessing, and is
      blocked (button disabled, not silently failing) when unaffordable.
- [ ] Decline costs nothing, grants no buff, and the visit is still marked
      resolved for that cycle.
- [ ] The blessing multiplier composes correctly with the existing
      Farmhouse sell-price multiplier and expires exactly at
      `chanda_blessing_active_until`.
- [ ] A second Give while a blessing is already active resets the timer
      rather than stacking multipliers.
- [ ] Full GUT suite green; new tests follow this project's
      `test_[system]_[scenario]_[expected]` naming convention.
- [ ] Verified on-device: the Events sheet renders the `ChandaCard`
      correctly during an active visit, Give/Decline both work and persist
      correctly across a save/reload.
