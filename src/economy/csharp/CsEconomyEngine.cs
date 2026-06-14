using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsLocationData
{
    public int Idx { get; set; }
    public string LocationId { get; set; }
    public string LocationName { get; set; }
    public CsPopulation Population { get; set; }

    public float[] Stocks { get; set; }
    public float[] Prices { get; set; }

    public List<CsNaturalResource> NaturalResources { get; } = new();
    public List<CsEconomyActor> Actors { get; } = new();
    public CsGovernment Government { get; set; }
    public List<CsGuild> Guilds { get; set; }
    public CsGeist Geist { get; set; }

    public float[] CostBasis { get; set; }
    public float[] LastDemand { get; set; }
    public float[] LastSupply { get; set; }

    public List<CsOrder> Demands { get; } = new();
    public List<CsOrder> Supplies { get; } = new();

    public CsLocationData(int goodsCount)
    {
        Stocks = new float[goodsCount];
        Prices = new float[goodsCount];
        CostBasis = new float[goodsCount];
        LastDemand = new float[goodsCount];
        LastSupply = new float[goodsCount];
    }

    public float GetAvailable(int thingIdx) => Stocks[thingIdx];

    public void Add(int thingIdx, float qty) => Stocks[thingIdx] += qty;

    public float Consume(int thingIdx, float qty)
    {
        float available = Stocks[thingIdx];
        float consumed = MathF.Min(available, qty);
        Stocks[thingIdx] = available - consumed;
        return consumed;
    }

    public float GetPrice(int thingIdx) => Prices[thingIdx];

    public void ClearOrderBook()
    {
        Demands.Clear();
        Supplies.Clear();
    }
}

public sealed class CsNaturalResource
{
    public int ThingIdx { get; set; }
    public float BaseCapacity { get; set; }
    public JobType WorkerJob { get; set; } = JobType.Farmer;
    public float WorkersNeeded { get; set; } = 50f;
}

public sealed class CsEconomyEngine
{
    public ThingDef[] Goods { get; private set; }
    public CsLocationData[] Locations { get; private set; }
    public HashSet<CsEconomyMove> ActiveMoves { get; } = new();
    public List<CsContract> ActiveContracts { get; } = new();
    public List<CsContract> CompletedContracts { get; } = new();
    public float NobleLoanThreshold { get; set; } = 100f;
    public float LoanAmount { get; set; } = 500f;
    public int TotalPromotions { get; set; }
    public int TotalDeaths { get; set; }
    public int TotalBirths { get; set; }

    private int _shipmentCounter;
    private int _goodsCount;
    private int _foodIdx = -1;
    private Random _rng = new();
    private EconomyContext _ctx;
    private readonly CsOrderMatcher _orderMatcher = new();

    public Func<int, int, int> GetTravelTimeFunc { get; set; }

    public CsGovernment ImperialGovernment
    {
        get
        {
            for (int li = 0; li < Locations.Length; li++)
            {
                var gov = Locations[li].Government;
                if (gov != null && gov.IsImperial) return gov;
            }
            return null;
        }
    }

    public void Initialize(ThingDef[] goods, CsLocationData[] locations)
    {
        Goods = goods;
        Locations = locations;
        _goodsCount = goods.Length;

        for (int i = 0; i < _goodsCount; i++)
            if (Goods[i].ThingType == ThingType.Food) { _foodIdx = i; break; }

        for (int li = 0; li < locations.Length; li++)
        {
            var loc = locations[li];
            if (loc.Geist == null)
            {
                loc.Geist = new CsGeist
                {
                    LocationIndex = li,
                    LocationId = loc.LocationId,
                };
            }
        }

        _ctx = new EconomyContext
        {
            Goods = goods,
            NobleLoanThreshold = NobleLoanThreshold,
            LoanAmount = LoanAmount,
            Rng = _rng,
        };
    }

