# Audio Accessibility Re-Audit: Kisan Khet (IFarming)

**Date:** 2026-08-21
**Scope:** `godot/scripts/audio/`, `godot/scripts/accessibility/`, `godot/scripts/ui/accessibility_sheet.gd`, all 40 delivered files in `godot/assets/audio/`
**Trigger:** `production/qa/accessibility/village-board-and-management-sheets-audit-2026-08-21.md` §7 deferred audio accessibility until real assets/sliders existed. Both now exist (EPIC-M8's audio pass) — this is that deferred re-audit.
**Standard applied:** this project's own `.claude/agents/accessibility-specialist.md` Audio Accessibility checklist (5 items), cross-referenced against `design/audio/audio-core-gameplay-loop.md` §5's own accessibility reasoning written during implementation.

---

## Summary Table

| # | Standard item | Status | Severity |
|---|---|---|---|
| 1 | Separate volume sliders: Master, Music, SFX, Dialogue, UI | ✅ Present, with justified adaptations | — |
| 2 | Visual indicators for important directional/ambient sounds | ✅ Confirmed compliant | — |
| 3 | Full subtitle support for dialogue/story-critical audio | N/A — no dialogue system exists | — |
| 4 | Option to disable sudden loud sounds / normalize audio | ✅ Fixed 2026-08-21 (see Remediation Log) | ~~HIGH~~ |
| 5 | Mono audio option for single-speaker/hearing aid users | ✅ Justified omission, one caveat noted | LOW |
| — | *(new, not on the checklist)* No Master-bus limiter as a structural safety net | ✅ Fixed 2026-08-21 (see Remediation Log) | ~~LOW~~ |

**Headline finding**: the volume-control architecture itself is solid and correctly wired. The real problem is upstream of it — most one-shot SFX/UI files were mis-mastered during the EPIC-M8 sourcing pass and are measurably far quieter than documented, which undermines "normalize audio" in practice regardless of how good the mixer controls are.

---

## 1. Volume Sliders (Standard item 1) — ✅ Present, with justified adaptations

`accessibility_sheet.gd`'s `_build_audio_row()` provides 4 independent linear `[0.0, 1.0]` sliders (Master/Ambience/SFX/UI) plus a single "Mute All Audio" toggle, each showing a live percentage. Confirmed in code:

- Applied **live** via `AudioServer.set_bus_volume_linear()`/`set_bus_mute()` (`village_board.gd`'s `_on_accessibility_settings_changed()`), not requiring a relaunch.
- Persisted independently of game-save data (`user://accessibility.tres`, not `save.tres`) — correct per this project's existing save-integrity boundary (`security-audit-2026-08-21.md`).
- Bus routing verified in `default_bus_layout.tres`: Ambience/SFX/UI all `send = "Master"`, so the Master slider/mute genuinely silences everything, not just itself.

**Deviation from the checklist's exact 5 names, and why it's fine**: no separate "Music" bus exists — this game has no music track, only an ambience bed, so "Ambience" fills that practical role. No "Dialogue" bus — no dialogue system exists (see §3 below). Both are honest adaptations to this game's actual content, not gaps.

## 2. Visual Indicators for Directional/Ambient Sound (Standard item 2) — ✅ Confirmed compliant

Checked every catalogued gameplay-relevant SFX event's actual call site (not just the design doc's claim) for a simultaneous visual equivalent:

| Audio event | Visual equivalent, verified |
|---|---|
| `progression_plot_ready_chime` | Fires in `village_board.gd`'s `_play_growth_tick_audio()` exactly on the GROWING→READY_TO_HARVEST transition — the same tick that stamps the ready-badge decal (see the earlier accessibility pass's §3 fix) |
| `economy_harvest`/`economy_plant` (worker-automated) | Same tick as the plot's tint/model changing; also a persistent `GameEvent` text notification ("A worker harvested...") for anything resolved off-screen/offline |
| `economy_sell`, `liveops_festival_tier_reward` | Coin count and inventory chips update in the same HUD refresh |
| `progression_structure_unlock`, `progression_farmhouse_upgrade` | Structure model/Farmhouse model changes on the board, level badge updates |
| `ui_sheet_open/close`, `ui_drag_pickup/drop_success`, `ui_rotate_flip` | Inherently tied to an already-visible UI action (opening a sheet, dragging something on screen) |

