---
paths:
  - "godot/scripts/village_board/**"
---

# Engine Code Rules

<!-- Update (2026-08-23): path corrected from the template-default
     `src/core/**`, which never matched anything in this project (no
     `src/` directory exists) -- this rule was silently inert for every
     engine-level GDScript edit this whole session. `godot/scripts/village_board/`
     is this project's real rendering/board-interaction layer (the
     Godot-target analog of the old `core/village3d/` LibGDX module). The
     "consult docs/engine-reference/ before writing engine API code" rule
     below is especially relevant here, given this project's pinned
     Godot 4.7.1 is flagged HIGH knowledge-risk (post-training-cutoff). -->


- ZERO allocations in hot paths (update loops, rendering, physics) — pre-allocate, pool, reuse
- All engine APIs must be thread-safe OR explicitly documented as single-thread-only
- Profile before AND after every optimization — document the measured numbers
- Engine code must NEVER depend on gameplay code (strict dependency direction: engine <- gameplay)
- Every public API must have usage examples in its doc comment
- Changes to public interfaces require a deprecation period and migration guide
- Use RAII / deterministic cleanup for all resources
- All engine systems must support graceful degradation
- Before writing engine API code, consult `docs/engine-reference/` for the current engine version and verify APIs against the reference docs

## Examples

**Correct** (zero-alloc hot path):

```gdscript
# Pre-allocated array reused each frame
var _nearby_cache: Array[Node3D] = []

func _physics_process(delta: float) -> void:
    _nearby_cache.clear()  # Reuse, don't reallocate
    _spatial_grid.query_radius(position, radius, _nearby_cache)
```

**Incorrect** (allocating in hot path):

```gdscript
func _physics_process(delta: float) -> void:
    var nearby: Array[Node3D] = []  # VIOLATION: allocates every frame
    nearby = get_tree().get_nodes_in_group("enemies")  # VIOLATION: tree query every frame
```
