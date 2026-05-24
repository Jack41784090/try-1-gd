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
    public CsGeist Geist { get; set; }

    // Per-good cost basis tracking (FIFO average)
    public float[] CostBasis { get; set; }

    // Price adjustment tracking: previous tick's demand/supply for gradual pricing
    public float[] LastDemand { get; set; }
    public float[] LastSupply { get; set; }

    // Tick-local order book for intangibles (services). Goods continue to flow
    // through the legacy market path; the order book unifies Subsistence,
    // Labor, MercenaryWork, BanditSlot, and Loan into one priority-sorted list.
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

/// <summary>
/// High-performance C# economy engine. All hot-path computation uses flat
/// arrays indexed by ThingDef.Id and location index, avoiding Dictionary overhead.
///
/// Tick pipeline (flat — no wrapper phases). Each step runs once per tick
/// in this order. Service-order matching is delegated to CsOrderMatcher.
/// </summary>
public sealed class CsEconomyEngine
{
    public ThingDef[] Goods { get; private set; }
    public CsLocationData[] Locations { get; private set; }
    public List<CsEconomyMove> ActiveMoves { get; } = new();
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
    private EconomyContext _ctx;
    private readonly CsOrderMatcher _orderMatcher = new();

    public Func<int, int, int> GetTravelTimeFunc { get; set; }

    /// <summary>
    /// Returns the imperial government — exactly one location must have IsImperial=true.
    /// Returns null if none configured (legacy / non-bank scenarios).
    /// </summary>
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

        // Auto-create CsGeist for every location with a population. The geist
        // is engine-internal — no .tres authoring required (per plan).
        for (int li = 0; li < locations.Length; li++)
        {
            var loc = locations[li];
            if (loc.Geist != null) continue;
            loc.Geist = new CsGeist
            {
                LocationIndex = li,
                LocationId = loc.LocationId,
            };
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

        int foodIdx = -1;
        for (int i = 0; i < _goodsCount; i++)
            if (Goods[i].ThingType == ThingType.Food) { foodIdx = i; break; }

        const float spoilageRate = 0.05f;
        const float adjustRate = 0.15f;
        const float minPriceRatio = 0.5f;
        const float maxPriceRatio = 3.0f;

        // ====================================================================
        // PHASE A — PRE-TICK GLOBALS
        // Move advancement, contract WorkOneTurn, build global assignment state.
        // ====================================================================

        var stillActive = new List<CsEconomyMove>();
        for (int i = 0; i < ActiveMoves.Count; i++)
        {
            var move = ActiveMoves[i];
            bool arrived = move.Advance();
            if (arrived)
            {
                Locations[move.DestLocationIdx].Add(move.ThingIdx, move.Quantity);
                result.MovesCompleted.Add(move);
            }
            else
            {
                stillActive.Add(move);
            }
        }
        ActiveMoves.Clear();
        ActiveMoves.AddRange(stillActive);

        var newCompleted = new List<CsContract>();
        foreach (var c in ActiveContracts)
            if (c.WorkOneTurn()) newCompleted.Add(c);
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

        int totalDemands = 0, totalSupplies = 0;

        // ====================================================================
        // PHASE B — PER-LOCATION MEGA-LOOP
        // All location-local work runs in one pass for cache locality.
        // ====================================================================

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];

            // --- B.1 Spoil Food ---
            if (foodIdx >= 0)
            {
                float stock = loc.GetAvailable(foodIdx);
                if (stock > 0f) loc.Consume(foodIdx, stock * spoilageRate);
            }

            // --- B.2 Update Prices ---
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
            loc.Government?.GenerateOrders(loc, _ctx);
            loc.Guild?.GenerateOrders(loc, _ctx);
            loc.Geist?.GenerateOrders(loc, _ctx);

            // --- B.4 Produce Natural Resources ---
            // TODO: based on contracts! Workers don't work for free 
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
                    float maxProducible = produced;
                    foreach (var input in thingDef.Inputs)
                    {
                        if (input.Quantity <= 0f) continue;
                        maxProducible = MathF.Min(maxProducible, loc.GetAvailable(input.ThingIdx) / input.Quantity);
                    }
                    produced = MathF.Max(maxProducible, 0f);

