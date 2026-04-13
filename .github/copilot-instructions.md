# CONDOR — Copilot Workspace Instructions

CONDOR — squad-based narrative strategy game. **Godot 4.5**, **GDScript**, **C#**. Requires `godot-mono` + `dotnet build` for C# economy engine (`try1.csproj`, Godot.NET.Sdk/4.6.0, net8.0).

Three-layer architecture: Tactical Combat (`src/squad-battle/`), Strategic Campaign (`src/strategy/`), Economy (`src/economy/`). Combat Bridge connects tactical↔strategic.

Run main scene: F5 (`scenario.tscn`). Demo scenes in `scenes/demos/` — run with F6. Autoload singletons: `StrategyEventBus`, `StatusEffectEventBus`, `DamageNumbersManager`, `SceneManager`, `SFX`, `GrimdarkFX`.

For detailed architecture of each subsystem, see file-specific instructions (auto-loaded when editing relevant files). For testing, interactive play, and animation workflows, use the `/condor-testing`, `/condor-play`, and `/condor-animation` skills.

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
- **Pre-built hidden nodes over scene instantiation** for bounded lists. Scene instantiation only for unbounded/compositional needs
- **Compartmentalize GUI into scenes** — each distinct UI component gets its own `.tscn`
- **Custom-drawn Controls must also be `.tscn` scenes** — prefer SVG assets over runtime `_draw()` when possible

### Terminal / File Operations
- **Never use `cat` heredoc** for GDScript files (strips tabs). Use Python `with open()` or `replace_string_in_file`
- Commit after each code update. Only add+commit your own changes

### Critical Pitfalls
- **Typed array assignment**: Never assign from `Dictionary.get()` to typed arrays. Iterate and append with type checks
- **Squad positions**: `Front = 1`, `Middle = 2`, `Back = 3` (NOT zero-indexed). Forward = -1, retreat = +1
- **Entity updates**: All combat state changes return `EntityUpdate` containing `EntityChange`
- **Never use `+=` on label text for state indicators** — store the base text and rebuild
- **Single source of truth for time progression** — `GameClock` owns `world.current_hour`. Never overwrite from other subsystems
- **Unit conversion on system migration** — when changing time granularity, audit ALL hardcoded numeric constants
- **Wire up all lifecycle methods** — verify methods are actually called somewhere
- **Keep `src/` warning-clean** — avoid shadowing built-ins, remove unused vars/signals/params

## Key Enums

- Entity Classes: `src/character/classes-enum.gd` — Landsknecht, Healer, Crossbowman, Arquebusier, Pikeman, Feldprediger, Gelehrter
- Combat: `src/squad-battle/types.gd` — Potency, DamageType, Reality, EntityChangeable, BattleOutcome
- Strategy: `src/strategy/types.gd` — LocationType, ActivityType, ContactState, EngagementType, SquadRole
- Economy: `src/economy/types.gd` — SocialClass, JobType, MoveState, ThingType, DirectiveType
- Animation: `src/animation/types.gd` — AnimTypes.Behavior (IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING)

## File Organization

- `src/squad-battle/` — combat engine (data.gd, presenter.gd, view_2d.gd, entity/, weapon/, armor/, clash/)
- `src/strategy/core/` — world, scenario, faction, travel, triggerable, shop, contact, activity handlers
- `src/strategy/ui/` — View/Presenter per feature (stage/, vn/, travel/, shop/, scouting/, squad_log/, missions/, market/, manage_squad/)
- `src/strategy/ai/` — fleet manager, squad brain, considerations, caravan brain
- `src/animation/` — WarriorRig, configs, expressions, actions, controller
- `src/economy/` — engine, types, populations, inventory, caravan bridge; `csharp/` for C# engine
- `src/singletons/` — event buses, SFX, Log
- `resources/scenarios/goetz-official/` — main campaign (7 locations, ~7420 population)
