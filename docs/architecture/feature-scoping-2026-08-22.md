# Feature Scoping Pass — 2026-08-22

> **Status**: Scoping briefs, not final GDDs. Produced by `game-designer` at
> the project owner's request, to inform roadmap sequencing before any
> single item gets a full 8-section GDD (`design/gdd/` template) and gets
> built. Nothing here is approved for implementation yet — each item still
> needs its own Question -> Options -> Decision -> Draft -> Approval pass
> per `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`.

## Source request

The project owner asked for a batch of new features in one message
(2026-08-21/22): villager walking animation, building upgrades changing the
visual layout, land unlocked by money, gems earned via daily tasks, cloud
save via a backend, weather tied to real-world timezone, more/livelier
villagers, and festival visiting-NPC events. Two of those were confirmed
already built before this scoping pass started (see below); cloud save got
its own ADR (`adr-0003-cloud-save-and-player-accounts.md`) since it's an
architecture-level decision, not a design brief. The festival visiting-NPC
item was parked entirely after a scope discussion with the owner (2026-08-22)
— see note at the end of item 5.

## Already built (confirmed, not re-scoped)

- **Villager walking animation** — villagers already play a continuous
  `Walking_A` clip while roaming (`villager.gd`'s `DEFAULT_ANIMATION`); by
  design there's no idle clip at all (`villager_roamer.gd` §3.4).
- **Land unlocked by money** — plot/zone unlock pricing already exists
  (`game_data.gd`/`game_economy.gd`, "land-expansion pricing" in the
  balance docs).

---

## 1. Building Upgrades Change Visual Layout

**Core concept**: Tie structure tiers to distinct 3D models/footprints on
the village board — most importantly Farmhouse's 8 numeric levels,
secondarily the one-time structure unlocks (Polyhouse/Agroforestry/
Aquaculture/Vertical Farm) and their sub-upgrades (Fan & Pad, UV Film,
Security, Electricity).

**Why it fits**: Closes a real gap between stated intent and
implementation. `farmhouse-progression.md` quotes `v2.md` directly: the
Farmhouse is meant to be "a central visual representation of [the
player's] success," growing from "a humble rural home" into "a sprawling
Haveli or modern agricultural estate" — but today it's purely three
numeric multipliers with a level-index int.

**Key mechanics/rules**:
- Bucket the 8 Farmhouse levels into ~4 visually-distinct model tiers (not
  8 unique assets): Hut (Lv0-1) -> Pucca/Bungalow (Lv2-4) -> Haveli (Lv5-6)
  -> Estate (Lv7). Keeps CC0-asset-sourcing burden bounded.
- One-time structure unlocks already go absent -> full model on unlock;
  sub-upgrades get small visual *attachments* (fence, shed, tint) rather
  than full model swaps — cheaper, and communicates "which add-ons are
  active" at a glance.
- An upgrade purchase should trigger a visible transform beat (swap + a
  small juice effect) as immediate feedback tied to the large currency spend.
- **Open question**: should the footprint grow with tier, or stay fixed and
  just re-skin? Growing footprint is the stronger fantasy payoff but forces
  resolution of `land-and-structures.md`'s existing open question
  ("zone/decoration collision validation — pure layout preference or
  enforced?"), since a bigger Farmhouse could newly overlap something the
  player placed.

**Interactions**: `farmhouse-progression.md` (tier table gains a
visual-tier mapping column), `land-and-structures.md` (footprint/collision),
`village_fixture_data.gd`/`village_snapshot_mapper.gd` (technical precedent
already exists — `crop_stage_model_path()` already does per-stage model
swapping for crops; same pattern is directly reusable for structure tiers).

**Complexity**: **M** if scoped to Farmhouse-only, fixed footprint, model
re-skin only. **L** if footprint growth and/or sub-upgrade attachments for
all 4 structure types are included. Recommend starting at M, footprint
growth as a v2 stretch.

---

## 2. Gems Currency via Daily Tasks

**Core concept**: A new secondary currency ("Gems") earned only by
completing a small rotating pool of daily tasks that reuse existing player
verbs (harvest, sell, plant, worker-cycle). Gems buy cosmetic/convenience
items that rupees can't, explicitly walled off from economic power.

**Why it fits**: Gives a short, legible daily goal ladder distinct from the
game's existing very-long-horizon rupee sinks (Farmhouse/Land/Polyhouse
costs are exponential and multi-session). A genuine reason to return daily,
which the current wall-clock LiveOps events (hours-long cycles, not
calendar-day-anchored) don't really provide.

**Key mechanics/rules**:
- Pool of 3-5 daily tasks (e.g. "Harvest N crops," "Sell to Mandi X times,"
  "Complete N worker cycles," "Earn ₹X") drawn from a template pool — no new
  gameplay verbs required, purely a reward wrapper.
- Reset anchor: recommend **real device local midnight**, not a
  wall-clock-modulo cycle — a deliberate divergence from the existing
  Monsoon/Festival pattern, flagged explicitly as new precedent.
- Reward shape: flat small gem amount per task + a bonus for completing all
  tasks same day.
- **Anti-pay-to-win guardrails (explicit, not implied)**: gems must not
  directly buy rupees or meaningfully outpace the existing economy's sink
  curve. Recommend gems buy (a) gem-exclusive cosmetic decorations, (b)
  capped convenience skips (e.g. one grow-time skip per day, hard-capped).
  No rupee-to-gem or gem-to-rupee exchange.
- **Open question, not assumed**: should gems ever be real-money
  purchasable? No IAP/billing integration exists anywhere in the stack
  today — if yes, that's a genuinely new technical dependency (Google Play
  Billing), its own decision, not a small addition.

