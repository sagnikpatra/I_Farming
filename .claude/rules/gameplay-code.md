---
paths:
  - "godot/scripts/economy/**"
---

# Gameplay Code Rules

<!-- Update (2026-08-23): path corrected from the template-default
     `src/gameplay/**`, which never matched anything in this project --
     `godot/scripts/economy/` (GameState/GameEconomy) is this project's
     real gameplay-logic layer. One line below doesn't literally match
     this project's real practice: gameplay values live as GDScript
     `const`s centralized in game_data.gd (data-driven in spirit --
     tunable, documented, no magic numbers scattered through logic --
     but not "external config files" in the JSON/CSV/Resource sense).
     That's a deliberate, established architectural choice throughout
     this project, not an oversight to fix by rewriting the rule. -->

- ALL gameplay values MUST come from external config/data files, NEVER hardcoded
- Use delta time for ALL time-dependent calculations (frame-rate independence)
- NO direct references to UI code — use events/signals for cross-system communication
- Every gameplay system must implement a clear interface
- State machines must have explicit transition tables with documented states
- Write unit tests for all gameplay logic — separate logic from presentation
- Document which design doc each feature implements in code comments
- No static singletons for game state — use dependency injection

## Examples

**Correct** (data-driven):

```gdscript
var damage: float = config.get_value("combat", "base_damage", 10.0)
var speed: float = stats_resource.movement_speed * delta
```

**Incorrect** (hardcoded):

```gdscript
var damage: float = 25.0   # VIOLATION: hardcoded gameplay value
var speed: float = 5.0      # VIOLATION: not from config, not using delta
```
