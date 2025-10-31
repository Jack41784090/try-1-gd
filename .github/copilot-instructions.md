# CONDOR - Godot/GDScript Project

## Project Overview
**CONDOR** is a squad-based narrative strategy game with turn-based tactical combat. The project consists of two major layers:
1. **Tactical Combat System**: Turn-based squad battles with entity stats, AI logic, weapons, armor, and skill effects
2. **Strategic Campaign Layer**: Activity-based turn management, event system, mission progression, and faction dynamics

Originally migrated from TypeScript/Roblox to Godot 4.x/GDScript.

## Architecture (Hierarchical)

### Tactical Combat Layer
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

### Strategic Campaign Layer
```
GameScenario (campaign orchestrator)
├── World (global state, locations, turn tracking)
├── EventManager (trigger-based event system)
├── Factions[] (allegiances with mission trees)
│   └── Missions[] (dependency graph nodes)
└── StrategicSquad (out-of-combat squad representation)
    ├── Warriors[] (individual units with morale/religion)
    ├── Resources (Money, Food, Travel Tools)
    └── Location (current position in world)
```

**Key Data Flow**: `GameScenario.execute_turn(Activity)` → `Activity.execute()` → `EventManager.check_triggers()` → `Events fire` → `Mission completion check` → `Ending check` → `World.advance_turn()`

### Combat ↔ Strategy Bridge Pattern
The strategic layer invokes combat when needed:
- `StrategicSquad.to_combat_squad()` → converts to `Squad` with `SquadEntity[]`
- Run combat via `SquadBattle`
- `StrategicSquad.from_combat_results()` → updates `Warriors[]` from `EntityUpdate[]`

## Critical Godot Patterns

### Class System
- **Non-Node classes**: Use `extends RefCounted` + `class_name` for global registration
  - Examples: `SquadBattle`, `Squad`, `SquadWeapon`, `SquadArmour`, `SquadLogic`
- **Resource classes**: Use `extends Resource` + `class_name` for serializable data
  - Examples: `SquadEntity`, `Skill`, `StatusEffect`, `EntityBaseStats`
- **Nested classes**: Defined inside parent class (see `SquadLogic.FrontlineLogic`, `SquadLogic.ArcherLogic`)

### Type System Conventions
- **Tactical Combat**: Enums in `SquadBattleTypes` (globally accessible via `SquadBattleTypes.Reality.HP`, `SquadBattleTypes.SquadEntityAction.ATTACK`, etc.)
- **Strategic Campaign**: Enums in `StrategyTypes` (accessible via `StrategyTypes.LocationType.CITY`, `StrategyTypes.Religion.CATHOLIC`, etc.)
- Use typed arrays where possible: `Array[EntityUpdate]`, `Array[Warrior]`, `Array[Mission]`, `Array[TriggerCondition]`
- Dictionary-based configs for initialization (see demo files for patterns)
- **Prefer typed enums over String**: Use `StrategyTypes.Religion` not `String`, `StrategyTypes.ActivityType` not `String`
- **Prefer typed classes over Dictionary**: Use `StrategyTypes.ActivityResult` not raw `Dictionary` when structure is known

### Resource Files (.tres)
- Store skill/status effect configurations as Godot resources
- See `resources/test-skill.tres` for skill definition pattern
- Can be loaded with `preload()` or drag-dropped in inspector

## Core Systems

### Tactical Combat Systems

#### Entity Stats System
**Reality Values** (calculated from base stats): HP, Force, Mana, Precision, Maneuver, Guts, etc.
- Calculated via `SquadEntity.calculate_reality_value(SquadBattleTypes.Reality.HP)`
- Formula examples: `HP = (endurance * 5) + (size * 2)`, `Force = (strength * 2) + (speed * 1) + (size * 1)`

**Changeable Stats**: HP, STA, ORG (organization/morale), LOC (location in squad formation)
- Clamped between floor/ceiling via `get_floor_changeable_stat()` / `get_ceiling_changeable_stat()`
- Modified via `mod_changeable_stat()` which returns `EntityChange` objects

