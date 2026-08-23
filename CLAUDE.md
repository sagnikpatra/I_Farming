# Kisan Khet (IFarming) -- Game Studio Agent Architecture

An Indian-farming-themed Android game built in Godot 4 (GDScript), developed
through many prior direct-implementation sessions and now additionally
managed through Claude Code Game Studios' coordinated subagents. Each agent
owns a specific domain, enforcing separation of concerns and quality --
adopted onto an already-substantial existing codebase via `/adopt`, not
started fresh via `/start`.

## Technology Stack

> **Engine migration complete.** Per
> `docs/architecture/adr-0001-godot-engine-migration.md` (Accepted
> 2026-08-18), the project migrated from native-Android+LibGDX to
> **Godot 4** in full (app shell, UI, economy logic, and the village board).
> Migration parity was reached and verified on-device 2026-08-21 (EPIC-M5);
> the frozen pre-migration Kotlin/Jetpack Compose/LibGDX codebase (`app/`,
> `core/`, and the root Gradle toolchain) was removed from the repository
> 2026-08-23 per explicit instruction, once it was confirmed no longer
> needed as a fallback. `godot/` is the only application codebase now.

- **Engine**: Godot 4.7.1 (pinned via `/setup-engine` 2026-08-18) -- see the ADR above for rationale. HIGH knowledge-risk: released 2026-08-07, past this assistant's Jan 2026 training cutoff -- see `docs/engine-reference/godot/VERSION.md` before suggesting any Godot API.
- **Language**: GDScript (per ADR-0002)
- **Version Control**: Git with trunk-based development (current work has been happening on `feature/isometric-village-view`, not directly on `master`)
- **Build System**: Godot's own project system + the Godot Android Build Environment (GABE) for Android export -- see `docs/engine-reference/godot/modules/android-export.md`
- **Asset Pipeline**: Manual -- CC0 Kenney.nl 3D asset kits sourced and curated by hand into `godot/assets_3d/`, see `assets_3d/README.md`. All 627 sourced `.obj`/`.mtl` models in the root `assets_3d/` import into Godot natively with no conversion step.

Route all engine-level work to `godot-specialist` (and its GDScript/C#/
shader/GDExtension sub-specialists) per `.claude/docs/technical-preferences.md`'s
"Engine Specialists" section -- there is no longer a pre-migration stack to
route around.

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
> real-3D Godot village board with ray-picking interaction, plus a
> substantial worker/villager/LiveOps layer built since the migration) built
> before this template was adopted and across the migration itself. Run
> `/adopt` any time to re-check template-format compliance as design/
> architecture docs get backfilled -- do not treat the existing app as
> "nothing built yet."

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
