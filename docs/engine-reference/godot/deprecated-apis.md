# Godot — Deprecated / Renamed APIs (as of 4.7.1)

Last verified: 2026-08-18. GDScript-relevant entries only are flagged for
priority attention, since ADR-0002 pins this project to GDScript
(`godot-gdscript-specialist` owns this file's application). C#-only entries
are kept for completeness in case ADR-0002 is ever revisited.

| Old API | Replacement | Since | Relevant To This Project? |
|---|---|---|---|
| `object_cast_to()` / `classdb_get_class_tag()` (GDExtension) | `is_class()` casts | 4.7 | No — GDScript-only, no GDExtension planned |
| Google Play OBB export | Play Asset Delivery or PCK split | 4.7 (removal of already-deprecated support) | **Yes if publishing to Google Play with assets exceeding APK/AAB limits** — see `modules/android-export.md` |
| `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | `UPDATE_WIDTH_UNIT` | 4.7 | Only if UI port (EPIC-M4) uses `RichTextLabel` image sizing |
| `RichTextLabel.add_image()`/`update_image()` `width_in_percent`/`height_in_percent` (bool) | `width_unit`/`height_unit` (`RichTextLabel.ImageUnit`) | 4.7 | Only if UI port uses this API |
| `RenderingServer.particles_request_process_time()` `time` param | `process_time` param | 4.7 | Only if custom particle systems are used |
| `AnimationNodeBlendSpace1D`/`2D` `sync` (bool) | `SyncMode` enum | 4.6 | Only if AnimationTree blend spaces are used (possible in EPIC-M6/M7 villager animation) |
| `FileAccess.get_as_text()` `skip_cr` param | removed, no replacement param | 4.6 | Check if used in save/load code (moot per ADR-0002's clean save format, but worth checking on any other file I/O) |
| `EditorFileDialog.add_side_menu()` | removed entirely | 4.6 | Editor-tooling only, not runtime-relevant |
| `AStar2D`/`AStar3D`/`AStarGrid2D` path methods from disabled/solid start point | now return empty path (was previously different) | 4.6 | **Yes — EPIC-M6 villager pathfinding must handle empty-path returns explicitly** |

## GDScript Language-Level Changes (Not API Renames, But Behavior Changes)

- **Packed array element assignment** no longer triggers the setter for the
  whole property (4.7) — if any planned code relies on assignment-triggers-
  setter for packed arrays (`PackedInt32Array`, etc.), that pattern breaks.
- **Typed-return methods now require an explicit `return`** (4.7) — write
  GDScript methods with declared return types accordingly from the start;
  this project has no legacy code to audit for it, but it's worth knowing
  before `godot-gdscript-specialist` starts writing EPIC-M2's economy port.

## How to Use This File

Before `godot-gdscript-specialist` (or any Godot specialist) suggests using
an API, check the table above. If an API isn't listed here, it's not known
to be deprecated as of 4.7.1 — but this list is derived from official
upgrade-guide pages covering 4.5→4.7 specifically, not an exhaustive API
diff, so verify uncertain cases against `docs.godotengine.org/en/4.7/` via
WebFetch rather than assuming silence means safety.
