# AGENTS.md

Guidance for AI coding agents working in this repository. Assumes no prior knowledge of the project.

This is a one-man project that changes very frequently — docs can drift out of sync with the code. If something in the codebase doesn't align with what's written here, make the opportunistic change: fix the doc (or the code, if the doc is right and the code is the outlier) on the spot rather than working around the mismatch silently.

> **Copilot**: Modularized instructions live in `.github/` — `copilot-instructions.md` (always-loaded), `instructions/*.instructions.md` (domain-specific: combat, economy, strategy), `skills/` (slash commands: `condor-animation`, `condor-play`, `condor-testing`).

## Project Overview

**CONDOR** — a squad-based narrative strategy game.

- **Engine**: Godot **4.7** (mono build required — `godot-mono`), Forward Plus renderer
- **Languages**: **GDScript** (primary) + **C#** (economy engine only)
- **C# project**: `try1.csproj` — Godot.NET.Sdk/**4.7.0**, net8.0, root namespace `Condor`, assembly name `try1`
- **Main scene**: `scenario.tscn` (run with F5)
- **Theme**: `resources/theme/condor_theme.tres` (EB Garamond), set as the global GUI theme
- Viewport: 1920×1080
- Origin: the tactical combat core was migrated from a Roblox/TypeScript project (`life-is-roblox`); `README.md` describes that migration and is largely historical — trust this file over it.

### Autoload singletons (from `project.godot`)

`StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager` (scene), `SFX`, `GrimdarkFX` (scene).

### Editor plugins

`addons/GDQuest_GDScript_formatter/` (GDScript formatter) and `addons/script-ide/` are enabled.

## Build, Run & Test Commands

- **Build C#** (required before anything touches the economy): `dotnet build`
- **Run main scene**: F5 in the editor, or `godot-mono --path .` (use `godot-mono`, not plain `godot`, whenever economy code runs)
- **Run a demo scene**: F6 in the editor, or headless:
  `godot --headless --path . scenes/demos/<name>.tscn` (use `godot-mono` for economy demos)
- **Run relevant demos after logic changes** — demo scenes in `scenes/demos/` are the test suite (see Testing below).
- **Sound generation**: `python3 tools/sound_designer.py` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
- **Hyprland**: any GUI Godot window (editor, `--gui` runs, `start_canvas.sh`) auto-routes to workspace 10 without stealing focus, via windowrules on class `Godot`/`try1` in `~/.config/hypr/userprefs.conf`. Launcher: `godot-ws` (`~/.local/bin`).

### AI Interactive Play (`tools/play.sh`)

