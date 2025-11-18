# CONDOR - Godot/GDScript Project

## Project Overview
**CONDOR** is a squad-based narrative strategy game with:
1. **Tactical Combat**: Turn-based battles with entity stats, AI logic, weapons/armor, skills
2. **Strategic Campaign**: Activities, events, missions, factions
3. See `.obsidian/AI-Notes` for additional details

Migrated from TypeScript/Roblox to Godot 4.x/GDScript.

## Architecture

### Tactical: `SquadBattle → Squad → SquadEntity → SquadLogic/Weapon/Armour → OneClash`
**Flow**: `squad_actions() → squad_attack() → action() → choose_action() → commit()` → `Array[EntityUpdate]`

### Strategic: `GameScenario → World/EventManager/Factions/StrategicSquad`
**Flow**: `execute_turn(Activity) → execute() → check_triggers() → advance_turn()`

### Bridge: `StrategicSquad.to_combat_squad()` ↔ `from_combat_results()`

## Godot Patterns

### Classes
- **RefCounted**: Logic classes (`SquadBattle`, `Squad`, `TriggerableManager`, `TravelGraph`)
- **Resource**: Serializable data (`SquadEntity`, `Skill`, `World`, `Mission`, `GameScenario`, `Triggerable`)
- **Consideration-based AI**: Current system uses `SimplifiedSquadLogic` with `Consideration` pattern (no nested logic subclasses)

### Types
- **Enums**: `SquadBattleTypes.Reality.HP`, `StrategyTypes.LocationType.CITY`
- **Typed arrays**: `Array[EntityUpdate]`, `Array[Warrior]`
- **Prefer enums over String**, typed classes over Dictionary

## Core Systems

### Combat
- **Stats**: Reality values (HP, Force, etc.) calculated from base stats via `calculate_reality_value()`
- **Changeable**: HP, STA, ORG, LOC modified via `mod_changeable_stat()` → `EntityChange`
- **Resolution**: Hit roll → Pierce roll → Damage → Skill effects → `Array[EntityUpdate]`
- **AI Logic**: Uses `SimplifiedSquadLogic` with `Consideration` pattern (scores actions/targets)
- **Skills/Status**: One-time vs persistent effects via `StatusEffectEventBus` autoload singleton

### Strategy
- **Activities**: `REST`, `DRILL`, `TRAVEL`, `PATROL`, `INVESTIGATE`, `HOLD_MASS`
- **Results**: `ActivityResult` extends `GenericResult` with `squad_stat_changes`, `event_chain_path`, `requires_async`

- **TriggerCondition**: `LOCATION`, `LOCATION_TYPE`, `WARRIOR_STATUS`, `SQUAD_STATUS`, `ACTIVITY_TYPE`, `TIME`, `MISSION_STATUS`, `COMPOUND` (nested AND/OR)
- **EventManager**: Checks events each turn by priority
- **Results**: `GenericResult` (base) → `ActivityResult`, `EventResult`, `MissionResult`, `EndingResult`

- **Triggerable** (base class): `check_conditions() → can_trigger() → trigger() → execute()`
  - **GameEvent**: `chance`, `repeats`, `times_triggered`, `emergency_priority`
  - **Mission**: `prerequisite_mission_ids`, `postrequisite_mission_ids`, `check_completion()`, `complete()`
  - **Ending**: `narrative_text`, `epilogue_scene_paths`
- **Async Pattern**: Set `requires_async = true`, `event_chain_path` in result, emit signals for scene manager
- **TriggerableManager**: Central registry with `register()`, `check_triggers()`, `get_by_id()`

- **Missions**: Locked → Unlocked → Completed/Failed
- **Dependency**: `prerequisites → mission → postrequisites`
- **Completion Effects**: `squad_stats`, `world_stats`, `reputation`, `trigger_events`
- **Faction Reputation**: Modified by activities/events

- **Travel**: Adjacency graph with `TravelGraph.find_path()` BFS pathfinding
- **Travel Time**: Base 1 turn, modified by location type and stability
- **World State**: Turn counter, location graph, global modifiers (五行), end progression

#### Bridge to Combat
**Strategic → Tactical** (not yet fully implemented):
```gdscript
func to_combat_squad() -> Squad:
    # Convert Warriors[] to SquadEntity configs
```

**Tactical → Strategic** (not yet fully implemented):
```gdscript
func from_combat_results(updates: Array[EntityUpdate]):
    # Apply HP/ORG changes, mark casualties
```

#### VN System
**EventChain** (Resource): Contains `chain_id`, `character_ids`, `dialogues[]`
- `load_from_json_file(path)` / `load_from_json_string(json)`

**Dialogue** (Resource): `speaker_name`, `line_spoken`, `on_screen_character_ids`, `background_id`, `triggers`

**Integration**: Results set `event_chain_path` + `requires_async = true` → UI loads and plays chain

## Project-Specific Conventions

### Integrated Visual Novel System
Activities, Events, Missions, and Endings can trigger EventChains for narrative presentation:
- **VisualNovelComponent** (RefCounted): Logic class managing EventChain state and progression
- **TrainingScreen UI Modes**: 
  - `STRATEGY`: Normal activity selection and stats display
  - `VISUAL_NOVEL`: EventChain playback with character portraits and dialogue
- **Result Extensions**: All Result types (`ActivityResult`, `EventResult`, `MissionResult`, `EndingResult`) have:
  - `event_chain_path: String` - Path to EventChain resource
  - `has_event_chain() -> bool` - Check if EventChain should be played
- **UI Integration**: VN elements embedded in main screen, no scene switching required
- **Flow**: Activity executes → Result with event_chain_path → UI switches to VN mode → Play chain → Return to strategy mode

See `_obsidian/AI-Notes/INTEGRATED_VN_SYSTEM.md` for complete documentation.

### Comments
Avoid comments unless Godot documentation (`## Doc comments`)

### Naming
- Classes: PascalCase with prefixes (`SquadEntity`, `SquadBattleTypes`)
- Files: snake_case or kebab-case matching class name (`squad_entity.gd`, `types.gd`, `_script.gd`)
- Nested classes: Defined inline (e.g., `SimplifiedSquadLogic` contains logic for considerations)

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
- `src/strategy/triggerable/`: Unified triggerable system (base class, manager, condition)
- `src/strategy/triggerable/game-event/`: GameEvent implementation and result
- `src/strategy/triggerable/mission/`: Mission implementation and result
- `src/strategy/triggerable/ending/`: Ending implementation and result
- `src/strategy/vn/`: Visual novel system (EventChain, Dialogue, VisualNovelComponent)
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

**✅ CORRECT Solution (Iterative Assignment):**
```gdscript
var my_array: Array[String] = []
var raw_data = config.get("items", [])
if raw_data is Array:
    for item in raw_data:
        if item is String:
            my_array.append(item)
```

**Golden Rule:** Never directly assign from Dictionary.get(), JSON parsing, or any untyped source to a typed array variable. Always iterate and append with type checking.
