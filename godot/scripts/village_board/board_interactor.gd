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

const SeedPickerScene := preload("res://scenes/ui/seed_picker.tscn")
const FarmhouseTabScene := preload("res://scenes/ui/farmhouse_tab.tscn")
const MandiTabScene := preload("res://scenes/ui/mandi_tab.tscn")
const PolyhouseTabScene := preload("res://scenes/ui/polyhouse_tab.tscn")
const AgroforestryTabScene := preload("res://scenes/ui/agroforestry_tab.tscn")
const NicheFarmingTabScene := preload("res://scenes/ui/niche_farming_tab.tscn")
const OpenFieldTabScene := preload("res://scenes/ui/open_field_tab.tscn")
const AgroPlantPickerScene := preload("res://scenes/ui/agro_plant_picker.tscn")
const GrowingInfoCardScene := preload("res://scenes/ui/growing_info_card.tscn")
const DecorationInfoCardScene := preload("res://scenes/ui/decoration_info_card.tscn")

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

enum _Mode { IDLE, PENDING_TAP, PANNING_CAMERA, DRAGGING_ZONE, DRAGGING_DECORATION }

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

## Decoration drag-to-reposition (EPIC-M5 parity pass) -- same long-press-
## then-drag gesture as zone dragging, kept as separate state rather than
## generalizing _drag_zone_id/_drag_start_center to a shared "what's being
## dragged" type: a decoration has no tile-grid snap or overlap validation
## at all (see village_board.gd's commit_decoration_move() doc comment),
## so its commit step is genuinely simpler than a zone's, and forcing both
## through one generalized code path would either lose that simplicity or
## bolt unnecessary validation onto decorations. Two small, clear state
## machines beat one blurry one here.
var _drag_decoration_id: int = -1
var _drag_decoration_start_pos: Vector3 = Vector3.ZERO
var _drag_decoration_start_ground_hit: Vector3 = Vector3.ZERO

## DecorationType.Kind ordinal, or -1 when no decoration is armed for
## placement -- set by arm_decoration_placement() (called from the
## DecorationPicker sheet via hud.gd), consumed by the next tap regardless
## of what it hits (see _handle_armed_decoration_tap()). Mirrors
## FarmScreen.kt's hoisted `pendingDecorationType` state, owned here instead
## since BoardInteractor is this project's single tap-dispatch authority
## (see this file's own header comment).
var _armed_decoration_type: int = -1

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
	# Zones-and-decorations pick, eagerly cached now: only used to decide
	# long-press-drag candidacy (plots are never draggable). Tap-select (on
	# quick release, below) does its own separate zones-or-plots-or-
	# decorations pick at the release position -- two cheap raycasts per
	# tap, not a missed reuse opportunity, since they answer different
	# questions (draggable? vs. selectable?) and a tap can move slightly
	# between press and release.
	_long_press_pick = _pick(pos, VillageBoard.PICK_LAYER_ZONES | VillageBoard.PICK_LAYER_DECORATIONS)
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
		_Mode.DRAGGING_DECORATION:
			_update_decoration_drag()
		_Mode.IDLE:
			pass


func _release_primary_touch() -> void:
	match _mode:
		_Mode.PENDING_TAP:
			if _armed_decoration_type != -1:
				_handle_armed_decoration_tap()
			else:
				var pick := _pick(
					_touch_last_screen_pos,
					VillageBoard.PICK_LAYER_ZONES | VillageBoard.PICK_LAYER_PLOTS | VillageBoard.PICK_LAYER_DECORATIONS
				)
				if pick.get("kind") == "decoration":
					# No selection highlight for decorations -- matches the
					# Kotlin original (GdxSelection's info card IS the
					# feedback, no separate highlight box). Handled before
					# the general _select() call below, which only knows
					# about zone/plot footprints.
					_open_decoration_info_card(pick.get("decoration_id", -1))
				elif not pick.is_empty():
					_select(pick["kind"], pick["id"])
					if pick["kind"] == "plot" and pick.get("plot_lifecycle") == PlotFixture.Lifecycle.EMPTY:
						if pick.get("plot_kind") == PlotKind.Kind.AGROFORESTRY:
							if pick.get("host_occupied", false):
								_remove_host(pick.get("plot_id", -1))
							else:
								_maybe_open_agro_plant_picker(pick.get("plot_id", -1))
						else:
							_maybe_open_seed_picker(pick.get("plot_id", -1), pick.get("plot_kind", -1))
					elif pick["kind"] == "plot" and pick.get("plot_lifecycle") == PlotFixture.Lifecycle.READY_TO_HARVEST:
						_harvest_plot(pick.get("plot_id", -1))
					elif pick["kind"] == "plot" and pick.get("plot_lifecycle") == PlotFixture.Lifecycle.GROWING:
						_maybe_open_growing_info_card(pick.get("plot_id", -1))
					elif pick["kind"] == "zone":
						_maybe_open_zone_sheet(pick["id"])
				else:
					_deselect()
		_Mode.DRAGGING_ZONE:
			_commit_zone_drag()
		_Mode.DRAGGING_DECORATION:
			_commit_decoration_drag()
		_Mode.PANNING_CAMERA, _Mode.IDLE:
			pass
	_mode = _Mode.IDLE
	_long_press_pick = {}


