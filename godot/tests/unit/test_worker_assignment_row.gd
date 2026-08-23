## Covers worker_assignment_row.gd -- the reusable "assign/unassign a
## worker" UI section embedded in every worker-eligible zone's sheet
## (design/gdd/worker-economy.md). Uses a real VillageBoard scene (not a
## bare GameEconomy) because persist_and_rebuild_if_dirty() always
## operates on that board's own internal economy -- the `economy` passed
## to configure() must be board.get_economy() itself, the same
## constraint every real *_tab.gd caller already follows.
extends GutTest

const VILLAGE_BOARD_SCENE: PackedScene = preload("res://scenes/village_board/village_board.tscn")


func _make_row(board: VillageBoard, plot_kind: PlotKind.Kind) -> WorkerAssignmentRow:
	var row := WorkerAssignmentRow.new()
	add_child_autofree(row)
	row.configure(board.get_economy(), board, plot_kind)
	return row


## Recursive descendant search -- Track A wrapped this row's content in a
## UiTheme card (PanelContainer > VBoxContainer > ...), one level deeper
## than the fixed child/grandchild nesting these tests originally assumed.
## Searching the whole subtree keeps these tests robust to that kind of
## presentational restructuring rather than re-coupling them to an exact
## depth again.
func _has_descendant(root: Node, predicate: Callable) -> bool:
	for child in root.get_children():
		if predicate.call(child):
			return true
		if _has_descendant(child, predicate):
			return true
	return false


func test_unassigned_zone_shows_an_option_button_and_assign_button() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	board.get_economy().unassign_worker(PlotKind.Kind.OPEN_FIELD)  # normalize -- see other tests' precedent

	var row := _make_row(board, PlotKind.Kind.OPEN_FIELD)

	var found_option_button := _has_descendant(row, func(n: Node) -> bool: return n is OptionButton)
	var found_assign_button := _has_descendant(
		row, func(n: Node) -> bool: return n is Button and n.text == "Assign"
	)
	assert_true(found_option_button)
	assert_true(found_assign_button)


func test_pressing_assign_assigns_the_selected_character() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	board.get_economy().unassign_worker(PlotKind.Kind.OPEN_FIELD)

	var row := _make_row(board, PlotKind.Kind.OPEN_FIELD)
	row._on_assign_pressed()  # default OptionButton selection is index 0 ("Ramesh")

	var assignment := board.get_economy().get_worker_assignment(PlotKind.Kind.OPEN_FIELD)
	assert_not_null(assignment)
	assert_eq(assignment.character_key, "barbarian")


func test_assigned_zone_shows_a_status_label_and_unassign_button() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	board.get_economy().assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	var row := _make_row(board, PlotKind.Kind.OPEN_FIELD)

	var found_status_label := _has_descendant(
		row, func(n: Node) -> bool: return n is Label and n.text.contains("Vijay")
	)
	var found_unassign_button := _has_descendant(
		row, func(n: Node) -> bool: return n is Button and n.text == "Unassign"
	)
	assert_true(found_status_label)
	assert_true(found_unassign_button)


func test_pressing_unassign_clears_the_assignment() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	board.get_economy().assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	var row := _make_row(board, PlotKind.Kind.OPEN_FIELD)
	row._on_unassign_pressed()

	assert_false(board.get_economy().has_worker_assigned(PlotKind.Kind.OPEN_FIELD))


func test_assigning_updates_the_boards_worker_station() -> void:
	# End-to-end through the row's own handler, not just the economy call
	# directly -- confirms this UI component actually drives the visual
	# stationing built earlier, not just the persisted assignment.
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	board.get_economy().unassign_worker(PlotKind.Kind.OPEN_FIELD)
	board.persist_and_rebuild_if_dirty()

	var row := _make_row(board, PlotKind.Kind.OPEN_FIELD)
	row._on_assign_pressed()

	assert_not_null(board.get_worker_station(PlotKind.Kind.OPEN_FIELD))