No audio-only critical information found anywhere. Ambience detail sounds (birds/temple bell/well-creak/cattle-bell) are atmosphere only, carry no gameplay information, and — confirmed via grep across `audio_manager.gd` — every player is a plain `AudioStreamPlayer` (never `AudioStreamPlayer2D`/`3D`), so nothing is positionally panned that could need a directional indicator in the first place.

## 3. Subtitles (Standard item 3) — N/A

No dialogue/narrative audio system exists anywhere in this codebase, confirmed by the original village-board audit and unchanged since. Nothing to caption.

## 4. Sudden Loud Sounds / Normalization (Standard item 4) — ⚠️ HIGH

`design/audio/audio-core-gameplay-loop.md` §4 documents loudness targets: ambience ≈ −23 LUFS integrated, regular SFX/UI ≈ −16 to −14 LUFS short-term, celebratory stingers ≈ −12 to −10 LUFS. Independently re-measured all 40 delivered files with `ffmpeg`'s `loudnorm` filter (not trusting the sourcing pipeline's own self-report) — the earlier sourcing session's own flagged caveat ("selection was by metadata only, nobody has listened through the 40 files yet") turns out to have a real, measurable consequence:

| Category | Target | Measured | Verdict |
|---|---|---|---|
| Ambience (14 files) | −23 LUFS | −22.0 to −23.9 LUFS (13 of 14 measurable) | ✅ On target |
| Celebratory stingers (4 files, all >1.6s) | −12 to −10 LUFS | −12.1 to −10.9 LUFS | ✅ On target |
| **Regular SFX/UI (22 files)** | **−16 to −14 LUFS** | **Only 2 of 22 (9%) land in range.** 13 measurably fall short (avg −21.4 LUFS, 6.4 dB under the −15 midpoint; worst case `sfx_economy_harvest_01.ogg` at −27.4 LUFS). 7 more (32%) are shorter than ~0.4s — too short for `loudnorm`'s own EBU R128 gating window to produce a valid measurement at all, meaning the original normalization pass couldn't have reliably corrected them either. | ❌ **Systemically under-target** |

**Root cause**: the sourcing pipeline ran single-pass `ffmpeg loudnorm`, which is well-documented to be unreliable below ~3 seconds of audio — nearly every one-shot SFX file in this catalogue is under that. This isn't a "some files got missed" problem; it's a "the technique used doesn't work for this content type" problem.

**Practical effect, not just a numbers mismatch**: because ambience sits at a rock-steady −23 LUFS and most one-shot SFX/UI sit anywhere from −18 to −27 LUFS, routine feedback sounds (button taps, plant/harvest/sell chimes, drag pickup) are frequently **quieter than or comparable to the always-on ambience bed**, not clearly above it the way the design intended. A player relying on audio confirmation — exactly who "normalize audio" and the volume-slider work is meant to serve — may not reliably hear it at all, regardless of how correct the mixer/slider code is. Turning up the SFX slider raises volume but doesn't fix the *relative* imbalance between individual clips within that same bus.

