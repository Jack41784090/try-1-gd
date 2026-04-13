---
description: "Use when editing economy system: C# engine, trade pipeline, government directives, guilds, populations, inventory, caravans, TradeMatcher. Covers src/economy/ architecture."
applyTo: "src/economy/**"
---

# Economy System

Demand/Supply matching system. **C# mandatory** — `CsEconomyEngine` via `CsEconomyBridge`; GDScript `EconomyEngine` is thin facade. Build: `dotnet build`. Run with `godot-mono`.

## Core Types

- `Thing` (goods), `EconPerson` (actors), `Population`, `LocationInventory` (stock+prices)
- `NaturalResource` (local production capacity), `EconomicDemand`/`EconomicSupply` (trade opportunities)
- `EconomyMove` (in-transit goods)

## Trade Pipeline

C# `Tick()` runs lifecycle phases → `GetPendingDemands()`/`GetAvailableSupplies()` export to GDScript → `TradeMatcher` scores Supply→Demand pairs using `StrategicConsideration` system → `ApplyTradeMatches()` creates shipment dispatches → `EconomyOrchestrator` spawns caravans.

- **TradeMatcher** (`trade_matcher.gd`): Greedy matching engine. Creates `TradeSituation` per pair, scores via considerations or default `(margin * 0.4 + urgency * 0.6) * safety`
- **RouteDangerCalculator** (`route_danger.gd`): Route safety (0-1) based on aggressive squads along connections. Per-edge safety = `1.0 / (1.0 + threats)`. Route = product of edges

## C# Engine

`src/economy/csharp/`: `CsEconomyBridge.Setup(world)` → `Tick(turn)` → `GetPendingDemands()`/`GetAvailableSupplies()` → `ApplyTradeMatches()` → `SyncInventories()`.

**25-phase tick lifecycle** (includes PhaseResetTurnFlags after starvation, PhaseGuildRecruit/Produce after government).

## Features

- Input-based production chains, FIFO cost-basis tracking, elastic demand
- Dynamic population (starvation/birth), social mobility, central bank
- **Food spoilage**: `PhaseSpoilage` decays 5% of food stocks per turn
- **Market revenue**: Consumer purchases split 85% to producers (farmers+craftsmen), 15% merchant commission. Money-conserving
- **Population sync**: `SyncBackToGdScript()` uses PersonId-based matching for births/deaths. `Population.remove_person()` for death sync
- **Bank metrics**: `engine.get_bank_info()` reads C# CsCentralBank state (printed/reserves/loans/debt). GDScript CentralBank is config-only
- **Person sync via `sync_full()`**: `EconomyOrchestrator.tick_and_spawn_caravans()` calls `engine.sync_full()` after each tick to propagate person money/satisfaction/class from C# back to GDScript

## Government Directives

`CsGovernment`, `CsDirective`, `GovernmentBrain` — Per-location government with treasury, tax collection, AI-driven directives:
1. **GovernmentTax**: collect from people with >10 money
2. **GovernmentPlan**: `GovernmentBrain.Evaluate()` analyzes worker gaps in natural resources, creates HireWorkers directives within budget
3. **GovernmentExecute**: process directives — hire from unemployed/laborers, pay wages

`GovernmentConfig` Resource on Location configures push/pull weights, tax rate, starting treasury, priority goods. Auto-generated in `_setup_economy()` for locations without one.

## Guild System

`CsGuild`, `GuildBrain`, `GuildConfig` — Per-location crafting guilds. 2 phases (after GovernmentExecute):
1. **PhaseGuildRecruit**: hire unemployed/laborers as craftsmen via GuildBrain
2. **PhaseGuildProduce**: consume inputs, output goods, pay wages, collect 10% revenue commission

`GuildConfig` Resource on Location configures guild_name, specialization (Thing), max_workers, wage_per_worker, starting_treasury, recruitment_rate.

Guild-produced goods flow into LocationInventory → TradeMatcher → merchant caravans automatically.

## Caravan Bridge

`src/economy/caravan_bridge.gd`: `CaravanBridge` materializes trade dispatches as MERCHANT squads. `CaravanBrain` (src/strategy/ai/caravan_brain.gd) pathfinds to destination. Lifecycle: dispatch → spawn/reassign → pathfind → deliver → idle → reassign/despawn.
