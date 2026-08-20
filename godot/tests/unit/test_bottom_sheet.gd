## Covers BottomSheet's open/close state machine -- the reusable UI shell
## every future EPIC-M4 management/picker sheet will build on (see
## bottom_sheet.gd's header comment). Visual/animation timing (the slide
## Tween) is explicitly NOT covered here per this project's testing
## standards (.claude/docs/coding-standards.md: "Visual/Feel" stories get
## screenshot evidence, not automated tests) -- only the synchronous state
## transitions and content-ownership behavior open()/close() guarantee
## regardless of animation.
extends GutTest

const BottomSheetScene := preload("res://scenes/ui/bottom_sheet.tscn")


func test_starts_closed() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	assert_eq(sheet.get_state(), BottomSheet.State.CLOSED)
	assert_false(sheet.is_open())


func test_open_sets_state_open_and_reparents_content() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	var content := Label.new()
	sheet.open(content)
	assert_eq(sheet.get_state(), BottomSheet.State.OPEN)
	assert_true(sheet.is_open())
	assert_eq(content.get_parent(), sheet.get_node("SheetPanel/ContentSlot"))


func test_close_sets_state_closed() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	sheet.open(Label.new())
	sheet.close()
	assert_eq(sheet.get_state(), BottomSheet.State.CLOSED)
	assert_false(sheet.is_open())


func test_close_when_already_closed_is_a_safe_no_op() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	sheet.close()
	assert_eq(sheet.get_state(), BottomSheet.State.CLOSED)


func test_reopening_with_new_content_frees_the_previous_content() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	var first := Label.new()
	var second := Label.new()
	sheet.open(first)
	sheet.open(second)
	assert_eq(second.get_parent(), sheet.get_node("SheetPanel/ContentSlot"))
	# open() synchronously remove_child()s the stale content before
	# queue_free()ing it (see bottom_sheet.gd), so this is true immediately,
	# not only after the current frame ends.
	assert_null(first.get_parent())


func test_reopening_with_the_same_content_instance_does_not_duplicate_it() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	var content := Label.new()
	sheet.open(content)
	var slot: Node = content.get_parent()
	sheet.open(content)
	assert_eq(content.get_parent(), slot)
	assert_eq(slot.get_child_count(), 1)


func test_reopen_after_close_returns_to_open_state() -> void:
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())
	sheet.open(Label.new())
	sheet.close()
	sheet.open(Label.new())
	assert_eq(sheet.get_state(), BottomSheet.State.OPEN)
