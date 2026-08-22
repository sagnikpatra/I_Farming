## Real end-to-end proof for design/gdd/festival-visiting-npcs.md's
## board-NPC stretch: drives BoardInteractor's own _open_chanda_visit_sheet()
## -- the exact function the real ray-picking dispatch calls once a
## ChandaVisitor PickArea is hit (see board_interactor.gd's
## _release_primary_touch()) -- on a real scene wired the way main.tscn
## actually wires VillageBoard/HUD as named siblings. Same shape as
## test_villager_tap_interaction.gd for the analogous villager-tap feature.
extends GutTest

const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")


func _build_wired_board_interactor() -> BoardInteractor:
	RealSavePaths.wipe_all()
	var parent: Node = add_child_autofree(Node.new())
	var board: VillageBoard = VillageBoardScene.instantiate()
	board.name = "VillageBoard"
	parent.add_child(board)
	var hud: Hud = HudScene.instantiate()
	parent.add_child(hud)
	return board.get_board_interactor()


func test_tapping_the_chanda_visitor_opens_the_real_events_sheet() -> void:
	var interactor := _build_wired_board_interactor()

	interactor._open_chanda_visit_sheet()

	var hud := get_tree().get_first_node_in_group("hud") as Hud
	var sheet := hud.get_bottom_sheet()
	assert_eq(sheet.get_state(), BottomSheet.State.OPEN, "a chanda-visitor tap must open the real shared BottomSheet")
	assert_true(sheet._current_content is EventsTab, "it must be the real Events sheet, not a separate give/decline UI")


func test_opening_the_events_sheet_via_a_visitor_tap_matches_the_banners_own_path() -> void:
	# Tapping the board NPC must be a second entry point into the exact
	# same sheet the LiveOps banner opens, not a parallel/duplicate
	# construction -- both routes end up at Hud.open_events_sheet().
	var interactor := _build_wired_board_interactor()
	var hud := get_tree().get_first_node_in_group("hud") as Hud

	interactor._open_chanda_visit_sheet()
	var content_from_visitor_tap := hud.get_bottom_sheet()._current_content

	hud._on_liveops_banner_pressed()
	var content_from_banner := hud.get_bottom_sheet()._current_content

	assert_true(content_from_visitor_tap is EventsTab)
	assert_true(content_from_banner is EventsTab)
