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
  - `ai_battle_royale_demo.tscn` — full fleet simulation with headless combat (small 2-location world)
  - `ai_stress_test_demo.tscn` — large-world AI stress test: 13 locations, 8 squads with mixed profiles, 50-turn simulation with forage/heal/buy/mercenary/patrol behaviors
  - `squad_battle_demo.tscn` — View/Presenter battle with graphical interface
  - `stage_demo.tscn` — warrior stage: animated rigs, march mode, speech bubbles, camera control
  - `dialogue_demo.tscn` — dialogue system: typewriter effect, after_id batch grouping, interrupt detection, SPACE fast-forward, narrator fallback. Headless test mode via `--headless` flag
  - `ranged_combat_demo.tscn` — ranged combat: mixed squads with Crossbowman, Arquebusier, Pikeman, Feldprediger. Headless battle testing ranged targeting, suppression ORG damage, reach weapons, and support skills
  - `aoe_combat_demo.tscn` — AoE combat: Gelehrter mages with Alchemical Fire (magical weapon). Tests splash damage (50% ratio), magical pierce rolls, BattleContext enemy-at-position lookup
  - `cinematic_instruction_demo.tscn` — cinematic instruction system: after_id resolution, chained dependencies, mixed absolute/relative timing, TimelinePlayback firing order, gate pausing, tutorial EventChain .tres loading. Headless-only test
  - `ai_act_demo.tscn` — AIAct scripted game testing: deterministic action sequences drive the player squad through the full production pipeline headlessly. Verifies travel, foraging, events, mission completions, stat changes via pass/fail assertions. Tracks all events fired (`triggerable_fired` signal) and mission completions (retroactive GAME_START detection + live signal). Tests Goetz tutorial events: `g0_weak_army_tutorial`, `tutorial_first_rest`, `tutorial_first_travel`, `city_toll_event`, and mission chain `g0_license_crisis` → `g1_march_to_nuremberg`. Usage: `godot --headless --path . scenes/demos/ai_act_demo.tscn`
  - `caravan_demo.tscn` — caravan bridge integration: economy+strategy bridge test. 3-location world (Farmstead→Market Town→Castle) with EconomyEngine supply rules dispatching ShipmentDispatch artifacts → CaravanBridge creates SquadStrategicData caravans with MERCHANT role → CaravanBrain pathfinds to destination → delivery applies goods to LocationInventory. 15-turn headless simulation, assertions on spawn/delivery/role. Usage: `godot --headless --path . scenes/demos/caravan_demo.tscn`
- **Autoload singletons** (configured in `project.godot`): `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`, `SFX`
- **Sound generation**: `python3 tools/sound_designer.py` writes synthesized SFX to `assets/sfx/` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
- Every time an update has been made to the logic of the code, run the relevant tests within the demo folder.

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
   - `World` (core/world.gd) holds location graph, roaming squads, turn counter, `@export goods: Array[Thing]` for economy goods registry
   - **Unified turn pipeline** (karma-sorted phase loop): All squads (player + AI) sorted by karma descending, then each phase (TURN_START → BEFORE → ACTIVITY → AFTER) executes for all squads before moving to the next phase. Combat resolved inline per-result (headless for AI, visual for player). No separate attack conflict resolution step.
   - `ActivityExecuteManager` (!main.gd) — shared execution engine with `exec_before()`, `exec_activity()`, `exec_after()` phase methods used by both `ActivityRunner` (player) and AI executors
   - **Triggerable system** (`core/triggerable/`): unified base for GameEvent, Mission, Ending — each with conditions, results, and a `TriggerableManager` registry. `TriggerableManager.triggerable_fired` signal emitted by AEM after each trigger fires and by StrategyPresenter after mission completions. `TriggerableManager.get_triggerables_triggered()` uses `can_trigger()` (respects repeat limits and chance rolls via GameEvent override)
   - **Mission system**: `Faction.check_mission_completions(context)` evaluates all unlocked missions against context (location, squad status, etc.), completes matching ones, and unlocks postrequisites. `StrategyPresenter._check_missions()` calls this after GAME_START and after each activity turn, queuing event chains for VN playback. Missions use `dialogue_scene_path` (mapped to `event_chain_path` on MissionResult) for narrative cutscenes

   - **Travel time system**: `TownConnection.travel_time` (int, @export) is the base cost per connection hop. `Location.calculate_base_travel_time(to)` uses `connection.travel_time` as base, then applies ROAD bonuses (-1 per road endpoint) and stability penalties (+1 if either location <50 stability). `TravelGraph.calculate_travel_time(path)` sums per-hop times. Goetz scenario connections range 2-3 turns per hop. Food demand halved to compensate (SOLDIER: 0.5/turn, PEASANT: 0.25, MERCHANT/CLERGY: 0.4, NOBLE: 0.75)

