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
##
## EPIC-M4 slice 2 addition: a GrowthTickTimer (3s interval) now drives
## GameEconomy.resolve_growth_completions() during live play -- previously
## nothing in the scene graph did (only tests called it). See
## persist_and_rebuild_if_dirty() for the shared save-if-dirty + re-render
## pattern this and seed_picker.gd (planting) both use, and rebuild()'s
## `preserve_camera` param for why neither of those triggers a full camera
## reframe the way the initial _ready() rebuild() does.
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
const PICK_LAYER_DECORATIONS: int = 4

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
@onready var _growth_tick_timer: Timer = $GrowthTickTimer

## zone.id -> ZoneFixture. This is the single in-memory source of truth for a
## zone's current tile position; try_commit_zone_move() mutates it in place so
## repeated drags in the same session accumulate correctly without a full
## rebuild() round-trip.
var _zones_by_id: Dictionary = {}
## zone.id -> the zone's root Node3D (parent of its Plinth/Building/PickArea).
var _zone_nodes_by_id: Dictionary = {}
## decoration.id (int) -> the decoration's root Node3D (mesh + PickArea
## siblings, see _build_decoration()) -- same rationale as
## _zone_nodes_by_id, for decoration drag-to-reposition (EPIC-M5 parity
## pass).
var _decoration_nodes_by_id: Dictionary = {}
## Owns the economy/save lifecycle for the whole board (see class doc) --
## no autoload, no other node touches this.
var _economy: GameEconomy


func _ready() -> void:
	var loaded_state := SaveSystem.load_state()
	_economy = GameEconomy.new(loaded_state)
	var zones := VillageSnapshotMapper.build(_economy.state)
	var overlaps := _find_overlapping_tiles(zones)
	if not overlaps.is_empty():
		# Logged loudly for developers, but NOT a hard assert (as this used to
		# be) -- a real bug found via on-device testing during EPIC-M4 slice
		# 3: the automated overlap test (test_village_snapshot_mapper.gd) only
		# covers the DEFAULT layout with every zone unlocked; it does not (and,
		# short of solving general layout constraint satisfaction, reasonably
		# can't) cover every custom zone position a player's save might
		# accumulate via drag (EPIC-M3) combined with later unlocking other
		# zones whose plot grids weren't accounted for at drag-time.
		# `assert(false, ...)` here used to halt _ready() entirely, silently
		# skipping the rebuild(zones) call below and leaving the board
		# permanently blank -- a real player hitting this rare edge case would
		# have an unrecoverable "empty board" save with no error shown to them
		# at all. A visual same-tile overlap is a strictly better failure mode
		# than a blank, unusable board.
		push_error("VillageBoard: zone/plot footprint overlap at tiles: %s" % [overlaps])
	else:
		print("VillageBoard: overlap check passed -- %d zones, no footprint collisions." % zones.size())
	rebuild(zones)

	_growth_tick_timer.timeout.connect(_on_growth_tick_timeout)


## Wipes and rebuilds the static layer (ground, boundary, zones+plinths+plots)
## from the given fixture data. Does not touch ActorLayer or BoardInteractor
## (selection highlight / drag state survive a rebuild, since neither is a
## child of StaticLayer).
##
## `preserve_camera`: when false (the default -- used by _ready()'s initial
## call), also reframes the camera to the board's full bounds via
## CameraRig.frame_bounds(), which resets zoom to fully-zoomed-out and pan to
## centered (see camera_rig.gd's own doc comment). When true (used by
## persist_and_rebuild_if_dirty() below), the camera is left exactly where
## the player last put it -- resetting framing on every 3s growth tick or
## every seed planted would be a jarring regression, not a neutral refresh.
func rebuild(zones: Array[ZoneFixture], preserve_camera: bool = false) -> void:
	for child in _static_layer.get_children():
		child.queue_free()
	_zones_by_id.clear()
	_zone_nodes_by_id.clear()
	_decoration_nodes_by_id.clear()

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

	var decorations_node := Node3D.new()
	decorations_node.name = "Decorations"
	_static_layer.add_child(decorations_node)
	for decoration: Decoration in _economy.state.decorations:
		var decoration_node := _build_decoration(decoration)
		decorations_node.add_child(decoration_node)
		_decoration_nodes_by_id[decoration.id] = decoration_node

	if not preserve_camera:
		var bounds := _board_bounds()
		_camera_rig.frame_bounds(bounds.center, bounds.extents)


