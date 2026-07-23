# CLAUDE.md

This file provides guidance to Claude Code when working with this repository. Update it whenever making project changes.

> **Copilot**: Modularized in `.github/` — `copilot-instructions.md` (always-loaded), `instructions/*.instructions.md` (domain-specific), `skills/` (slash commands). Prefer modular additions over expanding this file.

## Project

CONDOR — squad-based narrative strategy game. **Godot 4.5**, **GDScript** + **C#**. Requires `godot-mono` + `dotnet build` (`try1.csproj`, Godot.NET.Sdk/4.6.0, net8.0).

## Running & Testing

- **Main scene**: F5 runs `scenario.tscn`
- **Demo scenes** in `scenes/demos/` — run with F6 (or `godot --headless --path . scenes/demos/<name>.tscn`):
  - `combat_controller_test.tscn`, `combat_strategy_integration_test.tscn`, `scenario_attack_test.tscn` — combat tests
  - `ai_runner_demo.tscn` — AI brain decisions; `ai_battle_royale_demo.tscn` — fleet sim; `ai_stress_test_demo.tscn` — 50-turn stress
  - `pause_system_test.tscn` — pause/unpause/menu auto-pause (headless ok)
  - `squad_battle_2d_demo.tscn` — 2D WarriorRig battle
  - `animation_test.tscn` — `warrior_rig_2` harness. Keys `1-8`/`←→` cycle behaviors, `R` replay, `E` cycle expressions. Live texture hot-reload (0.4s poll). Script: `src/demos/animation_test.gd`
  - `stage_demo.tscn` — stage: rigs, march, speech bubbles, camera
  - `dialogue_demo.tscn` — dialogue system (headless ok)
  - `ranged_combat_demo.tscn`, `aoe_combat_demo.tscn` — ranged/AoE combat
  - `cinematic_instruction_demo.tscn` — GroupPlayback/CinematicGroup chains (headless only)
  - `cutscene_parliament.tscn` — Faust Ch.1 parliament scene. Cutscene `.tres` attached to the `cutscene` export. 9-char cast, per-char configs in `resources/animation/configs/rig2/rig2_*.tres`. SPACE advances gates, R replays. Regenerate: `python3 tools/build_parliament_cutscene.py`. Script: `src/demos/warrior_rig_2_cutscene_demo.gd`
  - `ai_act_demo.tscn` — scripted assertions. `godot-mono` required for economy tests
  - `economy_demo.tscn`, `economy_stress_test.tscn` — economy pipeline (use `godot-mono`)
  - `caravan_demo.tscn`, `bandit_demo.tscn` — caravan/bandit systems
  - `contact_system_test.tscn`, `government_test.tscn`, `guild_test.tscn` — unit tests
  - `reactive_stat_ui_test.tscn` — ReactiveStat → units_panel/unit_item UI wiring regression test (headless ok)
  - `interactive_demo.tscn` — terminal game (stdin commands)
  - `canvas_demo.tscn` — SVG drawing canvas. Start: `bash tools/start_canvas.sh [session]`
- **Autoload singletons**: `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`, `SFX`, `GrimdarkFX`
- **Sound generation**: `python3 tools/sound_designer.py` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
- Run relevant demos after logic changes.

### AI Interactive Play (`tools/play.sh`)
- `bash tools/play.sh "status"` — auto-starts game per `CONDOR_SESSION`. Set `export CONDOR_SESSION=<id>` for persistence.
- GOD commands: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`
- Flags: `--gui` (visible window), `--stop` (kill session)
- Screenshots: `bash tools/play.sh "screenshot" --gui`. MCP server: `tools/mcp-screenshot/server.py` (auto-starts own game)
- Pipes: `/tmp/condor_{input,output,pid}_<session>`

### SVG Drawing Canvas
- Start: `bash tools/start_canvas.sh [session]`; verify: `CONDOR_SESSION=<id> bash tools/play.sh "info"`
- Free-form: edit `scenes/demos/canvas/default.tscn` + `svgs/` — auto-reloads in 0.5s
- Rig mode: `play.sh "rig landsknecht"`. Animations: `"anim idle|walk|attack|defend|hurt|die"`
- Camera: `zoom 3.0`, `pan 500 300`, `center`. Other: `grid`, `bg #hex`, `tree`, `sizes`
- SVG viewBox sizes (×4): Head=176×200, Torso=136×112, Hips=112×32, Arm=40×88, Forearm=32×72, Hand=56×56, Leg=48×104, Shin=40×88, Foot=80×40
- Shaders in `assets/shaders/canvas/` — reference as ShaderMaterial in `.tscn`

