## Covers CameraRig.compute_framing_distance() -- the pure function extracted
## from _compute_default_distance() for the 2026-08-22 landscape framing fix
## (see camera_rig.gd's doc comment on the function for the full rationale).
## Before this fix, the board was always framed to whichever axis needed
## more distance (max(depth-fit, width-fit)) -- correct for portrait, but in
## landscape this picks depth almost every time, leaving the wide viewport's
## surplus horizontal FOV as empty space on both sides of the board instead
## of board. The fix frames to width specifically when aspect > 1.0. These
## tests use fov_degrees=90 throughout so tan(45 deg)=1.0 and every expected
## distance is a clean, hand-checkable number.
extends GutTest


# --- landscape (aspect > 1.0): fills width, not depth ---------------------

func test_landscape_wide_viewport_frames_to_width_not_depth() -> void:
	# extents (30 x 10) => half_width=15, half_depth=5. At aspect 4.0:
	# distance_for_depth = 5 / tan(45) = 5
	# distance_for_width = 15 / (tan(45) * 4) = 3.75
	# Landscape (aspect > 1.0) should pick the width distance (3.75), not
	# the larger depth distance (5) that the old max()-based logic picked.
	var distance := CameraRig.compute_framing_distance(
		Vector2(30.0, 10.0), Vector2(1600.0, 400.0), 90.0, 1.0
	)
	assert_almost_eq(distance, 3.75, 0.0001)


func test_landscape_result_is_strictly_less_than_the_old_max_based_distance() -> void:
	# Regression guard: if this ever silently reverts to maxf(depth, width),
	# this test catches it even without hand-verifying the exact number --
	# the whole point of the fix is that landscape framing must end up
	# *closer* than depth-fit, not equal to it.
	var extents := Vector2(30.0, 10.0)
	var viewport := Vector2(1600.0, 400.0)
	var distance := CameraRig.compute_framing_distance(extents, viewport, 90.0, 1.0)
	var half_vfov_rad := deg_to_rad(90.0 / 2.0)
	var old_max_distance := maxf(
		(extents.y / 2.0) / tan(half_vfov_rad),
		(extents.x / 2.0) / (tan(half_vfov_rad) * (viewport.x / viewport.y))
	)
	assert_lt(distance, old_max_distance)


# --- portrait / square (aspect <= 1.0): unchanged max()-based fit ---------

func test_portrait_viewport_still_frames_to_the_stricter_axis() -> void:
	# Same board, tall/narrow viewport (aspect 0.25): width becomes the
	# stricter axis (60), matching the EPIC-M1 zero-pan-on-load guarantee
	# this project's primary (portrait) target relies on.
	var distance := CameraRig.compute_framing_distance(
		Vector2(30.0, 10.0), Vector2(400.0, 1600.0), 90.0, 1.0
	)
	assert_almost_eq(distance, 60.0, 0.0001)


func test_aspect_exactly_one_uses_the_max_branch_not_the_landscape_branch() -> void:
	# Boundary check: aspect == 1.0 must NOT take the landscape (width-only)
	# path -- the real check is a strict ">" (mirrors board_interactor.gd's
	# TAP_MAX_MOVEMENT_PX boundary test, per this project's testing standard
	# of pinning down the exact number at a boundary). Extents flipped
	# (10 x 30, half_width=5, half_depth=15) so the two branches would
	# disagree if the boundary were wrong: max-branch => 15, landscape-style
	# width-only => 5.
	var distance := CameraRig.compute_framing_distance(
		Vector2(10.0, 30.0), Vector2(500.0, 500.0), 90.0, 1.0
	)
	assert_almost_eq(distance, 15.0, 0.0001)


func test_zero_height_viewport_falls_back_to_square_aspect_not_landscape() -> void:
	# Degenerate viewport height (e.g. mid-resize) must fall back to aspect
	# 1.0, not divide-by-zero or accidentally read as "landscape".
	var distance := CameraRig.compute_framing_distance(
		Vector2(10.0, 30.0), Vector2(500.0, 0.0), 90.0, 1.0
	)
	assert_almost_eq(distance, 15.0, 0.0001)


# --- framing_margin is still applied multiplicatively ----------------------

func test_framing_margin_scales_the_landscape_result() -> void:
	var distance := CameraRig.compute_framing_distance(
		Vector2(30.0, 10.0), Vector2(1600.0, 400.0), 90.0, 1.2
	)
	assert_almost_eq(distance, 3.75 * 1.2, 0.0001)


func test_framing_margin_scales_the_portrait_result() -> void:
	var distance := CameraRig.compute_framing_distance(
		Vector2(30.0, 10.0), Vector2(400.0, 1600.0), 90.0, 1.2
	)
	assert_almost_eq(distance, 60.0 * 1.2, 0.0001)
