# Accessibility Audit: Kisan Khet (IFarming) — Village Board, HUD & Management Sheets

**Date:** 2026-08-21
**Engine:** Godot 4.7.1 · **Scope:** `godot/` (active codebase) · **Target:** WCAG 2.1 Level AA
**Platform profile applied:** Mobile, touch-only (no gamepad/keyboard target — those checklist items are out of scope by design, not omitted by oversight). Single-player, no narrative dialogue (no subtitle/CC items — nothing to caption). Zero audio currently implemented on either stack (deferred, not audited as broken). Visual language is emoji-driven by design (not flagged as a defect in itself).

---

## 0. Top-Level Finding — No Accessibility Options Exist

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| The app has **no accessibility settings screen at all** — no text-scale control, no colorblind/high-contrast mode, no audio sliders (moot until audio exists, see §7), no gesture-alternative toggle, no reduced-motion toggle. Every accessibility-relevant value in the codebase (font sizes, colors, gesture thresholds) is a hardcoded constant with no player-facing override anywhere in `godot/scripts/ui/` or `godot/scripts/village_board/`. | SC 1.4.4 Resize Text; general AA baseline expectation | **BLOCKING** | Before shipping, add a minimal Settings/Accessibility sheet (reuse the existing `BottomSheet` primitive) with at minimum: a text-size multiplier, a colorblind-safe palette toggle, and — once audio lands per EPIC-M8 — the four/five volume sliders called for in this agent's own standards. This is one architectural gap, not the dozens of per-screen "text isn't scalable" duplicates that would otherwise appear below. |

**Status:** ✅ Fixed 2026-08-21 — a minimal Accessibility settings sheet was added (see Remediation Log).

---

## 1. Cross-Cutting — Shared Palette & Widget-Builder Pattern