3. **Combat Bridge** (`src/strategy/core/sb-bridge/`)
   - `CombatBridge` (!main.gd) — stateless data translation between strategic and tactical layers
   - `CombatController` (control.gd) — stateful orchestration: intermission → combat → resolution

### Supporting Systems

- **SFX System** (`src/singletons/sfx.gd`): Autoload singleton `SFX` caches and plays one-shot UI/combat sounds from `assets/sfx/*.wav` with semantic methods (`play_ui_hover`, `play_ui_click`, `play_ui_confirm`, `play_ui_cancel`, `play_attack_for_weapon`, `play_combat_clink`, `play_death`, `play_player_victory`, `play_player_defeat`). Disabled automatically in headless mode.
- **UI Animations** (`src/utils/ui_animations.gd`): `UIAnimations` static utility class (via `class_name`) for modern UI polish. Provides:
  - `register_button(button)` — attaches hover scale-up (1.05x, TRANS_BACK), press scale-down (0.95x), release bounce-back via mouse_entered/exited/button_down/button_up signals. Skips animation on disabled buttons
  - `register_button(button)` also triggers SFX hooks (`ui_hover` on hover enter, `ui_click` on release) via `SFX` autoload lookup
  - `register_all_buttons(root)` — recursively registers all Button children
  - `show_overlay(overlay, panel)` / `hide_overlay(overlay, panel)` — fade + slide-from-below overlay transitions (0.25s fade, 0.3s slide with TRANS_BACK easing)
  - `stagger_buttons(buttons, delay)` — cascade reveal animation for button grids (scale 0.8→1.0 + fade in, 0.04s between each)
  - `slide_in_panel(panel)` / `slide_out_panel(panel)` — standalone panel slide animations
  - `pulse(control)` — attention-drawing scale bounce
  - `animate_label_number(label, from, to)` — smooth number counter animation
  - All overlay views (Travel, Shop, Scouting, Missions, Investigation, Recruitment, ManageSquad) use `show_overlay`/`hide_overlay` for animated open/close
  - Action buttons and nav buttons in StrategyView are registered with `register_button` for hover/press animations
  - Strategy UI `show_strategy_ui()` uses `stagger_buttons()` for cascading button reveal
  - Combat panel uses `slide_in_panel`/`slide_out_panel` for animated show/hide
