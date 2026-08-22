# IFarming → Godot 4 Migration Roadmap

**Status**: M0–M5 complete, verified, and **cut over** — `godot/` is the
active codebase for all new work. M6–M8 not started (see Cutover Decision
below).
**Date**: 2026-08-18 (roadmap authored) / 2026-08-21 (M5 reached, cutover decided)
**Governing ADRs**: `adr-0001-godot-engine-migration.md` (Accepted), `adr-0002-godot-language-and-save-format.md` (Accepted — GDScript, clean save format)

> This is the working roadmap for the Godot migration. Update epic status as
> work progresses. See `production/session-state/active.md` for the current
> in-flight task.

## Cutover Decision (2026-08-21)

M0–M5 are complete: full UI parity with the shipped Kotlin/LibGDX app (every
management sheet, picker, and board interaction), full economy-layer parity
(every `GameViewModel` method has a matching `GameEconomy` method), 262
passing GUT tests, and every system verified live on-device. Per this
roadmap's own M5 stop-gate framing, "M0–M5 (parity + art fix reached) is a
complete, shippable product on its own" — that condition is now met.

**Decision**: `godot/` is the active codebase. All new feature work happens
in GDScript against the Godot project from this point forward — this
resolves CLAUDE.md's standing caveat ("do not start new LibGDX/Compose
feature work without checking the migration roadmap first"). `app/` and
`core/` (the Kotlin/Compose/LibGDX implementation) are **not deleted** —
they remain in the repository as the last-known-good fallback and are still
buildable — but are now frozen: no further feature development against
them is expected.

