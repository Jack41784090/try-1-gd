# Refactor Plan — Battle-wide Resolver + Unified Duration-based Reactions

> Status: **approved design, ready to build.** Scope: replace the per-action
> `ClashResolver` with a single battle-scoped resolver, unify
> `ReactionSkill` + `StatusEffect` into one duration-based class, make STA the
> reaction/skill resource, make retreat a reaction skill, and drop rounds in favor
> of a bounded action stack. Godot 4.7.1.mono is installed for verification.

## 0. Goal in one paragraph

Today every entity action instantiates a fresh `ClashResolver`
(`src/character/combat.gd:265`), so reactions are subscribed per-intent, the
`once_per_round` latch and reaction budget only last one action, and status
effects live in three separate half-dead systems (`StatusEffect` resource,
`SkillEffect` triggers on the global `StatusEffectEventBus`, and the unused
`status_effects` array). This refactor makes **one resolver own the whole
battle**: entities push root action intents into a single stack, reactions
subscribe to the resolver's window signal once and persist for the battle, and
the battle ends when the stack drains. One class replaces four.

Processing is **strictly sequential — no batching**. The action queue is bounded
by `action_count`; reactions are bounded by duration + STA + DAG. (The
`reaction_count` budget is a future tactic addon — basics first.)

## 1. Current state (as-is)

| System | File | Reality |
|---|---|---|
| Per-action resolver | `src/character/combat.gd:265-268` | `ClashResolver.new()` + `begin_round(1)` per entity action |
| Per-intent reaction subscription | `src/squad_battle/clash/reaction.gd:16-17` | `intent.reaction_window.connect(...)` per intent |
| Status effect resource | `src/squad_battle/clash/status-effect.gd` | `duration` + `stat_modifiers`; `apply_to()` never called (dead) |
| Trigger skill effects | `src/squad_battle/clash/skill-effect.gd`, `skill/ske-*.gd` | connect `commit` to global `StatusEffectEventBus` signals |
| Status array on entity | `src/character/combat.gd:26` | `status_effects: Array[StatusEffect]`, ticked in `data.gd:156-161`, never populated |
| Retreat | `src/squad_battle/entity/retreat_tracker.gd` | separate `RetreatTracker` class driven from `damage()` + `_determine_actions` |
| Rounds | `src/squad_battle/data.gd:136-194` | `advance_round()` loop; `max_rounds = tactic.action_count` |

Key bug this fixes: `begin_round(1)` is called per *action*, so `once_per_round`
actually means "once per action." The battle-wide resolver makes budget/latch
genuinely battle-scoped.

## 2. Target shape (to-be)

```
SquadBattle (data.gd)                      ← owns ONE resolver for the battle
  └─ ClashResolver (battle-scoped)
       ├─ _all_entities (roster, cached squad_data w/ dirty flag)
       ├─ signal window_raised(intent, window)      ← replaces intent.reaction_window
       ├─ _stack: Array[ClashIntent]                ← root actions + reaction children
       ├─ submit(intent) / solve() -> Array[EntityUpdate]
       └─ reactions subscribed ONCE at battle start (sorted by priority)

ReactionSkill (reaction.gd)                ← merges StatusEffect
  ├─ window, relation_to_target, condition, effect, skill, priority
  ├─ duration: int            ← replaces once_per_round; fires up to N times
  ├─ sta_cost: float          ← per-entity reaction resource
  └─ remaining_activations    ← decrements each fire; 0 → unsubscribe

CombatEntity (combat.gd)
  ├─ reactions: Array[ReactionSkill]       ← statuses folded in here
  ├─ retreat_state: RetreatState           ← flat enum, replaces RetreatTracker
  ├─ advance_retreat()                     ← logic ported from retreat_tracker.advance
  └─ recover()                             ← now also restores STA

Tactic (tactic.gd)
  └─ action_count    ← bounds the action queue (waves per entity); name unchanged
     (reaction_count budget + any rename = future tactic addon, not in basics)
```

## 3. Phase 1 — Unified reaction engine

### `src/squad_battle/clash/reaction.gd`
- Add `@export var duration: int = 1` and `@export var sta_cost: float = 10.0`;
  runtime `remaining_activations`. Delete `once_per_round`.
- `subscribe_to(resolver: ClashResolver, owner: CombatEntity)` connects to
  `resolver.window_raised` **once** (battle scope). Handlers sorted desc by
  priority at subscribe time to preserve current ordering.
- `_on_reaction_window(intent, window, resolver, owner)`:
  window match → owner alive → intent not CANCELLED → **DAG check** →
  `resolver.reaction_allowed(owner, self)` → build situation lazily (only if
  `condition != null`) → `can_react()` → `resolver.execute_reaction(...)`.
- On fire: decrement `remaining_activations`; at 0 unsubscribe + remove.