## Architecture

### Three-Layer System

1. **Tactical Combat** (`src/squad-battle/`) — Turn-based View/Presenter/Model
   - `SquadBattle` (data.gd) — Model: battle state, round logic
   - `SquadBattleView2D` (view_2d.gd) — 2D WarriorRig battle view
   - `SquadBattlePresenter` (presenter.gd) — round loop, `battle_completed` signal. Duck-typed `var view`
   - `BattlefieldView2D` — SubViewport + Camera2D, row containers (Front/Middle/Back)
   - `BattleEntityDisplay` — wraps WarriorRig + HP bar + ORG icons
   - Flow: `squad_actions() → choose_action() → OneClash.execute() → Array[EntityUpdate]`
   - All state changes produce immutable `EntityUpdate`/`EntityChange` objects
   - **RetreatTracker**: FIGHTING→RETREATING→LAST_STAND→CAPITULATED
   - **Reality calculation**: Table-driven via `CombatEntity._REALITY_TABLE` — `[base, op, terms]`

2. **Strategic Campaign** (`src/strategy/`) — Hour-based real-time, Paradox-style speed controls
   - `GameScenario` (core/scenario.gd) — orchestrator. `_setup_economy()` validates all locations
   - `World` (core/world.gd) — location graph, roaming squads, `current_hour`, `is_paused`, `speed_multiplier`
   - `GameClock` (core/game_clock.gd) — drives hour progression, emits `hour_ticked`. `pause()/unpause()/set_speed()`
   - **Hourly tick**: `hour_ticked` → `StrategyPresenter._on_hour_tick()`. Economy every 24h
   - **Activity toggle**: `SquadData.current_activity_type`. SPACE toggles pause. Selecting activity does NOT auto-unpause
   - **Menu auto-pause**: opening any menu pauses. Closing does NOT auto-unpause
   - `ActivityExecuteManager` (ui/actor/!main.gd) — `exec_before/activity/after()`. AI skips triggerables
   - `ActivityHandler` base → `ActivityRegistry` maps ActivityType→handler (10 handlers + 5 pass-through)
   - **Travel**: km-based, `TownConnection.distance_km`, `EntityClasses.SPEED_TABLE`, `TravelGraph` distance-weighted A*

3. **Combat Bridge** (`src/strategy/core/sb-bridge/`)
   - `CombatBridge` (!main.gd) — stateless strategic↔tactical translation. CAPITULATE → `is_injured=true`
   - `CombatController` (control.gd) — stateful. `CombatResult` includes `escaped_warriors`, `equipment_loot`

### Supporting Systems

- **SFX** (`src/singletons/sfx.gd`): semantic play methods. Disabled headless
- **GrimdarkFX** (`src/singletons/grimdark_fx.gd`): atmospheric shaders. Two layers: texture-based (bg/fg) + overlay (CanvasLayer 200). Disabled headless. Shaders in `assets/shaders/fx/`: `world_atmosphere`, `vignette`, `film_grain`, `damage_pulse`, `combat_atmosphere`
- **UIAnimations** (`src/utils/ui_animations.gd`): static — `register_button()`, `show/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`, `pulse()`, `animate_label_number()`
- **Log** (`src/singletons/log.gd`): `class_name Log`. Levels: TRACE/DEBUG/INFO/WARN/ERROR. `Log.info("Source", "msg")`. Default: DEBUG
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond. `ThemeConstants` (`src/utils/theme_constants.gd`)
- **Data models**: `SquadData` (squad/social.gd), `CombatSquad` (squad/combat.gd), `Warrior` (character/social.gd), `CombatEntity` (character/combat.gd)

### Animation System (`src/animation/`)

5-layer: Clips→iExpression→AnimAction→Behavior→WarriorAnimController.

**`WarriorRig` dual mode**:
- **Baked** (`warrior_rig_2.tscn`): `Sprite2D` per bone pre-authored; `apply_config()` updates in place; textured in editor — scrub `AnimPlayer` to see poses live. Regenerate: `godot --headless --path . --script res://tools/bake_rig_scene.gd`
- **Legacy** (`warrior_rig.tscn`): spawns `top_level` Polygon2D placeholders synced each frame in `_process()`

