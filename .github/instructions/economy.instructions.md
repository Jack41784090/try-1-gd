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

C# `Tick(turn, dangerMatrix)` runs all per-location phases in a single mega-loop, then runs internal trade matching using the GDScript-supplied NxN danger matrix to score `(margin * 0.4 + urgency * 0.6) * safety` and creates `EconomyMove`s + `CsShipmentDispatch`es inline → `EconomyEngine.tick_full()` reads dispatches directly from the tick result and emits `mercenary_work_changes` → `StrategyPresenter._run_economy_tick()` spawns caravans via `CaravanBridge`.

- **TradeMatcher** (`trade_matcher.gd`): Greedy matching engine. Creates `TradeSituation` per pair, scores via considerations or default `(margin * 0.4 + urgency * 0.6) * safety`
- **RouteDangerCalculator** (`route_danger.gd`): Route safety (0-1) based on aggressive squads along connections. Per-edge safety = `1.0 / (1.0 + threats)`. Route = product of edges

## Documentation Sync

- When editing `src/economy/**`, update matching architecture notes in `/home/ikec/Documents/schwarzwagen/CONDOR/Systems/` in the same task.
- Update impacted notes under `Systems/Economy/`.
- If economy runtime sequencing changes, also update `Systems/Runtime/Economy Tick 24h.md`, `Systems/Graph Seed.md`, and relevant `!index.md` notes.

## C# Engine

`src/economy/csharp/`: `CsEconomyBridge.Setup(world)` → `Tick(turn, dangerRows)` → `SyncBackToGdScript()`. Per-location mega-loop covers spoilage, prices, orders, production, subsistence, order matching, contract assignment, market, household, rent, government, guild, pop state, geist, snapshot.

**25-phase tick lifecycle** (PhasePersonDecisions at start, PhaseResetTurnFlags after starvation, PhaseGuildRecruit/Produce after government).

## PersonBrain System

`PersonBrain`, `NobleBrain`, `CommonBrain` — lightweight per-person decision-making:
- Each `CsPerson` has nullable `Brain` field. `PhasePersonDecisions` runs all brains at tick start
- **NobleBrain**: evaluates loan applications via weighted scoring (desperation 0.4, satisfaction 0.25, food prices 0.15, debt penalty -0.3, per-person risk tolerance from InternalId hash)
- **CommonBrain**: shared singleton no-op for non-nobles (extensible for future peasant/merchant decisions)
- Brains assigned on creation (factory methods, `MirrorPerson` bridge, birth) and updated on social mobility

## Gradual Pricing

`PhasePriceUpdate` adjusts prices incrementally (max 15%/tick) based on supply/demand imbalance:
- Goods-specific stickiness: food 1.2× (responds faster), weapons 0.6×, luxury 0.5×
- Location tracks `LastDemand[]`/`LastSupply[]` per good
- Prices linger at high levels during shortages, compounding lower-class suffering

## Scarcity Markup

`PhaseMarket` — as stock depletes within a tick (wealthiest buy first), remaining buyers face quadratic scarcity markup (up to 50% at full depletion). Rich buyers get base price, poor buyers hit inflated prices.

## Features

- Input-based production chains, FIFO cost-basis tracking, elastic demand
- Dynamic population (starvation/birth), social mobility, central bank
- **Food spoilage**: `PhaseSpoilage` decays 5% of food stocks per turn
- **Market revenue**: Consumer purchases split 85% to producers (farmers+craftsmen), 15% merchant commission. Money-conserving
- **Population sync**: `SyncBackToGdScript()` uses PersonId-based matching for births/deaths. `Population.remove_person()` for death sync
- **Bank metrics**: `engine.get_bank_info()` reads C# CsCentralBank state (printed/reserves/loans/debt). GDScript CentralBank is config-only
- **Person sync via `sync_full()`**: `EconomyEngine.tick_full()` calls `engine.sync_full()` after each tick to propagate person money/satisfaction/class from C# back to GDScript

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
