# Security Audit Report — Kisan Khet (IFarming)

**Date**: 2026-08-21
**Scope**: full (Category 2 Network/Multiplayer explicitly skipped — confirmed not applicable, single-player offline game, no `HTTPRequest`/`WebSocket`/`OS.execute`/network permissions found)
**Engine**: Godot 4.7.1 (GDScript) — active codebase is `godot/`; pre-migration Kotlin/LibGDX `app/`/`core/` stack is frozen and was **not** audited per scope instructions
**Audited by**: security-engineer via `/security-audit full`
**Files scanned**: 20 economy scripts (`godot/scripts/economy/*.gd`, full read), `board_interactor.gd` (full read, 786 lines), `game_economy.gd` (full read, 1001 lines), `save_system.gd` + `test_save_system.gd` (full read), ~10 UI scripts (`godot/scripts/ui/*.gd`, targeted read/grep), 4 village-board scripts (`village_board.gd`, `village_snapshot_mapper.gd`, `villager.gd`, `board_interactor.gd`), `export_presets.cfg`, `project.godot`, and `godot/addons/` (inventory glob, 257 files, all GUT)

---

## Executive Summary

| Severity | Count | Must Fix Before Release |
|----------|-------|--------------------------|
| CRITICAL | 0 | Yes — all |
| HIGH | 1 | Yes — all |
| MEDIUM | 0 | Recommended |
| LOW | 2 | Optional |

**Release recommendation**: FIX HIGH FINDING FIRST. SEC-001 is a small, well-contained fix (estimated Low–Medium effort) with a concrete reproducible crash path; it directly contradicts a graceful-degradation contract the codebase already documents and tests for a *different* corruption class. Recommend fixing rather than accepting it — both LOW findings are optional/defense-in-depth.

**Context worth stating up front**: this is a single-player, offline, no-leaderboard, no-IAP farming game. That materially changes what counts as a "finding" here versus a multiplayer/competitive game — see the Accepted Risk section. Findings below deliberately do not manufacture severity for things that don't threaten this game's actual threat model (e.g., local save-editing).

**Status as of this report**: SEC-001 and SEC-002 were fixed in the same session this audit was produced — see the note at the end of this document.

---

## CRITICAL Findings

None.

---

## HIGH Findings

### SEC-001: Save-loaded enum ordinals are not bounds-checked before catalogue lookup — crash/DoS on a structurally-valid-but-tampered save
**Category**: Save / Serialization
**Files**:
- `godot/scripts/economy/game_data.gd:167` (`crop_def`), `:236` (`host_type_def`), `:253` (`decoration_type_def`)
- Call sites that run automatically post-load: `godot/scripts/economy/game_economy.gd:102,282,341,352,373,425,438,575,791,865,913` (`resolve_growth_completions`, `harvest_plot`, `sell_crop`, `sell_all`, `_resolve_worker_cycle`, `mandi_price_multiplier`, `sell_to_mandi`) and `godot/scripts/village_board/village_snapshot_mapper.gd:250` (`_plot_label`)
- Tap-triggered: `godot/scripts/ui/decoration_info_card.gd:54`

**Description**: `GameState`'s save format (`.tres`, per ADR-0002) stores several fields as plain `int` ordinals with no engine-level range enforcement: `PlotState.crop`, `Plot.host_type`, `Decoration.type`, and the `inventory`/`mandi_glut` Dictionary keys (also crop ordinals). `SaveSystem.load_state()` already has a tested, correct fallback for two corruption classes — unparseable bytes and wrong Resource type (see `test_save_system.gd`) — both fall back to a fresh `GameState.new()`. But a *third* class is untested and unhandled: a save file that **is** a structurally valid `GameState` Resource (passes both of `load_state()`'s checks) but contains an out-of-range ordinal in one of the fields above.