- **Debug Logger** (`src/singletons/log.gd`): `Log` static utility class (via `class_name`, not autoload) with level-based filtering and per-source muting. Levels: TRACE, DEBUG, INFO, WARN, ERROR. Static methods: `Log.info("Source", "msg")`. Output format: `[LEVEL] [Source] msg`. Source convention: `"ClassName"` or `"ClassName:EntityName"`. `Log.mute("Contact")` suppresses by prefix match. `Log.set_level(Log.Level.INFO)` adjusts global verbosity. Default level: DEBUG.
- **Squad data model** (`src/squad.gd`, `src/squad-base-data.gd`, `src/squad-strat.gd`, `src/squad-combat.gd`): Squad wraps base roster + strategic state + combat state
- **Character model** (`src/character/`): Three layers — `CharacterBaseData`, `CharacterCombatStats`, `CharacterSocialStats`
- **Animation Composition System** (`src/animation/`): Five-layer system for 2D skeletal warrior characters
  - Layer 1 — **Clips**: Raw `AnimationPlayer` tracks in two domains: Body (Skeleton2D bone transforms) and Face (sprite frame indices)
  - Layer 2 — **iExpression** (expression.gd): Resource combining an eye clip + mouth clip. Predefined `.tres` in `resources/animation/expressions/`
  - Layer 3 — **AnimAction** (action.gd): Resource pairing a body clip + iExpression. Predefined `.tres` in `resources/animation/actions/`
  - Layer 4 — **Behavior**: Named states in an `AnimationNodeStateMachine` on the `AnimationTree` (idle, walking, attacking, defending, hurt, dying, talking, gesturing)
  - Layer 5 — **WarriorAnimController** (warrior_anim_controller.gd): Node that translates high-level `play_behavior()`/`set_expression()`/`play_action()` into AnimationTree parameter changes
  - `WarriorRig` (warrior_rig.gd) — Node2D scene with Skeleton2D, Face (Eyes+Mouth sprites), AnimPlayer, AnimTree, controller. Generates **placeholder Polygon2D body parts** at runtime via `_build_placeholder_body()`: top-level Polygon2D children synced to bone transforms each frame in `_process()`. Class-based palettes (Landsknecht=red, Healer=blue). Visuals tracked per bone name in `_limb_nodes` — `_replace_limb(bone_name, texture)` swaps placeholder polygons for a Sprite2D on a single bone. `apply_config()` does per-bone replacement (only bones with textures are replaced; others keep placeholders)
  - `WarriorRigConfig` (rig_config.gd) — Resource with per-bone-segment textures (Head, Torso, Hips, LeftArm/Forearm/Hand, RightArm/Forearm/Hand, LeftLeg/Shin/Foot, RightLeg/Shin/Foot) + face spritesheets. `get_bone_textures()` returns bone_name→Texture2D dictionary for only the populated fields
  - `WarriorRigConfigFactory` (rig_config_factory.gd) — Static loader + cache (same pattern as `AIProfileFactory`)
  - `WarriorRigFactory` (rig_factory.gd) — Creates rigs from warriors or NPC character IDs (NPC appearance seeded from ID hash)
  - `AnimTypes` (types.gd) — `Behavior` enum
  - Adding expressions/actions = create `.tres` files, no code changes
- **Warrior Stage** (`src/strategy/ui/stage/`): Shared 2D viewport for animated warriors, used by both march and VN
  - `StageView` (view.gd) — Control with SubViewportContainer (renders 2D WarriorRigs) + BubbleLayer (UI speech bubbles). Manages rig spawning, march movement, bubble positioning
  - `StagePresenter` (presenter.gd) — Mode switching (MARCH/VN/HIDDEN), march API, VN API (dialogue positioning, camera focus, NPC rig spawning)
  - `StageCamera` (stage_camera.gd) — Camera2D with tween-based `focus_on()`, `focus_between()`, `reset_to_wide()`, `get_screen_position()` for world→viewport projection
  - `SpeechBubble` (speech_bubble.gd) — PanelContainer rendered in BubbleLayer, positioned above WarriorRig heads via camera projection. Scale-up appear, fade-out dismiss. **Typewriter effect**: `start_typewriter()` reveals text character-by-character via `visible_characters`. Punctuation pauses (`.!?` = 0.22s, `,:;` = 0.12s, other = 0.03s). `set_speed(multiplier)` for fast-forward (5x). `word_revealed` signal emits each word for interrupt detection. `stop_typewriter()` freezes mid-word, `complete_immediately()` reveals all. `typewriter_finished` signal on completion
  - Mode transitions: MARCH (warriors walk, wide camera) ↔ VN (warriors rearrange, camera zooms, speech bubbles) ↔ HIDDEN (combat)
