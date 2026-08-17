# Directory Structure

IFarming is a native Android Gradle project (Kotlin), not one of the
Godot/Unity/Unreal layouts this template defaults to. The template's process
scaffolding (design docs, ADRs, sprint tracking) sits alongside the existing
Gradle module layout rather than replacing it.

```text
/
├── CLAUDE.md                    # Master configuration (this project's stack, not the template default)
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── app/                         # Android application module (Kotlin, Jetpack Compose UI, GameViewModel/GameRepository)
│   └── src/main/
│       ├── java/com/zonkrik/ifarming/   # game/ (state+economy), ui/ (Compose screens + village board glue), ui/gdx/ (LibGDX embedding)
│       └── assets/models3d/     # Bundled CC0 3D models (structures/decorations) used by the village board
├── core/                        # Pure Kotlin/JVM module: LibGDX village-board rendering (village3d/ package)
│   └── src/main/kotlin/com/zonkrik/ifarming/
├── assets_3d/                   # Full sourced CC0 asset kits (Kenney.nl) -- see assets_3d/README.md; app/'s models3d/ is a curated subset of these, bundled into the APK
├── design/                      # Game design documents (gdd, narrative, levels, balance) -- template scaffolding, mostly empty until populated
├── docs/                        # Technical documentation (architecture/adr-*.md, registry, engine-reference if ever added)
├── production/                  # Production management (sprints, milestones, releases, session-state)
├── v2.md                        # Pre-existing design notes (predates this template's adoption -- not yet migrated into design/gdd/)
└── Indian Farming Android Game.md  # Original concept doc
```

## Notes for template skills

- There is no `src/`, `assets/`, `tests/`, `tools/`, or `prototypes/` at the
  root the way the generic template expects -- Android/Gradle's own
  conventions (`app/src/main/...`, `core/src/main/kotlin/...`) already cover
  that role. Skills that need "where does game code live" should treat
  `app/` and `core/` as the source roots.
- No test suite exists yet (no `tests/` directory, no unit tests configured)
  -- `/qa-plan` and `/test-setup` should treat this as a gap to fill, not an
  existing convention to follow.
- `docs/engine-reference/` was deliberately **not** copied from the template
  -- it's Godot/Unity/Unreal API snapshots, not applicable here.
