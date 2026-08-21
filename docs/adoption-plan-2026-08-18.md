# Adoption Plan

> **Generated**: 2026-08-18
> **Project phase**: Production (38 real Kotlin source files in `app/`+`core/`, on-device-verified working game)
> **Engine**: Native Android (Kotlin, Jetpack Compose) + LibGDX 1.12.1 for the 3D village board -- not Godot/Unity/Unreal
> **Template version**: Claude Code Game Studios (adopted from github.com/Donchitos/Claude-Code-Game-Studios), v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

Unlike a typical brownfield adoption, none of the gaps below are "existing
artifact has the wrong format" -- IFarming has substantial real, working code
(the village board, the crop economy, the decorations system, the LibGDX
migration) but **zero** formal GDDs/ADRs/stories. Every item here is
"retroactively document a real decision or system that already exists and
already works," not "fix a malformed file." Expect this to take several
sessions, not one sitting.

---

## Step 1: Fix Blocking Gaps

None. Nothing exists yet to be malformed.

---

## Step 2: Fix High-Priority Gaps

### 2a. No GDDs exist

**Problem**: `design/gdd/` is empty. `/create-stories` needs a GDD with
Acceptance Criteria to generate stories from -- there's nothing to point it
at yet for any of IFarming's existing systems (crop economy, land expansion,
structure zones, decorations, the 3D village board) or for new feature work.

**Fix**: `/reverse-document design [system path]` -- generates a GDD by
working backwards from existing code, rather than authoring one from a blank
template for a system that's already built and playtested. Best candidates
to start with (highest-value, most self-contained systems):
1. `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game` -- the crop economy, land expansion pricing, structure unlocks
2. `/reverse-document design app/src/main/java/com/zonkrik/ifarming/ui/gdx` + `core/src/main/kotlin/com/zonkrik/ifarming/village3d` -- the 3D village board (rendering, camera, interaction)

**Time**: 1 session per system, realistically
- [ ] Crop economy / land expansion GDD reverse-documented
- [ ] 3D village board GDD reverse-documented

### 2b. No ADRs exist

**Problem**: Several real, significant architectural decisions were already
made and implemented across roughly a dozen commits, with no record of why:
- Migrating the village board from Jetpack Compose to LibGDX (Scene2D, then later a full real-3D rewrite)
- Switching the 3D camera from perspective to orthographic
- The free/open-source-only constraint on all engines/libraries/assets (LibGDX is Apache-2.0; all bundled 3D models are CC0 Kenney.nl kits)
- Full-stage-rebuild-on-GameState-change instead of diffing, for both the 2D and 3D board implementations
- Plain SharedPreferences + manual JSON serialization instead of Room/DataStore for persistence

**Fix**: `/architecture-decision retrofit` for each, or `/reverse-document architecture [path]` for a broader pass. Start with the two most load-bearing:
1. `/architecture-decision retrofit` -- "Real-3D village board over 2D Scene2D" (ray-picking interaction, orthographic camera, CC0 asset sourcing)
2. `/architecture-decision retrofit` -- "GameState persistence via SharedPreferences + manual JSON" (no Room/DataStore)

**Time**: 30-60 min per ADR
- [ ] ADR: real-3D village board architecture
- [ ] ADR: GameState persistence approach
- [ ] Remaining decisions (free/open-source constraint, full-rebuild-over-diffing) as time allows

### 2c. tr-registry.yaml is an empty template

**Problem**: `docs/architecture/tr-registry.yaml` has `requirements: []` -- no stable requirement IDs exist for anything.

**Fix**: Run `/architecture-review` once at least one GDD exists (from Step 2a) -- it bootstraps the TR registry from real GDD content rather than needing manual entries.
**Time**: 1 session (can be long; depends on how many GDDs exist by then)
- [ ] tr-registry.yaml populated via `/architecture-review`

### 2d. control-manifest.md missing

**Problem**: `docs/architecture/control-manifest.md` doesn't exist -- no flat, actionable rules sheet for what programmer agents must/must never do per layer.

**Fix**: Run `/create-control-manifest` after Step 2b's ADRs exist (it extracts from Accepted ADRs).
**Time**: 30 min
- [ ] control-manifest.md created

---

## Step 3: Bootstrap Infrastructure

### 3a. Register existing requirements (creates/updates tr-registry.yaml)
Run `/architecture-review` -- see Step 2c above, same action.
- [ ] Done (tracked in Step 2c)

### 3b. Create control manifest
Run `/create-control-manifest` -- see Step 2d above, same action.
- [ ] Done (tracked in Step 2d)

### 3c. Create sprint tracking file
Run `/sprint-plan update`
**Time**: 5 min
- [ ] `production/sprint-status.yaml` created

### 3d. Set authoritative project stage
Run `/gate-check production` (this project is already in Production, not an earlier phase)
**Time**: 5 min
- [ ] `production/stage.txt` written

---

## Step 4: Medium-Priority Gaps

### 4a. architecture-traceability.md missing
Bootstrapped automatically once `/architecture-review` runs (Step 2c/3a) with at least one GDD+ADR pair to trace.
- [ ] `docs/architecture/architecture-traceability.md` created

### 4b. No systems-index.md
Create via `/map-systems` once a few GDDs exist (Step 2a), to decompose IFarming's actual systems (crop economy, land, structures, decorations, village board, festival/liveops events, Mandi market) and their dependencies.
**Time**: 1 session
- [ ] `design/gdd/systems-index.md` created

---

## Step 5: Optional Improvements

- `design/registry/entities.yaml` / `docs/registry/architecture.yaml` are empty templates by design -- they populate naturally as GDDs (`/design-system`) and ADRs get written. No action needed now.

---

## What to Expect from Existing Stories

N/A -- no stories exist yet (none were ever written; all of IFarming's
existing features were built through direct conversational implementation,
not this template's story pipeline). Once GDDs/ADRs exist, new work can flow
through `/create-epics` -> `/create-stories` -> `/dev-story` normally. Past
work does not need to be retroactively broken into stories -- only
documented (GDDs/ADRs), per Step 2.

---

## Re-run

Run `/adopt` again after completing Step 2 to verify HIGH gaps are resolved
and see the plan reflect current state.