func _grid_to_world(col: float, row: float) -> Vector3:
	var x := (col - float(GRID_COLS - 1) / 2.0) * TILE_SIZE
	var z := (row - float(GRID_ROWS - 1) / 2.0) * TILE_SIZE
	return Vector3(x, 0.0, z)


## Inverse of _grid_to_world() -- nearest (col, row) for a world-space ground
## hit, NOT rounded to an integer tile here (GameEconomy.place_decoration()
## stores raw float tile coordinates, matching the Kotlin original's
## `tileX.roundToInt().toFloat()` rounding -- done by the caller,
## board_interactor.gd's _place_armed_decoration(), not baked in here so this
## stays a pure coordinate-space conversion).
func world_to_grid(world_pos: Vector3) -> Vector2:
	var col := world_pos.x / TILE_SIZE + float(GRID_COLS - 1) / 2.0
	var row := world_pos.z / TILE_SIZE + float(GRID_ROWS - 1) / 2.0
	return Vector2(col, row)


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
## Every tile ANY zone other than `exclude_zone_id` could ever need --
## building footprint plus full plot-grid extent at MAXIMUM capacity,
## regardless of current unlock state (VillageSnapshotMapper.
## max_reserved_tiles(), evaluated at each zone's CURRENT resolved anchor
## -- default or custom-dragged, via resolved_anchor()). Deliberately more
## conservative than "what's actually built right now" -- see
## max_reserved_tiles()'s own doc comment for the real bug this closes:
## a zone drag that only checked currently-existing footprints could still
## land on ground a not-yet-unlocked zone's future plot grid would need,
## creating an unrejectable overlap once that zone was later purchased.
## `state` is an explicit parameter (not read implicitly off `self._economy`)
## specifically so this is directly unit-testable via a bare GameState --
## see tests/unit/test_village_snapshot_mapper.gd's
## test_reserved_tiles_map_* tests, which instantiate this scene
## (add_child_autofree) but drive it with hand-built state, not a full
## SaveSystem-backed GameEconomy.
func _build_reserved_tiles_map(state: GameState, exclude_zone_id: String) -> Dictionary:
	var reserved: Dictionary = {}
	for zone_id in [
		VillageSnapshotMapper.ZONE_ID_FARMHOUSE, VillageSnapshotMapper.ZONE_ID_OPEN_FIELD,
		VillageSnapshotMapper.ZONE_ID_POLYHOUSE, VillageSnapshotMapper.ZONE_ID_MANDI,
		VillageSnapshotMapper.ZONE_ID_AGROFORESTRY, VillageSnapshotMapper.ZONE_ID_AQUACULTURE,
		VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM,
	]:
		if zone_id == exclude_zone_id:
			continue
		var anchor := VillageSnapshotMapper.resolved_anchor(state, zone_id)
		for tile in VillageSnapshotMapper.max_reserved_tiles(zone_id, anchor):
			reserved[tile] = zone_id
	return reserved


## True if `zone` would sit fully inside the grid and not overlap any OTHER
## zone's maximum possible footprint (building + full plot-grid extent, see
## _build_reserved_tiles_map()), were its origin (target_col, target_row)
## instead of its current position.
func _zone_fits(zone: ZoneFixture, target_col: int, target_row: int) -> bool:
	if target_col < 0 or target_row < 0:
		return false
	if target_col + zone.tile_width > GRID_COLS or target_row + zone.tile_depth > GRID_ROWS:
		return false

	var occupied := _build_reserved_tiles_map(_economy.state, zone.id)
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