                    if (produced <= 0f) continue;

                    float totalCost = 0f;
                    foreach (var input in thingDef.Inputs)
                    {
                        totalCost += loc.Prices[input.ThingIdx] * input.Quantity;
                        loc.Consume(input.ThingIdx, input.Quantity * produced);
                    }
                    costBasis = totalCost;
                }

                float existingStock = loc.Stocks[resource.ThingIdx];
                float totalStock = existingStock + produced;
                if (totalStock > 0f)
                    loc.CostBasis[resource.ThingIdx] = (loc.CostBasis[resource.ThingIdx] * existingStock + costBasis * produced) / totalStock;

                loc.Add(resource.ThingIdx, produced);
            }

            // --- B.5 Subsistence: farmers eat own food ---
            if (foodIdx >= 0)
            {
                var farmers = loc.Population.GetByJob(JobType.Farmer);
                for (int fi = 0; fi < farmers.Count; fi++)
                {
                    if (loc.GetAvailable(foodIdx) >= 1f)
                    {
                        loc.Consume(foodIdx, 1f);
                        farmers[fi].AddInventory(foodIdx, 1f);
                    }
                }
            }

            // --- B.6 Match Local Service Orders ---
            totalDemands += loc.Demands.Count;
            totalSupplies += loc.Supplies.Count;
            _orderMatcher.Match(loc, _ctx);

            // --- B.7 Noble Contract Assignment (uses global assignedSet) ---
            var nobles = loc.Population.GetByClass(SocialClass.Noble);
            var peasants = loc.Population.GetByClass(SocialClass.Peasant);
            var bourgeois = loc.Population.GetByClass(SocialClass.Bourgeois);

            for (int ni = 0; ni < nobles.Count; ni++)
            {
                var noble = nobles[ni];
                patronCounts.TryGetValue(noble, out int currentCount);
                if (currentCount >= 2) continue;

                float surplus = noble.Money - NobleLoanThreshold;
                if (surplus < 50f) continue;

                float budget = surplus * 0.6f;
                int labor = Math.Clamp((int)(budget / 15f), 1, 10);
                float merchantFee = budget * 0.15f;

                var types = new[] { ContractType.Construction, ContractType.LuxuryGoods, ContractType.FoodSupply };
                int idx = (noble.PersonId.GetHashCode() & 0x7FFFFFFF) % types.Length;
                var contractType = types[idx];

                var contract = CsContract.Create(contractType, noble, loc.LocationId, budget, labor, 3, 1.5f, merchantFee);

                for (int i = 0; i < bourgeois.Count; i++)
                {
                    if (assignedSet.Add(bourgeois[i]))
                    {
                        contract.AssignMerchant(bourgeois[i]);
                        break;
                    }
                }

                int assigned = 0;
                for (int i = 0; i < peasants.Count; i++)
                {
                    if (assigned >= contract.LaborNeeded) break;
                    if (assignedSet.Add(peasants[i]))
                    {
                        contract.AssignWorker(peasants[i]);
                        assigned++;
                    }
                }

                ActiveContracts.Add(contract);
                patronCounts[noble] = currentCount + 1;
            }

            // --- B.8 Market Consumption & Revenue ---
            float[] startingStock = new float[_goodsCount];
            Array.Copy(loc.Stocks, startingStock, _goodsCount);

            var buyers = loc.Population.SortedByWealthDesc();
            for (int bi = 0; bi < buyers.Length; bi++)
            {
                var person = buyers[bi];
                person.ComfortThisTurn = 0f;

                for (int gi = 0; gi < _goodsCount; gi++)
                {
                    float wantQty = person.GetWant(gi);
                    float held = person.GetInventory(gi);
                    float need = MathF.Max(wantQty - held, 0f);

                    if (need > 0f)
                    {
                        float marketAvailable = loc.GetAvailable(gi);
                        if (marketAvailable > 0f)
                        {
                            float depletionRatio = startingStock[gi] > 0f ? 1f - (marketAvailable / startingStock[gi]) : 0f;
                            float effectivePrice = loc.GetPrice(gi) * (1f + (depletionRatio * depletionRatio * 0.5f));
                            float buyQty = MathF.Min(need, marketAvailable);
                            buyQty = person.CanAfford(effectivePrice, buyQty);

                            if (buyQty > 0f)
                            {
                                person.Buy(gi, buyQty, effectivePrice);
                                loc.Consume(gi, buyQty);

                                float revenue = buyQty * effectivePrice;
                                var merchants = loc.Population.GetByJob(JobType.Merchant);
                                var farmers = loc.Population.GetByJob(JobType.Farmer);
                                var craftsmen = loc.Population.GetByJob(JobType.Craftsman);
                                int producerCount = farmers.Count + craftsmen.Count;

                                float merchantCut = revenue * 0.15f;
                                float producerCut = revenue * 0.85f;

                                if (merchants.Count > 0)
                                {
                                    float perMerchant = merchantCut / merchants.Count;
                                    for (int i = 0; i < merchants.Count; i++) merchants[i].Money += perMerchant;
                                }
                                else producerCut += merchantCut;

                                if (producerCount > 0)
                                {
                                    float perProducer = producerCut / producerCount;
                                    for (int i = 0; i < farmers.Count; i++) farmers[i].Money += perProducer;
                                    for (int i = 0; i < craftsmen.Count; i++) craftsmen[i].Money += perProducer;
                                }
                                else if (merchants.Count > 0)
                                {
                                    float perMerchant = producerCut / merchants.Count;
                                    for (int i = 0; i < merchants.Count; i++) merchants[i].Money += perMerchant;
                                }
                            }
                        }
                    }

                    if (Goods[gi].ThingType == ThingType.Food)
                    {
                        person.FedThisTurn = person.Consume(gi, 1f) >= 0.99f;
                    }
                    else
                    {
                        float consumed = person.Consume(gi, wantQty);
                        if (wantQty > 0f && consumed > 0f) person.ComfortThisTurn += consumed / wantQty;
                    }
                }
            }

            // --- B.9 Household Wages ---
            var servants = loc.Population.GetByJob(JobType.Servant);
            if (nobles.Count > 0 && servants.Count > 0)
            {
                int servantsPerNoble = (int)MathF.Ceiling(servants.Count / (float)nobles.Count);
                int servantIdx = 0;
                for (int ni = 0; ni < nobles.Count; ni++)
                {
                    int count = 0;
                    while (count < servantsPerNoble && servantIdx < servants.Count)
                    {
                        float pay = MathF.Min(0.5f, nobles[ni].Money);
                        if (pay > 0f)
                        {
                            nobles[ni].Money -= pay;
                            servants[servantIdx].Money += pay;
                        }
                        servantIdx++;
                        count++;
                    }
                }
            }

            // --- B.10 Rent ---
            if (nobles.Count > 0)
            {
                float totalRent = 0f;
                for (int i = 0; i < peasants.Count; i++)
                {
                    float rent = peasants[i].Money * 0.08f;
                    if (rent > 0.01f) { peasants[i].Money -= rent; totalRent += rent; }
                }
                for (int i = 0; i < bourgeois.Count; i++)
                {
                    float rent = bourgeois[i].Money * 0.04f;
                    if (rent > 0.01f) { bourgeois[i].Money -= rent; totalRent += rent; }
                }
                if (totalRent > 0f)
                {
                    float perNoble = totalRent / nobles.Count;
                    for (int ni = 0; ni < nobles.Count; ni++) nobles[ni].Money += perNoble;
                }
            }

            // --- B.11 Government Update ---
            if (loc.Government != null)
            {
                var gov = loc.Government;
                gov.TaxCollectedLastTick = 0;
                double taxCollected = 0;
                var pop = loc.Population.People;
                for (int pi = 0; pi < pop.Count; pi++)
                {
                    if (pop[pi].Money > 10f)
                    {
                        float tax = pop[pi].Money * (float)gov.TaxRate;
                        pop[pi].Money -= tax;
                        taxCollected += tax;
                    }
                }
                gov.Treasury += taxCollected;
                gov.TaxCollectedLastTick = taxCollected;

                for (int di = gov.ActiveDirectives.Count - 1; di >= 0; di--)
                {
                    var directive = gov.ActiveDirectives[di];
                    if (directive.Type == DirectiveType.HireWorkers)
                    {
                        int remaining = directive.Quantity - directive.WorkersHired;
                        float budgetLeft = directive.BudgetAllocated - directive.BudgetSpent;
                        if (remaining > 0 && budgetLeft >= directive.WageOffered)
                        {
                            var pool = new List<CsPerson>(loc.Population.GetByJob(JobType.Unemployed));
                            pool.AddRange(loc.Population.GetByJob(JobType.Laborer));

                            int hired = 0;
                            foreach (var p in pool)
                            {
                                if (hired >= remaining || budgetLeft < directive.WageOffered) break;
                                var oldClass = p.SocialClass;
                                var oldJob = p.Job;
                                p.Job = directive.JobTarget;
                                p.Money += directive.WageOffered;
                                loc.Population.NotifyClassChanged(p, oldClass, oldJob);

                                directive.BudgetSpent += directive.WageOffered;
                                budgetLeft -= directive.WageOffered;
                                gov.Treasury -= directive.WageOffered;
                                gov.WagesPaidLastTick += directive.WageOffered;
                                directive.WorkersHired++;
                                hired++;
                            }
                            gov.WorkersHiredLastTick += hired;
                        }
                    }
                    directive.AdvanceTurn();
                    if (directive.IsExpired) gov.ActiveDirectives.RemoveAt(di);
                }
            }

            // --- B.12 Guild Production ---
            if (loc.Guild != null)
            {
                loc.Guild.Produce(loc, Goods);
                loc.Guild.PayWages(loc);
                loc.Guild.CollectRevenue(loc, Goods);
            }

            loc.Population.MarkWealthDirty();

            // --- B.13 Population State (satisfaction, starvation, births, mobility) ---
            {
                var stateePeople = loc.Population.People;
                var toRemove = new List<CsPerson>();
                int births = 0;
                float foodSurplus = foodIdx >= 0 ? loc.GetAvailable(foodIdx) : 0f;

                for (int pi = 0; pi < stateePeople.Count; pi++)
                {
                    var person = stateePeople[pi];
                    person.TurnsAlive++;

                    if (person.FedThisTurn) person.Satisfaction = MathF.Min(person.Satisfaction + 5f, 100f);
                    else person.Satisfaction = MathF.Max(person.Satisfaction - 15f, 0f);
                    person.Satisfaction = MathF.Min(person.Satisfaction + (person.ComfortThisTurn * 2f), 100f);

                    if ((person.Satisfaction <= 0f && person.StarvationCounter > 0) || (!person.FedThisTurn && person.Satisfaction < 20f))
                    {
                        if (++person.StarvationCounter >= 5) toRemove.Add(person);
                    }
                    else person.StarvationCounter = 0;

                    if (foodSurplus >= 5f && person.Satisfaction >= 70f && _rng.NextDouble() <= 0.02) births++;

                    person.FedThisTurn = false;
                    person.ComfortThisTurn = 0f;
                }

                foreach (var dead in toRemove)
                {
                    loc.Population.RemovePerson(dead);
                    TotalDeaths++;
                }
                if (toRemove.Count > 0) result.Deaths += toRemove.Count;

                for (int b = 0; b < births; b++)
                {
                    var localPeasants = loc.Population.GetByClass(SocialClass.Peasant);
                    var newPerson = CsPerson.Create($"{loc.LocationId}_born_{TotalBirths}", localPeasants.Count > 0 ? SocialClass.Peasant : SocialClass.Bourgeois, JobType.Laborer, 0f, _goodsCount);
                    newPerson.Satisfaction = 50f;
                    loc.Population.AddPerson(newPerson);
                    TotalBirths++;
                }
                if (births > 0) result.Births += births;

                // Social Mobility
                var peasantsList = loc.Population.GetByClass(SocialClass.Peasant);
                for (int pi = 0; pi < peasantsList.Count; pi++)
                {
                    var p = peasantsList[pi];
                    if (p.Money >= 100f && p.Satisfaction >= 80f && _rng.NextDouble() <= 0.1)
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

            // --- B.14 Geist Update ---
            loc.Geist?.UpdateState(loc, Goods);

            // --- B.15 Snapshot ---
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
                if (loc.Guild != null)
                {
                    snap.GuildTreasury = (float)loc.Guild.Treasury;
                    snap.GuildProduced = loc.Guild.ProducedLastTick;
                    snap.GuildWorkerCount = loc.Guild.WorkerCount;
                }
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
        // PHASE C — POST-TICK GLOBALS
        // Pay global contract wages, imperial bank interest+spending.
        // ====================================================================

        bool anyPaid = false;
        foreach (var contract in ActiveContracts)
        {
            if (contract.WorkersAssigned.Count == 0) continue;
            var patron = contract.Patron;
            float canPay = MathF.Min(patron.Money, contract.GetTotalCostPerTurn());
            if (canPay <= 0f) continue;

            float payRatio = canPay / MathF.Max(contract.GetTotalWageCost() + contract.MerchantFee, 0.01f);

            for (int wi = 0; wi < contract.WorkersAssigned.Count; wi++)
            {
                float wPay = contract.WagePerWorker * payRatio;
                patron.Money -= wPay;
                contract.WorkersAssigned[wi].Money += wPay;
            }
            if (contract.MerchantAssigned != null)
            {
                float mPay = contract.MerchantFee * payRatio;
                patron.Money -= mPay;
                contract.MerchantAssigned.Money += mPay;
            }
            anyPaid = true;
        }

        if (anyPaid)
        {
            for (int li = 0; li < Locations.Length; li++) Locations[li].Population.MarkWealthDirty();
        }

        ImperialGovernment?.CollectInterestAndRepayments();
        if (ImperialGovernment != null)
        {
            float spend = ImperialGovernment.Reserves * 0.1f;
            if (spend >= 1f)
            {
                ImperialGovernment.Reserves -= spend;
                var allWorkers = new List<CsPerson>();
                for (int li = 0; li < Locations.Length; li++) allWorkers.AddRange(Locations[li].Population.GetByClass(SocialClass.Peasant));
                if (allWorkers.Count > 0)
                {
                    float perWorker = spend / allWorkers.Count;
                    for (int i = 0; i < allWorkers.Count; i++) allWorkers[i].Money += perWorker;
                }
            }
        }

        // ====================================================================
        // PHASE D — INTERNAL TRADE MATCHING
        // Pure-C# greedy match using pre-computed danger matrix.
        // Creates moves + shipment dispatches inline; no GDScript ping-pong.
        // ====================================================================

        RunTradeMatching(dangerMatrix, result);

        string bankInfo = ImperialGovernment != null ? $" bank[reserves={ImperialGovernment.Reserves:F0} loans={ImperialGovernment.ActiveLoans.Count} printed={ImperialGovernment.TotalPrinted:F0}]" : "";
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
        // Build demand/supply views from post-tick state.
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

        // Score every valid (supply, demand) pair.
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
                float margin = (deliveryValue - acquisitionCost) / deliveryValue;
                float urgency = d.Priority / 10f;
                float score = (margin * 0.4f + urgency * 0.6f) * safety;
                if (score <= 0f) continue;

                scored.Add(new ScoredPair { SupplyIdx = si, DemandIdx = di, Score = score, Safety = safety });
            }
        }

        scored.Sort((a, b) => b.Score.CompareTo(a.Score));

        // Greedy reserve + apply.
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

    // -----------------------------------------------------------------------

    internal Dictionary<string, int> _locationIdToIdx;
    internal Dictionary<string, int> _thingIdToIdx;
}
