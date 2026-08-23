## Shared UI chrome/theme helper library -- consolidates the panel/button/
## label construction helpers that were previously hand-rolled, nearly
## identically, in hud.gd, farmhouse_tab.gd, mandi_tab.gd, polyhouse_tab.gd,
## agroforestry_tab.gd, niche_farming_tab.gd, events_tab.gd, and
## accessibility_sheet.gd. Flagged explicitly in
## design/art/ui-visual-direction-2026-08.md (Track A, §4): "farmhouse_tab.gd
## and hud.gd currently hand-roll IDENTICAL copies of _make_panel()/
## _make_chunky_button()/_make_title_label()/_make_label_settings() --
## consolidating these into one shared script... is a natural 'while you're
## in there' cleanup."
##
## Static-method helper library (`class_name UiTheme`, no instance state,
## no .tscn) -- matches this project's existing "helpers in GDScript, no
## authored Theme resource" convention (see hud.gd's own class doc for why
## procedural construction was chosen over a hand-typed .tscn tree). A real
## Godot `Theme` resource was considered and rejected: every control in this
## project is built procedurally in code from data (not from an
## editor-authored scene tree), so a Theme's per-control-type override
## lookup buys little over calling one shared constructor function
## directly -- and per-role StyleBoxTexture tinting (see
## _tinted_stylebox_texture() below) is far more explicit as a function
## parameter than as a Theme variation name threaded through every call
## site. Every existing `*_tab.gd`/`*_picker.gd`/`*_card.gd`/`*_row.gd` file
## keeps its own thin `_make_panel()`/`_make_chunky_button()`/
## `_make_title_label()`/`_make_label_settings()` wrappers (unchanged call
## sites throughout each file) that now just delegate to this class's
## `make_*()` equivalents -- lowest-risk migration path for a mechanical,
## multi-file consolidation: one line changed per wrapper, zero call sites
## touched.
##
## CHROME SOURCE (design/art/ui-visual-direction-2026-08.md §2.6): a curated
## subset of two Kenney CC0 kits, copied into res://assets/ui/ (full kits
## live at assets_ui/ at the repo root -- source material, not imported, same
## convention as assets_3d/README.md's "full kit at repo root, curated
## subset copied into godot/"):
## - Fantasy UI Borders (`assets_ui/fantasy-ui-borders/`): panel_fill.png /
##   panel_fill_ornate.png / panel_border.png -- these are white silhouette
##   MASKS (1-bit source art), not pre-painted textures. That is exploited
##   deliberately: StyleBoxTexture.modulate_color tints a white mask to any
##   palette role color, which is what makes the doc's "gold = CTA / teal =
##   worker family / red = urgent" role-coding (§2.1) possible from a SINGLE
##   sourced asset rather than needing one pre-painted variant per role.
## - UI Pack: RPG Expansion (`assets_ui/ui-pack-rpg-expansion/`):
##   button_long*.png / button_round*.png. Two pre-painted families were
##   kept: "brown" (used AS-IS, untinted, for the neutral/wood-toned default
##   button role) and "grey" (a near-white neutral base, used as the
##   tintable mask for every role-colored button -- multiply-tinting the
##   already-brown "brown" family toward e.g. RIPE_GOLD or FIELD_GREEN
##   produces a muddy result since modulate multiplies against a non-white
##   base; "grey" avoids that the same way the Fantasy UI Borders masks do).
##
## texture_margin_* values below are a curation judgment call, not measured
## from the source art pixel-by-pixel (Kenney ships no metadata for exact
## 9-slice insets) -- verified visually via the Track A on-device screenshot
## pass, not assumed correct a priori, per this project's "verify on-device,
## don't assume" standard for anything touching the pinned 4.7.1
## `gl_compatibility` renderer.
class_name UiTheme
extends RefCounted

