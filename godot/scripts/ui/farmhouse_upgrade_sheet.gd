## Farmhouse upgrade management sheet -- shows current level, cost to upgrade,
## next level's unlocks, and passive income. Extends the bottom-sheet content
## pattern (configure() precondition, _ready() populate, close on upgrade success).
##
## design/gdd/farmhouse-progression.md, confirmed 2026-08-21. Lazy income
## resolution happens in the economy layer (resolve_passive_income), not here --
## this sheet's only job is UI display + upgrade trigger.
##
## ARCHITECTURE: small static shell (Scroll/Body) + procedural content built
## in _populate(), same as accessibility_sheet.gd and every other ported
## management sheet. No .tscn needed; content hierarchy is simple enough that
## pure-script is faster and easier than visual tuning.
class_name FarmhouseUpgradeSheet
extends VBoxContainer

const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const FIELD_GREEN := UiTheme.FIELD_GREEN
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR

signal upgraded

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _bottom_sheet: BottomSheet


## Precondition: must be called before adding this instance to a BottomSheet's
## content slot. Takes the economy instance for state reads and upgrade trigger.
func configure(economy: GameEconomy, bottom_sheet: BottomSheet) -> void:
	_economy = economy
	_bottom_sheet = bottom_sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func refresh_ui() -> void:
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()

	var current_level: int = _economy.state.farmhouse_level
	var current_def := GameData.farmhouse_level_def(current_level)
	var is_max_level: bool = current_level >= GameData.farmhouse_max_level()

	_body.add_child(_make_title_label(tr(&"farmhouse.title"), 20, SOIL_BROWN_DARK))

	# Current level display
	var level_text: String = tr(&"farmhouse.current_level") % [current_def.emoji, current_def.display_name, current_level]
	_body.add_child(_make_title_label(level_text, 16))

	# Passive income display (if any)
	if current_def.passive_income_per_hour > 0:
		var income_text: String = tr(&"farmhouse.passive_income") % current_def.passive_income_per_hour
		_body.add_child(_make_title_label(income_text, 14, GOLD_LIGHT))

	if not is_max_level:
		var next_level := GameData.farmhouse_level_def(current_level + 1)

		# Cost to upgrade
		var cost_text: String = tr(&"farmhouse.upgrade_cost") % [next_level.upgrade_cost, next_level.display_name]
		_body.add_child(_make_title_label(cost_text, 14))

		# Unlocks card
		if not next_level.unlocks.is_empty():
			_body.add_child(_build_unlocks_card(next_level.unlocks))

		# Upgrade button
		var can_afford: bool = _economy.state.coins >= next_level.upgrade_cost
		var upgrade_button := _make_chunky_button(tr(&"farmhouse.upgrade_action"), FIELD_GREEN, Color.WHITE, can_afford)
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		_body.add_child(upgrade_button)
	else:
		var max_label := _make_title_label(tr(&"farmhouse.max_level_reached"), 16, GOLD_LIGHT)
		_body.add_child(max_label)


func _build_unlocks_card(unlocks: Array[String]) -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UiTheme.scale_px(8))

	box.add_child(_make_title_label(tr(&"farmhouse.unlocks_title"), 14, SOIL_BROWN_DARK))

	for unlock in unlocks:
		var bullet := _make_title_label("• " + unlock, 12)
		box.add_child(bullet)

	card.add_child(box)
	return card


func _on_upgrade_pressed() -> void:
	var now: int = int(Time.get_unix_time_from_system()) * 1000
	var success: bool = _economy.upgrade_farmhouse(now)
	if success:
		upgraded.emit()
		_populate()


# ---------------------------------------------------------------------------
# Shared widget helpers
# ---------------------------------------------------------------------------

func _make_chunky_button(label_text: String, color: Color, font_color: Color = Color.WHITE, enabled: bool = true) -> Button:
	return UiTheme.make_chunky_button(label_text, color, font_color, enabled)


func _make_panel(bg_color: Color, corner_radius: int = 16, border_color: Color = GOLD_LIGHT) -> PanelContainer:
	return UiTheme.make_panel(bg_color)


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	return UiTheme.make_title_label(text, font_size, color)
