# Worker Economy — Design Document

---
**Status**: Confirmed — all open questions resolved by the user, ready for implementation
**Source**: Your direct answers to this session's clarifying questions (2026-08-21, quoted inline below); `docs/architecture/godot-migration-roadmap.md`'s EPIC-M7 (Worker Assignment & Wage Economy) — which is otherwise just a name and a size estimate, no prior design material; `design/gdd/crop-economy.md`'s existing plot lifecycle and lazy offline-resolution pattern, which this system extends rather than duplicates; `design/gdd/villagers.md`'s EPIC-M6 roster, which this system reuses per your answer
**Date**: 2026-08-21
**Verified By**: User — §3.6's visibility interpretation and all 4 of §5's edge cases confirmed 2026-08-21; §4's wage rate balance-checked 2026-08-21 (`/balance-check`), one formula bug found and fixed (see §4's Status column)
**Implementation Status**: **Update (2026-08-22) — this line had gone stale.** Complete: economy backend (assignment, eligibility, lazy harvest-and-replant automation, wage, all 3 confirmed edge cases — inventory-full, can't-afford-replant, Electricity-lapsed), the player-facing assign/unassign UI (`worker_assignment_row.gd`, now localized too — see `docs/architecture/localization-pipeline.md`), and the visual "stationed at zone" rendering for an assigned villager (§3.6, `WorkerStation`). Verified live via real touch input, 327/327 passing at EPIC-M7 close (545+ project-wide as of later sessions). See `docs/architecture/godot-migration-roadmap.md`'s EPIC-M7 section — marked Complete.
---

> **Unlike `villagers.md`, this document had almost no prior source
> material to ground it in.** `v2.md` never mentions workers, wages,
> hiring, or labor anywhere. Everything below traces either directly to
> your answers in this session or to a deliberate extension of an
> existing, already-implemented mechanic (crop-economy.md's lazy
> offline-resolution pattern). The core mechanics and every behavioral
> edge case are now confirmed (2026-08-21) — remaining **🔶 Proposed**
> markers below are specifically *tuning values* (the exact wage rate,
> whether a hire fee should exist) explicitly deferred to a
> `/balance-check` pass with real data, not open design questions.

---

## 1. Overview

Workers let the player assign an existing villager (from EPIC-M6's
ambient roster) to a specific structure zone, where it automates that
zone's plot labor — harvesting ready crops and replanting — including
while the player is away from the game, in exchange for a wage paid out
of the harvest's value. This is both an automation convenience (per your
answer: "both automation and a sink") and a new recurring coin sink,
consistent with `v2.md`'s own "continuous operational sinks" economy
pillar (`land-and-structures.md` already implements this pattern for
Polyhouse's UV Film and Vertical Farm's Electricity).

## 2. Player Fantasy

The player has been personally tapping every plant and harvest since day
one. Hiring a worker is the moment the farm stops being something the
player does entirely by hand and starts being something the player
*manages* — delegating the repetitive parts of a zone they've already
mastered so they can focus attention (and taps) on expansion, trading, or
a different zone, while still paying a real cost for that convenience so
it reads as a genuine trade-off, not a free win.

## 3. Detailed Rules

1. **Assignment source**: workers are assigned *from* the player's
   existing EPIC-M6 villager roster, not hired as separate new entities —
   per your answer, "workers are to be assigned by the villager." A
   villager currently roaming ambiently can be assigned to a zone; once
   assigned, it is no longer part of the ambient-roaming population (see
   Dependencies §6 for the exact hand-off with `VillagerSpawner`).
2. **Assignment granularity — 🔶 Proposed**: a worker is assigned to a
   *zone* (e.g., "assign this villager to the Polyhouse"), not to an
   individual plot. Once assigned, it automates *every* plot in that
   zone, not just one. Chosen because the game already organizes player
   interaction at the zone level (management sheets, pickers) — assigning
   per-plot would be a finer grain than anything else in the game
   currently uses, without an obvious player benefit.
