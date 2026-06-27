# Refactor Exploration — Composition for `CombatEntity`

> Status: **exploration only, no code changes.** Scope chosen: write a design/migration
> doc for one subsystem before touching anything. Subsystem: the combat entity model.

## 1. Why this subsystem first

`CombatEntity` is the clearest instance of the smell the whole refactor is reacting to:
**a `Resource` that is actually used as a live, mutable runtime actor.** Fixing it is
high value (it sits at the center of the tactical sim) and low risk (the sim is already
headless and deterministic, so behavior is easy to pin down with the existing demos).

It is *not* a candidate for Node-component composition — the combat core is a turn-based,
headless, immutable-update simulation (`SquadBattle.execute() -> Array[EntityUpdate]`).
Pushing it into the scene tree would trade away headless testability and serialization for
`_process`/signal coupling we don't want. The right composition move here is the
**template / runtime split**, not "make it a Node."

## 2. Current state (as-is)

`src/character/combat.gd` — `class_name CombatEntity extends Resource`. A single class plays
two incompatible roles:

| Role | Evidence |
|---|---|
| **Authored template** (serializable `.tres`) | `@export var class_id/entity_name/stats/icon/weapon_class/armor_class/logic_config`; loaded via `EntityFactory.get_entity()` then `init_from_resource()` |
| **Live battle actor** (mutable runtime) | `changeable_stats` dict mutated per clash, `retreat_tracker`, `status_effects`, `temporary_skills`, `weapon`/`armor`/`logic` instances, `side`/`team`/`player_id` |

### Symptoms of the dual identity

1. **Two construction paths that must be kept in sync** (`src/squad/combat.gd:13–31`):
   - `EntityConfig` (a RefCounted DTO) → `CombatEntity.new(config)` → `_init()` runs full setup incl. `init_after()`.
   - A saved `.tres` → `EntityFactory.get_entity()` → `init_from_resource()` re-derives weapon/armor/logic.
   - A pre-built `CombatEntity` → used as-is.
2. **Two-phase init.** `_init()` calls `init_after()`; the resource path calls
   `init_from_resource()` which *also* calls `init_after()`. The `if weapon != null: return`
   guard in `init_from_resource()` exists only to detect "have I already been hydrated?"
3. **`EntityConfig` already exists as the template-ish object** (`src/squad-battle/entity/_types.gd`,
   RefCounted) — but it duplicates fields rather than *being* the authored data, and it's a
   positional 13-arg constructor.
4. **Resource semantics leak — and there's already a band-aid for it.**
   `EntityFactory.get_entity()` does `load(path).duplicate(true)` precisely to avoid mutating
   the shared cached template at runtime. But per CLAUDE.md, `duplicate(true)` does **not**
   deep-copy external `.tres` sub-resources (`stats`, `logic_config`, weapon/armor configs) —
   so those are still aliased across every entity of that class. The template/runtime split
   removes the need for the `duplicate` trick entirely: the template is read-only, the runtime
   actor owns its own mutable state. This is the strongest single argument for the refactor.

## 3. Target shape (to-be)

Split the one class into **template (data) + runtime (logic)**, composed at battle start.

```
EntityTemplate        (Resource, .tres authorable)   ← was the @export half of CombatEntity
  ├─ class_id, entity_name, icon
  ├─ stats: EntityBaseStats          (Resource, unchanged)
  ├─ weapon_class / armor_class       (or WeaponConfig/ArmorConfig sub-resources)
  └─ logic_config: SimplifiedLogicConfig

CombatEntity          (RefCounted, live actor)        ← was the runtime half
  ├─ template: EntityTemplate         (read-only reference)
  ├─ changeable_stats, retreat_tracker, status_effects, temporary_skills
  ├─ side, team, player_id
  ├─ weapon: SquadWeapon, armor: SquadArmor, logic: SimplifiedSquadLogic
  └─ built once via CombatEntity.from_template(template, runtime_args)
```

Status effects (item 2 in the broader plan) become a natural follow-on: `status_effects`
is already a composed bag; with a stable runtime class it can grow `on_round_start` /
`on_damage` hooks without disturbing the template.

### What stays a Resource (do not convert)
- `EntityBaseStats`, `WeaponConfig`, `ArmorConfig`, `SimplifiedLogicConfig`, `Skill` — all
  genuinely authored, serializable data.
- The new `EntityTemplate`.

