# Systems Index

A single map of every design document in `design/gdd/`, what each system
covers, its current implementation status, and how the systems connect.
Referenced by `CLAUDE.md`'s directory structure and by
`docs/architecture/godot-migration-roadmap.md`'s original "Kickoff
approach" as a planned deliverable — created 2026-08-22, later than
originally planned (the roadmap's own gate-docs-to-when-needed decision
meant it kept getting deferred past every epic that could have used it;
this fills that real, previously-unaddressed gap).

**Update this file when adding a new GDD to `design/gdd/`** (per
`design/CLAUDE.md`'s own rule) — a new row here, one line, no need to
duplicate the source document's content.

## Status Legend

- ✅ **Shipped** — implemented, tested, and live in the current Godot build
- 📄 **Reverse-Documented** — documents a system that shipped in the
  pre-migration Kotlin/LibGDX app and has since been ported to Godot;
  the design is stable and implemented, the label just reflects how the
  doc came to exist (written from working code, not before it)
- 🚧 **Partially Shipped** — core logic implemented and unit-tested, but
  the doc's own Acceptance Criteria section lists real, named gaps (not
  just "on-device unverified") — read that section before assuming the
  system is reachable in actual gameplay

Added 2026-08-23: the first two 🚧 entries below. Both were reverse-
documented the same way as the 📄 entries (written from working code,
after the fact) but for a different reason -- a prior session's 8-feature
sprint had claimed all 8 as done via unverified per-agent checkmarks; a
follow-up review found only these 2 (plus Farmhouse Progression's
passive-income addition, folded into the existing 📄 doc above) had real,
compiling logic behind them once independently checked. See
`production/session-state/active.md` for the full accounting, including
the 5 features that turned out to be inert/unwired stub files.

## Core Economy (Foundation)

| System | Doc | Status | One-Line Summary |
|---|---|---|---|
| Crop Economy | [`crop-economy.md`](crop-economy.md) | 📄 | The core plant → grow → harvest → sell loop every other economic system hooks into — the game's "heartbeat" per `v2.md`'s Core Game Loop. |
| Land & Structures | [`land-and-structures.md`](land-and-structures.md) | 📄 | Land-expansion economy plus the 4 cultivation-tier structures (Polyhouse, Agroforestry, Aquaculture, Vertical Farm) gating access to higher-value crops. |
| Farmhouse Progression | [`farmhouse-progression.md`](farmhouse-progression.md) | 📄 | The central 8-tier home upgrade — simultaneously the primary long-term coin sink and the source of 3 farm-wide bonuses (storage, growth speed, sell price). |
| Mandi Trading | [`mandi-trading.md`](mandi-trading.md) | 📄 | A second, variable-price sale channel modeled on India's real APMC mandi / e-NAM system, alongside the fixed-price Farmhouse sale. |

## Secondary Systems (Feature)

| System | Doc | Status | One-Line Summary |
|---|---|---|---|
| LiveOps Events | [`liveops-events.md`](liveops-events.md) | 📄 | Two recurring backend-free events layered on the core economy: Monsoon Season (open-field risk/reward) and the Festival Event Pass (Battle-Pass-style). |
| Gems & Daily Tasks | [`gems-daily-tasks.md`](gems-daily-tasks.md) | ✅ | A secondary currency earned via 3 real-calendar-day tasks drawn from a 5-task pool; its first spend is rerolling the day's task set. |
| Gems: Grow-Time Skip | [`gems-second-sink.md`](gems-second-sink.md) | ✅ | Gems' second sink — one capped, gem-costed grow-time skip per real calendar day. |
| Festival Visiting NPCs (Chanda) | [`festival-visiting-npcs.md`](festival-visiting-npcs.md) | ✅ | A recurring low-stakes neighbor visit collecting a small community donation for a rotating real Indian festival; giving grants a modest time-limited sell-price blessing. Includes an on-board 3D visitor NPC, not just a sheet card. |
| Worker Economy | [`worker-economy.md`](worker-economy.md) | ✅ | Assigns an existing ambient villager to a structure zone, where it automates that zone's plot labor (harvest + replant) for a wage, lazily resolved offline like crop growth. |
| Seasonal Crop Rotation | [`seasonal-crop-rotation.md`](seasonal-crop-rotation.md) | 🚧 | Ties crop plantability to 4 real-world-calendar seasons; gates `plant_seed()`. Core detection/lookup logic is real and tested; seed-picker UI greying-out is not yet implemented (plant attempt is rejected with a toast instead). |
| Farm Equipment | [`farm-equipment.md`](farm-equipment.md) | 🚧 | A 50-item purchasable tool/machinery collection, gated by both coins and land-expansion tier (Basic/Common available immediately, Luxury needs 11 expansions bought). Real purchase logic + a dedicated shop sheet, reachable from a new HUD button. Missing: no board placement (no fitting CC0 model exists in any sourced kit) and no gameplay bonus (ownership-only for now). |
| Thief NPC Visitor | [`thief-system.md`](thief-system.md) | ✅ | Periodic, cooldown-gated, wealth-scaled chance of a thief visit; security investment reduces probability. Fully wired and on-device verified: a real board NPC spawns, taps open a working choice sheet, a resolved choice deducts real coins, and `thief_security_level` is purchasable via a Farmhouse-tab card (`GameEconomy.buy_thief_security()`). No remaining documented gaps. |

