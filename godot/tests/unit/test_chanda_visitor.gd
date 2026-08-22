extends GutTest
## Coverage for ChandaVisitor (godot/scripts/village_board/chanda_visitor.gd)
## -- construction/positioning/PickArea wiring for design/gdd/festival-
## visiting-npcs.md's board-NPC stretch (decided and built 2026-08-22).
## Mirrors test_villager_roamer.gd's construction-test shape.

const VISITOR_SCENE: PackedScene = preload("res://scenes/village_board/chanda_visitor.tscn")


func test_setup_positions_the_visitor_at_the_given_tile_world_position() -> void:
	var visitor := VISITOR_SCENE.instantiate() as ChandaVisitor
	add_child_autofree(visitor)

	visitor.setup("ranger", Vector2i(1, 1), 3, 3, 1.0)

	# grid_cols=3 -> center col is 1 -> world x = (1 - 1) * 1.0 = 0
	assert_almost_eq(visitor.position.x, 0.0, 0.001)
	assert_almost_eq(visitor.position.z, 0.0, 0.001)


func test_setup_spawns_a_villager_child_playing_the_idle_clip() -> void:
	var visitor := VISITOR_SCENE.instantiate() as ChandaVisitor
	add_child_autofree(visitor)

	visitor.setup("knight", Vector2i(0, 0), 3, 3, 1.0)

	var villager := visitor.get_node("Villager") as Villager
	assert_not_null(villager, "setup() must build a real Villager child")
	var anim_player := villager.get_animation_player()
	assert_true(
		anim_player.current_animation.ends_with(ChandaVisitor.IDLE_CLIP),
		"the visitor must stand idle, not mid-walk-cycle"
	)


func test_setup_builds_a_pick_area_tagged_as_a_chanda_visitor() -> void:
	var visitor := VISITOR_SCENE.instantiate() as ChandaVisitor
	add_child_autofree(visitor)

	visitor.setup("mage", Vector2i(0, 0), 3, 3, 1.0)

	var pick_area := visitor.get_node("PickArea") as Area3D
	assert_not_null(pick_area)
	assert_eq(pick_area.collision_layer, VillageBoard.PICK_LAYER_VILLAGERS)
	assert_eq(pick_area.get_meta("board_kind"), "chanda_visitor")
	assert_eq(pick_area.get_meta("board_id"), "mage")
	assert_eq(visitor.character_key, "mage")
