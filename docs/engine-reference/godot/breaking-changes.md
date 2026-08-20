# Godot — Breaking Changes (4.5 → 4.6 → 4.7)

Last verified: 2026-08-18. Source: official Godot upgrade guides
(`docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html`,
`docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html`).
This project is pinned to 4.7.1 and starts fresh (no prior Godot codebase to
migrate), so most C#-binary-incompatibility notes below are not directly
relevant (ADR-0002: GDScript, not C#) — kept for completeness and flagged
where GDScript-relevant.

## 4.5 → 4.6

**Rendering defaults changed — visually significant, relevant to EPIC-M1
(art direction)**:
- Glow post-processing: much faster on mobile; now uses Screen blending mode
  and applies before tone-mapping — **appears brighter than 4.5**
- Volumetric fog blending: more physically accurate — **appears brighter**
- Mobile renderer glow effect: rewritten

**GLSL shader breaking change**: `view_matrix`/`inv_view_matrix` in the
built-in `SceneData` uniform changed from `mat4` to `mat3x4` — any custom
shader using these needs transposed matrix operations. Relevant if EPIC-M1's
stylized/cel-shading pass writes custom shaders.

**Android export**: project layout restructured —
`android/build/src/` → `android/build/src/main/java/`. Relevant to EPIC-M0's
Android export setup; see `modules/android-export.md`.

**Navigation pathfinding**: `AStar2D.get_point_path()`,
`AStar3D.get_point_path()`, and `AStarGrid2D` path methods now return
**empty paths** when starting from a disabled/solid point (previously may
have behaved differently). **Relevant to EPIC-M6** (villager pathfinding) —
a villager actor whose start tile becomes solid/disabled mid-path (e.g. a
player drags a structure onto it) will get an empty path back, not a
best-effort partial one; handle this case explicitly rather than assuming a
path always exists.

**Other**: `FileAccess.get_as_text()` lost its `skip_cr` parameter;
`AnimationPlayer` string properties changed to `StringName` (C#-relevant,
not GDScript); `MeshInstance3D.skeleton` default path changed.

## 4.6 → 4.7

**Shader preprocessor restrictions** — some macro patterns that compiled in
4.6 no longer compile in 4.7. Relevant if EPIC-M1 writes custom shaders;
re-verify against 4.7 syntax, don't assume 4.6-era shader tutorials compile
as-is.

**Android: Google Play OBB support removed** (was already deprecated). If
distributing via Google Play with assets beyond the APK/AAB size limit, must
use Play Asset Delivery or PCK split instead of OBB. See
`modules/android-export.md`.

**LinearToSRGB shader**: no longer clamps to `[0.0, 1.0]` in Mobile/Forward+
renderers — relevant to EPIC-M1 if color values can exceed that range.

**GDExtension**: `object_cast_to`/`classdb_get_class_tag` deprecated in favor
of `is_class` casts — not relevant, this project is GDScript-only (ADR-0002).

**GDScript-specific**:
- Packed array element assignment no longer triggers the setter for the
  whole property (was previously a common footgun/workaround pattern —
  don't rely on it)
- Methods declaring a typed return value now require an explicit `return`
  statement (previously may have been permissive)

**Other**: `RenderingServer.particles_request_process_time()` parameter
renamed; `RichTextLabel` image-sizing API changed (`width_in_percent`/
`height_in_percent` params renamed and retyped); minimum macOS version
raised to 11 (not relevant, Android-only project); input device IDs for
mouse/keyboard changed from `0` to named constants.

## Not Yet Covered

This project has not yet upgraded past 4.7.1, so there is no 4.7→4.8+
section. Run `/setup-engine refresh` or `/setup-engine upgrade` when a newer
version is considered.
