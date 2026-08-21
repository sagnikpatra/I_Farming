# Audio Listen-Through Pass: Kisan Khet (IFarming)

**Date:** 2026-08-21
**Scope:** All 40 delivered files in `godot/assets/audio/{sfx,ambience}/`
**Trigger:** flagged as an open caveat since the original audio-sourcing session ("selection was by metadata only — nobody has listened through the 40 files yet") and repeated in the loudness-normalization fix's own remediation log.

---

## A real limitation, stated plainly, not worked around

**I cannot hear.** I have no auditory perception, so a genuine "does this sound good and fit the game" pass is not something I can actually perform, regardless of how the output is phrased. This document is **not** that pass — it's the closest technical proxy available, and it should not be mistaken for one. A human still needs to actually listen before this caveat can be considered closed.

What follows are three things I *can* verify without hearing:
1. **Objective technical QC** — clipping, DC offset, digital artifacts (`ffmpeg`/`astats`)
2. **Visual spectrogram inspection** — I can look at images, so structural sanity (clean transient vs. garbled noise, consistent texture, loop-splice continuity) is checkable
3. **Metadata/source plausibility** — cross-referencing each file's actual Freesound source description (`CREDITS.md`) against what it's meant to represent, which can catch a real conceptual mismatch without needing to hear the result

---

## 1. Technical QC — Clean

Ran `ffmpeg -af astats` across all 40 files: **zero clipped samples anywhere**, DC offset small and unremarkable throughout (largest: 0.020 on `sfx_progression_plot_ready_chime_02.ogg`, well under any audible-thump threshold), no dropouts or truncated files. Spot-checked 5 spectrograms across categories (a clean transient SFX, the base ambience loop, two contrasting ambience details) — all show expected, healthy structure: sharp broadband transients for percussive SFX, continuous textured energy with no dropouts for the ambience loop, no aliasing/digital-garbage artifacts anywhere. Nothing here needs fixing.

## 2. Metadata Plausibility — One real finding

Cross-checked all 40 source titles/descriptions in `CREDITS.md` against their catalogued gameplay role. Almost everything is a good or defensible fit (coin sounds for selling, digging sounds for planting, an authentic tabla loop for the festival layer, cow bells for cattle-bell ambience, etc.) — see the full pass below. **One finding stands out:**

### `amb_detail_temple_bell_01.ogg` — likely a poor cultural/tonal fit — MEDIUM

**Source**: "bell-at-daitokuji-temple-kyoto_modified.mp3" — Daitoku-ji is a Zen Buddhist temple complex in **Kyoto, Japan**. This is not an India-specific-tag approximation the way the bird/well-creak substitutions are (and are honestly documented as) — it's a bell from a different country's different religious tradition, and large Japanese temple bells (*bonshō*) are a structurally different instrument from typical Hindu temple bells: struck once, left to resonate in a long, deep, sustained decay.

**This isn't just a title-reading assumption** — I generated spectrograms of both temple-bell files and the difference is visually obvious:
- `amb_detail_temple_bell_01.ogg` (the Japanese one): **one strike**, then a single long sustained decay tail lasting the full ~2s clip — exactly the sonic signature of a large single-strike gong.
- `amb_detail_temple_bell_02.ogg` (explicitly labeled "Hindu Temples Bells" in its own source title): **10+ rapid, repeated strikes** across its 3.5s duration — matching how Hindu temple bells are actually rung (often rhythmically, as part of daily ritual), a completely different rhythmic character.

These two files, both catalogued as `amb_detail_temple_bell_*` variants meant to round-robin as the same conceptual sound, will likely read as **two different instruments** in-game, and `_01` specifically risks sounding identifiably Japanese/Buddhist rather than evoking an Indian village. **Recommend**: source a replacement for `_01` specifically (keep `_02`, which is already correct), or drop `_01` and let `_02` carry the temple-bell detail alone (`AudioCatalogue.AMBIENCE_DETAIL_PATHS` already treats these as one entry in an equal-weight pool, so removing one is a one-line change, not a re-architecture).

### Everything else checked