**What "cutover" does *not* cover, and why**: publishing the Godot build to
players (Play Console listing, signed release build, store metadata,
pricing/monetization decisions, privacy policy and other legal documents,
and real human playtesting beyond this project's own on-device verification)
requires the project owner's developer accounts, business identity, and
judgment — genuinely outside what this decision, or any engineering work,
can resolve. Those remain open, tracked under "Release Readiness" below,
not part of this engine-choice decision.

## Release Readiness (EPIC-M8, in progress)

Everything needed to take the now-cut-over Godot build from "verified
parity" to "a real player can download and play it," tracked here so it
isn't lost between sessions. EPIC-M8 ("Post-Migration Hardening") maps
directly to this checklist's engineering-side items — store readiness
stays the owner's regardless of how much of this list gets done.

- [x] Audio — `/team-audio` full pipeline run 2026-08-21, scoped to the
      core gameplay loop (village board + HUD): audio-director (ambient/
      nature-only soundscape, no melodic music track this pass — sidesteps
      the real licensing gap for authentic regional-instrument samples,
      fits a semi-idle loop better than a wearing-thin melody loop would),
      sound-designer (40-event catalogue: 26 SFX/UI + 14 ambience, the
      batch-resolve voice-flood hazard resolved via a 12-event threshold),
      accessibility-specialist (4-slider + mute-all `AccessibilitySheet`
      controls, confirmed no audio-only critical signal exists), technical-
      artist + godot-specialist (native `AudioStreamPlayer.max_polyphony`
      voice-limiting instead of a hand-rolled pool; `default_bus_layout.tres`
      not runtime `add_bus()`; verified against live Godot 4.7 docs since
      this project's own engine-reference has zero audio coverage — a real
      gap this pass surfaced), gameplay-programmer (full implementation).
      **Code complete and tested — 350/350 GUT passing** (independently
      re-verified, not just trusted). **Zero real audio asset files exist
      yet** — every catalogued path is a `ResourceLoader.exists()`-gated
      no-op until real `.ogg` files are dropped in; sourcing/composing them
      is a separate follow-up task. `agroforestry_tab.gd`/
      `niche_farming_tab.gd` wiring (mechanically identical to the done
      `polyhouse_tab.gd`) was deferred at the time this note was written,
      then closed the same way in a later session (commit `d268335`) --
      both tabs now call `_play_audio()` from every purchase handler,
      confirmed by inspection 2026-08-22. `ui_action_rejected` is also now
      closed (2026-08-22, same session as the localization pass) -- see
      `docs/architecture/localization-pipeline.md`'s Related section: it
      turned out to need a real GameEvent snackbar/toast drain, not just a
      wiring fix, since `pending_events` was never drained by any UI code
      at all before this. This EPIC-M8 audio bullet's own two originally-
      deferred items are both closed now.
      Design doc: `design/audio/audio-core-gameplay-loop.md`.
- [x] QA pass — done 2026-08-21: `/smoke-check` run against the Godot
      build (adapted for this project having no formal `production/
      sprints/`/story-file structure — scoped to "the whole godot/
      project post EPIC-M0-M7" instead). **328/328 GUT tests passing.**
      Found and closed a real coverage gap (`open_field_tab.gd` had no
      test file, unlike every sibling tab); found a second gap
      (`board_interactor.gd`'s gesture state machine had no dedicated
      test file), initially flagged for a future session and **closed
      later the same day** by extracting its 3 real decision points
      into pure functions and covering them with 12 new tests. All
      manual smoke-check batches confirmed clean. Report:
      `production/qa/smoke-2026-08-21.md`.
      `/qa-plan` itself wasn't run in its literal form — its Phase 1
      scope resolution assumes story files this project doesn't have;
      noted as a process gap in the smoke-check report rather than
      forced through.
- [x] Accessibility — audit done 2026-08-21: `accessibility-specialist`
      reviewed HUD/village board/management sheets against WCAG 2.1 AA,
      scoped to this project's real profile (touch-only mobile, no
      gamepad/keyboard, no dialogue/subtitles, zero audio exists yet).
      **4 BLOCKING findings (no accessibility settings screen at all;
      white text on the cream sheet background, ~1.06:1 contrast, 8
      sites; white text on active gold chips, ~1.63:1, 3 sites; harvest-
      ready plots signaled by tint hue alone), 5 HIGH, 1 MEDIUM, 1 LOW, 1
      ADVISORY, 1 DEFERRED (audio, until EPIC-M8's audio pass exists).**
      All 4 BLOCKING findings fixed and GUT-verified the same session
      (336/336 passing, up from 328 — 8 new tests for the new
      `AccessibilitySettings` resource): added a `BottomSheet`-based
      Accessibility settings screen (text-size cycling + a colorblind-
      safe blue/orange palette toggle that hot-reloads the board live),
      fixed all 11 contrast sites plus one more caught during remediation
      that the static read had missed (HUD's LiveOps banner), and added a
      checkmark badge decal so harvest-readiness isn't color-only anymore.
      HIGH/MEDIUM/LOW/ADVISORY findings remain open for a follow-up pass.
      **On-device visual verification not yet performed** (no emulator
      available this session) — recommended before considering this
      fully closed. Report: `production/qa/accessibility/
      village-board-and-management-sheets-audit-2026-08-21.md`.
- [x] Localization — Phase 1 done 2026-08-22: Godot's native CSV-translation
      pipeline (`godot/locales/ui_strings.csv`), English/Hindi locales,
      `AccessibilitySettings.locale` as the persisted player preference
      (new language-toggle row in the Accessibility sheet), applied live
      via `TranslationServer.set_locale()` from `village_board.gd`. Proven
      with a real migrated slice (`hud.gd`'s 3 buttons/labels, the full
      `accessibility_sheet.gd`) rather than left as untested scaffolding —
      558/558 GUT passing, up from 545/545. The rest of the UI's hardcoded
      strings (every remaining `*_tab.gd`/`*_card.gd`/`*_picker.gd`, plus
      `game_economy.gd`'s `_push_event()` message strings) remain
      unmigrated by design — see `docs/architecture/
      localization-pipeline.md`'s own Phase 2 plan, not silently assumed
      covered. Phase 2 itself is now in progress: all 7 management
      sheets done same day (`farmhouse_tab.gd`, `mandi_tab.gd`,
      `polyhouse_tab.gd`, `agroforestry_tab.gd`, `niche_farming_tab.gd`,
      `open_field_tab.gd`, `events_tab.gd`), 574/574 GUT passing. Only
      pickers/info cards/`_push_event()` remain.
- [x] Security/save-integrity audit — done 2026-08-21: `/security-audit
      full` run against the Godot save format and economy logic. **1 HIGH
      finding (SEC-001: save-loaded crop/host/decoration enum ordinals
      weren't bounds-checked before catalogue lookup — a hand-edited or
      corrupted save could crash repeatedly on the board's own 3s growth
      timer), 2 LOW findings (SEC-002: test tooling shipping in the
      release APK; SEC-003: a theoretical, currently-inapplicable Godot
      Resource-loading note). Zero CRITICAL/MEDIUM.** SEC-001 and SEC-002
      both fixed and verified live the same session (fresh export,
      install, launch, screenshot — zero regression). Local save-editing
      was explicitly assessed and **not** flagged as a vulnerability —
      correct for a single-player, no-leaderboard, no-IAP game, matching
      this genre's norm (Stardew Valley and similar all ship
      plaintext-editable saves). Report: `production/security/
      security-audit-2026-08-21.md`.
- [ ] Store readiness: `/release-checklist` + `/launch-checklist` never
      run. Needs a real Play Console developer account (owner-only step),
      signed release keystore (separate from the debug key used
      throughout this migration), store listing copy/screenshots, and a
      privacy policy.
- [x] EPIC-M6/M7 (villagers, worker assignment): complete — see their own
      sections above.

---

## Honest sizing (source: Kotlin codebase, 2026-08-18)

| Tier | Files | Lines | Port difficulty |
|---|---|---|---|
| Pure logic (`game/`) | GameData.kt, GameModels.kt, GameViewModel.kt, GameRepository.kt | 1,487 | Low, high volume — formulas transfer 1:1, `PlotState` needs a GDScript variant-pattern (no sealed classes) |
| Engine-neutral mapping | VillageSnapshotMapper.kt, TileSnapshot.kt, GroundKind.kt | 299 | Trivial |
| Engine-coupled | `village3d/*` (815 lines) + `ui/gdx/*` (958 lines) + Compose UI (1,880 lines, 48 composables) | 3,653 | Rewrite, not port |

Assets: 627 `.obj`/`.mtl` across 4 Kenney kits (13 MB), 31 bundled. **No rigged/animated humanoid character assets exist anywhere in the project** — only 5 static, unrigged, undead graveyard-kit models. This blocked EPIC-M6 until a new CC0/OFL character pipeline was sourced — **resolved 2026-08-21**, see EPIC-M6 section below.

## Key findings not in ADR-0001

- Villager epic needs a wholly new rigged-character asset pipeline (glTF/GLB + Skeleton3D + AnimationPlayer) — not covered by "obj imports natively." **Sourced and import-verified 2026-08-21** — see EPIC-M6 below.
- Two real bugs to fix during the port, not carry over: unconditional 1Hz persist-to-disk regardless of dirty state; three simultaneous event messages (weather/theft/flood) silently clobber down to one.
- The "compact the board" fix needs a save-migration step — player-dragged zone positions persist, so new default constants alone won't shrink an existing save. (Partially moot per ADR-0002's clean-save-format decision — no old saves carry forward at all.)
- Godot has no `ModalBottomSheet` equivalent — used on all 9 management screens; must be hand-built as a reusable component.
- Emoji is the entire visual language (crops, decorations, HUD, badges) — needs an explicit bundled-font decision (Noto Color Emoji, OFL), not an assumption.
- Root causes of the original "too big / too naturalistic" complaint are confirmed as data/material choices (18×25-tile content vs. 7.5-tile viewport; 87-tile unbounded terrain; zero model scaling; blurred-noise terrain + smooth Lambert shading) — they reproduce identically in Godot if ported 1:1. Nothing about switching engines fixes them for free.

## Decisions locked in (this session)

- **Language**: GDScript (ADR-0002)
- **Save format**: Clean Godot `Resource`-based, not JSON-schema-compatible with the old Kotlin format (ADR-0002) — no differential parity harness, no old-save carryover; EPIC-M2's test suite is the primary regression safety net as a result
- **Epic order**: Village-board art/scale fix moved to position 2 (fixture-driven, doesn't need the economy port, and directly answers the original complaint early rather than ~7 weeks in)
- **M5 stop-gate**: Hard gate — M0-M5 (parity + art fix reached) is a complete, shippable product on its own; villagers/workers (M6-M8) are explicitly re-evaluated at that point, not committed to blindly upfront
- **Kickoff approach**: Begin M0 now; backfill `design/gdd/` docs (systems-index, land-and-structures, farmhouse-progression, mandi-trading, liveops-events) and other `/create-epics` prerequisites only when each later epic actually needs them, not all upfront

## Epics

| Epic | Layer | Size | Depends on | Status |
|---|---|---|---|---|
| M0 — Godot Foundation & Migration Preflight | Foundation | 1–1.5 wk | — | **Complete** |
| M1 — Village Board: Layout, Scale & Art Direction | Presentation | 2–3 wk | M0 | **Complete** |
| M2 — Economy & State Core Port | Foundation | 2–2.5 wk | M0 | **Complete** |
| M3 — Village Board Interaction | Core | 2 wk | M1, M2 | **Complete** |
| M4 — UI Port: HUD, Sheets & Screens | Presentation | 2.5–3 wk | M2, M3 | **Complete** |
| M5 — Migration Parity Verification & Cutover | QA/Release | 1.5 wk | M1-M4 | **Complete — cutover decided 2026-08-21, see above** |
| M6 — Villager Asset Pipeline & Ambient Roaming | Feature | 2–2.5 wk | M1, M2 (gated: villager GDD, CC0 rigged characters) | **Complete** — all 6 characters live in-game with visual variety, measured with no detectable perf cost at the population cap (emulator; real-hardware/formal-budget work stays open project-wide, see below) |
| M7 — Worker Assignment & Wage Economy | Feature | 1.5–2 wk | M6, M2, M4 (gated: balance pass) | **Complete** — design, economy backend, visual stationing, and assignment UI all built, tested (327/327), and verified live via real touch input — see below |
| M8 — Post-Migration Hardening | Polish | 1 wk | M5 (+M6/M7 if taken) | **All 4 selected items done** — security audit, QA/smoke pass, accessibility (4 BLOCKING findings fixed), and audio (`/team-audio` core-gameplay-loop pass, code complete, real asset sourcing still open) — see "Release Readiness" above. Localization was not selected. Store readiness remains the owner's own step. |

**Re-baselined estimate**: 10–13 weeks to parity (M0–M5), +3.5–4.5 weeks for villagers/workers (M6–M7), +1 week hardening (M8). Total 14.5–18.5 weeks — higher than ADR-0001's original 8–14 week estimate, mainly due to the character-asset gap and the test-suite work the ADR's own risk analysis requires but didn't budget. Re-baseline again after M0 and after M2.

### Dependency graph

```
M0 Foundation & Preflight
 ├─────────────────┬──────────────────────────┐
 ▼                 ▼                          │
M1 Board Art    M2 Economy Port  ◄── (4 economy GDDs + TR registry, gated when needed)
 │  (fixture)      │  (+ test suite is now primary regression safety net)
 └────────┬────────┘
          ▼
    M3 Board Interaction
          ▼
    M4 UI Port
          ▼
    M5 Parity & Cutover  ◄══ HARD STOP-GATE / re-evaluate before continuing
          ▼
    M6 Villager Assets & Roaming  ◄── (villager GDD, CC0 rigged characters — blocking gap)
          ▼
    M7 Worker Assignment  ◄── (balance pass first)
          ▼
    M8 Hardening
```

## EPIC-M0 — Godot Foundation & Migration Preflight

**Scope**:
- Run `/setup-engine`; pin a specific Godot 4.x point release; populate `docs/engine-reference/godot/`
- Godot project skeleton + folder convention + Android export template (gradle build, minSdk 24 / target 37)
- Batch-import all 627 `.obj`/`.mtl` and produce a contact sheet: which import clean, which lose materials, which reproduce LibGDX's "black silhouette" class (`hedge-large`, `watermill`, `stall`, `lantern` were the known offenders there — re-verify, don't assume immunity)
- Spike: visual glyph strategy (Noto Color Emoji bundled font vs. icon atlas vs. models) — blocks M3 and M5
- Establish first formal performance budgets: frame time on the Medium_Phone AVD, memory ceiling, APK size delta vs. current LibGDX APK, cold-load time
- `CLAUDE.md`/`technical-preferences.md` already updated this session

**Demonstrable milestone**: A debug APK on the Medium_Phone AVD rendering ~30 Kenney models at a measured frame time, with a written baseline table, plus the 627-asset import report.

**Kill-switch**: If Godot's Android export can't hit budget with this asset load, ADR-0001's rollback (in-place LibGDX fix) is still fully available, costing ~1 week sunk instead of ~4 months.

---

## EPIC-M6 — Villager Asset Pipeline & Ambient Roaming

**Status**: In progress. Asset sourcing (the epic's named blocking gap since
M0) is done and import-verified. Scene/behavior work has not started.

**Asset decision (2026-08-21)**: `KayKit — Character Pack: Adventurers`
(Free tier) by Kay Lousberg, CC0 1.0, glTF/GLB — see
`assets_3d/README.md`'s "Rigged characters" section for full sourcing
detail, license text, and the trimmed file layout. Curated subset lives at
`godot/assets_3d/kaykit-adventurers/glTF/`. Verified clean import into the
project's pinned Godot 4.7.1 (zero errors, 6 character `.glb` + 2
animation-library `.glb`, confirmed real `Skeleton3D`/`AnimationPlayer`
nodes via a one-shot headless inspection script, since deleted).

**Why this pack**: CC0 (matches the project's existing free/open-source-only
constraint and its all-CC0 Kenney sourcing so far), explicitly Godot-4-
compatible per the publisher, and — critically — ships a shared 23-bone
rig (`Rig_Medium`) reused identically across every character *and* the
separate animation-library files, so animations can be retargeted onto any
character without per-character rework. The alternative candidates
considered (Kenney's own "Animated Characters 3": 4 skins/3 clips, no
dedicated Walk clip; the standalone legacy KayKit Animations pack: the
publisher's own page flags it as intended for an older no-legs rig) were
both thinner fits — Adventurers' `Rig_Medium_MovementBasic.glb` alone
supplies `Walking_A/B/C`, `Running_A/B`, `Jump_*`.

**Retargeting — done (2026-08-21)**: `godot/scripts/village_board/villager.gd`
(`Villager` class) + `godot/scenes/village_board/villager.tscn`. Instances
any of the 6 curated characters, builds a fresh `AnimationPlayer` as a
sibling of the character's own `Rig_Medium` node (matching the shared
library's relative track paths exactly — verified by inspecting bone names
and track paths directly, not assumed), loads
`Rig_Medium_MovementBasic.glb`'s default `AnimationLibrary` onto it, and
exposes `play_animation(clip_name)`. Applies the same toon-shading patch
used on every other board model. 4 new GUT tests (all 6 character keys
covered), 266/266 suite passing. **Also confirmed visually**, not just
structurally: ran the scene in a real (non-headless) windowed Godot
instance on this machine's actual GPU and screenshotted it — the Ranger
character renders in a natural mid-stride walking pose (not the frozen
T-pose a broken retarget would show), proving the shared animation data is
genuinely driving the character's bones. Not yet wired into the live
village board (`village_board.gd`'s `rebuild()`) — deliberately, since the
visual pass below hasn't happened and these still read as fantasy
adventurers, not farmers.

**Visual pass — first slice done (2026-08-21)**: `Villager._recolor_material_accent()`
re-hues each character's saturated blue accent (neckerchief/trim) toward
the warm saffron/maroon hue family already used for structure zones,
leaving skin/hair/leather/cream-cloth tones untouched. Implemented as a
per-pixel HSV scan over the character's albedo texture (cached per
character key — computed once, reused by every `Villager` instance),
applied alongside the existing toon-shading patch in one combined pass.
**Confirmed both ways**: a headless GUT test
(`test_setup_recolors_the_blue_accent_out_of_the_ranger_texture`) scans the
resulting texture and asserts no saturated blue pixel survives; a windowed
(non-headless) render on this machine's real GPU visually confirmed the
Ranger's neckerchief changed from bright blue to warm terracotta/saffron
with skin and hair unaffected. 267/267 suite passing.

This is deliberately a narrow slice, not a full costume redesign — no 3D
modeling or hand-painted texture work happened, only an algorithmic hue
shift of one accent color. **Only "ranger" has been visually checked.**
The other 5 characters (Barbarian/Knight/Mage/Rogue/Rogue_Hooded) carry
baked-in fantasy props (helmet, hood, weapon-ready stance) that a color
shift alone can't fix — those need either prop removal/hiding (a mesh-part
visibility toggle is plausible future work) or should simply be dropped
from the villager roster in favor of sourcing more plain-clothes
characters later. Do not spawn them into the live board on the assumption
this pass covers them too.

