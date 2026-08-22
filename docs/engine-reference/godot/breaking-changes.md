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

## Project-Specific Findings (Empirical, On-Device)

Unlike the sections above (sourced from official upgrade guides), this
section records behavior discovered by actually running this project's own
build on real hardware — the class of finding `VERSION.md` explicitly warns
won't be in any doc, since this pinned version is past the training cutoff.

### `Environment.glow_enabled = true` breaks rendering on this project's `gl_compatibility` renderer (found 2026-08-22/23)

**Symptom**: with `glow_enabled = true` on `village_board.tscn`'s
`WorldEnvironment`, the entire background renders as a garish, blown-out,
oversaturated bright blue — not a subtle bloom effect, a broken scene. Held
true even at conservative settings (`glow_intensity = 0.5`, `glow_bloom =
0.0`, `glow_hdr_threshold = 1.0`, Godot's own default threshold — meaning
only genuinely-HDR-bright pixels should trigger glow at all).

**Isolated via empirical, one-variable-at-a-time testing** (export → `adb
install -r` → launch → screencap, repeated per step, matching this
project's standard verify-before-trusting-this-engine-version discipline):
1. `tonemap_mode=FILMIC` + `glow_enabled=true` + `adjustment_enabled=true`
   together → broken.
2. Removed tonemap, reduced glow/adjustment values → still broken (rules out
   tonemap and rules out "values too strong" as the sole cause).
3. `glow_enabled=false`, nothing else → fixed. Conclusively isolates glow.
4. `glow_enabled=false` + `adjustment_enabled=true` (brightness 1.0, contrast
   1.03, saturation 1.06) → confirmed safe, tested on-device at Night phase
   (the darker, more failure-prone end of this project's day/night range).

**Root cause (suspected, not confirmed against Godot source)**: this
project's `project.godot` pins `renderer/rendering_method="gl_compatibility"`
for both desktop and mobile — not Forward+ or the Mobile renderer tier. The
4.5→4.6 note above ("Mobile renderer glow effect: rewritten") may or may not
cover `gl_compatibility` specifically; terminology is ambiguous in this
HIGH-knowledge-risk, post-training-cutoff territory, and this was not
resolved by reading docs — only by the on-device test above.

**Practical rule for this project**: do not enable `glow_enabled` on
`gl_compatibility` without a fresh on-device isolation test. `adjustment_*`
(brightness/contrast/saturation) tested safe independently — it's a
post-process color-grade multiply, not part of the HDR/bloom pipeline that
broke, so it is not suspected to share the same failure mode.

## Not Yet Covered

This project has not yet upgraded past 4.7.1, so there is no 4.7→4.8+
section. Run `/setup-engine refresh` or `/setup-engine upgrade` when a newer
version is considered.