- **Visual Novel** (`src/strategy/ui/vn/`): `EventChain` resources trigger via `requires_async = true` + `event_chain_path` in any result. Split into `VnView` (view.gd) for fallback/narrator display and `VnPresenter` (presenter.gd) for chain queue/progression state machine. VnPresenter is **stage-aware**: checks if speaker has a rig on the warrior stage — if yes, displays speech bubble on the rig; if no, falls back to the textbox (also used for narrator lines). `_DEBUG` mode shows a narrator message identifying the skipped chain (click to dismiss) instead of silently skipping.
  - `Dialogue` (dialogue.gd) — Stage-aware Resource with cutscene properties:
    - Core: `id` (unique within chain for referencing), `speaker_name`, `line_spoken`
    - Stage display: `keep_previous_bubbles` (overlay mode), `camera_target` (focus override), `expression_override`
    - Sequencing: `delay_ms` (pause before showing), `after_id` (dependency on another dialogue), `duration_ms` (auto-advance timer, 0 = manual)
    - Interruption: `interrupt_by_id` + `interrupt_on_word` (cut short when referenced dialogue says keyword)
    - Stage direction: `walk_to` (Vector2 stage coords), `behavior` (animation override), `face_direction` (-1/0/1)
    - Helpers: `has_walk_to()`, `has_interrupt()`, `has_after_dependency()`, `is_auto_advance()`
  - `EventChain` (event_chain.gd) — `get_dialogue_by_id()` for ID-based lookup
  - `StagePresenter.show_speech()` returns `SpeechBubble` for typewriter tracking. `walk_character()`, `set_character_facing()`, `set_character_behavior()`. `dismiss_all_speech()` only resets TALKING rigs to IDLE (preserves WALKING/GESTURING behaviors)
  - **Dialogue demo state machine** (`dialogue_demo.gd`): IDLE→TYPEWRITING→WAITING→COMPLETE. `after_id` batch grouping (dialogues sharing same `after_id` fire simultaneously). Interrupt detection via `word_revealed` signal (auto-fires interrupter dialogue). SPACE fast-forwards all active typewriters to 5x. Narrator typewriter uses `visible_characters` in `_process()`. Headless test mode via `--headless` flag
- **Strategic AI** (`src/strategy/ai/`): Data-driven Consideration scoring pattern for squad decision-making
  - `AIFleetManager` (fleet_manager.gd) — fleet orchestration: `prepare_ai_turns()` runs brain decisions and resolves Activity objects (duplicating for TRAVEL/FORCE_MARCH to avoid shared-state conflicts). Does NOT execute activities — execution happens in the unified karma-sorted phase loop in `StrategyPresenter`. Provides `_execute_headless_combat()` and `cleanup_defeated_squads()` for combat resolution. Caches `location_at_decision` per squad for correct edge_log reporting
  - `SquadBrain` (squad_brain.gd) — runtime evaluator, iterates considerations, picks highest-scoring action. Location-independent activities (TRAVEL, FORCE_MARCH, ATTACK, REST, HEAL, BUY_SUPPLIES, FORAGE, PATROL, DRILL, MERCENARY_WORK) bypass location activity_type checks
  - `SquadBrainConfig` (squad_brain_config.gd) — Resource container for considerations + fallback action
  - `StrategicConsideration` (consideration.gd) — holds glances, weight, op, returns a StrategicAction
  - `StrategicGlance` (glance.gd) — reads one property from StrategicSituation, normalizes, gates
  - `StrategicAction` (action.gd) — packages ActivityType + destination/target resolution strategies. Uses next-hop pathfinding for travel/force-march destinations
  - `StrategicSituation` (situation.gd) — pre-computed snapshot with lazy BFS for distances, contact analysis, enemy weakness tracking. **Contact-gated**: `enemies_here`, `adjacent_enemies`, `nearest_enemy_location`, `nearest_enemy_distance` all require SUSPECTED+ contact via `world.contact_tracker` — AI squads cannot see enemies they haven't detected through the contact system
  - `FactionBrain` (faction_brain.gd) — stub for faction-level coordination (returns NONE directives)
  - `AIProfileFactory` (profile_factory.gd) — static loader with cache for SquadBrainConfig profiles
  - AI behavior is authored as .tres files in `resources/ai/strategic/` (glances, considerations, actions, profiles)
  - Mirrors the combat AI pattern: `Glance → Consideration → Config → Brain`
  - Key considerations: attack-weak-enemy (15, MUL), buy-supplies-at-town (12), forage-when-hungry (10), rest-when-exhausted (8), finish-off-enemy (8), ambush-opportunity (8), travel-to-town (8), mercenary-work (7), hunt-enemies (6), heal-at-town (6), pursue-clues (5), break-contact (5), recruit-when-depleted (5), patrol-for-info (5), drill-when-idle (1)
  - Three profiles: aggressive-hunter (combat-focused, has hunt-enemies), balanced-roamer (versatile, default, has hunt-enemies), cautious-survivor (economic survival, no combat considerations)
  - **Patrol→Detect→Pursue cycle**: Squads patrol to build contact awareness via ContactTracker → once SUSPECTED+ contact is reached, hunt-enemies and attack considerations activate → squads travel toward and engage detected enemies. No omniscient enemy tracking
