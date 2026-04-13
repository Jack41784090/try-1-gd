---
description: "Use when editing tactical combat system: squad battles, weapons, armor, entities, clash logic, retreat, evasion, pierce. Covers src/squad-battle/ architecture."
applyTo: "src/squad-battle/**"
---

# Tactical Combat System

Turn-based View/Presenter/Model in `src/squad-battle/`.

## Core Architecture

- `SquadBattle` (data.gd) — Model: battle state, round logic. `order_retreat(team)`, `squad_actions()`, `_produce_retreat_updates()`
- `SquadBattleView2D` (view_2d.gd) — 2D WarriorRig-based battle view (extends Control)
- `SquadBattlePresenter` (presenter.gd) — round loop, victory checks, `battle_completed` signal. Duck-typed `var view`
- `BattlefieldView2D` (battlefield_view.gd) — 2D battlefield: SubViewport + Camera2D, row containers (Front/Middle/Back), tween animations
- `BattleEntityDisplay` (entity/battle_display.gd) — wraps WarriorRig + HP bar + ORG icons
- `SquadBattleMasterFactory` (_factory.gd) — loads `sb-master-2d.tscn`, returns Control

## Flow

`squad_actions() → choose_action() → action() → OneClash.execute() → Array[EntityUpdate]`

All state changes produce immutable `EntityUpdate`/`EntityChange` objects.

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
