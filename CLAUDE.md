# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Every time when you make changes to the project, modify this file to reflect the changes made.

## Project

CONDOR — a squad-based narrative strategy game built with **Godot 4.5**, **GDScript**, and **C#**. Requires `godot-mono` and `dotnet build` for the C# economy engine (`try1.csproj`, Godot.NET.Sdk/4.6.0, net8.0).

## Running & Testing

- **Main scene**: Open in Godot 4.5+, press F5 (runs `scenario.tscn`)
- **Demo scenes** in `scenes/demos/` — run with F6:
  - `combat_controller_test.tscn`, `combat_strategy_integration_test.tscn`, `scenario_attack_test.tscn` — combat system tests
  - `ai_runner_demo.tscn` — AI squad brain decisions
  - `ai_battle_royale_demo.tscn` — fleet simulation with headless combat
  - `ai_stress_test_demo.tscn` — 13-location, 8-squad, 50-turn stress test
  - `pause_system_test.tscn` — pause/unpause, menu auto-pause, resting banner. Headless via `--headless`
  - `squad_battle_2d_demo.tscn` — 2D WarriorRig battle with skeletal animations
  - `stage_demo.tscn` — warrior stage: rigs, march, speech bubbles, camera
  - `dialogue_demo.tscn` — dialogue system (typewriter, after_id, interrupts). Headless via `--headless`
  - `ranged_combat_demo.tscn` — ranged targeting, suppression, reach weapons
  - `aoe_combat_demo.tscn` — splash damage, magical pierce, BattleContext lookup
  - `cinematic_instruction_demo.tscn` — GroupPlayback, CinematicGroup, JSON chains. Headless-only
  - `ai_act_demo.tscn` — scripted game testing with assertions. Usage: `godot --headless --path . scenes/demos/ai_act_demo.tscn`
  - `economy_demo.tscn` — 3-location supply chain, 20-turn simulation. Usage: `godot --headless --path . scenes/demos/economy_demo.tscn`
  - `caravan_demo.tscn` — economy→strategy caravan bridge. Usage: `godot --headless --path . scenes/demos/caravan_demo.tscn`
  - `interactive_demo.tscn` — terminal game with stdin commands. Usage: `godot-mono --headless --path . scenes/demos/interactive_demo.tscn`
