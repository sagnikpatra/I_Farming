## Covers OpenFieldTab (open_field_tab.gd) -- the smallest of this
## project's zone sheets, added for EPIC-M7 solely to host worker
## assignment UI (Open Field has no build/upgrade content of its own, and
## no zone-level PickArea to reach a sheet through in the first place --
## see hud.gd's "Field Worker" button). Unlike every other *_tab.gd, this
## file had no test coverage at all until this smoke-check pass found the
## gap -- there's no build_view_data()-style pure function to test (all
## real logic lives in WorkerAssignmentRow, already covered by
## test_worker_assignment_row.gd), so this is a construction smoke test:
## does the sheet actually build without erroring and contain the row it's
## supposed to host.
extends GutTest

const OPEN_FIELD_TAB_SCENE: PackedScene = preload("res://scenes/ui/open_field_tab.tscn")


func test_configure_and_ready_produces_a_worker_assignment_row() -> void:
	var eco := GameEconomy.new()
	var board := (preload("res://scenes/village_board/village_board.tscn") as PackedScene).instantiate() as VillageBoard
	add_child_autofree(board)

	var tab: OpenFieldTab = OPEN_FIELD_TAB_SCENE.instantiate()
	tab.configure(board.get_economy(), board)
	add_child_autofree(tab)  # triggers _ready() -> _populate()

	var found_row := false
	for child in tab.get_node("Scroll/Body").get_children():
		if child is WorkerAssignmentRow:
			found_row = true
	assert_true(found_row, "OpenFieldTab should host exactly one WorkerAssignmentRow")