| File(s) | Source | Verdict |
|---|---|---|
| `sfx_economy_plant_*` | "Digging in wet course sand" | Good fit |
| `sfx_economy_harvest_*` | "Twig Snap" / branch-breaking sounds | Defensible — a stalk-snap reading works for harvesting, though it's a stylized choice rather than an obvious one; lowest-confidence "fine" verdict in this table, worth a human's ear specifically |
| `sfx_economy_sell_*` | Coin pouch / coins / register rattle | Good fit |
| `sfx_economy_purchase_small_*` | Generic UI clicks | Functional, unremarkable — fine |
| `sfx_progression_structure_unlock` | "achievement-sparkle" | Good fit |
| `sfx_progression_farmhouse_upgrade` | "Level Up" | Good fit |
| `sfx_progression_plot_ready_chime_*` | Notification dings | Good fit |
| `sfx_progression_batch_resolve` | "WinFantasia" | Good fit (celebratory, infrequent event) |
| `sfx_liveops_festival_tier_reward` | "Tadaa.wav" | Good fit |
| `sfx_ui_*` (tap/sheet/drag/rotate/rejected) | Generic UI clicks/swooshes/whooshes/buzz | Good, conventional fits throughout |
| `amb_village_base_loop` | "Countryside Ambience Spring" | Good fit, spectrogram confirms clean continuous texture |
| `amb_layer_monsoon_rain_loop` | "Louisiana Rain 1" | Generic rain, not India-specific but rain reads as rain — low concern |
| `amb_layer_festival_percussion_loop` | Authentic tabla loop | Strong fit — genuinely Indian classical percussion |
| `amb_detail_bird_bulbul_*`, `amb_detail_bird_mynah_01` | Generic songbird/parakeet calls | Already honestly documented as approximations (no India-specific tags exist on Freesound); reasonable generic substitutes |
| `amb_detail_bird_mynah_02` | "Livingstone's Turaco; Two Short Calls" | **Worth a second look, LOW-MEDIUM** — turacos are large African birds with loud, unusual whoop/bark calls; spectrogram shows two prominent, structurally complex bursts, not a subtle background chirp. A myna's real call (chattering, mimicking) is quite different in character. Lower-confidence approximation than the others in this bucket. |
| `amb_detail_bird_crow_*` | Crow caws | Good fit — crows are common in both source and target context |
| `amb_detail_well_creak` | "Creaking Door" | Already honestly documented as an approximation; reasonable ("wooden mechanism under tension" logic holds) |
| `amb_detail_cattle_bell_*` | Cow bells | Good fit |

## 3. What Still Needs a Human

This pass can't close the original caveat, only narrow it. Specifically still needed:
- Actually listening to all 40 files, particularly the two flagged above (`temple_bell_01`, `bird_mynah_02`) and the harvest twig-snaps (lowest-confidence "fine" verdict above)
- A subjective call on whether the overall soundscape *feels* right together, which no per-file technical check can substitute for
- Confirming the peak-normalized regular SFX/UI files (fixed in the loudness-normalization pass) sound appropriately punchy in practice, not just measure correctly

## Recommendation

Not blocking — nothing here is broken, and the one real finding (`temple_bell_01`) has a clear, cheap fix path already identified. Worth doing the actual human listen when convenient; this pass at least means that listen can be targeted (2 flagged files + a quick pass on the rest) rather than starting cold.

## Remediation Log (2026-08-21)

`amb_detail_temple_bell_01.ogg` removed from `AudioCatalogue.
AMBIENCE_DETAIL_PATHS` (the round-robin pool actually played in-game) —
`_02` (already confirmed as genuinely Hindu temple bells) now carries the
temple-bell detail sound alone, rather than round-robining with a
structurally mismatched Japanese temple bell. The file itself is left on
disk and still documented in `CREDITS.md` for provenance, just marked
retired — not deleted, since it's a harmless orphaned CC0 asset and
deleting it would ripple the "40 files" count referenced in several other
docs for no real benefit. `bird_mynah_02.ogg`'s weaker approximation and
the harvest twig-snaps were left as-is per this report's own confidence
levels (worth a human's ear, not clear-cut enough to act on unilaterally).
360/360 GUT tests pass, unaffected.

## Closed, 2026-08-21

User did the actual human listen-through (files staged in
`godot_builds/listen-tonight/`, see this doc's own Remediation Log for
what was prepared) and confirmed it sounds good, no further changes
requested. The genuine listen this whole document exists to substitute
for has now happened -- this caveat, open since the original
audio-sourcing session, is closed.
