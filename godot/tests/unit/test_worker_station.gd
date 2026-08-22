extends GutTest
## Coverage for WorkerStation (godot/scripts/village_board/worker_station.gd)
## -- a real gap found 2026-08-23: this class had zero test coverage, not
## even indirectly, despite owning real logic (position, character
## instancing, the deliberate held-pose animation). Found while reasoning
## through whether the same day's villager.gd loop_mode fix
## (_force_every_clip_to_loop()) could affect this class's own
## paused-immediately-after-play use of the exact same Walking_A clip --
## reasoned it wouldn't (loop_mode only governs what happens when a clip
## reaches its end on its own; an explicitly .pause()-frozen player never
## gets there), but that reasoning had never actually been tested until now.

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


## Regression guard for the held-pose design decision (see this file's own
## HELD_POSE_CLIP comment): a stationed worker must read as standing, not
## as a walk cycle silently looping in place while the character never
## actually moves.
func test_setup_pauses_the_animation_player_immediately() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3.ZERO, "mage")

	var anim_player := station.get_villager().get_animation_player()
	assert_false(anim_player.is_playing(), "a stationed worker's animation must be paused, not actively playing/looping")


## The actual regression this file exists to guard: confirms the
## 2026-08-23 loop_mode fix (villager.gd's _force_every_clip_to_loop(),
## which sets every clip -- including Walking_A -- to Animation.LOOP_LINEAR)
## does not un-pause or otherwise disturb this class's own explicit
## .pause() call. Proven empirically here rather than left as unverified
## reasoning in a comment.
func test_held_pose_is_unaffected_by_the_walk_clips_loop_mode() -> void:
	var station := STATION_SCENE.instantiate() as WorkerStation
	add_child_autofree(station)

	station.setup(Vector3.ZERO, "barbarian")

	var villager := station.get_villager()
	var anim_player := villager.get_animation_player()
	var library := anim_player.get_animation_library(Villager.ANIMATION_LIBRARY_KEY)
	var walking_clip: Animation = library.get_animation(WorkerStation.HELD_POSE_CLIP)
	assert_eq(walking_clip.loop_mode, Animation.LOOP_LINEAR, "precondition: this clip really is loop-forced now, not testing a stale assumption")
	assert_false(anim_player.is_playing(), "even though its own clip now loops, the station's explicit pause() must still hold -- loop_mode only matters when a clip reaches its end unattended, which a paused player never does")