## Renders one placed decoration using its curated Kenney model (EPIC-M5
## parity pass -- replaces the flat placeholder box EPIC-M4 slice 3 shipped
## with, per assets_3d/README's "Suggested mapping" table). Rangoli has no
## Kenney equivalent and gets a procedural flat decal instead -- see
## _build_rangoli_decal(). Returns a wrapper Node3D (mesh + PickArea
## siblings, same shape as _build_zone()'s return) rather than the
## MeshInstance3D directly -- the
## PickArea must NOT inherit the mesh's own transform (specifically its
## negative x-scale when `flipped_x` is set: Godot collision shapes under a
## negative-scale parent behave unpredictably, so the PickArea gets its own
## independent, always-positive-scale local transform instead).
##
## IMPORTANT: `root.position` carries the decoration's actual world
## position; both children stay at LOCAL origin (position untouched,
## defaulting to Vector3.ZERO). This was a real bug found and fixed during
## EPIC-M5's decoration-drag testing: an earlier version left root.position
## at its default ZERO and set world_pos directly on the mesh child instead.
## get_decoration_world_position()/preview_decoration_position()/
## commit_decoration_move() all read/write root.position (matching every
## other per-entity node this file tracks, e.g. _zone_nodes_by_id's zone
## group nodes) -- with world_pos on the child instead, those functions
## silently operated on the wrong node: get_decoration_world_position()
## always returned ZERO, so a drag's delta was computed from the wrong
## start point, and Node3D's hierarchical transform composition (root ZERO
## + child's already-correct absolute position) happened to render the
## LIVE preview in the right place by pure coincidence -- while
## commit_decoration_move() persisted the wrong (under-offset) tile
## position to disk the whole time. The bug was invisible until a fresh
## rebuild() (e.g. after a relaunch) read the actual (wrong) saved position
## back, which could land the decoration on top of or inside a zone's
## footprint -- looking exactly like a rendering/occlusion bug, but the
## data was wrong from the first commit onward. Root-caused via an on-device
## diagnostic (temporary print() instrumentation + adb logcat, not
## guesswork) rather than assumed to be a rendering/occlusion issue --
## village_board.gd has no unit test file for the same reason every other
## scene-tree-dependent file here doesn't (see board_interactor.gd/
## camera_rig.gd's precedent); verified instead via on-device ground truth
## (a save-file read confirming the tile position after a drag matches
## between a live commit and a post-relaunch reload).
func _build_decoration(decoration: Decoration) -> Node3D:
	var world_pos := _grid_to_world(decoration.tile_x, decoration.tile_y) + Vector3(0.0, PLINTH_HEIGHT + 0.15, 0.0)
	# Fixed tap-target size, independent of the visual model's own footprint
	# (real Kenney models vary a lot in native shape -- a fountain and a
	# lantern shouldn't have wildly different collision sizes just because
	# their meshes do). Unchanged from the placeholder-box version.
	var pick_box_size := Vector3(0.35, 0.3, 0.35) * TILE_SIZE

	var root := Node3D.new()
	root.name = "Decoration_%d" % decoration.id
	root.position = world_pos

	var instance := _build_decoration_visual(decoration.type)
	instance.rotation_degrees.y = float(decoration.rotation_degrees)
	instance.scale.x *= -1.0 if decoration.flipped_x else 1.0
	_apply_toon_shading(instance)
	root.add_child(instance)

	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = PICK_LAYER_DECORATIONS
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = false
	pick_area.set_meta("board_kind", "decoration")
	pick_area.set_meta("board_id", str(decoration.id))
	pick_area.set_meta("decoration_id", decoration.id)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = pick_box_size
	shape.shape = box_shape
	pick_area.add_child(shape)
	root.add_child(pick_area)

	return root


## Object-style decorations (everything except the flat Dirt Path/Rangoli
## ground decals) are normalized to this fraction of a tile -- smaller than
## FILL_RATIO (0.85, used for tile-filling ground pieces/plots) since these
## are accent objects sitting ON a tile, not covering it.
const _DECORATION_OBJECT_FILL_RATIO: float = 0.5


## Loads and scale-normalizes the curated model for `type`, or builds the
## procedural Rangoli decal -- see this function's callers' doc comments.
func _build_decoration_visual(type: int) -> MeshInstance3D:
	if type == DecorationType.Kind.RANGOLI:
		return _build_rangoli_decal()

	var instance := MeshInstance3D.new()
	var raw_mesh: Mesh = load(_decoration_model_path(type))
	instance.mesh = raw_mesh
	var fill_ratio := FILL_RATIO if type == DecorationType.Kind.DIRT_PATH else _DECORATION_OBJECT_FILL_RATIO
	var scale_factor := _footprint_scale_factor(raw_mesh, TILE_SIZE * fill_ratio)
	instance.scale = Vector3.ONE * scale_factor
	return instance


func _decoration_model_path(type: int) -> String:
	match type:
		DecorationType.Kind.POTTED_PLANT:
			return VillageFixtureData.DECORATION_POTTED_PLANT_MODEL
		DecorationType.Kind.SUNFLOWER:
			return VillageFixtureData.DECORATION_SUNFLOWER_MODEL
		DecorationType.Kind.BAMBOO:
			return VillageFixtureData.DECORATION_BAMBOO_MODEL
		DecorationType.Kind.LANTERN:
			return VillageFixtureData.DECORATION_LANTERN_MODEL
		DecorationType.Kind.FOUNTAIN:
			return VillageFixtureData.DECORATION_FOUNTAIN_MODEL
		DecorationType.Kind.STATUE:
			return VillageFixtureData.DECORATION_STATUE_MODEL
		DecorationType.Kind.DIRT_PATH:
			return VillageFixtureData.DECORATION_DIRT_PATH_MODEL
		_:
			return ""  # RANGOLI never reaches here -- see _build_decoration_visual().


