extends GutTest
## Structural regression coverage for the EPIC-M6 villager retargeting +
## palette-recolor component (godot/scripts/village_board/villager.gd).
## Cannot verify visual appearance headlessly beyond a per-pixel hue scan
## (see test_setup_recolors_the_blue_accent_out_of_the_ranger_texture) --
## the actual look was confirmed on a real GPU via a windowed render, see
## production/session-state/active.md's 2026-08-21 entries. These tests
## guard the wiring: the shared "Rig_Medium" animation library must keep
## resolving onto every character's own AnimationPlayer, and the accent
## recolor must keep actually removing the blue accent color.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")


func test_setup_default_character_creates_animation_player() -> void:
	var villager := VILLAGER_SCENE.instantiate() as Villager
	add_child_autofree(villager)
	villager.setup()

	assert_not_null(villager.get_animation_player(), "expected an AnimationPlayer after setup()")


func test_setup_default_character_plays_default_animation() -> void:
	var villager := VILLAGER_SCENE.instantiate() as Villager
	add_child_autofree(villager)
	villager.setup()

	var anim_player := villager.get_animation_player()
	assert_eq(String(anim_player.current_animation), "moves/Walking_A")


func test_every_character_key_wires_the_movement_library_without_error() -> void:
	for character_key in Villager.CHARACTER_SCENES.keys():
		var villager := VILLAGER_SCENE.instantiate() as Villager
		add_child_autofree(villager)
		villager.setup(character_key)

		var anim_player := villager.get_animation_player()
		assert_not_null(anim_player, "character '%s' should get an AnimationPlayer" % character_key)
		assert_true(
			anim_player.has_animation("moves/Walking_A"),
			"character '%s' should have the shared Walking_A clip" % character_key
		)


func test_setup_recolors_the_blue_accent_out_of_the_ranger_texture() -> void:
	# Arrange -- hue range/threshold mirrors villager.gd's own
	# _ACCENT_HUE_MIN/_ACCENT_HUE_MAX/_ACCENT_MIN_SATURATION constants
	# (duplicated here deliberately: this test should fail if the
	# implementation's recolor range ever drifts, not silently pass by
	# reading the same constants back).
	var villager := VILLAGER_SCENE.instantiate() as Villager
	add_child_autofree(villager)

	# Act
	villager.setup("ranger")

	# Assert -- no mesh part's albedo texture should still contain a
	# strongly-saturated blue pixel (the original neckerchief accent color)
	# after the recolor pass.
	var mesh_instance := _find_first_mesh_instance(villager)
	assert_not_null(mesh_instance, "expected the instanced character to contain a MeshInstance3D")
	var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(mat, "expected a recolored surface override material")
	var image := mat.albedo_texture.get_image()
	var found_blue_pixel := false
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a >= 0.05 and c.s >= 0.30 and c.h >= 0.50 and c.h <= 0.74:
				found_blue_pixel = true
				break
		if found_blue_pixel:
			break
	assert_false(found_blue_pixel, "expected no saturated blue pixels left in the recolored texture")


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


## design/gdd/richer-ambient-villagers.md -- Idle_A/Idle_B, merged in from
## Rig_Medium_General.glb, must resolve through the same "moves/X" lookup
## Walking_A etc. already use, for every character (same shared-skeleton
## guarantee test_every_character_key_wires_the_movement_library_without_error()
## already checks for the movement clips).
func test_every_character_key_wires_the_idle_clips_without_error() -> void:
	for character_key in Villager.CHARACTER_SCENES.keys():
		var villager := VILLAGER_SCENE.instantiate() as Villager
		add_child_autofree(villager)
		villager.setup(character_key)

		var anim_player := villager.get_animation_player()
		for clip_name in Villager.IDLE_CLIP_NAMES:
			assert_true(
				anim_player.has_animation("moves/%s" % clip_name),
				"character '%s' should have the shared %s clip" % [character_key, clip_name]
			)


func test_play_animation_can_switch_to_an_idle_clip() -> void:
	var villager := VILLAGER_SCENE.instantiate() as Villager
	add_child_autofree(villager)
	villager.setup()

	villager.play_animation("Idle_A")

	assert_eq(String(villager.get_animation_player().current_animation), "moves/Idle_A")


func test_play_animation_switches_clip() -> void:
	var villager := VILLAGER_SCENE.instantiate() as Villager
	add_child_autofree(villager)
	villager.setup()

	villager.play_animation("Running_A")

	assert_eq(String(villager.get_animation_player().current_animation), "moves/Running_A")


# Note: setup() with an unknown character key, and play_animation() with an
# unknown clip name, are both handled defensively (push_error + early
# return, no crash) but are not covered by an automated test here -- GUT's
# error tracker fails any test where push_error fires during the test body,
# and this version of the addon doesn't expose a documented "expect this
# error" API to whitelist it. Verified manually instead: both call sites
# were exercised by hand during development and confirmed to log a clear
# error and return without side effects, rather than throwing.
