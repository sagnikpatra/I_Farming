## Central input authority for the village board -- the single script that
## receives raw touch/mouse input and turns it into tap-to-select,
## drag-to-pan-camera, pinch-to-zoom, and long-press-then-drag-to-reposition-
## a-zone. Deliberately consolidated into one script (not split across
## CameraRig + a separate selection script) so exactly one
## _unhandled_input() handler exists for the whole board: the old LibGDX
## build's "touch interception" bug class was about a *different* node
## stealing input from the render surface, but a subtler version of the same
## class of bug is possible even within a single render surface if two
## scripts both listen for the same raw touch events and race to interpret
## them (e.g. camera-pan and zone-drag both trying to consume the same
## single-finger drag). This script is that one resolution point --
## CameraRig and VillageBoard only expose plain method calls, no input
## handling of their own.
##
## Uses _unhandled_input() rather than _input(), specifically so that once
## EPIC-M4 adds real UI (Control nodes), a Control with
## mouse_filter = MOUSE_FILTER_STOP over the render area will naturally
## consume the event first and this script will never see it -- the
## touch-interception bug class is prevented by construction rather than by
## careful z-ordering added later. As of EPIC-M3 there is no UI in the scene
## at all (main.tscn is a bare Node3D), so this is currently unexercised by
## anything -- re-verify once EPIC-M4 lands.
##
## Gesture-recognition note: Godot 4.7 has InputEventMagnifyGesture /
## InputEventPanGesture for pinch/two-finger-pan, but on Android these
## require explicitly enabling
## ProjectSettings.input_devices/pointing/android/enable_pan_and_scale_gestures
## (off by default) and their exact interaction with simultaneously-delivered
## raw per-finger InputEventScreenTouch/Drag is undocumented. Long-press-drag
## and tap-select both already need raw per-finger tracking, so pinch-zoom is
## implemented the same way here (manual two-finger distance tracking) rather
## than mixing in the gesture-event path -- one input model for the whole
## script, not two.
class_name BoardInteractor
extends Node3D

## Screen-space movement (px) below which a released touch counts as a tap,
## not a drag.
const TAP_MAX_MOVEMENT_PX: float = 24.0
## Matches the old LibGDX board's proven long-press threshold exactly
## (core/.../village3d/Village3DStage.kt's LONG_PRESS_SECONDS).
const LONG_PRESS_SECONDS: float = 0.45
## Pinch-distance change (px) required between frames before it's treated as
## an intentional zoom rather than sensor noise while two fingers are held
## roughly still.
const PINCH_MIN_DELTA_PX: float = 0.5
## Mouse fallback (desktop/editor testing convenience only -- see
## _unhandled_input()) uses a touch index no real touchscreen will ever
## report, so it can share all the same state as real touch handling.
const _MOUSE_POINTER_INDEX: int = -100

const GROUND_PLANE := Plane(Vector3(0.0, 1.0, 0.0), 0.0)

enum _Mode { IDLE, PENDING_TAP, PANNING_CAMERA, DRAGGING_ZONE }

@onready var _village_board: VillageBoard = get_parent() as VillageBoard
@onready var _camera_rig: CameraRig = _village_board.get_node("CameraRig") as CameraRig

var _highlight: MeshInstance3D

# -- Single-finger gesture state --
var _mode: _Mode = _Mode.IDLE
var _primary_touch_index: int = -1
var _touch_start_screen_pos: Vector2 = Vector2.ZERO
var _touch_last_screen_pos: Vector2 = Vector2.ZERO
var _long_press_pick: Dictionary = {}
var _long_press_request_id: int = 0

var _drag_zone_id: String = ""
var _drag_start_center: Vector3 = Vector3.ZERO
var _drag_start_ground_hit: Vector3 = Vector3.ZERO

# -- Two-finger pinch-zoom state --
var _active_touches: Dictionary = {}  # touch index -> last known Vector2 screen position
var _pinch_last_distance_px: float = -1.0


