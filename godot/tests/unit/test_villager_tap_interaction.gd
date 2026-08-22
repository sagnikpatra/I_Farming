## Real end-to-end proof for design/gdd/villagers.md rule 8's tap-
## interaction feature (2026-08-22): drives BoardInteractor's own
## _open_villager_info_card() -- the exact function the real ray-picking
## dispatch calls once a villager PickArea is hit (see
## board_interactor.gd's _release_primary_touch()) -- on a real scene
## wired the way main.tscn actually wires VillageBoard/HUD as named
## siblings, and confirms the real BottomSheet ends up showing the real
## card with the right content. Not a full ray-cast simulation (camera
## projection + a physics-server frame delay would make this fragile for
## marginal extra confidence) -- this project's own established pattern
## throughout 2026-08-22's session for exactly this class of feature
## (see test_toast_drain.gd's own header comment for the same call).
extends GutTest

const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")


func _find_label_with_text(node: Node, substring: String) -> Label:
	if node is Label and (node as Label).text.contains(substring):
		return node
	for child in node.get_children():
		var found := _find_label_with_text(child, substring)
		if found:
			return found
	return null


func _build_wired_board_interactor() -> BoardInteractor:
	var parent: Node = add_child_autofree(Node.new())
	var board: VillageBoard = VillageBoardScene.instantiate()
	board.name = "VillageBoard"
	parent.add_child(board)
	var hud: Hud = HudScene.instantiate()
	parent.add_child(hud)
	return board.get_board_interactor()


func test_opening_a_villager_info_card_shows_the_real_character_in_the_real_sheet() -> void:
	var interactor := _build_wired_board_interactor()

	interactor._open_villager_info_card("knight")

	var hud := get_tree().get_first_node_in_group("hud") as Hud
	var sheet := hud.get_bottom_sheet()
	assert_eq(sheet.get_state(), BottomSheet.State.OPEN, "a real villager tap must actually open the real shared BottomSheet")
	assert_not_null(_find_label_with_text(sheet, "Knight"), "the real sheet content must show the real tapped character's name")
	assert_not_null(_find_label_with_text(sheet, "Namaste"), "and the real greeting")


func test_opening_a_second_villager_info_card_replaces_the_first() -> void:
	var interactor := _build_wired_board_interactor()
	interactor._open_villager_info_card("barbarian")

	interactor._open_villager_info_card("mage")

	var hud := get_tree().get_first_node_in_group("hud") as Hud
	var sheet := hud.get_bottom_sheet()
	assert_not_null(_find_label_with_text(sheet, "Mage"))
	assert_null(_find_label_with_text(sheet, "Barbarian"), "the first card's content must be gone, not stacked underneath")
