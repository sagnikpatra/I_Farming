# Audio: Core Gameplay Loop

**Status**: Accepted direction, code complete and tested, all 40 real audio
asset files sourced and in place — see "Implementation Status" below.

## 1. Overview

The first audio pass for Kisan Khet's core gameplay loop: economy actions
(plant/harvest/sell/purchase), progression milestones (structure unlocks,
Farmhouse upgrades, batch-resolve), LiveOps rewards, UI feedback, and a
layered ambience bed (village base + Monsoon/Festival adaptive layers +
scattered environmental detail sounds).

## 2. Sonic Direction (audio-director)

Warm, grounded, and unhurried — matching the game's toon-shaded, sun-baked
Indian-village visual language rather than a bright/cartoonish "casual
mobile game" palette. Economy SFX (plant/harvest/sell) should feel tactile
and earthy (soil, cloth, coin/grain textures) rather than synthetic chimes.
Progression moments (structure unlocks, Farmhouse upgrades) get more
resonant, ceremonial voicing — these are rare and meant to land as genuine
milestones. UI sounds stay small and unobtrusive, clearly subordinate to
the SFX bus. Ambience is the emotional bed: a living village (birds, a
distant temple bell, a well's creak, cattle bells) that shifts
recognizably but gently for Monsoon (rain layer) and Festival (percussion
layer) periods via slow crossfades, never a hard cut.

Two decisions made explicitly during this pass, and why:
- **No looping melodic music track this pass.** A short mobile-budget
  melody loop wears out during the long idle stretches this semi-idle
  economic loop invites; there's also no state machine (no combat, no
  day/night) yet to justify adaptive music stems. The ambient soundscape
  fills the "music" slot instead.
- **Authentic regional-instrument sample libraries (bansuri/tabla/sitar/
  santoor) are almost entirely paid commercial products** — this project's
  hard CC0/free-only line has no easy answer there the way it does for
  Kenney's CC0 3D kits. Ambient/nature-only sound design sidesteps that
  licensing gap honestly rather than papering over it, and CC0 coverage for
  that category (birds, wind, foley) is genuinely strong.

## 3. Event List

### Economy (bus SFX, round-robin variants, max_polyphony 3)
- `economy_plant` — manual seed-picker plant, worker auto-replant, Sandalwood planting
- `economy_harvest` — manual harvest tap, worker auto-harvest
- `economy_sell` — Mandi sell, each Sell-All iteration *(direct/non-Mandi sell has no UI trigger yet — not wired)*
- `economy_purchase_small` — fan/pad, drip irrigation, film renew, security, electricity renew, plant host, place decoration *(land expansion has no UI trigger yet — not wired)*

### Progression (bus SFX)
- `progression_structure_unlock` (max_polyphony 1) — buy Polyhouse/Agroforestry/Aquaculture/Vertical Farm (NOT Mandi, which has no unlock purchase)
- `progression_farmhouse_upgrade` (max_polyphony 1)
- `progression_plot_ready_chime` (max_polyphony 3) — individual per-tick path, suppressed when the batch threshold is exceeded
- `progression_batch_resolve` (max_polyphony 1) — plays once when a single growth tick resolves more than 12 combined ready-transitions + worker actions

### LiveOps (bus SFX)
- `liveops_festival_tier_reward` (max_polyphony 3) — fires once per tier crossed, so a single sale crossing 2 tiers plays twice

### UI (bus UI)
- `ui_button_tap` (max_polyphony 3) — Sell All/Shop/Accessibility/LiveOps-banner/Field-Worker buttons, Quick Nav Bar chips
- `ui_sheet_open` / `ui_sheet_close` (max_polyphony 1 each) — every BottomSheet-based sheet/picker/card, via one shared hook
- `ui_drag_pickup` / `ui_drag_drop_success` (max_polyphony 1 each) — zone and decoration long-press-drag
- `ui_rotate_flip` (max_polyphony 3) — decoration rotate/flip *(zone rotate/flip has no UI trigger in this codebase)*
- `ui_action_rejected` (max_polyphony 1) — **catalogued, not wired** (see Implementation Status)

### Ambience (bus Ambience)
- `amb_village_base_loop` — always-on base bed, starts on VillageBoard load
- `amb_layer_monsoon_rain_loop`, `amb_layer_festival_percussion_loop` — adaptive layers, always playing at -80dB, crossfaded to 0dB over 3s on actual Monsoon/Festival state transitions only
- 11 equal-weight detail one-shots (birds/temple-bell/well-creak/cattle-bell), scheduled via 3 reusable Timer+player pairs firing every 8–150s