#### Combat Resolution (OneClash)
1. **Hit Roll**: `weapon.hit_value` vs `armour.DV` → determines if attack connects
2. **Pierce Roll**: `weapon.penetration_value` vs `armour.PV` → determines if armor is bypassed
3. **Damage Calculation**: Apply weapon damage with skill effects
4. **Skill Effect Application**: Triggers on successful hits (e.g., Frontline Strike +10% Force damage)

All combat updates return `Array[EntityUpdate]` where `EntityUpdate(source_id, target_id, EntityChange)`

#### AI Logic System
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

#### Skill & Status Effect System
**Skills**: One-time effects triggered by actions (e.g., basic attack)
**Status Effects**: Persistent effects with duration, triggered by event bus signals

Event bus pattern: `StatusEffectEventBus` is autoloaded singleton for decoupled event handling (see `project.godot`)

### Strategic Campaign Systems

#### Activity System
Activities are player actions that consume turns. Base class `Activity` with virtual `execute()` method.

**Activity Types** (enum `StrategyTypes.ActivityType`):
- `REST`: Recovers morale, costs food
- `DRILL`: Improves combat stats, costs morale
- `TRAVEL`: Moves between locations, triggers travel events
- `PATROL`: Improves location stability, gains reputation
- `INVESTIGATE`: Discovers missions/locations, costs money
- `HOLD_MASS`: Religious ceremony, affects morale by religion

**Factory Pattern**: `Activity.create_activity(ActivityType)` returns specific subclass

**Result Pattern**: All activities return `StrategyTypes.ActivityResult` with:
- `narrative_log: Array[String]` - Player-facing text
- `squad_stat_changes: Dictionary` - Squad resource modifications
- `world_stat_changes: Dictionary` - World state modifications
- `triggered_event_ids: Array[String]` - Events to fire

#### Event & Trigger System
Events are narrative occurrences checked before/after activities.

**TriggerCondition** types (enum `TriggerCondition.ConditionType`):
- `LOCATION`: Specific location ID check
- `LOCATION_TYPE`: Location category check (City, Town, etc.)
- `WARRIOR_STATUS`: Warrior attributes (religion count, morale range)
- `SQUAD_STATUS`: Squad resources (money, food, morale, karma)
- `ACTIVITY_TYPE`: Current activity being performed
- `TIME`: Turn number range
- `MISSION_STATUS`: Mission completion state
- `COMPOUND`: AND/OR logic combining multiple conditions

**Composite Pattern**: Conditions can nest infinitely:
```gdscript
var condition = TriggerCondition.new()
condition.condition_type = TriggerCondition.ConditionType.COMPOUND
condition.parameters = {
    "operator": "AND",
    "subconditions": [
        {"type": "SQUAD_STATUS", "parameters": {"squad_morale_max": 50.0}},
        {"type": "LOCATION_TYPE", "parameters": {"location_type": StrategyTypes.LocationType.CITY}}
    ]
}
```

**EventManager**: Checks all registered events each turn, sorts by emergency priority

#### Mission & Faction System
Missions are objectives organized in dependency graphs per faction.

**Mission States**:
- Locked: Prerequisites not met
- Unlocked: Available to pursue
- Completed: Finish conditions met
- Failed: Mission no longer achievable

**Dependency Graph**: `prerequisite_mission_ids` → current mission → `postrequisite_mission_ids`

**Faction Reputation**: Tracked per faction, modified by activities and events

#### World State
Global game state tracking:
- Turn counter
- Location graph (connected nodes)
- Global modifiers (五行: Metal, Wood, Water, Fire, Earth)
- End progression value

#### Bridge to Combat
**Strategic → Tactical** (not yet fully implemented):
```gdscript
func to_combat_squad() -> Squad:
    # Convert Warriors[] to SquadEntity configs
    # Preserve formation, equipment, stats
    # Return Squad ready for SquadBattle
```

**Tactical → Strategic** (not yet fully implemented):
```gdscript
func from_combat_results(updates: Array[EntityUpdate]):
    # Apply HP changes to warriors
    # Update morale from ORG changes
    # Mark dead warriors
    # Remove casualties from squad
```

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

