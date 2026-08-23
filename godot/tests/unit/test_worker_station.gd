extends GutTest
## Coverage for WorkerStation (godot/scripts/village_board/worker_station.gd)
## -- a real gap found 2026-08-23: this class had zero test coverage, not
## even indirectly, despite owning real logic (position, character
## instancing, the working-pose animation). Originally covered a
## paused-held-pose design (Walking_A frozen on its first frame, read as a
## T-pose-ish frozen stance); replaced the same day after a real on-device
## report ("workers stand in a T shape, no work is showing") with a real
## looping PickUp clip -- see worker_station.gd's own WORKING_POSE_CLIP doc
## comment. The tests below cover the CURRENT behavior, not the retired one.

const STATION_SCENE: PackedScene = preload("res://scenes/village_board/worker_station.tscn")


func test_setup_positions_the_station_at_the_given_world_position() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3(2.0, 0.0, -1.5), "ranger")

	assert_eq(station.position, Vector3(2.0, 0.0, -1.5))


func test_setup_creates_a_villager_child_with_the_given_character() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3.ZERO, "knight")

	var villager := station.get_villager()
	assert_not_null(villager, "setup() must build a real Villager child")
	assert_not_null(villager.get_animation_player(), "the villager itself must be fully set up, not a bare instance")


## Regression guard for design/gdd/worker-economy.md rule 6 ("performing a
## work-appropriate pose/animation"): a stationed worker must be visibly
## active, not frozen/paused -- the direct fix for the "workers stand in a
## T shape, no work is showing" report.
func test_setup_plays_the_working_pose_animation() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3.ZERO, "mage")

	var anim_player := station.get_villager().get_animation_player()
	assert_true(anim_player.is_playing(), "a stationed worker must be actively animating, not paused/frozen")
	assert_true(
		anim_player.current_animation.ends_with(WorkerStation.WORKING_POSE_CLIP),
		"must be playing the real working-pose clip, not left on whatever Villager.setup()'s own default animation was"
	)


## The actual regression this file exists to guard: the working-pose clip
## must actually loop rather than play once and freeze -- the same "frozen
## mid-cycle" defect villagers.md's Acceptance Criteria already flags for
## walking/idling, now guarded for the working pose too. Proven empirically
## here rather than left as unverified reasoning in a comment.
func test_working_pose_clip_is_loop_forced() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3.ZERO, "barbarian")

	var villager := station.get_villager()
	var anim_player := villager.get_animation_player()
	var library := anim_player.get_animation_library(Villager.ANIMATION_LIBRARY_KEY)
	var working_clip: Animation = library.get_animation(WorkerStation.WORKING_POSE_CLIP)
	assert_eq(
		working_clip.loop_mode, Animation.LOOP_LINEAR,
		"villager.gd's _force_every_clip_to_loop() must cover this merged clip too, not just Walking_A/B/C and Idle_A/B -- otherwise the worker plays PickUp once and freezes"
	)
