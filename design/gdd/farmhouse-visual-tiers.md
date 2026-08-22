# Farmhouse Visual Tiers

## 1. Overview

The Farmhouse's 8 numeric progression levels currently render as the exact
same 3D model regardless of level (`building-type-a.obj`, hardcoded). This
closes that gap: the Farmhouse's rendered model now changes as the player
upgrades, using the 5 visual tiers already implied by
`GameData.farmhouse_level_def()`'s own emoji choices (🛖 → 🏠 → 🏡 → 🏰 →
🏛️), reusing CC0 models already sourced in `assets_3d/city-kit-suburban/`.
Fixed footprint, model re-skin only this pass (see Tuning Knobs for the
footprint-growth stretch, deliberately deferred).

## 2. Player Fantasy

*"I can see what I've built."* `design/gdd/farmhouse-progression.md`
already quotes the game's own `v2.md` design intent directly: the
Farmhouse is meant to be "a central visual representation of the player's
success," growing from "a humble rural home" into "a sprawling Haveli or
modern agricultural estate." Today that promise is unmet -- the numbers
change, the building doesn't. This closes that gap with the smallest
change that actually delivers the payoff: the player's single biggest,
most-visited structure visibly grows as they invest in it.

## 3. Detailed Rules

- `farmhouse_level` (0-7) maps to one of **5 visual tiers**, following the
  boundaries `farmhouse_level_def()`'s own emoji sequence already implies
  (🛖 alone at 0, 🏠 spans 1-2, 🏡 spans 3-4, 🏰 spans 5-6, 🏛️ alone at 7)
  -- not a new, separately-invented tier scheme.
- Each tier maps to one `.obj` model from the already-sourced
  `city-kit-suburban` kit (see Formulas). No new asset sourcing needed.
- The model swap happens automatically as part of the existing
  `VillageSnapshotMapper.build()` → `village_board.gd rebuild()` cycle,
  the same pipeline that already re-renders the whole board on any
  `GameState` change -- no new rebuild trigger needed, buying an upgrade
  already causes a rebuild.
- Footprint, plinth size, and board position are unchanged across all 5
  tiers this pass -- only the building model swaps. (Deliberately deferred
  -- see Tuning Knobs.)
- No new visual "upgrade moment" juice/animation this pass -- the model
  simply appears correctly on the next rebuild, same as every other
  zone-state-driven visual change in this project (crop growth stages,
  locked-zone placeholders). A dedicated transform-beat effect is flagged
  as a future enhancement, not built here.

## 4. Formulas

**Tier -> model mapping** (`VillageFixtureData.farmhouse_model_path(level)`):

| Tier | Levels | Emoji | Model | Rationale |
|---|---|---|---|---|
| 1 | 0 | 🛖 | `building-type-h.obj` | Smallest file size (63.7KB) among the 20 sourced `building-type-*` shells -- simplest geometry, reads as the humblest starting structure. |
| 2 | 1-2 | 🏠 | `building-type-a.obj` | The model already in use today (101.8KB) -- kept as a mid-tier for continuity with every existing screenshot/save rather than discarded. |
| 3 | 3-4 | 🏡 | `building-type-l.obj` | Next step up (117.7KB). |
| 4 | 5-6 | 🏰 | `building-type-d.obj` | Larger still (163.1KB). |
| 5 | 7 | 🏛️ | `building-type-t.obj` | Largest file size among all 20 (189.1KB) -- the grandest available shell for the max-level Estate. |

Model size is used as a size/complexity proxy for grandeur, since these
are unmodified CC0 stand-in shells (`assets_3d/README.md` already
documents Farmhouse as using "`building-type-*.obj` (pick one house
shell)" -- there's no bespoke Indian-architecture model in any sourced
kit). Same honest stand-in precedent as Polyhouse's placeholder box and
Vertical Farm's windmill silhouette.

Scale/positioning: unchanged from today's single-model logic --
`_footprint_scale_factor()` against the same 2x2 footprint, `base_y` at
plinth height (Kenney models are base-anchored). No per-model scale
tuning needed since all 5 are shells from the same kit at the same
authored scale.

## 5. Edge Cases

- **Level out of range**: `farmhouse_model_path()` mirrors
  `farmhouse_level_def()`'s own existing defensive clamp (out-of-range
  level -> last tier), never crashes or returns an empty path.
- **Mid-upgrade-animation state**: not applicable -- there is no
  in-progress animation state for a Farmhouse upgrade (it's an instant
  `buy_farmhouse_upgrade()` call followed by a full rebuild), so there's
  no intermediate visual state to handle.
- **Save loaded at a level whose tier model changed**: not a real
  concern -- the mapping is level-driven and computed fresh on every
  rebuild, never cached in `GameState`, so any level always resolves to
  the correct current tier model.

## 6. Dependencies

- `village_fixture_data.gd` (new `farmhouse_model_path(level: int)`,
  replacing the flat `FARMHOUSE_MODEL` constant)
- `village_snapshot_mapper.gd`'s `_build_farmhouse(state)` (passes
  `state.farmhouse_level` through to the new lookup)
- `game_data.gd`'s existing `farmhouse_level_def()` (source of truth for
  the 5-tier emoji boundaries this reuses, not duplicates)
- Does **not** touch `game_economy.gd`, `farmhouse_tab.gd`, or any
  GameState field -- purely a render-layer change driven by the level
  that already exists.

## 7. Tuning Knobs

- The 5 model picks themselves -- swappable any time by editing
  `farmhouse_model_path()`'s table; no other code depends on which
  specific `.obj` is used per tier.
- **Decided against, not just deferred (2026-08-22)**: footprint growth
  per tier (a bigger Farmhouse at higher levels). Re-examined when the
  other item-1/3/4 stretch goals were being worked through the same
  session -- the original scoping brief's own recommendation was
  explicit ("footprint growth as a v2 stretch," keep this pass at
  fixed-footprint M complexity), and it would force resolving
  `land-and-structures.md`'s genuinely still-open zone/decoration
  collision-validation question as a side effect of a *visual* feature,
  with real risk of a larger Farmhouse newly overlapping a player's
  already-placed decoration. Fixed-footprint stays the shipped design,
  not a placeholder awaiting a follow-up.
- **Future stretch**: a visible transform/juice effect on the upgrade
  moment itself (currently just the standard full-board rebuild).
- Applying the same per-tier-model treatment to
  Polyhouse/Agroforestry/Aquaculture/Vertical Farm's own sub-upgrades
  (Fan & Pad, UV Film, Security, Electricity) as small visual cues --
  see `land-and-structures.md`'s own Tuning Knobs for the built version
  (a shared tint/emissive treatment, not per-flag distinct attachment
  meshes -- see that doc for why).

## 8. Acceptance Criteria

- [ ] `farmhouse_model_path(level)` returns the correct tier model for
      every level 0-7, verified by unit test against the exact table above.
- [ ] Out-of-range levels clamp to the last tier rather than erroring.
- [ ] `_build_farmhouse()` passes the real `state.farmhouse_level` through
      (not a hardcoded value), verified by a snapshot-mapper test.
- [ ] Full GUT suite green.
- [ ] Verified on-device: at least 3 distinct tiers (low/mid/high level)
      render correctly with no crash, no black-silhouette/missing-texture
      regression, and a visibly different building shell at each sampled
      tier.
