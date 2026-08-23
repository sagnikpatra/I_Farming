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


## Open this sheet for a thief visit. `steal_amount` is the coins at risk,
## `eco` is the GameEconomy reference for accessing current state.
func open_for_thief(steal_amount: int, eco: GameEconomy) -> void:
	_steal_amount = steal_amount
	_eco = eco
	if _steal_amount_label != null:
		_steal_amount_label.text = tr(&"thief.at_risk") % _steal_amount


## Builds the UI hierarchy programmatically (for testing without a scene file).
func _build_ui() -> void:
	# Root VBoxContainer
	var container := VBoxContainer.new()
	container.anchor_left = 0.05
	container.anchor_right = 0.95
	container.anchor_top = 0.05
	container.anchor_bottom = 0.95
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(container)

	# Title label
	var title := Label.new()
	title.text = tr(&"thief.title")
	title.add_theme_font_size_override("font_size", 28)
	container.add_child(title)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	container.add_child(spacer1)

	# Steal amount label
	_steal_amount_label = Label.new()
	_steal_amount_label.text = tr(&"thief.at_risk") % 0
	_steal_amount_label.add_theme_font_size_override("font_size", 20)
	container.add_child(_steal_amount_label)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	container.add_child(spacer2)

	# Buttons container (HBoxContainer for 3 columns)
	var buttons_container := HBoxContainer.new()
	buttons_container.separation = 8
	container.add_child(buttons_container)

	# Button 1: Let Them Go (neutral)
	_let_go_button = Button.new()
	_let_go_button.text = tr(&"thief.let_go")
	_let_go_button.pressed.connect(_on_let_go_pressed)
	buttons_container.add_child(_let_go_button)

	# Button 2: Pay Bribe (warning)
	_bribe_button = Button.new()
	_bribe_button.text = tr(&"thief.pay_bribe")
	_bribe_button.pressed.connect(_on_bribe_pressed)
	buttons_container.add_child(_bribe_button)

	# Button 3: Chase Them Off (action)
	_chase_button = Button.new()
	_chase_button.text = tr(&"thief.chase_off")
	_chase_button.pressed.connect(_on_chase_pressed)
	buttons_container.add_child(_chase_button)


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