    public CsEconomyTickResult Tick(int turn, float[,] dangerMatrix = null)
    {
        var result = new CsEconomyTickResult { Turn = turn };

        _ctx.CurrentTurn = turn;
        _ctx.NobleLoanThreshold = NobleLoanThreshold;
        _ctx.LoanAmount = LoanAmount;
        _ctx.ImperialGovernment = ImperialGovernment;

        const float spoilageRate = 0.05f;
        const float adjustRate = 0.15f;
        const float minPriceRatio = 0.5f;
        const float maxPriceRatio = 3.0f;

        // ====================================================================
        // PHASE A — PRE-TICK GLOBALS (move advancement only)
        // Contracts, loans, imperial bank — all disabled per plan.
        // ====================================================================

        var finishedMoves = new List<CsEconomyMove>();
        foreach (var move in ActiveMoves)
        {
            bool arrived = move.Advance();
            if (arrived)
            {
                Locations[move.DestLocationIdx].Add(move.ThingIdx, move.Quantity);
                result.MovesCompleted.Add(move);
                finishedMoves.Add(move);
            }
        }
        ActiveMoves.ExceptWith(finishedMoves);

        int totalDemands = 0, totalSupplies = 0;

        // ====================================================================
        // PHASE B — PER-LOCATION MEGA-LOOP
        // ====================================================================

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];

            // --- B.1 Spoil Food ---
            if (_foodIdx >= 0)
            {
                float stock = loc.GetAvailable(_foodIdx);
                if (stock > 0f) loc.Consume(_foodIdx, stock * spoilageRate);
            }

            // --- B.2 price update ---
            var wantsComputers = loc.Population.People;
            for (int pi = 0; pi < wantsComputers.Count; pi++)
                wantsComputers[pi].ComputeWants(Goods, loc.Prices);
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                float demand = loc.Population.GetTotalDemand(gi);
                float supply = MathF.Max(loc.Stocks[gi], 0.01f);
                loc.LastDemand[gi] = demand;
                loc.LastSupply[gi] = supply;

                float basePrice = Goods[gi].BasePrice;
                float currentPrice = loc.Prices[gi];
                if (currentPrice <= 0f) currentPrice = basePrice;

                float imbalance = (demand - supply) / MathF.Max(demand + supply, 1f);
                float stickiness = Goods[gi].ThingType switch
                {
                    ThingType.Food => 1.2f,
                    ThingType.Weapons => 0.6f,
                    ThingType.Luxury => 0.5f,
                    _ => 1.0f,
                };