**Tactical Demo**: `scenes/demos/squad_battle_demo.tscn` (F5 to run)
**Strategic Demo**: `src/demos/strategy_demo.gd` (attach to Node scene and run)
**Console Logging**: Extensive debug output shows combat/strategy resolution step-by-step
**Configuration**: Edit entity/activity configs in demo files

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
- `src/strategy/`: Strategic campaign layer
- `src/strategy/core/`: Core strategic classes (World, Squad, Warrior, GameScenario)
- `src/strategy/activities/`: Activity implementations
- `src/strategy/events/`: Event and trigger condition system
- `src/strategy/missions/`: Mission, faction, and ending system
- `src/strategy/locations/`: Location/travel graph
- `src/demos/`: Demo implementations
- `src/singletons/`: Autoloaded event buses
- `scenes/`: Godot scene files (.tscn)
- `resources/`: Serialized resource files (.tres)
- `notes/`: Documentation and migration notes

## Best Practices Learned

### Type Safety
1. **Always use enums over strings** for categorical data (Religion, LocationType, ActivityType)
2. **Always use typed arrays** when element type is known: `Array[Warrior]` not `Array`
3. **Use Resource subclasses** for data that needs serialization (World, Warrior, Mission)
4. **Use RefCounted subclasses** for logic classes (GameScenario, EventManager, Activity)
5. **Avoid exporting RefCounted types** - only Resources, built-ins, Nodes, or enums can be @export

### Architecture Patterns
1. **Factory Pattern**: Use static `create_*()` methods for polymorphic instantiation (Activity.create_activity())
2. **Composite Pattern**: For recursive structures like TriggerCondition with AND/OR nesting
3. **Bridge Pattern**: Separate strategic and tactical representations with conversion methods
4. **Result Pattern**: Return strongly-typed result objects (ActivityResult, EventResult) instead of raw dictionaries
5. **Event Bus Pattern**: Use autoloaded singletons for cross-system communication without tight coupling

### Data Flow
1. **Context Dictionaries**: Build context once, pass to all evaluators (avoid repeated data gathering)
2. **Immutable Results**: Return new result objects, don't modify passed parameters
3. **Stub Warnings**: Use `push_warning()` for unimplemented combat bridge methods to track what needs completion
4. **Signal Orchestration**: Emit signals from orchestrator (GameScenario) not from low-level classes

### Code Organization
1. **One class per file** except nested utility classes (EventChoice inside StrategyTypes is fine)
2. **Match file name to class name**: `strategic_squad.gd` for `StrategicSquad`
3. **Group related enums**: StrategyTypes contains all strategic enums, SquadBattleTypes contains all combat enums
4. **Prefix unused parameters**: Use `_squad` instead of `squad` to avoid warnings in virtual methods

### Common Pitfalls to Avoid
1. ❌ Don't use `class_name` for inner classes - it causes global namespace pollution
2. ❌ Don't export RefCounted types - Godot can only export Resources, Nodes, built-ins, or enums
3. ❌ Don't use `Array[CustomClass]` before CustomClass is defined - will cause compile errors until Godot parses all files
4. ❌ Don't mix strategic and tactical concerns in same class - keep layers separate
5. ❌ Don't hardcode magic numbers - use named constants or configuration dictionaries
6. ❌ **Don't directly assign untyped arrays to typed array properties in Resources** - use helper methods like `set_activity_types()` or explicit casts `as Array[Type]`

### Typed Array Assignment Pattern
When working with `@export var my_array: Array[CustomType] = []` in Resources:

**❌ Wrong** (causes runtime type errors):
```gdscript
location.available_activity_types = [ActivityType.REST, ActivityType.DRILL]
```

**✅ Better** (explicit cast):
```gdscript
location.available_activity_types = [ActivityType.REST, ActivityType.DRILL] as Array[StrategyTypes.ActivityType]
```

**✅ Best** (helper method):
```gdscript
# In the Resource class
func set_activity_types(types: Array[StrategyTypes.ActivityType]) -> void:
    available_activity_types.clear()
    available_activity_types.append_array(types)

# Usage
location.set_activity_types([ActivityType.REST, ActivityType.DRILL])
```

**Why?** Godot's Resource system can't infer array types from literals at runtime. Helper methods that accept typed parameters bypass this limitation cleanly.