func _on_long_press_timeout(request_id: int) -> void:
	if request_id != _long_press_request_id or _mode != _Mode.PENDING_TAP:
		return  # Stale timer: touch already released/moved/ended since this was scheduled.
	if _long_press_pick.is_empty():
		return  # Long-press over empty ground (or a non-draggable plot): nothing to drag.
	if _long_press_pick["kind"] == "decoration":
		_begin_decoration_drag(_long_press_pick["decoration_id"])
	else:
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
	# if the primary finger was mid-drag when a second finger touched down,
	# cancel the drag rather than let it keep tracking a now-ambiguous
	# "primary" finger; the zone/decoration snaps back to its last-committed
	# position, exactly like an invalid drop would.
	if _mode == _Mode.DRAGGING_ZONE:
		_village_board.preview_zone_position(_drag_zone_id, _drag_start_center)
	elif _mode == _Mode.DRAGGING_DECORATION:
		_village_board.preview_decoration_position(_drag_decoration_id, _drag_decoration_start_pos)
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
	_play_audio(&"ui_drag_pickup")


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
	else:
		_play_audio(&"ui_drag_drop_success")
	_select("zone", _drag_zone_id)  # Re-sync highlight to the committed (or reverted) position.
	_drag_zone_id = ""


## Decoration drag-to-reposition (EPIC-M5 parity pass) -- see this file's
## _drag_decoration_id doc comment for why this is a separate, simpler
## state machine rather than sharing the zone-drag one. No highlight box
## (matches _open_decoration_info_card()'s tap-select precedent: the
## Kotlin original never highlights a selected decoration, the info
## card/the drag motion itself is the only feedback).
func _begin_decoration_drag(decoration_id: int) -> void:
	_mode = _Mode.DRAGGING_DECORATION
	_drag_decoration_id = decoration_id
	_drag_decoration_start_pos = _village_board.get_decoration_world_position(decoration_id)
	var hit = _ground_hit(_touch_last_screen_pos)
	_drag_decoration_start_ground_hit = hit if hit != null else _drag_decoration_start_pos
	_play_audio(&"ui_drag_pickup")


func _update_decoration_drag() -> void:
	var hit = _ground_hit(_touch_last_screen_pos)
	if hit == null:
		return
	var delta: Vector3 = hit - _drag_decoration_start_ground_hit
	delta.y = 0.0
	_village_board.preview_decoration_position(_drag_decoration_id, _drag_decoration_start_pos + delta)