## 4. Asset Naming List (40 files, `res://assets/audio/{sfx,ambience}/`)

**SFX/UI (26, `res://assets/audio/sfx/`)**
```
sfx_economy_plant_01.ogg / _02 / _03
sfx_economy_harvest_01.ogg / _02 / _03
sfx_economy_sell_01.ogg / _02 / _03
sfx_economy_purchase_small_01.ogg / _02
sfx_progression_structure_unlock_01.ogg
sfx_progression_farmhouse_upgrade_01.ogg
sfx_progression_plot_ready_chime_01.ogg / _02
sfx_progression_batch_resolve_01.ogg
sfx_liveops_festival_tier_reward_01.ogg
sfx_ui_button_tap_01.ogg / _02
sfx_ui_sheet_open_01.ogg
sfx_ui_sheet_close_01.ogg
sfx_ui_drag_pickup_01.ogg
sfx_ui_drag_drop_success_01.ogg
sfx_ui_rotate_flip_01.ogg / _02
sfx_ui_action_rejected_01.ogg
```

**Ambience (14, `res://assets/audio/ambience/`)**
```
amb_village_base_loop.ogg
amb_layer_monsoon_rain_loop.ogg
amb_layer_festival_percussion_loop.ogg
amb_detail_bird_bulbul_01.ogg / _02
amb_detail_bird_mynah_01.ogg / _02
amb_detail_bird_crow_01.ogg / _02
amb_detail_temple_bell_01.ogg / _02
amb_detail_well_creak_01.ogg
amb_detail_cattle_bell_01.ogg / _02
```

Format: OGG Vorbis, 44.1kHz. Loudness targets: ambience ~-23 LUFS
integrated; rare celebratory stingers (structure-unlock, Farmhouse-upgrade,
batch-resolve, festival-tier-reward) ~-12 to -10 LUFS integrated — both
verified by direct `ffmpeg loudnorm` measurement of the delivered files
(`production/qa/accessibility/audio-accessibility-reaudit-2026-08-21.md`),
not just the sourcing pipeline's own self-report. Ambience detail one-shots
are CENTERED (plain, non-panned `AudioStreamPlayer`) — no directional/2D/3D
positioning this pass.

**Regular SFX/UI (the 22 files outside the stinger tier) — corrected target,
2026-08-21**: the original ~-16 to -14 LUFS *integrated* target was wrong
for this content and is now abandoned, not just missed. Independent
re-measurement (the same re-audit above) found nearly every one of these
files was 3-13 dB under that target despite having healthy peak levels
(-1.2 to -6.0 dBFS) — because most are sub-second transients, and LUFS-
integrated measurement is designed for continuous/broadcast content, not
short one-shot game SFX: raising a 100-300ms click's *integrated* loudness
to -15 LUFS is mathematically impossible without either clipping its peak
or applying destructive dynamic-range compression that would change its
character (confirmed directly — attempting real two-pass `loudnorm` on the
worst-case file could only reach -26.45 LUFS before hitting its true-peak
ceiling). **Corrected technique**: peak normalization to a consistent
-2.0 dBFS target (matching where most of these files already clustered
naturally), applied directly to the original files — deliberately NOT
silence-trimmed first, after a trim pass was found to occasionally cut
into real transient content on files with multiple internal silence gaps
(a real bug caught by an implausible +25 dB gain result during
remediation, not shipped). All 22 files re-peak-normalized, durations
verified unchanged, re-imported cleanly, evidence in the re-audit doc.