- `bash tools/play.sh "status"` — auto-starts a game session per `CONDOR_SESSION`. Set `export CONDOR_SESSION=<id>` for persistence.
- GOD commands: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`
- Flags: `--gui` (visible window), `--stop` (kill session)
- Screenshots: `bash tools/play.sh "screenshot" --gui`. MCP server: `tools/mcp-screenshot/server.py` (auto-starts its own game)
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

1. **Tactical Combat** (`src/squad_battle/`) — turn-based Model + View, coupled by signal
   - `SquadBattle` (data.gd) — Model (Resource): battle state, round logic. Owns `battle_completed(outcome)`, emitted once from `evaluate_outcome()` on the ONGOING→terminal transition. Held as a plain property on the View, never a scene child
   - `SquadBattleNode` (view_2d.gd) — 2D WarriorRig battle view + round loop (`_ready()` → recursive `_loop_round()`, needs `get_tree()` timers). `all_updates`, `delay_between_rounds`, `request_retreat(team)`
   - External consumers await the domain event through its owner: `battle.battle_completed`, not a View relay signal
   - `BattlefieldView2D` — SubViewport + Camera2D, row containers (Front/Middle/Back)
   - `BattleEntityDisplay` — wraps WarriorRig + HP bar + ORG icons
   - Flow: `advance_round() → CombatSquad.perform_actions() → CombatEntity.action() → ClashResolver.resolve(ClashIntent) → Array[EntityUpdate]`
   - All state changes produce immutable `EntityUpdate`/`EntityChange` objects
   - **RetreatTracker**: FIGHTING→RETREATING→LAST_STAND→CAPITULATED
   - **Reality calculation**: table-driven via `CombatEntity._REALITY_TABLE` — `[base, op, terms]`

2. **Strategic Campaign** (`src/strategy/`) — hour-based real-time, Paradox-style speed controls
   - `GameScenario` (core/scenario.gd) — orchestrator. `_setup_economy()` validates all locations
   - `World` (core/world.gd) — location graph, roaming squads, `current_hour`, `is_paused`, `speed_multiplier`
   - `GameClock` (core/game_clock.gd) — drives hour progression, emits `StrategyEventBus.strategy_hour_tick`. `pause()/unpause()/set_speed()`
   - **Hourly tick**: `StrategyEventBus.strategy_hour_tick` → `StrategyPresenter._on_hour_tick()`. Economy every 24h
   - **Activity toggle**: `StrategySquad.current_activity_type`. SPACE toggles pause. Selecting an activity does NOT auto-unpause
   - **Menu auto-pause**: opening any menu pauses. Closing does NOT auto-unpause
   - `ActivityExecuteManager` (ui/actor/activity_execute_manager.gd) — `exec_before()/exec_activity()/exec_after()`. AI skips triggerables
   - `ActivityHandler` base → `ActivityRegistry` maps ActivityType→handler (10 handlers + 5 pass-through)
   - **Travel**: km-based, `TownConnection.distance_km`, squad speed = `StrategySquad.get_speed_kmh()` (slowest warrior's MV_SPD), `TravelGraph` distance-weighted A*

3. **Combat Bridge** (`src/strategy/core/sb_bridge/`)
   - `CombatBridge` — translates `StrategySquad` ↔ `SquadBattle` via `Character.enter_battle()`/`exit_battle()`. CAPITULATE → `is_injured=true`
   - `CombatController` (control.gd) — stateful, entry point `inject_context()`. `CombatResult` includes `escaped_warriors`, `equipment_loot`

### Character & the ReactiveStat Cascade (`src/character/`)

Three-tier stat cascade, each tier a `Dictionary[StatName.I, ReactiveStat]` (`ReactiveStat` — `src/test_reactive_stat.gd`, a tiny `Resource` wrapping a `Variant` + `StatName.I`, emits `changed` on write):

- **Tier 1 — Template**: `StrategyEntityResource.rs_array` / `CombatEntityResource.rs_array` (`resources/combat/classes/*.tres`). Shared, never mutated
- **Tier 2 — Constant/Nature**: `StrategyEntity.rs_arr`. Persistent campaign warrior, duplicated from tier 1 once at creation (`StrategyEntityFactory.Create()`), rarely changes
- **Tier 3 — Current/Battle**: `CombatEntity.rs_arr`. Ephemeral per-battle runtime, duplicated fresh on `enter_battle()`, discarded on `exit_battle()`
- `StatName.I` enum (`statname_global.gd`): `MORALE, MV_SPD, WEAPON, ARMOUR, HP, STA, ORG, POS, MAG, LOC` (mutable/current) + 12 base attributes `STRENGTH..ENDURANCE` (`StatName.BASE_ATTRIBUTE_STATS`). Append-only — values are baked into `.tres` files
- **`Character`** (`character.gd`) mediates `strategy: StrategyEntity` (nullable) + `combat: CombatEntity` (nullable) — the only class that knows about both; `StrategyEntity`/`CombatEntity` never reference each other. `enter_battle(side, player_id, starting_location)` resolves each base attribute tier-2→tier-1 via `get_constant_stat_value()` (falls through to the class template whenever the persistent character has no override), builds a `CombatEntityConfig`, constructs `CombatEntity`. `exit_battle()` drops the reference. `StrategySquad.warriors: Array[Character]`. `combat_identification` lets a `Character` with `strategy=null` resolve straight from a template (monsters/bandits/demo combatants)
- `is_dead`/`is_injured` stay plain `bool` fields on `StrategyEntity`/`Character` (not `StatName` entries) — `not warrior.is_dead` must stay a real bool check, not a `Callable`
- `CombatEntity.calculate_reality_value()` → `get_ceiling_changeable_stat()` is driven by `RealityCalculationFactory.table` (`resources/combat/reality/reality_table.tres`), a data-driven `RealityTable` of curve-based `Calculation`s — see "Calculation / Curve composition system" below. `CombatEntityFactory.build_config_from_resource()` is the template-only construction path (no `Character`) for scripted/demo battles

### Calculation / Curve composition system (`src/squad_battle/calculation/`)

Combat's stat→value math (raw stat → Reality, Reality → Hit/Penetration, Reality → typed damage via `PotencyObj`) is `Curve`-sampled, not flat-multiplied — a near-flat curve expresses "barely scales with this stat," a concave curve expresses "rewards high stats disproportionately," both as pure data with no special-cased fields.

- `Calculation` (`calculation.gd`): `base: float`, `op: ADD|MUL`, `terms: Array[CalculationTerm]` — folds terms exactly like the old `_RealityOp`/`_REALITY_TABLE` did. `evaluate(entity: CombatEntity) -> float`
- `CalculationTerm` (`calculation_term.gd`): one term, `source: STAT|REALITY` selects whether it samples a raw `StatName.I` or a resolved `SquadBattleTypes.Reality`, then `curve.sample(x)`. Asserts `x <= curve.max_domain` — a curve authored with too small a domain fails fast instead of silently clamping
- **Curve domain convention — this is the one thing to get right when authoring or migrating a curve**: `Curve.sample()` uses whatever domain/tangents are stored, it does **not** auto-recompute anything from a "linear" mode flag at load time. Two rules:
  1. **Domain must cover the real range of the input**, with ~2x headroom. Raw stats (`STAT` source) cluster 0.6–2.5 across `resources/combat/classes/base_stats/*.tres` → use `max_domain = 5.0`. Resolved `Reality` values range much wider (MUL-composed ones especially) — `Force` ≈ 10, `Precision`/`Bravery` ≈ 15, `Maneuver` ≈ 16, `Mana` ≈ 20, `Spirituality` ≈ 22 (see `resources/combat/formula/*.tres` and any `PotencyObj.curve` for worked examples). Exceeding the domain clamps silently for `PotencyObj`/`DamageTranslation` curves (sampled directly, no assert) — always re-derive the domain from real stat combinations for whatever `Reality` a new curve is keyed on, don't reuse `5.0` by habit
  2. **To reproduce an old flat multiplier `y = weight * x` exactly** (e.g. when migrating, or adding a straight-line term): two points `Vector2(0,0)` and `Vector2(max_domain, weight*max_domain)`, tangent mode `1` (linear) on both, and — critically — the tangent **value** at each point set to `weight` (not `0.0`). The mode flag alone does not force a straight line; the stored tangent float is what Hermite-interpolates the segment, so a `0.0` tangent with mode=linear silently produces an S-curve (smoothstep), not a line. For a multi-point piecewise-linear curve, each interior point's `tangent_in`/`tangent_out` should be set to its *adjacent* segment's slope (they'll differ across a kink) — verified empirically, not just from docs, before trusting a hand-authored `.tres`
- `_limits = [min_value, max_value, min_domain, max_domain]` in the serialized `.tres`, and `max_value` **does** clamp `sample()`'s output — set it above the curve's actual peak y, not just default/copy-pasted

### Supporting Systems

- **SFX** (`src/singletons/sfx.gd`): semantic play methods. Disabled headless
- **GrimdarkFX** (`src/singletons/grimdark_fx.gd`): atmospheric shaders. Two layers: texture-based (bg/fg) + overlay (CanvasLayer 200). Disabled headless. Shaders in `assets/shaders/fx/`: `world_atmosphere`, `vignette`, `film_grain`, `damage_pulse`, `combat_atmosphere`
- **UIAnimations** (`src/utils/ui_animations.gd`): static — `register_button()`, `show/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`
- **Log** (`src/singletons/log.gd`): `class_name Log`. Levels: TRACE/DEBUG/INFO/WARN/ERROR. `Log.info("Source", "msg")`. Default: DEBUG
- **Data models**: `StrategySquad` (squad/social.gd, tier 2), `CombatSquad` (squad/combat.gd, tier 3), `StrategyEntity`+`Character` (character/strat.gd, character/character.gd), `CombatEntity` (character/combat.gd, tier 3)

### Animation System (`src/animation/`)

Body: Clips→Behavior→`WarriorAnimController` (AnimTree state machine). Face: a separate, signal-driven system — the AnimTree does not touch it.

**Character registry** (`resources/characters/<id>.tres`): one `CharacterManifest` per character — the single place that lists every file making them up (art dir, rig config, combat template, warrior preset, has_face). To add a character: create the manifest, add art to `assets/rig_textures/<id>/`, then run `tools/bake_character.sh <id>`.

**One-command bake**: `tools/bake_character.sh <id>` runs the full pipeline (SVG clip bake → face split → rig scene bake with RESET rebuild). `bake_rig_scene.gd` resolves the character via its manifest; defaults to rachelle when run without args.

**`WarriorRig` dual mode**:
- **Baked** (`scenes/rig/warrior_rig_2.tscn`): `Sprite2D` per bone pre-authored; `apply_config()` updates in place; textured in editor — scrub `AnimPlayer` to see poses live. Regenerate: `tools/bake_character.sh <id>` (or `godot --headless --path . --script res://tools/bake_rig_scene.gd -- <id>`)
- **Legacy** (`scenes/rig/warrior_rig.tscn`): spawns `top_level` Polygon2D placeholders synced each frame in `_process()`. No face parts; only `canvas_demo` still instantiates it

**Inspector-driven** (`@tool`): `config` export or `character_name`+`emotion` dropdowns (scanned from `assets/rig_textures/<name>/`). `RigTextureLibrary` (`rig_texture_library.gd`): `build_config(name, base=null)`, `apply_textures()` — bone + head textures only; face art is baked into the rig scene, not carried on the config.

**Factories**: `WarriorRigFactory` instantiates `warrior_rig_2.tscn` for all three entry points; `WarriorRigConfigFactory.get_config(id)` resolves a character/class id against `resources/animation/configs/` (stripping the `wcr_adventurer_`/`wcr_`/`rig2_` authoring prefixes), falling back to `landsknecht` with a `Log.warn`.

**Composable face (`src/animation/face/`)** — the face broadcasts intent; each part decides what it means:
- `Face` (`face.gd`, Node2D under the `Head` bone): `signal expression_changed(intent: StringName)` + `express(intent)`. Knows nothing about any intent. `character` records whose art it carries
- `FaceComponent` (`face_component.gd`, Sprite2D): every node in the subtree, art-bearing leaves and pure grouping nodes alike. On `_ready()` walks up to the Face, connects, and captures its authored position/rotation/scale/texture as an immutable baseline
- `FaceReaction` (`face_reaction.gd`, Resource): `intent`, `texture` (null = keep current), `position_delta`, `rotation_delta`, `scale_delta` (multiplicative), `blend_time`. Authored inline on the component in the Inspector — no per-expression `.tres`, no config-level lookup table
- **Every reaction is measured from the baseline**, so switching intents never accumulates drift. `&"neutral"` needs no authored entry: it means "back to the baked pose". An intent no part answers is a silent no-op
- Nesting composes — a reaction on a parent node carries its children with it, then children layer their own deltas on top
- `WarriorRig.set_expression_by_name(id)` → `face.express()`. `WarriorRigConfig.has_face_components` gates `face.visible`: all characters share one baked scene, so a config that isn't the baked character's hides the face rather than wearing it
- Per-emotion swaps (`blink`, `wide`) are generated from the artwork by `bake_rig_scene.gd`; procedural ones (`scared`, `angry`) live in `tools/author_face_reactions.gd` and are carried across rebakes
- Verify: `scenes/demos/face_component_test.tscn` (headless ok)

**SVG art pipeline**:
- Source heads: `assets/rig_textures/<name>/_head.svg` → bake: `python3 tools/bake_svg_clips.py` (resolves `<use>` in `<clipPath>`, flattens nested transforms)
- Face split: `tools/export_face_features.py` discovers parts recursively from the Inkscape "Face" layer — no hardcoded feature list. Every labelled `<g>` is a part; a label that is `Clip` or ends `-Clip`/`_Clip` is plumbing; a label ending `+clip` keeps the face-silhouette clip. Emotion sub-groups sit directly under each top-level part. Run automatically by `bake_svg_clips.py`
- Outputs `face/<part_path>_<emotion>.svg`, each stamping itself with `data-part-path`, `data-order` (painting order) and `data-pivot` (its own bbox centre, queried from Inkscape) so the bake tool never parses filenames. Stale outputs are pruned
- To add a part: label a group in Inkscape and re-bake. To add an emotion: author a same-named sub-group and re-bake — a part the emotion doesn't author is emitted EMPTY, never falling back to neutral art
- **Art style**: 2D anime SD, clean 2px outlines, solid fills, 1:2.5 head-body ratio, 3/4 right-facing (big eye LEFT, small eye RIGHT). Z-order: Right* behind, Left* in front
- Generator: `python3 tools/generate_sd_svgs.py`

**Animation style**: idle 2s breathe, walk 1s heavy stride, attack 0.9s explosive, defend 0.7s bracing, hurt 0.6s stagger, die 1.5s collapse+fade, talk 1.6s gestures, gesture 1s flourish

**Warrior Stage** (`src/strategy/ui/stage/`): `StageView`+`StagePresenter`. Modes: MARCH/VN/HIDDEN. `SpeechBubble` typewriter, `StageCamera` tween-based.

**Stage Scenery**: `StageProp`+`StageSet` Resources. `StageView.apply_stage_set()` builds `Sprite2D` per prop via `SvgLoader`. Per-prop: `svg_path`, `position`, `scale`, `z_index`, `flip_h`, `modulate`, `parallax` (<1 = slower parallax drift). Assets in `assets/scenery/`. Example: `resources/animation/stage_sets/parliament_chamber.tres`

### Visual Novel (`src/strategy/ui/vn/`)

- `VnPresenter` stage-aware; `EventChain` triggers via `event_chain_path` in results
- `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate)
- `CharacterInstruction` actions: MOVE/FACE/BEHAVIOR/SPAWN/SHOW/HIDE/**EXPRESSION**
  - `EXPRESSION` → `StagePresenter.set_character_expression()` → `WarriorRig.set_expression_by_name()` → `Face.express()`; the instruction's `expression` string is just an intent name
  - BEHAVIOR + EXPRESSION in the same parallel group = simultaneous animation + face reaction
- `SceneryInstruction`: ADD/REMOVE/MOVE/MODULATE/SHOW/HIDE/SET_BACKDROP during playback
- `CinematicGroup`/`CinematicInstruction` `@export` all fields → round-trips as `.tres` cutscene (no EventChain needed)

### Strategic AI (`src/strategy/ai/`)

- Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as `.tres` in `resources/ai/strategic/` (profiles in `profiles/`)
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

**C# mandatory** — `CsEconomyEngine` via `CsEconomyBridge`; the GDScript `EconomyEngine` is a thin facade.
- Build: `dotnet build`. Run with `godot-mono`
- Pipeline: GDScript computes `danger_matrix` → `CsEconomyBridge.Tick(turn, danger_matrix)` → `SyncBackToGdScript()`
- C# mega-loop phases (PHASE B per location): spoil→prices→orders→produce→subsist→match-orders→contracts→market→household→rent→gov→guild→pop state→geist→snapshot
- PHASE D: internal trade matcher using the danger matrix
- `EconomyEngine.tick_full()` makes exactly two bridge calls: `Tick(turn, danger_matrix)` then `SyncBackToGdScript()` (person money/satisfaction/class sync); `sync_full()` is a demo-only wrapper
- **Gradual pricing**: max 15%/tick adjustment. Food 1.2× sticky, weapons 0.6×, luxury 0.5×
- **Scarcity markup**: quadratic up to 50% as stock depletes (wealthiest buy first)
- **Government** (`CsGovernment`): 3 phases — GovernmentTax, GovernmentPlan (HireWorkers directives), GovernmentExecute. `GovernmentConfig` Resource on Location
- **Guilds** (`CsGuild`): 2 phases — PhaseGuildRecruit, PhaseGuildProduce. `GuildConfig` Resource on Location. First guild: Nürnberg Smithing (swords from 2 iron + 1 wood)
- **Person decisions**: per-class logic lives directly on `CsPerson` (no separate brain classes); noble loans via `CsLoan` + `SetupBank()` thresholds
- **Caravan Bridge** (`strategy_bridge/caravan_bridge.gd`): materializes trade dispatches as MERCHANT squads. Uses the `caravan-courier` brain profile
- **Bandit System** (`bandit_spawner.gd`, `mercenary_demand.gd`): desperation-driven spawning. `BanditSpawner.calculate_pressure(location)`. `bandit-raider.tres` brain. Lifecycle: pressure→spawn→roam→attack merchants→disband

### Systems Layer (prototype, `src/strategy/systems/` + `src/strategy/core/clock_system.gd`)

A composition-root pattern replacing the old Presenter-orchestrates-everything flow, wired entirely from `main.gd`/`main.tscn` (not `scenario.tscn`, which is still the legacy path):
- `ClockSystem`, `SquadBeingSystem`, `SquadTravelSystem`, `BattleResolutionSystem`, `ActivityRunSystem` — each a `Node` added under `main.tscn`'s `Systems` root by `main.gd._enter_system()`
- **Rule: no system may hold a reference to, `preload`, or call another system directly.** All cross-system data flow goes through signals (`squad_turn`, `request_travel`, `request_combat`, `hour_changed`, ...) connected by `main.gd` in `load_scenario()` — the composition root is the only place allowed to know about every system at once
- When a signal handler needs to reach a system the emitting system isn't allowed to know about (e.g. resolving `ActivityResult.combat_target_squad_id` to a `StrategySquad` needs `SquadBeingSystem`, but neither `ActivityRunSystem` nor `BattleResolutionSystem` may reference it), that bridging logic lives in `main.gd`, not in either system
- Still prototype-stage: `main.gd._run_prototype_tests()` runs scripted assertions inline against `main.tscn` on `_ready()` (no separate demo scene yet)

### Key Enums

- Classes: `src/character/entity_classes.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter. `CombatEntityFactory` identifies templates by lowercase string (`"landsknecht"`), scanned from `resources/combat/classes/*.tres`
- Weapons: `src/squad_battle/items/weapon/factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire
- Armor: `src/squad_battle/items/armor/factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate
- Combat: `src/squad_battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome
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

Pierce: physical (Force+Precision vs armor PV) or magical (Mana+Spirituality vs magical PV). The hit/pierce rolls are inline in `ClashResolver.resolve()` (clash/resolver.gd), branching on `weapon.resource.is_magical`. `OneClash` (clash/one_clash.gd) is legacy and currently uncalled.

## Code Style Guidelines (GDScript)

### Class Hierarchy
- **RefCounted** for logic — **Resource** for serializable data — **Node** for scene-attached UI

### Coding Rules
- **Composition over inheritance**: prefer composing behavior from small resources/components (e.g. keyed `ReactiveStat` dictionaries) over deep subclass hierarchies. Reach for inheritance only when Godot's own architecture requires it (Node/Resource base types, `@tool` plugin hooks)
- **Signals over direct calls for composed Resources**: a game-logic Resource composed into a Node as a plain property (never a scene child) announces its own state changes via its own signal — a custom one, or inherited `changed`/`emit_changed()` for simple cases. The owning Node connects/awaits; neither side reaches into the other to call methods for notification, and no intermediary Node exists just to shuttle calls between them. Worked examples: `ReactiveStat.changed` (`src/test_reactive_stat.gd`), `_squad.inventory.changed` (`manage_squad/inventory_panel.gd`, `unit_item.gd`, `inventory_tab.gd`), `SquadBattle.battle_completed` (`src/squad_battle/data.gd`) awaited by external consumers as `battle_scene.battle.battle_completed`
- **MVP (View/Presenter) is a sanctioned exception, not the default**: reach for a separate Presenter class only when a UI screen's orchestration is complex enough to warrant it — `strategy/ui/{market,travel,shop,scouting,stage,vn}` and `strategy/ui/presenter.gd` itself earn it. Everywhere else, default to composition-over-inheritance + signal-announced state. `src/squad_battle/` dropped its Presenter tier for exactly this reason — a headless, signal-driven simulation didn't need one; the round loop now lives directly on the View
- **Fail-fast**: `assert()` for requirements. No fallback values or stubs
- **Enums over strings**. **Typed arrays**: `Array[EntityUpdate]` not `Array`
- **No comments** unless `##` doc or complex algorithms
- **Instantiate squads through `SquadDataFactory.create_squad()`** (named params: squad_id, squad_name, money, food, travel_tools, karma, location ids, squad_role)
- **Don't use `preload`** on "class not found" errors. **Don't export RefCounted** types. **Don't use `class_name` for inner classes**
- **`Resource.duplicate(true)` does NOT deep-copy external `.tres` sub-resources** — explicitly duplicate: `activity.result = activity.result.duplicate(true)`
- **Never programmatically create GUI** — define in `.tscn`, use `@onready` refs. **Exception**: one-time-use offline generator scripts (Python, EditorScript, etc.) that *output* `.tscn`/`.tres` files to disk are fine — the generated file becomes the source of truth afterward. The generator is a build step, not a runtime dependency. Never re-run it to "refresh" a scene; edit the `.tscn` directly after generation
- **Pre-built hidden nodes** for bounded lists; scene instantiation only for unbounded/compositional needs
- **Compartmentalize GUI into scenes** — each distinct UI component gets its own `.tscn`
- **Custom-drawn Controls must also be `.tscn` scenes** — prefer SVG assets over runtime `_draw()`
- **No single-use functions**: don't extract a named function/method unless the code is called from more than one call site across the entire project. A block used once stays inline where it's used; if it needs a name for clarity, use a comment above it instead of a function signature. Exempt: Godot-invoked entry points the engine or scene tree calls directly — virtual/lifecycle methods (`_ready`, `_process`, `_input`, `_draw`, ...), signal-callback handlers (`_on_*` wired via `connect()`/editor signal), and `@tool`/exported methods invoked from the inspector. Not exempt: ordinary helper methods called from exactly one place in the same script — inline those

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
```

### Terminal / File Operations
- **Never use `cat` heredoc** for GDScript files (strips tabs). Use Python `with open()` or a string-replace edit tool
- **Mass renames** (many files/symbols across the tree): write a Python script to do it programmatically instead of editing occurrences one by one
- Commit after each code update. Only add+commit your own changes
- **Sprint logging**: after committing, append to `~/Documents/schwarzwagen/CONDOR/Development/Sprints/2026/Q<Q>/<Month>/W<N>.md` under `## Commits`
- **Obsidian docs sync**: when changing architecture, runtime flow, data contracts, or behavior, update the corresponding notes in `~/Documents/schwarzwagen/CONDOR/Systems/` in the same task (see `.github/copilot-instructions.md` for the subsystem→note mapping)

### Critical Pitfalls
- **Typed array assignment**: never assign from `Dictionary.get()` to typed arrays. Iterate and append
- **Squad positions**: `Front=1`, `Middle=2`, `Back=3` (NOT zero-indexed). Forward=-1, retreat=+1
- **Never `+=` label text for state indicators** — store base text and rebuild to prevent `"[PAUSED][PAUSED]"`
- **`GameClock` owns `world.current_hour`** — never overwrite from ActivityRunner or other subsystems
- **Unit conversion**: audit ALL hardcoded constants when changing time granularity (turns→hours)
- **Wire up lifecycle methods** — verify called methods like `decay_clues()` are actually invoked
- **Keep `src/` warning-clean** — avoid shadowing built-ins (`log`, `sign`), remove unused vars/signals

## Testing Instructions

There is no unit-test framework — **demo scenes in `scenes/demos/` are the tests**, many with scripted assertions. Run them headless where noted:

- `combat_controller_test.tscn`, `combat_strategy_integration_test.tscn`, `scenario_attack_test.tscn` — combat tests
- `combat_entity_rs_test.tscn` — CombatEntity ReactiveStat cascade: template resolution, `_REALITY_TABLE` math, floor/ceiling clamping, per-instance independence, `Character.enter_battle()` tier-2/tier-1 fallback (headless ok)
- `ai_runner_demo.tscn` — AI brain decisions; `ai_battle_royale_demo.tscn` — fleet sim; `ai_stress_test_demo.tscn` — 50-turn stress
- `pause_system_test.tscn` — pause/unpause/menu auto-pause (headless ok)
- `squad_battle_2d_demo.tscn` — 2D WarriorRig battle
- `animation_test.tscn` — `warrior_rig_2` harness. Keys `1-8`/`←→` cycle behaviors, `R` replay, `E` cycle expression intents. Live texture hot-reload (0.4s poll). Script: `src/demos/animation_test.gd`
- `face_component_test.tscn` — composable Face/FaceComponent assertions: intent cascade, no-drift baseline, unanswered intents, artwork texture swaps, faceless-config hiding (headless ok)
- `stage_demo.tscn` — stage: rigs, march, speech bubbles, camera
- `dialogue_demo.tscn` — dialogue system (headless ok)
- `ranged_combat_demo.tscn`, `aoe_combat_demo.tscn` — ranged/AoE combat
- `cinematic_instruction_demo.tscn` — GroupPlayback/CinematicGroup chains (headless only)
- `cutscene_parliament.tscn` — Faust Ch.1 parliament scene. Cutscene `.tres` attached to the `cutscene` export. 9-char cast, per-char configs in `resources/animation/configs/rig2_*.tres`. SPACE advances gates, R replays. Regenerate: `python3 tools/build_parliament_cutscene.py`
- `ai_act_demo.tscn` — scripted assertions. `godot-mono` required for economy tests
- `economy_demo.tscn`, `economy_stress_test.tscn` — economy pipeline (use `godot-mono`)
- `caravan_demo.tscn`, `bandit_demo.tscn` — caravan/bandit systems
- `contact_system_test.tscn`, `government_test.tscn`, `guild_test.tscn` — unit tests
- `reactive_stat_ui_test.tscn` — ReactiveStat → units_panel/unit_item UI wiring regression test (headless ok)
- `interactive_demo.tscn` — terminal game (stdin commands)
- `canvas_demo.tscn` — SVG drawing canvas. Start: `bash tools/start_canvas.sh [session]`

**All strategy tests MUST use `HeadlessStrategyView` + `StrategyPresenter`** — same code path as the real game. Load the real scenario: `presenter.scenario_path = "res://resources/strategy/scenarios/goetz-official/scenario.tres"`. Drive time: `game_clock.force_tick()` + `await presenter.tick_completed`.

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

- `src/squad_battle/` — combat engine (data.gd, view_2d.gd, entity/, items/, clash/, feedback/)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable, shop, contact, activity handlers, sb_bridge (combat bridge)
- `src/strategy/ui/` — View/Presenter per feature (stage/, vn/, travel/, shop/, scouting/, squad_log/, missions/, market/, manage_squad/, combat/, contact/, investigation/, notification/, recruitment/)
- `src/strategy/ui/actor/` — ActivityExecuteManager (activity_execute_manager.gd), ActivityRunner, AI executors
- `src/strategy/ai/` — fleet manager, squad brain, considerations, glances, actions, caravan brain
- `src/animation/` — WarriorRig, configs, controller; `face/` (Face, FaceComponent, FaceReaction)
- `src/character/` — StrategyEntity+StrategyEntityResource (strat.gd/strat_resource.gd, tier 2/1), Character mediator (character.gd), CombatEntity+CombatEntityResource (combat.gd/combat_resource.gd, tier 3/1), classes enum
- `src/squad/` — StrategySquad (social.gd), CombatSquad (combat.gd), CargoManifest, SquadDataFactory
- `src/economy/` — engine, types, thing, person, population, inventory, caravan bridge; `csharp/` (CsEconomyEngine/Bridge, CsPerson, CsGovernment, CsGuild, CsLoan, CsOrderMatcher, CsGeist)
- `src/singletons/` — event buses, SFX, Log
- `src/utils/` — SvgLoader, UIAnimations, SBLog
- `assets/rig_textures/` — SVG bone textures per character
- `assets/scenery/` — backdrop/prop SVGs; generator `tools/generate_scenery_svgs.py`
- `assets/shaders/fx/` — world_atmosphere, vignette, film_grain, damage_pulse, combat_atmosphere
- `assets/shaders/canvas/` — canvas shader experiments
- `resources/strategy/scenarios/goetz-official/` — main campaign (10 locations, ~7670 population)
- `resources/ai/strategic/` — AI behavior `.tres` files
- `resources/strategy/generic-activities/` — Activity `.tres` files
- `resources/characters/` — one `CharacterManifest` `.tres` per character (single registry entry listing all their files)
- `resources/combat/classes/` — `CombatEntityResource` class templates (tier 1); `resources/strategy/warrior-presets/`, `resources/strategy/squads-presets/` — `StrategyEntityResource`/`StrategySquad` preset data
- `resources/theme/` — condor_theme.tres, styles/, bold_font.tres
- `scenes/demos/canvas/` — SVG drawing canvas layout (`default.tscn`) + free-form `svgs/`
- `tools/` — offline generators and utilities: `bake_character.sh`, `bake_rig_scene.gd`, `bake_svg_clips.py`, `export_face_features.py`, `play.sh`, `start_canvas.sh`, `sound_designer.py`, `mcp-screenshot/`, etc.

## Security & Safety Considerations

- This is a local single-player game project; there is no network attack surface, no secrets management, and no user-authored content pipeline.
- `tools/play.sh` and the MCP screenshot server open local pipes under `/tmp/condor_*` — treat anything reading those pipes as trusted local automation only.
- Python tooling (`tools/*.py`) shells out to Inkscape for SVG geometry queries; run it only on project artwork, not untrusted SVG files.
- Fail-fast convention (`assert()`) is deliberate — do not add silent fallbacks that would mask corrupted save data or resources.