# ---------------------------------------------------------------------------
# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt (see hud.gd's original copy of this same block). Now the
# ONE place this palette is defined; every sheet's local `const SOIL_BROWN_
# DARK := Color("#3E2412")`-style block becomes `const SOIL_BROWN_DARK :=
# UiTheme.SOIL_BROWN_DARK` (kept as local aliases, not a search-and-replace
# of every call site, per this file's class doc). WOOD_BROWN_LIGHT and
# CREAM_BACKDROP are new per design/art/ui-visual-direction-2026-08.md §2.1
# (WOOD_BROWN_MID is that doc's rename of the old WOOD_BROWN_LIGHT token --
# both names are kept here, WOOD_BROWN_MID as the canonical name and
# WOOD_BROWN_LIGHT re-pointed to the NEW #A9713F bevel-highlight tone, so
# every existing call site that still says `WOOD_BROWN_LIGHT` for a card
# fill continues to resolve to a real, still-correct-looking color rather
# than silently breaking).
# ---------------------------------------------------------------------------
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_MID := Color("#8A5A34")
## New per §2.1 -- inner bevel highlight tone. Existing call sites that pass
## the OLD `WOOD_BROWN_LIGHT` name for a card fill (i.e. every pre-Track-A
## `_make_panel(WOOD_BROWN_LIGHT, ...)` call) now render with this lighter
## tone rather than WOOD_BROWN_MID -- a deliberate, visible-on-screen
## consequence of the doc's rename, not a silent behavior change to paper
## over (see the doc's own palette table).
const WOOD_BROWN_LIGHT := Color("#A9713F")
const GOLD_LIGHT := Color("#FFE082")
const RIPE_GOLD := Color("#FFC107")
## Accessibility fix (production/qa/accessibility/village-board-and-management-
## sheets-audit-2026-08-21.md §1, HIGH): both colors darkened from their
## original #C56A00/#4CAF50 specifically to clear SC 1.4.3's 4.5:1 contrast
## bar for white button-label text at these buttons' actual 15px font size
## (the audit's own "darken ~10-15% luminance" recommendation, not the
## alternative "bump to 18px large-text" option -- every consumer of these
## two constants is a _make_chunky_button() background per this file's own
## grep, so a shared, silent brand-identity shift here is lower-risk than
## a per-call-site font-size bump that would visually diverge from every
## other 15px chunky button in the app). Measured (WCAG relative-luminance
## formula): SAFFRON_DARK white-text contrast 3.85:1 -> 5.11:1; FIELD_GREEN
## 3.10:1 -> 4.68:1. Both now clear 4.5:1 with real margin, not just barely.
const SAFFRON_DARK := Color("#A75A00")
const FIELD_GREEN := Color("#39833C")
const CREAM_BACKDROP := Color("#FFF3DA")
const LEVEL_BADGE_BLUE := Color("#1976D2")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const UNAFFORDABLE_ALPHA: float = 0.4

## Global visual scale -- found 2026-08-23 from a direct user report
## ("need to zoom a lot to see the options"). Root cause: project.godot's
## viewport is a raw 1080px-wide canvas_items-stretch canvas, but every
## literal size in this file (and every *_tab.gd/*_picker.gd/*_row.gd call
## site) was authored assuming a ~360-420dp LOGICAL width -- the unit the
## pre-migration Kotlin/Compose app's sp/dp values used, carried over
## directly as raw px during the Godot port with no conversion. A typical
## real device in this project's own tested class (technical-preferences.md:
## OnePlus OPD2403) is ~411dp logical width at ~2.625x density, i.e. 1 of
## this codebase's "dp-shaped" units is only ~1080/411 =~ 2.6 raw canvas
## pixels wide on screen -- so every font/button/icon rendered at roughly a
## third of its intended size. This is the ONE place that conversion
## happens: every make_*() helper below multiplies its caller's existing
## "logical" size argument (unchanged call sites -- e.g. `48` for a button
## height, `15` for a button label, exactly as before) by UI_SCALE before
## applying it to a real Control. A file that sets a size directly instead
## of through a make_*() helper should wrap its own literal with
## scale_px()/scale_font() below, not hardcode a second factor.
##
## 2.6 chosen from the device-density math above, not an arbitrary "make it
## bigger" guess -- verified on-device (real hardware) after landing this
## change, per this project's standard practice for anything touching the
## pinned engine's actual rendering.
const UI_SCALE: float = 2.6

