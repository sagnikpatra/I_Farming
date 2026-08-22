# Festival Visiting NPCs — "Chanda" Events

---
**Status**: Implemented and shipped — live in the game
**Verified By**: 26 GUT tests (`test_chanda_visit.gd`), full suite green
(commit `56c62a9`), and real on-device verification (Eid card rendered,
Give deducted 300→280 coins and started the "+8% sell price for 1h 59m"
blessing, confirmed correctly on a real device)
**Update (2026-08-22)**: this document's Acceptance Criteria checkboxes
below had gone stale — left unchecked even after the feature was fully
built, tested, and verified. Corrected to reflect reality; see each
checkbox for what's actually confirmed and by what evidence.
**Update (2026-08-22, cont'd)**: the "future stretch" on-board visitor
NPC is now also decided and built — see Detailed Rules, Tuning Knobs, and
the new "On-Board Visitor NPC" Acceptance Criteria section below. 607/607
GUT tests passing (up from 592), run twice non-flaky, and verified live
on a real device (see that section's evidence screenshots).
---

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
- **On-board visitor (decided and built 2026-08-22)**: while a visit is
  awaiting a decision, a stationary `ChandaVisitor` NPC appears on the
  village board at the nearest open tile adjacent to the Farmhouse's
  current footprint (`ChandaVisitorPlacement.find_visitor_tile()`, a fixed
  search order: south, east, north, west). It reuses the `Villager`
  rendering/animation class (a random character each occurrence, playing
  an idle clip — see `richer-ambient-villagers.md`'s `Idle_A` clip) and is
  tappable via the same `PICK_LAYER_VILLAGERS` ray-picking dispatch every
  other board-tappable actor uses. Tapping it opens the **same** Events
  sheet the LiveOps banner already opens (`Hud.open_events_sheet()`) — a
  second, cosmetic discovery path into the existing Give/Decline flow, not
  a new give/decline UI of its own. The NPC despawns the instant the visit
  resolves (Give or Decline) or its active window ends, and spawns fresh
  on the next cycle's occurrence.

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
- **Update (2026-08-22)**: the board-NPC stretch is now built, touching
  `village_board.gd` (`_sync_chanda_visitor_if_needed()`/
  `_spawn_chanda_visitor()`/`_despawn_chanda_visitor()`, hooked into the
  3s growth tick and `persist_and_rebuild_if_dirty()`, same pattern as
  `_sync_villagers_if_needed()`), `board_interactor.gd`
  (`_open_chanda_visit_sheet()`, a new `NORMAL_PICK` dispatch branch), and
  `hud.gd` (`open_events_sheet()`, extracted from
  `_on_liveops_banner_pressed()` so both paths share one sheet-opening
  implementation). New files: `chanda_visitor.gd`/`.tscn` (the NPC node,
  reusing `Villager`) and `chanda_visitor_placement.gd` (pure tile-
  selection logic). The Events sheet itself is unchanged — this only adds
  a second way to reach it.

## 7. Tuning Knobs

- `CHANDA_CYCLE_MS` / `CHANDA_ACTIVE_DURATION_MS` — visit frequency and
  window length.
- `CHANDA_BASE_ASK` / `CHANDA_ASK_PER_LEVEL` — ask amount scaling.
- `CHANDA_BLESSING_MULTIPLIER` / `CHANDA_BLESSING_DURATION_MS` — reward
  strength and duration.
- The 4-festival rotation order/list itself — data-driven via
  `GameData._chanda_festivals`, same shape as `_festivals`.
- **On-board visitor NPC — decided and built (2026-08-22)**: a real 3D
  visiting NPC on the village board, reusing the villager rendering
  pipeline, was originally flagged as a "future stretch... materially
  larger scope." Built rather than left open, scoped narrowly to keep
  that risk contained: the NPC is deliberately **stationary** (not a
  `VillagerRoamer` with pathfinding — it stays put at one tile adjacent to
  the Farmhouse for the whole visit window) and tapping it **reuses** the
  existing Events sheet rather than building a second give/decline UI.
  Both narrowings are what kept this from actually touching
  `board_interactor.gd`'s gesture *state machine* — it only adds one new
  `NORMAL_PICK` dispatch branch, the same shape `villagers.md` rule 8's
  tap interaction already established. See Detailed Rules §3 for the
  full shape.

## 8. Acceptance Criteria

- [x] A Chanda Visit becomes active/inactive on schedule, verified via unit
      tests at cycle boundaries (mirrors `is_festival_active()`'s own test
      coverage shape) — `test_chanda_visit_active_within_the_active_window`/
      `test_chanda_visit_inactive_past_the_active_window`/
      `test_chanda_visit_active_again_on_the_next_cycle`.
- [x] The 4 festivals rotate in a fixed, even order — no festival ever
      appears 0% or disproportionately often across cycle indices —
      `test_chanda_festival_rotates_through_all_four_in_a_fixed_order`.
- [x] Give deducts the correct ask amount, starts the blessing, and is
      blocked (button disabled, not silently failing) when unaffordable —
      covered headlessly (`test_give_chanda_deducts_the_ask_and_marks_resolved`,
      `test_give_chanda_blocked_when_unaffordable`,
      `events_tab.gd`'s `can_afford_chanda`-gated button) and confirmed live
      on-device (Eid card, 300→280 coins, blessing banner shown correctly).
- [x] Decline costs nothing, grants no buff, and the visit is still marked
      resolved for that cycle — `test_decline_chanda_costs_nothing_and_grants_no_blessing`/
      `test_decline_chanda_still_marks_the_occurrence_resolved`. Headless-only;
      not separately exercised on-device (Give was the on-device sample).
- [x] The blessing multiplier composes correctly with the existing
      Farmhouse sell-price multiplier and expires exactly at
      `chanda_blessing_active_until` —
      `test_blessing_increases_sell_proceeds_while_active`/
      `test_blessing_no_longer_applies_once_it_expires`.
- [x] A second Give while a blessing is already active resets the timer
      rather than stacking multipliers —
      `test_give_chanda_a_second_time_next_cycle_resets_rather_than_stacks_the_blessing`.
- [x] Full GUT suite green; new tests follow this project's
      `test_[system]_[scenario]_[expected]` naming convention — 26 tests in
      `test_chanda_visit.gd`, full suite passing (592/592 as of this
      document's last verification pass, run twice non-flaky).
- [x] Verified on-device: the Events sheet renders the `ChandaCard`
      correctly during an active visit, and both Give and Decline work
      and persist correctly across a real app restart — confirmed live
      on a real device. **Update (2026-08-23)**: the two narrower gaps
      this checkbox used to note are now closed too. Decline: confirmed
      live — the neutral "Maybe next time -- no hard feelings." toast
      shows, coins stay unchanged, the card correctly switches to "Next
      visitor in 4h 40m," and (a nice incidental confirmation) the
      on-board `ChandaVisitor` NPC despawns immediately, which is why a
      tap at the same screen position fell through to the Farmhouse zone
      underneath it instead. Save/reload: force-stopped and relaunched
      the app after Declining, confirmed the LiveOps banner correctly
      still read "Monsoon Season" (not the Chanda-priority text) rather
      than resetting to a fresh awaiting-decision state — direct proof
      `chanda_last_resolved_cycle_index` round-trips through a real save
      file on a real device, not just `test_save_serializer.gd`'s
      headless proof. See
      `production/qa/evidence/chanda-decline-flow.png` and
      `chanda-decline-persists-after-relaunch.png`.

### On-Board Visitor NPC (2026-08-22)

- [x] `ChandaVisitorPlacement.find_visitor_tile()` returns the correct
      tile in a fixed, deterministic search order (south, then east, then
      north, then west), verified against a real `ZoneFixture` with
      reserved tiles progressively blocking each ring —
      `test_chanda_visitor_placement.gd` (7 tests, including an
      out-of-bounds-candidate case and a fully-boxed-in failure case
      returning `Vector2i(-1, -1)` rather than crashing).
- [x] The NPC spawns exactly when `chanda_visit_awaiting_decision()` is
      true and despawns exactly when it becomes false (Give, Decline, or
      window expiry) — `test_village_board.gd`'s
      `test_a_chanda_visit_awaiting_decision_spawns_a_board_visitor`/
      `test_giving_chanda_despawns_the_board_visitor`/
      `test_declining_chanda_despawns_the_board_visitor`/
      `test_a_resolved_visit_does_not_spawn_a_visitor_on_the_next_cycle_start`.
- [x] The NPC is built from real `Villager`/PickArea wiring (character
      instancing, idle animation, `PICK_LAYER_VILLAGERS` tagged
      `chanda_visitor`), not a placeholder — `test_chanda_visitor.gd`
      (3 tests).
- [x] Tapping the NPC opens the real Events sheet via the real
      `BoardInteractor` dispatch path, and that path is provably the same
      one the LiveOps banner uses (not a parallel duplicate) —
      `test_chanda_visitor_tap_interaction.gd`'s
      `test_tapping_the_chanda_visitor_opens_the_real_events_sheet`/
      `test_opening_the_events_sheet_via_a_visitor_tap_matches_the_banners_own_path`.
- [x] Full GUT suite green — 607/607 (592 + 15 new), run twice, non-flaky.
- [x] Verified on-device: the NPC visibly appears on the board adjacent to
      the Farmhouse during an active visit and tapping it opens the real
      Events sheet — confirmed live on a real device (temporarily forcing
      `CHANDA_ACTIVE_DURATION_MS == CHANDA_CYCLE_MS` to guarantee an
      active window without waiting on real wall-clock timing, same
      instrument-then-delete technique used elsewhere this session,
      reverted immediately after capturing evidence). See
      `production/qa/evidence/chanda-visitor-on-board.png` (the visitor
      standing beside the Farmhouse, LiveOps banner reading "🪔 Baisakhi
      chanda visitor") and `chanda-visitor-tap-opens-events-sheet.png`
      (tapping it opened the real Events sheet showing Monsoon/Festival/
      Chanda/Daily-Tasks cards together — the same shared sheet, not a
      duplicate UI). Despawn-after-decision is covered headlessly
      (`test_giving_chanda_despawns_the_board_visitor`) rather than
      separately re-verified on-device in this same pass.