### DAG enforcement (method A — path-based ancestor set)
- `resolver._has_ancestor(intent, owner, reaction_name)` walks `intent.cause`;
  if `(owner_id, reaction_name)` already appears in the chain → block. Prevents
  a reaction answering its own consequence. `MAX_DEPTH = 8` kept as a breadth
  safety net for non-cyclic diamonds.

### `src/squad_battle/clash/intent.gd`
- Delete `signal reaction_window`. Keep `cause` / `depth` (ancestor walk +
  view depth-grouping).

### `src/squad_battle/clash/resolver.gd` (core)
- Battle-scoped API: `set_entities(all)`, `submit(intent)`,
  `solve() -> Array[EntityUpdate]`, `signal window_raised(intent, window)`.
  Delete `begin_round(budget)`, `_latch`, `_budget`, `_reaction_budget`.
- Subscribe every living entity's reactions once at battle start (and on apply).
- `raise_window()` emits `window_raised`. Resolve loop emits ON_CAST, ON_HIT,
  ON_DODGE, ON_PIERCE, ON_BLOCK, ON_DAMAGED, ON_KILL, ON_HEAL as today.
- `reaction_allowed()` → STA check (`owner.get_changeable_stat_num(STA) >=
  reaction.sta_cost`) + duration remaining. (A per-entity `reaction_count`
  budget is a future tactic addon — basics rely on duration + STA + DAG.)
- `execute_reaction()` → spend STA (`mod_changeable_stat` → EntityUpdate),
  apply effect/skill, decrement duration, expire+unsubscribe at 0, push child
  intent carrying the ancestor set.
- `solve()` loop (**strictly sequential, no batching**): at battle start build a
  finite round-robin `_action_queue` — each living entity appears
  `tactic.action_count` times, interleaved. While the queue is non-empty: pop
  the next entity (skip dead/capitulated) → `intent = propose_action()`; if
  null the entity **idles** (slot consumed, no intent) → else `submit(intent)`
  and resolve the intent + its reaction children depth-first → after a root
  commits, caster `recover()`. Emits one flat `Array[EntityUpdate]` in commit
  order. When the queue drains the battle ends.
- Cached squad_data: `_squad_data` rebuilt lazily with a dirty flag invalidated
  on HP→0 / LOC / membership mutation; `_build_squad_data` reads the cache.

### `src/squad_battle/clash/reaction_effect.gd`
- Add `Kind.MOD_STAT` (stat-modifier statuses, from `StatusEffect.stat_modifiers`)
  and `Kind.RETREAT` (advance retreat state).

## 4. Phase 2 — Entity, skills, retreat, rounds

### `src/squad_battle/clash/skill.gd`
- Add `@export var sta_cost: float` (base skills pay too).
- Remove trigger machinery. `Skill.effects` = immediate commits only;
  `Skill.reactions: Array[ReactionSkill]` = carry-over reactions applied on cast.

### `src/character/combat.gd`
- `recover()` adds STA restore alongside HP/ORG.
- `action()` → `propose_action(our, enemy) -> ClashIntent` (skill pick +
  targeting only); the resolver submits. Returns **null (idle)** when the logic
  picks nothing. Affordability: `choose_skill()` skips rules whose
  `skill.sta_cost` exceeds current STA; if nothing is affordable/picked, idle.
- Replace `retreat_tracker` with flat `retreat_state: RetreatState` enum field +
  `advance_retreat()` method (logic ported from `retreat_tracker.advance`).
- Remove `status_effects: Array[StatusEffect]` — statuses are `reactions` now.

### Retreat-as-reaction
- Delete `src/squad_battle/entity/retreat_tracker.gd` and the `RetreatTracker`
  class. Every entity gets an implicit/config-provided retreat `ReactionSkill`
  (window ON_DAMAGED, condition `ORG <= 0`, effect `RETREAT`, duration 3 =
  FIGHTING→RETREATING→LAST_STAND→CAPITULATED).
- `SquadBattle.order_retreat(team)` injects self-targeted retreat intents for
  that team. `damage()` no longer calls `retreat_tracker.advance`.

### `src/squad_battle/data.gd`
- Owns the resolver (instantiate + `set_entities` in `_init`). Delete
  `advance_round()`, `_determine_actions`, `max_rounds`, per-round capacity.
- `run_headless()` → thin wrapper over `resolver.solve()`.
- Outcome when stack drains: one side wiped → victory; both alive → DRAW.
  `battle_completed` emitted once there.

### `src/squad/combat.gd`
- `perform_actions()` absorbed by the resolver's solve loop (it owns roster +
  cadence). File shrinks to entity construction + `get_all_entities`.

### `src/squad_battle/view_2d.gd`
- `_loop_round` replaced by one `await battle.solver.solve()` then animate the
  flat sequential stream. The **only** grouping is presentation-side: bucket by
  `metadata.depth` purely for animation pacing (keep DIE/LOC/row-move handling).
  `delay_between_rounds` becomes per-depth pacing. No resolver-side batching.

### `src/squad_battle/clash/skill/ske-flat.gd` / `ske-splash.gd`
- Drop trigger/disconnect logic → pure immediate commits (splash stays an
  immediate AoE effect on cast).

