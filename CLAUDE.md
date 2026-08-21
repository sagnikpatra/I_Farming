# Kisan Khet (IFarming) -- Game Studio Agent Architecture

An Indian-farming-themed Android game (Jetpack Compose UI + a real-3D LibGDX
village board), developed through many prior direct-implementation sessions
and now additionally managed through Claude Code Game Studios' coordinated
subagents. Each agent owns a specific domain, enforcing separation of
concerns and quality -- adopted onto an already-substantial existing
codebase via `/adopt`, not started fresh via `/start`.

## Technology Stack

> **⚠️ Engine migration in progress.** Per
> `docs/architecture/adr-0001-godot-engine-migration.md` (Accepted
> 2026-08-18), the project is migrating from native-Android+LibGDX to
> **Godot 4** in full (app shell, UI, economy logic, and the village board).
> The lines below describe the **current, not-yet-migrated** codebase, which
> remains the working app until the migration roadmap (technical-director +
> producer, phased epics/stories) completes each phase. Do not start new
> LibGDX/Compose feature work without checking the migration roadmap first
> once it exists -- new work may belong in Godot instead.

- **Engine (target)**: Godot 4.7.1 (pinned via `/setup-engine` 2026-08-18) -- see the ADR above for rationale. HIGH knowledge-risk: released 2026-08-07, past this assistant's Jan 2026 training cutoff -- see `docs/engine-reference/godot/VERSION.md` before suggesting any Godot API.
- **Engine (current, pre-migration)**: Native Android app (Kotlin, Jetpack Compose) with LibGDX 1.12.1 embedded for the 3D village board only
- **Language**: Kotlin (current codebase); GDScript (Godot target, per ADR-0002)
- **Version Control**: Git with trunk-based development (current work has been happening on `feature/isometric-village-view`, not directly on `master`)
- **Build System (current)**: Gradle (Android Gradle Plugin 9.3.1, Kotlin DSL), two modules: `app` (Android application) and `core` (pure Kotlin/JVM LibGDX rendering)
- **Asset Pipeline**: Manual -- CC0 Kenney.nl 3D asset kits sourced and curated by hand into `app/src/main/assets/models3d/`, see `assets_3d/README.md`. All 627 sourced `.obj`/`.mtl` models in `assets_3d/` import into Godot natively with no conversion step.

> **Note**: Now that migration to Godot 4 is Accepted, this template's
> `godot-specialist` (and its GDScript/C#/shader/GDExtension sub-specialists)
> **do apply** going forward -- route new Godot-side work there instead of
> the generic `engine-programmer`. `engine-programmer`/`gameplay-programmer`/
> `ui-programmer` remain the right routing for any work still touching the
> pre-migration Kotlin/Compose/LibGDX codebase until it's retired. See
> `.claude/docs/technical-preferences.md`'s "Engine Specialists" section.

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Project Structure

@.claude/docs/directory-structure.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **Adopted project.** This codebase already has real, working, on-device-verified
> features (draggable/rotatable/flippable structures, a decorations economy, a
> real-3D LibGDX village board with ray-picking interaction) built before this
> template was adopted. Run `/adopt` any time to re-check template-format
> compliance as design/architecture docs get backfilled -- do not treat the
> existing app as "nothing built yet."

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