### What becomes / stays RefCounted
- `CombatEntity` (becomes RefCounted), `EntityConfig` (already is — likely *absorbed* into the
  `from_template` args and deleted), `RetreatTracker`, `SquadWeapon`, `SquadArmor`.

## 4. Migration path (incremental, each step compiles & demos green)

The goal is to never have a broken `main`. Order matters.

1. **Introduce `EntityTemplate` as a pure data Resource**, mirroring the `@export` fields of
   today's `CombatEntity`. Don't remove anything yet. Add a converter
   `EntityTemplate.to_combat_entity(...)`.
2. **Re-author the `.tres` files** as `EntityTemplate` resources. The live authored
   templates are `resources/combat/classes/{landsknecht,healer,crossbowman,arquebusier,
   pikeman,feldprediger,gelehrter}.tres` (7 files, currently *modified* on this branch),
   loaded by `EntityFactory.get_entity()` (`src/squad-battle/entity/_factory.gd`) via
   `load(path).duplicate(true)`. The deleted `resources/strategy-warrior/BS_*.tres` are a
   *different*, strategy-layer set and are not the combat templates — ignore them here.
3. **Change `CombatEntity` to `extends RefCounted`** and route all three construction paths in
   `src/squad/combat.gd` through a single `CombatEntity.from_template()`. Collapse
   `_init(config)` + `init_from_resource()` + `init_after()` into one constructor; delete the
   `weapon != null` guard.
4. **Fold `EntityConfig` into the `from_template` signature** (named args / a small options
   dict for `side`/`team`/`player_id`/`starting_location`), then delete `EntityConfig` if no
   other caller remains (`grep` showed only 3 references).
5. **Update `Warrior.convert_to_entity()`** (`src/character/social.gd:93`) to emit a template +
   runtime args instead of an `EntityConfig`.
6. **Delete dead exports** from the old class and reconcile CLAUDE.md (`RefCounted for logic`
   rule now actually holds for `CombatEntity`).

## 5. Blast radius

| Touch point | File | Risk |
|---|---|---|
| 3 construction branches | `src/squad/combat.gd:13` | medium — central, but well-contained |
| Quick-dummy + `_init` + `init_from_resource` | `src/character/combat.gd:49,130,174` | medium |
| Entity DTO | `src/squad-battle/entity/_types.gd` (EntityConfig) | low — 3 refs |
| Strategy→combat conversion | `src/character/social.gd:93` | low |
| `EntityFactory.get_entity()` | (factory) | medium — returns Resource today |
| Authored `.tres` (7) | `resources/combat/classes/*.tres` | medium — re-typed to EntityTemplate |
| Factory load+duplicate | `src/squad-battle/entity/_factory.gd:15` | low — `duplicate(true)` trick removed |

Validation per step: `combat_controller_test.tscn`,
`combat_strategy_integration_test.tscn`, `scenario_attack_test.tscn`, plus
`ai_stress_test_demo.tscn` for the headless deterministic path.

## 6. Open questions (need answers before coding)

1. ~~Are authored entity `.tres` still a thing?~~ **Resolved: yes.**
   `resources/combat/classes/*.tres` (7 class templates) are loaded + `duplicate(true)`'d by
   `EntityFactory`. Step 2 (re-typing them to `EntityTemplate`) stands. Note these 7 files are
   already modified on this branch — sequence the refactor *after* whatever change is in flight
   lands, to avoid a messy merge.
2. Should `EntityTemplate` reference `WeaponConfig`/`ArmorConfig` sub-resources directly, or
   keep the enum `weapon_class`/`armor_class` + factory lookup? (Affects how much the `.tres`
   needs to carry.)
3. Is `CombatEntity` ever persisted mid-battle (save/load of an in-progress fight)? If yes,
   the runtime half needs its own serializer; if no (battles are atomic), RefCounted is free.

## 7. Recommendation

The strongest case for this refactor turned out to be the `duplicate(true)` band-aid in
`EntityFactory`: it exists *only* because a `Resource` is doing double duty as template and
actor, and it's incompletely correct (sub-resources stay aliased). The template/runtime split
deletes that whole class of bug.

Scope is now well-bounded: ~5–6 code files + re-typing 7 authored `.tres`. Sequence it after
the in-flight `resources/combat/classes/*.tres` changes land. Still answer Q2/Q3 first (they
shape `EntityTemplate`'s fields and whether the runtime half needs a serializer), but neither
blocks starting. This is a solid, low-risk first proof of the composition direction before
extending the same template/runtime split to `Warrior`, `SquadData`, and `CombatSquad`.