**Inspector-driven** (`@tool`): `config` export or `character_name`+`emotion` dropdowns (scanned from `assets/rig_textures/<name>/`). Baked rigs preview live in editor. `RigTextureLibrary` (`rig_texture_library.gd`): `build_config(name, emotion, base=null)`, `apply_textures()`.

**Facial expressions (texture-swap, NOT animated)**:
- `Face` node under `Head` bone: `EyeL`, `EyeR`, `Mouth`, `Brows`, `HairBack` sprites
- `iExpression` (`expression.gd`): per-feature `Texture2D`s; `null` = leave unchanged
- `WarriorRig.set_expression(expr)` / `set_expression_by_name(id)`
- `FaceBlend` disconnected from AnimTree output — animations cannot override expressions
- **Gotcha**: `default_expression` re-applies at end of `_apply_config_internal` — null it to prevent snapping back to neutral
- Expression `.tres` in `resources/animation/expressions/<character>/`

**SVG art pipeline**:
- Source heads: `assets/rig_textures/<name>/_head.svg` → bake: `python3 tools/bake_svg_clips.py` (resolves `<use>` in `<clipPath>`, flattens nested transforms)
- Face split: `tools/export_face_features.py` emits `face/{eye_l,eye_r,mouth,brows,head_base,hair_back}_<emotion>.svg` per emotion sub-group in Inkscape "Face" layer. Run automatically by `bake_svg_clips.py`. To add emotion: author same-named sub-group in feature groups + re-bake
- **Art style**: 2D anime SD, clean 2px outlines, solid fills, 1:2.5 head-body ratio, 3/4 right-facing (big eye LEFT, small eye RIGHT). Z-order: Right* behind, Left* in front
- Generator: `python3 tools/generate_sd_svgs.py`

**Animation style**: idle 2s breathe, walk 1s heavy stride, attack 0.9s explosive, defend 0.7s bracing, hurt 0.6s stagger, die 1.5s collapse+fade, talk 1.6s gestures, gesture 1s flourish

**Warrior Stage** (`src/strategy/ui/stage/`): `StageView`+`StagePresenter`. Modes: MARCH/VN/HIDDEN. `SpeechBubble` typewriter, `StageCamera` tween-based.

**Stage Scenery**: `StageProp`+`StageSet` Resources. `StageView.apply_stage_set()` builds `Sprite2D` per prop via `SvgLoader`. Per-prop: `svg_path`, `position`, `scale`, `z_index`, `flip_h`, `modulate`, `parallax` (<1 = slower parallax drift). Assets in `assets/scenery/`. Example: `resources/stage_sets/parliament_chamber.tres`

### Visual Novel (`src/strategy/ui/vn/`)