The batch-resolve suppression logic (`_play_growth_tick_audio()`'s `BATCH_RESOLVE_THRESHOLD` collapse-to-one-chime) and per-event `max_polyphony` caps already blunt one specific loudness-pileup scenario (many simultaneous events after an offline gap) — that part of "prevent sudden loud sounds" is solid. The mastering-level problem above is separate and larger.

**Recommendation**: needs a real remaster pass, not a threshold retune — two-pass `loudnorm` (measure, then apply) or a peak/RMS-based normalizer instead of single-pass integrated `loudnorm` for anything under ~3s, re-verified the same way this audit did (measure the *output*, don't trust the *pipeline's claim*). Out of scope to silently fix in this audit — flagging for your decision below.

## 5. Mono Audio Option (Standard item 5) — LOW, justified omission with one caveat

`design/audio/audio-core-gameplay-loop.md` §5 already reasoned through this at design time: "no stereo panning is used anywhere in this design, so a mono downmix would have no practical effect." Verified true for **engine-side** panning — confirmed no `AudioStreamPlayer2D`/`3D` anywhere, every sound plays centered regardless of camera position.

**One gap in that reasoning, not previously noted**: the sourced `.ogg` files themselves (real-world Freesound field recordings, particularly the ambience detail sounds) can carry genuine inherent stereo separation from how they were originally recorded, independent of anything Godot does. A player who can't perceive one channel could theoretically miss some stereo *nuance* in, say, a bird call's natural room ambience. This is narrow and low-stakes — per §2 above, ambience carries no gameplay-critical information, so the worst case is a slightly flatter atmosphere, never lost information. Not worth a code change on its own; worth noting if a future pass ever adds genuinely panned/positional audio, at which point the mono-option question should be revisited for real, per the design doc's own stated condition.

## 6. New: No Master-Bus Limiter — LOW

`default_bus_layout.tres` has no `AudioEffectLimiter`/`AudioEffectCompressor` on any bus. The per-event `max_polyphony` caps and batch-resolve suppression already prevent the specific *simultaneous-events* loudness-pileup scenario, but there's no structural safety net against a single mis-mastered or future-added asset spiking loud (the §4 finding above is itself proof individual clips can be significantly off-target without anything catching it). A `AudioEffectLimiter` on the Master bus (ceiling around −1 dBTP, matching the true-peak levels already measured across the existing files) would be a cheap, durable backstop independent of per-asset mastering quality — but is a nice-to-have alongside fixing §4, not a substitute for it.

---

## What's Genuinely Solid (not just "no findings")

- The mixer architecture (4 sliders + mute, live-applied, correctly routed, persisted separately from save data) is well-built and needs no changes.
- Every gameplay-relevant sound has a verified simultaneous visual equivalent — no audio-only information anywhere.
- The mono-audio omission and lack of a Music/Dialogue bus are both *reasoned* decisions matching this game's actual content, not oversights.
- Loudness targets are *correctly hit* for the two categories (ambience, stingers) whose source clips are long enough for the mastering technique used to work reliably.

## Remediation Log (2026-08-21)

User asked to fix the loudness normalization directly, no further scoping question needed.

**§4 — investigation changed the diagnosis, not just the fix**: chasing the
originally-documented −16 to −14 LUFS *integrated* target turned out to be
chasing the wrong number. Tested directly: real two-pass `loudnorm` on the
worst-case file (`sfx_economy_harvest_01.ogg`, originally −27.4 LUFS) could
only reach −26.45 LUFS before its own true-peak ceiling stopped it —
confirming a 100-300ms transient genuinely cannot hit that target without
either clipping or destructive compression, regardless of technique. The
original ~-16 to -14 LUFS integrated target itself was the mistake, not
the mastering execution against it.

Tried silence-trimming first (removing leading/trailing near-silence was
the hypothesis for why integrated LUFS read so low despite healthy peaks)
— this **broke 2 files**: `sfx_economy_sell_02.ogg`'s trim cut the file
down to 24ms and discarded its actual −2.0 dBFS peak transient entirely,
which only surfaced because the resulting gain calculation demanded an
implausible +25 dB — caught and discarded before it reached the real
asset directory, not shipped.

**Actual fix applied**: peak-normalized all 22 regular SFX/UI files
directly (no trimming) to a consistent −2.0 dBFS target, computed from
each file's own original measured peak (range: −0.8 dB to +4.0 dB gain
needed — all sane, no clipping risk anywhere). Verified per file: duration
unchanged (confirms no content was cut), new peak lands close to target,
re-imported cleanly via a headless editor pass (22/22, zero errors), full
GUT suite unaffected (360/360 — audio isn't unit-tested, this is scene-
tree-adjacent runtime content per this codebase's existing convention).
Originals backed up to the session scratchpad before any file was touched.

**§6 — Master-bus limiter**: added via a small one-off script that loaded
the real `AudioServer`, called `add_bus_effect()`, and re-saved the layout
through Godot's own `ResourceSaver` — deliberately not hand-typed against
this HIGH-knowledge-risk pinned Godot version (`docs/engine-reference/
godot/VERSION.md`). Ceiling −1.0 dBFS, threshold −3.0 dBFS. Verified via a
second script that all 4 buses (Master/Ambience/SFX/UI) still resolve
correctly by name/index/routing after the save, and the limiter is present
with `effects=1` on Master.

**§5's mono-audio caveat**: documented directly in `design/audio/audio-
core-gameplay-loop.md` §5 (the design doc's own accessibility-requirements
section), not just left in this report.

design/audio/audio-core-gameplay-loop.md §4/§5 updated to record the
corrected loudness target/technique and both fixes above.