func _ready() -> void:
	_highlight = _build_highlight_mesh()
	add_child(_highlight)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_on_drag(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


# ---------------------------------------------------------------------------
# Touch input
# ---------------------------------------------------------------------------

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and not event.canceled:
		_active_touches[event.index] = event.position
		if _active_touches.size() == 1:
			_begin_primary_touch(event.index, event.position)
		elif _active_touches.size() == 2:
			_begin_pinch()
		# 3+ simultaneous touches are ignored beyond updating _active_touches:
		# no interaction in this epic needs them, and treating extra
		# accidental contacts as pinch input would misread them.
	else:
		_end_touch(event.index)


func _on_drag(event: InputEventScreenDrag) -> void:
	if _active_touches.has(event.index):
		_active_touches[event.index] = event.position
	if _active_touches.size() >= 2:
		_update_pinch()
		return
	if event.index != _primary_touch_index:
		return
	_touch_last_screen_pos = event.position
	_advance_primary_gesture(event.relative)


func _end_touch(index: int) -> void:
	var was_primary := index == _primary_touch_index
	_active_touches.erase(index)
	if _active_touches.size() < 2:
		_pinch_last_distance_px = -1.0
	if was_primary:
		_release_primary_touch()
		_primary_touch_index = -1
	if _active_touches.size() == 1 and _primary_touch_index == -1:
		# The finger that was doing the pinch is still down after its partner
		# lifted -- resume single-finger handling from here rather than
		# leaving input dead until a fresh touch-down.
		var remaining_index: int = _active_touches.keys()[0]
		_begin_primary_touch(remaining_index, _active_touches[remaining_index])


# ---------------------------------------------------------------------------
# Mouse fallback -- desktop/editor testing convenience only. Exercises the
# same state machine as touch so this board's interaction logic can be
# sanity-checked from the Godot editor without an Android device attached.
# Not the shipping input path (Android-only target per technical-preferences).
# ---------------------------------------------------------------------------

func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_primary_touch(_MOUSE_POINTER_INDEX, event.position)
		elif _primary_touch_index == _MOUSE_POINTER_INDEX:
			_release_primary_touch()
			_primary_touch_index = -1
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_camera_rig.zoom_by(1.1)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_camera_rig.zoom_by(1.0 / 1.1)
		get_viewport().set_input_as_handled()


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _primary_touch_index != _MOUSE_POINTER_INDEX:
		return
	_touch_last_screen_pos = event.position
	_advance_primary_gesture(event.relative)
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Single-finger (or mouse) gesture state machine
# ---------------------------------------------------------------------------

func _begin_primary_touch(index: int, pos: Vector2) -> void:
	_primary_touch_index = index
	_touch_start_screen_pos = pos
	_touch_last_screen_pos = pos
	_mode = _Mode.PENDING_TAP
	# Zones-only pick, eagerly cached now: only used to decide long-press-drag
	# candidacy. Tap-select (on quick release, below) does its own separate
	# zones-or-plots pick at the release position -- two cheap raycasts per
	# tap, not a missed reuse opportunity, since they answer different
	# questions (draggable? vs. selectable?) and a tap can move slightly
	# between press and release.
	_long_press_pick = _pick(pos, VillageBoard.PICK_LAYER_ZONES)
	_long_press_request_id += 1
	var this_request_id := _long_press_request_id
	get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(
		_on_long_press_timeout.bind(this_request_id)
	)


func _advance_primary_gesture(relative: Vector2) -> void:
	var moved := _touch_last_screen_pos.distance_to(_touch_start_screen_pos)
	match _mode:
		_Mode.PENDING_TAP:
			if moved > TAP_MAX_MOVEMENT_PX:
				_mode = _Mode.PANNING_CAMERA
				_pan_camera_by_screen_delta(relative)
		_Mode.PANNING_CAMERA:
			_pan_camera_by_screen_delta(relative)
		_Mode.DRAGGING_ZONE:
			_update_zone_drag()
		_Mode.IDLE:
			pass


func _release_primary_touch() -> void:
	match _mode:
		_Mode.PENDING_TAP:
			var pick := _pick(_touch_last_screen_pos, VillageBoard.PICK_LAYER_ZONES | VillageBoard.PICK_LAYER_PLOTS)
			if not pick.is_empty():
				_select(pick["kind"], pick["id"])
			else:
				_deselect()
		_Mode.DRAGGING_ZONE:
			_commit_zone_drag()
		_Mode.PANNING_CAMERA, _Mode.IDLE:
			pass
	_mode = _Mode.IDLE
	_long_press_pick = {}


func _on_long_press_timeout(request_id: int) -> void:
	if request_id != _long_press_request_id or _mode != _Mode.PENDING_TAP:
		return  # Stale timer: touch already released/moved/ended since this was scheduled.
	if _long_press_pick.is_empty():
		return  # Long-press over empty ground (or a non-draggable plot): nothing to drag.
	_begin_zone_drag(_long_press_pick["id"])


# ---------------------------------------------------------------------------
# Camera pan (drag-pan)
# ---------------------------------------------------------------------------

## Converts a screen-space drag delta into a world-space pan delta via two
## ground-plane ray hits (Plane.intersects_ray), so panning stays correct at
## any zoom level and camera pitch instead of relying on a hand-tuned
## px-to-world constant -- the same "grab the ground and drag it" feel as a
## typical mobile map view.
func _pan_camera_by_screen_delta(relative: Vector2) -> void:
	var curr := _touch_last_screen_pos
	var prev := curr - relative
	var prev_hit = _ground_hit(prev)
	var curr_hit = _ground_hit(curr)
	if prev_hit == null or curr_hit == null:
		return
	var world_delta := Vector2(prev_hit.x - curr_hit.x, prev_hit.z - curr_hit.z)
	_camera_rig.pan_by(world_delta)


# ---------------------------------------------------------------------------
# Pinch-zoom
# ---------------------------------------------------------------------------

func _begin_pinch() -> void:
	# A pinch always supersedes any in-flight single-finger interpretation --
	# if the primary finger was mid-zone-drag when a second finger touched
	# down, cancel the drag rather than let it keep tracking a now-ambiguous
	# "primary" finger; the zone snaps back to its last-committed position,
	# exactly like an invalid drop would.
	if _mode == _Mode.DRAGGING_ZONE:
		_village_board.preview_zone_position(_drag_zone_id, _drag_start_center)
	_mode = _Mode.IDLE
	_primary_touch_index = -1
	_pinch_last_distance_px = -1.0


func _update_pinch() -> void:
	var positions := _active_touches.values()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var current_distance := a.distance_to(b)
	if _pinch_last_distance_px > 0.0 and absf(current_distance - _pinch_last_distance_px) >= PINCH_MIN_DELTA_PX:
		# Fingers spreading apart (current > last) -> factor > 1 -> zoom in.
		# Fingers pinching together -> factor < 1 -> zoom out. See
		# CameraRig.zoom_by() for the distance-scaling direction this assumes.
		var factor := current_distance / _pinch_last_distance_px
		_camera_rig.zoom_by(factor)
	_pinch_last_distance_px = current_distance


# ---------------------------------------------------------------------------
# Long-press-then-drag zone reposition
# ---------------------------------------------------------------------------

func _begin_zone_drag(zone_id: String) -> void:
	_mode = _Mode.DRAGGING_ZONE
	_drag_zone_id = zone_id
	_drag_start_center = _village_board.get_zone_center_world(zone_id)
	var hit = _ground_hit(_touch_last_screen_pos)
	_drag_start_ground_hit = hit if hit != null else _drag_start_center
	_select("zone", zone_id)  # Long-press also selects, matching tap's feedback.


func _update_zone_drag() -> void:
	var hit = _ground_hit(_touch_last_screen_pos)
	if hit == null:
		return
	var delta: Vector3 = hit - _drag_start_ground_hit
	delta.y = 0.0
	var preview_center := _drag_start_center + delta
	_village_board.preview_zone_position(_drag_zone_id, preview_center)
	_move_highlight_to(preview_center, _village_board.get_zone_footprint(_drag_zone_id).get("size", Vector2.ONE))


func _commit_zone_drag() -> void:
	var hit = _ground_hit(_touch_last_screen_pos)
	var final_hit: Vector3 = hit if hit != null else _drag_start_ground_hit
	var delta: Vector3 = final_hit - _drag_start_ground_hit
	var tile_dx := roundi(delta.x / VillageBoard.TILE_SIZE)
	var tile_dz := roundi(delta.z / VillageBoard.TILE_SIZE)

	var start_tile := _village_board.get_zone_tile_origin(_drag_zone_id)
	var committed := _village_board.try_commit_zone_move(
		_drag_zone_id, start_tile.x + tile_dx, start_tile.y + tile_dz
	)
	if not committed:
		push_warning(
			"BoardInteractor: zone '%s' drop target out of bounds or overlapping another zone/plot -- reverted to its last position." % _drag_zone_id
		)
	_select("zone", _drag_zone_id)  # Re-sync highlight to the committed (or reverted) position.
	_drag_zone_id = ""


# ---------------------------------------------------------------------------
# Selection highlight (visual-only -- no real game-state to update yet, see
# EPIC-M2 in the migration roadmap)
# ---------------------------------------------------------------------------

func _build_highlight_mesh() -> MeshInstance3D:
	var highlight := MeshInstance3D.new()
	highlight.name = "SelectionHighlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	highlight.mesh = mesh
	var mat := StandardMaterial3D.new()
	# Bright unshaded gold -- deliberately NOT run through _apply_toon_shading
	# so it never blends into the board's toon-shaded palette; selection
	# feedback should read clearly regardless of lighting.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.15, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.15)
	mat.emission_energy_multiplier = 0.6
	highlight.material_override = mat
	highlight.visible = false
	return highlight


func _select(kind: String, id: String) -> void:
	var footprint: Dictionary = (
		_village_board.get_zone_footprint(id) if kind == "zone" else _village_board.get_plot_footprint(id)
	)
	if footprint.is_empty():
		_deselect()
		return
	_move_highlight_to(footprint["center"], footprint["size"])


func _move_highlight_to(center: Vector3, size: Vector2) -> void:
	var highlight_thickness := 0.06
	(_highlight.mesh as BoxMesh).size = Vector3(size.x * 1.02, highlight_thickness, size.y * 1.02)
	_highlight.position = Vector3(center.x, VillageBoard.PLINTH_HEIGHT + 0.02, center.z)
	_highlight.visible = true


func _deselect() -> void:
	_highlight.visible = false


# ---------------------------------------------------------------------------
# Ray-picking (Area3D + Camera3D.project_ray_origin/project_ray_normal +
# PhysicsDirectSpaceState3D.intersect_ray) and ground-plane hit-testing
# (Plane.intersects_ray)
# ---------------------------------------------------------------------------

## Returns {} if nothing pickable was hit, else {"kind": "zone"|"plot",
## "id": String} read off the hit collider's meta (set at build time in
## village_board.gd's _build_zone()/_build_plot()).
func _pick(screen_pos: Vector2, mask: int) -> Dictionary:
	var camera := _camera_rig.get_camera()
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * camera.far

	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider: Object = result.get("collider")
	if collider == null or not (collider is Node) or not (collider as Node).has_meta("board_id"):
		return {}
	var node := collider as Node
	return {"kind": node.get_meta("board_kind"), "id": node.get_meta("board_id")}


## Vector3 world-space hit, or null if the ray is parallel to the ground
## plane (should not happen at this board's fixed camera pitch, but
## Plane.intersects_ray() can return null, so this is handled rather than
## assumed away).
func _ground_hit(screen_pos: Vector2) -> Variant:
	var camera := _camera_rig.get_camera()
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return GROUND_PLANE.intersects_ray(from, dir)