                float newPrice = currentPrice * (1f + imbalance * adjustRate * stickiness);
                loc.Prices[gi] = Math.Clamp(newPrice, basePrice * minPriceRatio, basePrice * maxPriceRatio);
            }

            loc.ClearOrderBook();

            // --- B.3 Generate Orders ---
            var people = loc.Population.People;
            for (int pi = 0; pi < people.Count; pi++)
                people[pi].GenerateOrders(loc, _ctx);
            for (int ai = 0; ai < loc.Actors.Count; ai++)
                loc.Actors[ai].GenerateOrders(loc, _ctx);

            // --- B.4 Update State ---
            for (int ai = 0; ai < loc.Actors.Count; ai++)
                loc.Actors[ai].UpdateState(loc, Goods);

            // --- B.5 AlwaysProduce (extraction guilds emit supply) ---
            for (int ai = 0; ai < loc.Actors.Count; ai++)
            {
                var actor = loc.Actors[ai];
                if (actor.ProductionTiming == CsEconomyActor.Timing.Always ||
                    actor.ProductionTiming == CsEconomyActor.Timing.Mixed)
                    actor.Produce(loc, Goods, CsEconomyActor.Timing.Always);
            }


            // --- B.5.5 Match Always-Produce Orders (later on-demand producers inspect the gap) ---
            _orderMatcher.Match(loc, _ctx);

            // // --- B.6 Emit Market Supply from surplus inventory ---
            // !! DEPRECATED: Not really helpful because all supplies should already be claimed
            // for (int gi = 0; gi < _goodsCount; gi++)
            // {
            //     float stock = loc.Stocks[gi];
            //     if (stock <= 0f) continue;
            //     float guildClaim = 0f;
            //     for (int si = 0; si < loc.Supplies.Count; si++)
            //     {
            //         var s = loc.Supplies[si];
            //         if (s.Category == ThingCategory.Good && s.ThingIdx == gi && s.IssuerActor is CsGuild)
            //             guildClaim += MathF.Max(s.Quantity, 0f);
            //     }
            //     float remaining = stock - guildClaim;
            //     if (remaining > 0f)
            //     {
            //         loc.Supplies.Add(CsOrder.GoodSupply(loc.Idx, gi, remaining,
            //             priority: 3f, unitPrice: loc.Prices[gi], issuer: loc.Government));
            //     }
            // }

            // // --- B.7 Subsistence: farmers eat from stock directly ---
            // !! DEPCREATED: subsistence is handled by very high priority demands
            // if (_foodIdx >= 0)
            // {
            //     var farmers = loc.Population.GetByJob(JobType.Farmer);
            //     for (int fi = 0; fi < farmers.Count; fi++)
            //     {
            //         if (loc.GetAvailable(_foodIdx) >= 1f)
            //         {
            //             loc.Consume(_foodIdx, 1f);
            //             farmers[fi].AddInventory(_foodIdx, 1f);
            //         }
            //     }
            // }

            // --- B.8 OnDemandProduce (crafting guilds inspect gap) ---
            for (int ai = 0; ai < loc.Actors.Count; ai++)
            {
                var actor = loc.Actors[ai];
                if (actor.ProductionTiming == CsEconomyActor.Timing.OnDemand ||
                    actor.ProductionTiming == CsEconomyActor.Timing.Mixed)
                    actor.Produce(loc, Goods, CsEconomyActor.Timing.OnDemand);
            }

            // --- B.9 Match All (single deferred pass) ---
            totalDemands += loc.Demands.Count;
            totalSupplies += loc.Supplies.Count;
            _orderMatcher.Match(loc, _ctx);

            // --- B.10 Pay Workers ---
            for (int ai = 0; ai < loc.Actors.Count; ai++)
                loc.Actors[ai].PayWorkers(loc);

            // --- B.11 Collect Revenue ---
            for (int ai = 0; ai < loc.Actors.Count; ai++)
                loc.Actors[ai].CollectRevenue(loc, Goods);

            loc.Population.MarkWealthDirty();

            // --- B.12 Population State (satisfaction, starvation, births, mobility) ---
            {
            }

            // --- B.13 Geist Update ---
            loc.Geist?.UpdateState(loc, Goods);

            // --- B.14 Snapshot ---
            {
                var snap = new CsLocationSnapshot
                {
                    LocationIdx = li,
                    LocationId = loc.LocationId,
                    LocationName = loc.LocationName,
                    PopulationCount = loc.Population.Size(),
                    AvgSatisfaction = loc.Population.GetAverageSatisfaction(),
                    AvgMoney = loc.Population.GetAverageMoney(),
                    Stocks = new float[_goodsCount],
                    Prices = new float[_goodsCount],
                    PeasantCount = loc.Population.GetByClass(SocialClass.Peasant).Count,
                    BourgeoisCount = loc.Population.GetByClass(SocialClass.Bourgeois).Count,
                    NobleCount = loc.Population.GetByClass(SocialClass.Noble).Count,
                };

                if (loc.Government != null)
                {
                    snap.GovernmentTreasury = (float)loc.Government.Treasury;
                    snap.GovernmentTaxCollected = (float)loc.Government.TaxCollectedLastTick;
                    snap.GovernmentDirectivesCount = loc.Government.ActiveDirectives.Count;
                    snap.GovernmentWorkersHired = loc.Government.WorkersHiredLastTick;
                }

                float totalGuildTreasury = 0f;
                float totalGuildProduced = 0f;
                int totalGuildWorkers = 0;
                for (int ai = 0; ai < loc.Actors.Count; ai++)
                {
                    if (loc.Actors[ai] is CsGuild g)
                    {
                        totalGuildTreasury += (float)g.Treasury;
                        totalGuildProduced += g.ProducedLastTick;
                        totalGuildWorkers += g.TotalWorkerCount(loc);
                    }
                }
                snap.GuildTreasury = totalGuildTreasury;
                snap.GuildProduced = totalGuildProduced;
                snap.GuildWorkerCount = totalGuildWorkers;

                if (loc.Geist != null)
                {
                    snap.GeistDesperation = loc.Geist.Desperation;
                    snap.GeistBanditPool = loc.Geist.BanditPoolSize;
                    snap.GeistBanditSlotsEmitted = loc.Geist.LastBanditSlotsEmitted;
                }

                Array.Copy(loc.Stocks, snap.Stocks, _goodsCount);
                Array.Copy(loc.Prices, snap.Prices, _goodsCount);
                result.LocationSnapshots.Add(snap);
            }
        }

        // ====================================================================
        // PHASE C — DISABLED (contract wages, imperial spending, bank interest)
        // ====================================================================

        // ====================================================================
        // PHASE D — INTER-LOCATION TRADE MATCHING (unchanged)
        // ====================================================================

        RunTradeMatching(dangerMatrix, result);

        string bankInfo = ImperialGovernment != null
            ? $" bank[reserves={ImperialGovernment.Reserves:F0} loans={ImperialGovernment.ActiveLoans.Count} printed={ImperialGovernment.TotalPrinted:F0}]"
            : "";
        Godot.GD.Print($"[Economy] Tick {turn}: orders D/S={totalDemands}/{totalSupplies} deaths={result.Deaths} births={result.Births} moves+={result.MovesCreated.Count} moves-={result.MovesCompleted.Count} dispatches={result.ShipmentDispatches.Count}{bankInfo}");

        return result;
    }

    // -----------------------------------------------------------------------
    // Internal Trade Matching
    // -----------------------------------------------------------------------

    private struct DemandEntry
    {
        public int ThingIdx;
        public int LocationIdx;
        public float Quantity;
        public float MaxPrice;
        public float Priority;
    }

    private struct SupplyEntry
    {
        public int ThingIdx;
        public int LocationIdx;
        public float Quantity;
        public float CostBasis;
    }

    private struct ScoredPair
    {
        public int SupplyIdx;
        public int DemandIdx;
        public float Score;
        public float Safety;
    }

    private void RunTradeMatching(float[,] dangerMatrix, CsEconomyTickResult result)
    {
        var demands = new List<DemandEntry>();
        var supplies = new List<SupplyEntry>();

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                float totalDemand = loc.Population.GetTotalDemand(gi);
                float localStock = loc.Stocks[gi];
                float unmet = totalDemand - localStock;
                if (unmet > 0f)
                {
                    float priority = Goods[gi].ThingType == ThingType.Food ? 10f :
                                     Goods[gi].ThingType == ThingType.Weapons ? 3f : 1f;
                    demands.Add(new DemandEntry
                    {
                        ThingIdx = gi,
                        LocationIdx = li,
                        Quantity = unmet,
                        MaxPrice = loc.Prices[gi] * 1.5f,
                        Priority = priority,
                    });
                }

                float reserve = 0f;
                var sp = loc.Population.People;
                for (int pi = 0; pi < sp.Count; pi++)
                {
                    float w = sp[pi].GetWant(gi);
                    float h = sp[pi].GetInventory(gi);
                    reserve += MathF.Max(w - h, 0f);
                }
                float surplus = MathF.Max(localStock - reserve, localStock * 0.4f);
                if (surplus > 1f)
                {
                    supplies.Add(new SupplyEntry
                    {
                        ThingIdx = gi,
                        LocationIdx = li,
                        Quantity = surplus,
                        CostBasis = loc.CostBasis[gi],
                    });
                }
            }
        }

        if (demands.Count == 0 || supplies.Count == 0) return;

        var scored = new List<ScoredPair>(supplies.Count * 2);
        for (int si = 0; si < supplies.Count; si++)
        {
            var s = supplies[si];
            for (int di = 0; di < demands.Count; di++)
            {
                var d = demands[di];
                if (s.ThingIdx != d.ThingIdx) continue;
                if (s.LocationIdx == d.LocationIdx) continue;

                float safety = (dangerMatrix != null)
                    ? dangerMatrix[s.LocationIdx, d.LocationIdx]
                    : 1f;
                if (safety <= 0f) continue;

                float qty = MathF.Min(s.Quantity, d.Quantity);
                float deliveryValue = d.MaxPrice * qty * safety;
                if (deliveryValue <= 0f) continue;
                float acquisitionCost = s.CostBasis * qty;
                float margin = (deliveryValue - acquisitionCost) / MathF.Max(deliveryValue, 0.01f);
                float urgency = d.Priority / 10f;
                float score = (margin * 0.4f + urgency * 0.6f) * safety;
                if (score <= 0f) continue;

                scored.Add(new ScoredPair { SupplyIdx = si, DemandIdx = di, Score = score, Safety = safety });
            }
        }

        scored.Sort((a, b) => b.Score.CompareTo(a.Score));

        var supplyRemaining = new float[supplies.Count];
        var demandRemaining = new float[demands.Count];
        for (int i = 0; i < supplies.Count; i++) supplyRemaining[i] = supplies[i].Quantity;
        for (int i = 0; i < demands.Count; i++) demandRemaining[i] = demands[i].Quantity;

        for (int pi = 0; pi < scored.Count; pi++)
        {
            var pair = scored[pi];
            float availS = supplyRemaining[pair.SupplyIdx];
            float availD = demandRemaining[pair.DemandIdx];
            if (availS <= 0f || availD <= 0f) continue;

            float qty = MathF.Min(availS, availD);
            var s = supplies[pair.SupplyIdx];
            var d = demands[pair.DemandIdx];

            var srcLoc = Locations[s.LocationIdx];
            float realAvail = srcLoc.GetAvailable(s.ThingIdx);
            qty = MathF.Min(qty, realAvail);
            if (qty <= 0f) continue;

            srcLoc.Consume(s.ThingIdx, qty);
            supplyRemaining[pair.SupplyIdx] -= qty;
            demandRemaining[pair.DemandIdx] -= qty;

            int travelTime = 1;
            if (GetTravelTimeFunc != null)
            {
                int t = GetTravelTimeFunc(s.LocationIdx, d.LocationIdx);
                if (t > 0) travelTime = t;
            }

            string thingId = Goods[s.ThingIdx].ThingId;
            string srcId = Locations[s.LocationIdx].LocationId;
            string destId = Locations[d.LocationIdx].LocationId;
            var move = CsEconomyMove.Create(
                s.ThingIdx, qty, s.LocationIdx, d.LocationIdx,
                travelTime, "trade_match", srcId, destId, thingId);
            ActiveMoves.Add(move);
            result.MovesCreated.Add(move);

            _shipmentCounter++;
            float cargoValue = qty * Goods[s.ThingIdx].BasePrice;
            int guardCount;
            if (cargoValue < 20f) guardCount = 1;
            else if (cargoValue < 100f) guardCount = 2;
            else if (cargoValue < 300f) guardCount = 3;
            else guardCount = 4;

            result.ShipmentDispatches.Add(
                CsShipmentDispatch.Create($"shipment_{_shipmentCounter}", move, guardCount));
        }
    }

    internal Dictionary<string, int> _locationIdToIdx;
    internal Dictionary<string, int> _thingIdToIdx;
}
