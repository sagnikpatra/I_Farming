# UI & 3D Board Visual Direction — 2026-08

Status: **Approved direction** (2026-08-21). **Track A (UI Chrome) is now
implemented** — see `godot/scripts/ui/ui_theme.gd` (Fantasy UI Borders +
UI Pack: RPG Expansion textures, Fredoka font, designed icon set, gutters,
disabled-button states all live) — this doc's original "implementation not
yet started" applied only briefly; do not treat Track A as still-open.
**Update (2026-08-23)**: user directive elevates lighting from Track B's
original "optional, low-priority" framing to a **main focus, alongside
design and UI, explicitly benchmarked against Clash of Clans (custom, not
literal-copy) aesthetics** — see §3's Lighting bullet for the resulting
on-device findings. Track B's model-variety/crop-geometry/decoration-density
items remain open, not yet started.
Owner: art-director (draft), user (decisions)
Related: `docs/architecture/adr-0001-godot-engine-migration.md`,
`docs/architecture/adr-0002-godot-language-and-save-format.md`,
`production/session-state/active.md` (EPIC-M1 root-cause-4, EPIC-M4 slices)

## Decisions (2026-08-21)

The three highest-leverage open questions from the original draft were
put to the user directly; all three went with the recommended option:

1. **UI chrome approach: Kenney CC0 texture kit** (not StyleBoxFlat-only).
   Import Kenney's **Fantasy UI Borders** (140 assets, CC0 1.0) as the base
   panel/border chrome, paired with a matching button pack (**UI Pack: RPG
   Expansion** or **UI Pack - Adventure**, both CC0) for buttons/icon
   frames. This is real integration work (texture import as
   `NinePatchRect`/`StyleBoxTexture`, on-device verification under this
   project's pinned `gl_compatibility` renderer), not just palette tuning —
   scope accordingly.
2. **Font bundling: yes.** Add one free, OFL-licensed rounded/geometric sans
   (Baloo 2 or Fredoka, both on Google Fonts) with real Bold/Regular
   weights, reversing EPIC-M0's earlier "OS-fallback only" call. **Before
   implementing**: confirm that earlier call wasn't driven by an APK-size or
   licensing concern specific to fonts (distinct from the emoji-rendering
   question it was actually about) — quick check, not expected to block.
3. **Icon language: replace emoji with a designed icon set.** Source a
   consistent CC0 icon set — check first whether the chosen Kenney UI kit(s)
   already bundle a matching icon/glyph set before sourcing a separate pack.

Two questions from the original draft remain genuinely open and are not
blocking Track A's start (see §5 for full detail, carried over unresolved):
tabbed-sheet interaction scope, and disabled-button-state inclusion in this
pass vs. tracked separately.

**Correction (2026-08-21, orchestrating session)**: the original draft's
"asset-count discrepancy" (question 4) was a false alarm from an incomplete
`Glob` search that missed nested `OBJ format/` subfolders. Verified directly:
`assets_3d/` genuinely contains all 627 documented `.obj` files
(40 + 167 + 91 + 329, exact match to `assets_3d/README.md`). What's actually
true — and already documented in `production/session-state/active.md`'s
EPIC-M1 notes — is that only a small, deliberately hand-picked subset (12
models) was ever *copied* into `godot/assets_3d/` (the directory Godot's
project actually imports from) for the early M1 fixture-driven pass. Track B
is therefore a **curate-and-copy task from an already-fully-sourced local
library**, not a from-the-internet re-sourcing pass — meaningfully lower
risk/effort than the original draft implied. This does not block Track B's
start; see §5, question 4 (now resolved).

---

## 0. Scope

This is a direction document — implementation happens in a later pass, by
`godot-specialist`/`ui-programmer` (Track A) and `technical-artist`
(Track B), per the decisions above.

Two independently-scoped tracks, kept cleanly separable:

- **Track A — UI Chrome**: HUD, BottomSheet, all `*_tab.gd` management
  sheets, pickers. **Sequenced first** (see §4).
- **Track B — 3D Board**: terrain, decoration density, zone-building
  variety, crop-plot readability. **Sequenced second**, blocked on
  resolving the asset-count discrepancy (§5, question 4).

---

## 1. Diagnosis

### 1.1 UI chrome (`production/qa/evidence/m4-farmhouse-upgraded.png` vs.
inspiration image 3)

