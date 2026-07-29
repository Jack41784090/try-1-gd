---
description: "Use when editing strategic campaign: world, scenario, clock, activities, travel, contact system, missions, triggerables, AI fleet/brain, UI views/presenters. Covers src/strategy/ architecture."
applyTo: "src/strategy/**"
---

# Strategic Campaign System

Hour-based real-time with Paradox-style speed controls in `src/strategy/`.

## Core

- `GameScenario` (core/scenario.gd) — main orchestrator. `_setup_economy()` asserts all non-FORT locations have inventory, validates shops require inventory
- `World` (core/world.gd) — location graph, roaming squads, **hour counter** (`current_hour`), `is_paused`, `speed_multiplier`, `get_day()`, `get_hour_of_day()`, `get_clock_display()`
- `GameClock` (core/game_clock.gd) — drives real-time hour progression. `process(delta)` accumulates time, emits `hour_ticked` signal. `pause()/unpause()/toggle_pause()/set_speed()`

## Hourly Tick Pipeline

`GameClock.hour_ticked` → `StrategyPresenter._on_hour_tick()` runs player's current activity + all AI squads each hour. Economy ticks every 24 hours.

## Documentation Sync

- When editing `src/strategy/**`, update matching architecture notes in `/home/ikec/Documents/schwarzwagen/CONDOR/Systems/` in the same task.
- Update the impacted notes under `Systems/Core/`, `Systems/Activities/`, `Systems/AI/`, `Systems/Contact/`, `Systems/Runtime/`, and `Systems/UI/`.
- If strategic flow edges change, also update `Systems/Graph Seed.md`, `Systems/Systems.md`, and relevant `!index.md` notes.

## Activity System

- Activities (REST, PATROL, DRILL, etc.) are persistent state on `SquadData.current_activity_type`. Player toggles, clock runs automatically
- Active button shows `[ACTIVE]` text + green modulate tint. REST is default (no REST button — RESTING banner shown instead)
- SPACE key toggles pause (via `_input`, not `_unhandled_input`). Selecting an activity does NOT auto-unpause
- **Menu auto-pause**: Opening any menu auto-pauses the game clock. Closing does NOT auto-unpause
- `ActivityExecuteManager` (ui/actor/activity_execute_manager.gd) — shared execution with `exec_before/activity/after()`. AI executors (`_IS_AI=true`) skip triggerables
- **Activity Strategy Pattern** (`core/activity/`): `ActivityHandler` base → `ActivityRegistry` maps ActivityType→handler. 10 handlers + 5 pass-through types

## Travel System

km-based distances with speed-dependent travel:
- `TownConnection.distance_km` per edge, `EntityClasses.SPEED_TABLE` (km/h per class)
- `SquadData.get_speed_kmh()` (slowest warrior, ×0.5 for caravan)
- `travel_progress_km`, `travel_route`, `travel_segment_index` on SquadData
- `TravelGraph` uses distance-weighted A*

## Contact System

`src/strategy/core/contact/` — HOI4-inspired gradual awareness (0-100 → NONE/SUSPECTED/TRACKED/LOCKED):
- Spotting: `BASE_SPOTTING_RATE * proximity * (scouting/(scouting+stealth)) * size_factor`. MERCHANT 0.3x stealth
- Proximity: SAME_LOCATION(1.0), SAME_EDGE(0.7), ADJACENT(0.3). Activity modifiers: PATROL 1.5x scouting, REST 1.3x stealth
- ATTACK requires LOCKED contact. Engagement types: AMBUSH/SET_PIECE/MEETING
- `ScoutingFocus` — player-configurable filter with role/class targeting and coordination multipliers

## Triggerable & Mission System

- **Triggerable system** (`core/triggerable/`): unified base for GameEvent, Mission, Ending. `TriggerableManager` with `triggerable_fired` signal
- **Mission system**: `Faction.check_mission_completions(context)` → unlocks postrequisites. `StrategyPresenter._check_missions()` after GAME_START and each turn

## Strategic AI

`src/strategy/ai/` — Data-driven Consideration scoring:
- `AISquadManager` (squad_manager.gd) — `prepare_ai_turns()` runs brain decisions, `cleanup_defeated_squads()`. Owns the `BanditSpawner` helper and exposes `tick_bandit_lifecycle(faction)`. Duplicates Activity AND result for travel to avoid shared-state conflicts
- `SquadBrain` (squad_brain.gd) — evaluates considerations, picks highest-scoring action
- Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as .tres in `resources/ai/strategic/`
- `StrategicSituation` (situation.gd) — lazy BFS snapshot. **Contact-gated**: enemies require SUSPECTED+ contact
- Three profiles: aggressive-hunter, balanced-roamer (default), cautious-survivor
- **Patrol→Detect→Pursue**: patrol builds contact via ContactTracker → hunt-enemies/attack activate on detection
- AI types: `src/strategy/ai/types.gd` — GlanceSubject (SQUAD, LOCATION, WORLD, FACTION, TRADE), SquadGlanceable, TradeGlanceable, DestinationStrategy, TargetStrategy

## UI Pattern

View/Presenter MVP. View calls `presenter.on_X()`, Presenter calls `view.update_X()`:
- `StrategyView/Presenter` — top-level. Two orchestrators: `CombatOrchestrator`, `ContactOrchestrator`. Economy lives directly on `EconomyEngine` (no orchestrator); `_run_economy_tick()` bridges `EconomyEngine.tick_full()` to `AISquadManager` via `CaravanBridge`. Unified turn pipeline in `_on_hour_tick()`
- `TravelView/Presenter` — AUTOPILOT/MANUAL/GOING state machine
- `ShopView/Presenter` — cart system with stock-aware purchasing from LocationInventory
- `ScoutingView/Presenter` — hover slide-in panel from left edge. Auto-refreshes contact data on open. `bind()` stores world/squad refs
- `SquadLogView` — right-side slide-in chatbox panel. Logs real-time squad events. Tab peeks from right edge with hover/click/pin behavior. Unread count badge
- `MissionsView/Presenter` — two-column: active/completed list + details
- `MarketView/Presenter` — economy overlay: prices, production, population, trade rumors
- `ManageSquadPage/Presenter` — tabbed: Tactics/Units/Formation/Recruitment/Inventory
- `CombatUI` (combat_ui.gd) — RefCounted helper for all combat display. `CombatUI.create()` factory

## Supporting

- **Shop System** (`core/shop/`): `Shop` Resource on Location. `Location.shop`, `Location.inventory`, `Location.natural_resources`
- **Inventory & Equipment** (`core/inventory.gd`, `loot_collector.gd`): `SquadInventory` for spare weapons/armors, `LootCollector` collects from dead enemies. `Warrior.equipment_weapon/armor` per-warrior slots
- **Data models**: `SquadData` (src/squad/social.gd), `CombatSquad` (src/squad/combat.gd), `CargoManifest` (src/squad/cargo_manifest.gd), `Warrior` (src/character/social.gd), `CombatEntity` (src/character/combat.gd)