- `VnPresenter` stage-aware; `EventChain` triggers via `event_chain_path` in results
- `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate)
- `CharacterInstruction` actions: MOVE/FACE/BEHAVIOR/SPAWN/SHOW/HIDE/**EXPRESSION**
  - `EXPRESSION` → `StagePresenter.set_character_expression()` → `WarriorRig.set_expression_by_name()`
  - BEHAVIOR + EXPRESSION in same parallel group = simultaneous animation + face swap
- `SceneryInstruction`: ADD/REMOVE/MOVE/MODULATE/SHOW/HIDE/SET_BACKDROP during playback
- `CinematicGroup`/`CinematicInstruction` `@export` all fields → round-trips as `.tres` cutscene (no EventChain needed)

### Strategic AI (`src/strategy/ai/`)

- Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as `.tres` in `resources/ai/strategic/`
- `AISquadManager` — `prepare_ai_turns()`, `cleanup_defeated_squads()`, `tick_bandit_lifecycle(faction)`, `register_squad(squad, profile_path="")`
- Three profiles: aggressive-hunter, balanced-roamer (default), cautious-survivor
- `StrategicSituation` — lazy BFS snapshot; enemies require SUSPECTED+ contact

### UI (`src/strategy/ui/`) — View/Presenter MVP

- `StrategyView/Presenter` — top-level, orchestrators: `CombatOrchestrator`, `ContactOrchestrator`. Unified tick in `_on_hour_tick()`
- `TravelView/Presenter` — AUTOPILOT/MANUAL/GOING states
- `ShopView/Presenter` — cart system with `LocationInventory`
- `ScoutingView/Presenter` — hover slide-in from left edge
- `SquadLogView` (`squad_log/view.gd`) — right-side slide-in chatbox, unread badge
- `MissionsView/Presenter` — active/completed list + details
- `MarketView/Presenter` — prices, production, population, trade rumors
- `ManageSquadPage/Presenter` — Tactics/Units/Formation/Recruitment/Inventory tabs

### Contact System (`src/strategy/core/contact/`)

HOI4-inspired: 0-100 → NONE/SUSPECTED/TRACKED/LOCKED. ATTACK requires LOCKED.
- Spotting: `BASE_SPOTTING_RATE * proximity * (scouting/(scouting+stealth)) * size_factor`
- Proximity: SAME_LOCATION(1.0), SAME_EDGE(0.7), ADJACENT(0.3). PATROL 1.5× scouting, REST 1.3× stealth

### Economy (`src/economy/`)

**C# mandatory** — `CsEconomyEngine` via `CsEconomyBridge`; GDScript `EconomyEngine` is thin facade.
- Build: `dotnet build`. Run with `godot-mono`
- Pipeline: GDScript computes `danger_matrix` → `CsEconomyBridge.Tick(turn, danger_matrix)` → `SyncBackToGdScript()`
- C# mega-loop phases (PHASE B per location): spoil→prices→orders→produce→subsist→match-orders→contracts→market→household→rent→gov→guild→pop state→geist→snapshot
- PHASE D: internal trade matcher using danger matrix
- `EconomyEngine.tick_full()` calls `engine.sync_full()` after each tick (person money/satisfaction/class sync)
- **Gradual pricing**: max 15%/tick adjustment. Food 1.2× sticky, weapons 0.6×, luxury 0.5×
- **Scarcity markup**: quadratic up to 50% as stock depletes (wealthiest buy first)
- **Government** (`CsGovernment`): 3 phases — GovernmentTax, GovernmentPlan (HireWorkers directives), GovernmentExecute. `GovernmentConfig` Resource on Location
- **Guilds** (`CsGuild`): 2 phases — PhaseGuildRecruit, PhaseGuildProduce. `GuildConfig` Resource on Location. First guild: Nürnberg Smithing (swords from 2 iron + 1 wood)
- **PersonBrain**: `NobleBrain` (loan scoring), `CommonBrain` (singleton no-op). `PhasePersonDecisions` runs all brains each tick
- **Caravan Bridge** (`caravan_bridge.gd`): materializes trade dispatches as MERCHANT squads. Uses `caravan-courier` brain profile
- **Bandit System** (`bandit_spawner.gd`, `mercenary_demand.gd`): desperation-driven spawning. `BanditSpawner.calculate_pressure(location)`. `bandit-raider.tres` brain. Lifecycle: pressure→spawn→roam→attack merchants→disband

### Key Enums

- Classes: `src/character/classes-enum.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter
- Weapons: `src/squad-battle/weapon/_factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire
- Armor: `src/squad-battle/armor/_factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate
- Combat: `src/squad-battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome
- Strategy: `src/strategy/types.gd` — LocationType, ActivityType, ContactState, EngagementType, SquadRole
- Economy: `src/economy/types.gd` — SocialClass, JobType, MoveState, ThingType, DirectiveType
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

Pierce: physical (Force+Precision vs armor PV) or magical (Mana+Spirituality vs magical PV). `OneClash.roll_for_pierce()` auto-branches on `is_magical`.

## GDScript Conventions

### Class Hierarchy
- **RefCounted** for logic — **Resource** for serializable data — **Node** for scene-attached UI

### Coding Rules
- **Fail-fast**: `assert()` for requirements. No fallback values or stubs
- **Enums over strings**. **Typed arrays**: `Array[EntityUpdate]` not `Array`
- **No comments** unless `##` doc or complex algorithms
- **Instantiate squads through `SquadDataFactory.create_squad(config)`**
- **Don't use `preload`** on "class not found" errors. **Don't export RefCounted** types. **Don't use `class_name` for inner classes**
- **`Resource.duplicate(true)` does NOT deep-copy external `.tres` sub-resources** — explicitly duplicate: `activity.result = activity.result.duplicate(true)`
- **Never programmatically create GUI** — define in `.tscn`, use `@onready` refs
- **Pre-built hidden nodes** for bounded lists; scene instantiation only for unbounded/compositional needs
- **Compartmentalize GUI into scenes** — each distinct UI component gets its own `.tscn`
- **Custom-drawn Controls must also be `.tscn` scenes** — prefer SVG assets over runtime `_draw()`

### Commit Message Format

```
<type>(<scope>): <subject>
```

