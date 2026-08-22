## Covers DecorationInfoCard's Rotate/Flip/Remove buttons -- a gap found
## 2026-08-23: this card is repeatedly cited BY OTHER test files' own
## comments as "the established precedent" for the "drive the real node,
## not just call the economy method" testing standard
## (growing_info_card.gd/villager_info_card.gd/chanda_visitor.gd's own
## header comments all reference it) -- but the precedent-setter itself
## had zero test coverage. These are real, save-mutating gameplay actions
## (Remove genuinely deletes the player's placed decoration), not cosmetic
## flavor text, making this a real gap worth more than most.
extends GutTest

const DecorationInfoCardScene := preload("res://scenes/ui/decoration_info_card.tscn")
const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")
const BottomSheetScene := preload("res://scenes/ui/bottom_sheet.tscn")


func before_each() -> void:
	# Same test-isolation rationale as every other test that instantiates
	# a real VillageBoard (see RealSavePaths' own doc comment) -- this
	# file's tests genuinely persist real economy mutations to disk.
	RealSavePaths.wipe_all()


func after_each() -> void:
	RealSavePaths.wipe_all()


func _find_button_with_text(node: Node, substring: String) -> Button:
	if node is Button and (node as Button).text.contains(substring):
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, substring)
		if found:
			return found
	return null


## Rotate/Flip are glyph-only circular buttons whose own Button.text is
## always "" -- UiTheme.make_circular_emoji_button() renders the glyph via
## a child Label instead (see that function's own body). Located by
## searching each Button's descendants for a Label with the exact glyph
## text, not the Button's own (always-empty) text property.
func _find_button_with_descendant_label_text(node: Node, text: String) -> Button:
	if node is Button and _has_descendant_label_with_text(node, text):
		return node
	for child in node.get_children():
		var found := _find_button_with_descendant_label_text(child, text)
		if found:
			return found
	return null


func _has_descendant_label_with_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_descendant_label_with_text(child, text):
			return true
	return false


func _build_wired_card(board: VillageBoard, decoration_id: int) -> Dictionary:
	var economy := board.get_economy()
	var sheet := BottomSheetScene.instantiate() as BottomSheet
	add_child_autofree(sheet)
	var card: DecorationInfoCard = DecorationInfoCardScene.instantiate()
	card.configure(DecorationType.Kind.LANTERN, decoration_id, economy, board, sheet)
	sheet.open(card)
	return {"economy": economy, "sheet": sheet, "card": card}


func _place_a_real_decoration(economy: GameEconomy) -> int:
	economy.state.coins = 1_000_000
	var next_id := economy.state.next_decoration_id
	economy.place_decoration(DecorationType.Kind.LANTERN, 3.0, 4.0)
	return next_id


func test_pressing_rotate_advances_the_real_decorations_rotation() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	var decoration_id := _place_a_real_decoration(economy)
	var built := _build_wired_card(board, decoration_id)
	var rotate_button := _find_button_with_descendant_label_text(built["card"], "↻")
	assert_not_null(rotate_button, "expected a real Rotate button")

	rotate_button.pressed.emit()

	var decoration := _find_decoration(economy, decoration_id)
	assert_eq(decoration.rotation_degrees, 90, "the real button press must rotate the real decoration, not just look clickable")


func test_pressing_flip_toggles_the_real_decorations_flipped_state() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	var decoration_id := _place_a_real_decoration(economy)
	var built := _build_wired_card(board, decoration_id)
	var flip_button := _find_button_with_descendant_label_text(built["card"], "⇋")
	assert_not_null(flip_button, "expected a real Flip button")
	assert_false(_find_decoration(economy, decoration_id).flipped_x, "precondition")

	flip_button.pressed.emit()

	assert_true(_find_decoration(economy, decoration_id).flipped_x)


func test_pressing_rotate_reopens_the_card_in_place_rather_than_closing_the_sheet() -> void:
	# design/decoration_info_card.gd's own DESIGN CALL: Rotate/Flip must
	# NOT close the sheet, unlike Remove -- verified directly rather than
	# assumed from the comment.
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	var decoration_id := _place_a_real_decoration(economy)
	var built := _build_wired_card(board, decoration_id)
	var rotate_button := _find_button_with_descendant_label_text(built["card"], "↻")

	rotate_button.pressed.emit()

	var sheet: BottomSheet = built["sheet"]
	assert_eq(sheet.get_state(), BottomSheet.State.OPEN, "Rotate must re-populate in place, not close the sheet")


func test_pressing_remove_deletes_the_real_decoration_and_closes_the_sheet() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	var decoration_id := _place_a_real_decoration(economy)
	assert_not_null(_find_decoration(economy, decoration_id), "precondition: the decoration must actually exist first")
	var built := _build_wired_card(board, decoration_id)
	var remove_button := _find_button_with_text(built["card"], tr(&"decoration_info.remove_button"))
	assert_not_null(remove_button, "expected a real Remove button")

	remove_button.pressed.emit()

	assert_null(_find_decoration(economy, decoration_id), "Remove must genuinely delete the decoration from real economy state")
	var sheet: BottomSheet = built["sheet"]
	assert_eq(sheet.get_state(), BottomSheet.State.CLOSED, "unlike Rotate/Flip, Remove must close the sheet")


func _find_decoration(economy: GameEconomy, id: int) -> Decoration:
	for decoration: Decoration in economy.state.decorations:
		if decoration.id == id:
			return decoration
	return null
