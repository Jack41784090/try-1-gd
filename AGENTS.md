# CONDOR — Agent Guide

This file is the single-source reference for AI coding agents working on the CONDOR project. It summarizes architecture, technology stack, build/test workflows, coding conventions, and agent behavior expectations. It is derived from `project.godot`, `try1.csproj`, `CLAUDE.md`, `.cursorrules`, `.github/instructions/*.md`, `.github/skills/condor-*/SKILL.md`, and the source tree.

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

- **Engine**: Godot 4.6 (`project.godot` features: `4.6`, `C#`, `Forward Plus`).
- **Primary language**: GDScript.
- **Secondary language**: C# via `try1.csproj` (`Godot.NET.Sdk/4.6.2`, `net8.0`, root namespace `Condor`).
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

- **Fail-fast**: use `assert()` for requirements. No silent fallbacks, stubs, or speculative code.
- **Enums over strings**; use typed arrays: `Array[EntityUpdate]` instead of `Array`.
- **No comments** unless they are `##` doc comments or explain a complex algorithm.
- **One class per file**. Use factory classes with static `create_*()` methods.
- Do **not** use `preload` when you hit a "class not found" error; classes take time to register.
- Do **not** export `RefCounted` types.
- Do **not** use `class_name` for inner classes.
- `Resource.duplicate(true)` does **not** deep-copy external `.tres` sub-resources; explicitly duplicate nested resources when needed.
- **Never programmatically create GUI elements** — define them in `.tscn` files and reference via `@onready`.
- For bounded lists, prefer pre-built hidden nodes over runtime scene instantiation. Scene instantiation is only for unbounded/compositional needs.
- Each distinct UI component gets its own `.tscn` (item rows, contact bars, etc.).
- Custom-drawn `Control`s must also be `.tscn` scenes. Prefer SVG assets over runtime `_draw()`.

### File Operations

- **Never use `cat` heredocs** for GDScript files (tabs are stripped). Use Python `with open()` or dedicated file-editing helpers.
- Commit after each code update. Only add and commit your own changes.
- Sprint logging: after committing, append a commit summary to the current week's sprint file under `~/Documents/schwarzwagen/CONDOR/Sprints/...`.

### Critical Pitfalls to Avoid

- **Typed array assignment**: never assign `Dictionary.get()` directly to typed arrays. Iterate and append with type checks.
- **Squad positions**: `Front = 1`, `Middle = 2`, `Back = 3` (not zero-indexed). Forward = -1, retreat = +1.
- **Entity updates**: all combat state changes return `EntityUpdate` containing `EntityChange`.
- **Never use `+=` on label text for state indicators** — store base text and rebuild.
- **Single source of truth for time**: `GameClock` owns `world.current_hour`. Only one place should emit `hour_advanced`.
- **Unit conversion**: when changing time granularity (e.g., days → hours), audit every hardcoded numeric constant in code and `.tres` files.
- **Wire up lifecycle methods**: if a method like `decay_clues()` exists, verify it is actually called.
- **Keep `src/` warning-clean**: avoid shadowing built-ins, remove unused variables/signals/parameters, avoid enum sentinel ints like `-1`.

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

1. **Tactical Combat** (`src/squad-battle/`)
   - `SquadBattle` (`data.gd`) — Model holding battle state and round logic.
   - `SquadBattlePresenter` (`presenter.gd`) — Round loop, victory checks, `battle_completed` signal.
   - `SquadBattleView2D` (`view_2d.gd`) / `BattlefieldView2D` (`battlefield_view.gd`) — 2D WarriorRig-based visuals.
   - `OneClash` (`clash/one_clash.gd`) — Hit/pierce/damage resolution.
   - `CombatEntity` data lives in `src/character/combat.gd`; social/campaign data in `src/character/social.gd`.
   - `CombatBridge` / `CombatController` (`src/strategy/core/sb-bridge/`) translate strategic↔tactical state.

