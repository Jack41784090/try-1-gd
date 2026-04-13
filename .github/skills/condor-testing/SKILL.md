---
name: condor-testing
description: "CONDOR test conventions, demo scene catalog, and HeadlessStrategyView patterns. Use when writing tests, creating demo scenes, or running headless validation. Covers test pipeline, assertions, and all demo scenes in scenes/demos/."
---

# CONDOR Testing

## Demo Scene Catalog

All demo scenes in `scenes/demos/` — run with F6 in editor or via command line:

| Demo | Purpose | Command |
|------|---------|---------|
| `combat_controller_test.tscn` | Combat system tests | F6 |
| `combat_strategy_integration_test.tscn` | Combat↔strategy bridge | F6 |
| `scenario_attack_test.tscn` | Scenario attack flow | F6 |
| `ai_runner_demo.tscn` | AI squad brain decisions | F6 |
| `ai_battle_royale_demo.tscn` | Fleet simulation with headless combat | F6 |
| `ai_stress_test_demo.tscn` | 13-location, 8-squad, 50-turn stress test | F6 |
| `pause_system_test.tscn` | Pause/unpause, menu auto-pause, resting banner | `godot --headless --path . scenes/demos/pause_system_test.tscn` |
| `squad_battle_2d_demo.tscn` | 2D WarriorRig battle with skeletal animations | F6 |
| `stage_demo.tscn` | Warrior stage: rigs, march, speech bubbles, camera | F6 |
| `dialogue_demo.tscn` | Dialogue system (typewriter, after_id, interrupts) | `godot --headless --path . scenes/demos/dialogue_demo.tscn` |
| `ranged_combat_demo.tscn` | Ranged targeting, suppression, reach weapons | F6 |
| `aoe_combat_demo.tscn` | Splash damage, magical pierce, BattleContext lookup | F6 |
| `cinematic_instruction_demo.tscn` | GroupPlayback, CinematicGroup, JSON chains | Headless-only |
| `ai_act_demo.tscn` | Scripted game testing with assertions | `godot --headless --path . scenes/demos/ai_act_demo.tscn` |
| `economy_demo.tscn` | 3-location supply chain, 20-turn simulation | `godot --headless --path . scenes/demos/economy_demo.tscn` |
| `economy_stress_test.tscn` | 50-turn economy stress test (full pipeline) | `godot-mono --headless --path . scenes/demos/economy_stress_test.tscn` |
| `caravan_demo.tscn` | Economy→strategy caravan bridge | `godot --headless --path . scenes/demos/caravan_demo.tscn` |
| `contact_system_test.tscn` | Contact system unit tests (40 assertions) | `godot --headless --path . scenes/demos/contact_system_test.tscn` |
| `government_test.tscn` | Government directive system (40 assertions) | `godot-mono --headless --path . scenes/demos/government_test.tscn` |
| `guild_test.tscn` | Guild system (10 tests) | `godot-mono --headless --path . scenes/demos/guild_test.tscn` |
| `interactive_demo.tscn` | Terminal game with stdin commands | `godot-mono --headless --path . scenes/demos/interactive_demo.tscn` |
| `canvas_demo.tscn` | SVG drawing canvas with rig preview | `bash tools/start_canvas.sh` |

## Mandatory: Use Real Game Pipeline

**All demo/test scenes MUST use `HeadlessStrategyView` + `StrategyPresenter`** — the same code path as the real game. Never hand-build World/EconomyEngine/Population manually in tests.

**Load the real scenario**: `presenter.scenario_path = "res://resources/scenarios/goetz-official/scenario.tres"`. Let `GameScenario._setup_economy()` initialize population, natural resources, government config, and the economy engine.

**Drive time with `game_clock.force_tick()` + `await presenter.tick_completed`** — this runs the full hourly pipeline: AI turns, world systems (economy every 24h), contacts, activities, missions.

## Canonical Test Pattern

From `ai_act_demo.gd`:

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
    # Now drive ticks:
    presenter.game_clock.force_tick()
    await presenter.tick_completed
```

## Why This Pattern Matters

- Hand-built tests bypass TradeMatcher, EconomyOrchestrator, CaravanBridge, GovernmentDirectives, and contact system — they test a different game
- Economy parameters (base prices, bank config, population scale) diverge from the real scenario, producing misleading results
- The HeadlessStrategyView provides no-op UI methods allowing the full presenter pipeline to run headlessly

## AIAct Testing

`src/strategy/ai/ai_act.gd` — `AIAct` Resource with activity + assertions. `HeadlessStrategyView` (src/demos/headless_strategy_view.gd) mocks UI for headless StrategyPresenter runs.
