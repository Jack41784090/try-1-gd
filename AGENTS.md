# CONDOR — Agent Guide

This file is the single-source reference for AI coding agents working on the CONDOR project. It summarizes architecture, technology stack, build/test workflows, coding conventions, and agent behavior expectations. It is derived from `project.godot`, `try1.csproj`, `CLAUDE.md`, `.cursorrules`, `.github/instructions/*.md`, `.github/skills/condor-*/SKILL.md`, and the source tree. **Keep this file in sync with `CLAUDE.md`** — they describe the same project for different tools and must not drift apart.

For deep subsystem details, prefer the modular guidance files:

- `.github/instructions/combat.instructions.md` — `src/squad-battle/**`
- `.github/instructions/strategy.instructions.md` — `src/strategy/**`
- `.github/instructions/economy.instructions.md` — `src/economy/**`
- `.github/skills/condor-testing/SKILL.md` — test conventions and demo catalog
- `.github/skills/condor-play/SKILL.md` — interactive play, screenshots, canvas
- `.github/skills/condor-animation/SKILL.md` — rigs, animation, stage/VN, FX

Project root: `/home/ikec/Documents/Code/Godot/try-1-gd`.

## Project Overview

**CONDOR** is a squad-based narrative strategy game originally migrated from a Roblox/TypeScript codebase (`life-is-roblox`) to Godot. It combines:

- **Tactical turn-based combat** with squads, weapons, armour, AI logic, and a two-phase hit/pierce/damage resolution system.
- **Strategic real-time campaign** with an hour-based clock, location graph, travel, contacts, missions, and AI-driven factions.
- **Economy simulation** with demand/supply matching, trade caravans, population dynamics, government directives, guilds, and central banking.
- **2D anime SD character animation** using skeletal `WarriorRig`s with SVG textures, stage scenery, visual-novel cutscenes, and grimdark atmospheric FX.

## Technology Stack

- **Engine**: Godot 4.7 (`project.godot` features: `4.7`, `C#`, `Forward Plus`).
- **Primary language**: GDScript.
- **Secondary language**: C# via `try1.csproj` (`Godot.NET.Sdk/4.7.0`, `net8.0`, root namespace `Condor`).
- **Build tool**: `dotnet build` for the C# economy engine.
- **Runtime executables**:
  - `godot` — pure GDScript scenes.
  - `godot-mono` — scenes requiring the C# economy engine.
- **Asset pipeline**: Python 3 helper scripts in `tools/` generate SVG textures, scenery, rig art, sound, and cutscene resources.
- **Version control**: Git (`.gitignore` excludes `.godot/`, `temp/`, `log`, `addons/`, `.obsidian/`, `assets/hoi4_icons/`).

## Project Configuration Files

- `project.godot` — Godot settings, autoload singletons, display size (1920×1080), main scene (`scenario.tscn` via UID), custom theme.
- `try1.csproj` — C# project for the economy engine.
- `.editorconfig` — UTF-8 charset only.
- `CLAUDE.md` — detailed project guidance (keep in sync with architectural changes).
- `.cursorrules` / `.github/copilot-instructions.md` / `.github/instructions/*.md` / `.github/skills/**` — existing coding-agent guidance.
- `.vscode/settings.json`, `.vscode/launch.json`, `.vscode/mcp.json` — VS Code workspace settings, Godot launch config, and MCP screenshot server.

## Agent Behavior Guidelines