## No grid-snap, no bounds/overlap validation, no revert-on-failure -- see
## village_board.gd's commit_decoration_move() doc comment: this mirrors
## GameEconomy.move_decoration()'s own total lack of validation exactly,
## not a simplification this port introduced.
func _commit_decoration_drag() -> void:
	var hit = _ground_hit(_touch_last_screen_pos)
	var final_hit: Vector3 = hit if hit != null else _drag_decoration_start_ground_hit
	var delta: Vector3 = final_hit - _drag_decoration_start_ground_hit
	delta.y = 0.0
	_village_board.commit_decoration_move(_drag_decoration_id, _drag_decoration_start_pos + delta)
	_play_audio(&"ui_drag_drop_success")  # Always succeeds -- see this file's own doc comment above.
	_drag_decoration_id = -1


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
## village_board.gd's _build_zone()/_build_plot()). For "plot" picks, also
## includes "plot_id" (int, the real economy Plot.id, or -1 for a GHOST tile
## with no backing Plot), "plot_kind" (PlotKind.Kind ordinal),
## "plot_lifecycle" (PlotFixture.Lifecycle ordinal), and "host_occupied"
## (bool, Agroforestry-only -- see village_board.gd's _build_plot() meta
## comment) -- read from the extra meta village_board.gd's _build_plot()
## sets, used by _maybe_open_seed_picker()/_harvest_plot()/
## _maybe_open_agro_plant_picker() below. Zone picks never carry these keys.
## For "decoration" picks, includes "decoration_id" (int, EPIC-M5 parity
## pass) -- read from village_board.gd's _build_decoration() meta.
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
	var picked: Dictionary = {"kind": node.get_meta("board_kind"), "id": node.get_meta("board_id")}
	if node.has_meta("plot_id"):
		picked["plot_id"] = node.get_meta("plot_id")
		picked["plot_kind"] = node.get_meta("plot_kind")
		picked["plot_lifecycle"] = node.get_meta("plot_lifecycle")
		picked["host_occupied"] = node.get_meta("host_occupied", false)
	if node.has_meta("decoration_id"):
		picked["decoration_id"] = node.get_meta("decoration_id")
	return picked


# ---------------------------------------------------------------------------
# Seed picker (EPIC-M4 slice 2) + direct-tap harvest + zone management sheets
# (EPIC-M4 slice 3). Tapping an EMPTY plot with at least one plantable crop
# opens the SeedPicker sheet via the HUD's shared BottomSheet instance;
# tapping a READY_TO_HARVEST plot harvests it instantly, no sheet, no
# confirmation; tapping a ZONE (Farmhouse or Mandi only, this round -- see
# _maybe_open_zone_sheet()) opens that zone's management sheet the same way.
#
# CORRECTION to this section's original comment: it previously claimed "the
# old Kotlin UI only ever triggered harvest from inside management-tab plot
# lists, never a raw board tap" -- that was true of FarmScreen.kt's Compose
# management tabs in isolation, but wrong about the actual shipped
# interaction: GdxVillageBoard.kt (the real production LibGDX board,
# ui/gdx/GdxVillageBoard.kt around its onTileTapped dispatch) harvests
# directly on tap -- `plot.state is PlotState.ReadyToHarvest ->
# viewModel.harvestPlot(id)` -- with no sheet at all, which is exactly why
# FarmScreen.kt's PolyhouseTab/NicheFarmingTab pass `showPlots = false`
# (that older plot-list-with-harvest-button affordance was already
# superseded). This port now matches the real shipped app, not the stale
# comment. A Growing plot's tap in the Kotlin original shows a read-only
# info card (emoji/name/sell price) -- not built here yet, tap-select's
# existing highlight is a reasonable stand-in until that's worth adding.
#
# Empty Agroforestry cells route separately from the generic seed picker
# (GameData.crops_for_plot_kind() deliberately excludes Sandalwood -- see
# that function's doc comment -- so it can't drive Agroforestry taps at
# all): a cell with a host already planted removes it instantly on tap
# (matching GdxVillageBoard.kt's GdxSelection.onRemove -> viewModel.removeHost()
# exactly -- no confirmation, same direct-tap language as harvest); a
# genuinely empty cell opens AgroPlantPicker (host + Sandalwood selection).
# ---------------------------------------------------------------------------

## Called by DecorationPicker (via hud.gd) when a row is tapped -- arms
## placement mode instead of placing immediately, since a decoration needs a
## world position only the board itself can resolve (matches
## GdxDecorationPicker.kt's own doc comment on this exact design call).
func arm_decoration_placement(type: int) -> void:
	_armed_decoration_type = type


