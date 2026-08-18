## Village board root. Owns the two-layer split (per ADR-0001): StaticLayer is
## wiped and rebuilt whenever fixture/state data changes (mirrors the old
## Village3DStage.rebuild() pattern); ActorLayer is untouched by rebuild() and
## reserved for EPIC-M6's per-frame-updating villager actors -- no actor logic
## is built in this epic, the node exists purely so M6 doesn't have to
## retrofit the split later.
##
## EPIC-M1 scope: originally rendered VillageFixtureData's hardcoded 3-zone
## fixture, not the real economy (EPIC-M2 had not been built yet). Root
## causes fixed here per docs/architecture/adr-0001-godot-engine-migration.md:
## compact bounded layout (#1 content span, #2 unbounded terrain),
## filled/plinth'd tiles (#3), and a warm Indian-architecture-inspired
## palette + built-in toon shading (#4 -- see _apply_toon_shading()) so the
## board reads as stylized rather than a muted realistic render.
##
## Post-EPIC-M2 update: _ready() now loads a real GameState via SaveSystem,
## owns a GameEconomy instance built from it, and maps it to fixture data via
## VillageSnapshotMapper.build() instead of VillageFixtureData's old
## hardcoded generator (removed). VillageBoard's "sole authority over fixture
## data" extends to the economy/save lifecycle too -- no autoload, no other
## node touches _economy.
##
## EPIC-M3 addition: every zone/plot also gets a tightly-fitted Area3D pick
## collider (child of its own node, sized from the *same* geometry math used
## to build the visible mesh -- never a separate guessed box) plus a small
## mutation API (preview_zone_position/try_commit_zone_move) so
## BoardInteractor can drive tap-select and long-press-drag without owning
## any layout math itself. VillageBoard remains the sole authority over
## fixture data and the built scene graph; BoardInteractor only calls these
## public methods and never reaches into _static_layer's children directly.
class_name VillageBoard
extends Node3D

const TILE_SIZE: float = 1.0
const GRID_COLS: int = 10
const GRID_ROWS: int = 12
const FILL_RATIO: float = 0.85
const PLINTH_HEIGHT: float = 0.08
const GATE_COL: int = 4

## Physics layers used purely for BoardInteractor's manual raycast picking
## (PhysicsDirectSpaceState3D.intersect_ray with collide_with_areas = true --
## see board_interactor.gd). Split so long-press-drag candidacy checks can
## query "zones only" (draggable) separately from tap-select's "zones or
## plots" (selectable but not draggable). See project.godot's
## [layer_names] section for the editor-facing labels.
const PICK_LAYER_ZONES: int = 1
const PICK_LAYER_PLOTS: int = 2

# Sun-baked field green -- warmer/more olive than the original placeholder
# (root cause #4: was a cooler, more temperate-lawn grass green). This is
# darker/more saturated than the intended on-screen olive tone on purpose:
# Godot's linear-light workflow sRGB-encodes lit surfaces noticeably brighter
# than the raw Color() literal would suggest (confirmed empirically -- a first
# pass at (0.58,0.68,0.30) rendered as a bright lime #CEE350, not the intended
# dusty olive, even after fixing the DIFFUSE_TOON clipping). This value is
# back-calculated (sRGB decode of the target display color) to land close to
# the intended #94AD4D "Sun-Baked Field Green" once actually lit and
# displayed -- verify against the real screenshot, not this literal.
const GROUND_COLOR := Color(0.32, 0.42, 0.10)
# Warm ivory rather than pure white, still low-alpha so the placeholder reads
# as glassy/transparent rather than a flat opaque slab -- used for any zone
# that's not yet unlocked, regardless of whether it has a sourced model (a
# locked zone always renders as this placeholder, never its real model).
const LOCKED_ZONE_PLACEHOLDER_COLOR := Color(0.97, 0.93, 0.84, 0.30)