### Deletions
- `src/squad_battle/clash/status-effect.gd` deleted; `status_effects` merged
  into `reactions`. Orphaned `resources/combat/logic/status-effects/` removed.
- `src/singletons/StatusEffectEventBus.gd` + `SkillEffect.triggers` retired
  (resolver stops emitting its 3 signals; windows replace them). `one_clash.gd`
  left as legacy.

## 5. Phase 3 — Data migration & demos

### `.tres` migration
- The 5 trigger-based skills (`arquebus`, `ranged-attack` "Ranged Suppression",
  `inspire`, `fireball`, `sacred_sentence` splash) convert their trigger effects
  to `Skill.reactions` + immediate effects. New reaction `.tres` under
  `resources/combat/logic/reactions/`. Braced (orphan, window=12) rewritten as a
  duration reaction or dropped.

### `src/demos/reaction_chain_demo.gd` (primary driver)
- Port to battle-wide API: one resolver, `set_entities`, reactions get
  `sta_cost` + `duration`, cycle-guard test (ping chain terminates at ancestor
  detection), STA-exhaustion assertion, `solve()` returns updates. Add a
  carry-over regression: a duration-2 reaction survives two root actions.

### Consumer updates
- `combat_bridge.gd:180` "round_count" → action/turn counter.
- `control.gd:224` `combat_phase` → total resolved intents (or drop).
- Demos printing `round_count`/`max_rounds` (`headless/aoe/ranged_combat_demo`,
  `combat_strategy_integration_test:623/714` asserts max_rounds — update to
  stack-budget semantics); `retreat` references in `sb_bridge`.

### Verification
```
godot-mono --headless --path . scenes/demos/reaction_chain_demo.tscn
godot-mono --headless --path . scenes/demos/aip_clash_test.tscn
godot-mono --headless --path . scenes/demos/squad_battle_2d_demo.tscn
godot-mono --headless --path . scenes/demos/scenario_attack_test.tscn
godot-mono --headless --path . scenes/demos/combat_strategy_integration_test.tscn
```

## 6. Resolved decisions

Locked from user answers:

1. **Idle** — when an entity's logic returns nothing, the entity **idles**: that
   submission slot produces no intent but is still consumed. The action queue is
   pre-built and finite, so idling can never stall termination.
2. **Tactic budgets — de-scoped, basics first** — property names stay
   `action_count` / `reaction_count` (no rename to attack_wave_count /
   retaliate_wave_count). For the basics, `action_count` alone bounds the action
   queue (waves per entity); reactions are bounded by duration + STA + DAG. The
   per-entity `reaction_count` budget is a **future tactic addon**, not wired now.
3. **No batching** — the resolver processes the stack strictly **sequentially**
   and emits one flat `Array[EntityUpdate]` in commit order. No batching/grouping
   in the resolver. The only grouping is in the view, which buckets by
   `metadata.depth` purely for animation pacing (presentation-only).

Carried defaults:
- **Recovery cadence** — `recover()` fires per-action: caster recovers after each
  of its own root intents commits.
- **`ON_ROUND_START` / `ON_ROUND_END` windows** — removed from the enum (rounds
  are gone).

## 7. Files touched (summary)

| File | Change |
|---|---|
| `src/squad_battle/clash/resolver.gd` | battle-scoped; submit/solve/window_raised; STA; DAG; cached roster |
| `src/squad_battle/clash/intent.gd` | drop `reaction_window` signal |
| `src/squad_battle/clash/reaction.gd` | duration + sta_cost; battle-wide subscribe; DAG check |
| `src/squad_battle/clash/reaction_effect.gd` | add MOD_STAT, RETREAT kinds |
| `src/squad_battle/clash/skill.gd` | sta_cost; effects=reactions split |
| `src/squad_battle/clash/skill/ske-flat.gd` | immediate-only |
| `src/squad_battle/clash/skill/ske-splash.gd` | immediate-only |
| `src/character/combat.gd` | propose_action; STA in recover; retreat_state; drop status_effects |
| `src/squad_battle/entity/retreat_tracker.gd` | **deleted** |
| `src/squad_battle/clash/status-effect.gd` | **deleted** |
| `src/squad_battle/data.gd` | own resolver; drop advance_round/max_rounds; solve() |
| `src/strategy/core/tactic.gd` | basics: `action_count` bounds queue; names unchanged (budget addon deferred) |
| `src/squad/combat.gd` | absorb perform_actions |
| `src/squad_battle/view_2d.gd` | single solve + animate stream |
| `src/singletons/StatusEffectEventBus.gd` | retired (resolver stops emitting) |
| `resources/combat/logic/skills/*.tres` | trigger effects → reactions |
| `resources/combat/logic/reactions/*.tres` | new reaction data |
| `src/demos/reaction_chain_demo.gd` | port to battle-wide API |
| bridge + round-printing demos | round_count → action counter |
