# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Every time when you make changes to the project, modify this file to reflect the changes made.

> **Copilot users**: This content is modularized for VS Code Copilot in `.github/`:
> - `copilot-instructions.md` — slim always-loaded workspace instructions
> - `instructions/combat.instructions.md` — auto-loaded for `src/squad-battle/**`
> - `instructions/strategy.instructions.md` — auto-loaded for `src/strategy/**`
> - `instructions/economy.instructions.md` — auto-loaded for `src/economy/**`
> - `skills/condor-testing/` — `/condor-testing` slash command for test workflows
> - `skills/condor-play/` — `/condor-play` slash command for interactive play
> - `skills/condor-animation/` — `/condor-animation` slash command for animation/VN/FX
>
> Customization policy for Copilot:
> - Do not default to editing existing instruction files for every request.
> - Choose action dynamically by scope: add/update skills for reusable workflows, create new skill/instruction directories for new domains, or edit an instruction file directly when the rule matches its existing scope.
> - Prefer modular additions over expanding one monolithic instruction file.

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
  - `scenes/animation_test.tscn` — F6 harness for `warrior_rig_2.tscn` (new-proportion rig). Instances the rig, applies a textured `WarriorRigConfig` (default `landsknecht.tres`, swappable in inspector), cycles behaviors via keys `1-8`/`←→`, `R` replays. Edit skeleton + animations in `warrior_rig_2.tscn`, then F6 `animation_test.tscn`. **Live texture hot-reload**: polls modified-times (0.4s) of the config `.tres` and each bone texture's source file; edits to the SVG art or to the config slots re-apply immediately without restart. Script: `src/demos/animation_test.gd`
  - `stage_demo.tscn` — warrior stage: rigs, march, speech bubbles, camera
  - `dialogue_demo.tscn` — dialogue system (typewriter, after_id, interrupts). Headless via `--headless`
  - `ranged_combat_demo.tscn` — ranged targeting, suppression, reach weapons
  - `aoe_combat_demo.tscn` — splash damage, magical pierce, BattleContext lookup
  - `cinematic_instruction_demo.tscn` — GroupPlayback, CinematicGroup, JSON chains. Headless-only
  - `warrior_rig_2_cutscene_demo.tscn` — recreates the **Faust Ch.1 parliament scene** (`schwarzwagen/CONDOR/Creative/Writing/Faust Official/Chapter 1.md`) with `warrior_rig_2` (new-proportion rig), driving **`GroupPlayback` directly (no `EventChain`)**. The cutscene is a single `CinematicGroup` `.tres` (`scenes/demos/warrior_rig_2_cutscene.tres`, id `parliament_ch1`) attached to the demo's `cutscene` `@export` — the only authoring surface (edit in the inspector or regenerate, no JSON, no runtime export key). Structure: sequential root group → ~78 `auto_gate=true` beat sub-groups, each `[CameraInstruction → optional CharacterInstruction(behavior) → DialogueInstruction]`. **9-character cast** with distinct looks via **per-character configs**: the demo exports `character_configs` (id→`WarriorRigConfig`, falls back to `config` for the Duchess/Gretchen rachelle look) and `seat_positions` (id→`Vector2` chamber seats; facing derived from x sign). Combined configs (class textures + warrior_rig_2 `*_size` block) live in `resources/animation/configs/rig2/rig2_*.tres`. Speaker→rig routing: `DialogueInstruction.speaker_name` must equal a `character_id` (case-insensitive) for the bubble to land on that rig (empty/`narrator`/unknown → narrator textbox; `System` used for the mute-vote banner). Narrative beats map to the 8 rig behaviors (sigil-cast/rise/paper → `gesturing`, paper-throw → `attacking`); map/sigil/ambient atmosphere render as narrator lines. Courier walks in from `OFFSCREEN_LEFT` (SHOW+MOVE), Gretchen is revealed (SHOW) on the final beat. Wiring: pre-spawns `warrior_rig_2` instances into `stage_view.rigs` so the pipeline uses them instead of `WarriorRigFactory`/`warrior_rig.tscn`; reuses `VnPresenter._on_instruction_fired` for stage dispatch (sets `character_ids_in_chain` directly, takes over `timeline_complete` since the presenter's default handler assumes a `current_chain`). `GroupPlayback` (`src/strategy/ui/vn/group_playback.gd`) is driven unmodified. Rig art hot-reloads per-character (polls each config's bone .svg mtimes every 0.4s). F6 to play: SPACE/click advances gates / fast-forwards, R replays. Headless self-test (`DisplayServer.get_name() == "headless"`) drives `on_input()` every frame (5× fast-forward) and asserts all instructions fire + completion (180s budget). Usage: `godot --headless --path . scenes/demos/warrior_rig_2_cutscene_demo.tscn`. Regenerate cutscene+configs: `python3 tools/build_parliament_cutscene.py`. Scripts: `src/demos/warrior_rig_2_cutscene_demo.gd`, `tools/build_parliament_cutscene.py`
  - `ai_act_demo.tscn` — scripted game testing with assertions. Usage: `godot --headless --path . scenes/demos/ai_act_demo.tscn`
  - `economy_demo.tscn` — 3-location supply chain, 20-turn simulation. Usage: `godot --headless --path . scenes/demos/economy_demo.tscn`
  - `economy_stress_test.tscn` — 50-turn economy stress test using real game pipeline (HeadlessStrategyView + StrategyPresenter + goetz-official scenario). Gini, starvation, class mobility, bank metrics. Usage: `godot-mono --headless --path . scenes/demos/economy_stress_test.tscn`
  - `caravan_demo.tscn` — economy→strategy caravan bridge. Usage: `godot --headless --path . scenes/demos/caravan_demo.tscn`
  - `bandit_demo.tscn` — bandit spawning system tests (faction setup, pressure calculation, forced spawn, route danger, mercenary demand, lifecycle/disband). Usage: `godot-mono --headless --path . scenes/demos/bandit_demo.tscn`
  - `contact_system_test.tscn` — contact system unit tests (40 assertions: state transitions, proximity, decay, focus, engagements). Usage: `godot --headless --path . scenes/demos/contact_system_test.tscn`
  - `government_test.tscn` — government directive system unit tests (40 assertions: tax, plan, execute, hire workers, budget constraints, snapshots). Usage: `godot-mono --headless --path . scenes/demos/government_test.tscn`
  - `guild_test.tscn` — guild system unit tests (10 tests: recruitment, production, wages, revenue, snapshots, real pipeline integration). Usage: `godot-mono --headless --path . scenes/demos/guild_test.tscn`
  - `interactive_demo.tscn` — terminal game with stdin commands. Usage: `godot-mono --headless --path . scenes/demos/interactive_demo.tscn`
  - `canvas_demo.tscn` — SVG drawing canvas with rig preview. Usage: `bash tools/start_canvas.sh`, then `bash tools/play.sh "info"`
- **Autoload singletons** (`project.godot`): `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`, `SFX`, `GrimdarkFX`
- **Sound generation**: `python3 tools/sound_designer.py` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
- Run relevant demo tests after logic changes.
- **AI Interactive Play** via `tools/play.sh`: auto-starts a dedicated game instance per session (no manual setup). `bash tools/play.sh "status"` — auto-generates `CONDOR_SESSION`, starts game, sends command. Set `export CONDOR_SESSION=<id>` for persistence across calls. GOD commands: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`. Flags: `--gui` (visible window for screenshots), `--stop` (kill session's game)
- **AI Interactive Play (GUI + screenshots)**: `bash tools/play.sh "screenshot" --gui` auto-starts with visible window. MCP server in `tools/mcp-screenshot/server.py` auto-starts its own game per instance — no manual setup needed
- **Per-agent game isolation**: Each agent gets a dedicated game instance via `CONDOR_SESSION`. `play.sh` auto-generates a session ID if unset. `start_game.sh [session_id]` / `start_game_gui.sh [session_id]` accept optional session IDs (default: `default`). MCP server auto-generates a unique session ID at startup. Pipes: `/tmp/condor_{input,output,pid}_<session>`
- **Screenshot workflow for AI agents**:
  1. Just call `bash tools/play.sh "status"` — game auto-starts (headless). For screenshots: `bash tools/play.sh "screenshot" --gui`
  2. Or start manually: `bash tools/start_game_gui.sh mysession` then `CONDOR_SESSION=mysession bash tools/play.sh "screenshot"`
  3. MCP tools (auto-discovered via `.vscode/mcp.json`): `screenshot_game` (command + screenshot), `view_screenshot` (last screenshot), `game_command` (text-only) — all auto-start their own game
  4. The `screenshot`/`ss` command in interactive_demo.gd uses `get_viewport().get_texture().get_image().save_png()` — only works in GUI mode, errors gracefully in headless
  5. Clock overlay: `ClockLabel` in top-left corner shows `⌚ HH:00`, updated by `StrategyView.update_clock()`
  6. Stop a session's game: `CONDOR_SESSION=<id> bash tools/play.sh --stop`
- **SVG Drawing Canvas** (`canvas_demo.tscn`): AI drawing sandbox — edit `.tscn` + `.svg` files, auto-reloads, screenshots via same pipes
  1. Start: `bash tools/start_canvas.sh [session_id]` — GUI window + per-session pipes. Defaults to session `canvas`
  2. **Multi-instance**: multiple canvases can run simultaneously with different session IDs: `bash tools/start_canvas.sh agent1`, `bash tools/start_canvas.sh agent2`
  3. Wait ~10s, then `CONDOR_SESSION=<id> bash tools/play.sh "info"` to verify
  4. **Free-form mode**: Edit `scenes/demos/canvas/default.tscn` (Sprite2D nodes with `metadata/svg_path`), edit SVGs in `scenes/demos/canvas/svgs/` — auto-reloads within 0.5s
  5. **Rig mode**: `CONDOR_SESSION=canvas bash tools/play.sh "rig landsknecht"` — loads warrior skeleton, applies SVG textures from `svgs/rig/landsknecht/` (15 bones: head, torso, hips, leftarm, etc.)
  6. Rig animations: `bash tools/play.sh "anim idle"` / `walk` / `attack` / `defend` / `hurt` / `die`
  7. Camera: `zoom 3.0`, `zoom_in`, `zoom_out`, `pan 500 300`, `center`
  8. Other: `grid` (toggle), `bg #1a1a2e` (background), `tree` (node dump), `sizes` (bone dimensions), `shader <node> <param> <value>`
  9. SVG viewBox sizes (base ×4): Head=176×200, Torso=136×112, Hips=112×32, Arm=40×88, Forearm=32×72, Hand=56×56, Leg=48×104, Shin=40×88, Foot=80×40
  10. Shaders: put `.gdshader` files in `assets/shaders/canvas/`, reference from canvas `.tscn` as ShaderMaterial — auto-reloads on edit
  11. Same MCP tools work (`screenshot_game`, `view_screenshot`, `game_command`) — uses identical pipe files
  12. **Concurrency**: `play.sh` uses `flock` per-session to serialize commands from parallel agents. `canvas_demo.gd` debounces file-watch reloads (0.3s) and gates commands/reloads behind `_busy` flag

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
   - `GameScenario` (core/scenario.gd) — main orchestrator. `_setup_economy()` asserts all non-FORT locations have inventory, validates shops require inventory
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
- **GrimdarkFX** (`src/singletons/grimdark_fx.gd` + `scenes/grimdark_fx.tscn`): `GrimdarkFX` autoload, atmospheric shader system. Two layers: texture-based (applied to bg/fg) + overlay (CanvasLayer 200). Disabled in headless
  - **World atmosphere** (`assets/shaders/fx/world_atmosphere.gdshader`): Applied directly to MainBackground and Foreground TextureRect via `register_world_textures()`. Time-of-day tinting (night=blue, dawn=amber, dusk=orange), desaturation, contrast boost, integrated fbm fog wisps. Auto-updates via `StrategyEventBus.hour_advanced`
  - **Vignette** (`assets/shaders/fx/vignette.gdshader`): Dark radial edges overlay, intensifies at night
  - **Film grain** (`assets/shaders/fx/film_grain.gdshader`): Subtle animated noise overlay, salt-and-pepper speckle
  - **Damage pulse** (`assets/shaders/fx/damage_pulse.gdshader`): Red vignette flash overlay, triggered via `GrimdarkFX.trigger_damage_pulse()`
  - **Combat atmosphere** (`assets/shaders/fx/combat_atmosphere.gdshader`): Desaturation + contrast + red shift overlay during combat, uses screen texture. `GrimdarkFX.set_combat_mode(true/false)`
- **UIAnimations** (`src/utils/ui_animations.gd`): static class — `register_button()` (hover/press/SFX), `show_overlay/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`, `pulse()`, `animate_label_number()`
- **Log** (`src/singletons/log.gd`): static `class_name Log`. Levels: TRACE/DEBUG/INFO/WARN/ERROR. `Log.info("Source", "msg")`, `Log.mute()`, `Log.set_level()`. Default: DEBUG
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond font, multi-use styles via `theme_type_variation`, single-use via `theme_override_*` or standalone `.tres` in `resources/theme/styles/`. `ThemeConstants` (`src/utils/theme_constants.gd`) for GDScript color/size constants
- **Data models**: `SquadData` (src/squad/social.gd), `CombatSquad` (src/squad/combat.gd), `CargoManifest` (src/squad/cargo_manifest.gd), `Warrior` (src/character/social.gd), `CombatEntity` (src/character/combat.gd)
- **Animation** (`src/animation/`): 5-layer system — Clips→iExpression→AnimAction→Behavior→WarriorAnimController. `WarriorRig` (warrior_rig.gd) generates placeholder Polygon2D body parts, `apply_config()` replaces with textures. `WarriorRigConfig/Factory` for per-class configs. **Texture sizing** is config-driven: `WarriorRigConfig` has per-bone `*_size` Vector3 + `*_offset` Vector2 fields (defaults match `WarriorRig.BONE_DISPLAY_SIZES`/`BONE_OFFSETS`, so untouched configs render identically). The `*_size` vector packs render size in `x`/`y` (px) and **draw order in `z`** (the sprite's `z_index`, higher draws in front, overriding `BONE_DRAW_ORDER` tree order). `_replace_limb()` scales each sprite to `target_size / texture_size` and applies `size.z` as `z_index`; a zero size x/y falls back to the rig constant. Set per-config sizes to fit a character's proportions (e.g. `warrior_rig_2`)
- **Rig Art Style**: 2D anime SD (super deformed) flat vector — clean 2px black outlines, solid color fills, no gradients or cross-hatching, 1:2.5 head-to-body ratio, **3/4 right-facing profile** (big eye on LEFT/near, small eye on RIGHT/far, nose bump on right edge). Z-order: Right* limbs drawn behind (far), Left* limbs in front (near). SVG textures in `assets/rig_textures/<class>/` (15 bones × 7 classes = 105 SVGs). Canvas demo copies in `scenes/demos/canvas/svgs/rig/<class>/`. Generator: `python3 tools/generate_sd_svgs.py`. Grain shader overlay: `assets/shaders/canvas/rugged_grain.gdshader` (grain + scratches + vignette + sepia)
  - **SVG clip baking** (`tools/bake_svg_clips.py`): Detailed hand-authored heads (e.g. `rachelle/_head.svg`) live as `_*.svg` sources; the bake tool emits Godot-loadable `*.svg`. Godot's ThorVG renderer (1) ignores `<use>` inside `<clipPath>` and (2) silently drops clip shapes buried in nested `<g>` wrappers — the latter let dark "shadow" gradients overflow as black smudges around the eyes. The tool resolves clip `<use>` refs, then **flattens** each `<clipPath>` to bare shapes with all ancestor `<g>`/`<use>` transforms composed down. Usage: `python3 tools/bake_svg_clips.py` (all `_*.svg`) or pass specific paths. Re-run after editing any `_*.svg`
- **Animation Style**: Dramatic weighted movement — idle (2s slow breathe), walk (1s heavy stride with shin bend), attack (0.9s explosive wind-up), defend (0.7s bracing), hurt (0.6s stagger), die (1.5s tragic collapse with alpha fade), talk (1.6s weighted gestures), gesture (1s dramatic flourish)
- **Warrior Stage** (`src/strategy/ui/stage/`): `StageView` + `StagePresenter` — shared 2D viewport for march and VN. Modes: MARCH/VN/HIDDEN. `SpeechBubble` with typewriter effect, `StageCamera` with tween-based focus
- **Visual Novel** (`src/strategy/ui/vn/`): `EventChain` triggers via `event_chain_path` in results. `VnPresenter` is stage-aware (speech bubble on rig or fallback textbox). `DialogueInstruction` (instructions/dialogue_instruction.gd) extends `CinematicInstruction` with speaker_name, line_spoken, after_id. `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate). `CharacterInstruction` (SHOW/HIDE + StageAnchor), `CameraInstruction` (screen position panning). `CinematicGroup`/`CinematicInstruction` `@export` all playback fields (`children`, `occupation`, `target_screen_position`, `anchor`/`anchor_offset`) so a group round-trips through `ResourceSaver.save()`/`load()` as a standalone reusable `.tres` cutscene (no `EventChain` wrapper needed) — feed the loaded `CinematicGroup` straight to `GroupPlayback.load_group()`
- **Strategic AI** (`src/strategy/ai/`): Data-driven Consideration scoring
  - `AISquadManager` (squad_manager.gd) — `prepare_ai_turns()` runs brain decisions, `cleanup_defeated_squads()`. Owns the `BanditSpawner` helper and exposes `tick_bandit_lifecycle(faction)`. Uses unified `register_squad(squad, profile_path="")` for caravan/bandit/other AI squads
  - `AIProfileFactory` (profile_factory.gd) trims incoming profile paths and falls back to `balanced-roamer` when a custom profile path fails; default-profile load remains assert-critical
  - `SquadBrain` (squad_brain.gd) — evaluates considerations, picks highest-scoring action
  - Pattern: `StrategicGlance` → `StrategicConsideration` → `SquadBrainConfig` → `SquadBrain`. Authored as .tres in `resources/ai/strategic/`
  - `StrategicSituation` (situation.gd) — lazy BFS snapshot. **Contact-gated**: enemies require SUSPECTED+ contact
  - Three profiles: aggressive-hunter, balanced-roamer (default), cautious-survivor
  - **Patrol→Detect→Pursue**: patrol builds contact via ContactTracker → hunt-enemies/attack activate on detection
- **AIAct Testing** (`src/strategy/ai/ai_act.gd`): `AIAct` Resource with activity + assertions. `HeadlessStrategyView` (src/demos/headless_strategy_view.gd) mocks UI for headless StrategyPresenter runs
- **UI** (`src/strategy/ui/`): View/Presenter MVP. View calls `presenter.on_X()`, Presenter calls `view.update_X()`
  - `StrategyView/Presenter` — top-level. Two orchestrators: `CombatOrchestrator`, `ContactOrchestrator`. Economy is owned by `EconomyEngine` directly (no orchestrator); presenter's `_run_economy_tick()` is a ~70-line bridge between `EconomyEngine.tick_full()` and `AISquadManager`. Unified turn pipeline in `_on_hour_tick()`
  - `TravelView/Presenter` — AUTOPILOT/MANUAL/GOING state machine
  - `ShopView/Presenter` — cart system with stock-aware purchasing from LocationInventory
  - `ScoutingView/Presenter` — hover slide-in panel from left edge. Tab peeks out, hover slides panel in with tween. Auto-refreshes contact data on open. `bind()` stores world/squad refs, called on setup and each tick
  - `SquadLogView` (`src/strategy/ui/squad_log/view.gd`) — right-side slide-in chatbox panel. Logs real-time squad events: activity changes, stat deltas, combat results, travel, contacts, recruitment, purchases, missions. Tab peeks from right edge with hover/click/pin behavior (mirrors ScoutingView). Unread count badge on tab. Replaces old activity result popup overlay
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
  - **Trade pipeline**: GDScript precomputes an NxN `danger_matrix` of route-safety values (via `RouteDangerCalculator` + `world.find_path`) and passes it to a single `CsEconomyBridge.Tick(turn, danger_matrix)` call. C# `Tick()` runs all 25 phases per location in one mega-loop, then internally scores Supply→Demand pairs using `(margin * 0.4 + urgency * 0.6) * safety`, creates `EconomyMove`s, and attaches `CsShipmentDispatch` to the result. `EconomyEngine.tick_full()` reads `shipment_dispatches` directly from the tick result, emits `mercenary_work_changes`, and `StrategyPresenter._run_economy_tick()` materializes dispatches as MERCHANT squads via `CaravanBridge` and notifies engine on arrival/defeat. Two bridge calls per tick total: `Tick(turn, danger_matrix)` and `SyncBackToGdScript()`.
  - **TradeMatcher** (`trade_matcher.gd`): Greedy matching engine. Creates `TradeSituation` per pair, scores via considerations or default `(margin * 0.4 + urgency * 0.6) * safety`
  - **RouteDangerCalculator** (`route_danger.gd`): Route safety (0-1) based on aggressive squads along connections. Per-edge safety = `1.0 / (1.0 + threats)`. Route = product of edges
  - Features: input-based production chains, FIFO cost-basis tracking, elastic demand, dynamic population (starvation/birth), social mobility, central bank, food spoilage (5%/turn)
  - **PersonBrain System** (`PersonBrain`, `NobleBrain`, `CommonBrain`): Lightweight per-person decision-making. Each `CsPerson` has a nullable `Brain` field. `PhasePersonDecisions` runs all brains at tick start — replaces old automatic `PhaseBankLending`. `NobleBrain` evaluates loan applications using weighted scoring (desperation 0.4, satisfaction 0.25, food prices 0.15, debt penalty -0.3, stable per-person risk tolerance from InternalId hash). `CommonBrain` is a shared singleton no-op for non-nobles. Brains assigned on creation (factory methods, MirrorPerson bridge, birth) and updated on social mobility
  - **Gradual Pricing** (`PhasePriceUpdate`): Prices adjust incrementally (max 15%/tick) based on supply/demand imbalance instead of snapping to equilibrium. Goods-specific stickiness: food 1.2× (responds faster), weapons 0.6×, luxury 0.5×. Location tracks `LastDemand[]`/`LastSupply[]` per good. Result: prices linger at high levels during shortages, compounding peasant suffering
  - **Scarcity Markup** (`PhaseMarket`): Within each tick, as stock depletes (wealthiest buy first), remaining buyers face quadratic scarcity markup (up to 50% at full depletion). Rich buyers get base price, poor buyers hit inflated prices. Models how inflation disproportionately affects lower classes
  - **Market revenue**: Consumer purchases split 85% to producers (farmers+craftsmen), 15% merchant commission. Money-conserving — no revenue leakage
  - **Food spoilage**: `PhaseSpoilage` decays 5% of food stocks per turn, preventing infinite accumulation
  - **Population sync**: `SyncBackToGdScript()` uses PersonId-based matching to handle births/deaths correctly. `Population.remove_person()` for death sync
  - **Bank metrics**: `engine.get_bank_info()` reads C# CsCentralBank state (printed/reserves/loans/debt). GDScript CentralBank is config-only
  - **Government Directives** (`CsGovernment`, `CsDirective`, `GovernmentBrain`): Per-location government with treasury, tax collection, and AI-driven directives. 3 phases in tick: GovernmentTax (collect from people with >10 money), GovernmentPlan (`GovernmentBrain.Evaluate()` analyzes worker gaps in natural resources, creates HireWorkers directives within budget), GovernmentExecute (process directives: hire from unemployed/laborers, pay wages). `GovernmentConfig` Resource on Location configures push/pull weights, tax rate, starting treasury, priority goods. Auto-generated in `_setup_economy()` for locations without one
  - **Guild System** (`CsGuild`, `GuildBrain`, `GuildConfig`): Per-location crafting guilds that recruit workers, produce high-value goods, and feed into the trade pipeline. 2 phases in tick (after GovernmentExecute): PhaseGuildRecruit (hire unemployed/laborers as craftsmen via GuildBrain), PhaseGuildProduce (consume inputs, output goods, pay wages, collect 10% revenue commission). `GuildConfig` Resource on Location configures guild_name, specialization (Thing), max_workers, wage_per_worker, starting_treasury, recruitment_rate. First guild: Nürnberg Smithing Guild (swords from 2 iron + 1 wood). Guild-produced goods flow into LocationInventory → TradeMatcher → merchant caravans automatically
  - C# engine (`src/economy/csharp/`): `CsEconomyBridge.Setup(world)` → `Tick(turn, dangerMatrix)` → `SyncBackToGdScript()`. The engine consolidates all per-location work into a single mega-loop (PHASE B: spoil → prices → orders → produce → subsist → match-orders → contracts → market → household → rent → gov → guild → pop state → geist → snapshot) bracketed by PHASE A (pre-tick globals: move advance, contract WorkOneTurn) and PHASE C (post-tick globals: contract wages, imperial spending). PHASE D runs the internal trade matcher using the supplied danger matrix. Build: `dotnet build`. Run with `godot-mono`
  - **Person sync via `sync_full()`**: `EconomyEngine.tick_full()` calls `engine.sync_full()` after each tick to propagate person money/satisfaction/class from C# back to GDScript. Without this, GDScript-side readings remain stale
- **Caravan Bridge** (`src/economy/caravan_bridge.gd`): `CaravanBridge` materializes trade dispatches as MERCHANT squads. Caravans now use `SquadBrain` with `caravan-courier` profile and always move toward destination unless out of food or low morale (tired). Lifecycle: dispatch → spawn/reassign → pathfind → deliver → idle → reassign/despawn
  - **Bandit System** (`src/strategy/ai/bandit_spawner.gd`, `src/economy/mercenary_demand.gd`): Desperation-driven bandit spawning. `BanditSpawner.calculate_pressure(location)` reads population satisfaction + peasant ratio → spawns BANDIT squads near distressed locations. Bandit AI brain (`bandit-raider.tres`) hunts merchants, attacks weak enemies, patrols. `RouteDangerCalculator` applies 1.5× threat for BANDIT role. `MercenaryDemandCalculator` computes trade loss vs hire cost, dynamically adds/removes MERCENARY_WORK at locations. `MercenaryWorkHandler` targets real bandits with bounty rewards. Lifecycle: pressure→spawn→roam→attack merchants→disband (low morale/all injured). `AISquadManager.tick_bandit_lifecycle(faction)` runs spawn+cleanup each economy tick (called from `StrategyPresenter._tick_world_systems`). Bandit faction auto-created in `GameScenario._setup()`

### Key Enums

- Entity Classes: `src/character/classes-enum.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter
- Weapons: `src/squad-battle/weapon/_factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire
- Armor: `src/squad-battle/armor/_factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate
- Logic: `src/squad-battle/entity/logic/_factory.gd` — Frontline, BacklineHeal, BacklineShooter, DefensiveFrontline, BacklineSupport, BacklineGunner, BacklineCaster
- Combat: `src/squad-battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome
- Strategy: `src/strategy/types.gd` — LocationType, ActivityType, ContactState, EngagementType, SquadRole (COMBAT, MERCHANT, BANDIT)
- Strategic AI: `src/strategy/ai/types.gd` — GlanceSubject (SQUAD, LOCATION, WORLD, FACTION, TRADE), SquadGlanceable, TradeGlanceable, DestinationStrategy, TargetStrategy
- Economy: `src/economy/types.gd` — SocialClass, JobType, MoveState, ThingType (FOOD, CLOTH, LUXURY, TOOLS, WEAPONS), DirectiveType
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
- **Instantiate squads through `SquadDataFactory.create_squad(config)`** to centralize shared field wiring (id, name, role, economy stats, location)
- **Don't use `preload`** on "class not found" errors. **Don't export RefCounted** types. **Don't use `class_name` for inner classes**
- **`Resource.duplicate(true)` does NOT deep-copy external `.tres` sub-resources** — always explicitly duplicate: `activity.result = activity.result.duplicate(true)`
- **Never programmatically create GUI elements** — define in `.tscn`, use `@onready` refs
- **Pre-built hidden nodes over scene instantiation** for bounded lists. Scene instantiation only for unbounded/compositional needs. Collect pools in `_ready()` from container children; hide all initially. Set `visible = true` with demo text in `.tscn` for editor preview
- **Compartmentalize GUI into scenes** — each distinct UI component gets its own `.tscn`. Item templates: `shop_item_row.tscn`, `recruitment_class_item.tscn`, `investigation_clue_item.tscn`, `contact_mini_bar.tscn`
- **Custom-drawn Controls must also be `.tscn` scenes** — even pure `_draw()` components get their own scene file with layout/size defaults baked in. Prefer SVG assets over runtime `_draw()` when possible

### Terminal / File Operations
- **Never use `cat` heredoc** for GDScript files (strips tabs). Use Python `with open()` or `replace_string_in_file`
- Commit after each code update. Only add+commit your own changes
- **Sprint logging**: After committing, append commit summary to the current week's sprint file at `~/Documents/schwarzwagen/CONDOR/Sprints/2026/Q2/April/W<N>.md` (or the appropriate quarter/month). Use ISO week numbers (W14=Mar 30, W15=Apr 7, W16=Apr 14, W17=Apr 21). Add commit messages under a `## Commits` section. If the sprint file has only YAML frontmatter, add a summary section and commits block

### Critical Pitfalls
- **Typed array assignment**: Never assign from `Dictionary.get()` to typed arrays. Iterate and append with type checks
- **Squad positions**: `Front = 1`, `Middle = 2`, `Back = 3` (NOT zero-indexed). Forward = -1, retreat = +1
- **Entity updates**: All combat state changes return `EntityUpdate` containing `EntityChange`
- **Never use `+=` on label text for state indicators** — store the base text and rebuild. Repeated calls append duplicates (e.g., `"[PAUSED][PAUSED][PAUSED]"`)
- **Single source of truth for time progression** — `GameClock` owns `world.current_hour`. Never overwrite it from `ActivityRunner` or other subsystems. Only one place should emit `hour_advanced`
- **Unit conversion on system migration** — when changing time granularity (turns→hours), audit ALL hardcoded numeric constants: decay timers, condition thresholds in `.tres` files, age description breakpoints. A "5" that meant "5 days" becomes "5 hours" if not scaled
- **Wire up all lifecycle methods** — if a method like `decay_clues()` exists, verify it's actually called somewhere. Dead code that looks functional is worse than missing code
- **Keep `src/` warning-clean** — avoid shadowing built-ins (e.g. `log`, `sign`), remove unused vars/signals/params, and avoid enum sentinel ints like `-1`

## Testing Conventions

### Mandatory: Use Real Game Pipeline
- **All demo/test scenes MUST use `HeadlessStrategyView` + `StrategyPresenter`** — the same code path as the real game. Never hand-build World/EconomyEngine/Population manually in tests
- **Load the real scenario**: `presenter.scenario_path = "res://resources/scenarios/goetz-official/scenario.tres"`. Let `GameScenario._setup_economy()` initialize population, natural resources, government config, and the economy engine
- **Drive time with `game_clock.force_tick()` + `await presenter.tick_completed`** — this runs the full hourly pipeline: AI turns, world systems (economy every 24h), contacts, activities, missions

### Canonical Test Pattern (from `ai_act_demo.gd`)
```
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
    # Now drive ticks:
    presenter.game_clock.force_tick()
    await presenter.tick_completed
```

### Why This Matters
- Hand-built tests bypass TradeMatcher, EconomyEngine.tick_full, CaravanBridge, GovernmentDirectives, and contact system — they test a different game
- Economy parameters (base prices, bank config, population scale) diverge from the real scenario, producing misleading results
- The HeadlessStrategyView provides no-op UI methods allowing the full presenter pipeline to run headlessly

## File Organization

- `src/squad-battle/` — combat engine (data.gd model, presenter.gd, view_2d.gd, entity/, weapon/, armor/, clash/)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable, shop, contact, activity handlers
- `src/strategy/ui/` — View/Presenter per feature (stage/, vn/, travel/, shop/, scouting/, squad_log/, missions/, market/, manage_squad/, investigation/, recruitment/)
- `src/strategy/ui/actor/` — ActivityExecuteManager (!main.gd), ActivityRunner, AI executors
- `src/strategy/ai/` — fleet manager, squad brain, considerations, glances, actions, caravan brain
- `src/animation/` — WarriorRig, configs, expressions, actions, controller
- `assets/rig_textures/` — SVG bone textures per class (landsknecht, healer, crossbowman, arquebusier, pikeman, feldprediger, gelehrter)
- `src/character/` — Warrior (social.gd), CombatEntity (combat.gd), classes enum
- `src/squad/` — SquadData, CombatSquad, CargoManifest
- `src/economy/` — engine, types, thing, person, population, inventory, caravan bridge, government_config, guild_config; `csharp/` for C# engine (CsDirective, CsGovernment, GovernmentBrain, CsGuild, GuildBrain)
- `src/singletons/` — event buses, SFX, Log
- `resources/scenarios/goetz-official/` — main campaign (7 locations, ~7420 population)
- `resources/ai/strategic/` — AI behavior .tres files
- `resources/generic-activities/` — Activity .tres files
- `resources/theme/` — condor_theme.tres, styles/, bold_font.tres
- `scenes/demos/canvas/` — SVG drawing canvas: editable `.tscn` layouts + `svgs/` directory + `svgs/rig/<class>/` bone SVGs
- `assets/shaders/canvas/` — canvas shader experiments
- `assets/shaders/fx/` — grimdark shaders: world_atmosphere (texture-applied), vignette, film_grain, damage_pulse, combat_atmosphere (overlays)