2. **Strategic Campaign** (`src/strategy/`)
   - `GameScenario` (`core/scenario.gd`) — Main orchestrator; initializes economy, factions, world.
   - `World` (`core/world.gd`) — Location graph, roaming squads, `current_hour`, pause/speed state.
   - `GameClock` (`core/game_clock.gd`) — Drives real-time hour progression; emits `hour_ticked`.
   - `StrategyPresenter` / `StrategyView` (`ui/` + `ui/actor/`) — MVP pattern; player and AI activity execution.
   - `AISquadManager` / `SquadBrain` (`ai/`) — Data-driven consideration scoring for AI squads.
   - `ContactTracker` (`core/contact/`) — HOI4-inspired awareness levels (NONE → SUSPECTED → TRACKED → LOCKED).
   - `TriggerableManager` (`core/triggerable/`) — unified base for GameEvent, Mission, Ending.

3. **Economy** (`src/economy/`)
   - Heavy simulation runs in C# (`src/economy/csharp/`): `CsEconomyBridge`, `CsEconomyEngine`, populations, orders, government, guilds.
   - GDScript facade (`EconomyEngine`, `TradeMatcher`, `CaravanBridge`, `RouteDangerCalculator`) bridges the C# engine with the strategic world.
   - Economy ticks every 24 in-game hours.

### Supporting Systems

- **Animation** (`src/animation/`): 5-layer pipeline Clips → iExpression → AnimAction → Behavior → `WarriorAnimController`. `WarriorRig` generates skeletal sprites; `WarriorRigConfig` swaps SVG textures. `AnimTypes.Behavior`: IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING.
- **Stage / VN** (`src/strategy/ui/stage/`, `src/strategy/ui/vn/`): Shared 2D viewport, speech bubbles, `GroupPlayback`/`CinematicGroup` cutscenes, scenery props. `StageView` modes: MARCH / VN / HIDDEN.
- **SFX / GrimdarkFX** (`src/singletons/sfx.gd`, `src/singletons/grimdark_fx.gd`, `assets/shaders/fx/`): Atmospheric shaders (world_atmosphere, vignette, film_grain, damage_pulse, combat_atmosphere), disabled in headless mode.
- **UIAnimations** (`src/utils/ui_animations.gd`): static helper for button registration, overlays, panels, tweens, number animations.
- **Logging** (`src/singletons/log.gd`): Static `Log` class with TRACE/DEBUG/INFO/WARN/ERROR levels.
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond font, multi-use styles via `theme_type_variation`, single-use overrides or standalone `.tres` in `resources/theme/styles/`.

## Detailed Subsystem Notes

### Activity System

- Activities (REST, PATROL, DRILL, etc.) are persistent state on `SquadData.current_activity_type`. Player toggles; clock runs automatically.
- REST is default. Active buttons show `[ACTIVE]` text + green modulate tint.
- **SPACE** toggles pause (handled in `_input`, not `_unhandled_input`). Selecting an activity does **not** auto-unpause.
- **Menu auto-pause**: opening any menu pauses the clock; closing does **not** auto-unpause.
- `ActivityExecuteManager` (`ui/actor/!main.gd`) provides shared `exec_before/activity/after()` execution. AI executors (`_IS_AI=true`) skip triggerables.
- Activity handlers live in `core/activity/` — `ActivityHandler` base + `ActivityRegistry` maps `ActivityType` → handler.

### Travel System

- km-based edge distances (`TownConnection.distance_km`) and class-specific speeds (`EntityClasses.SPEED_TABLE`).
- `SquadData.get_speed_kmh()` returns slowest warrior speed, ×0.5 for caravans.
- Travel progress tracked on `SquadData`: `travel_progress_km`, `travel_route`, `travel_segment_index`.
- `TravelGraph` uses distance-weighted A*.

### Contact System

