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

## Curated decoration models (EPIC-M5 parity pass) -- replaces the flat
## placeholder boxes _decoration_tint_color()/_build_decoration() used
## since EPIC-M4 slice 3. Sourced per assets_3d/README.md's "Suggested
## mapping to Kisan Khet's game entities" table (written during the
## original asset-acquisition pass, never wired into rendering until now).
## DecorationType.Kind.DIRT_PATH and RANGOLI have no candidate in that table
## (culturally-specific ground decals, not generic Kenney kit content) --
## Rangoli is a procedural decal built at runtime instead (see
## village_board.gd's _build_rangoli_decal(), a simplified Godot port of
## the pre-existing core/.../village3d/RangoliModelBuilder.kt's 8-petal
## pixel-painted texture); Dirt Path uses nature-kit's own flat path tile,
## a closer visual match than any "decoration" kit model would be.
const DECORATION_POTTED_PLANT_MODEL := "res://assets_3d/city-kit-suburban/OBJ format/planter.obj"
const DECORATION_SUNFLOWER_MODEL := "res://assets_3d/nature-kit/OBJ format/flower_yellowA.obj"
const DECORATION_BAMBOO_MODEL := "res://assets_3d/nature-kit/OBJ format/crops_bambooStageA.obj"
const DECORATION_LANTERN_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/lantern.obj"
const DECORATION_FOUNTAIN_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/fountain-round.obj"
const DECORATION_STATUE_MODEL := "res://assets_3d/nature-kit/OBJ format/statue_obelisk.obj"
const DECORATION_DIRT_PATH_MODEL := "res://assets_3d/nature-kit/OBJ format/ground_pathTile.obj"
