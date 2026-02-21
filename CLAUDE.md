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
  - `ai_runner_demo.tscn` — strategic AI squad brain decision tests
  - `ai_battle_royale_demo.tscn` — full fleet simulation with headless combat
  - `squad_battle_demo.tscn` — View/Presenter battle with graphical interface
- **No linter, test runner, or build step** — all verification is manual via Godot editor console output
- **Autoload singletons** (configured in `project.godot`): `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`

## Architecture

### Three-Layer System

1. **Tactical Combat** (`src/squad-battle/`) — Turn-based battle engine, View/Presenter/Model split
   - `SquadBattle` (data.gd) — Model: battle state, round logic, headless execution
   - `SquadBattleView` (view.gd) — View: entity spawning, animations, visual rendering (Node3D)
   - `SquadBattlePresenter` (presenter.gd) — Presenter: round loop, victory checks, `battle_completed` signal (Node child of View)
   - `SBGraphics` (graphics.gd) — 3D battlefield rendering, row management, attack/movement animations
   - `SquadBattleMasterFactory` (_factory.gd) — creates configured battle scene instances
   - Flow: `squad_actions() → choose_action() → action() → OneClash.execute() → Array[EntityUpdate]`
   - All state changes produce immutable `EntityUpdate`/`EntityChange` objects
   - External consumers access `battle_scene.presenter.battle_completed` signal

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
- **Strategic AI** (`src/strategy/ai/`): Data-driven Consideration scoring pattern for squad decision-making
  - `AIFleetManager` (fleet_manager.gd) — fleet orchestration, headless combat, turn execution
  - `SquadBrain` (squad_brain.gd) — runtime evaluator, iterates considerations, picks highest-scoring action
  - `SquadBrainConfig` (squad_brain_config.gd) — Resource container for considerations + fallback action
  - `StrategicConsideration` (consideration.gd) — holds glances, weight, op, returns a StrategicAction
  - `StrategicGlance` (glance.gd) — reads one property from StrategicSituation, normalizes, gates
  - `StrategicAction` (action.gd) — packages ActivityType + destination/target resolution strategies
  - `StrategicSituation` (situation.gd) — pre-computed snapshot with lazy BFS for distances
  - `FactionBrain` (faction_brain.gd) — stub for faction-level coordination (returns NONE directives)
  - `AIProfileFactory` (profile_factory.gd) — static loader with cache for SquadBrainConfig profiles
  - AI behavior is authored as .tres files in `resources/ai/strategic/` (glances, considerations, actions, profiles)
  - Mirrors the combat AI pattern: `Glance → Consideration → Config → Brain`
- **UI** (`src/strategy/ui/`): View/Presenter MVP architecture throughout. Each feature directory contains `view.gd` (passive display) and `presenter.gd` (orchestration logic). Presenter is a `Node` child of its View in the scene tree. View calls `presenter.on_X()`, Presenter calls `view.update_X()`.
  - `StrategyView` (view.gd) + `StrategyPresenter` (presenter.gd) — top-level strategy screen. Exports (`scenario_path`, `is_demo_scenario`) live on the Presenter.
  - `TravelView` (travel/view.gd) + `TravelPresenter` (travel/presenter.gd) — travel menu with AUTOPILOT/MANUAL/GOING state machine
  - `VnView` (vn/view.gd) + `VnPresenter` (vn/presenter.gd) — visual novel chain playback
  - `InvestigationView` (investigation/view.gd) — clue display, no presenter (below split threshold)
  - `RecruitmentView` (recruitment/view.gd) — warrior recruitment, no presenter (below split threshold)
  - `ManageSquadView` (manage_squad/view.gd) — roster display, no presenter (below split threshold)
  - `ShopView` (shop/view.gd) + `ShopPresenter` (shop/presenter.gd) — shop with cart system, quantity controls, confirmation flow
  - `ScoutingView` (scouting/view.gd) + `ScoutingPresenter` (scouting/presenter.gd) — scouting intelligence overlay with progressive contact revelation
