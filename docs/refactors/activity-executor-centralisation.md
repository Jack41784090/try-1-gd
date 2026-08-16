# Refactor Exploration — Centralise Activity Dispatch into One Executor

> Status: **exploration only, no code changes.** Scope: collapse the
> `ActivityHandler` subclass hierarchy + `ActivityRegistry` into a single
> match-dispatched executor class, and resolve the travel-logic duplication.

## 1. Why

The per-activity-type behavior is spread across 14 files whose only structural
purpose is enum dispatch: `Activity.execute()` asks a static, lazily-built
`ActivityRegistry` for an `ActivityHandler` subclass keyed by
`StrategyTypes.ActivityType`. The hierarchy exists purely to switch on an enum
— which `match` does natively. Per AGENTS.md, inheritance is reserved for cases
where Godot's own architecture requires it; this is not one of them.

On top of that, travel behavior now exists in **three places** since the
Systems-layer prototype landed, and the handler for it is bypassed on the new
path entirely.

## 2. Current state (as-is)

### The format

`Activity` (`src/strategy/core/triggerable/activity/script.gd`) is a
`Triggerable` Resource, authored as `.tres` under
`resources/strategy/generic-activities/`:

- **From Triggerable**: `trigger_id`, `trigger_name`, `description`,
  `conditions`, `trigger_chains`, `chance`, `emergency_priority`
- **Own fields**: `result: ActivityResult`, `activity_type: ActivityType`,
  `time_cost`, `destination_id`, `attack_config`, `force_march_config`,
  `custom_script` (**dead — exported but never read anywhere**),
  `ultimate_destination_id` (runtime-only, force-march double hop)
- **`execute(context)`**: duplicates `result` (shared template protection),
  looks up a handler via static `_registry`, handler mutates world/result,
  then fires `trigger_chains`
- **Pure-data activities** (REST, DRILL, HOLD_MASS, MANAGE_SQUAD, CUSTOM): no
  handler at all — effects live entirely in `result.squad_stat_changes` in the
  `.tres`, applied by `ActivityExecuteManager._apply_result()`

### The dispatch infra

```
        ┌──────────────────────────────────────┐
        │  Activity.execute(context)           │   script.gd:46
        │    result = result.duplicate(true)   │
        │    handler = _get_registry()         │◄── static var _registry
        │              .get_handler(type)      │
        │    handler.execute(context, result)  │
        │    run trigger_chains                │
        └──────────────┬───────────────────────┘
                       ▼
             ActivityRegistry            registry.gd — hardcoded dict
                       │
                       ▼
             ActivityHandler (base)      handler.gd
              ├── attack.gd
              ├── travel.gd         ◄── bypassed & duplicated (see below)
              ├── force_march.gd
              ├── recruit.gd        ◄── assert(false) stub
              ├── investigate.gd
              ├── forage.gd
              ├── heal.gd
              ├── buy_supplies.gd
              ├── mercenary_work.gd
              └── patrol.gd              10 files, one class each
```

### Two entry paths, three travel copies

```
        legacy:  presenter.gd ──► ActivityRunner (Node)
                 _on_hour_tick     │ holds walking_towards state
                                   │ create_travel_activity() — ~80 lines
                                   │ of km/segment movement (runner.gd:138)
                                   ▼
        new:     SquadBeingSystem ──squad_turn──► ActivityRunSystem
                                                     │
                                                     │ TRAVEL? ─yes─► request_travel
                                                     │                    │
                                                     │                    ▼
                                                     │        SquadTravelSystem
                                                     │        .advance_travel()
                                                     │        inlines supplies/morale:
                                                     │        "mirrors TravelHandler.
                                                     │        execute(), which this
                                                     │        path bypasses"
                                                     │        (squad_travel_system.gd:94)
                                                     ▼
                                               Activity .tres lookup → AEM → execute()
```

Travel is the odd one out for four reasons:

1. **Multi-hour, km-based** — every other activity resolves in one tick
2. **Runtime-constructed** — the `.tres` is a shell; destination/route are
   stamped in per tick