# Plot lifecycle/water/host tints (see _plot_tint_color()). Flat-color +
# toon-shading language only, no new meshes/sprites.
# Host-occupied cell: a companion plant fills this tile permanently --
# foliage green, takes precedence over lifecycle/water entirely.
const HOST_OCCUPIED_PLOT_COLOR := Color(0.42, 0.55, 0.25)
# GHOST (next open-field expansion slot): neutral + reduced alpha, same
# "not-yet-real" visual language as LOCKED_ZONE_PLACEHOLDER_COLOR above.
const GHOST_PLOT_COLOR := Color(0.85, 0.85, 0.85, 0.35)
# EMPTY: near-white so the sourced dirt texture's own look reads through
# almost untinted.
const PLOT_EMPTY_TINT := Color(0.95, 0.95, 0.95)
# GROWING: green-gold sprouting tint.
const PLOT_GROWING_TINT := Color(0.55, 0.75, 0.35)
# READY_TO_HARVEST: bright amber/gold ripe tint.
const PLOT_READY_TINT := Color(0.95, 0.75, 0.20)
# Multiplied component-wise onto the lifecycle tint for Aquaculture plots, so
# e.g. a growing Aquaculture plot reads as green-tinted-blue rather than
# losing the water cue entirely.
const WATER_TINT_MULTIPLIER := Color(0.55, 0.80, 0.90)

@onready var _static_layer: Node3D = $StaticLayer
@onready var _camera_rig: CameraRig = $CameraRig

## zone.id -> ZoneFixture. This is the single in-memory source of truth for a
## zone's current tile position; try_commit_zone_move() mutates it in place so
## repeated drags in the same session accumulate correctly without a full
## rebuild() round-trip.
var _zones_by_id: Dictionary = {}
## zone.id -> the zone's root Node3D (parent of its Plinth/Building/PickArea).
var _zone_nodes_by_id: Dictionary = {}
## Owns the economy/save lifecycle for the whole board (see class doc) --
## no autoload, no other node touches this.
var _economy: GameEconomy


func _ready() -> void:
	var loaded_state := SaveSystem.load_state()
	_economy = GameEconomy.new(loaded_state)
	var zones := VillageSnapshotMapper.build(_economy.state)
	var overlaps := _find_overlapping_tiles(zones)
	if not overlaps.is_empty():
		push_error("VillageBoard: zone/plot footprint overlap at tiles: %s" % [overlaps])
		assert(false, "Zone/plot footprint overlap detected -- see error above")
	else:
		print("VillageBoard: overlap check passed -- %d zones, no footprint collisions." % zones.size())
	rebuild(zones)


## Wipes and rebuilds the static layer (ground, boundary, zones+plinths+plots)
## from the given fixture data. Does not touch ActorLayer or BoardInteractor
## (selection highlight / drag state survive a rebuild, since neither is a
## child of StaticLayer).
func rebuild(zones: Array[ZoneFixture]) -> void:
	for child in _static_layer.get_children():
		child.queue_free()
	_zones_by_id.clear()
	_zone_nodes_by_id.clear()

	var ground := _build_ground()
	_static_layer.add_child(ground)

	var boundary := Node3D.new()
	boundary.name = "Boundary"
	_static_layer.add_child(boundary)
	_build_boundary(boundary)

	var zones_node := Node3D.new()
	zones_node.name = "Zones"
	_static_layer.add_child(zones_node)
	for zone in zones:
		_zones_by_id[zone.id] = zone
		_zone_nodes_by_id[zone.id] = _build_zone(zone, zones_node)

	var bounds := _board_bounds()
	_camera_rig.frame_bounds(bounds.center, bounds.extents)


func _grid_to_world(col: float, row: float) -> Vector3:
	var x := (col - float(GRID_COLS - 1) / 2.0) * TILE_SIZE
	var z := (row - float(GRID_ROWS - 1) / 2.0) * TILE_SIZE
	return Vector3(x, 0.0, z)


func _zone_center_world(zone: ZoneFixture) -> Vector3:
	var center_col := float(zone.tile_col) + float(zone.tile_width - 1) / 2.0
	var center_row := float(zone.tile_row) + float(zone.tile_depth - 1) / 2.0
	return _grid_to_world(center_col, center_row)


