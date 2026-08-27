## design/gdd/farm-equipment.md's shop sheet -- lists all 50 FarmEquipment
## items grouped by Tier, each tappable to purchase into
## GameState.owned_equipment. Same "small static shell + procedural content"
## split as decoration_picker.gd/seed_picker.gd (see seed_picker.gd's header
## comment for the rationale) -- and closely modeled on decoration_picker.gd
## specifically, since both are "browse a catalogue, tap to buy" sheets.
##
## The one real behavioral difference from DecorationPicker: buying here is
## a direct, immediate purchase (GameEconomy.buy_equipment(kind) deducts
## coins and records ownership right on tap), not a two-step "arm placement,
## then tap the board" flow -- there's no board placement to arm yet (see
## the GDD's Acceptance Criteria on why), so there's nothing to defer.
##
## Three states a row can be in, beyond plain affordable/unaffordable:
## owned (already purchased -- shown, not re-buyable) and locked (tier not
## yet unlocked via land_expansions_bought() -- shown, but for a different
## reason than "can't afford it," so it gets its own message rather than
## just looking identical to an expensive item).
class_name EquipmentShop
extends VBoxContainer

const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const SAFFRON_DARK := UiTheme.SAFFRON_DARK
const UNAFFORDABLE_ALPHA: float = UiTheme.UNAFFORDABLE_ALPHA

## Iteration order for tier grouping -- cheapest/earliest-unlocked first, so
## the sheet reads top-to-bottom as a progression the player scrolls into as
## they expand, rather than opening on the most expensive/locked items.
const TIER_ORDER: Array[int] = [
	FarmEquipment.Tier.BASIC,
	FarmEquipment.Tier.COMMON,
	FarmEquipment.Tier.STANDARD,
	FarmEquipment.Tier.MID_RANGE,
	FarmEquipment.Tier.PREMIUM,
	FarmEquipment.Tier.LUXURY,
]

@onready var _title_label: Label = $Title
@onready var _rows_container: VBoxContainer = $Scroll/Rows

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's
## content slot -- same precondition/ordering guarantee as
## SeedPicker.configure().
func configure(economy: GameEconomy, village_board: VillageBoard) -> void:
	_economy = economy
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = tr(&"equipment_shop.title")
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	_populate()


func _populate() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	var rows := build_row_data(_economy.state.coins, _economy.state.owned_equipment, _economy.land_expansions_bought())
	for row in rows:
		if row["row_type"] == "tier_header":
			_rows_container.add_child(_build_tier_header(row))
		else:
			_rows_container.add_child(_build_item_row(row))


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_equipment_shop.gd), no
# scene-tree dependency. Not underscore-prefixed for the same reason
# decoration_picker.gd's build_row_data() isn't.
# ---------------------------------------------------------------------------

## One entry per tier header plus one per equipment item, grouped by tier in
## TIER_ORDER and, within a tier, in FarmEquipment.all_equipment()'s own
## order. A tier header carries the same locked/expansions_remaining state
## as its items (they share one threshold) so the UI can show it once at
## the group level instead of repeating it per row.
static func build_row_data(coins: int, owned_equipment: Array[int], expansions_bought: int) -> Array:
	var rows: Array = []
	for tier in TIER_ORDER:
		var tier_items: Array[int] = []
		for kind in FarmEquipment.all_equipment():
			if FarmEquipment.equipment_tier(kind) == tier:
				tier_items.append(kind)
		if tier_items.is_empty():
			continue
		var required := FarmEquipment.tier_unlock_expansions(tier)
		var remaining: int = maxi(required - expansions_bought, 0)
		var tier_locked: bool = remaining > 0
		rows.append({
			"row_type": "tier_header",
			"tier": tier,
			"locked": tier_locked,
			"expansions_remaining": remaining,
		})
		for kind in tier_items:
			rows.append({
				"row_type": "item",
				"kind": kind,
				"tier": tier,
				"owned": owned_equipment.has(kind),
				"locked": tier_locked,
				"expansions_remaining": remaining,
				"affordable": coins >= FarmEquipment.equipment_cost(kind),
			})
	return rows


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

func _build_tier_header(row: Dictionary) -> Label:
	var tier: int = row["tier"]
	var text: String = tr(_tier_name_key(tier))
	if row["locked"]:
		text += "  " + (tr(&"equipment_shop.locked_row") % row["expansions_remaining"])
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = _make_label_settings(15, SAFFRON_DARK if not row["locked"] else Color(SAFFRON_DARK.r, SAFFRON_DARK.g, SAFFRON_DARK.b, UNAFFORDABLE_ALPHA))
	return label


static func _tier_name_key(tier: int) -> StringName:
	match tier:
		FarmEquipment.Tier.LUXURY: return &"equipment_shop.tier_luxury"
		FarmEquipment.Tier.PREMIUM: return &"equipment_shop.tier_premium"
		FarmEquipment.Tier.MID_RANGE: return &"equipment_shop.tier_mid_range"
		FarmEquipment.Tier.STANDARD: return &"equipment_shop.tier_standard"
		FarmEquipment.Tier.COMMON: return &"equipment_shop.tier_common"
		_: return &"equipment_shop.tier_basic"


func _build_item_row(row: Dictionary) -> Button:
	var kind: int = row["kind"]
	var owned: bool = row["owned"]
	var locked: bool = row["locked"]
	var affordable: bool = row["affordable"]
	var buyable: bool = not owned and not locked and affordable

	var btn := Button.new()
	btn.text = ""
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not buyable
	btn.custom_minimum_size = Vector2(0, UiTheme.scale_px(56))
	var dimmed: bool = owned or locked or not affordable
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WOOD_BROWN_LIGHT.r, WOOD_BROWN_LIGHT.g, WOOD_BROWN_LIGHT.b, 1.0 if not dimmed else UNAFFORDABLE_ALPHA)
	style.set_corner_radius_all(UiTheme.scale_px(12))
	style.set_border_width_all(UiTheme.scale_px(2))
	style.border_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 1.0 if not dimmed else UNAFFORDABLE_ALPHA)
	style.shadow_size = UiTheme.scale_px(4) if not dimmed else 0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = UiTheme.scale_px(12)
	style.content_margin_right = UiTheme.scale_px(12)
	style.content_margin_top = UiTheme.scale_px(8)
	style.content_margin_bottom = UiTheme.scale_px(8)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state_name, style)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UiTheme.scale_px(10))

	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", UiTheme.scale_px(10))

	var emoji_label := Label.new()
	emoji_label.text = FarmEquipment.equipment_emoji(kind)
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(26, Color.WHITE)
	left.add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = FarmEquipment.equipment_name(kind)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.label_settings = _make_label_settings(14, Color.WHITE)
	left.add_child(name_label)

	var status_label := Label.new()
	status_label.text = _status_text(row)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.label_settings = _make_label_settings(14, Color.WHITE)

	content.add_child(left)
	content.add_child(status_label)
	btn.add_child(content)

	if buyable:
		btn.pressed.connect(_on_row_pressed.bind(kind))
	return btn


func _status_text(row: Dictionary) -> String:
	if row["owned"]:
		return tr(&"equipment_shop.owned")
	if row["locked"]:
		return tr(&"equipment_shop.locked_row") % row["expansions_remaining"]
	return tr(&"equipment_shop.buy_button") % FarmEquipment.equipment_cost(row["kind"])


func _on_row_pressed(kind: int) -> void:
	_economy.buy_equipment(kind)
	if _economy.dirty:
		_play_audio(&"ui_button_tap")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