**Still not wired into the live board** — same reasoning as before: no
GDD yet, no roaming behavior yet, and 5 of 6 characters are unverified.

**Villager GDD — written (2026-08-21)**: `design/gdd/villagers.md`. Scopes
this epic explicitly to *ambient, non-interactive* roaming (no economy
function, no save-data footprint) and defers any worker-mechanical layer
to a separate future EPIC-M7 GDD. Defines the count/speed/exclusion-margin
formulas, the walkable-area rule (reuse `VillageSnapshotMapper.max_reserved_tiles()`,
don't invent a second occupancy system), and the no-idle-clip constraint
(the sourced animation library has no standing-idle loop — only `T-Pose`
and `Jump_Idle`; `Rig_Medium_General.glb` is unsourced-for-idle and still
unopened). Flags two decisions as genuinely the user's, not assumed:
whether villager count should ever be 0 early-game, and whether to spend
more visual-fix work on the other 5 characters or source more plain-clothes
characters instead.

**Roaming controller — done (2026-08-21)**: `WalkableGrid`
(`godot/scripts/village_board/walkable_grid.gd`, pure `RefCounted` logic —
grid occupancy + BFS pathfinding, no scene dependency) and `VillagerRoamer`
(`godot/scripts/village_board/villager_roamer.gd`, drives a `Villager`
continuously between random walkable tiles per the GDD's no-idle-pause
rule). **Deliberate deviation from this doc's earlier phrasing**
("`NavigationRegion3D`/`NavigationAgent3D` roaming behavior"): the board
is a small fixed 10×12 grid, so a hand-rolled BFS pathfinder is simpler,
fully headless-testable, and avoids a HIGH-knowledge-risk Godot 4.7
subsystem this project has never touched — consistent with
technical-preferences.md's existing manual-ray-picking-over-physics-engine
precedent. 18 new GUT tests (12 for `WalkableGrid`'s occupancy/pathfinding
— including routing around an obstacle and detecting an unreachable goal
— and 6 for `VillagerRoamer`'s movement/retargeting), 284/284 suite
passing. **Confirmed visually again**: windowed real-GPU render, two
screenshots ~3s apart showing the villager having visibly walked across
the ground plane and turned to face its new direction.

Still not wired into `village_board.gd` — same reasons as before (roster
still mostly unverified, no population-spawning integration written yet,
no on-device performance measurement to justify the population cap).

**GameState integration — done (2026-08-21)**:
`VillageSnapshotMapper.build_walkable_grid(state, cols, rows)` builds a
real `WalkableGrid` from live `GameState` — every zone's maximum footprint
(same deliberately-conservative "reserve regardless of unlock state"
policy the layout-overlap fix already established) plus every placed
decoration's tile. `VillageSnapshotMapper.unlocked_zone_count(state)` /
`villager_count(state)` implement the GDD's §4 population formula for
real. 9 new tests (custom zone-anchor tracking, decoration reservation,
not-yet-unlocked zones still blocking their future footprint, the
population formula's floor/ceiling), 293/293 suite passing.

**A real design question this answered, not just assumed**: the GDD
flagged "does the early-game open area stay usable given how conservative
this reservation policy is?" as needing confirmation. Checked directly —
a fresh game (only Farmhouse + Mandi unlocked) still has **63 of 120
tiles (52%) walkable**, even with every other zone's maximum future
footprint pre-reserved. Comfortably enough room for 2–6 villagers.

**Spawner — done (2026-08-21)**: `VillagerSpawner`
(`godot/scripts/village_board/villager_spawner.gd`, `RefCounted`) ties
`VillageSnapshotMapper.villager_count()`/`build_walkable_grid()` to actual
`VillagerRoamer` instances. `sync(state)` tears down and respawns the
whole population against a fresh grid — simplest correct behavior given
the GDD's "no persistence, re-randomize each load" rule — at distinct
random walkable tiles (a small seedable Fisher-Yates shuffle, not
`Array.shuffle()`, so tests stay deterministic). Explicitly decoupled from
`rebuild()`: callers decide when to call `sync()` (e.g. board load, or
after a `buy_*()` that might change `villager_count()`), not this class.
5 new tests (population size, distinct start tiles, resync replaces the
old population with fresh instances, a real zero-walkable-tiles
degenerate case, `clear()`), 298/298 suite passing. **Found a real parse
bug via `--check-only`** before it reached tests: GDScript couldn't infer
a swap variable's type through a typed-array index in the Fisher-Yates
loop — fixed with an explicit type annotation, documented as a reminder
that Godot 4.7's type inference has real gaps worth checking for, not a
one-off. **Verified visually a third time**: windowed real-GPU render, a
plain preview scene calling `VillagerSpawner.sync()` on a fresh
`GameEconomy` state spawned exactly 3 villagers (matching the formula);
two screenshots ~3s apart show all three having moved to entirely
different positions independently — proof the spawner and roaming
controller compose correctly for multiple simultaneous villagers, not
just one in isolation.

This closes out the entire roaming *pipeline* — assets, animation,
visuals, design, pathfinding, GameState integration, and population
spawning are all built and tested.

**Live in the game — done (2026-08-21)**: user decided "ranger only for
now" on the roster question (the other 5 characters remain unfixed/
unverified, not spawned). Wired `VillagerSpawner` into
`village_board.gd`: `_villager_spawner` created once in `_ready()`
(targeting `ActorLayer`, same `GRID_COLS`/`GRID_ROWS`/`TILE_SIZE` as the
rest of the board), synced via a new `_sync_villagers_if_needed()` called
from both `_ready()` and `persist_and_rebuild_if_dirty()` — but only
actually re-syncs the population when `villager_count()` changed since
the last sync, so it doesn't churn on every routine 3s growth tick or
plot edit, per the GDD's own decoupling requirement. 298/298 suite still
passing (no regressions from the wiring itself).

**Verified on the real shipped game, not a preview scene**: exported a
fresh debug APK, installed and launched on the emulator. Two screenshots
~4s apart of the actual production village board (Farmhouse, Mandi,
Polyhouse, Vertical Farm, Agroforestry, real decorations, all present)
show 3 villagers correctly rendered with the saffron-recolored accent,
standing on genuinely open ground (never inside a building/plot/
decoration footprint), having visibly moved and changed pose between the
two screenshots. No crash, no fatal errors in logcat, process stayed
alive throughout. This is the strongest verification available short of
human playtesting.

**Known, deliberately-not-solved gap**: a zone drag or a newly-unlocked
zone can change *where* reserved tiles are without changing
`villager_count()`, so an already-spawned villager's in-flight walk
target could in theory go stale mid-walk. Flagged in both the GDD's Edge
Cases and this file's own `_sync_villagers_if_needed()` doc comment as
unimplemented, not silently assumed to be covered.

**Performance measurement — first data point recorded (2026-08-21)**:
temporarily instrumented `village_board.gd` with a `Performance.get_monitor()`
sampler logging FPS/frame-time to logcat every 2s, then measured two
configurations on the Medium_Phone AVD emulator (~20s each, ~7-10
samples):

| Configuration | FPS (range) | Frame time ms (range) |
|---|---|---|
| 0 villagers (baseline) | 55–57 | 25–44 |
| 6 villagers (the formula's ceiling — this save has every zone unlocked) | 54–57 | 26–45 |

**Finding: villagers add no measurable cost.** The two configurations are
statistically indistinguishable — full population (6 low-poly toon-shaded
characters, each independently animated and pathfinding) costs the same
as an empty board within measurement noise. The board's own baseline
(~55-57 FPS, not a full 60) is a pre-existing cost unrelated to
villagers — worth its own look eventually, but out of scope for this
question.

**What this does and doesn't establish**: this is the project's
first-ever recorded performance number, anywhere — genuinely new
information, not a formality. But it does not fully close EPIC-M0's
still-pending performance-budget item: (1) it's the Android *emulator*
(AVD), not physical hardware — this project has never been tested on a
real device, a standing limitation `technical-preferences.md` already
notes, not something this measurement resolves; (2) no formal target
FPS/frame-time budget has ever been adopted for this project to grade
these numbers against — they are reported as raw data, not a pass/fail
verdict. Given that caveat, the practical conclusion for the specific
question this was asked to answer — "does raising the villager population
to its cap risk hurting performance" — is a real, evidence-based **no**.
The broader EPIC-M0 budget-setting work remains open.

Diagnostic instrumentation (the `_process()` sampler and a temporary
zero-villager early-return) was removed after collecting these numbers,
and the production APK was rebuilt/reinstalled/reverified clean (298/298
GUT, a real device screenshot showing all 6 villagers again, zero
crashes) — same instrument-then-delete precedent as every other
diagnostic this session.

**Roster expanded to all 6 characters + stale-walk-target fixed —
done (2026-08-21)**: `villager.gd` gained a mesh-name keep-list
(`_KEEP_MESH_SUFFIXES`) hiding every non-body-part mesh — verified by
directly inspecting each character's actual node names first, not
assumed: every character shares identical `_ArmLeft/_ArmRight/_Body/
_Head/_LegLeft/_LegRight` core parts, so this one filter removes Knight's
helmet/visor/cape, Mage's hat/cape, Barbarian's bear-hat, Rogue/
Rogue_Hooded's cape/mask, and Ranger's cape/quiver in one pass. All 6
visually confirmed with both passes (recolor + prop-hiding) via a
side-by-side render, then live on the real production board.
`VillagerSpawner.CHARACTER_KEYS` now lists all 6, randomly assigned per
villager. Separately, `_sync_villagers_if_needed()` was rewritten to
compare the board's full walkable-tile signature (not just
`villager_count()`), and `try_commit_zone_move()` now calls it directly
on a successful drag — closing the previously-flagged gap where a zone
move could leave an already-spawned villager's walk target stale, since
that path never went through `persist_and_rebuild_if_dirty()` at all.
Regression test: `test_try_commit_zone_move_resyncs_villagers_on_a_successful_move`.
299/299 suite passing. Verified live on-device again: visibly distinct
villagers (a hooded figure, a saffron-neckerchief character, two
bald/light-haired variants) all rendering correctly on the real
production board simultaneously, zero crashes.

**EPIC-M6 is now complete** — every item on its own original scope
(asset pipeline, animation, visual pass across the full roster,
GameState integration, roaming controller, population spawner, live
board wiring, a real performance measurement) is built, tested, and
verified on-device. What remains open is explicitly **not** M6-specific:
real-hardware testing and a formally adopted performance budget are
EPIC-M0's long-standing project-wide gap, and the villager GDD's one
still-open design question (`should count ever reach 0 early-game`) is a
genuine product decision, not an engineering task.

**Real-hardware performance pass — done (2026-08-22)**: the emulator-only
caveat above is now closed. Same instrument-then-delete method (a
temporary `Performance.get_monitor()` sampler in `village_board.gd`,
logged to logcat every 2s, reverted before committing — 379/379 GUT
confirmed clean after revert), this time run on a real physical device
connected via `adb`, not the AVD:

| Field | Value |
|---|---|
| Device | OnePlus OPD2403 ("5bc7f547"), Android 16 (SDK 36), Snapdragon (qcom), 2120×3000 @420dpi, ~12GB RAM |
| Config A — fresh save (3 ambient villagers, default zones) | 49–51 FPS steady, one 58–60 FPS blip; frame_ms (script/process time only) 33–49ms; static memory ~59.0MB |
| Config B — emulator's max-population save transplanted onto the device (2 assigned workers + ambient villagers, ₹2.69M, every zone unlocked) | 49–51 FPS steady, one 58–60 FPS blip; frame_ms 33–49ms; static memory ~59.0–59.3MB |
| Cold-start (Activity first-frame, `adb shell am start -W`) | `TotalTime=468ms` (fresh install, `LaunchState: COLD`) |
| APK size | ~31.0 MB (debug-signed, current build) |

**Finding: population is not the FPS ceiling on real hardware either** —
fresh-save and max-population-save numbers are statistically
indistinguishable, consistent with the emulator's own villager-cost
finding above. **The real ceiling is a fixed ~50Hz display-refresh lock**:
`dumpsys display` confirms this device natively supports up to 144Hz
(`supportedRefreshRates` includes 90/120/144) but negotiated down to
exactly `renderFrameRate 50.0` for this app specifically — with no
`max_fps`/`vsync` override anywhere in `project.godot`, this is the
device's own adaptive-refresh-rate policy choosing a conservative fixed
mode, not something this project's code is requesting. Not chased further
this pass — flagged as a real open question (below), not silently
attributed to either side.

**Caveats, stated honestly, not glossed over**:
- Single device, single session — this establishes "works acceptably on
  one real Android 16 phone," not a device-spread baseline. No formal
  frame-time/memory *budget* has still ever been adopted for this project
  to grade these numbers against (same caveat as the emulator pass) —
  these remain raw data with a direct answer to the specific questions
  asked (does population cost FPS on real hardware; does the game even
  run acceptably off the emulator), not a pass/fail verdict.
  Battery at 50%, USB-charging, screen on throughout — a cold/unplugged/
  adaptive-brightness real play session could measure differently.
- The ~50Hz refresh lock's root cause is unconfirmed (device power policy
  vs. something reachable from our end) — worth a closer look if this
  project ever cares about matching this device's full 144Hz ceiling, but
  50 FPS steady is well above any frame-time budget concern for a farming
  sim, so not treated as a blocker.
- APK size has no prior LibGDX baseline on record to diff against (ADR-0001's
  own Performance Implications table already noted this gap at migration
  time) — reported standalone, not as a delta.

**EPIC-M0's performance-budget item is now substantively closed**: both
the emulator and real-hardware questions this item existed to answer
("does this run acceptably, does population scale cost anything") have
real evidence-based answers. What's still open is only the *formal
numeric budget adoption* itself (an explicit target like "≥30 FPS, ≤X MB"
signed off as a gate) — a product decision about what threshold to hold
the game to, not a measurement gap.

---

## EPIC-M7 — Worker Assignment & Wage Economy

**Status**: Design drafted (`design/gdd/worker-economy.md`), awaiting
user review. No code written — the user explicitly chose "design doc
first, build after review" when this epic kicked off.

**Why this needed a real conversation first, unlike M6**: M6 had a real
source-material anchor (`v2.md`'s "living world" pillar) to design
against. M7 had none — it was purely a name and a size estimate in this
roadmap, invented during the original migration-planning session with no
grounding in what workers should actually do. Rather than invent a full
worker/wage system unilaterally, three clarifying questions were asked
before drafting anything:
1. What workers primarily do → **both automation and a wage sink**
2. Whether workers are the same characters as EPIC-M6's ambient
   villagers → **yes, assigned from that same roster**
3. Design-doc-first or design-and-build → **design doc first**

**Core mechanic, grounded in existing code rather than invented from
scratch**: a worker automates a zone's harvest-and-replant cycle, reusing
`crop-economy.md`'s existing `resolveGrowthCompletions()`-style lazy
offline-resolution pattern (the same mechanism that already makes
ordinary crop growth "just work" across an offline gap) rather than
inventing a second background-processing mechanism. A wage is deducted
per completed cycle, proposed at 15% of that crop's base sell value — a
first proposal only, explicitly flagged as needing a `/balance-check`
pass, not a researched number.

**Both open questions resolved (2026-08-21)**:
- §3.6 visibility: unassigned villagers stay in EPIC-M6's ambient
  roaming ("idle"); assigning a worker pulls it out of that population
  and stations it visibly at its assigned zone ("called"), using the
  same `Villager` rendering component but different placement/movement
  logic than `VillagerRoamer`.
- §5's four edge cases: all resolved around one consistent principle — a
  worker only ever charges a wage for value it actually delivered, and
  never takes an action the player didn't implicitly authorize (no
  forced sales, no crop substitution, no auto-spending beyond the wage).
  Inventory-full and Electricity-lapsed both skip/pause with no wage
  charged; can't-afford-replant still harvests (wage charged) but leaves
  the plot empty; zone-unavailable is confirmed moot (no structure in
  this game has a sell-back path).

Design is fully confirmed. See `design/gdd/worker-economy.md` for the
full document.

**Economy backend — done (2026-08-21)**: `WorkerAssignment`
(`godot/scripts/economy/worker_assignment.gd`) + `GameState.worker_assignments`
(keyed by `PlotKind.Kind`, not the village-board layer's zone-id strings
— keeps Foundation from depending on Presentation) +
`GameEconomy.assign_worker()`/`unassign_worker()`/`resolve_worker_actions()`.
The automation cycle reuses `resolve_growth_completions()`'s exact lazy,
offline-safe pattern rather than inventing a second one, and is wired
into the same growth-tick call site (`village_board.gd`'s
`_on_growth_tick_timeout()`), running right after growth resolution so a
plot that just finished growing is already eligible the same tick.
AGROFORESTRY is deliberately excluded from worker eligibility — Sandalwood
planting goes through a different entry point (`plant_host()`/
`plant_sandalwood()`'s adjacency puzzle) with no "replant the same crop"
concept to automate. 14 new tests (`test_worker_economy.gd`) cover
assignment, eligibility, the happy-path cycle, the wage charge, and all 3
economically-relevant edge cases (inventory-full, can't-afford-replant,
Electricity-lapsed) — 313/313 full suite passing, confirmed stable across
5 consecutive runs. Verified live: exported and launched on the emulator
with this code wired into the real tick loop — zero crashes, board
renders normally (correctly dormant, since no assignment exists in the
current save).

**Visual stationing — done (2026-08-21)**: `WorkerStation`
(`godot/scripts/village_board/worker_station.gd`) renders one assigned
worker at its zone's world position, held on a paused `Walking_A` frame
rather than a T-pose or a visibly-looping walk cycle while stationary
(known minor polish item, not a dedicated "working" animation — this
asset's library has none). `VillagerSpawner`'s ambient-roaming population
now shrinks by however many villagers are currently assigned as workers
(`state.worker_assignments.size()`) — "assigned FROM the roster," not
additional to it, per the confirmed design. `village_board.gd`'s resync
trigger was widened from just a walkable-tile-signature check to also
include the worker-assignment set, so an assignment change resyncs both
the roaming population and the stationed workers together. A real gap was
found and fixed while writing this slice's own tests, not a hypothetical
one: `assign_worker()` had no check that the target zone was actually
unlocked — fixed with `_is_plot_kind_unlocked()`. 9 new tests, 322/322
full suite passing. Verified live twice: a real-GPU windowed preview
confirmed the station renders correctly in isolation; then, since no UI
existed yet to trigger an assignment in the shipped game, the real
on-device save file was backed up, mutated via a one-shot script to add
an assignment, pushed back, and the app relaunched — the roaming
population visibly dropped from 6 to 5, two distinct stationary figures
appeared at the Open Field zone, and the coin balance changed
autonomously between screenshots (proof `resolve_worker_actions()` fired
live, not just in tests). The original save was restored afterward.

**Assignment UI — done (2026-08-21)**: `WorkerAssignmentRow`
(`godot/scripts/ui/worker_assignment_row.gd`) is a reusable
assign/unassign section (an `OptionButton` of the 6 characters + an
Assign/Unassign button) embedded in every worker-eligible zone's own
management sheet — `polyhouse_tab.gd`, `niche_farming_tab.gd` (both
Aquaculture and Vertical Farm), and a brand-new `open_field_tab.gd` (Open
Field never had a zone-level sheet before, since plot taps already
handled its planting/harvesting directly). A real architectural gap
surfaced while wiring this in: Open Field has no zone-level `PickArea` at
all (`village_board.gd`'s `_build_zone()` only builds one when
`has_building` is true, and Open Field is the one zone with none), so its
new sheet is unreachable through the normal tap system —
`_maybe_open_zone_sheet()` alone could never open it. Fixed with a small,
low-risk addition instead of touching the tap/PickArea system: a new "🌾
Field Worker" button in the HUD's existing bottom-left panel
(`hud.gd`), the one deliberately narrow entry point needed to reach the
one zone the existing zone-tap system can't. Uses plain default-styled
Godot controls, not this project's ChunkyButton/StyleBoxFlat look —
explicitly flagged as a follow-up visual-polish item, not done now,
matching this session's own "complete it, then polish it" precedent. 5
new tests, 327/327 full suite passing, confirmed stable across 4
consecutive runs.

**This completes the visual stationing + assignment UI slice the user
asked for.** EPIC-M7 now has a fully playable path: tap a worker-eligible
zone (or the new Field Worker button for Open Field), assign a character,
watch it station at the zone, and its automated harvest-and-wage cycle
runs for real — the entire chain from asset to UI to economy to
persistence is built and tested.

**Live tap-through verified (2026-08-21)**: the emulator went
unresponsive partway through this slice (PackageManagerService deadlock,
diagnosed precisely — see session state) and had to be relaunched fresh.
Once healthy, the full assign/unassign cycle was confirmed through real
touch input, not just automated tests: tapped the Field Worker button,
opened the sheet, tapped Assign, confirmed the change via a ground-truth
save-file read (a screenshot taken immediately after showed a stale
render mid-rebuild — verified via data instead of trusting a
possibly-stale frame), then confirmed the UI visually caught up once the
rebuild settled. Repeated for Unassign with the same result. **EPIC-M7 is
now complete** — every layer, from the confirmed design through the
economy backend, visual stationing, and this UI, is built, tested
(327/327), and proven working in the actual running game.

---

*Full epic-by-epic detail (M1–M8) including named risks, Godot API mappings for each of the 8 documented on-device bug classes, and the villager/worker-specific constraints is preserved in this session's transcript. Expand into `/create-epics`-formatted epic files as each epic starts, per the "begin M0 now, backfill docs when needed" kickoff decision.*
