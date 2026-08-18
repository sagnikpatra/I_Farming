## Load/save for GameState. Port of GameRepository.kt, but using a clean
## Godot-native Resource save format instead of hand-serialized JSON, per
## ADR-0002 -- not compatible with the old Kotlin/Android schema, no old-save
## carryover, no migration path (none needed, no players yet at this stage).
##
## Kept as a standalone RefCounted (not folded into GameEconomy) so the
## round-trip serialization behavior can be tested in isolation --
## see tests/unit/test_save_system.gd.
class_name SaveSystem
extends RefCounted

const SAVE_PATH: String = "user://save.tres"


## Loads GameState from disk, or returns a fresh default GameState if no save
## exists yet or the save is corrupt/unreadable (mirrors GameRepository.kt's
## `runCatching { deserialize(raw) }.getOrDefault(GameState())` fallback).
static func load_state(path: String = SAVE_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return GameState.new()
	var loaded: Resource = ResourceLoader.load(path, "GameState", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is GameState):
		push_warning("SaveSystem: save file at %s failed to load as GameState -- starting fresh." % path)
		return GameState.new()
	return loaded


## Saves the given GameState to disk. Returns true on success.
static func save_state(state: GameState, path: String = SAVE_PATH) -> bool:
	var err: Error = ResourceSaver.save(state, path)
	if err != OK:
		push_warning("SaveSystem: failed to save to %s (error %d)." % [path, err])
		return false
	return true