**Types** (required):
- `feat` — new feature or gameplay behavior
- `fix` — bug fix
- `refactor` — restructure with no behavior change
- `art` — SVG / texture / visual asset files
- `chore` — metadata, imports, configs, gitignore, build files
- `test` — test scenes or scripts
- `docs` — CLAUDE.md, AGENTS.md, inline documentation
- `data` — `.tres` / `.tscn` resource or scene files only

**Scopes** (optional, pick the most specific): `combat`, `strategy`, `economy`, `vn`, `animation`, `stage`, `rig`, `ai`, `ui`, `tools`

**Subject rules**: imperative mood (`add X` not `added`), lowercase first letter, no trailing period, ≤ 72 chars total including type and scope.

Examples:
```
feat(vn): add EXPRESSION CharacterInstruction + VN/stage expression dispatch
art(rig): rebake warrior_rig_2.tscn with split EyeL/EyeR/Brows/HairBack overlay sprites
chore: add gitignores for SVG imports + Python cache
docs: update CLAUDE.md with face/expression system + add AGENTS.md
```

### Terminal / File Operations
- **Never use `cat` heredoc** for GDScript files (strips tabs). Use Python `with open()` or `replace_string_in_file`
- Commit after each code update. Only add+commit your own changes
- **Sprint logging**: After committing, append to `~/Documents/schwarzwagen/CONDOR/Development/Sprints/2026/Q<Q>/<Month>/W<N>.md`. Add under `## Commits`

### Critical Pitfalls
- **Typed array assignment**: Never assign from `Dictionary.get()` to typed arrays. Iterate and append
- **Squad positions**: `Front=1`, `Middle=2`, `Back=3` (NOT zero-indexed). Forward=-1, retreat=+1
- **Never `+=` label text for state indicators** — store base text and rebuild to prevent `"[PAUSED][PAUSED]"`
- **`GameClock` owns `world.current_hour`** — never overwrite from ActivityRunner or other subsystems
- **Unit conversion**: audit ALL hardcoded constants when changing time granularity (turns→hours)
- **Wire up lifecycle methods** — verify called methods like `decay_clues()` are actually invoked
- **Keep `src/` warning-clean** — avoid shadowing built-ins (`log`, `sign`), remove unused vars/signals

## Testing Conventions

**All tests MUST use `HeadlessStrategyView` + `StrategyPresenter`** — same code path as real game. Load real scenario: `presenter.scenario_path = "res://resources/scenarios/goetz-official/scenario.tres"`. Drive time: `game_clock.force_tick()` + `await presenter.tick_completed`.

```gdscript
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
    presenter.game_clock.force_tick()
    await presenter.tick_completed
```

## File Organization

- `src/squad-battle/` — combat engine (data.gd, presenter.gd, view_2d.gd, entity/, weapon/, armor/, clash/)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable, shop, contact, activity handlers
- `src/strategy/ui/` — View/Presenter per feature (stage/, vn/, travel/, shop/, scouting/, squad_log/, missions/, market/, manage_squad/)
- `src/strategy/ui/actor/` — ActivityExecuteManager (!main.gd), ActivityRunner, AI executors
- `src/strategy/ai/` — fleet manager, squad brain, considerations, glances, actions, caravan brain
- `src/animation/` — WarriorRig, configs, expressions, actions, controller
- `src/character/` — Warrior (social.gd), CombatEntity (combat.gd), classes enum
- `src/squad/` — SquadData, CombatSquad, CargoManifest
- `src/economy/` — engine, types, thing, person, population, inventory, caravan bridge; `csharp/` (CsGovernment, CsGuild, GovernmentBrain, GuildBrain)
- `src/singletons/` — event buses, SFX, Log
- `assets/rig_textures/` — SVG bone textures per class (15 bones × 7 classes)
- `assets/scenery/` — backdrop/prop SVGs; generator `tools/generate_scenery_svgs.py`
- `assets/shaders/fx/` — world_atmosphere, vignette, film_grain, damage_pulse, combat_atmosphere
- `assets/shaders/canvas/` — canvas shader experiments
- `resources/scenarios/goetz-official/` — main campaign (7 locations, ~7420 population)
- `resources/ai/strategic/` — AI behavior `.tres` files
- `resources/generic-activities/` — Activity `.tres` files
- `resources/theme/` — condor_theme.tres, styles/, bold_font.tres
- `scenes/demos/canvas/` — SVG drawing canvas layouts + `svgs/rig/<class>/` bone SVGs
