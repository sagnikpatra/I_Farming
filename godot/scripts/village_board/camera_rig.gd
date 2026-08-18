## Camera rig for the village board. Computes default framing from the
## board's actual bounds (not a hardcoded guess) so the whole bounded
## playfield is visible at a readable angle by default (fixes root cause #1:
## content span vs. viewport mismatch). Aspect-ratio-aware -- recomputes
## against get_viewport()'s actual size, since this project's target is a
## narrow portrait phone viewport where horizontal FOV is much tighter than
## vertical at a given Camera3D.fov.
##
## EPIC-M3: now owns real pan/zoom state (previously pan_min/pan_max were
## computed once and never wired to input, by deliberate EPIC-M1 decision).
## pan_by()/zoom_by() are the only mutators BoardInteractor calls -- this
## script still contains zero input handling of its own (see
## board_interactor.gd's header comment for why input is deliberately
## consolidated into one script).
##
## Pan bounds are now zoom-aware: at the fully-zoomed-out default distance
## the whole board already fits on screen, so pan bounds collapse to a
## single point (no panning possible or needed); zooming in shrinks the
## visible ground-plane footprint and pan bounds grow to let the player
## reach every edge of the board without ever revealing space beyond the
## boundary fence. This was flagged as a known simplification to revisit in
## this file's EPIC-M1 header comment -- resolved here.
class_name CameraRig
extends Node3D

## Downward pitch of the camera, degrees -- isometric-ish angle for a
## readable whole-board view.
const PITCH_DEGREES: float = 50.0
## Must match the child Camera3D's fov property (vertical FOV).
const CAMERA_FOV_DEGREES: float = 50.0
## >1.0 = extra breathing room around the board so it doesn't touch viewport edges.
const FRAMING_MARGIN: float = 1.18
## How far in the player can zoom, as a fraction of the fully-zoomed-out
## default distance (e.g. 0.42 lets the camera get roughly 2.4x closer).
## Zooming out past the default distance is intentionally not allowed --
## the default framing already shows the whole bounded board, so zooming
## out further would only reveal empty space beyond the boundary fence,
## reintroducing the "content span vs. viewport" problem EPIC-M1 fixed.
const MIN_ZOOM_SCALE: float = 0.42

@onready var _camera: Camera3D = $Camera3D

var pan_min: Vector2 = Vector2.ZERO
var pan_max: Vector2 = Vector2.ZERO

var _board_center: Vector3 = Vector3.ZERO
var _board_extents: Vector2 = Vector2.ZERO
var _distance: float = 0.0
var _min_distance: float = 0.0
var _max_distance: float = 0.0
var _pan_target: Vector2 = Vector2.ZERO


## Frames the camera to show the full board (center + world-space XZ extents),
## resets zoom to fully-zoomed-out and pan to centered, and (re)computes the
## pan-clamp bounds. Called once by VillageBoard.rebuild().
func frame_bounds(center: Vector3, extents: Vector2) -> void:
	_board_center = center
	_board_extents = extents
	_max_distance = _compute_default_distance(extents)
	_distance = _max_distance
	_min_distance = _max_distance * MIN_ZOOM_SCALE
	_pan_target = Vector2(center.x, center.z)
	_recompute_pan_bounds()
	_apply_camera_transform()


func get_camera() -> Camera3D:
	return _camera


## Pans the rig by a world-space XZ delta (already in world units, e.g. the
## difference between two ground-plane ray hits -- see
## BoardInteractor._pan_camera_by_screen_delta()), clamped to the current
## zoom level's pan bounds.
func pan_by(world_delta: Vector2) -> void:
	_pan_target = clamp_pan_position(_pan_target + world_delta)
	_apply_camera_transform()


## Multiplies the current zoom distance by 1/factor (factor > 1.0 = zoom in,
## i.e. fingers spreading apart in a pinch; factor < 1.0 = zoom out), clamped
## to [MIN_ZOOM_SCALE * default, default]. Recomputes pan bounds and re-clamps
## the current pan target, since zooming out can make a previously-valid pan
## position fall outside the new (tighter) bounds.
func zoom_by(factor: float) -> void:
	if factor <= 0.0 or not is_finite(factor):
		return
	_distance = clampf(_distance / factor, _min_distance, _max_distance)
	_recompute_pan_bounds()
	_pan_target = clamp_pan_position(_pan_target)
	_apply_camera_transform()


func clamp_pan_position(target: Vector2) -> Vector2:
	return Vector2(
		clampf(target.x, pan_min.x, pan_max.x),
		clampf(target.y, pan_min.y, pan_max.y)
	)


func _compute_default_distance(extents: Vector2) -> float:
	var half_width := extents.x / 2.0
	var half_depth := extents.y / 2.0

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 1.0

	var half_vfov_rad := deg_to_rad(CAMERA_FOV_DEGREES / 2.0)
	var distance_for_depth := half_depth / tan(half_vfov_rad)
	var distance_for_width := half_width / (tan(half_vfov_rad) * aspect)
	return maxf(distance_for_depth, distance_for_width) * FRAMING_MARGIN


## Recomputes pan_min/pan_max for the *current* _distance: the ground-plane
## half-extents actually visible in the camera frustum at this distance are
## subtracted from the board's half-extents, so the player can never pan far
## enough to see past the board's edge. Zoomed all the way out (_distance ==
## _max_distance), the visible footprint already covers the whole board and
## slack collapses to zero on both axes.
func _recompute_pan_bounds() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 1.0

	var half_vfov_rad := deg_to_rad(CAMERA_FOV_DEGREES / 2.0)
	var visible_half_depth := _distance * tan(half_vfov_rad)
	var visible_half_width := visible_half_depth * aspect

	var half_board_width := _board_extents.x / 2.0
	var half_board_depth := _board_extents.y / 2.0

	var slack_x := maxf(half_board_width - visible_half_width, 0.0)
	var slack_z := maxf(half_board_depth - visible_half_depth, 0.0)

	pan_min = Vector2(_board_center.x - slack_x, _board_center.z - slack_z)
	pan_max = Vector2(_board_center.x + slack_x, _board_center.z + slack_z)


func _apply_camera_transform() -> void:
	position = Vector3(_pan_target.x, _board_center.y, _pan_target.y)

	var pitch_rad := deg_to_rad(PITCH_DEGREES)
	var height := _distance * sin(pitch_rad)
	var back_offset := _distance * cos(pitch_rad)
	_camera.position = Vector3(0.0, height, back_offset)
	_camera.look_at(global_position, Vector3.UP)