Every management sheet (`farmhouse_tab.gd`, `mandi_tab.gd`, `polyhouse_tab.gd`, `agroforestry_tab.gd`, `niche_farming_tab.gd`, `events_tab.gd`) and both info cards (`growing_info_card.gd`, `decoration_info_card.gd`) copy-pastes the same `_make_title_label()`/`_make_label_settings()` helpers, defaulting label text to `Color.WHITE`. This is safe when a label sits inside a `_make_panel()`-wrapped `WOOD_BROWN_LIGHT`/`SOIL_BROWN_DARK` container, but several call sites add labels **directly to the sheet body**, which sits on `BottomSheet`'s own cream panel background (`bottom_sheet.tscn:6`, `bg_color = Color(1, 0.972549, 0.905882, 1)` ≈ `#FFF8E7`).

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| **White text directly on the cream `SheetPanel` background** — measured contrast ratio ≈ **1.06:1** (white `#FFFFFF` vs `#FFF8E7`), against a 4.5:1 requirement. Confirmed at: `farmhouse_tab.gd` `_build_header()` (lines 119-143, added to `_body` unwrapped) and `_build_max_level_message()` (197-201); `mandi_tab.gd` `_build_build_card()` (197-231) and `_build_intro()` (234-253); `polyhouse_tab.gd` `_build_build_card()` (157-189); `agroforestry_tab.gd` `_build_build_card()` (107-141) and `_build_hint_label()` (169-174); `niche_farming_tab.gd` `_make_section_header()` (167-168) and `_build_build_card()` (171-199); `growing_info_card.gd` (31-50, entire card added to root with no panel); `decoration_info_card.gd` (56-75, same). The small drop-shadow (`shadow_size=4`, offset `(2,3)`) does not remedy this — WCAG contrast is measured on the glyph fill color, and the shadow only darkens one edge of each letter. | SC 1.4.3 Contrast (Minimum) | **BLOCKING** | Either wrap every unwrapped section in the existing `_make_panel(WOOD_BROWN_LIGHT, …)` helper (already used correctly elsewhere in the same files), or override these labels' `font_color` to `SOIL_BROWN_DARK` the way `seed_picker.gd`/`decoration_picker.gd`/`agro_plant_picker.gd`'s title labels correctly already do (`_make_label_settings(18, SOIL_BROWN_DARK)` — confirmed passes at ≈15:1). This is a real, on-device-reproducible bug affecting the *first thing a player sees* on 4 of 6 management sheets (every "not yet built" card) plus both info cards — not a hypothetical. |
| **White text on the `RIPE_GOLD` (`#FFC107`) "active/purchased" chip state** — measured contrast ≈ **1.63:1**. Confirmed at: `polyhouse_tab.gd` `_build_chip()` (229-269, "Fan & Pad ✓" / "Drip ✓" / "Film Active ✓" when active); `agroforestry_tab.gd` `_build_security_chip()` (144-166, "Security … ✓" when active); `niche_farming_tab.gd` `_build_electricity_chip()` (202-227, "⚡ Powered: …" when active). | SC 1.4.3 Contrast (Minimum) | **BLOCKING** | This is arguably worse than §1's cream-background bug because it hits exactly the state players most need to visually confirm — "did my upgrade purchase register?" — and 1.63:1 is unreadable for anyone, not just low-vision players. Swap active-state font color to `SOIL_BROWN_DARK` (same fix, same file already imports the constant) rather than leaving it `Color.WHITE`. |
| White text on `SAFFRON_DARK` (`#C56A00`, ≈3.85:1) and `FIELD_GREEN` (`#4CAF50`, ≈3.10:1) "chunky action buttons" — both clear the 3:1 non-text/large-text bar (SC 1.4.11) but fail the 4.5:1 normal-text bar at their actual 12-14px font sizes. Confirmed at: `hud.gd` Sell All (388) and Field Worker (400) buttons; `farmhouse_tab.gd` Upgrade button (72-73); `mandi_tab.gd` Register button (227); `polyhouse_tab.gd`/`agroforestry_tab.gd`/`niche_farming_tab.gd` Build buttons (185 / 137 / ~195); `events_tab.gd` Premium Pass button (251-276). | SC 1.4.3 Contrast (Minimum) | **HIGH** | Darken these two brand colors slightly for text-bearing buttons specifically (a ~10-15% luminance drop gets both over 4.5:1 without a visible brand-identity change), or bump these buttons' font size to the ≥18px "large text" threshold where 3:1 applies instead. |
| `events_tab.gd`'s active-Monsoon card background (`RIPE_GOLD.lerp(WOOD_BROWN_LIGHT, 0.5)`, line 124) with white 17px title text — measured contrast ≈ **3.03:1**, fails 4.5:1 (17px doesn't clear the large-text threshold). | SC 1.4.3 Contrast (Minimum) | **HIGH** | Same fix family as above — darken the lerp target or switch text color for this specific card state. |

**Status (BLOCKING rows):** ✅ Fixed 2026-08-21 (see Remediation Log). HIGH rows in this section remain open — tracked for a follow-up pass, not part of this remediation.

---

## 2. HUD (`godot/scripts/ui/hud.gd`)

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| Coin panel (`SOIL_BROWN_DARK` bg, white text, lines 344-355), Level badge (`LEVEL_BADGE_BLUE`, 357-361, ≈4.53:1 — passes, right at the line), and inventory chips (`WOOD_BROWN_LIGHT` bg, 494-507) all measure comfortably ≥4.5:1. No finding here — noted as the *correct* pattern this file otherwise follows. | — | — | — |
| Sell All / Field Worker buttons — see §1's `SAFFRON_DARK`/`FIELD_GREEN` finding (applies here too, lines 388/400). | SC 1.4.3 | HIGH | See §1. |
| Quick Nav Bar chips (`_build_nav_chip()`, 464-484) have no `custom_minimum_size` — their touch-target size is driven entirely by an 18px emoji glyph plus 8-10px padding, landing well under any reasonable touch-target guideline. | (WCAG 2.1 AA has no target-size SC — SC 2.5.5 is AAA-only in 2.1; SC 2.5.8, min 24×24 CSS px, is WCAG 2.2) | ADVISORY | Not a hard 2.1 AA failure, but worth a `custom_minimum_size` floor (e.g. 44×44) given this project's own touch-only, no-alternative-input profile — a missed tap here has no keyboard fallback to fall back on. |
| No emoji-only signal issue found in the HUD itself: every icon (🪙, 🌾, per-crop emoji in inventory chips) is paired with adjacent numeric/text labels, not used as the sole information carrier. | — | — | Confirmed compliant, noted for completeness. |

