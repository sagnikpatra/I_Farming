class_name Villager
extends Node3D
## A single ambient villager: a curated KayKit Adventurers character
## (EPIC-M6 asset pipeline, see assets_3d/README.md) driven by the shared
## `Rig_Medium` animation library. This class owns exactly one thing --
## instancing the right character mesh and wiring the shared animation
## library onto it so `play_animation()` works. It deliberately does NOT
## own movement, roaming AI, or spawning/placement decisions; those are
## still-undesigned EPIC-M6 follow-up work (see the roadmap's EPIC-M6
## section), not implemented here.
##
## Character keys are the raw KayKit asset names. Two visual-pass steps
## turn each fantasy-adventurer character into a plausible plain villager:
## (1) _recolor_material_accent() re-hues each character's saturated blue
## accent (neckerchief/trim) toward the same warm saffron/maroon family
## already used for structure zones -- see village_snapshot_mapper.gd's
## *_PLINTH_COLOR constants; (2) every mesh part that isn't a core body
## part (arms/legs/body/head) is hidden outright -- see
## _KEEP_MESH_SUFFIXES below -- which removes Knight's helmet/visor/cape,
## Mage's hat/cape, Barbarian's bear-hat, Rogue/Rogue_Hooded's cape/mask,
## and Ranger's cape/quiver, since a color recolor alone can't fix a
## baked-in weapon or headpiece. Deliberately NOT a full costume redesign
## beyond that: skin, hair, and clothing shape/silhouette are untouched.
## All 6 characters were visually confirmed with both passes applied
## (2026-08-21, side-by-side render) -- each reads as a plausible
## plain-clothed villager, none carry a visible weapon/helmet/hood-prop
## any more. "rogue_hooded" is the one partial exception: its hood is
## sculpted into the Head mesh itself, not a separate hideable prop, so it
## keeps a hooded silhouette -- judged acceptable (a farmer wearing a hood
## is plausible) rather than a defect.

const CHARACTER_SCENES: Dictionary = {
	"barbarian": "res://assets_3d/kaykit-adventurers/glTF/Characters/Barbarian.glb",
	"knight": "res://assets_3d/kaykit-adventurers/glTF/Characters/Knight.glb",
	"mage": "res://assets_3d/kaykit-adventurers/glTF/Characters/Mage.glb",
	"ranger": "res://assets_3d/kaykit-adventurers/glTF/Characters/Ranger.glb",
	"rogue": "res://assets_3d/kaykit-adventurers/glTF/Characters/Rogue.glb",
	"rogue_hooded": "res://assets_3d/kaykit-adventurers/glTF/Characters/Rogue_Hooded.glb",
}

## CHARACTER_SCENES' keys -> a display name, moved here 2026-08-22 (was
## duplicated as a private copy in worker_assignment_row.gd) so that file
## and villager_info_card.gd (the new tap-interaction card, see
## design/gdd/villagers.md rule 8) share one source instead of drifting.
const CHARACTER_DISPLAY_NAMES: Dictionary = {
	"barbarian": "Barbarian",
	"knight": "Knight",
	"mage": "Mage",
	"ranger": "Ranger",
	"rogue": "Rogue",
	"rogue_hooded": "Hooded Rogue",
}

## Both animation-library files share the "Rig_Medium" skeleton/bone naming
## with every character above (verified 2026-08-21 -- see session state);
## MovementBasic is the one with roaming-relevant clips (Walking_A/B/C,
## Running_A/B, Jump_*, T-Pose).
const MOVEMENT_LIBRARY_PATH := "res://assets_3d/kaykit-adventurers/glTF/Animations/Rig_Medium_MovementBasic.glb"
## design/gdd/richer-ambient-villagers.md -- General.glb was "sourced but
## never inspected" per villagers.md's own flagged gap. Direct glTF
## inspection (2026-08-22) found 15 clips, including real Idle_A/Idle_B
## clips on the same shared skeleton -- confirmed usable, not assumed. Only
## the 2 idle clips are pulled in below (not all 15, which are mostly
## unrelated combat/death/spawn clips with no ambient-villager use).
const GENERAL_LIBRARY_PATH := "res://assets_3d/kaykit-adventurers/glTF/Animations/Rig_Medium_General.glb"
const IDLE_CLIP_NAMES: Array[String] = ["Idle_A", "Idle_B"]
const DEFAULT_ANIMATION := "Walking_A"
const ANIMATION_LIBRARY_KEY := "moves"

