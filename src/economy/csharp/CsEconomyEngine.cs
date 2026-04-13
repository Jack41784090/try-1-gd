using System;
using System.Collections.Generic;

namespace Condor.Economy;

/// <summary>
/// Per-location data held by the C# engine. Maps 1:1 with GDScript Location
/// objects that have economy data (population + inventory + natural_resources).
/// </summary>
public sealed class CsLocationData
{
    public int Idx { get; set; }
    public string LocationId { get; set; }
    public string LocationName { get; set; }
    public CsPopulation Population { get; set; }

    // Per-good stocks and prices, indexed by ThingDef.Id
    public float[] Stocks { get; set; }
    public float[] Prices { get; set; }

    public List<CsNaturalResource> NaturalResources { get; } = new();
    public CsGovernment Government { get; set; }
    public CsGuild Guild { get; set; }

    // Per-good cost basis tracking (FIFO average)
    public float[] CostBasis { get; set; }

    public CsLocationData(int goodsCount)
    {
        Stocks = new float[goodsCount];
        Prices = new float[goodsCount];
        CostBasis = new float[goodsCount];
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
}

public sealed class CsNaturalResource
{
    public int ThingIdx { get; set; }
    public float BaseCapacity { get; set; }
    public JobType WorkerJob { get; set; } = JobType.Farmer;
    public float WorkersNeeded { get; set; } = 50f;
}

/// <summary>
/// High-performance C# economy engine. All hot-path computation uses flat
/// arrays indexed by ThingDef.Id and location index, avoiding Dictionary overhead.
/// </summary>
public sealed class CsEconomyEngine
{
    public ThingDef[] Goods { get; private set; }
    public CsLocationData[] Locations { get; private set; }
    public List<CsEconomyMove> ActiveMoves { get; } = new();
    public CsCentralBank Bank { get; set; }
    public List<CsContract> ActiveContracts { get; } = new();
    public List<CsContract> CompletedContracts { get; } = new();
    public float NobleLoanThreshold { get; set; } = 100f;
    public float LoanAmount { get; set; } = 500f;
    public int TotalPromotions { get; set; }

    public int TotalDeaths { get; set; }
    public int TotalBirths { get; set; }

    private int _shipmentCounter;
    private int _goodsCount;
    private Random _rng = new();

    // Travel time callback — set by the bridge to delegate to GDScript World
    public Func<int, int, int> GetTravelTimeFunc { get; set; }

    public void Initialize(ThingDef[] goods, CsLocationData[] locations)
    {
        Goods = goods;
        Locations = locations;
        _goodsCount = goods.Length;
    }

    private int GetTravelTime(int fromIdx, int toIdx)
    {
        if (GetTravelTimeFunc != null)
        {
            int t = GetTravelTimeFunc(fromIdx, toIdx);
            return t > 0 ? t : 1;
        }
        return 1;
    }

    private float GetInTransitTo(int destIdx, int thingIdx)
    {
        float total = 0f;
        for (int i = 0; i < ActiveMoves.Count; i++)
        {
            var move = ActiveMoves[i];
            if (move.DestLocationIdx == destIdx && move.ThingIdx == thingIdx)
                total += move.Quantity;
        }
        return total;
    }

    private int CalculateGuardCount(CsEconomyMove move)
    {
        float cargoValue = move.Quantity * Goods[move.ThingIdx].BasePrice;
        if (cargoValue < 20f) return 1;
        if (cargoValue < 100f) return 2;
        if (cargoValue < 300f) return 3;
        return 4;
    }