## While a decoration is armed, ANY tap consumes it -- matches
## GdxVillageBoard.kt's `groundTappedListener`/`tapListener` pair exactly:
## a tap that hits bare ground places the decoration there; a tap that hits
## an existing entity (zone/plot) is swallowed and does nothing (no
## sheet-open, no harvest, no selection) rather than falling through to its
## normal dispatch -- "the Compose overlay intercepts the tap instead" in
## the original's own words. Either way, placement mode disarms after
## exactly one tap, matching the one-shot original.
func _handle_armed_decoration_tap() -> void:
	var type := _armed_decoration_type
	_armed_decoration_type = -1
	var pick := _pick(_touch_last_screen_pos, VillageBoard.PICK_LAYER_ZONES | VillageBoard.PICK_LAYER_PLOTS)
	if not pick.is_empty():
		return  # Tapped an existing entity while armed -- no-op, see above.
	var hit = _ground_hit(_touch_last_screen_pos)
	if hit == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var tile := _village_board.world_to_grid(hit)
	economy.place_decoration(type, tile.x, tile.y)
	if economy.dirty:
		_play_audio(&"economy_purchase_small")
	_village_board.persist_and_rebuild_if_dirty()


func _maybe_open_seed_picker(plot_id: int, plot_kind: int) -> void:
	if plot_id < 0:
		return  # GHOST tile (or a pick with no real Plot behind it) -- nothing to plant.
	if GameData.crops_for_plot_kind(plot_kind).is_empty():
		return
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var picker: SeedPicker = SeedPickerScene.instantiate()
	picker.configure(plot_id, plot_kind, economy, _village_board, hud.get_bottom_sheet())
	hud.get_bottom_sheet().open(picker)


## Opens AgroPlantPicker for a tapped, genuinely-empty Agroforestry tile
## (host + Sandalwood selection) -- the Agroforestry counterpart to
## _maybe_open_seed_picker() above, kept as a separate function rather than
## folded into it since the two pickers have no shared row-building logic
## (GameData.crops_for_plot_kind() plays no role here at all).
func _maybe_open_agro_plant_picker(plot_id: int) -> void:
	if plot_id < 0:
		return  # GHOST tile -- nothing to plant on.
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var picker: AgroPlantPicker = AgroPlantPickerScene.instantiate()
	picker.configure(plot_id, economy, _village_board, hud.get_bottom_sheet())
	hud.get_bottom_sheet().open(picker)


## Direct-tap host removal, matching GdxVillageBoard.kt's real shipped
## behavior exactly (see the correction comment above this section) -- no
## confirmation sheet, same language as _harvest_plot() below.
## GameEconomy.remove_host() already no-ops safely if the tile has no host
## (a stale pick racing a tick-driven rebuild), so no extra guard is
## duplicated here.
func _remove_host(plot_id: int) -> void:
	if plot_id < 0:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	economy.remove_host(plot_id)
	_village_board.persist_and_rebuild_if_dirty()


## Direct-tap harvest, matching GdxVillageBoard.kt's real shipped behavior
## exactly (see the correction above) -- no confirmation sheet.
## GameEconomy.harvest_plot() already no-ops safely if the plot isn't
## actually READY_TO_HARVEST (e.g. a stale pick from a tick-driven rebuild
## racing the tap) or storage is full, so no extra guard is duplicated here.
func _harvest_plot(plot_id: int) -> void:
	if plot_id < 0:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	economy.harvest_plot(plot_id, now)
	if economy.dirty:
		_play_audio(&"economy_harvest")
	_village_board.persist_and_rebuild_if_dirty()


## Read-only GROWING-plot info card -- see growing_info_card.gd's header
## comment. Looks the plot up by id directly (GameEconomy has no public
## single-plot accessor -- _find_plot() is private -- so this mirrors
## GdxVillageBoard.kt's own `state.plots.find { it.id == id }` rather than
## adding new economy API surface for a single read-only lookup).
func _maybe_open_growing_info_card(plot_id: int) -> void:
	if plot_id < 0:
		return
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var plot: Plot = null
	for candidate: Plot in economy.state.plots:
		if candidate.id == plot_id:
			plot = candidate
			break
	if plot == null or plot.state.kind != PlotState.Kind.GROWING:
		return  # Stale pick racing a tick-driven rebuild -- nothing to show.
	var card: GrowingInfoCard = GrowingInfoCardScene.instantiate()
	card.configure(plot.state.crop)
	hud.get_bottom_sheet().open(card)


