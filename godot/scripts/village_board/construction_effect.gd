class_name ConstructionEffect
extends Node3D
## Transient "worker is building it" visual flourish -- shipped 2026-08-23
## in response to a real user report ("When building is upgraded then
## building should show that worker is building it"). Spawned by
## VillageBoard.play_construction_effect() from a UI call site right after a
## mutating GameEconomy call succeeds (checked via `_economy.dirty`, the
## same success-check pattern farmhouse_tab.gd's `_on_upgrade_pressed()`
## already used for its SFX cue, mirrored at every call site below). User
## confirmed (AskUserQuestion) this fires on both Farmhouse level-ups AND a
## zone's first-time unlock, not Farmhouse alone.
##
## Deliberately NOT persisted anywhere in GameState: this celebrates an
## action that has already fully completed by the time this node exists --
## there is no multi-step "under construction" process with its own state
## to save/resume, unlike e.g. Polyhouse's UV film timer. If the player
## closes the app mid-flourish, it simply doesn't replay next launch;
## nothing is lost because nothing was ever "in progress" to begin with.
## Same shape as WorkerStation.gd (setup(world_position, character_key),
## get_villager()) plus a one-shot Timer that frees this node when the
## flourish ends -- deliberately a NEW component, not a WorkerStation reuse,
## since WorkerStation's `is_playing() == false` (paused) contract and
## permanent-until-unassigned lifetime are wrong for a fire-and-forget
## effect (see test_worker_station.gd's own tests for that contract).
##
## Positioned at the zone's center -- the same spot WorkerStation stations a
## permanently-assigned worker, which was found this same day to fully
## occlude the building underneath for as long as that worker is assigned.
## That finding does NOT apply here: neither trigger (a Farmhouse upgrade --
## Farmhouse is never worker-eligible, confirmed via
## village_board.gd's _zone_id_for_plot_kind() -- or a zone's first-time
## unlock, which happens before a player could have assigned a worker to a
## zone that didn't exist yet) can ever collide with a real WorkerStation
## occupying the same spot. And unlike a permanent station, a few seconds of
## occlusion during the zone's own "just got built" celebration is the
## point, not a defect -- the player's attention is already on that exact
## spot because they just tapped Upgrade/Build.
const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")

## How long the flourish plays before self-despawning. Purely a feel/pacing
## choice (no gameplay tie-in) -- long enough to read as a deliberate beat,
## short enough not to block the player from immediately continuing to
## interact with the same zone.
const DURATION_SECONDS: float = 3.0

## Interact, not WorkerStation's PickUp -- see villager.gd's WORK_CLIP_NAMES
## doc comment for why these two deliberately stay visually distinct.
const CONSTRUCTION_POSE_CLIP: String = "Interact"

var _villager: Villager
var _timer: Timer


func setup(world_position: Vector3, character_key: String) -> void:
	position = world_position
	_villager = VILLAGER_SCENE.instantiate()
	add_child(_villager)
	_villager.setup(character_key)
	_villager.play_animation(CONSTRUCTION_POSE_CLIP)

	_timer = Timer.new()
	_timer.name = "DespawnTimer"
	_timer.wait_time = DURATION_SECONDS
	_timer.one_shot = true
	_timer.timeout.connect(queue_free)
	add_child(_timer)
	_timer.start()


func get_villager() -> Villager:
	return _villager


func get_despawn_timer() -> Timer:
	return _timer