- **Corner radius is real in code but invisible on screen.** `farmhouse_tab.gd`'s
  `_make_panel()`/`_make_chunky_button()` (and `hud.gd`'s near-identical
  copies) do call `set_corner_radius_all(12–20)`, but every card/button is a
  direct child of a full-viewport-width `VBoxContainer` with no side
  margins. A 12–20px radius on a ~2000px-wide, ~60px-tall bar reads as
  visually square — the radius is there, but at a scale where it can't be
  perceived. Image 3's panel is deliberately *inset* from the screen edges
  (visible grass/tree background around it), so its much larger radius
  relative to the panel's own width actually reads.
- **No gutters, so nothing "floats."** The bottom sheet's cream backdrop
  touches each brown card with zero margin. Result: stacked horizontal bars,
  not framed cards. Image 3 gets depth from layered insets — cream backdrop
  → gold border → wood panel → cream inner tiles/cards — at least 3 visible
  depth layers. The current sheet has one.
- **Single flat brown for every role.** Bonuses card, storage card, and the
  Upgrade CTA all use the same `WOOD_BROWN_LIGHT` fill (only the CTA differs,
  and only in the button variant, not the card). Nothing tells the eye "this
  is a stat readout" vs. "this is the button that costs money." Both
  inspiration images color-code by role (gold = currency/CTA, teal = a
  distinct button family, red = urgent/sale).
- **2px borders read as hairlines, not "carved."** What initially read as
  "thin white dividers" in the farmhouse screenshot *is* the existing
  `GOLD_LIGHT` 2px border — it's rendering, just too thin relative to panel
  size to register as an intentional border/bevel rather than a stray
  divider line. `shadow_size = 4` is also set but has nowhere to fall,
  since adjacent panels touch with no gap.
- **One emoji, no consistent icon language.** Only 🏠 appears in the
  Farmhouse sheet. Across the whole app (`hud.gd`'s 🪙⚙🎨🌾 and the seven-chip
  nav bar 🏠🌾🏚️🌳🪷🌸🏛️), every icon is a raw OS/font-fallback emoji glyph —
  `hud.gd`'s own header comment confirms there is no bundled font, so even
  these render inconsistently by device. Neither inspiration image relies on
  emoji; both use a fully custom, consistent icon set. **Resolved 2026-08-21:
  replacing with a designed icon set (see Decisions above).**
- **No true bold weight.** `hud.gd`'s `_make_title_label()` comment states
  emphasis is currently carried entirely by font size + drop shadow, not
  weight, because no font is bundled. Contributes to the "flat, thin" read
  versus image 3's chunky bold labels. **Resolved 2026-08-21: bundling a
  font (see Decisions above).**
- **No disabled-state treatment anywhere.** `farmhouse_tab.gd`'s Upgrade
  button always renders in its full-saturation CTA style regardless of
  whether the player can afford it — a secondary clarity gap worth flagging
  alongside the visual one. Still open — see §5, question 6.

### 1.2 3D board (`m1-rootcause4-shading.png`, `m4-hud-ondevice.png` vs.
inspiration images 1/2)

**Historical record — this diagnosis describes the board's state as of
2026-08-21.** Every item below has since been addressed; see §3's "DONE"
markers (added 2026-08-23) for current status and what changed. Left as-is
here rather than rewritten, since it's the record of what prompted Track B.

- **Sparse dressing even where content exists.** The board is one flat olive
  plane with a boundary fence, two real buildings (Farmhouse, Mandi), and a
  handful of crop-plot tiles — no trees, no paths, no ambient clutter. Image
  1 rings the entire plot edge with trees and mixes in water, paths, and
  background city; image 2 shows visible soil-furrow texture and readable
  individual crop stalks up close. The gap isn't the shading model (already
  deliberately toon-shaded, see below) — it's density and variety.