- **AIAct Scripted Testing** (`src/strategy/ai/ai_act.gd`): Resource for deterministic headless game testing
  - `AIAct` — Resource with `activity_type`, `destination_id`, `target_squad_id`, `description` + assertion fields (`expect_location`, `expect_min_food`, `expect_max_food`, `expect_min_morale`, `expect_event_fired`, `expect_events_fired: Array[String]`, `expect_min_warriors`)
  - `AIAct.create(type, desc, dest, target)` — static factory for programmatic test sequences
  - `HeadlessStrategyView` (`src/demos/headless_strategy_view.gd`) — mock view with no-op UI methods, real ActivityRunner/AIFleetManager, mock VN/Stage. Allows StrategyPresenter to run the full production pipeline headlessly
  - Demo (`ai_act_demo.gd`) uses the **real StrategyPresenter** with HeadlessStrategyView: `presenter.bind_view(mock_view)` boots the game, then `presenter.on_travel_confirmed()` / `presenter.on_activity_requested()` drive turns through the actual production turn pipeline
  - Travel uses the real multi-turn progress system — TRAVEL acts auto-continue until arrival (`on_travel_confirmed` + `on_continue_travel` loop)
  - StrategyPresenter `bind_view(v)` accepts untyped view (duck-typed) to support both StrategyView and HeadlessStrategyView
  - Assertions checked after each turn with PASS/FAIL logging; summary at end
  - AI squads (if present in scenario) still use normal SquadBrain via AIFleetManager
- **UI** (`src/strategy/ui/`): View/Presenter MVP architecture throughout. Each feature directory contains `view.gd` (passive display) and `presenter.gd` (orchestration logic). Presenter is a `Node` child of its View in the scene tree. View calls `presenter.on_X()`, Presenter calls `view.update_X()`.
  - `StrategyView` (view.gd) + `StrategyPresenter` (presenter.gd) — top-level strategy screen. Exports (`scenario_path`, `is_demo_scenario`) live on the Presenter. Owns the unified turn pipeline: `_execute_activity_obj()` calls `prepare_ai_turns()` → `_build_karma_sorted_entries()` → karma-sorted phase loop → `cleanup_defeated_squads()` → contacts → `_check_missions()` → advance turn. `_check_missions()` also runs after `GAME_START` triggerables in `bind_view()`. `_resolve_ai_combat_from_results()` handles inline headless combat for AI squads.
  - `StageView` (stage/view.gd) + `StagePresenter` (stage/presenter.gd) — warrior stage (see above)
  - `TravelView` (travel/view.gd) + `TravelPresenter` (travel/presenter.gd) — travel menu with AUTOPILOT/MANUAL/GOING state machine. Path selection cached across menu open/close (cleared only on explicit cancel). GOING mode shows location list for mid-travel destination changes
  - `VnView` (vn/view.gd) + `VnPresenter` (vn/presenter.gd) — visual novel chain playback, delegates to StagePresenter
  - `InvestigationView` (investigation/view.gd) — clue display, no presenter (below split threshold)
  - `RecruitmentView` (recruitment/view.gd) — warrior recruitment, no presenter (below split threshold)
  - `ManageSquadView` (manage_squad/view.gd) — roster display, no presenter (below split threshold)
  - `ShopView` (shop/view.gd) + `ShopPresenter` (shop/presenter.gd) — shop with cart system, quantity controls, confirmation flow
  - `ScoutingView` (scouting/view.gd) + `ScoutingPresenter` (scouting/presenter.gd) — scouting intelligence overlay with progressive contact revelation
  - `MissionsView` (missions/view.gd) + `MissionsPresenter` (missions/presenter.gd) — two-column missions overlay: left column lists active/completed missions, right column shows selected mission details (description, conditions, rewards). UI built programmatically. Opened via "Missions" button in bottom nav bar. `MissionsPresenter.open()` accepts `Array[Mission]` (caller collects from factions). Guarded against empty factions in presenter