- **Contact & Spotting System** (`src/strategy/core/contact/`): HOI4-inspired gradual awareness between squads
  - `Contact` (contact.gd) — RefCounted, tracks one squad's awareness of another (0-100 progress → NONE/SUSPECTED/TRACKED/LOCKED)
  - `ContactTracker` (tracker.gd) — RefCounted, central manager on `World.contact_tracker`. Update loop, proximity detection, engagement checks, tracking capacity
  - Spotting formula: `BASE_SPOTTING_RATE * proximity * (eff_scouting / (eff_scouting + eff_stealth)) * size_factor`
  - Proximity levels: SAME_LOCATION (1.0), SAME_EDGE (0.7), ADJACENT (0.3), none (0.0 → decay)
  - Activity modifiers: PATROL boosts scouting (1.5x), REST boosts stealth (1.3x), ATTACK reduces stealth (0.4x)
  - Tracking capacity per squad: `1 + floor(avg_perception / 30)`, PATROL adds +1 slot
  - ATTACK activity gated on TRACKED+ contact (30+ progress)
  - Engagement types: AMBUSH (attacker LOCKED, defender unaware), SET_PIECE (both LOCKED), MEETING (both TRACKED)
  - `SquadStrategicData.engagement_stance`: ALWAYS_ENGAGE or ENGAGE_WHEN_CONFIRMED
  - `CombatController` accepts engagement_type: AMBUSH disables flee/negotiate for defender
  - AI integration: `StrategicSituation` has `highest_contact_on_us`, `our_best_contact`, `can_ambush` lazy properties
  - AI considerations: `ambush-opportunity.tres` (weight 8), `break-contact.tres` (weight 5, travel away)
  - New `DestinationStrategy.AWAY_FROM_ENEMY` — BFS for location maximizing distance from nearest enemy
- **Shop System** (`src/strategy/core/shop/`): Data-driven shop per Location
  - `Shop` (shop.gd) — Resource with `shop_name` and `items: Array[ShopItem]`, configurable in Godot inspector
  - `ShopItem` (item.gd) — Resource with `item_type: StrategyTypes.ItemType`, `price`, `display_name`, `description`
  - `Location.shop: Shop` — optional exported property; `has_shop()` helper
  - Purchase effects mapped in `ShopPresenter._apply_item_effect()`: SUPPLY → food

### Key Enums and Types

- Combat: `src/squad-battle/types.gd` (Potency, DamageType, Reality, EntityChangeable, BattleOutcome)
- Strategy: `src/strategy/types.gd` (LocationType, Religion, ActivityType, WarriorAttribute, GlobalModifier, ItemType, ContactState, EngagementType, EngagementStance)
- Strategic AI: `src/strategy/ai/types.gd` (GlanceSubject, SquadGlanceable, LocationGlanceable, WorldGlanceable, DestinationStrategy, TargetStrategy, DirectiveType)
- Combat AI shared: `src/squad-battle/entity/logic/consideration/_types.gd` (CsdrTypes.OP, CsdrTypes.DETECTION — reused by strategic AI)

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

- `src/squad-battle/` — combat engine: View/Presenter/Model (view.gd, presenter.gd, data.gd), entity, weapon, armor, clash, AI logic
- `src/strategy/core/` — world, scenario, faction, travel, triggerable system, shop, contact
- `src/strategy/core/sb-bridge/` — combat bridge and controller
- `src/strategy/ui/` — UI View/Presenter components (view.gd + presenter.gd per feature directory)
- `src/strategy/ui/vn/` — visual novel system
- `src/strategy/ui/travel/` — travel menu
- `src/strategy/ui/investigation/` — investigation overlay
- `src/strategy/ui/recruitment/` — warrior recruitment
- `src/strategy/ui/manage_squad/` — squad roster
- `src/strategy/ui/shop/` — shop with cart UI
- `src/strategy/ui/scouting/` — scouting report overlay (progressive contact intel)
- `src/strategy/ai/` — strategic AI (fleet manager, squad brain, considerations, glances, actions)
- `resources/ai/strategic/` — AI behavior .tres files (glances, considerations, actions, profiles)
- `resources/ai/faction/` — faction brain profiles
- `src/character/` — character data classes
- `src/singletons/` — autoloaded event buses
- `resources/` — `.tres` files: scenarios, squads, warriors, events, activities, event chains
- `scenes/` — `.tscn` scene files; `scenes/demos/` for test scenes