## Recolor tuning: KayKit's gradient-atlas textures encode each color band
## as a light-to-dark vertical strip. The only strongly saturated
## non-neutral hue observed across the free-tier characters is a cool blue
## accent (roughly cyan through blue-violet); this range/threshold pair was
## picked by sampling the actual ranger_texture.png swatches (see
## production/session-state/active.md's 2026-08-21 entry), not guessed.
const _ACCENT_HUE_MIN: float = 0.50
const _ACCENT_HUE_MAX: float = 0.74
const _ACCENT_MIN_SATURATION: float = 0.30
## Target hue: warm saffron-to-maroon (~14 degrees), same family as
## FARMHOUSE_PLINTH_COLOR's terracotta in village_snapshot_mapper.gd.
const _ACCENT_TARGET_HUE: float = 0.04

## Every character's core body-part meshes share this exact naming suffix
## convention across all 6 free-tier characters -- verified 2026-08-21 by
## directly inspecting every character's node names (not assumed):
## <Name>_ArmLeft/_ArmRight/_Body/_Head/_LegLeft/_LegRight. Any mesh part
## whose name doesn't end with one of these is a prop (helmet, hat, cape,
## mask, quiver, etc.) and gets hidden -- see _is_core_body_part() below.
const _KEEP_MESH_SUFFIXES: Array[String] = [
	"ArmLeft", "ArmRight", "Body", "Head", "LegLeft", "LegRight",
]

## Recolored textures are expensive to compute (a 1024x1024 per-pixel scan)
## but identical for every Villager instance of the same character key, so
## cache by character key across the whole running game.
static var _recolored_texture_cache: Dictionary = {}

var _anim_player: AnimationPlayer
var _character_root: Node3D


## Instances the given character (defaults to "ranger") as a child of this
## node and wires the shared movement animation library onto a fresh
## AnimationPlayer. Safe to call once; re-calling before clearing the
## previous instance is not supported.
func setup(character_key: String = "ranger") -> void:
	var scene_path: String = CHARACTER_SCENES.get(character_key, "")
	if scene_path.is_empty():
		push_error("Villager.setup: unknown character key '%s'" % character_key)
		return

	var char_scene: PackedScene = load(scene_path)
	_character_root = char_scene.instantiate()
	add_child(_character_root)
	_apply_visual_pass_recursive(_character_root, character_key)

	var library := _load_movement_library()
	if library == null:
		push_error("Villager.setup: could not load movement animation library")
		return
	_merge_idle_clips_into(library)

	# Track paths inside the library are relative to the AnimationPlayer's
	# parent (e.g. "Rig_Medium/Skeleton3D:hips") -- so the AnimationPlayer
	# must be a direct sibling of the character's "Rig_Medium" node, i.e. a
	# direct child of _character_root, for those paths to resolve.
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	_character_root.add_child(_anim_player)
	_anim_player.add_animation_library(ANIMATION_LIBRARY_KEY, library)
	play_animation(DEFAULT_ANIMATION)


## Plays a clip from the shared movement library by its bare name (e.g.
## "Walking_A", not "moves/Walking_A"). No-op with a pushed error if
## setup() hasn't been called yet or the clip doesn't exist.
func play_animation(clip_name: String) -> void:
	if _anim_player == null:
		push_error("Villager.play_animation: setup() was not called")
		return
	var full_name := "%s/%s" % [ANIMATION_LIBRARY_KEY, clip_name]
	if not _anim_player.has_animation(full_name):
		push_error("Villager.play_animation: no clip '%s'" % clip_name)
		return
	_anim_player.play(full_name)


func get_animation_player() -> AnimationPlayer:
	return _anim_player


func _load_movement_library() -> AnimationLibrary:
	var anim_scene: PackedScene = load(MOVEMENT_LIBRARY_PATH)
	var anim_root := anim_scene.instantiate()
	var source_player := _find_animation_player(anim_root)
	var library: AnimationLibrary = null
	if source_player != null:
		library = source_player.get_animation_library("")
	anim_root.free()
	return library


