# Technical Preferences

<!-- Filled in by hand during /adopt (brownfield adoption), not /setup-engine -- -->
<!-- IFarming predates this template. All agents reference this file for -->
<!-- project-specific standards and conventions. -->

> **⚠️ Engine migration in progress.** Per
> `docs/architecture/adr-0001-godot-engine-migration.md` (Accepted
> 2026-08-18), the project is migrating in full to **Godot 4**. Everything
> below documents the **current, pre-migration** LibGDX/Compose stack, which
> remains authoritative until the migration roadmap's phases land. Once
> `/setup-engine` pins a Godot version and `docs/engine-reference/godot/`
> exists, that becomes the reference for new engine-level work.

## Engine & Language

- **Engine (target)**: Godot 4.7.1, MIT-licensed -- satisfies the free/open-source-only constraint below. Pinned 2026-08-18 via `/setup-engine`; HIGH knowledge-risk (released 2026-08-07, past this assistant's Jan 2026 training cutoff) -- see `docs/engine-reference/godot/VERSION.md`.
- **Engine (current)**: Native Android (Android SDK / AGP 9.3.1) for the app shell and UI, plus **LibGDX 1.12.1** (Apache-2.0) embedded via a Fragment for the real-3D village board only. There is no single "game engine" here; LibGDX is a rendering library used inside an otherwise-normal Android app.
- **Language (current)**: Kotlin (2.1.20)
- **Language (target)**: GDScript (ADR-0002) -- chosen over C# for ecosystem/documentation fit given no prior Godot experience on the team, at the cost of a hand-rolled variant pattern for `PlotState` (GDScript has no sealed-class equivalent)
- **Rendering (current)**: Jetpack Compose (Material3) for all app UI; LibGDX `ModelBatch`/`OrthographicCamera` (OpenGL ES, via `core` module's `village3d` package) for the 3D village board specifically
- **Rendering (target)**: Godot Control-node scenes for UI (replacing Compose); Godot 3D scene (`Node3D`) for the village board (replacing `Village3DStage`)
- **Physics**: None -- no physics simulation. The current LibGDX board uses manual ray-picking (`Intersector.intersectRayBounds`/`intersectRayPlane`) against per-entity bounding boxes, not a physics engine. The Godot target may use Godot's built-in navigation (`NavigationRegion3D`/`NavigationAgent3D`) for villager pathfinding specifically -- to be decided by the migration roadmap; tap/drag interaction on structures/decorations is not expected to need physics.

## Input & Platform

- **Target Platforms**: Android only (mobile). minSdk 24, targetSdk/compileSdk 37.
- **Input Methods**: Touch
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full -- tap-to-select, long-press-then-drag (structures/decorations), pinch-zoom + drag-pan (village board camera)
- **Platform Notes**: Developed/tested against an Android Emulator AVD ("Medium_Phone", API 35/36), not yet tested on physical hardware or other screen sizes/densities.

## Naming Conventions

**Current (Kotlin)**:
- **Classes**: PascalCase (standard Kotlin) -- package root `com.zonkrik.ifarming`
- **Variables**: camelCase
- **Signals/Events**: N/A (no signal system) -- state changes flow through `GameViewModel`'s `StateFlow<GameState>` plus a one-shot `GameEvent` channel for snackbar messages
- **Files**: One primary class/object per file, filename matches the type name
- **Scenes/Prefabs**: N/A -- Compose screens are plain `@Composable` functions in `ui/`; the 3D board's "scene" is built procedurally each `GameState` change by `VillageSnapshotMapper` (app) -> `Village3DStage.rebuild()` (core), not authored scene files
- **Constants**: SCREAMING_SNAKE_CASE for `const val`, grouped in `GameData` (tunable economy constants) or as `private const val` near their usage

**Target (GDScript, ADR-0002)**:
- **Classes**: PascalCase (e.g. `PlayerController`)
- **Variables/functions**: snake_case (e.g. `move_speed`)
- **Signals**: snake_case, past tense (e.g. `health_changed`)
- **Files**: snake_case matching the class (e.g. `player_controller.gd`)
- **Scenes**: PascalCase matching the root node (e.g. `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g. `MAX_HEALTH`)
- **Sealed-class replacement**: `PlotState` (`Empty | Growing | ReadyToHarvest`) has no direct GDScript equivalent -- use a base class with an `enum Kind` discriminant plus per-kind subclasses, or a tagged dictionary/Resource; decide and document explicitly in EPIC-M2 rather than reinventing per file (per ADR-0002)

## Performance Budgets

**Current (Kotlin/LibGDX)**:
- **Target Framerate**: Not formally measured yet
- **Frame Budget**: Not measured
- **Draw Calls**: Not measured (village board renders full-rebuild-per-GameState-change, not diffed -- acceptable at current tile counts, unverified at scale)
- **Memory Ceiling**: Not measured

**Target (Godot)**: To be established as EPIC-M0's baseline-measurement deliverable (frame time on the Medium_Phone AVD, memory ceiling, APK size delta vs. the current LibGDX APK, cold-load time) -- see `docs/architecture/godot-migration-roadmap.md`. Do not invent numbers here before that measurement exists.

## Testing

**Current**: None configured -- no unit test suite exists (`app`/`core` have no `src/test`). All verification so far has been manual on-device testing via adb (screenshots, logcat, uiautomator).

**Target (Godot)**: GUT (Godot Unit Test) or gdUnit4 -- exact choice deferred to EPIC-M2 (Economy & State Core Port), which per ADR-0002 must build the project's first automated test suite as the primary regression safety net (the migration is not preserving JSON-save-based differential testing -- see ADR-0002). Priority coverage: every formula in `design/gdd/crop-economy.md` and its sibling docs, plus every `PlotState` transition (the GDScript variant-pattern translation above is a likely source of subtle bugs a Kotlin sealed class would have caught at compile time).
- **Required Tests**: Balance formulas (crop economy, land-expansion pricing), gameplay systems (planting/harvesting/decay), village-board interaction -- currently untested by automation on either stack

## Forbidden Patterns

- Paid/proprietary engines, asset packs, or SDKs -- the project has an explicit free/open-source-only constraint (LibGDX is Apache-2.0; all bundled 3D models are CC0-licensed Kenney.nl kits, see `assets_3d/README.md`)

## Allowed Libraries / Addons

- Jetpack Compose (Compose BOM 2025.02.00), Material3
- LibGDX 1.12.1 (`com.badlogicgames.gdx:gdx`, `gdx-backend-android`, `gdx-platform` natives) -- Apache-2.0
- Kenney.nl CC0 3D asset kits (nature-kit, city-kit-suburban, graveyard-kit, fantasy-town-kit) -- see `assets_3d/README.md` for per-kit sourcing/license notes
- `org.json` (bundled with Android) for GameState persistence -- no Room/DataStore

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs written yet -- the LibGDX migration, the 2D-to-3D village board rewrite, and the free/open-source-only constraint were all real architectural decisions made during earlier sessions but never captured as formal ADRs. Worth retroactively documenting with `/architecture-decision` -- see the adoption plan.]

## Engine Specialists

> **Post-migration-decision routing.** With ADR-0001 Accepted, `godot-specialist`
> and its sub-specialists now apply to any **new Godot-side** work. The rows
> below still describe routing for the **pre-migration LibGDX/Compose**
> codebase, which remains the working app until the migration roadmap's
> phases land -- use them for any work still touching that code.

- **Primary (pre-migration code)**: Route general engine/rendering work to `engine-programmer` (LibGDX/`core` module) or `gameplay-programmer` (app-layer game logic), both briefed to work in Kotlin against this stack.
- **Primary (Godot target)**: `godot-specialist` for architecture-level Godot decisions (node/scene design, cross-cutting review, ADR validation).
- **Language/Code Specialist (current)**: None dedicated for the current Kotlin code -- `lead-programmer`/`gameplay-programmer`/`engine-programmer` handle it directly.
- **Language/Code Specialist (target)**: `godot-gdscript-specialist` (all `.gd` files) -- per ADR-0002's GDScript choice. `godot-csharp-specialist` does not apply; this project is GDScript-only.
- **Shader Specialist**: None for the current code (LibGDX's default `DefaultShader` via `ModelBatch`, no custom shaders yet). `godot-shader-specialist` (`.gdshader` files, VisualShader resources) applies once Godot-side rendering work begins.
- **UI Specialist**: `ui-programmer`, briefed on Jetpack Compose, for the current code. `godot-specialist` covers the Godot target's Control-node UI -- no dedicated Godot UI specialist exists in this template.
- **Additional Specialists**: `godot-gdextension-specialist` -- GDExtension/native C++ bindings only; not expected to be needed given the GDScript-only language choice, available if a genuine native-performance case arises.
- **Routing Notes**: If a task needs genuine LibGDX/OpenGL ES depth beyond what `engine-programmer` can reasonably cover, flag it rather than silently routing elsewhere. For Godot work, specialists read `docs/engine-reference/godot/VERSION.md` (HIGH knowledge-risk -- pinned version is past this assistant's training cutoff) before suggesting any API.

### File Extension Routing

**Current (pre-migration)**:

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| `.kt` in `app/.../game/` (state, economy, ViewModel) | `gameplay-programmer` |
| `.kt` in `app/.../ui/` (Compose screens/components) | `ui-programmer` |
| `.kt` in `app/.../ui/gdx/` (Compose<->LibGDX embedding glue) | `engine-programmer` |
| `.kt` in `core/` (`village3d` LibGDX rendering) | `engine-programmer` |
| Gradle build files (`.gradle.kts`) | `lead-programmer` |
| `.obj`/`.mtl` 3D model assets | `technical-artist` (asset integration), not an engine shader specialist |
| General architecture review | Primary (`engine-programmer`/`lead-programmer`, as above) |

**Target (Godot, GDScript)**:

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (`.gd` files) | `godot-gdscript-specialist` |
| Shader / material files (`.gdshader`, VisualShader) | `godot-shader-specialist` |
| UI / screen files (Control nodes, CanvasLayer) | `godot-specialist` |
| Scene / resource files (`.tscn`, `.tres`) | `godot-specialist` |
| Native extension / plugin files (`.gdextension`, C++) | `godot-gdextension-specialist` (not expected to be needed) |
| `.obj`/`.mtl` 3D model assets | `technical-artist` (asset integration) |
| General architecture review | `godot-specialist` |