- **4 of 7 zones are literal flat-color cubes.** Only Farmhouse
  (`FARMHOUSE_MODEL`) and Mandi (`MANDI_MODEL`) have a real sourced Kenney
  model wired into `village_fixture_data.gd`. Polyhouse, Agroforestry,
  Aquaculture, and Vertical Farm all fall into `village_board.gd`'s
  "unlocked but no sourced model yet" branch — a `BoxMesh` tinted with the
  zone's `plinth_color`. This is exactly the teal/salmon/tan boxes visible
  in the screenshots; not a bug, but a real fidelity gap on more than half
  the zones.
- **Crop plots have no growth-stage geometry.** `CROP_PLOT` is a single
  bare-dirt model (`crops_dirtSingle.obj`); Empty/Growing/Ready states are
  communicated *only* by a flat color-tint multiply on that one mesh, plus
  an accessibility checkmark decal for Ready. There's no stalk/leaf/fruit
  silhouette change at any stage, unlike image 2's readable individual corn
  stalks and wheat sheaves.
- **Asset-count discrepancy — verified, not assumed.** `assets_3d/README.md`
  and `CLAUDE.md` both describe "627 sourced .obj/.mtl models" across four
  Kenney kits (329 + 91 + 40 + 167). Only **12 `.obj` files total** exist on
  disk in this checkout — 7 in `nature-kit/`, 2 in `city-kit-suburban/`, 3 in
  `fantasy-town-kit/` — and `graveyard-kit/` doesn't exist on disk at all.
  Every model path referenced by `village_fixture_data.gd` does resolve to a
  real file, but the much larger "already sourced, just needs deploying"
  pool the README implies is not actually available in this environment.
  This materially changes what Track B can promise without a re-sourcing
  pass — see §5, question 4 (unresolved, blocks Track B).