- **Autoload singletons** (`project.godot`): `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`, `SFX`
- **Sound generation**: `python3 tools/sound_designer.py` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
- Run relevant demo tests after logic changes.
- **AI Interactive Play** via `tools/play.sh`: start game with `bash tools/start_game.sh`, wait ~20s, then `bash tools/play.sh "command"`. GOD commands: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`
- **AI Interactive Play (GUI + screenshots)**: start with `bash tools/start_game_gui.sh` (visible window), then `bash tools/play.sh "screenshot"` saves `/tmp/condor_screenshot.png`. MCP server in `tools/mcp-screenshot/server.py` exposes `screenshot_game`, `view_screenshot`, `game_command` tools for Copilot Agent
- **Screenshot workflow for AI agents**:
  1. Start game: `bash tools/start_game_gui.sh` — launches Godot with visible window + stdin/stdout pipes. Uses real `scenario.tscn` StrategyView (full UI) when in GUI mode, `HeadlessStrategyView` when `--headless`
  2. Wait ~25s for init, then send commands via `bash tools/play.sh "<command>" [wait_seconds]`
  3. Capture screenshot: `bash tools/play.sh "screenshot"` → saves `/tmp/condor_screenshot.png`
  4. MCP tools (auto-discovered via `.vscode/mcp.json`): `screenshot_game` (command + screenshot), `view_screenshot` (last screenshot), `game_command` (text-only)
  5. The `screenshot`/`ss` command in interactive_demo.gd uses `get_viewport().get_texture().get_image().save_png()` — only works in GUI mode, errors gracefully in headless
  6. Clock overlay: `ClockLabel` in top-left corner shows `⌚ HH:00`, updated by `StrategyView.update_clock()`

## Architecture

### Three-Layer System

1. **Tactical Combat** (`src/squad-battle/`) — Turn-based View/Presenter/Model
   - `SquadBattle` (data.gd) — Model: battle state, round logic. `order_retreat(team)`, `squad_actions()`, `_produce_retreat_updates()`
   - `SquadBattleView2D` (view_2d.gd) — 2D WarriorRig-based battle view (extends Control)
   - `SquadBattlePresenter` (presenter.gd) — round loop, victory checks, `battle_completed` signal. Duck-typed `var view`
   - `BattlefieldView2D` (battlefield_view.gd) — 2D battlefield: SubViewport + Camera2D, row containers (Front/Middle/Back), tween animations
   - `BattleEntityDisplay` (entity/battle_display.gd) — wraps WarriorRig + HP bar + ORG icons
   - `SquadBattleMasterFactory` (_factory.gd) — loads `sb-master-2d.tscn`, returns Control
   - Flow: `squad_actions() → choose_action() → action() → OneClash.execute() → Array[EntityUpdate]`
   - All state changes produce immutable `EntityUpdate`/`EntityChange` objects
   - **RetreatTracker** (entity/retreat_tracker.gd): FIGHTING→RETREATING→LAST_STAND→CAPITULATED. `advance()` produces LOC+1/ORG restore/CAPITULATE updates
   - **Evasion**: `OneClash.roll_for_hit()` — attacker weapon hit vs defender Maneuver reality
   - **Reality calculation**: Table-driven via `CombatEntity._REALITY_TABLE` — `[base, op, terms]` per Reality
   - **Forced retreat**: `order_retreat(ATTACKER)` mid-battle. Entities progress Front→Back→last stand→capitulate

2. **Strategic Campaign** (`src/strategy/`) — **Hour-based real-time** with Paradox-style speed controls
   - `GameScenario` (core/scenario.gd) — main orchestrator. `_setup_economy()` auto-initializes economy for worlds with `goods`/`inventory`
   - `World` (core/world.gd) — location graph, roaming squads, **hour counter** (`current_hour`), `is_paused`, `speed_multiplier`, `get_day()`, `get_hour_of_day()`, `get_clock_display()`
   - `GameClock` (core/game_clock.gd) — drives real-time hour progression. `process(delta)` accumulates time, emits `hour_ticked` signal. `pause()/unpause()/toggle_pause()/set_speed()`
   - **Hourly tick pipeline**: `GameClock.hour_ticked` → `StrategyPresenter._on_hour_tick()` runs player's current activity + all AI squads each hour. Economy ticks every 24 hours
   - **Activity toggle system**: Activities (REST, PATROL, DRILL, etc.) are persistent state on `SquadData.current_activity_type`. Player toggles, clock runs automatically. Active button shows `[ACTIVE]` text + green modulate tint. REST is default (no REST button — RESTING banner shown instead). SPACE key toggles pause (via `_input`, not `_unhandled_input`, to prevent button re-activation). Selecting an activity does NOT auto-unpause — only explicit SPACE toggle unpauses
   - **Menu auto-pause**: Opening any menu (travel, recruit, manage squad, shop, investigate, scouting, missions, market) auto-pauses the game clock. Closing a menu does NOT auto-unpause — game stays paused until explicit SPACE toggle
   - `ActivityExecuteManager` (ui/actor/!main.gd) — shared execution with `exec_before/activity/after()`. AI executors (`_IS_AI=true`) skip triggerables
   - **Activity Strategy Pattern** (`core/activity/`): `ActivityHandler` base → `ActivityRegistry` maps ActivityType→handler. 10 handlers + 5 pass-through types
   - **Triggerable system** (`core/triggerable/`): unified base for GameEvent, Mission, Ending. `TriggerableManager` with `triggerable_fired` signal, `get_triggerables_triggered()`
   - **Mission system**: `Faction.check_mission_completions(context)` → unlocks postrequisites. `StrategyPresenter._check_missions()` after GAME_START and each turn
   - **Travel system**: km-based distances with speed-dependent travel. `TownConnection.distance_km` per edge, `EntityClasses.SPEED_TABLE` (km/h per class), `SquadData.get_speed_kmh()` (slowest warrior, ×0.5 for caravan). `travel_progress_km`, `travel_route`, `travel_segment_index` on SquadData. `TravelGraph` uses distance-weighted A*

3. **Combat Bridge** (`src/strategy/core/sb-bridge/`)
   - `CombatBridge` (!main.gd) — stateless strategic↔tactical data translation. CAPITULATE → `is_injured=true`
   - `CombatController` (control.gd) — stateful orchestration. `CombatResult` includes `escaped_warriors`, `equipment_loot`

### Supporting Systems

- **SFX** (`src/singletons/sfx.gd`): `SFX` autoload, semantic play methods. Disabled in headless
- **UIAnimations** (`src/utils/ui_animations.gd`): static class — `register_button()` (hover/press/SFX), `show_overlay/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`, `pulse()`, `animate_label_number()`
- **Log** (`src/singletons/log.gd`): static `class_name Log`. Levels: TRACE/DEBUG/INFO/WARN/ERROR. `Log.info("Source", "msg")`, `Log.mute()`, `Log.set_level()`. Default: DEBUG
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond font, multi-use styles via `theme_type_variation`, single-use via `theme_override_*` or standalone `.tres` in `resources/theme/styles/`. `ThemeConstants` (`src/utils/theme_constants.gd`) for GDScript color/size constants
- **Data models**: `SquadData` (src/squad/social.gd), `CombatSquad` (src/squad/combat.gd), `CargoManifest` (src/squad/cargo_manifest.gd), `Warrior` (src/character/social.gd), `CombatEntity` (src/character/combat.gd)
- **Animation** (`src/animation/`): 5-layer system — Clips→iExpression→AnimAction→Behavior→WarriorAnimController. `WarriorRig` (warrior_rig.gd) generates placeholder Polygon2D body parts, `apply_config()` replaces with textures. `WarriorRigConfig/Factory` for per-class configs
- **Warrior Stage** (`src/strategy/ui/stage/`): `StageView` + `StagePresenter` — shared 2D viewport for march and VN. Modes: MARCH/VN/HIDDEN. `SpeechBubble` with typewriter effect, `StageCamera` with tween-based focus
- **Visual Novel** (`src/strategy/ui/vn/`): `EventChain` triggers via `event_chain_path` in results. `VnPresenter` is stage-aware (speech bubble on rig or fallback textbox). `DialogueInstruction` (instructions/dialogue_instruction.gd) extends `CinematicInstruction` with speaker_name, line_spoken, after_id. `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate). `CharacterInstruction` (SHOW/HIDE + StageAnchor), `CameraInstruction` (screen position panning)
- **Strategic AI** (`src/strategy/ai/`): Data-driven Consideration scoring
  - `AIFleetManager` (fleet_manager.gd) — `prepare_ai_turns()` runs brain decisions, `cleanup_defeated_squads()`. Duplicates Activity AND result for travel to avoid shared-state conflicts
  - `SquadBrain` (squad_brain.gd) — evaluates considerations, picks highest-scoring action
  - Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as .tres in `resources/ai/strategic/`
  - `StrategicSituation` (situation.gd) — lazy BFS snapshot. **Contact-gated**: enemies require SUSPECTED+ contact
  - Three profiles: aggressive-hunter, balanced-roamer (default), cautious-survivor
  - **Patrol→Detect→Pursue**: patrol builds contact via ContactTracker → hunt-enemies/attack activate on detection