- **Contact & Spotting System** (`src/strategy/core/contact/`): HOI4-inspired gradual awareness between squads
  - `Contact` (contact.gd) — RefCounted, tracks one squad's awareness of another (0-100 progress → NONE/SUSPECTED/TRACKED/LOCKED)
  - `ContactTracker` (tracker.gd) — RefCounted, central manager on `World.contact_tracker`. Update loop, proximity detection, engagement checks, tracking capacity
  - Spotting formula: `BASE_SPOTTING_RATE * proximity * (eff_scouting / (eff_scouting + eff_stealth)) * size_factor`
  - Proximity levels: SAME_LOCATION (1.0), SAME_EDGE (0.7), ADJACENT (0.3), none (0.0 → decay)
  - Activity modifiers: PATROL boosts scouting (1.5x), REST boosts stealth (1.3x), ATTACK reduces stealth (0.4x)
  - Tracking capacity per squad: `1 + floor(avg_perception / 30)`, PATROL adds +1 slot
  - ATTACK activity gated on SUSPECTED+ contact (1+ progress) for same-location enemies (both AI fleet_manager and activity script.gd use SUSPECTED threshold)
  - Engagement types: AMBUSH (attacker LOCKED, defender unaware), SET_PIECE (both LOCKED), MEETING (both TRACKED)
  - `SquadStrategicData.engagement_stance`: ALWAYS_ENGAGE or ENGAGE_WHEN_CONFIRMED
  - `CombatController` accepts engagement_type: AMBUSH disables flee/negotiate for defender
  - AI integration: `StrategicSituation` has `highest_contact_on_us`, `our_best_contact`, `can_ambush`, `weakest_tracked_enemy_warriors` lazy properties
  - AI considerations: `ambush-opportunity.tres` (weight 8), `break-contact.tres` (weight 5, travel away), `finish-off-enemy.tres` (weight 8, force march when enemy weak + tracked), `rest-when-exhausted.tres` (weight 8, rest when morale low)
  - `DestinationStrategy.AWAY_FROM_ENEMY` — BFS for location maximizing distance from nearest enemy
  - `hunt-enemies` action uses TRAVEL (not FORCE_MARCH) — AI travels towards enemies normally, only force-marches to finish off weak tracked targets
  - `patrol-for-info` weight reduced to 3.0 — prevents patrol from dominating other decisions
  - Force march resolves destination via next-hop pathfinding (no teleportation), moves 2 hops per turn (double speed)
- **Shop System** (`src/strategy/core/shop/`): Data-driven shop per Location
  - `Shop` (shop.gd) — Resource with `shop_name` and `items: Array[Thing]`, configurable in Godot inspector
  - `Location.shop: Shop` — optional exported property; `has_shop()` helper. Goetz scenario: 6 towns have shops (Öhringen, Heilbronn, Schwäbisch Hall, Rothenburg, Nürnberg, Bamberg) with food/cloth/tools/luxury scaled by development
  - `Location.supply_rules: Array[SupplyRule]` — exported, configurable per-location production/import rules for economy engine
  - Purchase effects mapped in `ShopPresenter._apply_thing_effect()`: ThingType.FOOD → food, CLOTH → money, TOOLS → travel_tools, LUXURY → morale