- Gradual awareness 0–100 → NONE / SUSPECTED / TRACKED / LOCKED.
- Spotting = `BASE_SPOTTING_RATE * proximity * (scouting/(scouting+stealth)) * size_factor`. MERCHANT has 0.3× stealth.
- Proximity: SAME_LOCATION(1.0), SAME_EDGE(0.7), ADJACENT(0.3).
- Activity modifiers: PATROL 1.5× scouting, REST 1.3× stealth.
- ATTACK requires LOCKED contact. Engagement types: AMBUSH / SET_PIECE / MEETING.
- `ScoutingFocus` lets the player configure role/class targeting and coordination multipliers.

### Economy Deep Dive

- **C# mandatory**: `CsEconomyEngine` via `CsEconomyBridge`; GDScript `EconomyEngine` is a thin facade. Build with `dotnet build`; run with `godot-mono`.
- **Trade pipeline**: GDScript precomputes an N×N `danger_matrix` via `RouteDangerCalculator`, then calls `CsEconomyBridge.Tick(turn, danger_matrix)`. C# runs per-location phases and internal trade matching using `(margin * 0.4 + urgency * 0.6) * safety`, creating `EconomyMove`s and `CsShipmentDispatch`es. `StrategyPresenter._run_economy_tick()` materializes dispatches as MERCHANT squads via `CaravanBridge`.
- **PersonBrain System**: `PersonBrain` / `NobleBrain` / `CommonBrain`. `PhasePersonDecisions` runs all brains at tick start. `NobleBrain` scores loan applications; `CommonBrain` is a shared no-op for non-nobles.
- **Gradual Pricing**: `PhasePriceUpdate` adjusts prices incrementally (max 15%/tick) with goods-specific stickiness (food 1.2×, weapons 0.6×, luxury 0.5×).
- **Scarcity Markup**: `PhaseMarket` applies quadratic scarcity markup up to 50% as stock depletes; wealthy buyers purchase at base price first.
- **Market revenue**: 85% to producers, 15% merchant commission. Money-conserving.
- **Food spoilage**: 5% per turn via `PhaseSpoilage`.
- **Population sync**: `SyncBackToGdScript()` matches by `PersonId`; `Population.remove_person()` handles death sync.
- **Bank metrics**: `engine.get_bank_info()` reads C# `CsCentralBank` state.
- **Government Directives**: `CsGovernment` / `CsDirective` / `GovernmentBrain` — tax, plan, execute HireWorkers directives. Config via `GovernmentConfig` Resource on `Location`.
- **Guild System**: `CsGuild` / `GuildBrain` / `GuildConfig` — recruit workers, consume inputs, produce goods, collect 10% commission. First guild: Nürnberg Smithing Guild.

### Caravan & Bandit Systems

- `CaravanBridge` materializes C# trade dispatches as MERCHANT squads. Caravans use `SquadBrain` with the `caravan-courier` profile.
- `BanditSpawner` (`src/strategy/ai/bandit_spawner.gd`) calculates pressure from population satisfaction + peasant ratio and spawns BANDIT squads.
- `RouteDangerCalculator` applies 1.5× threat for BANDIT role.
- `MercenaryDemandCalculator` dynamically adds/removes MERCENARY_WORK based on trade loss vs hire cost.
- Bandit lifecycle: pressure → spawn → roam → attack merchants → disband. `AISquadManager.tick_bandit_lifecycle(faction)` runs each economy tick.

### UI Pattern

- View/Presenter MVP: View calls `presenter.on_X()`; Presenter calls `view.update_X()`.
- Top-level: `StrategyView` / `StrategyPresenter` with `CombatOrchestrator` and `ContactOrchestrator`.
- Notable views: Travel, Shop, Scouting, SquadLog, Missions, Market, ManageSquad.
- `CombatUI` (`combat_ui.gd`) is a `RefCounted` helper factory for combat display.

### Animation & Visual Style