---

## 3. Village Board — Plot Lifecycle Color Coding (`godot/scripts/village_board/village_board.gd`)

This was the specific item flagged for careful review, and it is a real finding.

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| **Whether a crop plot is ready to harvest is conveyed *only* by tint color**, with no accompanying shape, icon, or text overlay in the live 3D scene. `_build_plot()` (766-832) applies `_plot_tint_color()` (743-763) as a flat `albedo_color` multiply on the *same* crop-plot mesh (`VillageFixtureData.CROP_PLOT`) for every lifecycle state — no separate model, particle, glow, or badge is added for `READY_TO_HARVEST` vs `GROWING`. `PLOT_GROWING_TINT = Color(0.55, 0.75, 0.35)` (a yellow-green, HSV hue ≈90°) vs `PLOT_READY_TINT = Color(0.95, 0.75, 0.20)` (an amber/gold, HSV hue ≈44°) share the same saturation family and green channel; the two rely on hue (green vs. amber) and a value/brightness bump to differ. Hue discrimination in exactly this yellow-green-to-orange range is a known weak point for protanopia/deuteranopia. The lifecycle-tinted color is *also* multiplied by `WATER_TINT_MULTIPLIER` for Aquaculture plots (94), compressing the already-narrow hue gap further underwater. A `GrowingInfoCard`/direct-harvest tap only tells the player the state *after* they've already committed to a tap — there is no pre-tap signal other than color for "should I tap this now." | SC 1.4.1 Use of Color | **BLOCKING** | This is core, frequent, resource-consequential gameplay (deciding what to harvest right now, board-wide, at a glance), not decorative — it should not rely on color alone even under WCAG's baseline bar. Cheapest fix: reuse the existing Rangoli-decal technique (`_build_rangoli_decal()`, 493-557 — a runtime-painted flat texture on a `PlaneMesh`) to stamp a small ripe-crop icon/badge (e.g. a ✓ or the crop's own emoji rendered to a decal) on `READY_TO_HARVEST` plots only. A shape-based alternative (e.g. a distinct low-poly "glow ring" mesh) also satisfies SC 1.4.1 without needing new art assets. |
| Secondary, lower-severity note: `HOST_OCCUPIED_PLOT_COLOR` (Agroforestry host-planted cells, 80) and `GHOST_PLOT_COLOR` (future-expansion placeholder tiles, 83) are likewise color-only signals on the same mesh, though both are lower-frequency/lower-stakes than the Growing-vs-Ready distinction above (host-occupied is a permanent, rarely-re-checked state; ghost tiles are non-interactive placeholders players see rarely). | SC 1.4.1 Use of Color | LOW | Worth folding into the same decal-badge fix above if/when it's built, not worth a separate task on its own. |

**Status (BLOCKING row):** ✅ Fixed 2026-08-21 (see Remediation Log). LOW row remains open.

---

## 4. Village Board — Touch/Gesture Input (`godot/scripts/village_board/board_interactor.gd`)

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| `TAP_MAX_MOVEMENT_PX = 24.0` (line 51) and `LONG_PRESS_SECONDS = 0.45` (54) are reasonable, standard values — not flagged. No action required. | — | — | — |
| **Camera zoom is reachable only via two-finger pinch** (`_begin_pinch()`/`_update_pinch()`, 328-356) on the shipping (touch) input path — the `InputEventMouseButton` wheel fallback (191-196) is explicitly desktop-editor-only per this file's own header comment, not a shipped alternative. There is no single-finger/single-tap zoom-in/zoom-out control anywhere in `hud.gd`. | SC 2.5.1 Pointer Gestures | **HIGH** | Pinch-zoom is a non-essential convenience (the board is always reachable at its default framed-out view — `frame_bounds()` on load), so per SC 2.5.1 it needs a single-pointer equivalent. Add a simple +/- zoom button pair to the HUD (or to a future Settings sheet) calling `CameraRig.zoom_by()`, which already exists and is called from the desktop mouse-wheel path today — this is a small, low-risk addition since the underlying method is already proven. |
| **Repositioning a zone or decoration requires a long-press-then-precise-drag** (`_begin_zone_drag()`/`_update_zone_drag()`, 363-399; `_begin_decoration_drag()`/`_update_decoration_drag()`, 408-434) — a path-based gesture with no tap-based alternative (e.g., "select, then tap a destination tile"). | SC 2.5.1 Pointer Gestures | MEDIUM | Lower severity than the zoom finding because this is purely cosmetic/optional (village layout, not core farming gameplay) — but still a real gap for a player with a tremor or limited fine motor control who wants to rearrange their village. A "move mode" toggle (tap to arm, tap destination to commit) would satisfy this without disturbing the existing drag path for players who prefer it. |

**Status:** Open — not part of this remediation pass (HIGH/MEDIUM only, no BLOCKING findings in this section).

---

## 5. Management Sheets — Shared Modal Pattern (`godot/scripts/ui/bottom_sheet.gd` + all `*_tab.gd`)

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| **Most body/detail text across every management sheet renders at 10-14px** at the project's own pinned base resolution (`project.godot`: `viewport_width=1080`, `viewport_height=2280`, `stretch/mode="canvas_items"` — confirmed these are the true effective on-screen pixel sizes, not further scaled). This is well under this agent's own 18px-at-1080p minimum, and — per §0 — there is no scaling mechanism to compensate. Representative sizes: crop/decoration row subtitles (12px, `seed_picker.gd:152`, `decoration_picker.gd`, `agro_plant_picker.gd:163`), Mandi crop-row percentages/forecasts (12-15px), Events tier rows (12px), Polyhouse/Agroforestry/Niche chip labels (12-13px). | SC 1.4.4 Resize Text | **HIGH** | Two independent fixes needed: (1) raise the practical floor for frequently-read numeric/status text (grow times, sell prices, percentages) to 14-16px minimum even before any settings screen exists, since these are read repeatedly during core play, not decorative; (2) build the text-scale control from §0 so 200% scaling is possible at all, which today it structurally cannot be (every size is a bare integer literal, no theme/scale multiplier layer exists to hook into). |
| Rotate/Flip icon buttons in `decoration_info_card.gd` (`_make_icon_button()`, 105-109) use `custom_minimum_size = Vector2(48, 48)` — a good touch-target size, correctly sized. Contrast this against §6's `WorkerAssignmentRow` finding below, which is the outlier. | — | — | No action — cited as the correct pattern. |
| The `BottomSheet`'s backdrop-tap-to-dismiss (`bottom_sheet.gd:139-141`) only listens for `InputEventMouseButton`, relying on Godot's documented touch/mouse normalization through `gui_input` (per this file's own header comment) — verified this is long-standing stable Control behavior, not a gap. | — | — | No action. |

**Status:** Open — HIGH only, no BLOCKING findings in this section. The text-scale multiplier added for §0's fix (see Remediation Log) provides the mechanism this section's fix #2 called for; raising individual sheets' hardcoded floors is left for a follow-up pass.

---

## 6. Worker Assignment Row & Open Field Tab — Visual/Target-Size Outlier

`godot/scripts/ui/worker_assignment_row.gd` (embedded in Polyhouse/Aquaculture/Vertical-Farm/Open-Field sheets) and `godot/scripts/ui/open_field_tab.gd` are both explicitly flagged in their own header comments as using "plain default-styled Godot controls… deliberate scope boundary… matching visual styling is a follow-up polish pass, not done here."

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| Every `Label`, `Button`, and `OptionButton` in these two files has **zero font-size or font-color override** — no `_make_label_settings()`, no explicit sizing, no `custom_minimum_size` on the Assign/Unassign buttons or the character-select `OptionButton`. They inherit Godot's default theme, which (a) renders at Godot's default 16px (below this project's own 18px floor, and inconsistent with every sibling sheet), (b) has an unverified/likely-poor contrast against the same cream `SheetPanel` background documented broken in §1 (default Label font color is a light gray, not the `SOIL_BROWN_DARK` every other sheet correctly uses on that background), and (c) has no `custom_minimum_size` on its buttons, unlike every other button builder in this codebase. | SC 1.4.3 Contrast (Minimum); SC 1.4.4 Resize Text; SC 3.2.4 Consistent Identification (same "worker assignment" concept renders with a visibly different, unstyled look than every other purchasable/manageable row in the app) | **HIGH** | This is explicitly scoped as a known follow-up in the code's own comments, so it isn't a surprise — but it's a real, currently-shipping gap on 3 of 6 zone sheets (Polyhouse, Aquaculture, Vertical Farm) plus the standalone Open Field sheet. Bring it up to the same `_make_title_label()`/`_make_panel()`/button-styling pattern every sibling file already uses — this is a mechanical, low-risk change given the pattern is already proven four times over elsewhere in this same directory. |

**Status:** Open — HIGH only, no BLOCKING findings in this section. Pre-existing known follow-up, not part of this remediation pass.

---

## 7. Audio Accessibility — Deferred, Not Broken

| Finding | WCAG Criterion | Severity | Recommendation |
|---|---|---|---|
| No music, SFX, or `AudioStreamPlayer` usage exists anywhere in `godot/scripts/` (confirmed by the task brief and consistent with everything read in this audit). Separate Master/Music/SFX/Dialogue/UI volume sliders, a mono-audio option, sudden-loud-sound normalization, and visual indicators for directional/ambient sound (per this agent's own Audio Accessibility standards) are all **not applicable yet** — there is nothing to make accessible. | N/A | **DEFER** | Not a finding against today's build. Flagging as a requirement to design in *from the start* of the upcoming EPIC-M8 audio work (per this session's own stated sequence), rather than retrofitted after the fact — cheaper to build the 5-slider mixer and mono-sum option alongside the first `AudioStreamPlayer` than to add it later. Coordinate with Audio Director/Sound Designer when that epic starts. |

---

## 8. Explicitly Out of Scope for This Audit

- **Subtitles/closed captions** — skipped. No dialogue/narrative audio system exists; `GameEvent`/`push_event()` strings are already always-visible text notifications, not audio requiring captioning.
- **Gamepad remapping, controller-layout support, keyboard-navigation-alone reachability** — skipped. Confirmed via `.claude/docs/technical-preferences.md`: Input Methods = Touch, Gamepad Support = None, and desktop/mouse handling in `board_interactor.gd` is explicitly commented as "editor testing convenience only," not a shipping input path.

---

## Summary Table

| # | Area | Severity | Count | Status |
|---|---|---|---|---|
| 0 | No accessibility settings screen exists | BLOCKING | 1 (top-level) | ✅ Fixed 2026-08-21 |
| 1 | White text on cream sheet background | BLOCKING | 1 (8 call sites) | ✅ Fixed 2026-08-21 |
| 1 | White text on RIPE_GOLD active chips | BLOCKING | 1 (3 call sites) | ✅ Fixed 2026-08-21 |
| 1 | SAFFRON_DARK/FIELD_GREEN button text contrast | HIGH | 1 (7+ call sites) | ✅ Fixed 2026-08-21 (2nd pass) |
| 1 | Monsoon-active card (RIPE_GOLD.lerp) white text | HIGH | 1 | ✅ Fixed 2026-08-21 (2nd pass) -- flagged in §1's table originally but never carried into this Summary Table, so it stayed open through the first remediation round |
| 3 | Plot lifecycle Growing-vs-Ready color-only signal | BLOCKING | 1 | ✅ Fixed 2026-08-21 |
| 3 | Host-occupied/ghost color-only signal | LOW | 1 | Open |
| 4 | Pinch-only camera zoom, no single-pointer alt | HIGH | 1 | ✅ Fixed 2026-08-21 (2nd pass) |
| 4 | Long-press-drag reposition, no alt | MEDIUM | 1 | ✅ Fixed 2026-08-21 (2nd pass) |
| 5 | Sub-18px body text, no scaling mechanism | HIGH | 1 | ✅ Fixed 2026-08-21 (2nd pass) -- every call site below this project's 14px floor raised; the §0 text-scale multiplier already covered the "no scaling mechanism" half |
| 6 | WorkerAssignmentRow/OpenFieldTab unstyled outlier | HIGH | 1 | ✅ Already fixed by an earlier Track A UI-chrome pass (not this audit's remediation) -- confirmed directly in code before re-closing this row, since this doc had gone stale on it |
| 2 | Quick Nav Bar chip touch-target size | ADVISORY | 1 | Open |
| 7 | Audio accessibility | DEFER | 1 | Volume sliders (Master/Ambience/SFX/UI) now exist as of EPIC-M8's audio pass -- deferred item substantially addressed, though a dedicated re-audit of the audio system itself hasn't been done |

**Release recommendation:** All 4 BLOCKING findings and all 4 HIGH findings the user selected for this pass, plus the one MEDIUM finding, are now fixed and verified on-device (see 2026-08-21 2nd-pass Remediation Log below). Remaining LOW/ADVISORY findings are real but non-blocking -- fine to leave for a future polish pass.

---

## Remediation Log (2026-08-21)

All four BLOCKING findings were fixed the same day as the audit:

1. **§0 — No accessibility settings screen**: Added `AccessibilitySettings` (`godot/scripts/accessibility/accessibility_settings.gd`, a plain `Resource` loaded/owned by `VillageBoard` the same way it already owns `GameEconomy` -- deliberately NOT an autoload, matching this codebase's established "no autoload, no other node touches this" convention) holding `text_scale: float` (steps 1.0/1.15/1.3) and `colorblind_safe: bool`, persisted to its own `user://accessibility.tres` (separate from `save.tres` -- a player preference, not game progress, so it stays outside the save-integrity/tamper-audit surface `security-audit-2026-08-21.md` covers). Added `AccessibilitySheet` (`godot/scripts/ui/accessibility_sheet.gd` + `godot/scenes/ui/accessibility_sheet.tscn`), a `BottomSheet`-based settings screen with a text-size-cycle button and a colorblind-safe-palette toggle, reachable from a new 44×44 HUD gear-icon button (`_make_accessibility_button()`). Audio sliders intentionally deferred per §7 (no audio exists yet to control).
   - `text_scale` is wired into `hud.gd`'s own `_make_label_settings()` (`_scaled_font_size()`) -- applied to every HUD label. It takes effect the next time the HUD is built (app open / scene reload), not hot-reloaded into already-built Controls -- rebuilding five interdependent Control trees live had no on-device verification pass available this round, so the sheet says so explicitly rather than silently under-delivering. The per-sheet 12-14px floors flagged in §5 (HIGH, still open) are not yet threaded through this mechanism.
   - `colorblind_safe` DOES apply live -- toggling it calls `VillageBoard.rebuild()`, the same call every other board mutation (zone drag, decoration move) already goes through, so this reuses an already-proven code path rather than a new one.

2. **§1 — White text on cream background / gold chips**: Replaced `Color.WHITE` font colors with `SOIL_BROWN_DARK` at all 11 call sites identified in §1 (8 cream-background sites + 3 gold-chip sites), matching the pattern already used correctly in `seed_picker.gd`/`decoration_picker.gd`/`agro_plant_picker.gd`. Contrast is now ≈15:1 (cream) and ≈8.9:1 (gold chip), both well over the 4.5:1 bar. A 4th, closely-related site was found and fixed during remediation that the original audit pass hadn't caught (its text is set at runtime, not in a literal at the call site the audit read statically): `hud.gd`'s LiveOps banner (`_liveops_banner = _make_chunky_button("", RIPE_GOLD)`) had the identical white-on-RIPE_GOLD defect -- `_make_chunky_button()` gained an explicit `font_color` parameter (default `Color.WHITE`, unchanged for its `SAFFRON_DARK`/`FIELD_GREEN` callers, which is the separate still-open HIGH finding) and the banner now passes `SOIL_BROWN_DARK`.

3. **§3 — Plot lifecycle color-only signal**: Added a ready-to-harvest badge decal (`_build_ready_badge_decal()`/`_build_ready_badge_texture()`, reusing the existing `_build_rangoli_decal()` runtime-texture-paint technique) -- a warm-white disc with a dark checkmark, stamped onto `READY_TO_HARVEST` plots only, deliberately not colored with either lifecycle tint so it reads as an independent signal. Harvest-readiness is now conveyed by an added shape in addition to the existing tint, not by color alone.

4. **Colorblind-safe palette toggle**: When `AccessibilitySettings.colorblind_safe` is enabled, `PLOT_GROWING_TINT`/`PLOT_READY_TINT` swap to a blue/orange pair (`PLOT_GROWING_TINT_CB_SAFE`/`PLOT_READY_TINT_CB_SAFE` -- a hue separation that survives protanopia, deuteranopia, and tritanopia) instead of the default green/amber pair, giving a second, independent mitigation for §3 alongside the always-on badge decal.

**Verification**: a new GUT test file (`tests/unit/test_accessibility_settings.gd`, 8 tests) covers `AccessibilitySettings`' load/save round-trip and both documented fallback paths (no prefs file, corrupt/wrong-type prefs file), mirroring `test_save_system.gd`'s existing coverage shape for `SaveSystem`. Full suite re-run after these changes: **336/336 passing** (328 pre-existing + 8 new), zero regressions. `village_board.gd`'s tint/badge changes and `hud.gd`'s new button/scaling changes have no dedicated automated test, consistent with this codebase's existing precedent that scene-tree-dependent files in these two areas aren't unit-tested (see `village_board.gd`'s own header comment on why). **On-device visual verification of the new badge decal, gear button, and settings sheet has NOT been performed this round** (no emulator was available in this session) -- recommended as a follow-up before considering this remediation fully closed, same as any other visual/feel change in this project's testing standards. HIGH/MEDIUM/LOW/ADVISORY findings above remain open and are recommended for a dedicated follow-up pass.

## Remediation Log (2026-08-21, 2nd pass) -- the 4 HIGH + 1 MEDIUM findings the user selected

Before touching anything, re-verified every item in the Summary Table directly
against current code rather than trusting the table as-is -- it had gone
stale on one row (WorkerAssignmentRow/OpenFieldTab were already fixed by an
intervening Track A UI-chrome pass this document never knew about) and was
missing one real, still-open finding entirely (the Monsoon-active card's
white-on-gold text, flagged in §1's own detailed table but never carried
into the Summary Table in the first remediation round).

1. **§1 -- SAFFRON_DARK/FIELD_GREEN button text contrast**: every consumer of
   both colors is a `UiTheme.make_chunky_button()` background (confirmed via
   a full-codebase grep before touching anything) except one non-text border
   use in `polyhouse_tab.gd`, so the two base constants in `ui_theme.gd` were
   darkened directly rather than introducing new "_TEXT" variants:
   `#C56A00` -> `#A75A00` (white-text contrast 3.85:1 -> 5.11:1) and
   `#4CAF50` -> `#39833C` (3.10:1 -> 4.68:1), both computed via the real WCAG
   relative-luminance formula, not eyeballed. Both now clear 4.5:1 with real
   margin. Same pass also fixed the Monsoon-active card
   (`events_tab.gd`'s `RIPE_GOLD.lerp(WOOD_BROWN_LIGHT, 0.5)` background,
   ~3.03:1) by swapping its text to `SOIL_BROWN_DARK` while active -- the
   same fix already applied to every other RIPE_GOLD-family active state
   elsewhere in this codebase, just never reached this one card.

2. **§4 -- pinch-only camera zoom**: added a +/-  button pair to the HUD's
   bottom-right corner (`UiTheme.make_circular_emoji_button()`, 44px,
   satisfying §2's separate touch-target ADVISORY at the same time), calling
   `CameraRig.zoom_by()` with the exact same 1.1x factor the existing
   desktop-only mouse-wheel path already used -- one tap now delivers the
   same zoom step one scroll-wheel notch always did.

3. **§5 -- sub-18px body text**: every font-size literal below this
   project's 14px floor was raised to 14px, across 9 files and roughly two
   dozen call sites (`accessibility_sheet.gd`, `agro_plant_picker.gd`, `agroforestry_tab.gd`,
   `events_tab.gd`, `farmhouse_tab.gd`, `hud.gd`, `mandi_tab.gd`,
   `niche_farming_tab.gd`, `polyhouse_tab.gd`, `seed_picker.gd`) -- found via
   3 successive grep passes of increasing precision, since several call
   sites span multiple lines (embedded `%`-format commas break a naive
   single-line regex) and were missed by the first two passes. The §0
   text-scale multiplier this table's own §5 row called for already
   existed from the first remediation round.

4. **§4 -- long-press-drag reposition, no tap alternative**: added a
   universal "Move" toggle button (📍, next to the zoom buttons) rather than
   editing every management sheet -- `board_interactor.gd` gained a 2-step
   "pick, then place" tap sequence (`set_move_mode_active()`/
   `_handle_move_mode_tap()`), generalizing the existing one-shot
   `_armed_decoration_type` pattern (already used for placing *new*
   decorations) to a 2-tap pick-then-place sequence for *repositioning*
   an existing zone or decoration. Reuses the exact same commit paths
   long-press-drag already used (`try_commit_zone_move()`'s bounds/overlap
   validation for zones -- computed via the same origin-delta math
   `_commit_zone_drag()` uses, just anchored on the zone's current center
   instead of a drag-start snapshot; `commit_decoration_move()`'s
   always-succeeds behavior for decorations), so no new validation logic
   was invented. Mutually exclusive with decoration-placement mode and
   with starting a long-press-drag (both explicitly guarded against).

**Independently verified on-device** (emulator, fresh debug build with all
of today's commits) rather than trusting the diffs alone -- screenshots in
`production/qa/evidence/a11y-fix*.png`:
- Fix 1: cropped/zoomed the Sell All and Field Worker buttons -- both
  visibly darker with clearly legible white text.
- Fix 2: cropped/zoomed the new button stack (confirmed the 📍 glyph
  rendered correctly, not a missing-glyph box); functionally confirmed by
  tapping zoom-in 5x and comparing screenshots -- the board's on-screen
  scale visibly increased.
- Fix 3: opened the Farmhouse sheet (3 of the raised-to-14px stat lines)
  and confirmed no text overflow/clipping/wrapping regression from the
  size bump.
- Fix 4: armed move mode, tapped the Farmhouse zone (confirmed the
  selection highlight applied, same as long-press-drag's own feedback),
  tapped an invalid destination first (confirmed via logcat the
  bounds/overlap validation correctly fired and reverted, matching
  long-press-drag's existing revert behavior on a bad drop -- not a
  silent failure), then re-armed and tapped a valid nearby destination
  (confirmed the Farmhouse genuinely relocated on the board).

**Full GUT suite re-run 3 times across this pass**: 360/360 passing,
unchanged from before this pass started (these are all scene-tree-dependent
UI/interaction files, none of which carry dedicated unit tests per this
codebase's existing convention -- see `village_board.gd`'s own header
comment on why). One unrelated, pre-existing flaky test was noticed
(`test_resolve_worker_actions_charges_the_wage`, an intermittent off-by-1
failure with no connection to anything touched this pass -- confirmed by
re-running 2 more times, both clean) -- flagged here rather than silently
ignored, but not investigated further as out of scope for this pass.

**Remaining open, non-blocking**: §3's LOW host-occupied/ghost color-only
signal, §2's ADVISORY Quick Nav Bar touch-target size. §7's audio
accessibility is substantially addressed (4 volume sliders now exist) but
hasn't had its own dedicated re-audit pass.