## Village Board & Presentation

| System | Doc | Status | One-Line Summary |
|---|---|---|---|
| Villagers | [`villagers.md`](villagers.md) | ✅ | Ambient, non-persistent villager NPCs roaming the board's open ground so the farm reads as lived-in, not a static diorama. Includes cosmetic tap-to-greet interaction. |
| Richer Ambient Villagers | [`richer-ambient-villagers.md`](richer-ambient-villagers.md) | ✅ | Adds standing-idle pauses, Congregating (idling villagers face each other), Point-of-Interest Lingering, and Night population thinning on top of `villagers.md`'s base roaming. |
| Real-Time Day/Night | [`real-time-day-night.md`](real-time-day-night.md) | ✅ | Board lighting shifts through 4 phases (Dawn/Day/Dusk/Night) keyed to the device's real local hour, plus a loose seasonal palette tint and villager lamp-lighting at Night. Phase transitions crossfade smoothly. |
| Farmhouse Visual Tiers | [`farmhouse-visual-tiers.md`](farmhouse-visual-tiers.md) | ✅ | The Farmhouse's rendered model changes across 5 visual tiers as `farmhouse_level` increases, instead of one fixed model regardless of level. |

## Dependency Notes

Not every dependency edge is repeated here — each document's own
**Dependencies** section (§6, required by `design/CLAUDE.md`'s 8-section
template) is the authoritative source and is kept bidirectional per
`.claude/rules/design-docs.md`. The high-level shape:

- `crop-economy.md` is the hub: `land-and-structures.md`,
  `mandi-trading.md`, `liveops-events.md`, `worker-economy.md`, and
  `gems-second-sink.md` all read or modify plot/crop state it owns.
- `villagers.md` is `worker-economy.md`'s entire roster source (assigning
  a worker removes that villager from the ambient-roaming population) and
  `richer-ambient-villagers.md`'s base to extend.
- `festival-visiting-npcs.md`'s on-board visitor reuses `villagers.md`'s
  `Villager` rendering class and `board_interactor.gd`'s tap-dispatch
  pattern, without depending on the ambient roaming population itself.
- `real-time-day-night.md` and `farmhouse-visual-tiers.md` are both purely
  Presentation-layer — neither touches `game_economy.gd`/`GameState`.

## What's Deliberately Not Indexed Here

- `docs/architecture/adr-*.md` — architecture decisions, not game-design
  documents; see `docs/architecture/godot-migration-roadmap.md` for the
  engineering-side status these GDDs' implementations are tracked against.
- `design/balance/*.md` — point-in-time `/balance-check` reports, not
  living design specs.
- `production/qa/*` — verification evidence, referenced from the
  relevant GDD's own Acceptance Criteria rather than duplicated here.

---

*Authored 2026-08-22, closing a gap the migration roadmap's own "Kickoff
approach" flagged as a deliverable back on 2026-08-18 and every session
since kept deferring past — not a new requirement, a backfill of an
already-planned document.*
