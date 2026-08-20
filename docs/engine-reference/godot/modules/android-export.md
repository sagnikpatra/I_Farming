# Godot 4.7.1 — Android Export

Last verified: 2026-08-18. This project targets Android exclusively
(`technical-preferences.md`: minSdk 24, targetSdk/compileSdk 37, no other
platform planned), so Android export gets its own reference file rather than
living only in `current-best-practices.md`'s general notes.

## GABE — Godot Android Build Environment (Stable in 4.7)

The headline change for this project's EPIC-M0 setup. GABE is a companion
app to the Godot Android editor providing Gradle export support — it can
generate AAB and APK files directly, including **on an Android/XR device
itself**, without hand-installing and wiring up the Android SDK/NDK/Gradle
toolchain externally first. Before assuming the older "install Android
Studio's command-line tools, configure Godot's Editor Settings with SDK/
JDK/Gradle paths" workflow is still the primary path, check whether GABE
covers EPIC-M0's setup needs — it's the newer, lower-friction option as of
this pinned version.

Practical implication for EPIC-M0: budget time to evaluate GABE first before
falling back to the traditional manual toolchain setup this assistant's
older training data would otherwise default to describing.

## Project Layout Change (Since 4.6)

Android export project structure changed:
```
android/build/src/          (pre-4.6)
    ↓
android/build/src/main/java/   (4.6+)
```
Relevant if referencing any pre-4.6 Godot Android export tutorial or
documentation — the file layout it describes is outdated for this project's
pinned 4.7.1.

## Asset Delivery — OBB Removed (4.7)

Deprecated Google Play OBB support was removed in 4.7. If total asset size
(this project has 627 sourced Kenney `.obj`/`.mtl` models, though only a
curated subset is expected to ship — see `assets_3d/README.md`'s "curated
subset" model, which should carry over conceptually to the Godot target)
exceeds APK/AAB limits for Play Store distribution, the replacement paths
are:
- **Play Asset Delivery** — Google Play's own dynamic asset delivery system
- **PCK split** — Godot's own mechanism for splitting the exported `.pck`
  data file

Decide which (if either is needed at all, depending on final bundled-asset
size) during EPIC-M0's asset-import spike, once the contact-sheet import
pass gives a real size figure — don't assume OBB is available as a fallback.

## Other Android-Relevant 4.7 Features (Not Expected to Be Used, Noted for Completeness)

- Picture-in-picture windowed rendering support
- Built-in virtual joystick / gyro aiming / accelerometer input — this
  project's interaction model is tap/long-press-drag/pinch-zoom/pan, not
  joystick or motion-based, so not expected to be relevant, but available
  natively if touch-input needs expand later

## Verification Required Before EPIC-M0 Ships

- Confirm GABE (or the traditional toolchain, if GABE proves insufficient
  for this project's needs) actually produces a working debug APK on the
  Medium_Phone AVD (API 35/36) — this project's existing verified target
  environment, per `technical-preferences.md`
- Confirm minSdk 24 / targetSdk 37 are both still valid/supported export
  settings under 4.7.1 — verify against `docs.godotengine.org/en/4.7/` if
  Godot's own minimum-supported-Android-API floor has moved since this
  assistant's training data
