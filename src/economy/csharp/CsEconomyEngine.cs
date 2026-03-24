using System;
using System.Collections.Generic;

namespace Condor.Economy;

/// <summary>
/// Per-location data held by the C# engine. Maps 1:1 with GDScript Location
/// objects that have economy data (population + inventory + supply_rules).
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

    public List<CsSupplyRule> SupplyRules { get; } = new();

    public CsLocationData(int goodsCount)
    {
        Stocks = new float[goodsCount];
        Prices = new float[goodsCount];
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

public sealed class CsSupplyRule
{
    public string RuleId { get; set; }
    public int ThingIdx { get; set; }
    public RuleAction Action { get; set; }
    public int SourceLocationIdx { get; set; } = -1;
    public string SourceLocationId { get; set; } = "";
    public float CapacityPerTurn { get; set; }
    public JobType WorkerJob { get; set; } = JobType.Farmer;
    public float WorkersPerFullOutput { get; set; } = 50f;
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

        PhaseBankLending();
        PhaseDemand();
        PhaseContracts();
        PhaseProduction();
        PhaseSubsistence();
        PhaseTradeAdvance(result);
        PhaseTradeDispatch(result);
        PhasePriceUpdate();
        PhaseMarket();
        PhaseConsumption();
        PhaseWages();
        PhaseHouseholdWages();
        PhaseRent();
        PhaseLoanRepayment();
        PhaseGovernmentSpending();
        PhaseSatisfaction();
        PhaseStarvation(result);
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
            Array.Copy(loc.Stocks, snap.Stocks, _goodsCount);
            Array.Copy(loc.Prices, snap.Prices, _goodsCount);
            result.LocationSnapshots.Add(snap);
        }

        return result;
    }

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

    private void PhaseProduction()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            foreach (var rule in loc.SupplyRules)
            {
                if (rule.Action == RuleAction.Extract)
                {
                    var workers = loc.Population.GetByJob(rule.WorkerJob);
                    int workerCount = workers.Count;
                    if (workerCount == 0) continue;
                    float ratio = MathF.Min((float)workerCount / rule.WorkersPerFullOutput, 1f);
                    float produced = rule.CapacityPerTurn * ratio;

                    // If the output thing has inputs, consume them proportionally
                    var thingDef = Goods[rule.ThingIdx];
                    if (thingDef.Inputs.Length > 0)
                    {
                        produced = LimitByInputs(loc, thingDef, produced);
                        if (produced <= 0f) continue;
                        ConsumeInputs(loc, thingDef, produced);
                    }

                    loc.Add(rule.ThingIdx, produced);
                }
                else if (rule.Action == RuleAction.Produce)
                {
                    float produced = rule.CapacityPerTurn;

                    var thingDef = Goods[rule.ThingIdx];
                    if (thingDef.Inputs.Length > 0)
                    {
                        produced = LimitByInputs(loc, thingDef, produced);
                        if (produced <= 0f) continue;
                        ConsumeInputs(loc, thingDef, produced);
                    }

                    loc.Add(rule.ThingIdx, produced);
                }
            }
        }
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

    private void PhaseTradeDispatch(CsEconomyTickResult result)
    {
        // orderedThisTick[locIdx * goodsCount + thingIdx] = amount
        var orderedThisTick = new Dictionary<int, float>();
        // sourceReserveCache[locIdx * goodsCount + thingIdx] = reserve
        var sourceReserveCache = new Dictionary<int, float>();
        // consumptionCache[locIdx * goodsCount + thingIdx] = consumption
        var consumptionCache = new Dictionary<int, float>();

        // Build candidate list with scoring
        var candidates = new List<TradeCandidate>();

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            foreach (var rule in loc.SupplyRules)
            {
                if (rule.Action != RuleAction.Import) continue;

                int consKey = li * _goodsCount + rule.ThingIdx;
                float consumptionPerTurn;
                if (consumptionCache.TryGetValue(consKey, out float cached))
                    consumptionPerTurn = cached;
                else
                {
                    consumptionPerTurn = loc.Population.GetTotalDemand(rule.ThingIdx);
                    consumptionCache[consKey] = consumptionPerTurn;
                }
                if (consumptionPerTurn <= 0f) continue;

                int travelTime = GetTravelTime(rule.SourceLocationIdx, li);
                float coverageNeeded = consumptionPerTurn * (travelTime + 0.5f);
                float localSupply = loc.GetAvailable(rule.ThingIdx);
                float inTransit = GetInTransitTo(li, rule.ThingIdx);
                float projectedSupply = localSupply + inTransit;
                if (projectedSupply >= coverageNeeded) continue;

                float shortfall = coverageNeeded - projectedSupply;

                // Score: urgency (shortfall / coverage) * 0.6 + margin * 0.4
                float urgency = coverageNeeded > 0f ? shortfall / coverageNeeded : 0f;
                float destPrice = loc.GetPrice(rule.ThingIdx);
                float srcPrice = rule.SourceLocationIdx >= 0 && rule.SourceLocationIdx < Locations.Length
                    ? Locations[rule.SourceLocationIdx].GetPrice(rule.ThingIdx) : Goods[rule.ThingIdx].BasePrice;
                float transportCost = Goods[rule.ThingIdx].BasePrice * 0.1f * travelTime;
                float margin = destPrice > 0f ? (destPrice - srcPrice - transportCost) / destPrice : 0f;
                float score = urgency * 0.6f + MathF.Max(margin, 0f) * 0.4f;

                candidates.Add(new TradeCandidate
                {
                    DestIdx = li,
                    Rule = rule,
                    Shortfall = shortfall,
                    TravelTime = travelTime,
                    Score = score,
                });
            }
        }

        // Sort by score descending — highest priority dispatched first
        candidates.Sort((a, b) => b.Score.CompareTo(a.Score));

        foreach (var c in candidates)
        {
            var loc = Locations[c.DestIdx];
            var rule = c.Rule;

            // Recheck projected supply with already-ordered
            int key = c.DestIdx * _goodsCount + rule.ThingIdx;
            float alreadyOrdered = orderedThisTick.GetValueOrDefault(key, 0f);
            float localSupply = loc.GetAvailable(rule.ThingIdx);
            float inTransit = GetInTransitTo(c.DestIdx, rule.ThingIdx);
            float projectedSupply = localSupply + inTransit + alreadyOrdered;

            int consKey = c.DestIdx * _goodsCount + rule.ThingIdx;
            float consumptionPerTurn = consumptionCache[consKey];
            float coverageNeeded = consumptionPerTurn * (c.TravelTime + 0.5f);
            if (projectedSupply >= coverageNeeded) continue;
            float shortfall = coverageNeeded - projectedSupply;

            if (rule.SourceLocationIdx < 0 || rule.SourceLocationIdx >= Locations.Length)
                continue;
            var sourceLoc = Locations[rule.SourceLocationIdx];
            float rawSource = sourceLoc.GetAvailable(rule.ThingIdx);
            if (rawSource <= 0f) continue;

            int reserveKey = rule.SourceLocationIdx * _goodsCount + rule.ThingIdx;
            float sourceReserve;
            if (sourceReserveCache.TryGetValue(reserveKey, out float cachedReserve))
                sourceReserve = cachedReserve;
            else
            {
                sourceReserve = 0f;
                var sp = sourceLoc.Population.People;
                for (int pi = 0; pi < sp.Count; pi++)
                {
                    float w = sp[pi].GetWant(rule.ThingIdx);
                    float h = sp[pi].GetInventory(rule.ThingIdx);
                    sourceReserve += MathF.Max(w - h, 0f);
                }
                sourceReserveCache[reserveKey] = sourceReserve;
            }

            float availableAtSource = MathF.Max(rawSource - sourceReserve, rawSource * 0.4f);
            if (availableAtSource <= 0f) continue;

            float sendQty = MathF.Min(shortfall, MathF.Min(availableAtSource, rule.CapacityPerTurn));
            sourceLoc.Consume(rule.ThingIdx, sendQty);
            orderedThisTick[key] = alreadyOrdered + sendQty;

            var move = CsEconomyMove.Create(
                rule.ThingIdx, sendQty, rule.SourceLocationIdx, c.DestIdx,
                c.TravelTime, $"rule:{rule.RuleId}",
                sourceLoc.LocationId, loc.LocationId, Goods[rule.ThingIdx].ThingId);
            ActiveMoves.Add(move);
            result.MovesCreated.Add(move);

            _shipmentCounter++;
            int guardCount = CalculateGuardCount(move);
            result.ShipmentDispatches.Add(
                CsShipmentDispatch.Create($"shipment_{_shipmentCounter}", move, guardCount));
        }
    }

    private struct TradeCandidate
    {
        public int DestIdx;
        public CsSupplyRule Rule;
        public float Shortfall;
        public int TravelTime;
        public float Score;
    }

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
        var merchants = loc.Population.GetByJob(JobType.Merchant);
        if (merchants.Count == 0) return;
        float share = revenue * 0.5f / merchants.Count;
        for (int i = 0; i < merchants.Count; i++)
            merchants[i].Money += share;
    }

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

    private void PhaseBankLending()
    {
        if (Bank == null) return;
        for (int li = 0; li < Locations.Length; li++)
        {
            var nobles = Locations[li].Population.GetByClass(SocialClass.Noble);
            for (int ni = 0; ni < nobles.Count; ni++)
            {
                if (Bank.ShouldIssueLoan(nobles[ni], NobleLoanThreshold))
                    Bank.IssueLoan(nobles[ni], LoanAmount);
            }
        }
    }

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

    private void PhaseLoanRepayment()
    {
        Bank?.CollectInterestAndRepayments();
    }

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
                person.FedThisTurn = false;
                person.ComfortThisTurn = 0f;
            }
        }
    }

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
                    if (person.StarvationCounter >= 3)
                        toRemove.Add(person);
                }
                else if (!person.FedThisTurn && person.Satisfaction < 20f)
                {
                    person.StarvationCounter++;
                    if (person.StarvationCounter >= 3)
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

    private void PhaseBirth(CsEconomyTickResult result)
    {
        // Growth: ~2% chance per person per turn if satisfaction > 70 and food surplus
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