- **Verify before asserting**. Never assume, guess, or speculate. If context is insufficient, investigate with tools or ask.
- **Preserve existing code**. Do not remove unrelated functionality or structures. Make minimal, focused changes.
- **Single-chunk edits**. Provide all edits for one file in one go rather than multi-step instructions.
- **No apologies, no understanding feedback, no unnecessary confirmations**. Do not acknowledge understanding or ask the user to verify what is visible in context.
- **No invented changes**. Do not propose or implement anything beyond what is explicitly requested.
- **No summarization**. Do not summarize changes in prose unless the user asks.
- **Use real file paths**. Reference actual files, never placeholder names like `x.md`.
- **Check guidance files**. Before editing, consult the relevant `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, or scoped `.github/instructions/*.md`.

## Code Style Guidelines

### Class Hierarchy

- `RefCounted` — logic classes (non-serializable game logic).
- `Resource` — serializable data that should be saved/loaded or shown in the inspector.
- `Node` — scene-attached UI or runtime objects.

### GDScript Rules

- **Composition over inheritance**: prefer composing behavior from small resources/components (e.g. keyed `ReactiveStat` dictionaries) over deep subclass hierarchies. Reach for inheritance only when Godot's own architecture requires it (Node/Resource base types, `@tool` plugin hooks).
- **Fail-fast**: use `assert()` for requirements. No silent fallbacks, stubs, or speculative code.
- **Enums over strings**; use typed arrays: `Array[EntityUpdate]` instead of `Array`.
- **No comments** unless they are `##` doc comments or explain a complex algorithm.
- **One class per file**. Use factory classes with static `create_*()` methods — instantiate squads through `SquadDataFactory.create_squad(config)`.
- Do **not** use `preload` when you hit a "class not found" error; classes take time to register.
- Do **not** export `RefCounted` types.
- Do **not** use `class_name` for inner classes.
- `Resource.duplicate(true)` does **not** deep-copy external `.tres` sub-resources; explicitly duplicate nested resources when needed (e.g. `activity.result = activity.result.duplicate(true)`).
- **Never programmatically create GUI elements** — define them in `.tscn` files and reference via `@onready`.
- For bounded lists, prefer pre-built hidden nodes over runtime scene instantiation. Scene instantiation is only for unbounded/compositional needs.
- Each distinct UI component gets its own `.tscn` (item rows, contact bars, etc.).
- Custom-drawn `Control`s must also be `.tscn` scenes. Prefer SVG assets over runtime `_draw()`.

### Commit Message Format

```
<type>(<scope>): <subject>
```

**Types** (required): `feat` (new feature/gameplay behavior), `fix` (bug fix), `refactor` (restructure, no behavior change), `art` (SVG/texture/visual assets), `chore` (metadata, imports, configs, gitignore, build files), `test` (test scenes/scripts), `docs` (CLAUDE.md, AGENTS.md, inline documentation), `data` (`.tres`/`.tscn` resource or scene files only).

**Scopes** (optional, pick the most specific): `combat`, `strategy`, `economy`, `vn`, `animation`, `stage`, `rig`, `ai`, `ui`, `tools`.

**Subject rules**: imperative mood (`add X` not `added`), lowercase first letter, no trailing period, ≤ 72 chars total including type and scope.

Examples:
```
feat(vn): add EXPRESSION CharacterInstruction + VN/stage expression dispatch
art(rig): rebake warrior_rig_2.tscn with split EyeL/EyeR/Brows/HairBack overlay sprites
chore: add gitignores for SVG imports + Python cache
docs: update CLAUDE.md with face/expression system + add AGENTS.md
```

### File Operations

- **Never use `cat` heredocs** for GDScript files (tabs are stripped). Use Python `with open()` or dedicated file-editing helpers.
- **Mass renames** (many files/symbols across the tree): write a Python script to do it programmatically instead of editing occurrences one by one.
- Commit after each code update. Only add and commit your own changes.
- Sprint logging: after committing, append to `~/Documents/schwarzwagen/CONDOR/Development/Sprints/2026/Q<Q>/<Month>/W<N>.md`, under `## Commits`.

### Critical Pitfalls to Avoid

- **Typed array assignment**: never assign `Dictionary.get()` directly to typed arrays. Iterate and append with type checks.
- **Squad positions**: `Front = 1`, `Middle = 2`, `Back = 3` (not zero-indexed). Forward = -1, retreat = +1.
- **Entity updates**: all combat state changes return `EntityUpdate` containing `EntityChange`.
- **Never use `+=` on label text for state indicators** — store base text and rebuild (prevents `"[PAUSED][PAUSED]"`).
- **Single source of truth for time**: `GameClock` owns `world.current_hour`. Never overwrite it from `ActivityRunner` or other subsystems.
- **Unit conversion**: when changing time granularity (e.g., turns → hours), audit every hardcoded numeric constant in code and `.tres` files.
- **Wire up lifecycle methods**: if a method like `decay_clues()` exists, verify it is actually called.
- **Keep `src/` warning-clean**: avoid shadowing built-ins (`log`, `sign`), remove unused variables/signals/parameters, avoid enum sentinel ints like `-1`.

## Runtime Architecture

Godot autoload singletons (from `project.godot`):

- `StrategyEventBus` — `src/singletons/StrategyEventBus.gd`
- `StatusEffectEventBus` — `src/singletons/StatusEffectEventBus.gd`
- `DamageNumbersManager` — `src/singletons/DamageNumbersManager.gd`
- `SceneManager` — `scenes/scene_manager.tscn`
- `SFX` — `src/singletons/sfx.gd`
- `GrimdarkFX` — `scenes/grimdark_fx.tscn`

Main scene: `scenario.tscn`.

### Three-Layer Architecture

1. **Tactical Combat** (`src/squad-battle/`) — turn-based Model + View, coupled by signal
   - `SquadBattle` (`data.gd`) — Model (Resource): battle state, round logic. Owns `battle_completed(outcome)`, emitted once from `evaluate_outcome()` on the ONGOING→terminal transition. Held as a plain property on the View, never a scene child.
   - `SquadBattleView2D` (`view_2d.gd`) / `BattlefieldView2D` — round loop (`_start_battle()`/`_process_round()`), SubViewport + Camera2D, row containers (Front/Middle/Back). `all_updates`, `delay_between_rounds`, `request_retreat(team)`.
   - External consumers await `battle.battle_completed` — the owner of the event, not a View relay signal.
   - `BattleEntityDisplay` — wraps WarriorRig + HP bar + ORG icons.
   - Flow: `squad_actions() → choose_action() → OneClash.execute() → Array[EntityUpdate]`. All state changes produce immutable `EntityUpdate`/`EntityChange` objects.
   - `OneClash` (`clash/one_clash.gd`) — hit/pierce/damage resolution.
   - **RetreatTracker**: FIGHTING → RETREATING → LAST_STAND → CAPITULATED.
   - **Reality calculation**: table-driven via `CombatEntity._REALITY_TABLE` — `[base, op, terms]`.
   - `CombatEntity` data lives in `src/character/combat.gd`; social/campaign data in `src/character/social.gd`.
   - `CombatBridge` (`src/strategy/core/sb-bridge/combat_bridge.gd`) — stateless strategic↔tactical translation; CAPITULATE → `is_injured=true`.
   - `CombatController` (`control.gd`) — stateful; `CombatResult` includes `escaped_warriors`, `equipment_loot`.

2. **Strategic Campaign** (`src/strategy/`) — hour-based real-time, Paradox-style speed controls
   - `GameScenario` (`core/scenario.gd`) — orchestrator; `_setup_economy()` validates all locations.
   - `World` (`core/world.gd`) — location graph, roaming squads, `current_hour`, `is_paused`, `speed_multiplier`.
   - `GameClock` (`core/game_clock.gd`) — drives hour progression, emits `hour_ticked`. `pause()/unpause()/set_speed()`.
   - **Hourly tick**: `hour_ticked` → `StrategyPresenter._on_hour_tick()`. Economy every 24h.
   - **Activity toggle**: `SquadData.current_activity_type`. SPACE toggles pause (handled in `_input`, not `_unhandled_input`). Selecting an activity does **not** auto-unpause.
   - **Menu auto-pause**: opening any menu pauses the clock; closing does **not** auto-unpause.
   - `ActivityExecuteManager` (`ui/actor/!main.gd`) — `exec_before/activity/after()`. AI executors (`_IS_AI=true`) skip triggerables.
   - `ActivityHandler` base → `ActivityRegistry` maps `ActivityType` → handler (10 handlers + 5 pass-through).
   - **Travel**: km-based (`TownConnection.distance_km`), class-specific speeds (`EntityClasses.SPEED_TABLE`), `TravelGraph` distance-weighted A*. `SquadData.get_speed_kmh()` returns slowest warrior speed, ×0.5 for caravans.

3. **Economy** (`src/economy/`)
   - Heavy simulation runs in C# (`src/economy/csharp/`): `CsEconomyBridge`, `CsEconomyEngine`, populations, orders, government, guilds.
   - GDScript facade (`EconomyEngine`, `TradeMatcher`, `CaravanBridge`, `RouteDangerCalculator`) bridges the C# engine with the strategic world.
   - Economy ticks every 24 in-game hours.

### Supporting Systems

- **SFX** (`src/singletons/sfx.gd`): semantic play methods. Disabled headless.
- **GrimdarkFX** (`src/singletons/grimdark_fx.gd`): atmospheric shaders. Two layers: texture-based (bg/fg) + overlay (CanvasLayer 200). Disabled headless. Shaders in `assets/shaders/fx/`: `world_atmosphere`, `vignette`, `film_grain`, `damage_pulse`, `combat_atmosphere`.
- **UIAnimations** (`src/utils/ui_animations.gd`): static helper — `register_button()`, `show/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`, `pulse()`, `animate_label_number()`.
- **Log** (`src/singletons/log.gd`): `class_name Log`. Levels TRACE/DEBUG/INFO/WARN/ERROR. `Log.info("Source", "msg")`. Default: DEBUG.
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond font, `ThemeConstants` (`src/utils/theme_constants.gd`), multi-use styles via `theme_type_variation`, single-use overrides or standalone `.tres` in `resources/theme/styles/`.
- **Data models**: `SquadData` (`squad/social.gd`), `CombatSquad` (`squad/combat.gd`), `Warrior` (`character/social.gd`), `CombatEntity` (`character/combat.gd`).

## Detailed Subsystem Notes

### Animation System (`src/animation/`)

5-layer pipeline: Clips → iExpression → AnimAction → Behavior → `WarriorAnimController`.

**`WarriorRig` dual mode**:
- **Baked** (`warrior_rig_2.tscn`): `Sprite2D` per bone pre-authored; `apply_config()` updates in place; textured in editor — scrub `AnimPlayer` to see poses live. Regenerate: `godot --headless --path . --script res://tools/bake_rig_scene.gd`.
- **Legacy** (`warrior_rig.tscn`): spawns `top_level` Polygon2D placeholders synced each frame in `_process()`.

**Inspector-driven** (`@tool`): `config` export or `character_name`+`emotion` dropdowns (scanned from `assets/rig_textures/<name>/`). Baked rigs preview live in editor. `RigTextureLibrary` (`rig_texture_library.gd`): `build_config(name, emotion, base=null)`, `apply_textures()`.

**Facial expressions (texture-swap, NOT animated)**:
- `Face` node under `Head` bone: `EyeL`, `EyeR`, `Mouth`, `Brows`, `HairBack` sprites.
- `iExpression` (`expression.gd`): per-feature `Texture2D`s; `null` = leave unchanged.
- `WarriorRig.set_expression(expr)` / `set_expression_by_name(id)`.
- `FaceBlend` disconnected from AnimTree output — animations cannot override expressions.
- **Gotcha**: `default_expression` re-applies at end of `_apply_config_internal` — null it to prevent snapping back to neutral.
- Expression `.tres` in `resources/animation/expressions/<character>/`.

**SVG art pipeline**:
- Source heads: `assets/rig_textures/<name>/_head.svg` → bake: `python3 tools/bake_svg_clips.py` (resolves `<use>` in `<clipPath>`, flattens nested transforms).
- Face split: `tools/export_face_features.py` emits `face/{eye_l,eye_r,mouth,brows,head_base,hair_back}_<emotion>.svg` per emotion sub-group in Inkscape "Face" layer. Run automatically by `bake_svg_clips.py`. To add emotion: author same-named sub-group in feature groups + re-bake.
- **Art style**: 2D anime SD, clean 2px outlines, solid fills, no gradients, 1:2.5 head-body ratio, 3/4 right-facing (big eye LEFT, small eye RIGHT). Z-order: Right* behind, Left* in front.
- Generator: `python3 tools/generate_sd_svgs.py`.

**Animation style**: idle 2s breathe, walk 1s heavy stride, attack 0.9s explosive, defend 0.7s bracing, hurt 0.6s stagger, die 1.5s collapse+fade, talk 1.6s gestures, gesture 1s flourish.

**Warrior Stage** (`src/strategy/ui/stage/`): `StageView`+`StagePresenter`. Modes: MARCH/VN/HIDDEN. `SpeechBubble` typewriter, `StageCamera` tween-based.

**Stage Scenery**: `StageProp`+`StageSet` Resources. `StageView.apply_stage_set()` builds `Sprite2D` per prop via `SvgLoader`. Per-prop: `svg_path`, `position`, `scale`, `z_index`, `flip_h`, `modulate`, `parallax` (<1 = slower parallax drift). Assets in `assets/scenery/`. Example: `resources/stage_sets/parliament_chamber.tres`.

### Visual Novel (`src/strategy/ui/vn/`)

- `VnPresenter` stage-aware; `EventChain` triggers via `event_chain_path` in results.
- `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate).
- `CharacterInstruction` actions: MOVE/FACE/BEHAVIOR/SPAWN/SHOW/HIDE/**EXPRESSION**.
  - `EXPRESSION` → `StagePresenter.set_character_expression()` → `WarriorRig.set_expression_by_name()`.
  - BEHAVIOR + EXPRESSION in the same parallel group = simultaneous animation + face swap.
- `SceneryInstruction`: ADD/REMOVE/MOVE/MODULATE/SHOW/HIDE/SET_BACKDROP during playback.
- `CinematicGroup`/`CinematicInstruction` `@export` all fields → round-trips as `.tres` cutscene (no EventChain needed).

### Strategic AI (`src/strategy/ai/`)

- Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as `.tres` in `resources/ai/strategic/`.
- `AISquadManager` (public API `AIFleetManager`) — `prepare_ai_turns()`, `cleanup_defeated_squads()`, `tick_bandit_lifecycle(faction)`, `register_squad(squad, profile_path="")`.
- Three profiles: aggressive-hunter, balanced-roamer (default), cautious-survivor.
- `StrategicSituation` — lazy BFS snapshot; enemies require SUSPECTED+ contact.
- `StrategicAction._get_next_hop()` resolves travel destinations to adjacent hops via `TravelGraph` pathfinding. Force march moves 2 hops per turn (double speed), using `Activity.ultimate_destination_id` for the second hop.

### Activity System

- Activities (REST, PATROL, DRILL, etc.) are persistent state on `SquadData.current_activity_type`. Player toggles; clock runs automatically.
- REST is default. Active buttons show `[ACTIVE]` text + green modulate tint.
- Activities in `resources/generic-activities/`: rest, drill, travelling, patrol, investigate, attack, force-march, hold-mass, recruit, forage, heal, mercenary-work, buy-supplies.
- `ActivityType` enum: REST=0 through CUSTOM=12, HEAL=13, BUY_SUPPLIES=14.
- Execution in `Activity._execute_generic()` dispatches to `_execute_forage()`, `_execute_heal()`, `_execute_buy_supplies()`, `_execute_mercenary_work()`, etc.
- Forage yields food by location type: VILLAGE 2-4, ROAD/FORT 1-2, TOWN 0-1, CITY 0.
- Heal costs 10 gold per injured warrior, cures `is_injured` + morale boost.
- Mercenary work: probabilistic combat against 2-4 monsters, money per kill, risk of injury.
- Buy supplies: purchases up to 5 food from the location's shop.

### Contact System (`src/strategy/core/contact/`)

- HOI4-inspired: gradual awareness 0-100 → NONE/SUSPECTED/TRACKED/LOCKED. ATTACK requires LOCKED.
- Spotting: `BASE_SPOTTING_RATE * proximity * (scouting/(scouting+stealth)) * size_factor`. MERCHANT has 0.3× stealth.
- Proximity: SAME_LOCATION(1.0), SAME_EDGE(0.7), ADJACENT(0.3). Activity modifiers: PATROL 1.5× scouting, REST 1.3× stealth.
- Engagement types: AMBUSH / SET_PIECE / MEETING.
- `ScoutingFocus` lets the player configure role/class targeting and coordination multipliers.
- `World.contact_tracker` lazily loaded via `load()` to avoid class-not-found parse errors.

### Economy Deep Dive (`src/economy/`)

- **C# mandatory**: `CsEconomyEngine` via `CsEconomyBridge`; GDScript `EconomyEngine` is a thin facade. Build with `dotnet build`; run with `godot-mono`.
- **Trade pipeline**: GDScript precomputes an N×N `danger_matrix` via `RouteDangerCalculator`, then calls `CsEconomyBridge.Tick(turn, danger_matrix)`.
- C# mega-loop phases (PHASE B per location): spoil → prices → orders → produce → subsist → match-orders → contracts → market → household → rent → gov → guild → pop state → geist → snapshot.
- PHASE D: internal trade matcher using the danger matrix, `(margin * 0.4 + urgency * 0.6) * safety`, creating `EconomyMove`s and `CsShipmentDispatch`es. `StrategyPresenter._run_economy_tick()` materializes dispatches as MERCHANT squads via `CaravanBridge`.
- `EconomyEngine.tick_full()` calls `engine.sync_full()` after each tick (person money/satisfaction/class sync).
- **PersonBrain System**: `PersonBrain` / `NobleBrain` (loan scoring) / `CommonBrain` (singleton no-op). `PhasePersonDecisions` runs all brains at tick start.
- **Gradual Pricing**: `PhasePriceUpdate` adjusts prices incrementally, max 15%/tick, with goods-specific stickiness (food 1.2×, weapons 0.6×, luxury 0.5×).
- **Scarcity Markup**: `PhaseMarket` applies quadratic scarcity markup up to 50% as stock depletes; wealthiest buyers purchase at base price first.
- **Market revenue**: 85% to producers, 15% merchant commission. Money-conserving.
- **Food spoilage**: 5% per turn via `PhaseSpoilage`.
- **Population sync**: `SyncBackToGdScript()` matches by `PersonId`; `Population.remove_person()` handles death sync.
- **Bank metrics**: `engine.get_bank_info()` reads C# `CsCentralBank` state.
- **Government** (`CsGovernment`): 3 phases — GovernmentTax, GovernmentPlan (HireWorkers directives), GovernmentExecute. `GovernmentConfig` Resource on `Location`.
- **Guilds** (`CsGuild`): 2 phases — PhaseGuildRecruit, PhaseGuildProduce. `GuildConfig` Resource on `Location`. First guild: Nürnberg Smithing (swords from 2 iron + 1 wood), 10% commission.

### Caravan & Bandit Systems

- `CaravanBridge` (`caravan_bridge.gd`) materializes C# trade dispatches as MERCHANT squads. Caravans use `SquadBrain` with the `caravan-courier` profile.
- `BanditSpawner` (`bandit_spawner.gd`) calculates pressure from population satisfaction + peasant ratio and spawns BANDIT squads (desperation-driven). Brain: `bandit-raider.tres`.
- `RouteDangerCalculator` applies 1.5× threat for BANDIT role.
- `MercenaryDemandCalculator` (`mercenary_demand.gd`) dynamically adds/removes MERCENARY_WORK based on trade loss vs hire cost.
- Bandit lifecycle: pressure → spawn → roam → attack merchants → disband. `AISquadManager.tick_bandit_lifecycle(faction)` runs each economy tick.

### UI Pattern (`src/strategy/ui/`) — View/Presenter MVP

- View calls `presenter.on_X()`; Presenter calls `view.update_X()`.
- `StrategyView`/`StrategyPresenter` — top-level, orchestrators: `CombatOrchestrator`, `ContactOrchestrator`. Unified tick in `_on_hour_tick()`.
- `TravelView`/`Presenter` — AUTOPILOT/MANUAL/GOING states.
- `ShopView`/`Presenter` — cart system with `LocationInventory`.
- `ScoutingView`/`Presenter` — hover slide-in from left edge.
- `SquadLogView` (`squad_log/view.gd`) — right-side slide-in chatbox, unread badge.
- `MissionsView`/`Presenter` — active/completed list + details.
- `MarketView`/`Presenter` — prices, production, population, trade rumors.
- `ManageSquadPage`/`Presenter` — Tactics/Units/Formation/Recruitment/Inventory tabs.
- `CombatUI` (`combat_ui.gd`) is a `RefCounted` helper factory for combat display.

### Key Enums

- Classes: `src/character/entity_classes.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter.
- Weapons: `src/squad-battle/weapon/_factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire.
- Armor: `src/squad-battle/armor/_factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate.
- Combat: `src/squad-battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome.
- Strategy: `src/strategy/types.gd` — LocationType, ActivityType, ContactState, EngagementType, SquadRole.
- Economy: `src/economy/types.gd` — SocialClass, JobType, MoveState, ThingType, DirectiveType.
- Animation: `src/animation/types.gd` — `AnimTypes.Behavior` (IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING).

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

Pierce: physical (Force+Precision vs armor PV) or magical (Mana+Spirituality vs magical PV). `OneClash.roll_for_pierce()` auto-branches on `is_magical`.

## Code Organization

```
src/
├── animation/          # WarriorRig, configs, actions, expressions, controller
├── character/          # Warrior social/combat data, classes, skills, backgrounds
├── demos/              # Demo/test scripts (ai_act_demo, headless_strategy_view, etc.)
├── economy/            # Economy engine (GDScript + C#), trade, caravans, population
├── singletons/         # Autoloads: event buses, SFX, Log, GrimdarkFX logic
├── squad/              # SquadData, CombatSquad, CargoManifest, factories
├── squad-battle/       # Tactical combat model/presenter/view, entities, weapons, armour
└── strategy/           # Campaign: core, ai, ui (views/presenters), activity, contact

resources/
├── ai/                 # Faction and strategic AI .tres profiles
├── animation/          # Actions, expressions, rig configs
├── character/          # Backgrounds
├── combat/             # Weapon/armour/class/logic .tres resources
├── event_chains/       # VN/cutscene event chains
├── generic-activities/ # Activity .tres definitions
├── generic-events/     # Game event .tres definitions
├── jsons/              # JSON data
├── scenarios/          # Campaign scenarios (goetz-official is the main one)
├── stage_sets/         # Stage scenery bundles
└── theme/              # condor_theme.tres and style boxes

scenes/
├── demos/              # All demo/test scenes
├── ui/                 # UI scene components
├── main.tscn
├── scenario.tscn       # Main game scene
└── ...

assets/
├── box_styles/         # UI box style textures
├── fonts/              # EB Garamond and other fonts
├── icons/
├── rig_textures/       # Per-class SVG bone textures
├── scenery/            # Backdrop/prop SVGs
├── sfx/                # Sound effects
└── shaders/            # FX and canvas shaders

tools/                  # Python/bash helper scripts for assets, play, canvas, sound
```

## Build and Test Commands

### Build the C# Economy Engine

```bash
dotnet build
```

Run this before testing any scene that uses the economy engine (most `godot-mono` scenes below).

### Run the Main Game

In the Godot editor:

- Open the project.
- Press **F5** to run `scenario.tscn`.

From command line:

```bash
godot-mono --path .
```

### Run Demo / Test Scenes

Most demos live in `scenes/demos/` and can be run with **F6** in the editor, or headlessly from the terminal (`godot --headless --path . scenes/demos/<name>.tscn`).

| Scene | Purpose |
|-------|---------|
| `combat_controller_test.tscn`, `combat_strategy_integration_test.tscn`, `scenario_attack_test.tscn` | Combat tests |
| `ai_runner_demo.tscn` | AI brain decisions |
| `ai_battle_royale_demo.tscn` | Fleet simulation with headless combat |
| `ai_stress_test_demo.tscn` | 50-turn stress test |
| `pause_system_test.tscn` | Pause/unpause/menu auto-pause (headless ok) |
| `squad_battle_2d_demo.tscn` | 2D WarriorRig battle |
| `animation_test.tscn` | `warrior_rig_2` harness; keys `1-8`/`←→` cycle behaviors, `R` replay, `E` cycle expressions; live texture hot-reload (0.4s poll) |
| `stage_demo.tscn` | Warrior stage, march, speech bubbles, camera |
| `dialogue_demo.tscn` | Dialogue system (headless ok) |
| `ranged_combat_demo.tscn`, `aoe_combat_demo.tscn` | Ranged/AoE combat |
| `cinematic_instruction_demo.tscn` | GroupPlayback/CinematicGroup chains (headless only) |
| `cutscene_parliament.tscn` | Faust Ch.1 parliament scene; regenerate via `python3 tools/build_parliament_cutscene.py` |
| `ai_act_demo.tscn` | Scripted AI activity assertions (`godot-mono` required for economy tests) |
| `economy_demo.tscn`, `economy_stress_test.tscn` | Economy pipeline (use `godot-mono`) |
| `caravan_demo.tscn`, `bandit_demo.tscn` | Caravan/bandit systems |
| `contact_system_test.tscn`, `government_test.tscn`, `guild_test.tscn` | Unit tests |
| `reactive_stat_ui_test.tscn` | ReactiveStat → units_panel/unit_item UI wiring regression test (headless ok) |
| `interactive_demo.tscn` | Terminal game (stdin commands) |
| `canvas_demo.tscn` | SVG drawing canvas — start via `bash tools/start_canvas.sh [session]` |

Examples:

```bash
godot --headless --path . scenes/demos/pause_system_test.tscn
godot --headless --path . scenes/demos/contact_system_test.tscn
godot --headless --path . scenes/demos/dialogue_demo.tscn
godot-mono --headless --path . scenes/demos/economy_stress_test.tscn
godot-mono --headless --path . scenes/demos/government_test.tscn
godot-mono --headless --path . scenes/demos/guild_test.tscn
```

Run the relevant demo tests after logic changes.

### Sound Generation

```bash
python3 tools/sound_designer.py --list
python3 tools/sound_designer.py --preset <name> --format wav|mp3|ogg
```

### Hyprland

Any GUI Godot window (editor, `--gui` runs, `start_canvas.sh`) auto-routes to workspace 10 without stealing focus, via silent windowrules on class `Godot`/`try1` in `~/.config/hypr/userprefs.conf`. Launcher: `godot-ws` (`~/.local/bin`).

## Interactive AI Play & Canvas

`tools/play.sh` auto-starts a per-session game instance and sends commands via named pipes.

```bash
bash tools/play.sh "status"
bash tools/play.sh "travel oehringen" 15
bash tools/play.sh "rest" 6

# GUI mode (required for screenshots)
bash tools/play.sh "screenshot" --gui

# Stop the session's game
CONDOR_SESSION=<id> bash tools/play.sh --stop
```

Sessions are isolated via `CONDOR_SESSION`. If unset, an ID is auto-generated. Pipes: `/tmp/condor_{input,output,pid}_<session>`.

GOD commands: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`.

### Canvas / Rig Drawing Sandbox

```bash
bash tools/start_canvas.sh [session_id]
CONDOR_SESSION=<id> bash tools/play.sh "info"
CONDOR_SESSION=<id> bash tools/play.sh "rig landsknecht"
CONDOR_SESSION=<id> bash tools/play.sh "anim idle"
```

Camera: `zoom 3.0`, `zoom_in`, `zoom_out`, `pan 500 300`, `center`. Other: `grid`, `bg #1a1a2e`, `tree`, `sizes`, `shader <node> <param> <value>`.

SVG viewBox sizes (×4): Head=176×200, Torso=136×112, Hips=112×32, Arm=40×88, Forearm=32×72, Hand=56×56, Leg=48×104, Shin=40×88, Foot=80×40.

### Asset Generation Helpers

```bash
python3 tools/generate_sd_svgs.py      # rig textures
python3 tools/generate_scenery_svgs.py # scenery SVGs
python3 tools/bake_svg_clips.py        # fix clipPaths in hand-authored SVGs
python3 tools/generate_rig_textures.py # rig texture batch
python3 tools/sound_designer.py        # procedural SFX
python3 tools/build_parliament_cutscene.py # regenerate cutscene resource
```

## Testing Instructions

### Use the Real Game Pipeline

All demo/test scenes **must** use `HeadlessStrategyView` + `StrategyPresenter`, the same path as the real game. Do not hand-build `World`, `EconomyEngine`, or `Population` in tests.

Canonical setup:

```gdscript
const SCENARIO_PATH := "res://resources/scenarios/goetz-official/scenario.tres"
const HeadlessView = preload("res://src/demos/headless_strategy_view.gd")

var presenter: StrategyPresenter

func _ready():
    var mock_view = HeadlessView.new()
    add_child(mock_view)
    mock_view.setup_headless()

    presenter = StrategyPresenter.new()
    presenter.scenario_path = SCENARIO_PATH
    presenter.is_demo_scenario = false
    mock_view.add_child(presenter)

    await presenter.bind_view(mock_view)

    # Drive time:
    presenter.game_clock.force_tick()
    await presenter.tick_completed
```

`GameScenario._setup_economy()` initializes population, natural resources, government config, and the economy engine from the real scenario. `force_tick()` runs the full hourly pipeline: AI turns, world systems, contacts, activities, missions, and economy every 24 hours.

Hand-built tests bypass `TradeMatcher`, `EconomyEngine.tick_full`, `CaravanBridge`, `GovernmentDirectives`, and the contact system — they test a different game.

## Security Considerations

- The project runs external processes (`godot`, `godot-mono`) from helper scripts in `tools/`. `tools/play.sh` and `tools/start_game.sh` launch detached game instances using `nohup`/`setsid` and write/read named pipes under `/tmp/condor_*_<session>`.
- `tools/mcp-screenshot/server.py` provides an MCP server that can start its own game instance and take screenshots.
- These scripts are intended for local development only; do not expose them to untrusted inputs or network-facing services.
- No hardcoded credentials or secrets are present in tracked files (sensitive files like `.env` are ignored by default).
- Python helper scripts operate only on project assets; they do not download or execute remote code.

## Documentation Sync

When you change architecture, runtime flow, data contracts, or behavior, keep the existing guidance files consistent:

- `AGENTS.md` (this file)
- `CLAUDE.md` (main project guidance)
- `.github/copilot-instructions.md`
- `.github/instructions/combat.instructions.md` — for `src/squad-battle/**`
- `.github/instructions/strategy.instructions.md` — for `src/strategy/**`
- `.github/instructions/economy.instructions.md` — for `src/economy/**`
- `.github/skills/condor-testing/SKILL.md` — testing conventions
- `.github/skills/condor-play/SKILL.md` — interactive play
- `.github/skills/condor-animation/SKILL.md` — animation/VN/FX

The project also maintains Obsidian architecture notes under `/home/ikec/Documents/schwarzwagen/CONDOR/Systems/`. Subsystem mappings:

- `src/strategy/**` → `Systems/Core/`, `Systems/Activities/`, `Systems/AI/`, `Systems/Contact/`, `Systems/Runtime/`, `Systems/UI/`, `Systems/Data/Strategy Types.md`
- `src/squad-battle/**` and combat bridge → `Systems/Combat/`, `Systems/Data/Combat Types.md`, `Systems/Runtime/Combat Flow.md`
- `src/economy/**` → `Systems/Economy/`, `Systems/Runtime/Economy Tick 24h.md`

## Useful References

- Main scenario: `resources/scenarios/goetz-official/scenario.tres`
- Main theme: `resources/theme/condor_theme.tres`
- Unit classes: `src/character/entity_classes.gd`
- Combat types: `src/squad-battle/types.gd`
- Strategy types: `src/strategy/types.gd`
- Economy types: `src/economy/types.gd`
- Animation types: `src/animation/types.gd`
- Log singleton: `src/singletons/log.gd`
- AI profiles: `resources/ai/strategic/`
- Activity definitions: `resources/generic-activities/`
- Stage sets: `resources/stage_sets/`