## §2.2: "Every sheet's content column gets a fixed 16-20px side margin...
## so cards visibly float on CREAM_BACKDROP." Applied at bottom_sheet.tscn's
## shared ContentSlot MarginContainer (one edit point, cascades to all 9
## management/picker sheets), not per-sheet. Pre-scaled directly (20 * 2.6 =
## 52) rather than computed at load time -- GDScript const initializers must
## be constant-foldable, and this keeps the const's declared value exact and
## grep-able rather than an expression.
const GUTTER_MARGIN: int = 52


## Converts one of this file's own "logical" pixel values (a diameter,
## height, margin -- anything that ISN'T a font size, see scale_font() for
## those) to the real canvas pixel size, per UI_SCALE's doc comment above.
## Exposed for the handful of *_tab.gd/*_picker.gd/*_row.gd call sites that
## build a Control's custom_minimum_size directly instead of going through
## a make_*() helper (worker_assignment_row.gd's OptionButton, the picker
## rows' custom_minimum_size, etc.) -- keeps them on the same one scale
## factor rather than inventing their own.
static func scale_px(logical_px: float) -> int:
	return roundi(logical_px * UI_SCALE)


## Same conversion, named separately from scale_px() only so a call site
## reads self-documenting about which kind of literal it's scaling (a font
## size vs. a layout dimension) -- both currently do the same multiply.
static func scale_font(logical_px: int) -> int:
	return roundi(float(logical_px) * UI_SCALE)

# ---------------------------------------------------------------------------
# Curated texture assets (see class doc for sourcing/curation rationale).
# ---------------------------------------------------------------------------
const PANEL_FILL_TEXTURE: Texture2D = preload("res://assets/ui/panels/panel_fill.png")
const PANEL_FILL_ORNATE_TEXTURE: Texture2D = preload("res://assets/ui/panels/panel_fill_ornate.png")
const BUTTON_LONG_BROWN_TEXTURE: Texture2D = preload("res://assets/ui/buttons/button_long.png")
const BUTTON_LONG_BROWN_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/buttons/button_long_pressed.png")
const BUTTON_LONG_GREY_TEXTURE: Texture2D = preload("res://assets/ui/buttons/button_long_grey.png")
const BUTTON_LONG_GREY_PRESSED_TEXTURE: Texture2D = preload("res://assets/ui/buttons/button_long_grey_pressed.png")
const BUTTON_ROUND_GREY_TEXTURE: Texture2D = preload("res://assets/ui/buttons/button_round_grey.png")

const ICON_HOME: Texture2D = preload("res://assets/ui/icons/icon_home.png")
const ICON_GEAR: Texture2D = preload("res://assets/ui/icons/icon_gear.png")
const ICON_CART: Texture2D = preload("res://assets/ui/icons/icon_cart.png")
const ICON_CHECKMARK: Texture2D = preload("res://assets/ui/icons/icon_checkmark.png")
const ICON_LOCKED: Texture2D = preload("res://assets/ui/icons/icon_locked.png")
const ICON_AUDIO_ON: Texture2D = preload("res://assets/ui/icons/icon_audio_on.png")
const ICON_AUDIO_OFF: Texture2D = preload("res://assets/ui/icons/icon_audio_off.png")

## §2.7: Fredoka (OFL-licensed, Google Fonts), variable font -- Bold/
## SemiBold/Regular are FontVariation "wght"-axis instances of this ONE
## imported FontFile, not separate font files (a variable font ships every
## weight in one binary; this project only bundles the one .ttf).
const FREDOKA_FONT: FontFile = preload("res://assets/fonts/fredoka/Fredoka-Variable.ttf")

static var _font_bold_cache: FontVariation
static var _font_semibold_cache: FontVariation
static var _font_regular_cache: FontVariation


## Headers, card titles, CTA button labels -- §2.7's "genuine Bold weight
## for headers/CTAs". Cached (static var, Godot 4.2+) since FontVariation is
## a Resource and every label on a sheet would otherwise construct an
## identical one.
static func font_bold() -> FontVariation:
	if _font_bold_cache == null:
		_font_bold_cache = FontVariation.new()
		_font_bold_cache.base_font = FREDOKA_FONT
		_font_bold_cache.variation_opentype = {"wght": 700}
	return _font_bold_cache


