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
const MANDI_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/stall-red.obj"

## design/gdd/farmhouse-visual-tiers.md -- 5 tiers matching the boundaries
## GameData.farmhouse_level_def()'s own emoji sequence already implies
## (🛖 alone at 0, 🏠 spans 1-2, 🏡 spans 3-4, 🏰 spans 5-6, 🏛️ alone at 7),
## not a separately-invented tier scheme. All 5 are unmodified CC0 shells
## from the same city-kit-suburban kit already documented as the
## Farmhouse's stand-in ("pick one house shell", assets_3d/README.md) --
## picked by file size as a size/complexity proxy for grandeur, same
## honest-stand-in precedent as Polyhouse's placeholder box.
const FARMHOUSE_MODEL_TIER_1 := "res://assets_3d/city-kit-suburban/OBJ format/building-type-h.obj"
## Kept as the existing model (was the sole FARMHOUSE_MODEL before this
## tiering) for continuity with every prior screenshot/save.
const FARMHOUSE_MODEL_TIER_2 := "res://assets_3d/city-kit-suburban/OBJ format/building-type-a.obj"
const FARMHOUSE_MODEL_TIER_3 := "res://assets_3d/city-kit-suburban/OBJ format/building-type-l.obj"
const FARMHOUSE_MODEL_TIER_4 := "res://assets_3d/city-kit-suburban/OBJ format/building-type-d.obj"
const FARMHOUSE_MODEL_TIER_5 := "res://assets_3d/city-kit-suburban/OBJ format/building-type-t.obj"


## The Farmhouse model for a given farmhouse_level (0-7) -- see the table in
## design/gdd/farmhouse-visual-tiers.md §4. Mirrors
## GameData.farmhouse_level_def()'s own defensive out-of-range clamp
## (never errors, clamps to the last tier) rather than duplicating a
## second parallel level table.
static func farmhouse_model_path(level: int) -> String:
	if level <= 0:
		return FARMHOUSE_MODEL_TIER_1
	if level <= 2:
		return FARMHOUSE_MODEL_TIER_2
	if level <= 4:
		return FARMHOUSE_MODEL_TIER_3
	if level <= 6:
		return FARMHOUSE_MODEL_TIER_4
	return FARMHOUSE_MODEL_TIER_5

## Track B (design/art/ui-visual-direction-2026-08.md, §3) -- zone-building
## variety pass. Per assets_3d/README.md's "Suggested mapping" table:
## watermill for Aquaculture (waterwheel reads as pond infrastructure),
## windmill for Vertical Farm (distinct tall silhouette from the other
## zones), hedge-large for Agroforestry (reads as a hedge/grove enclosure --
## picked over the smaller `hedge.obj` since it fills a 2x2 footprint less
## sparsely once scaled by _footprint_scale_factor()). Polyhouse has no
## greenhouse shape in any sourced kit (confirmed, see README's "Still
## missing" section) -- deliberately left with no model_path here; it keeps
## rendering via village_board.gd's placeholder-box branch, now switched to
## a translucent material for Polyhouse specifically (see
## ZoneFixture.use_translucent_placeholder / VillageSnapshotMapper's
## Polyhouse builder) so it reads as "glass structure" rather than a solid
## opaque box.
const AQUACULTURE_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/watermill.obj"
const VERTICAL_FARM_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/windmill.obj"
const AGROFORESTRY_MODEL := "res://assets_3d/fantasy-town-kit/OBJ format/hedge-large.obj"

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

## Track B decoration-density pass. Only `flower_yellowA` (above) was ever
## curated for the purchasable Sunflower decoration; B/C add cheap visual
## variety when several Sunflowers are placed (see village_board.gd's
## _decoration_model_path(), which now round-robins the three by
## decoration.id) -- no new DecorationType.Kind, still one purchasable
## "Sunflower" entry, just a varied look.
const DECORATION_SUNFLOWER_MODEL_B := "res://assets_3d/nature-kit/OBJ format/flower_yellowB.obj"
const DECORATION_SUNFLOWER_MODEL_C := "res://assets_3d/nature-kit/OBJ format/flower_yellowC.obj"