### Key Enums and Types

- Entity Classes: `src/character/classes-enum.gd` (EntityClasses.Types: Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter)
- Weapons: `src/squad-battle/weapon/_factory.gd` (WeaponClasses: Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire)
- Armor: `src/squad-battle/armor/_factory.gd` (ArmorClasses: Unarmored, LeatherArmor, PaddedArmor, HalfPlate)
- Logic: `src/squad-battle/entity/logic/_factory.gd` (LogicAvailable: Frontline, BacklineHeal, BacklineShooter, DefensiveFrontline, BacklineSupport, BacklineGunner, BacklineCaster)
- Combat: `src/squad-battle/types.gd` (Potency, DamageType, Reality, EntityChangeable, BattleOutcome)
- Strategy: `src/strategy/types.gd` (LocationType, Religion, ActivityType [includes HEAL=13, BUY_SUPPLIES=14], WarriorAttribute, GlobalModifier, ContactState, EngagementType, EngagementStance, SquadRole [COMBAT, MERCHANT])
- Strategic AI: `src/strategy/ai/types.gd` (GlanceSubject, SquadGlanceable [includes WEAKEST_TRACKED_ENEMY_WARRIORS, INJURED_WARRIOR_COUNT], LocationGlanceable [includes HAS_SHOP], WorldGlanceable, DestinationStrategy, TargetStrategy, DirectiveType)
- Combat AI shared: `src/squad-battle/entity/logic/consideration/_types.gd` (CsdrTypes.OP [ADD=0, RDC=1, MUL=2, AVG=3], CsdrTypes.DETECTION [BELOW=0, ABOVE=1, EQUAL=2] — reused by strategic AI)
- Animation: `src/animation/types.gd` (AnimTypes.Behavior — IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING)

### Unit Classes & Combat Configuration

7 unit classes with distinct combat roles:
- **Landsknecht** — melee frontline DPS. Flammenschwert (Force→Slash+Strike), Leather Armor, Frontline logic. Front position. Cost: 100
- **Healer** — backline support. Unarmed, Unarmored, BacklineHeal logic (move-to-back + heal). Back position. Cost: 150
- **Crossbowman** — ranged DPS. Crossbow (Precision→Stab+Strike, range: Back→all, Mid→Front+Mid, Front→Front), Padded Armor, BacklineShooter logic. -4 ORG suppression on hit. Back position. Cost: 120
- **Arquebusier** — glass cannon. Arquebus (Force→Strike+Stab, high penetration, low accuracy, range: Back→all, Mid→Front+Mid), Unarmored, BacklineGunner logic. -6 ORG suppression on hit. Back position. Cost: 200
- **Pikeman** — defensive frontline with reach. Pike (Force→Stab+Strike, range: Front→Front+Mid, Mid→Front), Half Plate, DefensiveFrontline logic. Front position. Cost: 130
- **Feldprediger** — enhanced support. Mace (Force→Strike, Front→Front only), Padded Armor, BacklineSupport logic (move-to-back + heal + inspire ORG boost). Back position. Cost: 180
- **Gelehrter** — AoE backline mage. Alchemical Fire (Mana→Arcane, `is_magical=true`, range: Back→Front+Mid, Mid→Front, Front→Front), Unarmored, BacklineCaster logic (move-to-back + fireball). Fireball splash deals 50% damage to all enemies at target's position via `SkillEffectSplash`. Back position. Cost: 250

Ranged targeting works via WeaponLocation.can_hit arrays — each weapon defines which positions it can reach from each position. Suppression is a SkillEffectFlat with property_direct=ORG triggered on TargetTookDamage. Splash is a `SkillEffectSplash` triggered on TargetTookDamage — iterates enemies at target's position, rolls magical pierce per target, deals ratio-reduced damage.

