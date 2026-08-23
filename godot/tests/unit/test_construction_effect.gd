extends GutTest
## Coverage for ConstructionEffect (godot/scripts/village_board/
## construction_effect.gd) -- the transient "worker is building it" flourish
## shipped 2026-08-23. Same shape as test_worker_station.gd (real scene,
## setup()'s immediate/synchronous guarantees), plus coverage for the
## despawn Timer WorkerStation doesn't have, since this component's whole
## point is disappearing on its own after DURATION_SECONDS.

const EFFECT_SCENE: PackedScene = preload("res://scenes/village_board/construction_effect.tscn")


func test_setup_positions_the_effect_at_the_given_world_position() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)

	effect.setup(Vector3(3.0, 0.0, -2.0), "mage")

	assert_eq(effect.position, Vector3(3.0, 0.0, -2.0))


func test_setup_creates_a_villager_child_with_the_given_character() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)

	effect.setup(Vector3.ZERO, "knight")

	var villager := effect.get_villager()
	assert_not_null(villager, "setup() must build a real Villager child")
	assert_not_null(villager.get_animation_player(), "the villager itself must be fully set up, not a bare instance")


## Regression guard mirroring test_worker_station.gd's own working-pose
## test, but for Interact -- see villager.gd's WORK_CLIP_NAMES doc comment
## for why this deliberately uses a different clip from WorkerStation's
## PickUp.
func test_setup_plays_the_construction_pose_animation() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)

	effect.setup(Vector3.ZERO, "ranger")

	var anim_player := effect.get_villager().get_animation_player()
	assert_true(anim_player.is_playing(), "the construction flourish must be actively animating")
	assert_true(
		anim_player.current_animation.ends_with(ConstructionEffect.CONSTRUCTION_POSE_CLIP),
		"must play Interact, not whatever Villager.setup()'s own default animation was"
	)


## The actual regression this file exists to guard: the flourish must
## eventually disappear on its own, not linger forever -- a one-shot Timer
## sized to DURATION_SECONDS, not the "waits for the player to explicitly
## unassign" contract WorkerStation has.
func test_setup_starts_a_one_shot_despawn_timer_sized_to_duration() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)

	effect.setup(Vector3.ZERO, "rogue")

	var timer := effect.get_despawn_timer()
	assert_not_null(timer, "setup() must create the despawn timer")
	assert_true(timer.one_shot, "must not repeat -- this is a single flourish, not a looping cycle")
	assert_almost_eq(timer.wait_time, ConstructionEffect.DURATION_SECONDS, 0.001)
	assert_false(timer.is_stopped(), "the timer must actually be running after setup(), not just configured")


## Proves the timer really does free the node when it fires, rather than
## just being configured correctly and trusted to work -- same
## "proven empirically, not left as an assumption" bar
## test_worker_station.gd's own loop-mode regression test holds itself to.
func test_when_the_timer_fires_the_effect_frees_itself() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)
	effect.setup(Vector3.ZERO, "rogue_hooded")

	effect.get_despawn_timer().timeout.emit()
	await get_tree().process_frame

	assert_false(is_instance_valid(effect), "queue_free() triggered by the timer's timeout must actually remove the node")


## The real regression this file needs: the timer must fire ON ITS OWN
## after real time passes, not just when manually emitted (the test above
## only proves the *connection* is correct, not that the timer actually
## counts down in a live tree -- found necessary after an on-device check
## showed the effect NOT despawning after well over DURATION_SECONDS).
func test_the_timer_actually_fires_after_real_time_passes() -> void:
	var effect := EFFECT_SCENE.instantiate() as ConstructionEffect
	add_child_autofree(effect)
	effect.setup(Vector3.ZERO, "knight")

	await get_tree().create_timer(ConstructionEffect.DURATION_SECONDS + 1.0).timeout

	assert_false(is_instance_valid(effect), "the despawn timer must fire on its own well within DURATION_SECONDS + 1s -- if this fails, the timer is configured but never actually counting down")