## Rotate/Flip/Remove card for a tapped decoration -- ports
## GdxVillageBoard.kt's decoration tap branch (GdxSelection with
## onRotate/onFlip/onRemove, no onAction since decorations aren't
## manageable via a sheet). EPIC-M5 parity pass -- decoration placement
## shipped in EPIC-M4 slice 3 without this; flagged as a follow-up there,
## closed here. Same BottomSheet-reuse architecture deviation
## growing_info_card.gd already established (see that file's header comment
## for the rationale) -- the Kotlin original floats this near the tapped
## tile; this port reuses the shared sheet instead.
func _open_decoration_info_card(decoration_id: int) -> void:
	if decoration_id < 0:
		return
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var decoration: Decoration = null
	for candidate: Decoration in economy.state.decorations:
		if candidate.id == decoration_id:
			decoration = candidate
			break
	if decoration == null:
		return  # Stale pick racing a tick-driven rebuild -- nothing to show.
	var card: DecorationInfoCard = DecorationInfoCardScene.instantiate()
	card.configure(decoration.type, decoration_id, economy, _village_board, hud.get_bottom_sheet())
	hud.get_bottom_sheet().open(card)


## Opens the matching management sheet for a tapped ZONE, via the same
## HUD-owned shared BottomSheet _maybe_open_seed_picker() reuses above.
## All 6 zone kinds now have a sheet (EPIC-M4 slice 3 complete): Farmhouse,
## Mandi, Polyhouse, Agroforestry each open their own; Aquaculture and
## Vertical Farm both open the same combined NicheFarmingTab (matching the
## real shipped app's single `IsoSheet.Niche` for both zones).
## Fires regardless of the zone's lock state (a locked Mandi is still tap-
## pickable -- village_board.gd's _build_zone() gives every has_building
## zone a PickArea even while locked) -- each sheet's own configure()/
## _populate() is responsible for showing a build/register card instead of
## its unlocked content when the relevant `state.has_*` flag is false.
##
## A GROWING plot tap opens GrowingInfoCard (read-only emoji/name/sell-price,
## see that file's header comment on why it's a BottomSheet card here rather
## than the Kotlin original's floating screen-space overlay) -- the last of
## the tap-dispatch gaps flagged during EPIC-M4 slice 2/3, now closed.
func _maybe_open_zone_sheet(zone_id: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	match zone_id:
		VillageSnapshotMapper.ZONE_ID_FARMHOUSE:
			var tab: FarmhouseTab = FarmhouseTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		VillageSnapshotMapper.ZONE_ID_MANDI:
			var tab: MandiTab = MandiTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		VillageSnapshotMapper.ZONE_ID_POLYHOUSE:
			var tab: PolyhouseTab = PolyhouseTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		VillageSnapshotMapper.ZONE_ID_AGROFORESTRY:
			var tab: AgroforestryTab = AgroforestryTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		VillageSnapshotMapper.ZONE_ID_AQUACULTURE, VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM:
			# Both zones open the SAME combined sheet -- matches the real
			# shipped app exactly (IsoSheet.Niche is one sheet for both).
			var tab: NicheFarmingTab = NicheFarmingTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		VillageSnapshotMapper.ZONE_ID_OPEN_FIELD:
			# EPIC-M7: Open Field previously had no zone-level sheet at all
			# (plot taps already handle planting/harvesting directly) --
			# now hosts worker-assignment UI, see open_field_tab.gd.
			var tab: OpenFieldTab = OpenFieldTabScene.instantiate()
			tab.configure(economy, _village_board)
			hud.get_bottom_sheet().open(tab)
		_:
			pass


## Vector3 world-space hit, or null if the ray is parallel to the ground
## plane (should not happen at this board's fixed camera pitch, but
## Plane.intersects_ray() can return null, so this is handled rather than
## assumed away).
func _ground_hit(screen_pos: Vector2) -> Variant:
	var camera := _camera_rig.get_camera()
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return GROUND_PLANE.intersects_ray(from, dir)


# ---------------------------------------------------------------------------
# Audio pass -- see audio_manager.gd's class doc. Shared one-line helper so
# every call site above stays a single line, matching this file's existing
# "small private helper, reused everywhere" style.
# ---------------------------------------------------------------------------

func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)
