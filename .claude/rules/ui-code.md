---
paths:
  - "godot/scripts/ui/**"
---

# UI Code Rules

<!-- Update (2026-08-23): path corrected from the template-default
     `src/ui/**`, which never matched anything in this project --
     `godot/scripts/ui/` is where every HUD/sheet/picker/card actually
     lives. The gamepad line below doesn't apply to this project: input
     is touch-only (technical-preferences.md's own Input & Platform
     section -- "Gamepad Support: None"), a deliberate platform choice,
     not a gap. Everything else here is genuinely relevant, especially
     the localization-system rule -- this project has a real, complete
     CSV-translation pipeline this whole rule already assumes exists. -->

- UI must NEVER own or directly modify game state — display only, use commands/events to request changes
- All UI text must go through the localization system — no hardcoded user-facing strings
- Support both keyboard/mouse AND gamepad input for all interactive elements
- All animations must be skippable and respect user motion/accessibility preferences
- UI sounds trigger through the audio event system, not directly
- UI must never block the game thread
- Scalable text and colorblind modes are mandatory, not optional
- Test all screens at minimum and maximum supported resolutions