`GameData.crop_def()`, `host_type_def()`, and `decoration_type_def()` all do a raw `_defs[key]` Dictionary lookup with no bounds check and no fallback — contrast this with `GameData.farmhouse_level_def()` (`game_data.gd:299-306`), which explicitly clamps out-of-range levels to the last defined tier specifically to avoid crashing, and with `villager.gd:86-90`'s `character_key` handling, which uses `.get(key, "")` + a graceful `push_error`-and-return instead of a hard failure. The three catalogue lookups above don't follow either of those two already-established patterns in this codebase.

A GDScript Dictionary `[]` lookup on a missing key returns `null` rather than raising immediately, so the failure surfaces one line later as a null-dereference (e.g. `GameData.crop_def(crop).weather_risk_percent`) — an unhandled runtime error at the point of use.

**Attack scenario**: `.tres` is a **human-readable plaintext format** — no special tooling is needed to hand-edit `user://save.tres` (reachable via a rooted device, or `adb run-as` on a debug build). Setting `plot.state.crop`, `plot.host_type`, or a `Decoration.type` to any integer outside its enum's defined range (or accidentally corrupting one of these fields through any future bug elsewhere in the save pipeline) produces a save that loads successfully but then fails on first use:
- `resolve_growth_completions()` runs on a 3-second repeating `Timer` (`village_board.gd:32,99,158`) and calls `GameData.crop_def(growing.crop)` for any `GROWING` plot — this means a save with a tampered `crop` ordinal on a growing plot will error every 3 seconds, every time the game is launched, until the save is deleted or manually fixed.
- `village_snapshot_mapper._plot_label()` is called on every board rebuild (same cadence).
- A tampered `Decoration.type` is safer at render time (`village_board.gd:457-474`'s `_decoration_model_path()` already has a default `_:` case and degrades to an invisible decoration) but crashes as soon as the player taps that decoration to open its info card (`decoration_info_card.gd:54`).

**Why this is HIGH and not MEDIUM**: the practical impact is more severe than "limited" (the MEDIUM tier's own definition) — repeated runtime errors on a background timer effectively brick that save on every future launch until manual intervention, with no player-facing explanation. It also contradicts this codebase's own explicit design intent: `save_system.gd`'s header comment and `test_save_system.gd` both frame "any invalid save degrades gracefully to a fresh state" as a deliberate, already-partially-implemented contract (mirroring `GameRepository.kt`'s original Kotlin fallback) — this finding is a gap in that same contract, not a new concern.

**Remediation**: make `crop_def()`, `host_type_def()`, `decoration_type_def()` defensive like `farmhouse_level_def()` already is, plus extend `SaveSystem.load_state()` to validate loaded field ranges as defense-in-depth.

**Effort**: Low–Medium.

**Status**: ✅ Fixed 2026-08-21 (same session). See `godot/scripts/economy/game_data.gd` and `godot/scripts/economy/save_system.gd`.

---

## MEDIUM Findings

None.

---

## LOW Findings

### SEC-002: Test/dev tooling (GUT addon + `tests/`) ships inside the release Android export
**Category**: Data Exposure / Dependency hygiene
**File**: `godot/export_presets.cfg:9-11` (`export_filter="all_resources"`, `include_filter=""`, `exclude_filter=""`)
**Description**: The single Android export preset uses `export_filter="all_resources"` with no exclude filter, so `godot/addons/gut/` (257 files, ~2.9 MB — the GUT unit-test framework, editor/CLI-only) and `godot/tests/unit/` (227 KB of test scripts, including test fixtures that exercise internal economy formulas) are bundled into the shipped APK/AAB alongside game code.
**Attack scenario**: Not a credential leak or an exploit — a hardening gap. An APK is trivially unpackable, so this ships internal test source/dev tooling to anyone who downloads the app, unnecessarily grows the binary. GUT itself carries negligible supply-chain risk (pure GDScript, MIT-licensed, no CVEs, not network-facing — see Dependency Inventory) — the concern is scope/bloat, not the library's safety.
**Remediation**: Set `exclude_filter="addons/gut/*,tests/*"` on the Android export preset.
**Effort**: Low.
**Status**: ✅ Fixed 2026-08-21 (same session). See `godot/export_presets.cfg`.

### SEC-003: Godot `.tres`/Resource loading executes embedded script/resource references — informational, not currently exploitable given this project's threat model
**Category**: Save / Serialization (architectural note)
**File**: `godot/scripts/economy/save_system.gd:21` (`ResourceLoader.load(path, "GameState", ...)`)
**Description**: Godot's `.tres`/`.tscn` text-resource format can embed references to arbitrary `Resource`/`Script` subresources, and loading an untrusted `.tres` can execute GDScript embedded in it (long-standing Godot behavior, not specific to 4.7). `SaveSystem.load_state()` type-checks the *result* but the parse/instantiation step happens before that check runs.
**Why this is LOW, not higher**: the threat model that would make this exploitable — an attacker with write access to `user://save.tres` — already requires root or `adb run-as` on a debug build, i.e. far more device access than this vector would grant.
**Remediation**: No urgent action. Worth revisiting if the project ever adds save import/export, cloud sync, or save-sharing between players.
**Effort**: Low (documentation now; re-evaluate only if save-sharing becomes real).
**Status**: Accepted — documented, no action needed unless the scope above changes.

---

## Accepted Risk

- **No per-user encryption or integrity checksum on save files**: explicitly assessed and accepted, not a gap to fix. Single-player, offline, no leaderboard, no PvP, no real-money IAP, cosmetic/economy-only save data. Encrypting/signing the save would add real friction (blocks legitimate backup/hand-editing, a normalized practice in this genre — Stardew Valley, Harvest Moon, etc. all ship plaintext-editable saves) for negligible actual benefit, since there's no other player or economy to protect from a single player editing their own file. Local save-editing is real but is expected/accepted-risk territory for this genre, not a MEDIUM/HIGH finding — the actual bug was SEC-001 (crashing on malformed data), a robustness problem, not a cheat-prevention one.
- **No save-format version field**: `GameState` has no explicit schema-version field. Known, already-documented deliberate deferral (ADR-0002: "no migration path (none needed, no players yet at this stage)") — noted here for visibility at the next audit, once real players exist and a migration path becomes necessary.
- **Worker-automation wage deduction** (`game_economy.gd`, `state.coins = maxi(state.coins - wage, 0)`): independently reviewed — every player-initiated purchase across the whole economy layer is gated by an explicit `if state.coins < cost: return` before any deduction; the one ungated site is this automated post-harvest wage, which only runs after a harvest has already completed (can't be undone) and is clamped at 0. Confirmed as a deliberate, correctly-conservative design choice, not a gating bug.
- **GDPR/COPPA/CCPA**: confirmed via grep that no personal data, analytics, ads, or IAP code exists anywhere in the audited codebase, and `export_presets.cfg` requests no custom Android permissions. The game currently collects zero player data of any kind. Still worth a placeholder privacy policy for store-listing purposes — an owner/release-management concern, not a code-level finding.

---

## Dependency Inventory

| Plugin / Library | Version | Source | Known CVEs |
|---|---|---|---|
| GUT (Godot Unit Test) | 9.6.1 | `godot/addons/gut/` — bitwes/Gut, MIT license | None — pure-GDScript test runner, not network-facing, not a parser of untrusted external input. Editor/CLI tool only; see SEC-002 for the separate concern that it currently ships in the release binary. |

No other addons, plugins, or third-party libraries found under `godot/addons/`, `godot/plugins/`, or equivalent.

---

## Remediation Priority Order

1. ~~**SEC-001**~~ — ✅ Fixed 2026-08-21
2. ~~**SEC-002**~~ — ✅ Fixed 2026-08-21
3. **SEC-003** — Documented/accepted; no action needed unless save-import/sharing is added later — Est. effort: **Low**

---

## Re-Audit Trigger

Run `/security-audit` again before any public release to confirm SEC-001/SEC-002's fixes hold and no new HIGH/CRITICAL findings have appeared since. The Polish → Release gate requires this report with no open CRITICAL or HIGH items — met as of the fixes recorded above.
