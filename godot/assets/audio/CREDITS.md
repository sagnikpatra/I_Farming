# Audio Asset Credits

All 40 files below are sourced from [freesound.org](https://freesound.org),
filtered to **license:"Creative Commons 0" (CC0 1.0 / public domain)** —
no attribution is legally required, but source sounds are recorded here for
traceability, consistent with this project's Kenney CC0 3D-asset convention
(see `assets_3d/README.md`).

Sourced 2026-08-21 via freesound.org's public CC0-filtered search results
(preview-quality streams only — no Freesound account was created or used).
Each file was selected by title/tag/duration metadata, not by listening —
if any sound reads as a poor fit once actually heard in-game, swap that one
file; the naming/path contract (`design/audio/audio-core-gameplay-loop.md`
Section 4) is unaffected either way.

**Processing**: downloaded preview `.ogg`, trimmed where noted, loudness-
normalized via `ffmpeg loudnorm` to this project's target LUFS per category
(celebratory stingers -11, ambience -23), re-encoded to 44.1kHz OGG Vorbis
(`libvorbis -q:a 5`).

**Correction, 2026-08-21** (`production/qa/accessibility/audio-
accessibility-reaudit-2026-08-21.md`): the original SFX/UI target above
(-15 LUFS integrated) was independently re-measured and found wrong for
this content, not just imperfectly hit — nearly every regular SFX/UI file
is a sub-second transient, and LUFS-integrated measurement (designed for
continuous/broadcast content) cannot reach -15 for a clip that short
without either clipping its peak or destructive compression; confirmed
directly by testing real two-pass `loudnorm`, which could only reach
-26.45 LUFS on the worst-case file before hitting its own true-peak
ceiling. The 22 regular SFX/UI files were re-mastered via peak
normalization instead (-2.0 dBFS target, computed per-file from each
file's own original peak, -0.8 to +4.0 dB gain needed -- no clipping risk).
The 4 celebratory-stinger files and all 14 ambience files were independently
re-measured and confirmed already correctly on-target -- untouched.

**Known approximations** (freesound has no India-specific tag for these):
generic bird-chirp/call recordings stand in for Bulbul/Myna (species-accurate
CC0 field recordings of these specific birds were not found); a door-hinge
creak stands in for a well-pulley creak (same "wooden mechanism under
tension" sound character). `sfx_ui_sheet_close_01.ogg` is a time-reversed
copy of `sfx_ui_sheet_open_01.ogg`'s source (`areverse`), a deliberate choice
for a matched open/close pair rather than an unrelated third sound.

| File | Freesound ID | Title | Author | Notes |
|---|---|---|---|---|
| sfx/sfx_economy_plant_01.ogg | [651293](https://freesound.org/s/651293/) | Digging in wet course sand (2) | f3bbbo | |
| sfx/sfx_economy_plant_02.ogg | [651292](https://freesound.org/s/651292/) | Digging in wet course sand (1) | f3bbbo | |
| sfx/sfx_economy_plant_03.ogg | [651294](https://freesound.org/s/651294/) | Digging in wet course sand (raw file) | f3bbbo | trimmed 2.0–3.3s |
| sfx/sfx_economy_harvest_01.ogg | [322416](https://freesound.org/s/322416/) | Twig Snap 05.wav | Glitchedtones | |
| sfx/sfx_economy_harvest_02.ogg | [841854](https://freesound.org/s/841854/) | Twigs Snap Reverbed | Dreadman247 | |
| sfx/sfx_economy_harvest_03.ogg | [452570](https://freesound.org/s/452570/) | branch breaking forest twig snap crunch.wav | kyles | |
| sfx/sfx_economy_sell_01.ogg | [575583](https://freesound.org/s/575583/) | Pouch of Gold Coins Place Down on Wood.wav | The_Frisbee_of_Peace | |
| sfx/sfx_economy_sell_02.ogg | [378270](https://freesound.org/s/378270/) | 15. Coins.wav | 13GPanska_Jirova_Tereza | trimmed 0–1.8s |
| sfx/sfx_economy_sell_03.ogg | [828156](https://freesound.org/s/828156/) | Register Close Rattle | casperhazebeats | |
| sfx/sfx_economy_purchase_small_01.ogg | [333430](https://freesound.org/s/333430/) | UI Series: A basic click | brandondelehoy | |
| sfx/sfx_economy_purchase_small_02.ogg | [528561](https://freesound.org/s/528561/) | Soft UI Button Click | Jummit | |
| sfx/sfx_progression_structure_unlock_01.ogg | [715067](https://freesound.org/s/715067/) | achievement-sparkle | SkySpeira | |
| sfx/sfx_progression_farmhouse_upgrade_01.ogg | [442943](https://freesound.org/s/442943/) | Level Up | qubodup | |
| sfx/sfx_progression_plot_ready_chime_01.ogg | [700332](https://freesound.org/s/700332/) | Notification Ding | NoTomorrow12 | |
| sfx/sfx_progression_plot_ready_chime_02.ogg | [187337](https://freesound.org/s/187337/) | Electronic Bing Soft.wav | baidonovan | |
| sfx/sfx_progression_batch_resolve_01.ogg | [521645](https://freesound.org/s/521645/) | WinFantasia.wav | Fupicat | |
| sfx/sfx_liveops_festival_tier_reward_01.ogg | [415504](https://freesound.org/s/415504/) | Tadaa.wav | Exchanger | |
| sfx/sfx_ui_button_tap_01.ogg | [488534](https://freesound.org/s/488534/) | UI click | Ranner | |
| sfx/sfx_ui_button_tap_02.ogg | [253168](https://freesound.org/s/253168/) | SFX UI Button Click | suntemple | |
| sfx/sfx_ui_sheet_open_01.ogg | [786514](https://freesound.org/s/786514/) | swoosh_v2 | migoreng1 | |
| sfx/sfx_ui_sheet_close_01.ogg | [786514](https://freesound.org/s/786514/) | swoosh_v2 | migoreng1 | reversed (`areverse`) |
| sfx/sfx_ui_drag_pickup_01.ogg | [824189](https://freesound.org/s/824189/) | Pop in sfx | Sadiquecat | |
| sfx/sfx_ui_drag_drop_success_01.ogg | [339365](https://freesound.org/s/339365/) | drop05.wav | newagesoup | trimmed 0–1.0s |
| sfx/sfx_ui_rotate_flip_01.ogg | [425706](https://freesound.org/s/425706/) | Woosh_Medium_Short_01.wav | moogy73 | trimmed 0–1.0s |
| sfx/sfx_ui_rotate_flip_02.ogg | [803773](https://freesound.org/s/803773/) | whoosh 1 short | Logicogonist | |
| sfx/sfx_ui_action_rejected_01.ogg | [419023](https://freesound.org/s/419023/) | acess denied buzz | Jacco18 | |
| ambience/amb_village_base_loop.ogg | [514550](https://freesound.org/s/514550/) | Countryside Ambience Spring | Kinoton | trimmed 15–45s excerpt |
| ambience/amb_layer_monsoon_rain_loop.ogg | [21189](https://freesound.org/s/21189/) | Louisiana Rain 1.wav | uberhuberman | |
| ambience/amb_layer_festival_percussion_loop.ogg | [633150](https://freesound.org/s/633150/) | tabla 5to4 85bpm -loop.aif | MieliTietty | trimmed 0–20s; authentic tabla loop |
| ambience/amb_detail_bird_bulbul_01.ogg | [815833](https://freesound.org/s/815833/) | Songbirds - Common Chiffchaff; Distant | TheKingOfGeeks360 | approximation, see above |
| ambience/amb_detail_bird_bulbul_02.ogg | [233255](https://freesound.org/s/233255/) | Single Bird Chirp | alegemaate | approximation, see above |
| ambience/amb_detail_bird_mynah_01.ogg | [839918](https://freesound.org/s/839918/) | Parrots - White-winged Parakeets | TheKingOfGeeks360 | trimmed 0–2s; approximation, see above |
| ambience/amb_detail_bird_mynah_02.ogg | [864632](https://freesound.org/s/864632/) | Livingstone's Turaco; Two Short Calls | TheKingOfGeeks360 | approximation, see above |
| ambience/amb_detail_bird_crow_01.ogg | [361470](https://freesound.org/s/361470/) | Crow Caw | Jofae | |
| ambience/amb_detail_bird_crow_02.ogg | [536732](https://freesound.org/s/536732/) | Caw.ogg | egomassive | |
| ambience/amb_detail_temple_bell_01.ogg | [337048](https://freesound.org/s/337048/) | bell-at-daitokuji-temple-kyoto_modified.mp3 | shinephoenixstormcrow | |
| ambience/amb_detail_temple_bell_02.ogg | [271627](https://freesound.org/s/271627/) | 2HinduTemplesBells2.wav | LoopUdu | trimmed 0–3.5s; explicitly Hindu temple bells |
| ambience/amb_detail_well_creak_01.ogg | [845753](https://freesound.org/s/845753/) | Creaking Door #2 | True_Killian | trimmed 0–2.2s; approximation, see above |
| ambience/amb_detail_cattle_bell_01.ogg | [481151](https://freesound.org/s/481151/) | Cow Bells 01.wav | LilMati | |
| ambience/amb_detail_cattle_bell_02.ogg | [481060](https://freesound.org/s/481060/) | Cow Bells 02.wav | LilMati | |