**Interactions**: Can reuse `liveops-events.md`'s proven
`withFreshEventOccurrence`-style lazy-reset-on-read pattern directly for
daily task tracking. `worker-economy.md` (a worker-cycle-based task rewards
the automation system). `land-and-structures.md`'s `DecorationType` gains a
gem-cost field if gem-exclusive decorations are added.

**Complexity**: **M** without real-money purchase (pure grind-reward
currency, reuses proven lazy-reset architecture). **L** if real-money gem
purchases are added (new billing integration, needs its own decision first).

---

## 3. Weather Tied to Real-World Timezone

**Core concept**: Layer real-device-local-time-driven ambient presentation
(and optionally season) on top of — not replacing — the existing
in-game-abstracted Monsoon Season.

**Why it fits**: Real-world timing was actually `v2.md`'s *original*
Monsoon intent ("a server-wide Monsoon Season lasting one real-world
week") — the shipped Monsoon deliberately compressed that into an abstract
6h/90min wall-clock cycle for pacing reasons. Real-world-timezone weather is
a *different* idea worth treating separately: grounding ambient
presentation in the player's actual local time without re-touching
Monsoon's already-tuned gameplay math.

**Three options** (recommendation: A or B):

| Option | What it does | Touches gameplay math? | Risk |
|---|---|---|---|
| **A — Cosmetic day/night only** | Sky/lighting/lamp-lighting reflects real device local hour | No | Low — pure presentation layer |
| **B — Cosmetic + loose season skin** | Real-calendar-month -> India's 3 broad seasons (Monsoon Jun-Sep/Winter Oct-Feb/Summer Mar-May) as an ambient palette shift | No | Low-Medium — needs season-detection + palette assets |
| **C — Mechanically layered** | Real-world monsoon months bias the existing gameplay Monsoon Season's active-window frequency | Yes | **Not recommended** — entangles two clean systems, and means players in different timezones/hemispheres get different actual difficulty |

**Key mechanics (recommended path)**: real local hour drives day/night
lighting + villager lamp-lighting; Monsoon Season keeps its own fully
independent compressed cycle exactly as documented today. Good synergy
point with item 4 (villagers going "home" at night).

**Interactions**: `liveops-events.md` must explicitly state this is
additive/independent, not a modification of Monsoon's formula.
`villagers.md` (day/night ambient behavior — shared work with item 4). New
technical dependency either way: reading device local time/timezone, which
nothing in the stack currently does.

**Complexity**: **S** for Option A, **M** for Option B, **L** for Option C
(not recommended without a specific reason).

---

## 4. More Villagers, Richer Ambient Behavior ("Living Peacefully")

**Core concept**: Extend `villagers.md`'s EPIC-M6 scope beyond "walk to
random tile, repeat, no idle" into a richer ambient state machine — idle
pauses, villager-to-villager "chatting," lingering near player-placed
decorations, day/night population thinning — while preserving the existing
"purely ambient, no player interaction" scope boundary unless the owner
wants to lift that too.

**Why it fits**: Explicitly flagged as open, unfinished territory in
`villagers.md` itself — the current continuous-no-idle walk is candidly
documented as a **content constraint** (the sourced animation rig has no
idle clip), not a design preference.

**Key mechanics/rules**:
- **Prerequisite check first**: `villagers.md` already flags
  `Rig_Medium_General.glb` as sourced-but-never-inspected for a real idle
  clip. If no usable idle animation exists, new asset sourcing becomes
  required (swings complexity up) — do this check before finalizing scope.
- Extend `VillagerRoamer`'s state machine: Walking (default) -> Idle-pause
  -> Congregate (two villagers path toward each other, both idle-pause =
  cheap readable "chatting," no dialogue/AI needed) -> Point-of-interest
  lingering (bias tile selection toward decoration tiles like the
  Well/Temple Shrine — gives the cosmetic Decorations economy its first
  functional feedback loop).
- Day/night population thinning, designed to work standalone with an
  abstracted in-game day/night cycle, with real-world time (item 3) as an
  optional enhancement, not a hard dependency.
- Population cap increase requires re-verifying the walkable-tile budget
  `villagers.md` already calculated (52% walkable at minimum-unlock state)
  at the new higher count.
- Explicitly **not** in scope for this pass: tap-to-interact/flavor text —
  `villagers.md` already calls that its own deliberate future scope
  decision.

**Interactions**: Direct revision/extension of `villagers.md`.
`land-and-structures.md`'s Decorations gain a "used by the village" payoff.
`worker-economy.md` must be explicitly confirmed unaffected — an
assigned/"called" worker keeps its own stationed-at-zone behavior and
shouldn't get swept into the new congregate/idle states meant for the
unassigned ambient population.

**Complexity**: **M**, contingent on the idle-animation asset check above —
stays M if a usable clip already exists; pushes toward **L** if new
animation sourcing is required. Recommend a quick technical-artist asset
check as literally the first step.

---

## 5. Festival Visiting-NPC "Chanda" Events — BUILT (2026-08-22)

**Status: Done.** Implemented as scoped — the full plural version, all
four festivals (Durga Puja, Eid, Christmas, Baisakhi) rotating in a fixed,
even order. See `design/gdd/festival-visiting-npcs.md` for the full design
and commit `56c62a9` for the implementation (economy layer, `ChandaCard`
in the Events sheet, 26 new/updated GUT tests, on-device verified on the
project owner's physical device).

**History, for the record**: during scoping the project owner initially
asked for a version that excluded Eid specifically while keeping the other
three festivals. That was declined — a feature that includes other
communities' festivals but specifically carves out Eid isn't a neutral
scope cut, it singles out one community for exclusion in a game about
representing Indian village life. The request was repeated once more and
declined again. The owner then briefly parked the whole feature, before
asking for it to be built as the original plural version, which is what
shipped here.

---

## Summary for Roadmap Planning

| # | Feature | Complexity | Key dependency / prerequisite | Status |
|---|---|---|---|---|
| 1 | Building upgrades change layout | M (Farmhouse-only) / L (footprint growth + all structures) | Resolves `land-and-structures.md`'s open collision-validation question if footprint grows | **Built (2026-08-22, commit `d03eaee` + a same-day stretch goal)** -- Farmhouse model re-skin, fixed footprint. **Footprint growth decided against, not deferred** (2026-08-22): the brief's own recommendation was fixed-footprint, and growing it would force resolving `land-and-structures.md`'s still-open collision-validation question as a side effect of a visual feature. The other 3 structures' sub-upgrades (Fan & Pad/UV Film/Drip Irrigation/Security/Electricity) shipped same-day as a shared warm-tint visual cue (not per-flag distinct attachments -- no sourced asset exists for any of them) -- item 1 has no open stretch goals left |
| 2 | Gems via daily tasks | M (grind-only) / L (if real-money purchasable) | Real-money path needs a billing-integration decision first | **Built (2026-08-22, commit `85a0079` + a same-day second-sink stretch goal)** -- grind-only, as scoped; real-money purchase stays explicitly out of scope (no billing integration exists). **Second sink also decided and shipped same-day**: a capped grow-time skip (10 gems, once per real calendar day) -- see `design/gdd/gems-second-sink.md`. Gem-exclusive decorations (the brief's other candidate) not pursued -- needs a new sourced 3D asset, deliberately avoided this pass. The skip's economy logic is fully unit-tested; the on-device button press itself was not visually confirmed (see that GDD's Acceptance Criteria) |
| 3 | Real-world-timezone weather | S/M (cosmetic, recommended) / L (mechanical, not recommended) | New device-timezone read dependency either way | **Built (2026-08-22, commit `81a0d3c` + 2 same-day stretch goals)** -- Option A (cosmetic day/night, S complexity); **both originally-deferred stretch goals now also shipped same-day**: Option B (seasonal palette -- real-calendar-month tint layered on the phase preset) and villager lamp-lighting (one `OmniLight3D` per structure, lit only at Night, no new 3D assets needed) -- item 3 has no open stretch goals left |
| 4 | Richer ambient villager behavior | M (contingent) / L (if new animation sourcing needed) | Verify `Rig_Medium_General.glb` has a usable idle clip first | **Built (2026-08-22, commits `028c36a` + 3 same-day stretch goals)** -- prerequisite confirmed true (Idle_A/Idle_B exist), idle-pause shipped at M; **all three originally-deferred stretch goals now also shipped same-day**: congregating (villagers turn to face each other), point-of-interest lingering (villagers bias toward decoration-adjacent tiles), and night population thinning (roaming population roughly halves at real-world Night, restores at Dawn) -- item 4 has no open stretch goals left |
| 5 | Festival chanda visiting-NPCs | L | — | **Built (2026-08-22, commit `56c62a9`)** |

All 5 items from this scoping pass are now built (2026-08-22) -- see each
row's linked GDD in `design/gdd/` and commit for the real implementation,
tests, and on-device evidence. Items 3 and 4 realized their flagged
synergy directly: item 4's idle-pause work reused item 3's real-time
infrastructure precedent (`local_hour()` mirrors `local_day_key()`'s exact
pure-function shape). Cloud save is tracked separately in
`adr-0003-cloud-save-and-player-accounts.md` (Proposed, not yet actioned).

**Update (2026-08-22, later the same day)**: every item's own stretch
goals have since been decided and, where they didn't need new art
content, built -- see each row above for the specifics. Two were
decided *against* rather than built (Farmhouse footprint growth,
gem-exclusive decorations), both for the same reason: pursuing them
would have meant either resolving an unrelated open architecture
question as a side effect of a visual feature, or taking on real new
3D-asset content-creation scope this pass deliberately stayed out of.
Nothing on this list remains open or undecided. Two items initially
carried an honestly-flagged on-device-screenshot gap -- the grow-time
skip button and Point-of-Interest Lingering -- both blocked by the same
real-device friction (screen lock interrupting debug builds, imprecise
tap-targeting on the isometric board). Both were closed the same way,
not by fighting the device further: a headless test that drives the
real, unmocked code path end to end and asserts the real outcome --
pressing the actual Skip Button node's `pressed` signal for the former,
and driving the real selection-roll -> pathfind -> movement chain to
confirm genuine tile arrival for the latter (see `gems-second-sink.md`
and `richer-ambient-villagers.md`'s own Acceptance Criteria for each).
Both are stronger, CI-durable proofs than a single screenshot would
have been. Cloud save is tracked separately in
`adr-0003-cloud-save-and-player-accounts.md` (Proposed, not yet
actioned). The project owner's next move, per the Collaborative Design
Principle, is a genuinely new direction -- the cloud-save ADR's
remaining Play Console step, or something not on this list at all.