    public CsEconomyTickResult Tick(int turn)
    {
        var result = new CsEconomyTickResult { Turn = turn };

        PhaseBankLending(turn);
        PhaseDemand();
        PhaseContracts();
        PhaseSupplyGeneration();
        PhaseSpoilage();
        PhaseSubsistence();
        PhaseTradeAdvance(result);
        PhasePriceUpdate();
        PhaseMarket();
        PhaseConsumption();
        PhaseWages();
        PhaseHouseholdWages();
        PhaseRent();
        PhaseGovernmentTax();
        PhaseGovernmentPlan();
        PhaseGovernmentExecute();
        PhaseGuildRecruit();
        PhaseGuildProduce();
        PhaseLoanRepayment();
        PhaseGovernmentSpending();
        PhaseSatisfaction();
        PhaseStarvation(result);
        PhaseResetTurnFlags();
        PhaseBirth(result);
        PhaseSocialMobility();

        // Snapshots
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
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
            if (loc.Guild != null)
            {
                snap.GuildTreasury = (float)loc.Guild.Treasury;
                snap.GuildProduced = loc.Guild.ProducedLastTick;
                snap.GuildWorkerCount = loc.Guild.WorkerCount;
            }
            Array.Copy(loc.Stocks, snap.Stocks, _goodsCount);
            Array.Copy(loc.Prices, snap.Prices, _goodsCount);
            result.LocationSnapshots.Add(snap);
        }

        return result;
    }

