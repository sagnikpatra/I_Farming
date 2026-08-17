# Kisan Khet (IFarming) -- Game Studio Agent Architecture

An Indian-farming-themed Android game (Jetpack Compose UI + a real-3D LibGDX
village board), developed through many prior direct-implementation sessions
and now additionally managed through Claude Code Game Studios' coordinated
subagents. Each agent owns a specific domain, enforcing separation of
concerns and quality -- adopted onto an already-substantial existing
codebase via `/adopt`, not started fresh via `/start`.

## Technology Stack

- **Engine**: None of Godot/Unity/Unreal -- native Android app (Kotlin, Jetpack Compose) with LibGDX 1.12.1 embedded for the 3D village board only
- **Language**: Kotlin
- **Version Control**: Git with trunk-based development (current work has been happening on `feature/isometric-village-view`, not directly on `master`)
- **Build System**: Gradle (Android Gradle Plugin 9.3.1, Kotlin DSL), two modules: `app` (Android application) and `core` (pure Kotlin/JVM LibGDX rendering)
- **Asset Pipeline**: Manual -- CC0 Kenney.nl 3D asset kits sourced and curated by hand into `app/src/main/assets/models3d/`, see `assets_3d/README.md`

> **Note**: This template's Godot/Unity/Unreal engine-specialist agents do
> not apply to this project. See `.claude/docs/technical-preferences.md`'s
> "Engine Specialists" section for the actual routing (generic
> `engine-programmer`/`gameplay-programmer`/`ui-programmer`, briefed on
> Kotlin/Compose/LibGDX instead).

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
