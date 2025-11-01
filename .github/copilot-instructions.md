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

#### Triggerable Pattern (Base Class)
Events, Missions, and Endings share a common "check condition then execute" pattern via the `Triggerable` base class.

**Base Class** (`Triggerable` extends `Resource`):
- `trigger_id: String` - Unique identifier
- `trigger_name: String` - Display name
- `conditions: Array[TriggerCondition]` - Conditions to check before triggering
- `check_conditions(context: Dictionary) -> bool` - Evaluates all conditions
- `can_trigger(context: Dictionary) -> bool` - Virtual method for additional trigger logic
- `trigger(squad: StrategicSquad, world: World) -> Dictionary` - Executes and returns result
- `execute(squad: StrategicSquad, world: World) -> Dictionary` - Virtual method to override

**Signals for Async Execution**:
- `triggered(result: Dictionary)` - Emitted when trigger fires
- `execution_started()` - Emitted before execution begins
- `execution_completed(result: Dictionary)` - Emitted after execution finishes (for async scenes)

**Subclasses**:
- `GameEvent`: Adds `chance`, `repeats`, `when_to_trigger`, `emergency_priority`
- `Mission`: Adds prerequisite/postrequisite graph, completion effects, unlock state
- `Ending`: Adds epilogue scenes, ends the game

**Async Execution Pattern**:
When a Triggerable requires scene playback (dialogue, battle, cutscene):
1. Set `requires_async = true` in result dictionary
2. Set `dialogue_scene_path` or similar scene path field
3. Emit `triggered` signal but NOT `execution_completed`
4. External scene manager loads and plays scene
5. When scene finishes, call `triggerable.complete_async_execution(result)`
6. This emits `execution_completed` signal

**TriggerableManager**: Unified manager for Events, Missions, and Endings:
- `register(triggerable: Triggerable)` - Add any triggerable to registry
- `check_triggers(context: Dictionary, filter: Callable) -> Array[Triggerable]` - Find matching triggerables
- `trigger_all_matching(squad, world, context, filter) -> Array[Dictionary]` - Execute all matches
- `get_events()`, `get_missions()`, `get_endings()` - Type-filtered accessors
- Connects to all triggerable signals for centralized event handling

#### Mission & Faction System
Missions are objectives organized in dependency graphs per faction.

**Mission States**:
- Locked: Prerequisites not met
- Unlocked: Available to pursue
- Completed: Finish conditions met
- Failed: Mission no longer achievable

**Dependency Graph**: `prerequisite_mission_ids` → current mission → `postrequisite_mission_ids`

**Mission Completion Effects** (`completion_effects` Dictionary):
- `squad_stats: Dictionary` - Modify squad resources (money, food, morale, etc.)
- `world_stats: Dictionary` - Modify world state (end_progression, global modifiers)
- `reputation: Dictionary` - Change faction reputation by faction_id
- `trigger_events: Array[String]` - Event IDs to trigger on completion

**Mission Completion Flow**:
1. `Mission.check_completion(context)` evaluates finish conditions
2. `Mission.complete()` called by `Faction.check_mission_completions()`
3. Returns `StrategyTypes.MissionResult` with all effects
4. `Faction.update_mission_graph()` unlocks postrequisite missions
5. Effects applied by GameScenario or calling code

**Faction Reputation**: Tracked per faction, modified by activities and events

#### Location & Travel System
Locations form an adjacency graph instead of being fully connected.

**Location Connections**:
- `connected_location_ids: Array[String]` - IDs of adjacent locations
- `is_connected_to(location_id: String) -> bool` - Check adjacency
- `add_connection(location_id: String)` - Add bidirectional or directed edge
- Connections manually configured or procedurally generated

**TravelGraph Helper Class**:
- `add_location(location: Location)` - Register location in graph
- `find_path(from_id: String, to_id: String) -> Array[String]` - BFS pathfinding
- `calculate_path_travel_time(path: Array[String]) -> int` - Sum travel time per segment
- `get_distance(from_id: String, to_id: String) -> int` - Hop count
- `get_all_reachable_locations(from_id: String, max_hops: int) -> Array[String]` - BFS with depth limit
- `is_adjacent(from_id: String, to_id: String) -> bool` - Direct connection check

**Travel Time Calculation** (per segment):
- Base time: 1 turn
- ROAD locations: -1 turn (min 1)
- Low stability (<50): +1 turn
- Calculated via `Location.calculate_base_travel_time(to_location)`

**TravelActivity Pathfinding**:
- If destination is adjacent: Travel directly
- If destination is NOT adjacent: Use `World.find_path()` to get route, travel to first waypoint
- Each travel action moves one hop along the path
- Player sees narrative: "Traveled to X, en route to Y (N more steps)"

**World Integration**:
- `World.travel_graph: TravelGraph` - Maintained automatically
- `World.add_location(location)` - Adds to both locations array and travel graph
- `World.build_travel_graph()` - Rebuilds graph from current locations
- `World.find_path(from, to)`, `World.calculate_travel_time(from, to)`, `World.get_reachable_locations(from)` - Delegate to TravelGraph

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
6. ❌ **Don't directly assign untyped arrays to typed array properties** - Always use iterative assignment or helper methods (see below)
7. ❌ **Don't use `.get()` with default array values for typed arrays** - Returns untyped Array, causing type errors
8. ❌ **Don't cast Dictionary.get() results to typed arrays** - The cast happens after .get() returns untyped Array

### Typed Array Assignment Pattern (CRITICAL)
GDScript has strict typed array requirements. **ANY assignment to a typed array variable MUST come from a compatible typed source.**

**The Problem:**
```gdscript
var my_array: Array[String] = []
my_array = config.get("items", [])  # ❌ WRONG: .get() returns untyped Array
my_array = config.get("items", [] as Array[String])  # ❌ STILL WRONG: Cast happens before .get()
my_array = config.get("items", []) as Array[String]  # ❌ STILL WRONG: .get() already returned untyped Array
```

**✅ CORRECT Solutions:**

**Method 1: Iterative Assignment (Most Reliable)**
```gdscript
var my_array: Array[String] = []
var raw_data = config.get("items", [])
if raw_data is Array:
    for item in raw_data:
        if item is String:  # Type check each element
            my_array.append(item)
```

**Method 2: Helper Method**
```gdscript
# In the class
func set_items(items: Array[String]) -> void:
    my_array.clear()
    my_array.append_array(items)  # append_array from typed param is safe

# Usage - caller must provide typed array
var items: Array[String] = ["a", "b", "c"]
obj.set_items(items)
```

**Method 3: Two-step with Clear Intermediate**
```gdscript
var temp_array = config.get("items", [])
var my_array: Array[String] = []
if temp_array is Array:
    for val in temp_array:
        my_array.append(val if val is String else "")
```

**When Loading from JSON/Dictionary:**
```gdscript
# ❌ NEVER do this:
character_ids = data.get("character_ids", [] as Array[String])

# ✅ ALWAYS do this:
var raw_ids = data.get("character_ids", [])
if raw_ids is Array:
    for id_val in raw_ids:
        if id_val is String:
            character_ids.append(id_val)
```

**Why This Matters:**
- `Dictionary.get()` always returns untyped Variant
- Type casts (`as Array[String]`) don't convert, they just assert/fail
- Godot's type system is strict at assignment boundaries
- **This error will appear at compile time and break the code completely**

**Golden Rule:** Never directly assign from Dictionary.get(), JSON parsing, or any untyped source to a typed array variable. Always iterate and append with type checking.