- **AIAct Testing** (`src/strategy/ai/ai_act.gd`): `AIAct` Resource with activity + assertions. `HeadlessStrategyView` (src/demos/headless_strategy_view.gd) mocks UI for headless StrategyPresenter runs
- **UI** (`src/strategy/ui/`): View/Presenter MVP. View calls `presenter.on_X()`, Presenter calls `view.update_X()`
  - `StrategyView/Presenter` — top-level. Three orchestrators: `EconomyOrchestrator`, `CombatOrchestrator`, `ContactOrchestrator`. Unified turn pipeline in `_execute_activity_obj()`
  - `TravelView/Presenter` — AUTOPILOT/MANUAL/GOING state machine. Travel arrows for mid-journey navigation
  - `ShopView/Presenter` — cart system with stock-aware purchasing from LocationInventory
  - `ScoutingView/Presenter` — progressive contact intel with focus filters
  - `MissionsView/Presenter` — two-column: active/completed list + details
  - `MarketView/Presenter` — economy overlay: prices, production, population, trade rumors
  - `ManageSquadPage/Presenter` — tabbed: Tactics/Units/Formation/Recruitment/Inventory
  - `CombatUI` (combat_ui.gd) — RefCounted helper for all combat display. `CombatUI.create()` factory
- **Contact System** (`src/strategy/core/contact/`): HOI4-inspired gradual awareness (0-100 → NONE/SUSPECTED/TRACKED/LOCKED)
  - Spotting: `BASE_SPOTTING_RATE * proximity * (scouting/(scouting+stealth)) * size_factor`. MERCHANT 0.3x stealth
  - Proximity: SAME_LOCATION(1.0), SAME_EDGE(0.7), ADJACENT(0.3). Activity modifiers: PATROL 1.5x scouting, REST 1.3x stealth
  - ATTACK requires LOCKED contact. Engagement types: AMBUSH/SET_PIECE/MEETING
  - `ScoutingFocus` — player-configurable filter with role/class targeting and coordination multipliers