- 2D anime SD flat vector: clean 2px black outlines, solid fills, no gradients, 1:2.5 head-to-body ratio, 3/4 right-facing profile.
- SVG textures in `assets/rig_textures/<class>/`; generator: `python3 tools/generate_sd_svgs.py`.
- `StageSet` / `StageProp` bundle backdrops and props. Scenery uses `SvgLoader.load_svg()`.
- `GroupPlayback` processes `CinematicGroup` trees (sequential/parallel/auto-gate) for VN/cutscenes.
- GrimdarkFX shaders: world_atmosphere, vignette, film_grain, damage_pulse, combat_atmosphere.

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

Most demos live in `scenes/demos/` and can be run with **F6** in the editor, or headlessly from the terminal.

#### GDScript-only (`godot`)

| Scene | Purpose |
|-------|---------|
| `pause_system_test.tscn` | Pause/menu auto-pause tests |
| `ai_act_demo.tscn` | Scripted AI activity assertions |
| `economy_demo.tscn` | 3-location economy simulation |
| `caravan_demo.tscn` | Economy → strategy caravan bridge |
| `contact_system_test.tscn` | Contact system unit tests (40 assertions) |
| `dialogue_demo.tscn` | Dialogue system (typewriter, interrupts) |

```bash
godot --headless --path . scenes/demos/pause_system_test.tscn
godot --headless --path . scenes/demos/ai_act_demo.tscn
godot --headless --path . scenes/demos/economy_demo.tscn
godot --headless --path . scenes/demos/caravan_demo.tscn
godot --headless --path . scenes/demos/contact_system_test.tscn
godot --headless --path . scenes/demos/dialogue_demo.tscn
```

#### C# required (`godot-mono`)

| Scene | Purpose |
|-------|---------|
| `economy_stress_test.tscn` | 50-turn economy stress test |
| `government_test.tscn` | Government directive tests (40 assertions) |
| `guild_test.tscn` | Guild system tests (10 tests) |
| `interactive_demo.tscn` | Terminal game |
| `bandit_demo.tscn` | Bandit spawning/lifecycle tests |

```bash
godot-mono --headless --path . scenes/demos/economy_stress_test.tscn
godot-mono --headless --path . scenes/demos/government_test.tscn
godot-mono --headless --path . scenes/demos/guild_test.tscn
godot-mono --headless --path . scenes/demos/interactive_demo.tscn
godot-mono --headless --path . scenes/demos/bandit_demo.tscn
```

#### Editor-only / visual (`F6`)

| Scene | Purpose |
|-------|---------|
| `combat_controller_test.tscn` | Combat system tests |
| `combat_strategy_integration_test.tscn` | Combat↔strategy bridge |
| `scenario_attack_test.tscn` | Scenario attack flow |
| `ai_runner_demo.tscn` | AI squad brain decisions |
| `ai_battle_royale_demo.tscn` | Fleet simulation with headless combat |
| `ai_stress_test_demo.tscn` | 13-location, 8-squad, 50-turn stress test |
| `squad_battle_2d_demo.tscn` | 2D WarriorRig battle |
| `stage_demo.tscn` | Warrior stage, march, speech bubbles |
| `ranged_combat_demo.tscn` | Ranged targeting, suppression, reach |
| `aoe_combat_demo.tscn` | Splash damage, magical pierce |
| `cinematic_instruction_demo.tscn` | GroupPlayback / CinematicGroup |
| `warrior_rig_2_cutscene_demo.tscn` | Parliament Ch.1 cutscene |
| `animation_test.tscn` | Rig texture hot-reload harness |
| `canvas_demo.tscn` | SVG drawing / rig sandbox |

Run the relevant demo tests after logic changes.

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

Canonical setup (from `src/demos/ai_act_demo.gd`):

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
- Unit classes: `src/character/classes-enum.gd`
- Combat types: `src/squad-battle/types.gd`
- Strategy types: `src/strategy/types.gd`
- Economy types: `src/economy/types.gd`
- Animation types: `src/animation/types.gd`
- Log singleton: `src/singletons/log.gd`
- AI profiles: `resources/ai/strategic/`
- Activity definitions: `resources/generic-activities/`
- Stage sets: `resources/stage_sets/`