### Magical vs Physical Combat
- `WeaponConfig.is_magical` / `SquadWeapon.is_magical` — flags weapon as magical
- **Physical pierce**: `weapon.get_total_penetration_value()` (Force+Precision) vs `armor.get_PV()` (armor_bonus+Endurance+Bravery)
- **Magical pierce**: `weapon.get_magical_penetration_value()` (Mana+Spirituality) vs `armor.get_magical_PV()` (magical_armor_bonus+Spirituality+Willpower)
- `OneClash.roll_for_pierce()` branches on `is_magical` automatically
- `BattleContext` (battle_context.gd) — typed wrapper around context dict, provides `get_enemies_at(loc)` and `get_allies_at(loc)` for AoE targeting. Constructed in `OneClash.commit()` and passed to skill effects via `set_attacker_and_target()`

## GDScript Conventions

### Class Hierarchy

- **RefCounted** for logic classes (SquadBattle, GameScenario, TriggerableManager, TravelGraph)
- **Resource** for serializable data (World, Faction, Mission, Squad, Character data, iExpression, AnimAction, WarriorRigConfig)
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

### Terminal / File Operations

- **Never use `cat` with a heredoc to overwrite files** — bash heredocs strip all tab indentation, breaking GDScript (which is indentation-sensitive). Use Python instead:
  ```
  python3 - << 'PYEOF'
  content = '''\t(tabs preserved as \\t escapes)'''
  with open('path/to/file.gd', 'w') as f: f.write(content)
  PYEOF
  ```
- **Prefer `replace_string_in_file`** for targeted edits to existing files — avoids full rewrites entirely.

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

- `src/animation/` — animation composition system: types, expression, action, rig config/factory, warrior rig, anim controller
- `src/squad-battle/` — combat engine: View/Presenter/Model (view.gd, presenter.gd, data.gd), entity, weapon, armor, clash, AI logic
- `src/strategy/core/` — world, scenario, faction, travel, triggerable system, shop, contact
- `src/strategy/core/sb-bridge/` — combat bridge and controller
- `src/strategy/ui/` — UI View/Presenter components (view.gd + presenter.gd per feature directory)
- `src/strategy/ui/stage/` — warrior stage: 2D viewport, camera, speech bubbles, march/VN mode switching
- `src/strategy/ui/vn/` — visual novel system (delegates display to stage)
- `src/strategy/ui/travel/` — travel menu
- `src/strategy/ui/investigation/` — investigation overlay
- `src/strategy/ui/recruitment/` — warrior recruitment
- `src/strategy/ui/manage_squad/` — squad roster
- `src/strategy/ui/shop/` — shop with cart UI
- `src/strategy/ui/scouting/` — scouting report overlay (progressive contact intel)
- `src/strategy/ui/missions/` — missions overlay (two-column: active/completed list + details/conditions/rewards)
- `src/strategy/ai/` — strategic AI (fleet manager, squad brain, considerations, glances, actions)
- `resources/ai/strategic/` — AI behavior .tres files (glances, considerations, actions, profiles)
- `resources/ai/faction/` — faction brain profiles
- `resources/generic-activities/` — Activity .tres files: rest, drill, travelling, patrol, investigate, attack, force-march, hold-mass, recruit, forage, heal, mercenary-work, buy-supplies
- `resources/scenarios/goetz-official/` — Main Goetz von Berlichingen campaign scenario. Missions in `missions/`, faction in `factions/`, event chains in `event-chains/`
- `resources/scenarios/ai-stress-test/` — Large 13-location stress test scenario for AI behavior observation
- `resources/animation/` — animation data files
  - `expressions/` — iExpression .tres (eye + mouth clip pairs)
  - `actions/` — AnimAction .tres (body clip + expression pairs)
  - `configs/` — WarriorRigConfig .tres (per-class textures)
- `src/character/` — character data classes
- `src/singletons/` — autoloaded event buses
- `resources/` — `.tres` files: scenarios, squads, warriors, events, activities, event chains
- `scenes/` — `.tscn` scene files; `scenes/demos/` for test scenes
  - `warrior_rig.tscn` — WarriorRig scene (Skeleton2D + Face + AnimPlayer + AnimTree + controller)
  - `speech_bubble.tscn` — SpeechBubble scene (PanelContainer with speaker name + text + tail)