static func font_semibold() -> FontVariation:
	if _font_semibold_cache == null:
		_font_semibold_cache = FontVariation.new()
		_font_semibold_cache.base_font = FREDOKA_FONT
		_font_semibold_cache.variation_opentype = {"wght": 600}
	return _font_semibold_cache


## Body/stat-row text -- §2.7's "Regular for body text".
static func font_regular() -> FontVariation:
	if _font_regular_cache == null:
		_font_regular_cache = FontVariation.new()
		_font_regular_cache.base_font = FREDOKA_FONT
		_font_regular_cache.variation_opentype = {"wght": 400}
	return _font_regular_cache


# ---------------------------------------------------------------------------
# Panels / cards
# ---------------------------------------------------------------------------

## Replaces every sheet's `_make_panel(bg_color, corner_radius, border_color)`
## StyleBoxFlat body. `corner_radius`/`border_color` are accepted and IGNORED
## (kept as params so every existing call site -- there are ~13 of them --
## needed zero changes beyond the wrapper's one-line body): per §2.2, "with
## the Kenney kit... panel radius/border/bevel is provided by the imported
## 9-slice texture itself," so a StyleBoxTexture replaces the StyleBoxFlat
## entirely rather than layering both. `role_color` tints PANEL_FILL_TEXTURE's
## white mask -- this is how "Current Bonuses" (WOOD_BROWN_MID), the Upgrade
## CTA area, etc. stay visually distinct from one shared source asset.
static func make_panel(role_color: Color, ornate: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := PANEL_FILL_ORNATE_TEXTURE if ornate else PANEL_FILL_TEXTURE
	panel.add_theme_stylebox_override("panel", _tinted_panel_stylebox(texture, role_color))
	return panel


## Circular decorative (non-interactive) panel -- level badge, etc. Same
## texture-tint strategy as make_panel(), stretched to a fixed square.
static func make_circular_panel(role_color: Color, diameter: int = 44) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scaled_diameter := scale_px(diameter)
	panel.custom_minimum_size = Vector2(scaled_diameter, scaled_diameter)
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_ROUND_GREY_TEXTURE
	style.modulate_color = role_color
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func _tinted_panel_stylebox(texture: Texture2D, role_color: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = role_color
	style.texture_margin_left = scale_px(14)
	style.texture_margin_right = scale_px(14)
	style.texture_margin_top = scale_px(14)
	style.texture_margin_bottom = scale_px(14)
	style.content_margin_left = scale_px(14)
	style.content_margin_right = scale_px(14)
	style.content_margin_top = scale_px(10)
	style.content_margin_bottom = scale_px(10)
	return style


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

## Replaces every sheet's `_make_chunky_button(label_text, color[, font_
## color])` StyleBoxFlat body. `enabled` is new -- §2.4's disabled state,
## previously absent everywhere (farmhouse_tab.gd's Upgrade button always
## rendered full-saturation regardless of affordability). When `enabled` is
## false: fill desaturated + ~40% alpha, no shadow (StyleBoxTexture has no
## shadow_size to zero out the way the old StyleBoxFlat did -- the "no
## shadow" cue instead comes from the flatter, duller disabled texture
## itself), font at 50% alpha -- matches §2.4's disabled-state spec.
static func make_chunky_button(
	label_text: String, role_color: Color, font_color: Color = Color.WHITE, enabled: bool = true
) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, scale_px(48))

	var normal_style := _tinted_button_stylebox(role_color, false, enabled)
	var pressed_style := _tinted_button_stylebox(role_color, true, enabled)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("focus", normal_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style)

	var effective_font_color := font_color if enabled else Color(font_color.r, font_color.g, font_color.b, 0.5)
	for color_slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color_slot, effective_font_color)
	button.add_theme_font_override("font", font_bold())
	button.add_theme_font_size_override("font_size", scale_font(15))
	return button


