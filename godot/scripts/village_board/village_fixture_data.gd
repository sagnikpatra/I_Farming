## Shared asset-path constants for the village board and
## VillageSnapshotMapper. Originally (EPIC-M1) this class also generated a
## hardcoded 3-zone placeholder fixture via get_fixture_zones(), standing in
## for the real economy until EPIC-M2 ported it to Godot. That generator was
## removed once EPIC-M2's real GameEconomy/GameState became available --
## village_board.gd now builds its fixture data from real game state via
## VillageSnapshotMapper.build() instead. This file now exists purely to hold
## the .obj model paths both the board's boundary-fence code and the mapper
## still need.
class_name VillageFixtureData
extends RefCounted

const FENCE_SIMPLE := "res://assets_3d/nature-kit/OBJ format/fence_simple.obj"
const FENCE_GATE := "res://assets_3d/nature-kit/OBJ format/fence_gate.obj"
const CROP_PLOT := "res://assets_3d/nature-kit/OBJ format/crops_dirtSingle.obj"
const FARMHOUSE_MODEL := "res://assets_3d/city-kit-suburban/OBJ format/building-type-a.obj"
const MANDI_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/stall-red.obj"