- **Shop System** (`src/strategy/core/shop/`): `Shop` Resource on Location. `Location.shop`, `Location.inventory`, `Location.natural_resources`
- **Inventory & Equipment** (`src/strategy/core/inventory.gd`, `loot_collector.gd`): `SquadInventory` for spare weapons/armors, `LootCollector` collects from dead enemies. `Warrior.equipment_weapon/armor` per-warrior slots
- **Economy** (`src/economy/`): Demand/Supply matching system. **C# mandatory** — `CsEconomyEngine` via `CsEconomyBridge`; GDScript `EconomyEngine` is thin facade
  - Core: `Thing` (goods), `EconPerson` (actors), `Population`, `LocationInventory` (stock+prices), `NaturalResource` (local production capacity), `EconomicDemand`/`EconomicSupply` (trade opportunities), `EconomyMove` (in-transit goods)
  - **Trade pipeline**: C# `Tick()` runs lifecycle phases → `GetPendingDemands()`/`GetAvailableSupplies()` export to GDScript → `TradeMatcher` scores Supply→Demand pairs using `StrategicConsideration` system → `ApplyTradeMatches()` creates shipment dispatches → `EconomyOrchestrator` spawns caravans
  - **TradeMatcher** (`trade_matcher.gd`): Greedy matching engine. Creates `TradeSituation` per pair, scores via considerations or default `(margin * 0.4 + urgency * 0.6) * safety`
  - **RouteDangerCalculator** (`route_danger.gd`): Route safety (0-1) based on aggressive squads along connections. Per-edge safety = `1.0 / (1.0 + threats)`. Route = product of edges
  - Features: input-based production chains, FIFO cost-basis tracking, elastic demand, dynamic population (starvation/birth), social mobility, central bank
  - C# engine (`src/economy/csharp/`): `CsEconomyBridge.Setup(world)` → `Tick(turn)` → `GetPendingDemands()`/`GetAvailableSupplies()` → `ApplyTradeMatches()` → `SyncInventories()`. Build: `dotnet build`. Run with `godot-mono`
- **Caravan Bridge** (`src/economy/caravan_bridge.gd`): `CaravanBridge` materializes trade dispatches as MERCHANT squads. `CaravanBrain` (src/strategy/ai/caravan_brain.gd) pathfinds to destination. Lifecycle: dispatch → spawn/reassign → pathfind → deliver → idle → reassign/despawn

### Key Enums

- Entity Classes: `src/character/classes-enum.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter
- Weapons: `src/squad-battle/weapon/_factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire
- Armor: `src/squad-battle/armor/_factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate
- Logic: `src/squad-battle/entity/logic/_factory.gd` — Frontline, BacklineHeal, BacklineShooter, DefensiveFrontline, BacklineSupport, BacklineGunner, BacklineCaster
- Combat: `src/squad-battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome
- Strategy: `src/strategy/types.gd` — LocationType, ActivityType, ContactState, EngagementType, SquadRole (COMBAT, MERCHANT)
- Strategic AI: `src/strategy/ai/types.gd` — GlanceSubject (SQUAD, LOCATION, WORLD, FACTION, TRADE), SquadGlanceable, TradeGlanceable, DestinationStrategy, TargetStrategy
- Economy: `src/economy/types.gd` — SocialClass, JobType, MoveState, ThingType
- Animation: `src/animation/types.gd` — AnimTypes.Behavior (IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING)

### Unit Classes