## Ambient, non-interactive dressing -- never a purchasable DecorationType,
## placed automatically by village_board.gd's _build_tree_ring()/
## _build_ambient_clutter() (see those functions' doc comments). Three tree
## variants for a mixed-canopy edge ring (echoes inspiration image 1's tree
## border, direction doc §3); bush/rock pairs for ambient ground clutter
## scattered across unreserved margin tiles.
const TREE_RING_MODELS: Array[String] = [
	"res://assets_3d/nature-kit/OBJ format/tree_default.obj",
	"res://assets_3d/nature-kit/OBJ format/tree_fat.obj",
	"res://assets_3d/nature-kit/OBJ format/tree_oak.obj",
]
const AMBIENT_CLUTTER_MODELS: Array[String] = [
	"res://assets_3d/nature-kit/OBJ format/plant_bush.obj",
	"res://assets_3d/nature-kit/OBJ format/plant_bushSmall.obj",
	"res://assets_3d/nature-kit/OBJ format/rock_smallA.obj",
	"res://assets_3d/nature-kit/OBJ format/rock_smallB.obj",
]

## Crop growth-stage geometry pass: real staged crop models (Track B sourced
## these into assets_3d/ but deliberately left them unwired -- see
## design/art/ui-visual-direction-2026-08.md, §3). Wheat gets an exact model
## match. Tomato/Capsicum have no tomato/pepper-specific sourced model in any
## curated kit; crops_leafsStage{A,B} (a generic leafy-vegetable silhouette)
## is used as an approximation for both -- a real judgment call, not a proven
## fit, flagged here the same way the audio pass flagged its bird-species
## approximations (production/audio EPIC-M8 notes).
##
## Paddy/Dutch Rose/Sandalwood/Makhana/Pond Fish/Saffron are deliberately
## NOT mapped: corn stalks (crops_cornStageA-D.obj, also sourced but unused)
## don't read as rice paddy, and sandalwood/saffron/rose need species-specific
## geometry nothing in the curated kits provides. Those crops stay on the
## existing flat dirt-mesh + lifecycle-tint rendering via
## crop_stage_model_path() returning "" for them -- see that function's own
## doc comment and village_board.gd's _build_plot(), which falls back to
## CROP_PLOT whenever this returns "".
const CROP_WHEAT_STAGE_GROWING := "res://assets_3d/nature-kit/OBJ format/crops_wheatStageA.obj"
const CROP_WHEAT_STAGE_READY := "res://assets_3d/nature-kit/OBJ format/crops_wheatStageB.obj"
const CROP_LEAFY_STAGE_GROWING := "res://assets_3d/nature-kit/OBJ format/crops_leafsStageA.obj"
const CROP_LEAFY_STAGE_READY := "res://assets_3d/nature-kit/OBJ format/crops_leafsStageB.obj"


## Real staged crop-growth model for `crop` at its current stage, or "" if
## this crop has no staged model (see the constants block above for exactly
## which crops are and aren't mapped, and why). `is_ready` selects the
## second/riper stage (PlotFixture.Lifecycle.READY_TO_HARVEST) vs. the first/
## sprouting stage (Lifecycle.GROWING) -- callers must not call this for
## Lifecycle.EMPTY/GHOST, which have no crop planted at all.
##
## `crop` is typed CropType.Kind for editor/call-site clarity, but (like
## GameData.crop_def()) is routinely called with a plain int that may be -1
## (PlotFixture.crop's "no crop planted" sentinel, e.g. a host-occupied
## Agroforestry cell) -- GDScript enum-typed params don't enforce membership,
## and the `match` below's `_` branch safely returns "" for that case, same
## as for every crop ordinal deliberately left unmapped.
static func crop_stage_model_path(crop: CropType.Kind, is_ready: bool) -> String:
	match crop:
		CropType.Kind.WHEAT:
			return CROP_WHEAT_STAGE_READY if is_ready else CROP_WHEAT_STAGE_GROWING
		CropType.Kind.TOMATO, CropType.Kind.CAPSICUM:
			return CROP_LEAFY_STAGE_READY if is_ready else CROP_LEAFY_STAGE_GROWING
		_:
			return ""