## §2.5: circular icon-button chrome, 56-64px diameter (bumped up from the
## old 44px accessibility-gear button and inconsistent per-button sizing --
## every icon button now goes through this one constructor). `icon` is
## white-on-transparent source art (game-icons kit, see class doc) tinted
## via the TextureRect's own `self_modulate` to whatever contrasts with
## `role_color`'s button base -- kept at white by default since every button
## base color in this palette is dark/mid-toned enough for white to read.
static func make_icon_button(icon: Texture2D, role_color: Color, diameter: int = 56, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	var scaled_diameter := scale_px(diameter)
	button.custom_minimum_size = Vector2(scaled_diameter, scaled_diameter)

	var style := StyleBoxTexture.new()
	style.texture = BUTTON_ROUND_GREY_TEXTURE
	style.modulate_color = role_color if enabled else Color(role_color.r, role_color.g, role_color.b, UNAFFORDABLE_ALPHA)
	style.set_content_margin_all(0)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, style)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(scaled_diameter, scaled_diameter) * 0.5
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.modulate.a = 1.0 if enabled else UNAFFORDABLE_ALPHA
	button.add_child(icon_rect)
	return button


## Circular button showing an emoji/text glyph rather than a sourced icon
## texture -- used where no Kenney/game-icons asset is a reasonable match
## (zone nav chips: farm-domain pictographs like 🌾/🪷/🌸 that no CC0 kit
## covers, see assets_ui/README.md's "no Kenney kit has farm-specific
## icons" note). Same tinted-mask chrome as make_icon_button(), just a
## Label glyph instead of a TextureRect child.
static func make_circular_emoji_button(glyph: String, role_color: Color, diameter: int = 56) -> Button:
	var button := Button.new()
	button.text = ""
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	var scaled_diameter := scale_px(diameter)
	button.custom_minimum_size = Vector2(scaled_diameter, scaled_diameter)

	var style := StyleBoxTexture.new()
	style.texture = BUTTON_ROUND_GREY_TEXTURE
	style.modulate_color = role_color
	style.set_content_margin_all(0)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)

	var glyph_label := Label.new()
	glyph_label.text = glyph
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# diameter (unscaled) * 0.32, then scaled -- matches make_label_settings()'s
	# own "font_size argument is a logical value, scaled once inside" contract
	# rather than scaling an already-scaled diameter a second time.
	glyph_label.label_settings = make_label_settings(roundi(diameter * 0.32), Color.WHITE)
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(glyph_label)
	return button