## Named risk (compacting the layout increases collision likelihood vs. the
## old sprawling layout) -- verified explicitly rather than assumed.
func _find_overlapping_tiles(zones: Array[ZoneFixture]) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var collisions: Array[Vector2i] = []
	for zone in zones:
		for tile in zone.occupied_tiles():
			if seen.has(tile):
				collisions.append(tile)
			else:
				seen[tile] = zone.id
		for plot in zone.plots:
			var plot_tile := Vector2i(plot.tile_col, plot.tile_row)
			if seen.has(plot_tile):
				collisions.append(plot_tile)
			else:
				seen[plot_tile] = "%s:plot" % zone.id
	return collisions


## EPIC-M3: per-candidate-position occupancy map, built from the same
## tile-ownership concept as _find_overlapping_tiles() above but answering a
## different question ("is this tile already taken by anyone other than
## `exclude_zone_id`?") used by _zone_fits() to validate a live drag target.
func _build_occupancy_map(zones_by_id: Dictionary, exclude_zone_id: String) -> Dictionary:
	var occupied: Dictionary = {}
	for zone_id in zones_by_id:
		if zone_id == exclude_zone_id:
			continue
		var zone: ZoneFixture = zones_by_id[zone_id]
		for tile in zone.occupied_tiles():
			occupied[tile] = zone.id
		for plot in zone.plots:
			occupied[Vector2i(plot.tile_col, plot.tile_row)] = "%s:plot" % zone.id
	return occupied


## True if `zone` would sit fully inside the grid and not overlap any OTHER
## zone's footprint or any plot, were its origin (target_col, target_row)
## instead of its current position.
func _zone_fits(zone: ZoneFixture, target_col: int, target_row: int) -> bool:
	if target_col < 0 or target_row < 0:
		return false
	if target_col + zone.tile_width > GRID_COLS or target_row + zone.tile_depth > GRID_ROWS:
		return false

	var occupied := _build_occupancy_map(_zones_by_id, zone.id)
	for dx in range(zone.tile_width):
		for dz in range(zone.tile_depth):
			var tile := Vector2i(target_col + dx, target_row + dz)
			if occupied.has(tile):
				return false
	return true


func _build_ground() -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_COLS * TILE_SIZE, GRID_ROWS * TILE_SIZE)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	ground.material_override = mat
	ground.position = _grid_to_world(float(GRID_COLS - 1) / 2.0, float(GRID_ROWS - 1) / 2.0)
	_apply_toon_shading(ground)
	return ground


func _build_boundary(parent: Node3D) -> void:
	for col in range(GRID_COLS):
		_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, col, -1, 0.0)
		if col == GATE_COL:
			_place_boundary_piece(parent, VillageFixtureData.FENCE_GATE, col, GRID_ROWS, 0.0)
		else:
			_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, col, GRID_ROWS, 0.0)
	for row in range(GRID_ROWS):
		_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, -1, row, 90.0)
		_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, GRID_COLS, row, 90.0)

	# Corners: reuse fence_simple (the same piece + rotation convention as the
	# adjacent straight runs above) as an L-join, rather than the separate
	# fence_corner asset -- fence_corner's own local orientation didn't match
	# the straight runs' rail-offset convention and produced a visibly
	# detached/angled post. Two overlapping fence_simple copies (rotation 0
	# continuing the row run, rotation 90 continuing the column run) are
	# guaranteed to align since they're identical to their straight neighbors.
	var corners: Array[Vector2i] = [
		Vector2i(-1, -1),
		Vector2i(GRID_COLS, -1),
		Vector2i(-1, GRID_ROWS),
		Vector2i(GRID_COLS, GRID_ROWS),
	]
	for corner in corners:
		_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, corner.x, corner.y, 0.0)
		_place_boundary_piece(parent, VillageFixtureData.FENCE_SIMPLE, corner.x, corner.y, 90.0)


