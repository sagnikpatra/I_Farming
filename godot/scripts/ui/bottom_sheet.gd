## Reusable bottom-sheet UI primitive -- the ONE sheet shell every future
## management/picker sheet (Farmhouse/Mandi/Polyhouse/Agroforestry/Niche/
## Events tabs, seed/decoration/agro-plant pickers -- see the EPIC-M4 slice
## plan in docs/architecture/godot-migration-roadmap.md) will reuse via
## open(content)/close(), rather than each screen hand-rolling its own
## slide-up panel + backdrop. Godot has no built-in ModalBottomSheet
## equivalent (Compose Material3's ModalBottomSheet, used on all 9 of the old
## Kotlin UI's management/picker sheets, has no Control-node counterpart) --
## this is the hand-built replacement the migration roadmap flagged as a
## required risk item.
##
## ARCHITECTURE: .tscn + .gd, not pure-script. village_board.gd builds its
## content procedurally because that content is data-driven (rebuilt from
## ZoneFixture arrays whenever state changes) -- there's no equivalent reason
## here: this shell's layout (backdrop, panel, content slot) is small (3
## nodes) and static, and is best tuned visually in the editor. Same reason
## village_board.tscn/.gd already split this way (structural nodes in the
## scene, behavior in the script) -- following that precedent rather than
## inventing a second pattern for the UI layer. (Compare hud.gd, which is
## the OPPOSITE call for a much larger, more Kotlin-source-driven widget
## tree -- see that file's header comment for why.)
##
## Root is a CanvasLayer (layer=10, above HUD's own CanvasLayer), not a
## Control, specifically so this scene is fully self-contained: any future
## script can `add_child()` an instance of this scene ANYWHERE in the tree
## (even under a 3D node) and it still renders as a correct full-screen
## overlay above both the 3D board and the HUD -- callers never need to know
## it has to live under a CanvasLayer themselves. That is what "reusable
## without knowing internals" means concretely for this component.
##
## SheetPanel is deliberately NOT vertically anchored (anchor_top=0,
## anchor_bottom=0, i.e. left at Godot's default point-anchor): it is sized
## explicitly (SHEET_HEIGHT_RATIO of the viewport height, in
## _panel_height()) and positioned via a direct `.position.y` Tween.
## Anchor+offset layout math and Tween-driven position animation fight each
## other on a stretch-anchored Control; a point-anchored Control with
## explicit size/position sidesteps that entirely. Horizontal sizing (full
## viewport width) is likewise set explicitly in code, not via anchors.
##
## Sizing is a fixed proportion of the viewport, not auto-sized to content
## (no wrap-content/partial-expand/drag-handle like Compose's
## ModalBottomSheet) -- explicitly out of scope for this round per the
## EPIC-M4 slice plan; content that overflows the fixed height is future
## content's own responsibility (e.g. wrapping itself in a ScrollContainer)
## once real sheet content is built next round.
##
## open()/close() set `_state` SYNCHRONOUSLY, before the slide Tween starts --
## the logical "is a sheet open" state is available immediately to callers
## and to tests (see tests/unit/test_bottom_sheet.gd), independent of
## animation timing. Only the visual position and backdrop alpha are
## Tweened. Per this project's testing standards (coding-standards.md), the
## Tween's actual visual motion is NOT unit tested -- that is "Visual/Feel"
## territory (screenshot evidence, not automation); only the state machine
## and content-ownership guarantees are.
##
## Touch vs. mouse: no custom handling needed here (unlike board_interactor.gd,
## which deliberately does its own raw per-finger tracking for 3D-board
## picking/panning/pinch-zoom). Godot's Control system already normalizes
## touch and mouse identically for `gui_input`/Button `pressed` -- that is
## long-standing, stable Control behavior, not something introduced or
## changed in the 4.6/4.7 window per docs/engine-reference/godot/
## breaking-changes.md.
class_name BottomSheet
extends CanvasLayer

enum State { CLOSED, OPEN }

## Bottom sheet occupies this fraction of the viewport height once open --
## fixed, not content-driven (see class doc).
const SHEET_HEIGHT_RATIO: float = 0.6
const SLIDE_DURATION_SECONDS: float = 0.25
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.5)

signal opened
signal closed

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet_panel: Control = $SheetPanel
@onready var _content_slot: MarginContainer = $SheetPanel/ContentSlot

var _state: State = State.CLOSED
var _current_content: Control = null
var _tween: Tween = null


func _ready() -> void:
	visible = false
	_backdrop.color = BACKDROP_COLOR
	_backdrop.modulate.a = 0.0
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_layout_panel_closed()
	get_viewport().size_changed.connect(_on_viewport_resized)


func get_state() -> State:
	return _state


func is_open() -> bool:
	return _state == State.OPEN


## Shows the sheet with `content` as its body. Takes ownership of `content`:
## calling open() again with a DIFFERENT Control removes+frees whatever was
## previously shown before adding the new one; calling it again with the
## SAME instance is a safe no-op reparent (no restart of the slide-in
## animation). Removal happens synchronously (Node.remove_child(), not just
## queue_free()) so the content slot's child count is correct immediately,
## not only after the current frame ends -- see
## test_reopening_with_new_content_frees_the_previous_content.
func open(content: Control) -> void:
	if content != _current_content:
		if _current_content != null and is_instance_valid(_current_content):
			_content_slot.remove_child(_current_content)
			_current_content.queue_free()
		_current_content = content
		_content_slot.add_child(content)

	var was_closed := not visible
	_state = State.OPEN
	if was_closed:
		_backdrop.modulate.a = 0.0
	visible = true
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_animate_to(_open_y(), true)
	opened.emit()


func close() -> void:
	if _state == State.CLOSED:
		return
	_state = State.CLOSED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animate_to(_closed_y(), false)
	closed.emit()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _open_y() -> float:
	return get_viewport().get_visible_rect().size.y - _panel_height()


func _closed_y() -> float:
	return get_viewport().get_visible_rect().size.y


func _panel_height() -> float:
	return get_viewport().get_visible_rect().size.y * SHEET_HEIGHT_RATIO


func _layout_panel_closed() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_sheet_panel.size = Vector2(viewport_size.x, _panel_height())
	_sheet_panel.position.y = _closed_y()


func _on_viewport_resized() -> void:
	_sheet_panel.size = Vector2(get_viewport().get_visible_rect().size.x, _panel_height())
	_sheet_panel.position.y = _open_y() if _state == State.OPEN else _closed_y()


func _animate_to(target_y: float, fading_in: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sheet_panel, "position:y", target_y, SLIDE_DURATION_SECONDS)
	_tween.parallel().tween_property(_backdrop, "modulate:a", 1.0 if fading_in else 0.0, SLIDE_DURATION_SECONDS)
	if not fading_in:
		_tween.tween_callback(func(): visible = false)