static func _tinted_button_stylebox(role_color: Color, pressed: bool, enabled: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	# WOOD_BROWN_MID keeps the kit's own painted "brown" family untinted --
	# multiply-tinting an already-brown base toward brown again would be a
	# no-op at best and muddy at worst (see class doc). Every OTHER role
	# color uses the neutral "grey" family as a tintable mask.
	if role_color.is_equal_approx(WOOD_BROWN_MID):
		style.texture = BUTTON_LONG_BROWN_PRESSED_TEXTURE if pressed else BUTTON_LONG_BROWN_TEXTURE
		style.modulate_color = Color.WHITE if enabled else Color(1, 1, 1, UNAFFORDABLE_ALPHA)
	else:
		style.texture = BUTTON_LONG_GREY_PRESSED_TEXTURE if pressed else BUTTON_LONG_GREY_TEXTURE
		style.modulate_color = role_color if enabled else Color(role_color.r, role_color.g, role_color.b, UNAFFORDABLE_ALPHA)
	style.texture_margin_left = scale_px(22)
	style.texture_margin_right = scale_px(22)
	style.texture_margin_top = scale_px(10)
	style.texture_margin_bottom = scale_px(10)
	style.content_margin_left = scale_px(18)
	style.content_margin_right = scale_px(18)
	style.content_margin_top = scale_px(10)
	style.content_margin_bottom = scale_px(10)
	return style


# ---------------------------------------------------------------------------
# Labels / typography (§2.7)
# ---------------------------------------------------------------------------

## Replaces every sheet's `_make_title_label(text, font_size[, color])`.
## `bold` selects font_bold() (headers/CTAs) vs font_regular() (body/stat
## rows) per §2.7 -- defaults true since most existing call sites are
## headers/emphasis text (the pre-Track-A version carried ALL emphasis via
## size+shadow with no real weight at all, see hud.gd's old class doc).
static func make_title_label(
	text: String, font_size: int, color: Color = Color.WHITE, bold: bool = true, accessibility_scale: float = 1.0
) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = make_label_settings(font_size, color, bold, accessibility_scale)
	return label


## For any Label that will have `autowrap_mode` set to something other than
## AUTOWRAP_OFF. Found 2026-08-23, on-device: a `LabelSettings`-styled Label
## (make_title_label()/make_label_settings() above) with autowrap enabled
## renders with visibly ghosted/doubled glyphs on this project's pinned
## gl_compatibility renderer -- confirmed via extensive on-device isolation
## (logcat-verified correct layout positions, ruled out ALIGNMENT_CENTER,
## multi-Label-stacking, the shadow effect alone, and an adjacent emoji
## sibling one at a time) that this is specifically about LabelSettings +
## autowrap together: a short LabelSettings Label with NO wrapping (e.g.
## farmhouse_tab.gd's 2-line combo header, joined by an explicit \n, no
## autowrap needed) renders clean; the exact same LabelSettings approach
## with autowrap_mode enabled on longer text does not, even with
## shadow_size forced to 0. Switching to plain Control theme property
## overrides (this function, no LabelSettings resource involved at all)
## instead of LabelSettings fixes it completely -- confirmed on-device.
## Full write-up: docs/engine-reference/godot/breaking-changes.md's
## "Project-Specific Findings" section.
##
## Trade-off: no drop-shadow (LabelSettings.shadow_* has no direct
## Control-theme-property equivalent) -- acceptable here since every
## confirmed real call site is body/description/blurb text, not a bold
## header (which stays on make_title_label(), safe without autowrap).
static func make_wrapping_label(
	text: String, font_size: int, color: Color = Color.WHITE, bold: bool = true, accessibility_scale: float = 1.0
) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_override("font", font_bold() if bold else font_regular())
	label.add_theme_font_size_override("font_size", roundi(float(font_size) * UI_SCALE * accessibility_scale))
	label.add_theme_color_override("font_color", color)
	return label


## Replaces every sheet's `_make_label_settings(font_size, color)`.
## `accessibility_scale` defaults to 1.0 (unscaled) -- preserves each
## existing call site's current behavior exactly (only hud.gd wired real
## AccessibilitySettings.text_scale before Track A; extending that to every
## sheet is a separate, already-tracked HIGH finding per hud.gd's own
## _scaled_font_size() doc comment, not silently done here as a side effect
## of this consolidation).
static func make_label_settings(
	font_size: int, color: Color, bold: bool = true, accessibility_scale: float = 1.0
) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = font_bold() if bold else font_regular()
	settings.font_size = roundi(float(font_size) * UI_SCALE * accessibility_scale)
	settings.font_color = color
	# Found 2026-08-23, on-device (zoomed screenshot of farmhouse_tab.gd's
	# non-wrapping title/bonus-list labels): scaling BOTH shadow_size (to
	# scale_px(4), ~10px) and shadow_offset (to (2,3)*UI_SCALE, ~5x8px) by
	# the full 2.6x UI_SCALE preserves the pre-scale proportion, but at that
	# absolute pixel size the shadow separates far enough from the glyph to
	# read as a second overlapping copy of the text rather than a receding
	# drop shadow -- worse against SOIL_BROWN_DARK fill, since TEXT_SHADOW_COLOR
	# is near-black and low-contrast against dark-brown text specifically.
	# Fix: scale shadow_size at half rate and shrink+square the offset so the
	# shadow stays tucked close behind the glyph at any UI_SCALE instead of
	# growing in lockstep with it. See breaking-changes.md's "Project-Specific
	# Findings" section for the full isolation writeup.
	settings.shadow_size = scale_px(2)
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(1, 1) * UI_SCALE
	return settings