3. **What automation means, concretely**: for each of the assigned
   zone's plots, whenever that plot is `ReadyToHarvest`
   (`crop-economy.md` §2.1's plot lifecycle), the worker automatically
   harvests it and immediately replants the same crop that was just
   harvested — no player tap required. This reuses the existing
   `harvestPlot()`/`plantSeed()` economy calls; a worker does not bypass
   any of their existing rules (inventory-capacity blocking a harvest,
   affordability blocking a replant, Vertical Farm's Electricity
   requirement, etc. all still apply — see §5 Edge Cases for what happens
   when one of those blocks an automated action).
4. **Offline-safe by construction, not by new machinery**: per your
   answer, "they will work when \[the player is] offline." This reuses
   `crop-economy.md`'s existing lazy-resolution pattern
   (`resolveGrowthCompletions(now)`, which already makes ordinary crop
   growth "just work" across an offline gap) rather than inventing a
   background service — worker actions resolve the same way, on the next
   state read, by replaying elapsed time. This is a deliberate consistency
   choice: the game already has exactly one pattern for "things that
   happen while the app is closed," and workers should use that pattern,
   not a second one.
5. **Wages — 🔶 Proposed formula, confirmed concept**: per your answer,
   "the villagers will charge for doing work." Proposed: a wage is
   deducted **per completed harvest-and-replant cycle**, not a flat
   per-assignment hire fee or a pure time-based salary — tying cost
   directly to value delivered (every automated cycle both saves the
   player a tap and costs a wage), and reusing the same "resolved lazily
   alongside growth" mechanism above rather than a separate ticking cost.
   See §4 Formulas for the actual rate proposal.
6. **Visibility — Confirmed 2026-08-21**: "idle" describes an
   **unassigned** villager — today's EPIC-M6 ambient roaming *is* the
   idle state, unchanged by this document. "Called" describes an
   **assigned** villager: assigning a worker pulls it out of the ambient
   roaming population (§3.1) and it becomes visibly active *at its
   assigned zone* — this is the "called" state, not a background/
   invisible one. Concretely: an assigned worker walks to (or is placed
   at) its zone and is visible there, performing a work-appropriate pose/
   animation, rather than continuing to wander the open ground. It does
   not roam elsewhere on the board while assigned. This resolves cleanly
   against `villagers.md`'s existing architecture — an assigned worker
   simply stops being one of `VillagerSpawner`'s roaming population and
   becomes a new, distinct "stationed at a zone" entity instead, using
   the same `Villager` character-rendering component but different
   movement/placement logic than `VillagerRoamer`.
7. **Un-assignment**: the player can un-assign a worker at any time,
   returning it to the EPIC-M6 ambient-roaming population immediately (no
   cooldown, no penalty) — mirrors this game's existing pattern of
   free/reversible layout actions (zone drag, decoration placement) having
   no lock-in.

## 4. Formulas

| Formula | Expression | Purpose | Status |
|---|---|---|---|
| Wage per harvest-and-replant cycle | `crop.baseSellPrice × (0.5 if damaged else 1.0) × 0.15` (15% of that crop's *actually realized* sell value — the same 0.5× damage scaling `sell_crop()` applies — min ₹1) | Ties cost to value delivered; a worker nets the player ~80-81% of manual-harvest net profit per cycle for 6 of the 8 eligible crops instead of 100%, the "convenience tax" | ✅ Balance-checked 2026-08-21, extended to all 8 eligible crops the same day after a follow-up pass (see `production/balance/` or the `/balance-check` session) — 15% confirmed proportionally consistent (18.8–20.8% of net profit) across 6 of 8 crops. **One real bug found and fixed**: the formula originally ignored damage entirely, charging the full undamaged rate even on a harvest that sold for half (an effective ~30% cut, contradicting §5's own "only charge for value delivered" principle) — now fixed in `game_economy.gd`'s `_worker_wage_for()`, covered by a regression test. **Two crops, not one, sit outside that band**: cut% = 15% ÷ (1 − seedCost/baseSellPrice) is an exact function of a crop's own seed-cost-to-price ratio, so any crop with an unusually high ratio pays a disproportionate net cut regardless of the flat 15% rate being "fair" in gross terms — Wheat (50% ratio) at 30.0% and **Paddy (37.5% ratio) at 24.0%** both breach the ~20% ceiling the other 6 crops stay under (see the full 8-crop table in the balance-check session). Left as an open designer call, not a blocker — the flat-15%-of-gross design itself isn't wrong, but neither Open-Field starter crop is priced to fit it comfortably. Also noted, also left open: stacking a worker onto Polyhouse/Vertical Farm's own recurring sink (UV Film/Electricity) roughly doubles-to-triples that zone's total "tax" (10–11% → 22–26%) |
| Assignment cost | None proposed (free to assign/un-assign) | Keeps the friction entirely in the recurring wage, not an entry fee, so the player can experiment freely | 🔶 Proposed — an alternative would add a one-time hire cost too; deliberately not proposed here to keep this document's invented-formula surface as small as possible |
| Worker capacity | 1 worker per zone (matches §3.2's per-zone assignment granularity); no stated cap on how many zones can have a worker simultaneously, bounded naturally by the EPIC-M6 roster size (currently 6 villagers total) | Simplicity — no new cap to invent when the roster size already bounds it | 🔶 Proposed |

**Worked example** (added 2026-08-21, post-balance-check): a Capsicum
(Polyhouse) harvest — base sell price ₹650 — nets the player ₹650 - ₹150
seed cost = ₹500 manually, or ₹650 - ₹98 wage - ₹150 seed cost = ₹402 via
a worker (80.4% of manual net kept, a 19.6% cut). If that same harvest
arrives damaged (spoiled past Polyhouse's grace window, or, for an
Open-Field crop, a weather/pest roll), the wage itself now halves to ₹49
(matching the crop's own halved ₹325 realized sale value) rather than
staying at ₹98 — see §4's Status column for why that damage-scaling was a
real bug, now fixed.

**Worked example, the two outliers** (added 2026-08-21, follow-up pass):
Wheat — base sell price ₹20, seed cost ₹10 — nets ₹10 manually vs. ₹7 via
a worker (a 30% cut). Paddy — base sell price ₹80, seed cost ₹30 — nets
₹50 manually vs. ₹38 via a worker (a 24% cut). Both are Open-Field starter
crops with an unusually high seed-cost-to-price ratio (50% and 37.5%
respectively, vs. 20–28% for the other 6 eligible crops) — the flat 15% of
*gross* value lands as a much larger bite out of *net* profit precisely
because seed cost already consumes so much of the gross value before the
wage is even subtracted.

## 5. Edge Cases

**Resolved (2026-08-21)** — every automated-cycle blocker follows the
same underlying principle: a worker only ever charges a wage for value it
actually delivered, and never takes an action the player didn't
implicitly authorize (no forced sales, no silent crop substitutions, no
auto-spending beyond the wage itself):
- **Inventory full** at harvest time: skip this cycle entirely, retry on
  the next resolution. No wage charged (no work was done). The
  `ReadyToHarvest` crop simply waits, same as it would for a human player
  who hasn't gotten around to harvesting yet.
- **Can't afford the replant's `seedCost`**: the worker still harvests
  the ready crop (banking that value, wage still charged for the
  harvest) but leaves the plot `Empty` rather than replanting. Partial
  automation beats none; the plot picks up replanting again on a later
  cycle once funds allow.
- **Vertical Farm's Electricity credit lapses**: the worker pauses —
  cannot start a new Saffron grow cycle until the player renews
  Electricity themselves (matches `crop-economy.md`'s existing rule that
  Electricity gates *starting* a grow, not an in-progress one) — and
  charges no wage while paused, consistent with the "only charge for
  real work" principle above.
- **The zone itself becomes unavailable** (sold back, etc.): confirmed
  moot, not resolved by a game-design decision — no structure in this
  game has a sell-back path (`land-and-structures.md` §3), so this case
  cannot currently occur. Worth re-checking if a sell-back mechanic is
  ever added later, not something to build defensive handling for now.

**Handled by extension of existing rules, not new invention**:
- A worker's harvest/replant still obeys every existing rule
  (`crop-economy.md`'s weather/pest risk roll, Polyhouse spoilage,
  Agroforestry theft, Vertical Farm Electricity gating) exactly as a
  manual action would — a worker is a *trigger*, not a rules exception.

## 6. Dependencies

**Update (2026-08-22)**: all three "should note" cross-references below
were the design-time expectation, written before implementation — all
three are now confirmed actually present in the referenced docs' own
Dependents sections, not still-open TODOs.

**Design Dependencies**:
- `villagers.md` — this document's entire worker roster *is* that
  document's villager roster; an assigned worker is removed from
  `VillagerSpawner`'s ambient-roaming population (exact hand-off
  mechanism is engineering work, not decided here, but the *rule* that
  assigned ≠ ambient-roaming is a real design decision made in §3.1).
  Confirmed present in `villagers.md`'s own Dependents section.
- `crop-economy.md` — this document's automation (§3.3) and offline-safety
  (§3.4) are both direct extensions of that document's plot lifecycle and
  lazy-resolution pattern, not new mechanics. Confirmed present in
  `crop-economy.md`'s own Dependents section (`harvestPlot()`/
  `plantSeed()` called on the player's behalf).
- `land-and-structures.md` — workers are assigned to that document's
  structure zones. Confirmed present in `land-and-structures.md`'s own
  Dependents section.

**Technical Dependencies**: **Update — this line had gone stale.**
Fully implemented: `game_economy.gd` (`assign_worker`/`unassign_worker`/
`resolve_worker_actions`), `worker_assignment_row.gd` (the assign/
unassign UI, embedded in every eligible zone sheet), `village_board.gd`
(`WorkerStation` visual stationing). See the Implementation Status line
at the top of this document.

**Content Dependencies**: None beyond the EPIC-M6 character roster
already sourced.

## 7. Tuning Knobs

| Knob | Safe Range | Affects | Notes |
|---|---|---|---|
| Wage rate (% of crop base sell price) | 15% confirmed reasonable 2026-08-21, extended to all 8 crops the same day — safe range is roughly 10-20%; below ~10% the automation approaches a "free win" (against the Player Fantasy's explicit "genuine trade-off" goal), above ~20% Wheat's and Paddy's already-thin margins (see §4) start turning worker-assignment into a net loss for those two zones specifically | How much of a worker's value the player keeps vs. pays out | Balance-checked against the real crop value table (see §4). Do not tune this rate without re-running `/balance-check` — Wheat (50% seed-cost-to-price ratio) and Paddy (37.5%) are BOTH binding constraints on how high it can safely go, not just Wheat |
| Worker capacity (zones simultaneously staffed) | Bounded by roster size (currently 6) | How much of the game a player can fully automate at once | Not independently tunable yet — a direct function of `villagers.md`'s roster size knob |

## 8. Acceptance Criteria

**Status, 2026-08-22 (update — fully built and verified, this section had gone stale)**:
- [x] A villager can be assigned to a specific zone (`assign_worker()`) —
      both the economy layer and the player-facing UI
      (`worker_assignment_row.gd`, embedded in every eligible zone sheet)
      exist and are wired together
- [x] An assigned zone's `ReadyToHarvest` plots are automatically
      harvested and replanted with the same crop, without a player tap —
      `resolve_worker_actions()`, tested against Wheat/Open-Field
- [x] This resolves correctly across an offline gap, using the same
      elapsed-time-replay pattern as ordinary crop growth — same
      lazy-resolution mechanism as `resolve_growth_completions()`, wired
      into the same growth-tick call site
- [x] A wage is deducted per completed automated cycle, and only per
      cycle where real work happened (not on a skipped/paused cycle) —
      verified for all 3 economically-relevant edge cases (inventory
      full charges nothing; can't-afford-replant still charges for the
      harvest; Electricity-lapsed charges nothing while paused)
- [x] An assigned villager is removed from the EPIC-M6 ambient-roaming
      population while assigned, and returns to it on un-assignment —
      confirmed in `villager_spawner.gd` (`roaming_count` is computed as
      the target population minus `state.worker_assignments.size()`),
      plus the visual "stationed at zone" rendering (`WorkerStation`,
      `village_board.gd`'s `_sync_worker_stations()`)
- [x] Every edge case in §5 has an explicit, confirmed answer — resolved
      2026-08-21, and now also covered by passing tests, not just design
      text

**Definition of Done for this document specifically**: ✅ met, and the
implementation it specified is also ✅ complete (EPIC-M7, 327/327 at
close). §3.6's visibility interpretation and all 4 of §5's edge cases
are confirmed by the user, not assumed. The wage rate (§4, 15%) was
balance-checked 2026-08-21 against all 8 eligible crops — confirmed
proportionally reasonable, with one real formula bug (missing damage
scaling) found and fixed in the implementation. Two non-blocking
designer calls remain open (Wheat's *and Paddy's* disproportionate
net-profit cut; worker+structural-sink stacking on Polyhouse/Vertical
Farm) — noted in §4/§7, not required before this document can be
considered done.

---

**Next Steps**: Design confirmed and fully implemented (EPIC-M7,
Complete). The bidirectional dependency notes in §6 are confirmed
present in `villagers.md`/`crop-economy.md`/`land-and-structures.md`.

**Related Skills**: `/design-review design/gdd/worker-economy.md`, `/balance-check` (once implemented, for the wage formula)

---

*Authored 2026-08-21 in response to "continue with EPIC-M7", grounded in your direct answers to this session's clarifying questions.*