**Loop-point note for the 3 ambience-loop files**: Godot's Ogg Vorbis import
only supports a loop-*begin* offset, not a loop-end trim point. The
implementation deliberately does not depend on that import setting at all —
each ambience player self-restarts via its own `finished` signal instead —
but the seamless splice point (the file's actual end matching its start)
still needs to be authored into the audio file itself by whoever creates it.

## 5. Accessibility Requirements (accessibility-specialist)

- Independent linear [0.0, 1.0] volume control per bus (Master/Ambience/SFX/UI) plus a single "Mute All Audio" toggle, all in `AccessibilitySheet`, persisted to `user://accessibility.tres`
- Applied LIVE via `AudioServer.set_bus_volume_linear()`/`set_bus_mute()` — no relaunch needed, unlike text-scale
- No audio-only critical information: every gameplay signal audio reinforces (plot ready, batch resolve, rejected action) has an existing visual equivalent (ready badge decal, tint, event message) — audio is supplementary, never the sole channel
- Ambience detail sounds are CENTERED (plain `AudioStreamPlayer`, no directional/2D/3D panning) so they read identically regardless of camera position
- No subtitle/caption requirements — this game has no dialogue/narrative audio at all, by genre; nothing to caption
- No mono-audio option this pass — no *engine-side* stereo panning is used anywhere in this design (confirmed: every player is a plain non-positional `AudioStreamPlayer`), so a mono downmix would have no practical effect on anything gameplay-critical; revisit only if a future pass introduces directional/panned audio. One caveat added 2026-08-21: the sourced ambience files themselves (real-world field recordings) can carry inherent stereo separation independent of any engine panning — low-stakes since ambience carries no gameplay-critical information (see the point above), but not literally zero effect the way the original reasoning implied
- A `AudioEffectLimiter` (ceiling -1.0 dBFS, threshold -3.0 dBFS) was added to the Master bus 2026-08-21 as a structural safety net against any individual sound spiking loud — the per-event `max_polyphony` caps and the growth-tick batch-resolve suppression already prevented the *simultaneous-events* loudness-pileup case; this covers the *single mis-mastered or future-added asset* case that caught the regular-SFX/UI loudness bug above in the first place

## 6. Implementation Status

**Code: complete and tested (350/350 GUT tests passing).** `AudioManager`,
the full 40-file catalogue, bus routing (`godot/default_bus_layout.tres`),
round-robin variant selection, ambience crossfading/scheduling, the
batch-resolve hazard fix, and the accessibility volume/mute controls are
all implemented and wired to real, verified call sites throughout the
codebase (`village_board.gd`, `board_interactor.gd`, `hud.gd`,
`seed_picker.gd`, `agro_plant_picker.gd`, `decoration_info_card.gd`,
`farmhouse_tab.gd`, `mandi_tab.gd`, `polyhouse_tab.gd`).

**All 40 real audio asset files are now sourced and in place** at
`godot/assets/audio/{sfx,ambience}/`, exactly matching this document's
Section 4 naming list (cross-checked programmatically against every path
string `audio_catalogue.gd` references — 40/40 match, zero drift). Sourced
2026-08-21 from freesound.org, filtered to CC0-licensed (public domain)
results only, downloaded as preview-quality streams (no Freesound account
was created or used — see the caveat below), then trimmed/loudness-
normalized/re-encoded to this doc's OGG Vorbis 44.1kHz spec via `ffmpeg`.
Full per-file source/license/author attribution (not legally required for
CC0, kept for traceability, matching this project's Kenney-CC0-credits
convention) is in `godot/assets/audio/CREDITS.md`, including two flagged
approximations: generic bird-chirp/call recordings stand in for
Bulbul/Myna specifically (no CC0 India-species-accurate recordings were
found), and a door-hinge creak stands in for the well-pulley creak (same
"wooden mechanism under tension" character). All 40 files import cleanly
into Godot (verified via a headless editor reimport pass, 40/40
`.import` files generated, zero errors) and the full GUT suite still
passes unchanged (350/350) since this was a pure asset drop, no code
touched. `ResourceLoader.exists()` gating is now satisfied for every
catalogued path — actual playback has NOT yet been verified on-device (no
emulator/phone audio check has been run since these files landed); that
remains a real follow-up, not done as part of this pass.

**Caveat carried forward, not fully resolved**: selection was done by
title/tag/duration metadata only — nobody has actually listened through
the 40 files for tonal fit, loudness-normalization artifacts, or outright
mismatches yet. Preview-quality streams (not Freesound's original
full-quality masters, which require a login this project deliberately
did not create) were used throughout; likely adequate at this doc's modest
mobile SFX/ambience LUFS targets, but not verified against the originals.
A listen-through pass (and an on-device audio check) is the natural next
step before treating this as fully done.

**Not wired this pass** (explicit follow-up, not implied as covered):
- `agroforestry_tab.gd` / `niche_farming_tab.gd` — mechanically identical to
  the already-done `polyhouse_tab.gd` (`progression_structure_unlock` +
  `economy_purchase_small`), deferred for time, not difficulty.
- `ui_action_rejected` — no reliable trigger exists yet. `GameEvent`'s
  `pending_events` carries no success/rejection discriminant and isn't
  drained by any UI code today; needs its own small design decision first.
- Direct (non-Mandi) `sell_crop()`, `buy_land_expansion()`, `rotate_zone()`/
  `flip_zone()` — none of these currently have ANY UI call site in the
  codebase, so there is nothing to wire yet regardless of audio.
- `open_field_tab.gd`, `worker_assignment_row.gd`, `growing_info_card.gd` —
  no catalogued event covers their actions (worker assign/unassign, a
  read-only info card); would need new event definitions, not just wiring,
  if ever added.