3. **Its handler is bypassed** on the Systems path — supplies/morale logic is
   duplicated inline in `SquadTravelSystem.advance_travel()`
4. **Own UI state machine** (AUTOPILOT/MANUAL/GOING) in TravelPresenter

### Infra count today

1 registry + 1 base class + 10 handler files + static singleton on Activity +
travel logic in 3 places.

## 3. Target shape (to-be)

One `ActivityExecutor` (RefCounted) owning all per-type behavior:

```
        ActivityRunSystem ─────────────────────────────┐
              │                                        │ TRAVEL
              │ resolve Activity .tres                 ▼
              ▼                              SquadTravelSystem
        ActivityExecuteManager               (owns ALL travel:
              │ context, before/after,        route + km + supplies/
              │ result application            morale — one place)
              ▼                                        ▲
        ┌──────────────────────────────┐               │
        │ Activity.execute(context)    │               │
        │   result = dupe              │               │
        │   ActivityExecutor.execute() │               │
        │   run trigger_chains         │               │
        └──────────────┬───────────────┘               │
                       ▼                               │
        ┌──────────────────────────────────────┐       │
        │  ActivityExecutor  (ONE RefCounted)  │       │
        │                                      │       │
        │  can_execute(activity, squad, loc):  │       │
        │    match type: ATTACK: ...           │       │
        │                                      │       │
        │  execute(activity, context):         │       │
        │    match activity.activity_type:     │       │
        │      ATTACK:      <attack.gd body>   │       │
        │      FORCE_MARCH: <force_march body> │       │
        │      FORAGE:      <forage.gd body>   │       │
        │      HEAL:        ...                │       │
        │      TRAVEL:  ────────────────────────┼───────┘ (or branch dies;
        │      _:  pass   # pure-data types    │        ActivityRunSystem
        └──────────────────────────────────────┘        already redirects)

        DELETED: registry.gd, handler.gd, handlers/ (10 files),
                 static _registry, custom_script field
```

```
        files:  14 ──► 2        travel logic copies:  3 ──► 1
```

Each handler body moves **verbatim** into its match branch (~400 lines total,
same combined size as today). The `.tres` files stay pure data. AEM is
untouched — it's phase orchestration (context building, before/activity/after
triggerables, result application), not per-type dispatch. AI path unaffected:
`ActivityExecuteManager(true)` shares `Activity.execute()`.

## 4. Steps

1. Create `ActivityExecutor` in `src/strategy/core/activity/executor.gd` with
   `can_execute(activity, squad, location) -> bool` and
   `execute(activity, context) -> ActivityResult`, each a `match` on
   `activity.activity_type`
2. Move the 10 handler bodies verbatim into branches (recruit keeps its
   assert-stub)
3. Repoint `Activity.execute()`/`can_execute()` at the executor; delete
   `static var _registry` and `_get_registry()`
4. Delete `handler.gd`, `handlers/`, `registry.gd` and their `.uid` files;
   delete the dead `custom_script` export
5. Travel: fold `TravelHandler`'s supplies/morale into
   `SquadTravelSystem.advance_travel()` (already mirrored there); the
   executor's TRAVEL branch either delegates to the travel system or is
   deleted outright since `ActivityRunSystem` redirects before `execute()`
6. Verify: `pause_system_test`, `ai_act_demo`, `contact_system_test` demos +
   a manual `scenario.tscn` run exercising rest/travel/attack

## 5. Open questions

- **Executor access**: static singleton on `Activity` (minimal call-site
  changes, matches today's `_get_registry()` shape) vs. injected via context
  by AEM (no statics, easier to test)
- **Legacy path**: delete `ActivityRunner.create_travel_activity()` +
  presenter special-case in the same pass, or keep until the Systems layer
  replaces `scenario.tscn` as the main scene
- **FORCE_MARCH double-hop** lives in the handler today but is travel-shaped;
  consider moving it next to `advance_travel()` rather than into the executor