- **Toon shading (EPIC-M1 root cause #4) is already correct and should be
  kept as-is**, not redone. `_apply_toon_shading()`'s 2-band diffuse ramp +
  disabled specular is a legitimate, deliberate stylization choice, verified
  against the pinned 4.7.1 `gl_compatibility` build. The diagnosis here is
  variety/density on top of that shading, not the shading itself.

---

## 2. UI Chrome Direction (Track A)

### 2.1 Palette (hex)

Keep the existing warm Indian-farm brand palette (already ported verbatim
from the old Kotlin `Color.kt` and reused across `hud.gd`/`farmhouse_tab.gd`/
`polyhouse_tab.gd` etc. — no reason to re-invent it), extended with a few
additions to support role-based color-coding and a real inset backdrop:

| Token | Hex | Role | Status |
|---|---|---|---|
| `SOIL_BROWN_DARK` | `#3E2412` | Outer borders, shadows, primary text-on-cream | existing |
| `WOOD_BROWN_MID` | `#8A5A34` | Card fills (info/stat cards) | existing (`WOOD_BROWN_LIGHT`, renamed for clarity now that a true light tone is added) |
| `WOOD_BROWN_LIGHT` (new) | `#A9713F` | Inner bevel highlight (top-left edge of a card, 1px) | new |
| `GOLD_LIGHT` | `#FFE082` | Borders / unlocked-state accents | existing |
| `RIPE_GOLD` | `#FFC107` | Primary CTA fill (Upgrade, Plant, Buy) | existing |
| `SAFFRON_DARK` | `#C56A00` | Secondary action fill (Sell All, nav accents) | existing |
| `FIELD_GREEN` | `#4CAF50` | Worker/planting-family actions | existing |
| `CREAM_BACKDROP` (new) | `#FFF3DA` | Sheet body background — cards sit *on* this, not flush against it | new — formalizes the sheet's existing near-cream bg as a named token |
| `LEVEL_BADGE_BLUE` | `#1976D2` | Level badge only | existing, unchanged |

No new hues invented — this is a role clarification of what's already there
plus one new inner-bevel tone and one named backdrop tone. **Once the Kenney
texture kit is integrated (§2.6), this palette becomes the tint/accent
reference for recoloring/selecting kit variants, not a from-scratch
`StyleBoxFlat` spec** — the kit's own painted wood-tone becomes the base,
this table guides which variant/tint to pick per role.

### 2.2 Panel treatment

- **Gutters, finally.** Every sheet's content column gets a fixed
  16–20px side margin (`MarginContainer` inside `ContentSlot`, or padding on
  `_body`) so cards visibly float on `CREAM_BACKDROP` instead of touching
  both screen edges.
- **Corner radius, scaled to the element, not a flat constant.** Full-bleed
  containers are gone (see gutters above), so a real radius reads: 16–18px
  on cards/rows, 24–28px on the sheet's own top-left/top-right corners
  (bottom stays square, sheet slides up from the screen edge), 50%
  (`diameter/2`) on all circular icon buttons — unchanged from today's
  circular treatment, which already works fine at that scale.
- **With the Kenney kit (§2.6 decision), panel "radius/border/bevel" is
  provided by the imported 9-slice texture itself** — the corner-radius/
  border-width numbers above become the *fallback* spec for any element the
  kit doesn't cover (e.g. small inline chips), not the primary mechanism for
  every panel.
- **Shadow, now with somewhere to land.** `shadow_size` 6–8px,
  `shadow_color` alpha 0.35–0.4, offset `(0, 3)`. With gutters in place this
  adds real depth even for non-kit-covered elements.

### 2.3 Tabs / pills

Image 3's pill-tab row (资源/工具/任务) has no direct counterpart in the
current app — every `*_tab.gd` sheet today is single-purpose, not
internally multi-section. Pill treatment: pill shape
(`corner_radius = height / 2`), active tab in `RIPE_GOLD` +
`SOIL_BROWN_DARK` text, inactive tabs in `WOOD_BROWN_MID` + white text at
70% alpha — or the Kenney kit's own tab/pill sprite if it includes one.
Specified now so it's ready if a sheet needs it; **whether any sheet
actually gains internal tabs remains open — see §5, question 5.**

### 2.4 Button states

| State | Treatment |
|---|---|
| Default | Kit sprite (or fallback fill = role color; border `SOIL_BROWN_DARK` 3px; shadow 6px, offset `(0,3)`) |
| Pressed | Kit's pressed-state sprite if provided, else fill darkened ~15%, shadow reduced to 2px offset `(0,1)` |
| Disabled | Kit's disabled-state sprite if provided, else fill desaturated ~40% opacity, border at 40% alpha, no shadow, font 50% alpha. **Currently does not exist anywhere in the codebase** — still open whether to include in this pass, see §5, question 6. |
| Hover | Same as default (touch-only platform; low priority) |

### 2.5 Icon-button chrome

Circular, 56–64px diameter (the existing Shop button's 64px is already
right; bump the smaller ones — accessibility gear is 44px today — up to at
least 56px for visual consistency, still comfortably above touch-target
minimums). **Resolved 2026-08-21**: icon glyphs come from a designed CC0
icon set (check the chosen Kenney kit(s) for a bundled matching set first,
per the Decisions section, before sourcing separately) rather than emoji.

### 2.6 UI chrome approach — RESOLVED 2026-08-21: Kenney CC0 texture kit

Confirmed via web search: [Fantasy UI Borders](https://kenney.nl/assets/fantasy-ui-borders)
— 140 assets, CC0 1.0, explicitly built as 9-slice sprites for
fantasy/RPG window and dialog chrome (i.e., exactly image 3's genre).
[UI Pack: RPG Expansion](https://kenney.nl/assets/ui-pack-rpg-expansion)
(85 assets, CC0) and [UI Pack - Adventure](https://kenney.nl/assets/ui-pack-adventure)
(130 assets, CC0) are candidates for buttons/icon frames in the same visual
family. All CC0, matching this project's existing Kenney-sourcing
convention (`assets_3d/README.md` already sources 4 other Kenney kits) and
the explicit free/open-source-only constraint.

Delivers the carved-wood/gold-inlay/ornamental-corner look authentically —
this is the asset category built for exactly that aesthetic. Panels,
buttons, and tabs come from one coherent family, guaranteed consistent
rather than independently hand-tuned. May include a matching icon glyph set
(check before sourcing icons separately, per §2.5).

**Implementation scope note (not a palette-tuning task)**: a curation pass
to pick specific 9-slice panel/button sprites, import as Godot
`NinePatchRect`/`StyleBoxTexture` resources, and an explicit on-device
verification pass under `gl_compatibility` — 2D `NinePatchRect` rendering is
standard Canvas rendering and should be unaffected by the 3D renderer
choice, but per this project's HIGH-knowledge-risk Godot 4.7.1 pin
(`docs/engine-reference/godot/VERSION.md`), this needs on-device
confirmation, not just an assumption. Small but nonzero APK size increase.
Needs `technical-artist`/`godot-specialist` integration time.

### 2.7 Typography — RESOLVED 2026-08-21: bundle a font

Bundle one free, OFL-licensed rounded/geometric sans — **Baloo 2** or
**Fredoka**, both on Google Fonts, both OFL, compatible with the
free/open-source-only constraint — with a genuine Bold weight for
headers/CTAs and Regular for body text. **Before implementing, confirm**
EPIC-M0's original "no bundled fonts" call wasn't driven by an APK-size or
licensing concern specific to fonts themselves (as opposed to the
emoji-rendering question it was actually answering) — quick check, not
expected to block, but worth 5 minutes before treating this as settled.

Sizing: headers 20–24px, card titles 15–16px, body/stat rows 13–14px
minimum (this floor already matches an existing open finding in this
codebase's own accessibility audit — not a new number invented here), CTA
button label 15–16px bold.

---

## 3. 3D Board Art Direction (Track B)

Everything here builds on EPIC-M1 root cause #4 (toon shading, base palette)
— **kept exactly as-is**, not redone. The push is density/variety on top of
it. **Not blocked** — per the correction above, the full 627-model library
already exists at `assets_3d/`; the items below are a curate-and-copy task
into `godot/assets_3d/`, not a from-the-internet sourcing pass.

- **Terrain texture — DONE.** `_build_terrain_texture()` generates a
  procedural furrow/soil-speckle albedo texture at runtime via
  `Image`/`ImageTexture` (same technique as the rangoli/ready-badge decals),
  wired to the ground `PlaneMesh`. Landed in commit `4f36cdd` ("Indian-theme
  the village board"), predating this doc's most recent update.
- **Zone building variety — DONE (verified 2026-08-23 by reading
  `village_fixture_data.gd`/`village_board.gd` directly, not assumed from
  this doc).** `AQUACULTURE_MODEL` (watermill), `VERTICAL_FARM_MODEL`
  (windmill), and `AGROFORESTRY_MODEL` (hedge-large) are all wired and in
  use; Mandi (`MANDI_MODEL`) was already done. Polyhouse's translucent-glass
  interim (`use_translucent_placeholder` + `POLYHOUSE_GLASS_ALPHA`) is
  implemented exactly as recommended below — a locked zone still renders as
  a dim ghost box (`LOCKED_ZONE_PLACEHOLDER_COLOR`), which is a deliberate,
  separate visual state, not a leftover placeholder bug.
- **Crop plot readability — DONE for the crops that have a genuine model
  fit, and deliberately NOT force-fit for the rest.**
  `VillageFixtureData.crop_stage_model_path()` gives Wheat real
  Growing/Ready stage geometry (`crops_wheatStageA`/`B`) and Tomato/Capsicum
  a shared leafy stand-in (`crops_leafsStageA`/`B`). Paddy, Dutch Rose,
  Sandalwood, Makhana, Pond Fish, and Saffron are **deliberately** left
  unmapped (return `""`, falling back to the dirt-mesh+tint rendering) —
  confirmed via `tests/unit/test_village_fixture_data.gd`'s
  `test_crops_with_no_reasonable_model_fit_return_empty_string()`, which
  exists specifically to catch a future regression that force-fits a
  bad-match model (e.g. a generic tree standing in for a sandalwood
  sapling, or corn stalks standing in for rice paddy) onto one of these.
  Closing this the "honest" way needs genuine new asset sourcing (a rice
  paddy, a sandalwood sapling, a saffron crocus) — out of scope for a
  curate-from-what's-already-sourced pass; tracked here as a real, open,
  future re-sourcing item, not a wiring gap.
- **Decoration density — DONE.** `TREE_RING_MODELS` (tree_default/tree_fat/
  tree_oak) ring the boundary fence, `AMBIENT_CLUTTER_MODELS` scatter
  bush/rock variety across the field, and `DECORATION_DIRT_PATH_MODEL` lays
  a default path — all confirmed wired in `village_board.gd` and visible
  on-device (see `board_review.png`-class evidence from the 2026-08-23
  lighting-pass session). Only `flower_yellowA` originally existed on disk;
  `flower_yellowB`/`flower_yellowC` were added since and are wired too
  (`DECORATION_SUNFLOWER_MODEL_B`/`_C`).
- **Lighting — elevated to a main focus (2026-08-23 user directive: "design,
  UI and lightings, just like COC, custom").** On-device empirical pass
  completed against `village_board.tscn`'s `WorldEnvironment`:
  - **`Environment.glow_enabled` is unsafe on this project's pinned
    `gl_compatibility` renderer** — breaks the entire scene into a garish,
    blown-out blue even at conservative settings. Confirmed root cause via
    isolated on-device testing; full writeup in
    `docs/engine-reference/godot/breaking-changes.md`'s "Project-Specific
    Findings" section. Do not re-attempt glow without a fresh isolation
    test.
  - **`adjustment_enabled` (brightness 1.0, contrast 1.03, saturation 1.06)
    confirmed safe and shipped** — a modest global color-grade multiply,
    tested clean on-device at Night phase (the darker, more failure-prone
    end of the day/night range) and via the full GUT suite (632/632, twice).
    Landed in `village_board.tscn`.
  - **Still open, not yet attempted**: the original warmer-directional-light
    color-temperature idea (for golden-hour COC-style warmth) and any
    per-phase (`time_of_day.gd` preset) tuning beyond the current
    Dawn/Day/Dusk/Night values — glow being unsafe removes the most
    COC-typical "premium bloom" tool from consideration, so remaining
    lighting polish likely comes from `DirectionalLight3D` color/energy
    tuning and `Environment.ambient_light_*` values instead, evaluated the
    same on-device-isolation way.

---

## 4. Sequencing Recommendation

**Update (2026-08-23): both tracks below are now substantially complete** —
Track A per its own header note, Track B per §3's "DONE" markers. This
section is kept as the historical rationale for why A went first, not as an
indication either track is still pending.

1. **UI chrome first (Track A).** Self-contained — touches only
   `godot/scripts/ui/*.gd` plus the Kenney texture import. No 3D-board or
   economy-logic dependency. Highest visual-impact-per-effort: every one of
   the 9 management/picker sheets funnels through the same
   `_make_panel()`/`_make_chunky_button()`-style helpers, so fixing those
   shared helpers once cascades everywhere. Worth noting while scoping this:
   `farmhouse_tab.gd` and `hud.gd` currently hand-roll *identical* copies of
   `_make_panel()`/`_make_chunky_button()`/`_make_title_label()`/
   `_make_label_settings()` — consolidating these into one shared script or
   a real Godot `Theme` resource is a natural "while you're in there"
   cleanup for whichever specialist implements this, not new scope creep.
2. **3D board push second (Track B).** Curation-heavy (from an already-
   fully-sourced local library — see correction above, not from-the-internet
   sourcing) — likely a couple hours of `technical-artist`/art-director
   selection-and-copy work before any `.gd` changes. Lower urgency than the
   UI chrome gap given the original ask was a direct reaction to the UI
   screenshots specifically, and the board's shading pass is already a
   deliberate, tuned decision rather than naive placeholder.

---

## 5. Open Questions

Four of the original six are resolved (see Decisions, top of document, and
the asset-count correction above). Two remain genuinely open:

5. **Tabbed-sheet scope** — image 3's pill-tab pattern doesn't map onto any
   current `*_tab.gd` sheet (each is single-purpose today). Is combining
   sheets into internally-tabbed panels an actual goal, or should §2.3's
   pill styling just be banked for future use without new tab-switching
   interaction work (`ux-designer` scope either way)? **Does not block
   Track A start** — can be decided during or after initial implementation.
6. **Disabled-button state** — fold into this visual pass, or track
   separately as a gameplay-clarity fix rather than pure art direction?
   Missing today (`farmhouse_tab.gd`'s Upgrade button always renders
   full-saturation regardless of affordability) — real but small, doesn't
   block Track A start either way.