## Flat, alpha-blended ground decal for Rangoli -- the painted/powdered
## floor pattern set outside Indian homes for festivals and daily welcome.
## No Kenney kit has an equivalent (culturally-specific, see
## village_fixture_data.gd's model-constants header comment), so this is a
## simplified Godot port of the pre-existing
## core/.../village3d/RangoliModelBuilder.kt's runtime-painted 8-petal
## texture (same petal count, same color bands/radii, built via Godot's
## Image/ImageTexture instead of LibGDX's Pixmap/Texture -- half the source
## resolution, 64px not 128px, adequate at this decal's on-screen size).
## shading_mode = UNSHADED so the caller's subsequent _apply_toon_shading()
## call (applied uniformly to every decoration type, not special-cased
## here) is a harmless no-op instead of darkening the painted colors -- a
## rangoli should read as flat paint, not a toon-shaded 3D object.
const _RANGOLI_TEXTURE_SIZE: int = 64
const _RANGOLI_PETAL_COUNT: int = 8

func _build_rangoli_decal() -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (TILE_SIZE * FILL_RATIO)
	instance.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _build_rangoli_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = mat
	return instance


func _build_rangoli_texture() -> ImageTexture:
	var size := _RANGOLI_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) / 2.0
	var outer_radius := center * 0.92
	# Festive rangoli palette -- the colors traditionally used in kolam/
	# rangoli powder. Matches RangoliModelBuilder.kt's palette exactly.
	var petal_a := Color(0.85, 0.15, 0.45)  # magenta
	var petal_b := Color(0.95, 0.65, 0.10)  # saffron
	var center_color := Color(0.80, 0.10, 0.15)  # deep red bindu
	var outline := Color(1.0, 0.95, 0.85)  # warm white
	var angle_per_petal := TAU / _RANGOLI_PETAL_COUNT

	for y in range(size):
		for x in range(size):
			var dx := float(x) - center
			var dy := float(y) - center
			var dist := sqrt(dx * dx + dy * dy)
			if dist > outer_radius:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var norm_dist := dist / outer_radius
			var angle := atan2(dy, dx) + PI
			var sector := int(angle / angle_per_petal)
			var local_angle := angle - (sector + 0.5) * angle_per_petal
			# Maps the petal's angular center to a full bump (1.0) and its
			# edges to 0 -- a smooth scalloped lobe, not a plain disc or a
			# hard pie-slice.
			var bump := clampf(cos((local_angle / (angle_per_petal / 2.0)) * (PI / 2.0)), 0.0, 1.0)
			var lobe_radius := 0.40 + 0.42 * bump

			var color: Color
			if norm_dist < 0.14:
				color = center_color
			elif norm_dist < 0.20:
				color = outline
			elif norm_dist < lobe_radius:
				color = petal_a if sector % 2 == 0 else petal_b
			elif norm_dist < lobe_radius + 0.035:
				color = outline
			else:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			# Soft-fades the very outer edge so the decal blends into the
			# grass instead of ending in a hard silhouette.
			if norm_dist > 0.85:
				color.a *= clampf((1.0 - norm_dist) / 0.15, 0.0, 1.0)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


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
	# EPIC-M4 slice 2: the real integer Plot.id (or -1 for a GHOST tile with
	# no backing Plot) plus its PlotKind/Lifecycle, read by
	# board_interactor.gd off this PickArea's meta to drive the seed picker.
	# board_id/board_kind above are left exactly as before (still the
	# string-encoded id get_plot_footprint() parses) -- these are additive,
	# not a replacement, so existing selection/footprint code is unaffected.
	pick_area.set_meta("plot_id", plot.plot_id)
	pick_area.set_meta("plot_kind", plot.kind)
	pick_area.set_meta("plot_lifecycle", plot.lifecycle)
	# EPIC-M4 slice 3: read by board_interactor.gd to distinguish an
	# Agroforestry tile with a host planted (tap removes it) from a
	# genuinely empty one (tap opens the host/Sandalwood picker) -- both
	# read as Lifecycle.EMPTY, since a host occupying a tile doesn't touch
	# Plot.state at all (see game_economy.gd's plant_host()/remove_host()).
	pick_area.set_meta("host_occupied", plot.host_occupied)
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


## Current world-space position of a placed decoration, by id -- used by
## BoardInteractor to compute a drag delta the same way zone dragging does
## (EPIC-M5 parity pass: decoration drag-to-reposition).
func get_decoration_world_position(decoration_id: int) -> Vector3:
	var node: Node3D = _decoration_nodes_by_id.get(decoration_id)
	return node.position if node != null else Vector3.ZERO