    /// <summary>Each person computes wants for all goods based on prices.</summary>
    private void PhaseDemand()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var people = loc.Population.People;
            for (int pi = 0; pi < people.Count; pi++)
                people[pi].ComputeWants(Goods, loc.Prices);
        }
    }

    /// <summary>Natural resources produce goods using workers; input-chain crafting consumes ingredients.</summary>
    private void PhaseSupplyGeneration()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            foreach (var resource in loc.NaturalResources)
            {
                var workers = loc.Population.GetByJob(resource.WorkerJob);
                int workerCount = workers.Count;
                if (workerCount == 0) continue;
                float ratio = MathF.Min((float)workerCount / resource.WorkersNeeded, 1f);
                float produced = resource.BaseCapacity * ratio;

                var thingDef = Goods[resource.ThingIdx];
                float costBasis = 0f;

                if (thingDef.Inputs.Length > 0)
                {
                    produced = LimitByInputs(loc, thingDef, produced);
                    if (produced <= 0f) continue;
                    costBasis = CalculateInputCost(loc, thingDef);
                    ConsumeInputs(loc, thingDef, produced);
                }

                // Update location cost basis as weighted average
                float existingStock = loc.Stocks[resource.ThingIdx];
                float existingCost = loc.CostBasis[resource.ThingIdx];
                float totalStock = existingStock + produced;
                if (totalStock > 0f)
                    loc.CostBasis[resource.ThingIdx] = (existingCost * existingStock + costBasis * produced) / totalStock;

                loc.Add(resource.ThingIdx, produced);
            }
        }
    }

    private float CalculateInputCost(CsLocationData loc, ThingDef thingDef)
    {
        float totalCost = 0f;
        foreach (var input in thingDef.Inputs)
        {
            totalCost += loc.Prices[input.ThingIdx] * input.Quantity;
        }
        return totalCost;
    }

    /// <summary>
    /// Limit production to what inputs can support.
    /// Returns the max units that can be produced given available inputs.
    /// </summary>
    private float LimitByInputs(CsLocationData loc, ThingDef thingDef, float desiredQty)
    {
        float maxProducible = desiredQty;
        foreach (var input in thingDef.Inputs)
        {
            float available = loc.GetAvailable(input.ThingIdx);
            float neededPerUnit = input.Quantity;
            if (neededPerUnit <= 0f) continue;
            float canProduce = available / neededPerUnit;
            maxProducible = MathF.Min(maxProducible, canProduce);
        }
        return MathF.Max(maxProducible, 0f);
    }

    private void ConsumeInputs(CsLocationData loc, ThingDef thingDef, float producedQty)
    {
        foreach (var input in thingDef.Inputs)
        {
            float toConsume = input.Quantity * producedQty;
            loc.Consume(input.ThingIdx, toConsume);
        }
    }

    /// <summary>5% of food stocks decay each turn to prevent infinite accumulation.</summary>
    private void PhaseSpoilage()
    {
        const float spoilageRate = 0.05f;
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                if (Goods[gi].ThingType != ThingType.Food) continue;
                float stock = loc.GetAvailable(gi);
                if (stock <= 0f) continue;
                float spoiled = stock * spoilageRate;
                loc.Consume(gi, spoiled);
            }
        }
    }

    /// <summary>Farmers take 1 food from local stock into personal inventory (pre-market self-feeding).</summary>
    private void PhaseSubsistence()
    {
        int foodIdx = -1;
        for (int i = 0; i < _goodsCount; i++)
        {
            if (Goods[i].ThingType == ThingType.Food) { foodIdx = i; break; }
        }
        if (foodIdx < 0) return;

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var farmers = loc.Population.GetByJob(JobType.Farmer);
            for (int fi = 0; fi < farmers.Count; fi++)
            {
                float available = loc.GetAvailable(foodIdx);
                if (available >= 1f)
                {
                    loc.Consume(foodIdx, 1f);
                    farmers[fi].AddInventory(foodIdx, 1f);
                }
            }
        }
    }

    /// <summary>In-transit trade shipments advance one step; arrivals deposit goods at destination.</summary>
    private void PhaseTradeAdvance(CsEconomyTickResult result)
    {
        var stillActive = new List<CsEconomyMove>();
        for (int i = 0; i < ActiveMoves.Count; i++)
        {
            var move = ActiveMoves[i];
            bool arrived = move.Advance();
            if (arrived)
            {
                var destLoc = Locations[move.DestLocationIdx];
                destLoc.Add(move.ThingIdx, move.Quantity);
                result.MovesCompleted.Add(move);
            }
            else
            {
                stillActive.Add(move);
            }
        }
        ActiveMoves.Clear();
        ActiveMoves.AddRange(stillActive);
    }

    /// <summary>
    /// Export pending demands from all locations. Unfulfilled wants become demands.
    /// Called by bridge after C# demand phase, before GDScript trade matching.
    /// </summary>
    public List<CsDemandExport> ExportPendingDemands()
    {
        var demands = new List<CsDemandExport>();
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                float totalDemand = loc.Population.GetTotalDemand(gi);
                float localSupply = loc.Stocks[gi];
                float unmet = totalDemand - localSupply;
                if (unmet <= 0f) continue;

                float priority = Goods[gi].ThingType == ThingType.Food ? 10f :
                                   Goods[gi].ThingType == ThingType.Weapons ? 3f : 1f;
                demands.Add(new CsDemandExport
                {
                    ThingIdx = gi,
                    ThingId = Goods[gi].ThingId,
                    Quantity = unmet,
                    MaxPrice = loc.Prices[gi] * 1.5f,
                    LocationIdx = li,
                    LocationId = loc.LocationId,
                    Priority = priority,
                });
            }
        }
        return demands;
    }

    /// <summary>
    /// Export available supplies from all locations. Surplus stock becomes supply.
    /// Called by bridge after C# supply generation, before GDScript trade matching.
    /// </summary>
    public List<CsSupplyExport> ExportAvailableSupplies()
    {
        var supplies = new List<CsSupplyExport>();
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                float totalDemand = loc.Population.GetTotalDemand(gi);
                float localStock = loc.Stocks[gi];
                // Reserve enough for local population, export the rest
                float reserve = 0f;
                var sp = loc.Population.People;
                for (int pi = 0; pi < sp.Count; pi++)
                {
                    float w = sp[pi].GetWant(gi);
                    float h = sp[pi].GetInventory(gi);
                    reserve += MathF.Max(w - h, 0f);
                }
                float surplus = MathF.Max(localStock - reserve, localStock * 0.4f);
                if (surplus <= 1f) continue;

                supplies.Add(new CsSupplyExport
                {
                    ThingIdx = gi,
                    ThingId = Goods[gi].ThingId,
                    Quantity = surplus,
                    CostBasis = loc.CostBasis[gi],
                    LocationIdx = li,
                    LocationId = loc.LocationId,
                });
            }
        }
        return supplies;
    }

    /// <summary>
    /// Apply trade matches from GDScript TradeMatcher.
    /// Creates economy moves and shipment dispatches for cross-location trades.
    /// </summary>
    public void ApplyTradeMatches(List<CsTradeMatchImport> matches, CsEconomyTickResult result)
    {
        foreach (var match in matches)
        {
            if (!_locationIdToIdx.TryGetValue(match.SourceLocationId, out int srcIdx)) continue;
            if (!_locationIdToIdx.TryGetValue(match.DestLocationId, out int destIdx)) continue;
            if (!_thingIdToIdx.TryGetValue(match.ThingId, out int thingIdx)) continue;

            var srcLoc = Locations[srcIdx];
            float available = srcLoc.GetAvailable(thingIdx);
            float sendQty = MathF.Min(match.Quantity, available);
            if (sendQty <= 0f) continue;

            srcLoc.Consume(thingIdx, sendQty);

            int travelTime = GetTravelTime(srcIdx, destIdx);
            var move = CsEconomyMove.Create(
                thingIdx, sendQty, srcIdx, destIdx,
                travelTime, "trade_match",
                match.SourceLocationId, match.DestLocationId, match.ThingId);
            ActiveMoves.Add(move);
            result.MovesCreated.Add(move);

            _shipmentCounter++;
            int guardCount = CalculateGuardCount(move);
            result.ShipmentDispatches.Add(
                CsShipmentDispatch.Create($"shipment_{_shipmentCounter}", move, guardCount));
        }
    }

    // Index lookups injected from bridge
    internal Dictionary<string, int> _locationIdToIdx;
    internal Dictionary<string, int> _thingIdToIdx;

    /// <summary>Prices adjust toward demand/supply ratio, clamped to 0.5x-3x base price.</summary>
    private void PhasePriceUpdate()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            for (int gi = 0; gi < _goodsCount; gi++)
            {
                float demand = loc.Population.GetTotalDemand(gi);
                float supply = MathF.Max(loc.Stocks[gi], 0.01f);
                float ratio = demand / supply;
                loc.Prices[gi] = Goods[gi].BasePrice * Math.Clamp(ratio, 0.5f, 3.0f);
            }
        }
    }

    /// <summary>People buy goods from local market (wealthiest first); revenue splits to producers/merchants.</summary>
    private void PhaseMarket()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var buyers = loc.Population.SortedByWealthDesc();
            for (int bi = 0; bi < buyers.Length; bi++)
            {
                var person = buyers[bi];
                for (int gi = 0; gi < _goodsCount; gi++)
                {
                    float wantQty = person.GetWant(gi);
                    float held = person.GetInventory(gi);
                    float need = MathF.Max(wantQty - held, 0f);
                    if (need <= 0f) continue;

                    float price = loc.GetPrice(gi);
                    float marketAvailable = loc.GetAvailable(gi);
                    float buyQty = MathF.Min(need, marketAvailable);
                    buyQty = person.CanAfford(price, buyQty);
                    if (buyQty <= 0f) continue;

                    person.Buy(gi, buyQty, price);
                    loc.Consume(gi, buyQty);
                    DistributeRevenue(loc, buyQty * price);
                }
            }
            loc.Population.MarkWealthDirty();
        }
    }

    private void DistributeRevenue(CsLocationData loc, float revenue)
    {
        // Split revenue: 15% merchant commission, 85% to producers (farmers + craftsmen)
        var merchants = loc.Population.GetByJob(JobType.Merchant);
        var farmers = loc.Population.GetByJob(JobType.Farmer);
        var craftsmen = loc.Population.GetByJob(JobType.Craftsman);
        int producerCount = farmers.Count + craftsmen.Count;

        float merchantCut = revenue * 0.15f;
        float producerCut = revenue * 0.85f;

        if (merchants.Count > 0)
        {
            float perMerchant = merchantCut / merchants.Count;
            for (int i = 0; i < merchants.Count; i++)
                merchants[i].Money += perMerchant;
        }
        else
        {
            producerCut += merchantCut;
        }

        if (producerCount > 0)
        {
            float perProducer = producerCut / producerCount;
            for (int i = 0; i < farmers.Count; i++)
                farmers[i].Money += perProducer;
            for (int i = 0; i < craftsmen.Count; i++)
                craftsmen[i].Money += perProducer;
        }
        else if (merchants.Count > 0)
        {
            float perMerchant = producerCut / merchants.Count;
            for (int i = 0; i < merchants.Count; i++)
                merchants[i].Money += perMerchant;
        }
        // If no merchants or producers, revenue is lost (shouldn't happen in practice)
    }

    /// <summary>People consume food (1 unit) and comfort goods from personal inventory.</summary>
    private void PhaseConsumption()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var people = Locations[li].Population.People;
            for (int pi = 0; pi < people.Count; pi++)
            {
                var person = people[pi];
                person.ComfortThisTurn = 0f;
                for (int gi = 0; gi < _goodsCount; gi++)
                {
                    float wantQty = person.GetWant(gi);
                    if (Goods[gi].ThingType == ThingType.Food)
                    {
                        float consumed = person.Consume(gi, 1f);
                        person.FedThisTurn = consumed >= 0.99f;
                    }
                    else
                    {
                        float consumed = person.Consume(gi, wantQty);
                        if (wantQty > 0f && consumed > 0f)
                            person.ComfortThisTurn += consumed / wantQty;
                    }
                }
            }
        }
    }

    /// <summary>Bank issues loans to nobles below wealth threshold.</summary>
    private void PhaseBankLending(int turn)
    {
        if (Bank == null) return;
        for (int li = 0; li < Locations.Length; li++)
        {
            var nobles = Locations[li].Population.GetByClass(SocialClass.Noble);
            for (int ni = 0; ni < nobles.Count; ni++)
            {
                if (Bank.ShouldIssueLoan(nobles[ni], NobleLoanThreshold, turn))
                    Bank.IssueLoan(nobles[ni], LoanAmount, turn);
            }
        }
    }

    /// <summary>Nobles commission contracts; workers/merchants are assigned; active contracts progress.</summary>
    private void PhaseContracts()
    {
        var newCompleted = new List<CsContract>();
        foreach (var c in ActiveContracts)
        {
            if (c.WorkOneTurn())
                newCompleted.Add(c);
        }
        foreach (var c in newCompleted)
        {
            ActiveContracts.Remove(c);
            CompletedContracts.Add(c);
        }

        var assignedSet = new HashSet<CsPerson>();
        var patronCounts = new Dictionary<CsPerson, int>();
        foreach (var c in ActiveContracts)
        {
            if (c.MerchantAssigned != null) assignedSet.Add(c.MerchantAssigned);
            foreach (var w in c.WorkersAssigned) assignedSet.Add(w);
            patronCounts.TryGetValue(c.Patron, out int cnt);
            patronCounts[c.Patron] = cnt + 1;
        }

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var nobles = loc.Population.GetByClass(SocialClass.Noble);
            var merchants = loc.Population.GetByClass(SocialClass.Bourgeois);
            var workers = loc.Population.GetByClass(SocialClass.Peasant);

            for (int ni = 0; ni < nobles.Count; ni++)
            {
                var noble = nobles[ni];
                patronCounts.TryGetValue(noble, out int currentCount);
                if (currentCount >= 2) continue;
                float surplus = noble.Money - NobleLoanThreshold;
                if (surplus < 50f) continue;
                float budget = surplus * 0.6f;
                int labor = Math.Clamp((int)(budget / 15f), 1, 10);
                const float wage = 1.5f;
                float merchantFee = budget * 0.15f;
                var contractType = PickContractType(noble);

                var contract = CsContract.Create(
                    contractType, noble, loc.LocationId,
                    budget, labor, 3, wage, merchantFee);
                AssignStaffFast(contract, merchants, workers, assignedSet);
                ActiveContracts.Add(contract);
                patronCounts[noble] = currentCount + 1;
            }
        }
    }

    private ContractType PickContractType(CsPerson noble)
    {
        var types = new[] { ContractType.Construction, ContractType.LuxuryGoods, ContractType.FoodSupply };
        int idx = (noble.PersonId.GetHashCode() & 0x7FFFFFFF) % types.Length;
        return types[idx];
    }

    private void AssignStaffFast(CsContract contract, List<CsPerson> merchants,
        List<CsPerson> workers, HashSet<CsPerson> assignedSet)
    {
        for (int i = 0; i < merchants.Count; i++)
        {
            if (!assignedSet.Contains(merchants[i]))
            {
                contract.AssignMerchant(merchants[i]);
                assignedSet.Add(merchants[i]);
                break;
            }
        }
        int assigned = 0;
        for (int i = 0; i < workers.Count; i++)
        {
            if (assigned >= contract.LaborNeeded) break;
            if (!assignedSet.Contains(workers[i]))
            {
                contract.AssignWorker(workers[i]);
                assignedSet.Add(workers[i]);
                assigned++;
            }
        }
    }

    /// <summary>Contract patrons pay wages to assigned workers and merchant fees.</summary>
    private void PhaseWages()
    {
        bool anyPaid = false;
        foreach (var contract in ActiveContracts)
        {
            if (contract.WorkersAssigned.Count == 0) continue;
            var patron = contract.Patron;
            float cost = contract.GetTotalCostPerTurn();
            float canPay = MathF.Min(patron.Money, cost);
            if (canPay <= 0f) continue;
            float wagePortion = contract.GetTotalWageCost();
            float merchantPortion = contract.MerchantFee;
            float total = wagePortion + merchantPortion;
            float payRatio = canPay / MathF.Max(total, 0.01f);

            for (int wi = 0; wi < contract.WorkersAssigned.Count; wi++)
            {
                float wPay = contract.WagePerWorker * payRatio;
                patron.Money -= wPay;
                contract.WorkersAssigned[wi].Money += wPay;
            }
            if (contract.MerchantAssigned != null)
            {
                float mPay = merchantPortion * payRatio;
                patron.Money -= mPay;
                contract.MerchantAssigned.Money += mPay;
            }
            anyPaid = true;
        }
        if (anyPaid)
        {
            for (int li = 0; li < Locations.Length; li++)
                Locations[li].Population.MarkWealthDirty();
        }
    }

    /// <summary>Nobles pay household servants a flat wage.</summary>
    private void PhaseHouseholdWages()
    {
        const float servantWage = 0.5f;
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var nobles = loc.Population.GetByClass(SocialClass.Noble);
            var servants = loc.Population.GetByJob(JobType.Servant);
            if (nobles.Count == 0 || servants.Count == 0) continue;
            int servantsPerNoble = (int)MathF.Ceiling(servants.Count / (float)nobles.Count);
            int servantIdx = 0;
            for (int ni = 0; ni < nobles.Count; ni++)
            {
                int count = 0;
                while (count < servantsPerNoble && servantIdx < servants.Count)
                {
                    float pay = MathF.Min(servantWage, nobles[ni].Money);
                    if (pay > 0f)
                    {
                        nobles[ni].Money -= pay;
                        servants[servantIdx].Money += pay;
                    }
                    servantIdx++;
                    count++;
                }
            }
            loc.Population.MarkWealthDirty();
        }
    }

    /// <summary>Peasants/bourgeois pay 8%/4% rent to nobles (wealth redistribution upward).</summary>
    private void PhaseRent()
    {
        const float rentRate = 0.08f;
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var nobles = loc.Population.GetByClass(SocialClass.Noble);
            if (nobles.Count == 0) continue;
            var peasants = loc.Population.GetByClass(SocialClass.Peasant);
            var bourgeois = loc.Population.GetByClass(SocialClass.Bourgeois);
            float totalRent = 0f;
            for (int i = 0; i < peasants.Count; i++)
            {
                float rent = peasants[i].Money * rentRate;
                if (rent > 0.01f)
                {
                    peasants[i].Money -= rent;
                    totalRent += rent;
                }
            }
            for (int i = 0; i < bourgeois.Count; i++)
            {
                float rent = bourgeois[i].Money * rentRate * 0.5f;
                if (rent > 0.01f)
                {
                    bourgeois[i].Money -= rent;
                    totalRent += rent;
                }
            }
            if (totalRent > 0f)
            {
                float perNoble = totalRent / nobles.Count;
                for (int ni = 0; ni < nobles.Count; ni++)
                    nobles[ni].Money += perNoble;
            }
            loc.Population.MarkWealthDirty();
        }
    }

    /// <summary>Bank collects interest and principal repayments on outstanding loans.</summary>
    private void PhaseLoanRepayment()
    {
        Bank?.CollectInterestAndRepayments();
    }

    /// <summary>Government collects income tax from people with >10 money.</summary>
    private void PhaseGovernmentTax()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var gov = loc.Government;
            if (gov == null) continue;
            gov.TaxCollectedLastTick = 0;
            gov.WorkersHiredLastTick = 0;
            gov.WagesPaidLastTick = 0;
            double taxCollected = 0;
            var people = loc.Population.People;
            for (int pi = 0; pi < people.Count; pi++)
            {
                var person = people[pi];
                if (person.Money > 10f)
                {
                    float tax = person.Money * (float)gov.TaxRate;
                    person.Money -= tax;
                    taxCollected += tax;
                }
            }
            gov.Treasury += taxCollected;
            gov.TaxCollectedLastTick = taxCollected;
        }
    }

    /// <summary>Government AI evaluates worker gaps and creates HireWorkers directives within budget.</summary>
    private void PhaseGovernmentPlan()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var gov = loc.Government;
            if (gov == null) continue;
            var newDirectives = GovernmentBrain.Evaluate(gov, loc, Goods, _goodsCount);
            gov.ActiveDirectives.AddRange(newDirectives);
        }
    }

    /// <summary>Government executes directives: hires unemployed/laborers, pays wages from treasury.</summary>
    private void PhaseGovernmentExecute()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var gov = loc.Government;
            if (gov == null) continue;
            for (int di = gov.ActiveDirectives.Count - 1; di >= 0; di--)
            {
                var directive = gov.ActiveDirectives[di];
                if (directive.Type == DirectiveType.HireWorkers)
                    ExecuteHireWorkers(loc, gov, directive);
                directive.AdvanceTurn();
                if (directive.IsExpired)
                    gov.ActiveDirectives.RemoveAt(di);
            }
        }
    }

    private void ExecuteHireWorkers(CsLocationData loc, CsGovernment gov, CsDirective directive)
    {
        int remaining = directive.Quantity - directive.WorkersHired;
        if (remaining <= 0) return;
        float budgetLeft = directive.BudgetAllocated - directive.BudgetSpent;
        if (budgetLeft < directive.WageOffered) return;

        var unemployed = loc.Population.GetByJob(JobType.Unemployed);
        var laborers = loc.Population.GetByJob(JobType.Laborer);
        var pool = new List<CsPerson>();
        pool.AddRange(unemployed);
        pool.AddRange(laborers);

        int hiredThisTick = 0;
        foreach (var person in pool)
        {
            if (hiredThisTick >= remaining) break;
            if (budgetLeft < directive.WageOffered) break;
            var oldClass = person.SocialClass;
            var oldJob = person.Job;
            person.Job = directive.JobTarget;
            person.Money += directive.WageOffered;
            loc.Population.NotifyClassChanged(person, oldClass, oldJob);
            directive.BudgetSpent += directive.WageOffered;
            budgetLeft -= directive.WageOffered;
            gov.Treasury -= directive.WageOffered;
            gov.WagesPaidLastTick += directive.WageOffered;
            directive.WorkersHired++;
            hiredThisTick++;
        }
        gov.WorkersHiredLastTick += hiredThisTick;
    }

    /// <summary>Central bank spends 10% of reserves as stimulus distributed to all peasants.</summary>
    private void PhaseGovernmentSpending()
    {
        if (Bank == null) return;
        float spend = Bank.Reserves * 0.1f;
        if (spend < 1f) return;
        Bank.Reserves -= spend;
        var allWorkers = new List<CsPerson>();
        for (int li = 0; li < Locations.Length; li++)
            allWorkers.AddRange(Locations[li].Population.GetByClass(SocialClass.Peasant));
        if (allWorkers.Count == 0) return;
        float perWorker = spend / allWorkers.Count;
        for (int i = 0; i < allWorkers.Count; i++)
            allWorkers[i].Money += perWorker;
    }

    private void PhaseGuildRecruit()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var guild = loc.Guild;
            if (guild == null) continue;
            GuildBrain.Evaluate(guild, loc);
        }
    }

    private void PhaseGuildProduce()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var guild = loc.Guild;
            if (guild == null) continue;
            guild.Produce(loc, Goods);
            guild.PayWages(loc);
            guild.CollectRevenue(loc, Goods);
        }
    }

    private void PhaseSatisfaction()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var people = Locations[li].Population.People;
            for (int pi = 0; pi < people.Count; pi++)
            {
                var person = people[pi];
                person.TurnsAlive++;
                if (person.FedThisTurn)
                    person.Satisfaction = MathF.Min(person.Satisfaction + 5f, 100f);
                else
                    person.Satisfaction = MathF.Max(person.Satisfaction - 15f, 0f);
                float comfortBonus = person.ComfortThisTurn * 2f;
                person.Satisfaction = MathF.Min(person.Satisfaction + comfortBonus, 100f);
            }
        }
    }

    /// <summary>Unfed people with low satisfaction accumulate starvation; 3+ consecutive turns = death.</summary>
    private void PhaseStarvation(CsEconomyTickResult result)
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var people = loc.Population.People;
            var toRemove = new List<CsPerson>();
            for (int pi = 0; pi < people.Count; pi++)
            {
                var person = people[pi];
                if (person.Satisfaction <= 0f && person.StarvationCounter > 0)
                {
                    person.StarvationCounter++;
                    if (person.StarvationCounter >= 5)
                        toRemove.Add(person);
                }
                else if (!person.FedThisTurn && person.Satisfaction < 20f)
                {
                    person.StarvationCounter++;
                    if (person.StarvationCounter >= 5)
                        toRemove.Add(person);
                }
                else
                {
                    person.StarvationCounter = 0;
                }
            }
            foreach (var dead in toRemove)
            {
                loc.Population.RemovePerson(dead);
                TotalDeaths++;
            }
            if (toRemove.Count > 0)
                result.Deaths += toRemove.Count;
        }
    }

    /// <summary>Clear per-turn flags (FedThisTurn, ComfortThisTurn) for next tick.</summary>
    private void PhaseResetTurnFlags()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var people = Locations[li].Population.People;
            for (int pi = 0; pi < people.Count; pi++)
            {
                people[pi].FedThisTurn = false;
                people[pi].ComfortThisTurn = 0f;
            }
        }
    }

    /// <summary>2% birth chance per satisfied person if food surplus exists at location.</summary>
    private void PhaseBirth(CsEconomyTickResult result)
    {
        int foodIdx = -1;
        for (int i = 0; i < _goodsCount; i++)
        {
            if (Goods[i].ThingType == ThingType.Food) { foodIdx = i; break; }
        }
        if (foodIdx < 0) return;

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            float foodSurplus = loc.GetAvailable(foodIdx);
            if (foodSurplus < 5f) continue;

            var people = loc.Population.People;
            int births = 0;
            int popSize = people.Count;
            for (int pi = 0; pi < popSize; pi++)
            {
                var person = people[pi];
                if (person.Satisfaction < 70f) continue;
                if (_rng.NextDouble() > 0.02) continue;
                births++;
            }

            for (int b = 0; b < births; b++)
            {
                // New person inherits most common class at location
                var peasants = loc.Population.GetByClass(SocialClass.Peasant);
                SocialClass newClass = peasants.Count > 0 ? SocialClass.Peasant : SocialClass.Bourgeois;
                JobType newJob = newClass == SocialClass.Peasant ? JobType.Laborer : JobType.Laborer;
                var newPerson = CsPerson.Create(
                    $"{loc.LocationId}_born_{TotalBirths}",
                    newClass, newJob, 0f, _goodsCount);
                newPerson.Satisfaction = 50f;
                loc.Population.AddPerson(newPerson);
                TotalBirths++;
            }
            if (births > 0)
                result.Births += births;
        }
    }

    /// <summary>Wealthy satisfied peasants have 10% chance to promote to bourgeois/merchant.</summary>
    private void PhaseSocialMobility()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var peasants = loc.Population.GetByClass(SocialClass.Peasant);
            var toPromote = new List<CsPerson>();
            for (int pi = 0; pi < peasants.Count; pi++)
            {
                var p = peasants[pi];
                if (p.Money < 100f || p.Satisfaction < 80f) continue;
                if (_rng.NextDouble() > 0.1) continue;
                toPromote.Add(p);
            }
            foreach (var p in toPromote)
            {
                var oldClass = p.SocialClass;
                var oldJob = p.Job;
                p.SocialClass = SocialClass.Bourgeois;
                p.Job = JobType.Merchant;
                loc.Population.NotifyClassChanged(p, oldClass, oldJob);
                TotalPromotions++;
            }
        }
    }
}