func _place_boundary_piece(parent: Node3D, model_path: String, col: int, row: int, rotation_deg: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = load(model_path)
	instance.position = _grid_to_world(float(col), float(row))
	instance.rotation_degrees.y = rotation_deg
	_apply_toon_shading(instance)
	parent.add_child(instance)


## Builds one zone's Plinth + Building + PickArea trio and positions them at
## the zone's current fixture tile position. Returns the zone's root node
## (registered by rebuild() into _zone_nodes_by_id).
func _build_zone(zone: ZoneFixture, parent: Node3D) -> Node3D:
	var zone_node := Node3D.new()
	zone_node.name = zone.id
	parent.add_child(zone_node)

	if zone.has_building:
		_build_zone_structure(zone, zone_node)
		_reposition_zone_group(zone_node, _zone_center_world(zone))

	# Locked zones never get their plots populated -- VillageSnapshotMapper
	# already won't populate zone.plots for a locked zone, this is
	# defense-in-depth at the render layer too (mirrors the Kotlin
	# reference's early-return pattern).
	if zone.is_unlocked:
		for plot in zone.plots:
			_build_plot(plot, zone_node, zone.id)

	return zone_node


## Builds one zone's Plinth/Building/PickArea trio. Only called for zones
## with has_building=true (see _build_zone()) -- the synthetic "open_field"
## pseudo-zone has no building/plinth and skips this entirely.
func _build_zone_structure(zone: ZoneFixture, zone_node: Node3D) -> void:
	var footprint := Vector2(zone.tile_width, zone.tile_depth) * TILE_SIZE

	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = Vector3(footprint.x * 0.95, PLINTH_HEIGHT, footprint.y * 0.95)
	plinth.mesh = plinth_mesh
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = zone.plinth_color
	plinth.material_override = plinth_mat
	_apply_toon_shading(plinth)
	zone_node.add_child(plinth)

	var building := MeshInstance3D.new()
	building.name = "Building"
	var building_height: float
	if not zone.is_unlocked:
		# Locked: always the dim/semi-transparent placeholder box, regardless
		# of whether this zone has a sourced model.
		var box := BoxMesh.new()
		var box_footprint := minf(footprint.x, footprint.y) * FILL_RATIO
		box.size = Vector3(box_footprint, box_footprint * 0.9, box_footprint)
		building.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = LOCKED_ZONE_PLACEHOLDER_COLOR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		building.material_override = mat
		building_height = box.size.y
		# Placeholder box's own pivot is centered, not base-anchored, so its
		# resting position is half its own height above the plinth top.
		building.set_meta("base_y", PLINTH_HEIGHT + building_height / 2.0)
	elif zone.model_path.is_empty():
		# Unlocked but no sourced model yet: same box geometry as the locked
		# placeholder, but opaque and tinted with this zone's own
		# plinth_color, so it reads as a solid built structure rather than a
		# locked ghost (Agroforestry/Aquaculture/Vertical Farm each read as a
		# distinct solid structure once unlocked).
		var box := BoxMesh.new()
		var box_footprint := minf(footprint.x, footprint.y) * FILL_RATIO
		box.size = Vector3(box_footprint, box_footprint * 0.9, box_footprint)
		building.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(zone.plinth_color.r, zone.plinth_color.g, zone.plinth_color.b, 1.0)
		building.material_override = mat
		building_height = box.size.y
		building.set_meta("base_y", PLINTH_HEIGHT + building_height / 2.0)
	else:
		var raw_mesh: Mesh = load(zone.model_path)
		building.mesh = raw_mesh
		var target_footprint := minf(footprint.x, footprint.y) * FILL_RATIO
		var scale_factor := _footprint_scale_factor(raw_mesh, target_footprint)
		building.scale = Vector3.ONE * scale_factor
		building_height = raw_mesh.get_aabb().size.y * scale_factor
		# Sourced Kenney models are base-anchored (pivot at y=0 local), so they
		# rest directly on the plinth top with no extra offset.
		building.set_meta("base_y", PLINTH_HEIGHT)
	_apply_toon_shading(building)
	zone_node.add_child(building)

	# EPIC-M3 pick collider -- sized directly from footprint/building_height
	# (the exact values used to build the visible mesh above), never a
	## separate guessed box. This is the fix for the old LibGDX board's
	# "hit-box sizing vs. camera angle" bug class: an oversized collider at
	# this board's ~50 deg camera pitch could let one tap register on two
	# entities several tiles apart. A collider that exactly matches the
	# rendered geometry's true footprint and height cannot overhang far
	# enough to cause that.
	var building_top_y := PLINTH_HEIGHT + building_height
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = PICK_LAYER_ZONES
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = false
	pick_area.set_meta("board_kind", "zone")
	pick_area.set_meta("board_id", zone.id)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(footprint.x * 0.95, building_top_y, footprint.y * 0.95)
	shape.shape = box_shape
	pick_area.add_child(shape)
	zone_node.add_child(pick_area)
	zone_node.set_meta("building_top_y", building_top_y)


## Single source of truth for "where do this zone's Plinth/Building/PickArea
## sit for a given world-space center" -- used both for the zone's initial
## placement (_build_zone(), above) and for every drag-preview/commit frame
## (preview_zone_position()/try_commit_zone_move(), below), so a dragged
## zone's vertical resting height can never drift from how it was first built.
func _reposition_zone_group(zone_node: Node3D, center: Vector3) -> void:
	var plinth := zone_node.get_node("Plinth") as Node3D
	plinth.position = Vector3(center.x, PLINTH_HEIGHT / 2.0, center.z)

	var building := zone_node.get_node("Building") as Node3D
	var base_y: float = building.get_meta("base_y")
	building.position = Vector3(center.x, base_y, center.z)

	var pick_area := zone_node.get_node("PickArea") as Node3D
	var top_y: float = zone_node.get_meta("building_top_y")
	pick_area.position = Vector3(center.x, top_y / 2.0, center.z)


## Generic per-model scale normalization (root cause #3): scales a mesh
## uniformly so its largest ground-plane footprint axis fills target_footprint
## world units. Used for both zone buildings and crop plots so neither reads
## as a small floating speck inside its tile -- same formula, not hand-tuned
## per model.
func _footprint_scale_factor(mesh: Mesh, target_footprint: float) -> float:
	var raw_aabb := mesh.get_aabb()
	var raw_footprint := maxf(raw_aabb.size.x, raw_aabb.size.z)
	return target_footprint / raw_footprint if raw_footprint > 0.0 else 1.0


## Root cause #4 (material half): patches every material on a MeshInstance3D
## to use Godot's built-in 2-band toon diffuse ramp and zero specular, so the
## board reads as stylized rather than a smoothly-lit realistic render -- no
## custom shader needed (verified against this project's pinned 4.7.1 build
## and its gl_compatibility renderer). Handles both cases in this file:
##
## - Instances with an explicit material_override (Ground/Plinth/Polyhouse
##   placeholder box) -- patched in place, since material_override always wins
##   over any per-surface override and a surface-level patch would be a no-op.
## - Instances relying on their imported mesh's own per-surface materials
##   (Farmhouse/Mandi/fence pieces/crop plot) -- patched via
##   set_surface_override_material() so the shared imported Mesh resource
##   itself is never mutated (fence pieces alone reuse one Mesh across ~28
##   instances per rebuild).
func _apply_toon_shading(instance: MeshInstance3D) -> void:
	if instance.material_override != null:
		if instance.material_override is StandardMaterial3D:
			var overridden: StandardMaterial3D = instance.material_override
			overridden.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			overridden.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return

	var mesh := instance.mesh
	if mesh == null:
		return
	for i in range(mesh.get_surface_count()):
		var source_mat := mesh.surface_get_material(i)
		var toon_mat: StandardMaterial3D
		if source_mat is StandardMaterial3D:
			toon_mat = source_mat.duplicate()
		else:
			toon_mat = StandardMaterial3D.new()
		toon_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		toon_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		instance.set_surface_override_material(i, toon_mat)


## Precedence: host_occupied overrides everything (foliage-green tint,
## ignoring lifecycle/water entirely -- a host plant fills the cell
## permanently, see plot_fixture.gd) > GHOST (neutral + reduced alpha, same
## "not-yet-real" visual language as LOCKED_ZONE_PLACEHOLDER_COLOR) > normal
## lifecycle tint, multiplied by WATER_TINT_MULTIPLIER when is_water is true.
func _plot_tint_color(plot: PlotFixture) -> Color:
	if plot.host_occupied:
		return HOST_OCCUPIED_PLOT_COLOR
	if plot.lifecycle == PlotFixture.Lifecycle.GHOST:
		return GHOST_PLOT_COLOR
	var lifecycle_tint: Color
	match plot.lifecycle:
		PlotFixture.Lifecycle.GROWING:
			lifecycle_tint = PLOT_GROWING_TINT
		PlotFixture.Lifecycle.READY_TO_HARVEST:
			lifecycle_tint = PLOT_READY_TINT
		_:
			lifecycle_tint = PLOT_EMPTY_TINT
	if not plot.is_water:
		return lifecycle_tint
	return Color(
		lifecycle_tint.r * WATER_TINT_MULTIPLIER.r,
		lifecycle_tint.g * WATER_TINT_MULTIPLIER.g,
		lifecycle_tint.b * WATER_TINT_MULTIPLIER.b,
		lifecycle_tint.a,
	)


func _build_plot(plot: PlotFixture, parent: Node3D, zone_id: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Plot_%s" % plot.label
	var raw_mesh: Mesh = load(VillageFixtureData.CROP_PLOT)
	instance.mesh = raw_mesh
	var target_footprint := TILE_SIZE * FILL_RATIO
	var scale_factor := _footprint_scale_factor(raw_mesh, target_footprint)
	instance.scale = Vector3.ONE * scale_factor
	instance.position = _grid_to_world(float(plot.tile_col), float(plot.tile_row))

	# Lifecycle/water/host tint -- duplicates the sourced mesh's own surface-0
	# material (preserving its texture) and multiplies albedo_color, the same
	# "preserve texture, only multiply albedo" language _apply_toon_shading()
	# already uses below. Applied via material_override (not
	# set_surface_override_material) specifically so _apply_toon_shading()'s
	# material_override branch patches diffuse/specular in place rather than
	# overwriting this tint with a fresh untinted duplicate.
	var tint := _plot_tint_color(plot)
	var source_mat: Material = raw_mesh.surface_get_material(0) if raw_mesh.get_surface_count() > 0 else null
	var tint_mat: StandardMaterial3D = source_mat.duplicate() if source_mat is StandardMaterial3D else StandardMaterial3D.new()
	tint_mat.albedo_color = Color(
		tint_mat.albedo_color.r * tint.r,
		tint_mat.albedo_color.g * tint.g,
		tint_mat.albedo_color.b * tint.b,
		tint.a,
	)
	if tint.a < 1.0:
		tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = tint_mat

	_apply_toon_shading(instance)
	parent.add_child(instance)

	# EPIC-M3 pick collider -- same "match the real geometry" rule as zones,
	# above. Plots are selectable but never draggable in this epic (see
	# board_interactor.gd), so this only needs PICK_LAYER_PLOTS.
	var plot_height := maxf(raw_mesh.get_aabb().size.y * scale_factor, 0.05)
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = PICK_LAYER_PLOTS
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = false
	pick_area.set_meta("board_kind", "plot")
	pick_area.set_meta("board_id", plot_id_for(zone_id, plot.tile_col, plot.tile_row))
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(target_footprint, plot_height, target_footprint)
	shape.shape = box_shape
	pick_area.add_child(shape)
	pick_area.position = instance.position + Vector3(0.0, plot_height / 2.0, 0.0)
	parent.add_child(pick_area)


## Stable id encoding for a plot, parsed back by get_plot_footprint(). Zone
## ids are simple identifiers with no colons (see village_fixture_data.gd),
## so ":" is a safe separator.
static func plot_id_for(zone_id: String, tile_col: int, tile_row: int) -> String:
	return "%s:%d:%d" % [zone_id, tile_col, tile_row]


## Outer bound of the playfield including the one-tile boundary-fence ring.
## Returns {"center": Vector3, "extents": Vector2} (world-space XZ size).
func _board_bounds() -> Dictionary:
	var half_tile := TILE_SIZE / 2.0
	var min_corner := _grid_to_world(-1.0, -1.0) - Vector3(half_tile, 0.0, half_tile)
	var max_corner := _grid_to_world(float(GRID_COLS), float(GRID_ROWS)) + Vector3(half_tile, 0.0, half_tile)
	var center := (min_corner + max_corner) / 2.0
	var extents := Vector2(max_corner.x - min_corner.x, max_corner.z - min_corner.z)
	return {"center": center, "extents": extents}


# ---------------------------------------------------------------------------
# EPIC-M3 public API for BoardInteractor. VillageBoard stays the sole owner
# of fixture data and the built scene graph; BoardInteractor never reaches
# into _static_layer/_zones_by_id directly.
# ---------------------------------------------------------------------------

## World-space XZ center + footprint size of a zone at its *current*
## fixture-authoritative position (not a mid-drag preview position). Used by
## BoardInteractor to size/position the selection highlight.
func get_zone_footprint(zone_id: String) -> Dictionary:
	var zone: ZoneFixture = _zones_by_id.get(zone_id)
	if zone == null:
		return {}
	return {
		"center": _zone_center_world(zone),
		"size": Vector2(zone.tile_width, zone.tile_depth) * TILE_SIZE,
	}


## World-space XZ center + footprint size of a plot, given the id produced by
## plot_id_for() (as read off a PickArea's "board_id" meta).
func get_plot_footprint(plot_id: String) -> Dictionary:
	var parts := plot_id.split(":")
	if parts.size() != 3:
		return {}
	var col := int(parts[1])
	var row := int(parts[2])
	return {
		"center": _grid_to_world(float(col), float(row)),
		"size": Vector2.ONE * TILE_SIZE,
	}


func get_zone_center_world(zone_id: String) -> Vector3:
	var zone: ZoneFixture = _zones_by_id.get(zone_id)
	return _zone_center_world(zone) if zone != null else Vector3.ZERO


func get_zone_tile_origin(zone_id: String) -> Vector2i:
	var zone: ZoneFixture = _zones_by_id.get(zone_id)
	return Vector2i(zone.tile_col, zone.tile_row) if zone != null else Vector2i.ZERO


## Live-follows a zone's Plinth/Building/PickArea to world_center during an
## in-progress drag. Does not touch the ZoneFixture or run any validity
## check -- that only happens once, at try_commit_zone_move(), on release.
func preview_zone_position(zone_id: String, world_center: Vector3) -> void:
	var zone_node: Node3D = _zone_nodes_by_id.get(zone_id)
	if zone_node == null:
		return
	_reposition_zone_group(zone_node, world_center)


## Validates and commits (or rejects) a drag-repositioned zone at the given
## target tile origin (grid-snapped tile_col/tile_row, not a world position).
## On success: mutates the ZoneFixture in place, snaps the visual group to
## the exact tile-aligned center, and returns true. On failure (out of grid
## bounds, or overlaps another zone/plot's footprint): snaps the visual back
## to the zone's last-committed position and returns false.
func try_commit_zone_move(zone_id: String, target_col: int, target_row: int) -> bool:
	var zone: ZoneFixture = _zones_by_id.get(zone_id)
	var zone_node: Node3D = _zone_nodes_by_id.get(zone_id)
	if zone == null or zone_node == null:
		return false

	var fits := _zone_fits(zone, target_col, target_row)
	if fits:
		zone.tile_col = target_col
		zone.tile_row = target_row
		_economy.move_zone(zone_id, float(target_col), float(target_row))
		if _economy.dirty:
			SaveSystem.save_state(_economy.state)
			_economy.dirty = false
	_reposition_zone_group(zone_node, _zone_center_world(zone))
	return fits
