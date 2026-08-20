# Godot 4.7.1 — What's New Since This Assistant's Training Cutoff

Last verified: 2026-08-18. Covers Godot 4.6 (2026-01-28) and 4.7/4.7.1
(2026-06-19 / 2026-08-07) — both released at or after this assistant's
January 2026 knowledge cutoff, so treat all of the below as unfamiliar
rather than half-remembered.

## Android Export — Directly Relevant to This Project (Android-Only Target)

**Godot Android Build Environment (GABE), stable in 4.7**: a companion app
for the Godot Android editor that provides Gradle export support directly.
GABE can generate AAB and APK files **on an Android or XR device itself**,
without the developer installing and wiring up the external Android SDK/NDK
toolchain by hand. This materially simplifies EPIC-M0's Android export
setup compared to older Godot Android export workflows this assistant might
otherwise assume are still current. See `modules/android-export.md`.

**Google Play OBB removed** (4.7) — was already deprecated; now gone. Any
export config assuming OBB for large-asset delivery must use Play Asset
Delivery or PCK split instead.

**Picture-in-picture support** (4.7) — lets the app render inside a small
floating window while the user interacts with other apps. Not currently a
requirement for this project, noted for completeness.

**Built-in virtual joystick, gyro aiming, accelerometer input** (4.7) — not
needed for this project's tap/drag/pinch-zoom interaction model, but worth
knowing these now exist natively rather than requiring a third-party addon,
should touch-input needs expand.

## Rendering — Relevant to EPIC-M1 (Village Board Art Direction)

**HDR output support** (4.7) — works across Windows/macOS/iOS/visionOS and
Linux (Wayland only). Not directly relevant to a mobile-only, stylized/flat-
shaded art direction target, but means any reference material or tutorial
showing HDR-lit scenes is describing a real 4.7 feature, not a rendering
bug — don't assume it's unavailable when reasoning about visual references.

**AreaLight3D** (4.7) — new node for rectangular light sources. Possibly
useful for the flat/stylized lighting EPIC-M1 is targeting (a soft area
light reads less "spotlit/naturalistic" than a point/directional light), but
not a substitute for the actual shading-model change (flat/toon materials)
the migration roadmap identifies as the real fix.

**Rendering defaults shifted brighter since 4.5** (glow blend mode, fog
blending — see `breaking-changes.md`) — account for this when tuning
EPIC-M1's palette; a palette that looked right under 4.5-era defaults will
read brighter under 4.7.

## Asset Pipeline

**New Asset Store** (4.7) replaces the former Asset Library — faster,
different UI. If sourcing any additional CC0/OFL assets (e.g. the rigged
character assets EPIC-M6 needs, per the migration roadmap's flagged gap),
expect the new Asset Store's interface, not the older Asset Library.

## XR

Godot 4.7 became a substantially more complete open-source XR engine
(Steam Frame, Android XR as first-class targets). Not relevant to this
project's scope, noted for completeness only.

## Not Covered Here

Anything not explicitly called out above should be treated as "possibly
unfamiliar" rather than assumed unchanged from pre-2026 Godot 4.x knowledge.
When in doubt, WebFetch `docs.godotengine.org/en/4.7/` rather than relying
on this assistant's general Godot familiarity, which predates this version.
