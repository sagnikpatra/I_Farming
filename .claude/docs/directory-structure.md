# Directory Structure

> **Update (2026-08-23): this document had gone badly stale.** It still
> described the pre-migration Kotlin/Gradle layout as the primary
> structure and never mentioned `godot/` at all, despite
> `adr-0001-godot-engine-migration.md` being Accepted and the migration
> roadmap recording cutover on 2026-08-21 ("`godot/` is the active
> codebase for all new work"). Every session loads this file via
> CLAUDE.md's `@.claude/docs/directory-structure.md` include, so this
> staleness was silently misleading every session since cutover.
> Corrected below to describe the real current structure.

IFarming's active codebase is **Godot 4.7.1 / GDScript**, at `godot/`. The
pre-migration native Android Gradle project (Kotlin, Jetpack Compose +
embedded LibGDX) remains in the repository at `app/`/`core/` as a frozen,
still-buildable fallback per ADR-0001 -- not deleted, but no new feature
work happens there. The template's process scaffolding (design docs, ADRs,
production tracking) sits alongside both.

```text
/
├── CLAUDE.md                    # Master configuration (this project's stack, not the template default)
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── godot/                       # ACTIVE codebase -- Godot 4.7.1 project (GDScript)
│   ├── project.godot            # Engine/export config (internationalization, audio buses, Android export)
│   ├── scripts/                 # economy/ (GameState+GameEconomy, pure logic), village_board/ (3D board rendering
│   │                             #   + interaction), ui/ (HUD, sheets, pickers, cards), audio/ (AudioManager,
│   │                             #   AudioCatalogue), accessibility/ (AccessibilitySettings)
│   ├── scenes/                  # .tscn scene files mirroring scripts/ (village_board/, ui/)
│   ├── tests/unit/               # GUT test suite -- the project's primary regression safety net (per ADR-0002)
│   ├── autoload/                 # Small always-on singletons (e.g. a temporary PGS sign-in spike probe)
│   ├── addons/                   # GUT (test runner), GodotPlayGameServices (cloud-save plugin)
│   ├── assets/                   # Fonts, UI textures, audio (.ogg) -- assets authored/sourced for the Godot port
│   ├── assets_3d/                # Curated subset of the root assets_3d/ kits actually imported into this project
│   ├── locales/                  # ui_strings.csv -- source of truth for the CSV-translation localization pipeline
│   └── android/                  # Generated Gradle build output (GABE) -- regenerable, gitignored
├── app/                          # FROZEN pre-migration Android app module (Kotlin, Compose, GameViewModel/GameRepository)
│   └── src/main/
│       ├── java/com/zonkrik/ifarming/   # game/ (state+economy), ui/ (Compose screens + village board glue), ui/gdx/
│       └── assets/models3d/     # Bundled CC0 3D models used by the pre-migration LibGDX board
├── core/                         # FROZEN pure Kotlin/JVM module: LibGDX village-board rendering (village3d/ package)
│   └── src/main/kotlin/com/zonkrik/ifarming/
├── assets_3d/                    # Full sourced CC0 asset kits (Kenney.nl, KayKit) -- see assets_3d/README.md;
│                                  #   godot/assets_3d/ and the old app/'s models3d/ are both curated subsets of this
├── design/                       # Game design documents
│   ├── gdd/                      # 14 system GDDs (crop-economy, villagers, worker-economy, etc.) + systems-index.md
│   ├── audio/                    # Sonic direction docs (audio-core-gameplay-loop.md)
│   ├── balance/                  # Point-in-time /balance-check reports
│   ├── art/                      # Visual direction docs
│   └── registry/                 # (template scaffolding)
├── docs/                         # Technical documentation
│   ├── architecture/              # adr-*.md, godot-migration-roadmap.md, tr-registry.yaml, localization-pipeline.md
│   └── engine-reference/godot/    # Version-pinned Godot 4.7.1 API notes (HIGH knowledge-risk -- post-cutoff engine)
├── production/                   # Production management
│   ├── session-state/active.md    # The living session journal -- read this first after any compaction/crash
│   ├── qa/evidence/               # Real on-device verification screenshots (required by Testing Standards)
│   └── security/                  # Security audit reports
├── v2.md                         # Original design notes -- now substantially superseded by design/gdd/'s 14
│                                  #   individual GDDs (each traces back to a v2.md section), kept as the
│                                  #   original source document, not deleted
└── Indian Farming Android Game.md  # Original concept doc
```

## Notes for template skills

- `godot/` is the source root for all new engine-level work -- treat it
  the way the generic template treats `src/`. `app/`/`core/` remain the
  source roots only for work explicitly scoped to the frozen pre-migration
  stack (rare; check the migration roadmap first).
- `godot/tests/unit/` is a real, actively-maintained test suite (GUT) --
  `/qa-plan` and `/test-setup` should treat it as the existing convention
  to extend, not a gap to fill from scratch. The pre-migration Kotlin
  stack has no equivalent: `app/src/test`/`app/src/androidTest` exist but
  contain only Android Studio's default placeholder
  `ExampleUnitTest.kt`/`ExampleInstrumentedTest.kt`, never real project
  tests.
- `docs/engine-reference/godot/` **does** apply now (added once the Godot
  migration was decided) -- the template's blanket "not applicable here"
  framing for `engine-reference/` predates that decision.
