## FIXTURE DATA — represents one structure zone (e.g. Farmhouse, Polyhouse,
## Mandi) with its footprint, model, and attached plots, as rendered by the
## village board. Built fresh every rebuild by VillageSnapshotMapper from the
## real economy's GameState (see scripts/economy/) -- this class itself
## carries no economy logic, purely render-facing data (see plot_fixture.gd,
## its per-plot sibling).
class_name ZoneFixture
extends RefCounted

var id: String
var display_name: String
## res:// path to an .obj model, or "" to use a primitive placeholder box
## (used for zones with no sourced Kenney model, e.g. Polyhouse/greenhouse).
var model_path: String
var tile_col: int
var tile_row: int
var tile_width: int
var tile_depth: int
var plinth_color: Color
var plots: Array[PlotFixture] = []
## False only while VillageSnapshotMapper's backing GameState flag for this
## zone (e.g. has_polyhouse) is not yet true. A locked zone always renders as
## the dim/semi-transparent placeholder box regardless of model_path, and
## never gets its plots populated (see village_board.gd's _build_zone()).
var is_unlocked: bool = true
## False only for the synthetic "open_field" pseudo-zone: it has no
## building/plinth, just attached plots, and is therefore never draggable
## (no PickArea gets created for it -- see village_board.gd's _build_zone()).
var has_building: bool = true
## Track B (design/art/ui-visual-direction-2026-08.md, §3): true only for
## Polyhouse. No sourced Kenney kit has a greenhouse shape (confirmed,
## assets_3d/README.md's "Still missing" section), so Polyhouse always
## falls into village_board.gd's "unlocked but no sourced model yet"
## placeholder-box branch (model_path == "") -- this flag switches that
## branch's material from opaque to translucent (StandardMaterial3D.
## transparency + the existing toon shading) so it reads as "glass
## structure" instead of a solid tinted box. Has no effect on a zone with a
## real model_path (Aquaculture/Vertical Farm/Agroforestry/Farmhouse/Mandi)
## or on a locked zone (which always uses LOCKED_ZONE_PLACEHOLDER_COLOR,
## already translucent, regardless of this flag).
var use_translucent_placeholder: bool = false
## design/gdd/land-and-structures.md's sub-upgrade visual cue stretch goal
## -- how many of this zone's own sub-upgrades (Fan & Pad/UV Film/Drip
## Irrigation for Polyhouse, Security for Agroforestry, Electricity for
## Vertical Farm) are currently active. 0 for every zone with none of its
## own (Farmhouse, Mandi, Open Field, Aquaculture -- which has no
## sub-upgrade of its own in GameState today) or when the base structure
## itself isn't unlocked yet. Set post-construction by
## VillageSnapshotMapper (like host_occupied/lifecycle on PlotFixture),
## not a constructor parameter -- this field is optional/zero-default for
## the many zones that never set it.
var active_upgrade_count: int = 0

func _init(
	p_id: String,
	p_display_name: String,
	p_model_path: String,
	p_tile_col: int,
	p_tile_row: int,
	p_tile_width: int,
	p_tile_depth: int,
	p_plinth_color: Color,
	p_plots: Array[PlotFixture] = [],
	p_is_unlocked: bool = true,
	p_has_building: bool = true,
	p_use_translucent_placeholder: bool = false
) -> void:
	id = p_id
	display_name = p_display_name
	model_path = p_model_path
	tile_col = p_tile_col
	tile_row = p_tile_row
	tile_width = p_tile_width
	tile_depth = p_tile_depth
	plinth_color = p_plinth_color
	plots = p_plots
	is_unlocked = p_is_unlocked
	has_building = p_has_building
	use_translucent_placeholder = p_use_translucent_placeholder

## Every (col, row) tile this zone's building footprint occupies.
func occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dx in range(tile_width):
		for dz in range(tile_depth):
			tiles.append(Vector2i(tile_col + dx, tile_row + dz))
	return tiles
