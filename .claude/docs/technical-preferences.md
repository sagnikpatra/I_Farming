# Technical Preferences

<!-- Filled in by hand during /adopt (brownfield adoption), not /setup-engine -- -->
<!-- IFarming predates this template. All agents reference this file for -->
<!-- project-specific standards and conventions. -->

> **Update (2026-08-23): engine migration complete, pre-migration stack
> removed.** Per `docs/architecture/adr-0001-godot-engine-migration.md`
> (Accepted 2026-08-18, parity verified 2026-08-21), the project migrated in
> full to **Godot 4**. The frozen pre-migration LibGDX/Compose stack
> (`app/`, `core/`, the root Gradle toolchain) was removed from the
> repository 2026-08-23. Everything below now describes the single, current
> stack -- there is no more "current vs. target" split.

## Engine & Language

- **Engine**: Godot 4.7.1, MIT-licensed -- satisfies the free/open-source-only constraint below. Pinned 2026-08-18 via `/setup-engine`; HIGH knowledge-risk (released 2026-08-07, past this assistant's Jan 2026 training cutoff) -- see `docs/engine-reference/godot/VERSION.md`.
- **Language**: GDScript (ADR-0002) -- chosen over C# for ecosystem/documentation fit given no prior Godot experience on the team, at the cost of a hand-rolled variant pattern for `PlotState` (GDScript has no sealed-class equivalent)
- **Rendering**: Godot Control-node scenes for UI, Godot 3D scene (`Node3D`) for the village board (`village_board.gd` and siblings)
- **Physics**: None -- no physics simulation. The village board uses manual ray-picking (`PhysicsRayQueryParameters3D` against per-entity `Area3D` pick regions), not a physics engine. Villager pathfinding uses a hand-rolled BFS grid pathfinder (`walkable_grid.gd`), not `NavigationRegion3D`/`NavigationAgent3D` -- see that file's own doc comment for why (small fixed board, fully headless-testable, avoids a HIGH-knowledge-risk subsystem this project has never used).

## Input & Platform

- **Target Platforms**: Android only (mobile). minSdk 24, targetSdk/compileSdk 36-37.
- **Input Methods**: Touch
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full -- tap-to-select, long-press-then-drag (structures/decorations), pinch-zoom + drag-pan (village board camera)
- **Screen Orientation**: Portrait-locked (`window/handheld/orientation=1` in `project.godot`, fixed 2026-08-23 -- was previously `SCREEN_SENSOR`, which let the OS rotate into landscape even though every screen in this game is a hand-built portrait-only layout). Do not change this without a corresponding landscape UI pass -- none exists.
- **Platform Notes**: Developed against an Android Emulator AVD ("Medium_Phone", API 35/36), and extensively verified on real physical hardware since (a OnePlus OPD2403 for the formal EPIC-M6 performance pass, plus repeated ad hoc real-device verification passes across many features). Still open: testing on more than one physical device/screen size -- every real-hardware pass so far has used the same one or two devices, not a spread of screen sizes/densities. **Note**: this OnePlus device has been found (2026-08-23) with a lingering WindowManager `ignoreOrientationRequest=true` developer flag set (`adb shell cmd window get/set-ignore-orientation-request`) that overrides every app's manifest orientation lock, not just this one -- almost certainly left on from earlier ad hoc testing and never reset. Worth clearing (`adb shell cmd window set-ignore-orientation-request -d 0 false`) before relying on this device for any future orientation-sensitive verification, since it silently masks that whole bug class.

## Naming Conventions

- **Classes**: PascalCase (e.g. `PlayerController`)
- **Variables/functions**: snake_case (e.g. `move_speed`)
- **Signals**: snake_case, past tense (e.g. `health_changed`)
- **Files**: snake_case matching the class (e.g. `player_controller.gd`)
- **Scenes**: PascalCase matching the root node (e.g. `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g. `MAX_HEALTH`)
- **Sealed-class replacement**: `PlotState` (`Empty | Growing | ReadyToHarvest`) has no direct GDScript equivalent -- uses a base class with an `enum Kind` discriminant plus per-kind subclasses (decided in EPIC-M2, per ADR-0002)

## Performance Budgets

Real measurements exist from both AVD and real hardware (see
`docs/architecture/godot-migration-roadmap.md`'s EPIC-M6 section, "Real-hardware performance pass," 2026-08-22), but no formal numeric budget has been adopted yet:

- **Target Framerate**: Measured 49-51 FPS steady on a real device (OnePlus OPD2403, Android 16) at both zero and max-population saves -- population is not the bottleneck; the device's own ~50Hz refresh-rate lock is (that device natively supports up to 144Hz). No formal target adopted -- this is raw data, not a pass/fail gate.
- **Frame Budget**: Script/process time (`Performance.TIME_PROCESS`) measured 33-49ms on real hardware; no formal budget line adopted yet.
- **Memory Ceiling**: Static memory measured ~59-59.3MB on real hardware at both population extremes; no formal ceiling adopted yet.
- **Cold-load time**: 468ms Activity-first-frame on a fresh install (real device, `adb shell am start -W`).
- **APK size**: ~31.0MB (debug-signed).

Adopting an explicit numeric budget (e.g. "≥30 FPS, ≤X MB" as a release gate) is a product decision still open -- the measurement gap that blocked it is closed.

## Testing

GUT (Godot Unit Test), per ADR-0002 -- the project's primary regression
safety net, `godot/tests/unit/`. 55 test scripts, 700+ tests as of
2026-08-23 (a growing count -- check `git log` / `production/session-state/active.md`
for the latest real number rather than trusting this line to stay current).
Local invocation:
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit --path godot
```
A handful of tests fail on every run independent of any given session's
changes (pre-existing, not caused by recent work -- see session-state for
the running account of which ones and why); compare against a clean
baseline (e.g. a `git worktree` at an earlier commit) before assuming a
new failure is a regression from the current change, not something
already broken.

- **Required Tests**: Balance formulas (crop economy, land-expansion pricing), gameplay systems (planting/harvesting/decay), village-board interaction -- covered by the GUT suite; UI/Visual-Feel stories remain manual/on-device per the Testing Standards table in `.claude/docs/coding-standards.md`.

## Forbidden Patterns

- Paid/proprietary engines, asset packs, or SDKs -- the project has an explicit free/open-source-only constraint (Godot 4 is MIT-licensed; all bundled 3D models are CC0-licensed Kenney.nl kits, see `assets_3d/README.md`)

## Allowed Libraries / Addons

- Godot 4.7.1 built-in Control/Node3D/GDScript toolchain
- GUT (Godot Unit Test) -- `godot/addons/gut/`
- GodotPlayGameServices -- `godot/addons/GodotPlayGameServices/`, cloud-save plugin (see ADR-0003)
- Kenney.nl CC0 3D asset kits (nature-kit, city-kit-suburban, graveyard-kit, fantasy-town-kit) -- see `assets_3d/README.md` for per-kit sourcing/license notes

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
4 ADRs exist:
- `adr-0001-godot-engine-migration.md` (Accepted) — LibGDX/native-Android → Godot 4 full migration. Parity verified 2026-08-21; the frozen pre-migration fallback this ADR's rollback plan kept available was removed 2026-08-23, per explicit instruction, once no longer needed.
- `adr-0002-godot-language-and-save-format.md` (Accepted) — GDScript, clean Resource-based save format
- `adr-0003-cloud-save-and-player-accounts.md` (Proposed) — Google Play Games Services Snapshots, offline-first
- `adr-0004-lazy-read-time-growth-resolution.md` (Accepted, retroactive) — lazy read-time growth/state resolution over a live ticking timer

Still genuinely un-documented as formal ADRs: the 2D-to-3D village board
rewrite (predates the Godot migration entirely) and the free/open-source-only
constraint (a project-wide policy, not a single architectural choice with
alternatives to weigh — may not need a full ADR at all). Worth a look with
`/architecture-decision` if either ever needs the same retroactive
treatment ADR-0004 got.

## Engine Specialists

`godot-specialist` is the primary routing for architecture-level Godot
decisions (node/scene design, cross-cutting review, ADR validation) -- there
is no pre-migration stack to route around anymore; every file in the
codebase is Godot/GDScript.

- **Primary**: `godot-specialist` for architecture-level Godot decisions.
- **Language/Code Specialist**: `godot-gdscript-specialist` (all `.gd` files) -- per ADR-0002's GDScript choice. `godot-csharp-specialist` does not apply; this project is GDScript-only.
- **Shader Specialist**: `godot-shader-specialist` (`.gdshader` files, VisualShader resources) once Godot-side custom rendering work begins -- none exists yet (village board rendering is still Godot's default materials).
- **UI Specialist**: `godot-specialist` covers the Control-node UI -- no dedicated Godot UI specialist exists in this template.
- **Additional Specialists**: `godot-gdextension-specialist` -- GDExtension/native C++ bindings only; not expected to be needed given the GDScript-only language choice, available if a genuine native-performance case arises.
- **Routing Notes**: If a task needs genuine engine-level depth beyond what `godot-specialist` can reasonably cover, flag it rather than silently routing elsewhere. Every specialist reads `docs/engine-reference/godot/VERSION.md` (HIGH knowledge-risk -- pinned version is past this assistant's training cutoff) before suggesting any API.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (`.gd` files) | `godot-gdscript-specialist` |
| Shader / material files (`.gdshader`, VisualShader) | `godot-shader-specialist` |
| UI / screen files (Control nodes, CanvasLayer) | `godot-specialist` |
| Scene / resource files (`.tscn`, `.tres`) | `godot-specialist` |
| Native extension / plugin files (`.gdextension`, C++) | `godot-gdextension-specialist` (not expected to be needed) |
| `.obj`/`.mtl` 3D model assets | `technical-artist` (asset integration) |
| General architecture review | `godot-specialist` |
