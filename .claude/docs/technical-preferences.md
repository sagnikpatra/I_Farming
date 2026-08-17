# Technical Preferences

<!-- Filled in by hand during /adopt (brownfield adoption), not /setup-engine -- -->
<!-- IFarming predates this template. All agents reference this file for -->
<!-- project-specific standards and conventions. -->

## Engine & Language

- **Engine**: None of Godot/Unity/Unreal -- native Android (Android SDK / AGP 9.3.1) for the app shell and UI, plus **LibGDX 1.12.1** (Apache-2.0) embedded via a Fragment for the real-3D village board only. There is no single "game engine" here; LibGDX is a rendering library used inside an otherwise-normal Android app.
- **Language**: Kotlin (2.1.20)
- **Rendering**: Jetpack Compose (Material3) for all app UI; LibGDX `ModelBatch`/`OrthographicCamera` (OpenGL ES, via `core` module's `village3d` package) for the 3D village board specifically
- **Physics**: None -- no physics simulation. Tap/drag interaction on the 3D board uses manual ray-picking (`Intersector.intersectRayBounds`/`intersectRayPlane`) against per-entity bounding boxes, not a physics engine.

## Input & Platform

- **Target Platforms**: Android only (mobile). minSdk 24, targetSdk/compileSdk 37.
- **Input Methods**: Touch
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full -- tap-to-select, long-press-then-drag (structures/decorations), pinch-zoom + drag-pan (village board camera)
- **Platform Notes**: Developed/tested against an Android Emulator AVD ("Medium_Phone", API 35/36), not yet tested on physical hardware or other screen sizes/densities.

## Naming Conventions

- **Classes**: PascalCase (standard Kotlin) -- package root `com.zonkrik.ifarming`
- **Variables**: camelCase
- **Signals/Events**: N/A (no signal system) -- state changes flow through `GameViewModel`'s `StateFlow<GameState>` plus a one-shot `GameEvent` channel for snackbar messages
- **Files**: One primary class/object per file, filename matches the type name
- **Scenes/Prefabs**: N/A -- Compose screens are plain `@Composable` functions in `ui/`; the 3D board's "scene" is built procedurally each `GameState` change by `VillageSnapshotMapper` (app) -> `Village3DStage.rebuild()` (core), not authored scene files
- **Constants**: SCREAMING_SNAKE_CASE for `const val`, grouped in `GameData` (tunable economy constants) or as `private const val` near their usage

## Performance Budgets

- **Target Framerate**: Not formally measured yet -- gap, see adoption plan
- **Frame Budget**: Not measured
- **Draw Calls**: Not measured (village board renders full-rebuild-per-GameState-change, not diffed -- acceptable at current tile counts, unverified at scale)
- **Memory Ceiling**: Not measured

## Testing

- **Framework**: None configured yet -- no unit test suite exists (`app`/`core` have no `src/test`). All verification so far has been manual on-device testing via adb (screenshots, logcat, uiautomator) during development sessions.
- **Minimum Coverage**: N/A
- **Required Tests**: Balance formulas (crop economy, land-expansion pricing), gameplay systems (planting/harvesting/decay), village-board interaction (ray-picking, drag) -- all currently untested by automation

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

- **Primary**: None of `godot-specialist`/`unity-specialist`/`unreal-specialist` apply. Route general engine/rendering work to `engine-programmer` (LibGDX/`core` module) or `gameplay-programmer` (app-layer game logic), both briefed to work in Kotlin against this stack, not a template engine.
- **Language/Code Specialist**: None dedicated -- Kotlin is common enough that `lead-programmer`/`gameplay-programmer`/`engine-programmer` should handle it directly without a language specialist.
- **Shader Specialist**: None -- no custom shaders in use (LibGDX's default `DefaultShader` via `ModelBatch`).
- **UI Specialist**: `ui-programmer`, briefed on Jetpack Compose (not a template UI system like Unity UGUI/Godot Control nodes/UE UMG).
- **Additional Specialists**: None of the Godot/Unity/Unreal sub-specialists (GDScript, C#, Blueprint, GAS, DOTS, etc.) apply -- do not route to them.
- **Routing Notes**: If a task needs genuine LibGDX/OpenGL ES depth (custom shaders, shadow mapping, etc.) beyond what `engine-programmer` can reasonably cover generically, flag it to the user rather than silently routing to a Godot/Unity/Unreal specialist that doesn't apply.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| `.kt` in `app/.../game/` (state, economy, ViewModel) | `gameplay-programmer` |
| `.kt` in `app/.../ui/` (Compose screens/components) | `ui-programmer` |
| `.kt` in `app/.../ui/gdx/` (Compose<->LibGDX embedding glue) | `engine-programmer` |
| `.kt` in `core/` (`village3d` LibGDX rendering) | `engine-programmer` |
| Gradle build files (`.gradle.kts`) | `lead-programmer` |
| `.obj`/`.mtl` 3D model assets | `technical-artist` (asset integration), not an engine shader specialist |
| General architecture review | Primary (`engine-programmer`/`lead-programmer`, as above) |
