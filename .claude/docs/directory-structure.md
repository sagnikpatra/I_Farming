# Directory Structure

> **Update (2026-08-23): the frozen pre-migration Kotlin/Compose/LibGDX
> codebase (`app/`, `core/`, and the root Gradle toolchain) has been removed
> from the repository**, per explicit instruction, once ADR-0001's migration
> was confirmed complete and verified (parity reached 2026-08-21, EPIC-M5).
> This doc previously described `godot/` as the active codebase alongside a
> still-present frozen fallback -- that fallback no longer exists. `godot/`
> is now the only application codebase, not one of two.

IFarming's codebase is **Godot 4.7.1 / GDScript**, at `godot/`. The
template's process scaffolding (design docs, ADRs, production tracking)
sits alongside it.

```text
/
├── CLAUDE.md                    # Master configuration (this project's stack, not the template default)
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── godot/                       # The application codebase -- Godot 4.7.1 project (GDScript)
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
├── assets_3d/                    # Full sourced CC0 asset kits (Kenney.nl, KayKit) -- see assets_3d/README.md;
│                                  #   godot/assets_3d/ is a curated subset of this
├── design/                       # Game design documents
│   ├── gdd/                      # System GDDs (crop-economy, villagers, worker-economy, thief-system, etc.) + systems-index.md
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
├── v2.md                         # Original design notes -- now substantially superseded by design/gdd/'s
│                                  #   individual GDDs (each traces back to a v2.md section), kept as the
│                                  #   original source document, not deleted
└── Indian Farming Android Game.md  # Original concept doc
```

## Notes for template skills

- `godot/` is the source root for all engine-level work -- treat it the
  way the generic template treats `src/`.
- `godot/tests/unit/` is a real, actively-maintained test suite (GUT) --
  `/qa-plan` and `/test-setup` should treat it as the existing convention
  to extend, not a gap to fill from scratch.
- `docs/engine-reference/godot/` **does** apply now (added once the Godot
  migration was decided) -- the template's blanket "not applicable here"
  framing for `engine-reference/` predates that decision.
- If you find a reference to `app/`, `core/`, LibGDX, or Jetpack Compose
  anywhere else in `.claude/docs/` or `CLAUDE.md`, it is stale -- the
  pre-migration codebase those paths pointed to no longer exists in this
  repository (removed 2026-08-23). Flag it for correction rather than
  routing work there.
