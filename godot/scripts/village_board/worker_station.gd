class_name WorkerStation
extends Node3D
## Renders one assigned worker stood at a fixed world position -- the
## "called" half of design/gdd/villagers.md §3.6, as opposed to
## VillagerRoamer's ambient "idle" roaming. Does not move; owned/spawned
## by village_board.gd's _sync_worker_stations(), one per active
## GameState.worker_assignments entry.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")

## Found 2026-08-23: the previous "held pose" (Walking_A, paused immediately
## after starting) read as a broken/T-pose-ish frozen stance on-device --
## a real, reported gap against design/gdd/worker-economy.md rule 6, which
## explicitly wants an assigned worker "performing a work-appropriate pose/
## animation," not a frozen walk frame. Fixed by direct glTF inspection of
## Rig_Medium_General.glb (see villager.gd's WORK_CLIP_NAMES) finding a real
## `PickUp` clip (bend down, grab, stand) on the same shared skeleton --
## the closest visual match to farm work available in this asset kit, out
## of Interact/PickUp/Use_Item. Played on a continuous loop (not paused --
## villager.gd's _force_every_clip_to_loop() already sets LOOP_LINEAR on
## every merged clip including this one), so a stationed worker visibly
## repeats a bend-and-gather motion for as long as it's assigned, instead
## of standing frozen.
const WORKING_POSE_CLIP: String = "PickUp"

var _villager: Villager


func setup(world_position: Vector3, character_key: String) -> void:
	position = world_position
	_villager = VILLAGER_SCENE.instantiate()
	add_child(_villager)
	_villager.setup(character_key)
	_villager.play_animation(WORKING_POSE_CLIP)


func get_villager() -> Villager:
	return _villager
