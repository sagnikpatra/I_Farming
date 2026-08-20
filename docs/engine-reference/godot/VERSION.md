# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7.1 (stable) |
| **Project Pinned** | 2026-08-18 |
| **Released** | 2026-08-07 |
| **LLM Knowledge Cutoff** | 2026-01 (this assistant's stated cutoff) |
| **Risk Level** | **HIGH** — version released after the LLM knowledge cutoff. Godot 4.6 (2026-01-28) landed right at the cutoff edge; 4.7 (2026-06-19) and 4.7.1 (2026-08-07) are both fully past it. |

## What This Means

Do not trust this assistant's unaided memory of Godot 4.7 APIs, node
behavior, or defaults. Before suggesting GDScript code or Godot API usage:

1. Check `breaking-changes.md` in this directory for changes between 4.5→4.6→4.7
2. Check `deprecated-apis.md` for renamed/removed APIs
3. Check `current-best-practices.md` for features new since the cutoff
4. Check `modules/android-export.md` for this project's specific export path
5. If still uncertain, use WebSearch/WebFetch against `docs.godotengine.org/en/4.7/` rather than guessing

## Migration Context

This project is migrating from native-Android+LibGDX+Compose to Godot 4.7.1
in full, per `docs/architecture/adr-0001-godot-engine-migration.md`
(Accepted) and `docs/architecture/adr-0002-godot-language-and-save-format.md`
(Accepted — GDScript, clean save format). See
`docs/architecture/godot-migration-roadmap.md` for the phased epic plan.

## Why 4.7.1, Not an Earlier Point Release

4.7.1 is the latest stable release as of the pin date. Two notable
Android-relevant changes landed in the 4.6→4.7 window (see
`modules/android-export.md`): the stable Godot Android Build Environment
(GABE), which substantially simplifies the APK/AAB export pipeline this
project needs, and removal of deprecated Google Play OBB support. Given
EPIC-M0 (Godot Foundation & Migration Preflight) is standing up the Android
export pipeline from scratch, pinning the version that ships GABE stable —
rather than an earlier one that would need a mid-migration upgrade — is the
lower-risk choice.

## Re-Verification

Run `/setup-engine refresh` periodically to check for new patch releases and
update this pin. Run `/setup-engine upgrade 4.7.1 [new-version]` if a later
minor/major version becomes worth adopting mid-migration — that flow
produces a pre-upgrade audit of this project's actual GDScript usage against
the new version's breaking changes, not just a version bump.

Last verified: 2026-08-18