## Live-follows a decoration to world_pos during an in-progress drag --
## same "preview only, no economy mutation yet" rationale as
## preview_zone_position(). Unlike zones, a decoration has no tile-grid
## snap or overlap validation at all (matches GameEconomy.move_decoration()/
## place_decoration(), neither of which validate -- see game_economy.gd),
## so there is no separate "commit" step beyond directly writing the final
## position; see commit_decoration_move() below.
func preview_decoration_position(decoration_id: int, world_pos: Vector3) -> void:
	var node: Node3D = _decoration_nodes_by_id.get(decoration_id)
	if node == null:
		return
	node.position = world_pos


## Commits a decoration's dragged-to position: converts world_pos to tile
## coordinates (same world_to_grid() the placement flow already uses) and
## calls GameEconomy.move_decoration(), then persists if dirty. Always
## succeeds -- no bounds/overlap check exists for decorations in the
## original either (see preview_decoration_position()'s doc comment).
func commit_decoration_move(decoration_id: int, world_pos: Vector3) -> void:
	var tile := world_to_grid(world_pos)
	_economy.move_decoration(decoration_id, tile.x, tile.y)
	if _economy.dirty:
		SaveSystem.save_state(_economy.state)
		_economy.dirty = false
	var node: Node3D = _decoration_nodes_by_id.get(decoration_id)
	if node != null:
		node.position = world_pos


# ---------------------------------------------------------------------------
# EPIC-M4 public API for HUD. Read-only access to the GameEconomy instance
# VillageBoard already owns and loads in _ready() -- HUD reads its
# state/formulas directly (coins, inventory, is_monsoon_active(), etc.) and
# calls its mutating methods itself (e.g. sell_all()). VillageBoard remains
# the sole owner of the GameEconomy instance and its save lifecycle (see
# class doc) -- this accessor does not transfer ownership; callers persist
# via SaveSystem.save_state()/the dirty flag the same way
# try_commit_zone_move() above already does.
# ---------------------------------------------------------------------------

func get_economy() -> GameEconomy:
	return _economy


## Minimal read-only accessor, same rationale as get_economy() above -- lets
## hud.gd reach BoardInteractor (to arm decoration placement) without a
## fragile tree-shape-coupled get_node() path of its own, matching
## hud.gd's own get_bottom_sheet() accessor's precedent.
func get_board_interactor() -> BoardInteractor:
	return $BoardInteractor as BoardInteractor


## Same rationale as get_board_interactor() above -- lets hud.gd reach
## CameraRig (for the Quick Nav Bar's center_on() calls, EPIC-M5 parity pass)
## without a fragile tree-shape-coupled path of its own.
func get_camera_rig() -> CameraRig:
	return _camera_rig


# ---------------------------------------------------------------------------
# EPIC-M4 slice 2: growth-tick driver + the shared save-if-dirty/re-render
# pattern it and seed_picker.gd both need. Closes the gap flagged in EPIC-M4
# slice 1's session notes -- nothing previously drove
# GameEconomy.resolve_growth_completions() during real play; only tests
# called it. See game_economy.gd's class doc, "bugfix (a)": mutating methods
# set `dirty = true`, and resolve_growth_completions() only does so when a
# plot actually transitioned, specifically so a periodic caller doesn't have
# to unconditionally persist every tick.
# ---------------------------------------------------------------------------

func _on_growth_tick_timeout() -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_economy.resolve_growth_completions(now)
	persist_and_rebuild_if_dirty()


## Shared save-if-dirty + re-render pattern, gated on GameEconomy.dirty per
## bugfix (a) above -- a no-op when nothing actually changed. Used by the
## growth-tick timeout above and by seed_picker.gd after a successful plant.
## `preserve_camera` defaults to true because both of those callers fire
## during live play, potentially after the player has already panned/zoomed
## -- see rebuild()'s own doc comment for why a full camera reset on every
## tick/plant would be a regression. try_commit_zone_move() above
## deliberately does NOT go through this method: it already has its own
## lighter-weight visual sync (_reposition_zone_group()) that avoids a full
## StaticLayer rebuild entirely during an interactive drag.
func persist_and_rebuild_if_dirty(preserve_camera: bool = true) -> void:
	if not _economy.dirty:
		return
	SaveSystem.save_state(_economy.state)
	_economy.dirty = false
	rebuild(VillageSnapshotMapper.build(_economy.state), preserve_camera)