| Class | Role | Weapon | Armor | Logic | Pos | Cost |
|-------|------|--------|-------|-------|-----|------|
| Landsknecht | melee DPS | Flammenschwert | Leather | Frontline | Front | 100 |
| Healer | support | Unarmed | None | BacklineHeal | Back | 150 |
| Crossbowman | ranged DPS | Crossbow (-4 ORG) | Padded | BacklineShooter | Back | 120 |
| Arquebusier | glass cannon | Arquebus (-6 ORG) | None | BacklineGunner | Back | 200 |
| Pikeman | defensive | Pike (reach) | Half Plate | DefensiveFrontline | Front | 130 |
| Feldprediger | enhanced support | Mace | Padded | BacklineSupport | Back | 180 |
| Gelehrter | AoE mage | AlchemicalFire (magical, 50% splash) | None | BacklineCaster | Back | 250 |

- Ranged targeting: `WeaponLocation.can_hit` arrays define position→position reach
- Pierce: physical (Force+Precision vs armor PV) or magical (Mana+Spirituality vs magical PV). `OneClash.roll_for_pierce()` auto-branches on `is_magical`

## GDScript Conventions

### Class Hierarchy
- **RefCounted** for logic classes — **Resource** for serializable data — **Node** for scene-attached UI

### Coding Rules
- **Fail-fast**: `assert()` for requirements. No fallback values, stubs, or speculative code
- **Enums over strings**. **Typed arrays** always: `Array[EntityUpdate]` not `Array`
- **No comments** unless `##` doc comments or complex algorithms
- **One class per file**. **Factory pattern** with static `create_*()` methods
- **Don't use `preload`** on "class not found" errors. **Don't export RefCounted** types. **Don't use `class_name` for inner classes**
- **`Resource.duplicate(true)` does NOT deep-copy external `.tres` sub-resources** — always explicitly duplicate: `activity.result = activity.result.duplicate(true)`
- **Never programmatically create GUI elements** — define in `.tscn`, use `@onready` refs
- **Pre-built hidden nodes over scene instantiation** for bounded lists. Scene instantiation only for unbounded/compositional needs. Collect pools in `_ready()` from container children; hide all initially. Set `visible = true` with demo text in `.tscn` for editor preview
- **Compartmentalize GUI into scenes** — each distinct UI component gets its own `.tscn`. Item templates: `shop_item_row.tscn`, `recruitment_class_item.tscn`, `investigation_clue_item.tscn`, `contact_mini_bar.tscn`

### Terminal / File Operations
- **Never use `cat` heredoc** for GDScript files (strips tabs). Use Python `with open()` or `replace_string_in_file`
- Commit after each code update. Only add+commit your own changes

### Critical Pitfalls
- **Typed array assignment**: Never assign from `Dictionary.get()` to typed arrays. Iterate and append with type checks
- **Squad positions**: `Front = 1`, `Middle = 2`, `Back = 3` (NOT zero-indexed). Forward = -1, retreat = +1
- **Entity updates**: All combat state changes return `EntityUpdate` containing `EntityChange`

## File Organization

- `src/squad-battle/` — combat engine (data.gd model, presenter.gd, view_2d.gd, entity/, weapon/, armor/, clash/)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable, shop, contact, activity handlers
- `src/strategy/ui/` — View/Presenter per feature (stage/, vn/, travel/, shop/, scouting/, missions/, market/, manage_squad/, investigation/, recruitment/)
- `src/strategy/ui/actor/` — ActivityExecuteManager (!main.gd), ActivityRunner, AI executors
- `src/strategy/ai/` — fleet manager, squad brain, considerations, glances, actions, caravan brain
- `src/animation/` — WarriorRig, configs, expressions, actions, controller
- `src/character/` — Warrior (social.gd), CombatEntity (combat.gd), classes enum
- `src/squad/` — SquadData, CombatSquad, CargoManifest
- `src/economy/` — engine, types, thing, person, population, inventory, caravan bridge; `csharp/` for C# engine
- `src/singletons/` — event buses, SFX, Log
- `resources/scenarios/goetz-official/` — main campaign (7 locations, ~7420 population)
- `resources/ai/strategic/` — AI behavior .tres files
- `resources/generic-activities/` — Activity .tres files
- `resources/theme/` — condor_theme.tres, styles/, bold_font.tres
