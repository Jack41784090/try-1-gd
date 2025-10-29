# Squad Battle System - Godot/GDScript Project

## Project Overview
Turn-based tactical combat system migrated from TypeScript/Roblox to Godot 4.x/GDScript. Features squad-based combat with entity stats, AI logic, weapons, armor, and skill effects.

## Architecture (Hierarchical)
```
SquadBattle (battle orchestrator)
└── Squad (entity positioning & coordination)
    └── SquadEntity (combat units with stats/equipment)
        ├── SquadLogic (AI decision-making with specialized subclasses)
        ├── SquadWeapon (damage calculation)
        ├── SquadArmour (damage mitigation)
        └── OneClash (combat resolution with hit/pierce rolls)
```

**Key Data Flow**: `SquadBattle.squad_actions()` → `Squad.squad_attack()` → `SquadEntity.action()` → `SquadLogic.choose_action()` → `OneClash.commit()` → returns `Array[EntityUpdate]`

## Critical Godot Patterns

### Class System
- **Non-Node classes**: Use `extends RefCounted` + `class_name` for global registration
  - Examples: `SquadBattle`, `Squad`, `SquadWeapon`, `SquadArmour`, `SquadLogic`
- **Resource classes**: Use `extends Resource` + `class_name` for serializable data
  - Examples: `SquadEntity`, `Skill`, `StatusEffect`, `EntityBaseStats`
- **Nested classes**: Defined inside parent class (see `SquadLogic.FrontlineLogic`, `SquadLogic.ArcherLogic`)

### Type System Conventions
- Enums in `SquadBattleTypes` (globally accessible via `Types.Reality.HP`, `Types.SquadEntityAction.ATTACK`, etc.)
- Use typed arrays where possible: `Array[EntityUpdate]`, `Array[Skill]`, `Array[SkillEffect]`
- Dictionary-based configs for initialization (see `squad_battle_demo.gd` for patterns)

### Resource Files (.tres)
- Store skill/status effect configurations as Godot resources
- See `resources/test-skill.tres` for skill definition pattern
- Can be loaded with `preload()` or drag-dropped in inspector

## Core Systems

### Entity Stats System
**Reality Values** (calculated from base stats): HP, Force, Mana, Precision, Maneuver, Guts, etc.
- Calculated via `SquadEntity.calculate_reality_value(Types.Reality.HP)`
- Formula examples: `HP = (endurance * 5) + (size * 2)`, `Force = (strength * 2) + (speed * 1) + (size * 1)`

**Changeable Stats**: HP, STA, ORG (organization/morale), LOC (location in squad formation)
- Clamped between floor/ceiling via `get_floor_changeable_stat()` / `get_ceiling_changeable_stat()`
- Modified via `mod_changeable_stat()` which returns `EntityChange` objects

### Combat Resolution (OneClash)
1. **Hit Roll**: `weapon.hit_value` vs `armour.DV` → determines if attack connects
2. **Pierce Roll**: `weapon.penetration_value` vs `armour.PV` → determines if armor is bypassed
3. **Damage Calculation**: Apply weapon damage with skill effects
4. **Skill Effect Application**: Triggers on successful hits (e.g., Frontline Strike +10% Force damage)

All combat updates return `Array[EntityUpdate]` where `EntityUpdate(source_id, target_id, EntityChange)`

### AI Logic System
Base class `SquadLogic` with `choose_action()` and `choose_reaction()` methods.

**Specialized AI Types** (nested classes in `logic.gd`):
- `FrontlineLogic`: Aggressive melee (attacks from front, moves forward if ORG > 50%, has special strike skill)
- `ArcherLogic`: Defensive ranged (retreats if front line falls, stays in back positions)
- `AbsurdLogic`: Test AI (always forward/retreat)
- `AdjustWeaponTestLogic`: Optimizes position based on weapon range

**Factory Pattern**: In `Squad._init()`, logic types instantiated by string matching:
```gdscript
match logic_type:
    "frontline": logic = SquadLogic.FrontlineLogic.new(...)
    "archer": logic = SquadLogic.ArcherLogic.new(...)
```

### Skill & Status Effect System
**Skills**: One-time effects triggered by actions (e.g., basic attack)
**Status Effects**: Persistent effects with duration, triggered by event bus signals

Event bus pattern: `StatusEffectEventBus` is autoloaded singleton for decoupled event handling (see `project.godot`)

## Project-Specific Conventions

### Comments
Avoid comments unless Godot documentation (`## Doc comments`)

### Naming
- Classes: PascalCase with prefixes (`SquadEntity`, `SquadBattleTypes`)
- Files: snake_case matching class name (`squad_entity.gd`, `types.gd`)
- Nested classes: Full path reference (`SquadLogic.FrontlineLogic`)

### Entity Update Pattern
All state changes return `EntityUpdate` objects containing `EntityChange`:
```gdscript
var updates: Array[EntityUpdate] = []
updates.append(EntityUpdate.new(source_id, target_id, 
    entity.mod_changeable_stat(Types.EntityChangeable.HP, -damage)))
return updates
```

### Location System
Squad positions use enum: `Front = 1`, `Middle = 2`, `Back = 3` (NOT zero-indexed)
- Moving forward: `mod_changeable_stat(LOC, -1)`
- Retreating: `mod_changeable_stat(LOC, +1)`

## Running & Testing

**Demo Scene**: `scenes/demos/squad_battle_demo.tscn` (F5 to run)
**Console Logging**: Extensive debug output shows combat resolution step-by-step
**Configuration**: Edit entity configs in `src/demos/squad_battle_demo.gd`

No build system needed - direct Godot editor execution. No external dependencies.

## Migration Context
Originally TypeScript/Roblox project with reactive state (`@rbxts/charm` atoms). Migration removed:
- Reactive atoms → direct value management
- Complex event bus → simplified/stubbed (foundation exists for expansion)
- Roblox-specific APIs

See `notes/MIGRATION_SUMMARY.md` and `notes/FRONTLINE_LOGIC_UPDATE.md` for detailed migration history.

## File Organization
- `src/squad_battle/`: Core combat system
- `src/squad_battle/clash/`: Skill/status effect subsystem  
- `src/demos/`: Demo implementations
- `scenes/`: Godot scene files (.tscn)
- `resources/`: Serialized resource files (.tres)
- `notes/`: Documentation and migration notes
