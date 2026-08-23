class_name ThiefInteractionSheet
extends Control
## Bottom-sheet UI for player interaction with a thief NPC on the board.
## Shows the steal amount at risk and three player choice buttons:
## 1. "Let Them Go" (neutral, default) -- lose 100% of steal amount
## 2. "Pay Bribe" (warning) -- lose 50% of steal amount
## 3. "Chase Them Off" (action) -- 30% success rate; 75% recovery on success,
##    lose 100% + ₹50 penalty on failure.
##
## Architecture: child of BottomSheet (owned by caller). Emits thief_choice_made
## signal with {choice: String, success: bool, coins_lost: int} when the player
## makes a choice. The caller is responsible for handling this signal, applying
## the economy logic, animating the thief's departure, and closing the sheet.

signal thief_choice_made(choice: String, success: bool, coins_lost: int)

enum Choice { LET_GO, PAY_BRIBE, CHASE_OFF }

## UI references (set in _ready)
var _steal_amount_label: Label = null
var _let_go_button: Button = null
var _bribe_button: Button = null
var _chase_button: Button = null

## State for the current thief visit
var _steal_amount: int = 0
var _eco: GameEconomy = null


func _ready() -> void:
	# Build UI hierarchy if not already present (for testing)
	if _steal_amount_label == null:
		_build_ui()
	_refresh_display()


## Open this sheet for a thief visit. `steal_amount` is the coins at risk,
## `eco` is the GameEconomy reference for accessing current state. Matches
## this project's configure()-then-_ready() idiom (see EventsTab.configure()):
## works whether called before this node enters the tree (the normal case --
## hud.gd configures it, then BottomSheet.open() adds it as a child,
## triggering _ready()) or after (_refresh_display() is safe to call from
## both places since it re-checks _steal_amount_label itself).
func open_for_thief(steal_amount: int, eco: GameEconomy) -> void:
	_steal_amount = steal_amount
	_eco = eco
	_refresh_display()


func _refresh_display() -> void:
	if _steal_amount_label != null:
		_steal_amount_label.text = tr(&"thief.at_risk") % _steal_amount


## Builds the UI hierarchy programmatically (for testing without a scene file).
## BUGFIX (found on-device 2026-08-23, once this sheet was actually wired up
## and reachable for the first time -- see production/session-state/active.md):
## the original version used raw Button.new()/Label.new() with unscaled pixel
## spacers, unlike every other sheet in this codebase (farmhouse_tab.gd,
## seed_picker.gd, events_tab.gd, ...), which all go through UiTheme's
## make_chunky_button()/make_title_label()/scale_px() -- this project's UI
## runs at a 2.6x UI_SCALE (ui_theme.gd's UI_SCALE), and raw unscaled/
## untextured controls rendered so small and undersized relative to
## everything else that the three choice buttons were effectively invisible
## on a real device, even though they existed in the scene tree and worked
## if you knew blindly where to tap. Rebuilt to match the established
## pattern exactly.
func _build_ui() -> void:
	# Root VBoxContainer -- matches farmhouse_tab.gd's Scroll/Body shell
	# convention closely enough for a sheet this simple (no ScrollContainer
	# needed -- content is short and fixed-height, unlike farmhouse_tab's
	# variable-length unlocks list).
	var container := VBoxContainer.new()
	container.anchor_left = 0.05
	container.anchor_right = 0.95
	container.anchor_top = 0.05
	container.anchor_bottom = 0.95
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", UiTheme.scale_px(14))
	add_child(container)

	# Title label -- A11Y (village-board-and-management-sheets-audit-2026-08-21.md
	# §1): sits directly on BottomSheet's cream background, not inside a
	# colored panel, so it must use SOIL_BROWN_DARK, not make_title_label()'s
	# Color.WHITE default (same rule farmhouse_tab.gd's _build_header() follows).
	var title := UiTheme.make_title_label(tr(&"thief.title"), 22, UiTheme.SOIL_BROWN_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	# Steal amount label -- inside a panel card, so the default WHITE is fine.
	var amount_card := UiTheme.make_panel(UiTheme.WOOD_BROWN_LIGHT)
	_steal_amount_label = UiTheme.make_title_label(tr(&"thief.at_risk") % 0, 18)
	_steal_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_card.add_child(_steal_amount_label)
	container.add_child(amount_card)

	# Buttons -- one per row (not an HBoxContainer of 3 squeezed columns):
	# this project's UI_SCALE makes make_chunky_button()'s text/padding wide
	# enough that 3-across would either clip or force a much smaller,
	# inconsistent button size versus every other sheet's single-column
	# chunky buttons (farmhouse_tab.gd's Upgrade button, etc.).
	_let_go_button = UiTheme.make_chunky_button(tr(&"thief.let_go"), UiTheme.WOOD_BROWN_LIGHT, Color.WHITE)
	_let_go_button.pressed.connect(_on_let_go_pressed)
	container.add_child(_let_go_button)

	_bribe_button = UiTheme.make_chunky_button(tr(&"thief.pay_bribe"), UiTheme.SAFFRON_DARK, Color.WHITE)
	_bribe_button.pressed.connect(_on_bribe_pressed)
	container.add_child(_bribe_button)

	_chase_button = UiTheme.make_chunky_button(tr(&"thief.chase_off"), UiTheme.FIELD_GREEN, Color.WHITE)
	_chase_button.pressed.connect(_on_chase_pressed)
	container.add_child(_chase_button)


func _on_let_go_pressed() -> void:
	# Player lets them go: loses 100% of steal amount
	_disable_buttons()
	var coins_lost := _steal_amount
	thief_choice_made.emit("let_go", true, coins_lost)


func _on_bribe_pressed() -> void:
	# Player pays bribe: loses 50% of steal amount
	_disable_buttons()
	var coins_lost := roundi(float(_steal_amount) * GameData.THIEF_BRIBE_PERCENTAGE)
	thief_choice_made.emit("bribe", true, coins_lost)


func _on_chase_pressed() -> void:
	# Player chases: 30% success rate
	_disable_buttons()
	var success := randf() < GameData.THIEF_CHASE_SUCCESS_RATE
	var coins_lost: int
	if success:
		# Chase succeeds: recover 75%, lose 25%
		coins_lost = _steal_amount - roundi(float(_steal_amount) * GameData.THIEF_CHASE_RECOVERY_RATE)
	else:
		# Chase fails: lose 100% + penalty
		coins_lost = _steal_amount + GameData.THIEF_CHASE_FAILURE_PENALTY
	thief_choice_made.emit("chase_off", success, coins_lost)


func _disable_buttons() -> void:
	if _let_go_button != null:
		_let_go_button.disabled = true
	if _bribe_button != null:
		_bribe_button.disabled = true
	if _chase_button != null:
		_chase_button.disabled = true