## Copies IDLE_CLIP_NAMES from Rig_Medium_General.glb into `library` (the
## movement library, already assigned to the AnimationPlayer under the
## "moves" key) in place, so play_animation("Idle_A") resolves through the
## exact same "moves/X" lookup play_animation() already uses -- no change
## to that method's convention needed. Missing clips are skipped silently
## (mirrors play_animation()'s own no-op-on-missing-clip guard) rather than
## erroring, since a missing idle clip should degrade to "never idles," not
## break character setup entirely.
func _merge_idle_clips_into(library: AnimationLibrary) -> void:
	var anim_scene: PackedScene = load(GENERAL_LIBRARY_PATH)
	var anim_root := anim_scene.instantiate()
	var source_player := _find_animation_player(anim_root)
	if source_player != null:
		var general_library := source_player.get_animation_library("")
		if general_library != null:
			for clip_name in IDLE_CLIP_NAMES:
				if general_library.has_animation(clip_name):
					library.add_animation(clip_name, general_library.get_animation(clip_name))
	anim_root.free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## Walks the instanced character and, for every MeshInstance3D, applies
## both the toon-diffuse/no-specular patch (same technique
## village_board.gd's _apply_toon_shading() uses on every other board
## model, duplicated here rather than exported from that file to keep this
## new EPIC-M6 component decoupled from the stable, already-verified board
## renderer -- see coordination-rules.md's "no unilateral cross-domain
## changes" note) and the accent-color palette recolor below.
func _apply_visual_pass_recursive(node: Node, character_key: String) -> void:
	if node is MeshInstance3D:
		_apply_visual_pass(node as MeshInstance3D, character_key)
	for child in node.get_children():
		_apply_visual_pass_recursive(child, character_key)


func _apply_visual_pass(instance: MeshInstance3D, character_key: String) -> void:
	if not _is_core_body_part(instance.name):
		instance.visible = false
		return

	if instance.material_override != null:
		if instance.material_override is StandardMaterial3D:
			var overridden: StandardMaterial3D = instance.material_override
			overridden.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			overridden.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			_recolor_material_accent(overridden, character_key)
		return

	var mesh := instance.mesh
	if mesh == null:
		return
	for i in range(mesh.get_surface_count()):
		var source_mat := mesh.surface_get_material(i)
		if source_mat is StandardMaterial3D:
			var patched_mat: StandardMaterial3D = source_mat.duplicate()
			patched_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			patched_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			_recolor_material_accent(patched_mat, character_key)
			instance.set_surface_override_material(i, patched_mat)


## Re-hues the material's albedo texture's blue accent band toward the
## warm Indian-palette target hue, in place on the (already-duplicated)
## material passed in. No-op if the material has no albedo texture or the
## texture can't be read back (e.g. a VRAM-compressed import -- not the
## case for these lossless-imported character textures, see
## assets_3d/README.md, but guarded defensively).
func _recolor_material_accent(mat: StandardMaterial3D, character_key: String) -> void:
	if mat.albedo_texture == null:
		return

	var cached: ImageTexture = _recolored_texture_cache.get(character_key)
	if cached == null:
		var source_image := mat.albedo_texture.get_image()
		if source_image == null:
			return
		var recolored_image := source_image.duplicate()
		_recolor_accent_pixels(recolored_image)
		cached = ImageTexture.create_from_image(recolored_image)
		_recolored_texture_cache[character_key] = cached

	mat.albedo_texture = cached


func _is_core_body_part(mesh_name: String) -> bool:
	for suffix in _KEEP_MESH_SUFFIXES:
		if String(mesh_name).ends_with(suffix):
			return true
	return false


func _recolor_accent_pixels(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a < 0.05:
				continue
			if c.s >= _ACCENT_MIN_SATURATION and c.h >= _ACCENT_HUE_MIN and c.h <= _ACCENT_HUE_MAX:
				image.set_pixel(x, y, Color.from_hsv(_ACCENT_TARGET_HUE, c.s, c.v, c.a))
