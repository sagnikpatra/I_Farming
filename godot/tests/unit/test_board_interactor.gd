## Covers BoardInteractor's gesture state machine -- specifically the 3 pure
## decision functions extracted from it (next_gesture_mode(),
## classify_tap_dispatch(), is_long_press_still_valid()), per
## production/qa/smoke-2026-08-21.md's flagged gap: "a genuinely complex
## Logic/Integration-type... 5-state gesture machine... no dedicated test
## file... real unit-testing this would mean extracting its gesture-
## resolution logic into pure functions." That extraction is what this file
## tests -- not a full input-simulation harness (the report's own larger,
## separately-scoped alternative), matching this codebase's established
## "extract the pure decision, test it directly" pattern (build_view_data(),
## AudioManager.pick_variant(), etc.), none of which need scene-tree
## instantiation either.
extends GutTest


# --- next_gesture_mode() -------------------------------------------------------

func test_next_gesture_mode_pending_tap_stays_pending_tap_under_threshold() -> void:
	var next := BoardInteractor.next_gesture_mode(
		BoardInteractor._Mode.PENDING_TAP, BoardInteractor.TAP_MAX_MOVEMENT_PX - 1.0
	)
	assert_eq(next, BoardInteractor._Mode.PENDING_TAP)


func test_next_gesture_mode_pending_tap_becomes_panning_camera_over_threshold() -> void:
	var next := BoardInteractor.next_gesture_mode(
		BoardInteractor._Mode.PENDING_TAP, BoardInteractor.TAP_MAX_MOVEMENT_PX + 1.0
	)
	assert_eq(next, BoardInteractor._Mode.PANNING_CAMERA)


func test_next_gesture_mode_pending_tap_stays_pending_tap_exactly_at_threshold() -> void:
	# The real check is a strict ">" -- exactly at the threshold does not
	# yet count as a drag. Boundary-value test: the exact number IS the
	# point (per .claude/docs/coding-standards.md's stated exception to
	# "no hardcoded magic numbers" in tests).
	var next := BoardInteractor.next_gesture_mode(
		BoardInteractor._Mode.PENDING_TAP, BoardInteractor.TAP_MAX_MOVEMENT_PX
	)
	assert_eq(next, BoardInteractor._Mode.PENDING_TAP)


func test_next_gesture_mode_leaves_every_other_mode_unchanged() -> void:
	# next_gesture_mode() only ever makes the PENDING_TAP->PANNING_CAMERA
	# decision -- every other mode is a pure pass-through, decided
	# elsewhere (drag begin/end, pinch begin/end), not by this function.
	for mode: int in [
		BoardInteractor._Mode.IDLE,
		BoardInteractor._Mode.PANNING_CAMERA,
		BoardInteractor._Mode.DRAGGING_ZONE,
		BoardInteractor._Mode.DRAGGING_DECORATION,
	]:
		var next := BoardInteractor.next_gesture_mode(mode, 9999.0)
		assert_eq(next, mode, "mode %d should never be changed by next_gesture_mode()" % mode)


# --- classify_tap_dispatch() ----------------------------------------------------

func test_classify_tap_dispatch_normal_pick_when_nothing_armed() -> void:
	var result := BoardInteractor.classify_tap_dispatch(false, -1)
	assert_eq(result, BoardInteractor.TapDispatch.NORMAL_PICK)


func test_classify_tap_dispatch_armed_decoration_when_type_set() -> void:
	var result := BoardInteractor.classify_tap_dispatch(false, 2)
	assert_eq(result, BoardInteractor.TapDispatch.ARMED_DECORATION)


func test_classify_tap_dispatch_move_mode_when_active() -> void:
	var result := BoardInteractor.classify_tap_dispatch(true, -1)
	assert_eq(result, BoardInteractor.TapDispatch.MOVE_MODE)


func test_classify_tap_dispatch_move_mode_takes_precedence_over_armed_decoration() -> void:
	# set_move_mode_active(true) clears _armed_decoration_type in practice
	# (see that method's own doc comment), so both being simultaneously
	# true shouldn't happen -- but this function's own precedence is what
	# actually decides behavior if that invariant were ever violated, and
	# that precedence is worth pinning down explicitly rather than left
	# implicit.
	var result := BoardInteractor.classify_tap_dispatch(true, 5)
	assert_eq(result, BoardInteractor.TapDispatch.MOVE_MODE)


# --- is_long_press_still_valid() ------------------------------------------------

func test_is_long_press_still_valid_true_for_matching_request_still_pending() -> void:
	var valid := BoardInteractor.is_long_press_still_valid(1, 1, BoardInteractor._Mode.PENDING_TAP, false)
	assert_true(valid)


func test_is_long_press_still_valid_false_when_request_id_is_stale() -> void:
	# A newer touch has been scheduled since this timer fired -- e.g. the
	# player tapped, released, and tapped again before the first timer
	# elapsed.
	var valid := BoardInteractor.is_long_press_still_valid(1, 2, BoardInteractor._Mode.PENDING_TAP, false)
	assert_false(valid)


func test_is_long_press_still_valid_false_when_mode_already_changed() -> void:
	# The touch already resolved into a drag/pan/release before the timer
	# fired.
	var valid := BoardInteractor.is_long_press_still_valid(1, 1, BoardInteractor._Mode.PANNING_CAMERA, false)
	assert_false(valid)


func test_is_long_press_still_valid_false_when_move_mode_active() -> void:
	# Move mode is a tap-only alternative to long-press-drag -- see
	# is_long_press_still_valid()'s own doc comment on why a long press
	# must never also start a drag while it's armed.
	var valid := BoardInteractor.is_long_press_still_valid(1, 1, BoardInteractor._Mode.PENDING_TAP, true)
	assert_false(valid)
