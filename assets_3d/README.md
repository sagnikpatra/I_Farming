# 3D asset kits (Part 3 prep)

Free, open-source (CC0 / public domain) 3D model kits acquired for the eventual
"real 3D models" migration scoped separately in the village-view plan (see the
plan history — Part 3 was deliberately deferred; this directory is prep work
for whenever that's picked up, not yet wired into rendering).

All four kits are by **Kenney** (<https://kenney.nl>), released under
**CC0 1.0** (<https://creativecommons.org/publicdomain/zero/1.0/>) — free to
use in personal, educational and commercial projects, no attribution required
(crediting Kenney is appreciated but optional). Each kit's original
`License.txt` is kept alongside its models as the license record.

Only the **OBJ format** subset of each kit is kept here (`.obj` + `.mtl`,
plus a shared `Textures/colormap.png` atlas for the three textured kits) —
LibGDX's built-in `ObjLoader` reads this directly with zero extra
dependencies, and dropping the other bundled formats (FBX/DAE/GLB/STL) that
Kenney ships alongside keeps this directory to ~13MB instead of ~40MB+ for no
loss of usable content.

## Kits

| Folder | Kenney page | Models | Materials | Good for |
|---|---|---|---|---|
| `nature-kit/` | [nature-kit](https://kenney.nl/assets/nature-kit) | 329 | flat vertex colors, no texture | decorations: flowers, mushrooms, bushes, rocks, fences, bamboo crop stages, statues, bridges |
| `graveyard-kit/` | [graveyard-kit](https://kenney.nl/assets/graveyard-kit) | 91 | `colormap.png` atlas | lanterns/lightposts, statues, altars |
| `city-kit-suburban/` | [city-kit-suburban](https://kenney.nl/assets/city-kit-suburban) | 40 | `colormap.png` atlas | `building-type-a`..`u` house shells (structure stand-ins), planters, fences, trees |
| `fantasy-town-kit/` | [fantasy-town-kit](https://kenney.nl/assets/fantasy-town-kit) | 167 | `colormap.png` atlas | fountains, lanterns, hedges, stalls, windmill/watermill, market stalls (structure stand-ins) |

## Suggested mapping to Kisan Khet's game entities

Not final — a real curation pass (and almost certainly some resizing/
recoloring for visual consistency across kits) happens when Part 3 actually
starts. Recorded here so that pass doesn't start from zero.

**Decorations** (`DecorationType` in `GameModels.kt`):

| Decoration | Candidate model |
|---|---|
| 🪴 Potted Plant | `city-kit-suburban/OBJ format/planter.obj` or `nature-kit/OBJ format/plant_bush.obj` |
| 🌻 Sunflower | `nature-kit/OBJ format/flower_yellowA.obj` (also `B`/`C` for variety) |
| 🎋 Bamboo | `nature-kit/OBJ format/crops_bambooStageA.obj` / `crops_bambooStageB.obj` |
| 🏮 Lantern | `fantasy-town-kit/OBJ format/lantern.obj` or `graveyard-kit/OBJ format/lantern-candle.obj` / `lantern-glass.obj` |
| ⛲ Fountain | `fantasy-town-kit/OBJ format/fountain-round.obj` (+ `fountain-round-detail.obj`, `fountain-center.obj`, `fountain-edge.obj` for a modular build) |
| 🗿 Statue | `nature-kit/OBJ format/statue_head.obj`, `statue_obelisk.obj`, `statue_column.obj`, `statue_ring.obj` |

**Structure zones** (stand-ins until/if bespoke farm buildings get modeled):

| Zone | Candidate model |
|---|---|
| Farmhouse | `city-kit-suburban/OBJ format/building-type-*.obj` (pick one house shell) |
| Polyhouse | none of these kits has a greenhouse shape — likely needs a different kit or a simple procedural box+glass material |
| Agroforestry | `nature-kit/OBJ format/tree_*` groupings, or `fantasy-town-kit/OBJ format/hedge*.obj` for the grid border |
| Aquaculture | `fantasy-town-kit/OBJ format/watermill.obj` / `watermill-wide.obj` (waterwheel reads as "pond infrastructure") |
| Vertical Farm | `fantasy-town-kit/OBJ format/windmill.obj` as a placeholder silhouette, or a `city-kit-suburban` multi-story `building-type-*` |
| Mandi | `fantasy-town-kit/OBJ format/stall.obj` / `stall-red.obj` / `stall-green.obj` (market stall reads well as a trading post) |

## Still missing

No kit here has a **greenhouse/polyhouse** shape or **aquaculture pond**
shape specifically — those two structure zones would need either a different
Kenney kit (worth another sourcing pass) or a simple hand-built primitive
(a translucent box for the polyhouse, a flat blue plane + `fence`/`bridge`
pieces already in `nature-kit` for a pond) rather than a found asset.

## Rigged characters (`kaykit-adventurers/`) — EPIC-M6

The four Kenney kits above are static/unrigged (fine for structures and
decorations, but no `.obj` kit has skeleton or animation data — `.obj` has
none by format design). EPIC-M6 (villagers) needed a genuinely different
pipeline: **glTF/GLB with a real `Skeleton3D` + `AnimationPlayer`**, sourced
2026-08-21 from **Kay Lousberg**'s `KayKit — Character Pack: Adventurers`
(Free tier, <https://kaylousberg.itch.io/kaykit-adventurers>), also
**CC0 1.0** (same license terms as the Kenney kits above; `License.txt` kept
alongside as the record). Kept here as source-format prep, same as the other
kits — the curated glTF subset actually used by the Godot project lives at
`godot/assets_3d/kaykit-adventurers/`.

Trimmed from the ~12MB free-tier download to the glTF-format subset only
(dropping the bundled FBX/OBJ/Unity duplicates and preview renders), ~4.6MB:

| Folder | Contents |
|---|---|
| `KayKit_Adventurers_2.0_FREE/Characters/gltf/` | 6 rigged character `.glb` files (Barbarian, Knight, Mage, Ranger, Rogue, Rogue_Hooded) — 23-bone `Skeleton3D` named `Rig_Medium`, embedded textures |
| `KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/` | 2 animation-library `.glb` files sharing the same `Rig_Medium` skeleton — `Rig_Medium_MovementBasic.glb` has the roaming-relevant clips: `Walking_A/B/C`, `Running_A/B`, `Jump_*`, `T-Pose`; `Rig_Medium_General.glb` has more (not yet inspected) |
| `KayKit_Adventurers_2.0_FREE/Assets/gltf/` | 25+ accessory/weapon `.gltf` files (swords, bows, staves, etc.) — fantasy-themed, not obviously farm-appropriate; kept in case a prop (e.g. `staff` → farming tool reskin) proves useful, otherwise unused |

**Verified 2026-08-21** against the project's pinned Godot 4.7.1
(`E:\Godot\Godot_v4.7.1-stable_win64.exe`): all 6 character `.glb` + 2
animation `.glb` files import clean with zero errors via a headless editor
pass (`--headless --editor --quit-after 20`). A one-shot inspection script
confirmed `Barbarian.glb` produces `Skeleton3D` (23 bones) with mesh parts
parented correctly, and `Rig_Medium_MovementBasic.glb` produces a real
`AnimationPlayer` with the clip list above — the script was temporary and
has been deleted after confirming this.

**Not yet done**: retargeting the shared animation library onto each
character's own `AnimationPlayer` (or building a shared rig scene the
villager system instantiates per-NPC), any Indian-village-appropriate
material/palette pass (these read as generic fantasy-adventurer low-poly,
same toon-shading technique used elsewhere in the project should unify the
look), and the actual roaming/pathfinding behavior — all EPIC-M6 scope, not
started.

## Not yet done (Part 3 proper)

This is asset acquisition only. None of this is wired into the LibGDX
renderer yet — `core`'s `VillageStage`/`Building` still render the 2D
billboarded-emoji-on-diamond look. Actually switching to these models still
needs the `ModelBatch`/`PerspectiveCamera`/`Environment` rendering pipeline
and, the harder part, ray-picking-based tap/drag interaction to replace
Scene2D's free actor hit-testing — both explicitly scoped as separate future
work, not started here.
