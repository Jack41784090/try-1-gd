# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Every time when you make changes to the project, modify this file to reflect the changes made.

## Project

CONDOR — a squad-based narrative strategy game built with **Godot 4.5** and **GDScript**. Migrated from TypeScript/Roblox. No external dependencies or build system; everything runs directly in the Godot editor.

## Running & Testing

- **Main scene**: Open in Godot 4.5+, press F5 (runs `scenario.tscn`)
- **Demo scenes**: In `scenes/demos/` — open any `.tscn` and run with F6
  - `combat_controller_test.tscn` — combat system
  - `combat_strategy_integration_test.tscn` — bridge between strategy and combat
  - `scenario_attack_test.tscn` — activity/combat flow
- **No linter, test runner, or build step** — all verification is manual via Godot editor console output
- **Autoload singletons** (configured in `project.godot`): `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`

## Architecture

### Three-Layer System

1. **Tactical Combat** (`src/squad-battle/`) — Turn-based battle engine
   - `SquadBattle` (master.gd) orchestrates rounds
   - Flow: `squad_actions() → choose_action() → action() → OneClash.execute() → Array[EntityUpdate]`
   - All state changes produce immutable `EntityUpdate`/`EntityChange` objects

2. **Strategic Campaign** (`src/strategy/`) — Overworld activities, events, factions
   - `GameScenario` (core/scenario.gd) is the main orchestrator
   - `World` (core/world.gd) holds location graph, roaming squads, turn counter
   - Flow: `execute_turn(Activity) → execute() → check_triggers() → advance_turn()`
   - **Triggerable system** (`core/triggerable/`): unified base for GameEvent, Mission, Ending — each with conditions, results, and a `TriggerableManager` registry

3. **Combat Bridge** (`src/strategy/core/sb-bridge/`)
   - `CombatBridge` (!main.gd) — stateless data translation between strategic and tactical layers
   - `CombatController` (control.gd) — stateful orchestration: intermission → combat → resolution

### Supporting Systems

- **Squad data model** (`src/squad.gd`, `src/squad-base-data.gd`, `src/squad-strat.gd`, `src/squad-combat.gd`): Squad wraps base roster + strategic state + combat state
- **Character model** (`src/character/`): Three layers — `CharacterBaseData`, `CharacterCombatStats`, `CharacterSocialStats`
- **Visual Novel** (`src/strategy/ui/vn/`): `EventChain` resources trigger via `requires_async = true` + `event_chain_path` in any result. Split into `VnView` (view.gd) for display and `VnPresenter` (presenter.gd) for chain queue/progression state machine.
- **AI** (`src/strategy/ai/`): `FleetManager` for roaming squads; `SimplifiedSquadLogic` with Consideration pattern for combat decisions
- **UI** (`src/strategy/ui/`): View/Presenter MVP architecture throughout. Each feature directory contains `view.gd` (passive display) and `presenter.gd` (orchestration logic). Presenter is a `Node` child of its View in the scene tree. View calls `presenter.on_X()`, Presenter calls `view.update_X()`.
  - `StrategyView` (view.gd) + `StrategyPresenter` (presenter.gd) — top-level strategy screen. Exports (`scenario_path`, `is_demo_scenario`) live on the Presenter.
  - `TravelView` (travel/view.gd) + `TravelPresenter` (travel/presenter.gd) — travel menu with AUTOPILOT/MANUAL/GOING state machine
  - `VnView` (vn/view.gd) + `VnPresenter` (vn/presenter.gd) — visual novel chain playback
  - `InvestigationView` (investigation/view.gd) — clue display, no presenter (below split threshold)
  - `RecruitmentView` (recruitment/view.gd) — warrior recruitment, no presenter (below split threshold)
  - `ManageSquadView` (manage_squad/view.gd) — roster display, no presenter (below split threshold)

### Key Enums and Types

- Combat: `src/squad-battle/types.gd` (Potency, DamageType, Reality, EntityChangeable, BattleOutcome)
- Strategy: `src/strategy/types.gd` (LocationType, Religion, ActivityType, WarriorAttribute, GlobalModifier)

## GDScript Conventions

### Class Hierarchy

- **RefCounted** for logic classes (SquadBattle, GameScenario, TriggerableManager, TravelGraph)
- **Resource** for serializable data (World, Faction, Mission, Squad, Character data)
- **Node** for scene-attached UI

### Coding Rules

- **Fail-fast**: No fallback values, no stubs, no unused signals/parameters/speculative code. Use `assert()` for requirements.
- **Enums over strings** for all categorical data. **Typed arrays** always: `Array[EntityUpdate]` not `Array`.
- **No comments** unless Godot doc comments (`##`) or genuinely complex algorithms.
- **One class per file** except small nested utility classes.
- **Factory pattern** with static `create_*()` methods for polymorphic instantiation.
- **Don't use `preload`** when you see "class not found" errors — Godot needs time to parse classes.
- **Don't export RefCounted types** — only Resources, Nodes, built-ins, or enums.
- **Don't use `class_name` for inner classes** — causes namespace pollution.
- **Don't add comments in `.tscn` files** — Godot scene format doesn't support them.

### Typed Array Assignment (Critical Pitfall)

Never assign from `Dictionary.get()` or untyped sources to typed arrays. Always iterate and append:

```gdscript
# WRONG: my_array = config.get("items", [])
var my_array: Array[String] = []
var raw = config.get("items", [])
if raw is Array:
    for item in raw:
        if item is String:
            my_array.append(item)
```

### Location System

Squad positions: `Front = 1`, `Middle = 2`, `Back = 3` (NOT zero-indexed). Forward = `-1`, retreat = `+1`.

### Entity Update Pattern

All combat state changes return `EntityUpdate` containing `EntityChange`:
```gdscript
var updates: Array[EntityUpdate] = []
updates.append(EntityUpdate.new(source_id, target_id,
    entity.mod_changeable_stat(Types.EntityChangeable.HP, -damage)))
return updates
```

## File Organization

- `src/squad-battle/` — combat engine (entity, weapon, armor, clash, AI logic)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable system
- `src/strategy/core/sb-bridge/` — combat bridge and controller
- `src/strategy/ui/` — UI View/Presenter components (view.gd + presenter.gd per feature directory)
- `src/strategy/ui/vn/` — visual novel system
- `src/strategy/ui/travel/` — travel menu
- `src/strategy/ui/investigation/` — investigation overlay
- `src/strategy/ui/recruitment/` — warrior recruitment
- `src/strategy/ui/manage_squad/` — squad roster
- `src/strategy/ai/` — strategic AI (fleet manager)
- `src/character/` — character data classes
- `src/singletons/` — autoloaded event buses
- `resources/` — `.tres` files: scenarios, squads, warriors, events, activities, event chains
- `scenes/` — `.tscn` scene files; `scenes/demos/` for test scenes
