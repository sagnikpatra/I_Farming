class_name WorkerStation
extends Node3D
## Renders one assigned worker stood at a fixed world position -- the
## "called" half of design/gdd/villagers.md §3.6, as opposed to
## VillagerRoamer's ambient "idle" roaming. Does not move; owned/spawned
## by village_board.gd's _sync_worker_stations(), one per active
## GameState.worker_assignments entry.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")

## Held pose: Walking_A, paused immediately after starting, rather than
## either the rig's T-pose rest bind or a walk cycle visibly looping in
## place while stationary. Known minor polish item, not a dedicated
## "working" animation -- this asset's animation library has no such clip
## (villagers.md Detailed Rules §3.4 already notes the same gap for
## ambient roaming's lack of an idle clip).
const HELD_POSE_CLIP: String = "Walking_A"

var _villager: Villager


func setup(world_position: Vector3, character_key: String) -> void:
	position = world_position
	_villager = VILLAGER_SCENE.instantiate()
	add_child(_villager)
	_villager.setup(character_key)
	_villager.play_animation(HELD_POSE_CLIP)
	_villager.get_animation_player().pause()


func get_villager() -> Villager:
	return _villager
