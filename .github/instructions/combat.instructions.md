---
description: "Use when editing tactical combat system: squad battles, weapons, armor, entities, clash logic, retreat, evasion, pierce. Covers src/squad-battle/ architecture."
applyTo: "src/squad-battle/**"
---

# Tactical Combat System

Turn-based Model + View in `src/squad-battle/`, coupled by signal (no Presenter).

## Core Architecture

- `SquadBattle` (data.gd) — Model (Resource): battle state, round logic. `order_retreat(team)`, `squad_actions()`, `_produce_retreat_updates()`. Owns `battle_completed(outcome)`, emitted once from `evaluate_outcome()` on the ONGOING→terminal transition; `get_battle_outcome()`/`check_victory()`/`run_headless()` stay pure queries
- `SquadBattleView2D` (view_2d.gd) — 2D WarriorRig-based battle view (extends Control) + round loop: `_start_battle()`/`_process_round()` (need `get_tree()` timers, which the Resource can't provide). Holds `battle` as a plain property, never a scene child. `all_updates`, `delay_between_rounds`, `request_retreat(team)`
- External consumers await `battle.battle_completed` through the owning object, not a relay signal on the View
- `BattlefieldView2D` (battlefield_view.gd) — 2D battlefield: SubViewport + Camera2D, row containers (Front/Middle/Back), tween animations
- `BattleEntityDisplay` (entity/battle_display.gd) — wraps WarriorRig + HP bar + ORG icons
- `SquadBattleMasterFactory` (_factory.gd) — loads `sb-master-2d.tscn`, returns Control

## Flow

`squad_actions() → choose_action() → action() → OneClash.execute() → Array[EntityUpdate]`

All state changes produce immutable `EntityUpdate`/`EntityChange` objects.

## Documentation Sync

- When editing `src/squad-battle/**`, update matching architecture notes in `/home/ikec/Documents/schwarzwagen/CONDOR/Systems/` in the same task.
- Update impacted notes under `Systems/Combat/` and `Systems/Data/Combat Types.md`.
- If strategy-combat integration flow changes, also update `Systems/Runtime/Combat Flow.md` and related hub notes.

## Subsystems

- **RetreatTracker** (entity/retreat_tracker.gd): FIGHTING→RETREATING→LAST_STAND→CAPITULATED. `advance()` produces LOC+1/ORG restore/CAPITULATE updates
- **Evasion**: `OneClash.roll_for_hit()` — attacker weapon hit vs defender Maneuver reality
- **Reality calculation**: Table-driven via `CombatEntity._REALITY_TABLE` — `[base, op, terms]` per Reality
- **Forced retreat**: `order_retreat(ATTACKER)` mid-battle. Entities progress Front→Back→last stand→capitulate
- **Ranged targeting**: `WeaponLocation.can_hit` arrays define position→position reach
- **Pierce**: physical (Force+Precision vs armor PV) or magical (Mana+Spirituality vs magical PV). `OneClash.roll_for_pierce()` auto-branches on `is_magical`

## Combat Bridge

`src/strategy/core/sb-bridge/` — connects tactical↔strategic:
- `CombatBridge` (!main.gd) — stateless data translation. CAPITULATE → `is_injured=true`
- `CombatController` (control.gd) — stateful orchestration. `CombatResult` includes `escaped_warriors`, `equipment_loot`

## Enums & Factories

- Weapons: `weapon/_factory.gd` — Unarmed, Flammenschwert, Crossbow, Arquebus, Pike, Mace, AlchemicalFire
- Armor: `armor/_factory.gd` — Unarmored, LeatherArmor, PaddedArmor, HalfPlate
- Logic: `entity/logic/_factory.gd` — Frontline, BacklineHeal, BacklineShooter, DefensiveFrontline, BacklineSupport, BacklineGunner, BacklineCaster

## Unit Classes

| Class | Role | Weapon | Armor | Logic | Pos | Cost |
|-------|------|--------|-------|-------|-----|------|
| Landsknecht | melee DPS | Flammenschwert | Leather | Frontline | Front | 100 |
| Healer | support | Unarmed | None | BacklineHeal | Back | 150 |
| Crossbowman | ranged DPS | Crossbow (-4 ORG) | Padded | BacklineShooter | Back | 120 |
| Arquebusier | glass cannon | Arquebus (-6 ORG) | None | BacklineGunner | Back | 200 |
| Pikeman | defensive | Pike (reach) | Half Plate | DefensiveFrontline | Front | 130 |
| Feldprediger | enhanced support | Mace | Padded | BacklineSupport | Back | 180 |
| Gelehrter | AoE mage | AlchemicalFire (magical, 50% splash) | None | BacklineCaster | Back | 250 |
