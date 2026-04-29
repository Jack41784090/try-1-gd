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

    private int GetTravelTime(int fromIdx, int toIdx)
    {
        if (GetTravelTimeFunc != null)
        {
            int t = GetTravelTimeFunc(fromIdx, toIdx);
            return t > 0 ? t : 1;
        }
        return 1;
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

        _ctx.CurrentTurn = turn;
        _ctx.NobleLoanThreshold = NobleLoanThreshold;
        _ctx.LoanAmount = LoanAmount;
        _ctx.ImperialGovernment = ImperialGovernment;

        // === System: trade advance, spoilage, price update, order-book clear ===
        AdvanceTradeMoves(result);
        SpoilFood();
        UpdatePrices();
        for (int li = 0; li < Locations.Length; li++)
            Locations[li].ClearOrderBook();

        // === GenerateOrders: actors emit Supply/Demand; production runs ===
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var people = loc.Population.People;
            for (int pi = 0; pi < people.Count; pi++)
                people[pi].GenerateOrders(loc, _ctx);
            loc.Government?.GenerateOrders(loc, _ctx);
            loc.Guild?.GenerateOrders(loc, _ctx);
            loc.Geist?.GenerateOrders(loc, _ctx);
            ProduceFromNaturalResources(loc);
        }

        // === MatchOrders: subsistence then priority-sorted service matching ===
        PhaseSubsistence();
        int totalDemands = 0, totalSupplies = 0;
        for (int li = 0; li < Locations.Length; li++)
        {
            totalDemands += Locations[li].Demands.Count;
            totalSupplies += Locations[li].Supplies.Count;
            _orderMatcher.Match(Locations[li], _ctx);
        }

        // === Execute: goods market, consumption, wages, government, guild, bank ===
        PhaseContracts();
        PhaseMarket();
        PhaseConsumption();
        PhaseWages();
        PhaseHouseholdWages();
        PhaseRent();
        PhaseGovernmentTax();
        PhaseGovernmentExecuteDirectives();
        PhaseGuildProduce();
        ImperialGovernment?.CollectInterestAndRepayments();
        PhaseImperialSpending();

        // === PostUpdate: satisfaction, deaths, births, mobility, geist ===
        PhaseSatisfaction();
        PhaseStarvation(result);
        PhaseResetTurnFlags();
        PhaseBirth(result);
        PhaseSocialMobility();
        for (int li = 0; li < Locations.Length; li++)
            Locations[li].Geist?.UpdateState(Locations[li], Goods);

        BuildSnapshots(result);

        // Per-tick summary: orders, deaths/births, imperial bank state
        string bankInfo = ImperialGovernment != null
            ? $" bank[reserves={ImperialGovernment.Reserves:F0} loans={ImperialGovernment.ActiveLoans.Count} printed={ImperialGovernment.TotalPrinted:F0}]"
            : "";
        Godot.GD.Print(
            $"[Economy] Tick {turn}: orders D/S={totalDemands}/{totalSupplies} " +
            $"deaths={result.Deaths} births={result.Births} moves+={result.MovesCreated.Count} moves-={result.MovesCompleted.Count}{bankInfo}");

        return result;
    }

    // -----------------------------------------------------------------------
    // System helpers
    // -----------------------------------------------------------------------

    private void AdvanceTradeMoves(CsEconomyTickResult result)
    {
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
    }

    private void SpoilFood()
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
                loc.Consume(gi, stock * spoilageRate);
            }
        }
    }

    private void UpdatePrices()
    {
        const float adjustRate = 0.15f;
        const float minPriceRatio = 0.5f;
        const float maxPriceRatio = 3.0f;

        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
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
        }
    }

    private void ProduceFromNaturalResources(CsLocationData loc)
    {
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

            float existingStock = loc.Stocks[resource.ThingIdx];
            float existingCost = loc.CostBasis[resource.ThingIdx];
            float totalStock = existingStock + produced;
            if (totalStock > 0f)
                loc.CostBasis[resource.ThingIdx] = (existingCost * existingStock + costBasis * produced) / totalStock;

            loc.Add(resource.ThingIdx, produced);
        }
    }

    private float CalculateInputCost(CsLocationData loc, ThingDef thingDef)
    {
        float total = 0f;
        foreach (var input in thingDef.Inputs)
            total += loc.Prices[input.ThingIdx] * input.Quantity;
        return total;
    }

    private float LimitByInputs(CsLocationData loc, ThingDef thingDef, float desiredQty)
    {
        float maxProducible = desiredQty;
        foreach (var input in thingDef.Inputs)
        {
            float available = loc.GetAvailable(input.ThingIdx);
            if (input.Quantity <= 0f) continue;
            maxProducible = MathF.Min(maxProducible, available / input.Quantity);
        }
        return MathF.Max(maxProducible, 0f);
    }

    private void ConsumeInputs(CsLocationData loc, ThingDef thingDef, float producedQty)
    {
        foreach (var input in thingDef.Inputs)
            loc.Consume(input.ThingIdx, input.Quantity * producedQty);
    }

    // -----------------------------------------------------------------------
    // MatchOrders helpers
    // -----------------------------------------------------------------------

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
                if (loc.GetAvailable(foodIdx) >= 1f)
                {
                    loc.Consume(foodIdx, 1f);
                    farmers[fi].AddInventory(foodIdx, 1f);
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Execute helpers (each called once from Tick — retained for navigation)
    // -----------------------------------------------------------------------

    private void PhaseMarket()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            float[] startingStock = new float[_goodsCount];
            Array.Copy(loc.Stocks, startingStock, _goodsCount);

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

                    float marketAvailable = loc.GetAvailable(gi);
                    if (marketAvailable <= 0f) continue;

                    float baseTickPrice = loc.GetPrice(gi);
                    float depletionRatio = startingStock[gi] > 0f
                        ? 1f - (marketAvailable / startingStock[gi])
                        : 0f;
                    float scarcityMarkup = depletionRatio * depletionRatio * 0.5f;
                    float effectivePrice = baseTickPrice * (1f + scarcityMarkup);

                    float buyQty = MathF.Min(need, marketAvailable);
                    buyQty = person.CanAfford(effectivePrice, buyQty);
                    if (buyQty <= 0f) continue;

                    person.Buy(gi, buyQty, effectivePrice);
                    loc.Consume(gi, buyQty);
                    DistributeRevenue(loc, buyQty * effectivePrice);
                }
            }
            loc.Population.MarkWealthDirty();
        }
    }

    private void DistributeRevenue(CsLocationData loc, float revenue)
    {
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
                if (rent > 0.01f) { peasants[i].Money -= rent; totalRent += rent; }
            }
            for (int i = 0; i < bourgeois.Count; i++)
            {
                float rent = bourgeois[i].Money * rentRate * 0.5f;
                if (rent > 0.01f) { bourgeois[i].Money -= rent; totalRent += rent; }
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

    private void PhaseGovernmentTax()
    {
        for (int li = 0; li < Locations.Length; li++)
        {
            var loc = Locations[li];
            var gov = loc.Government;
            if (gov == null) continue;
            gov.TaxCollectedLastTick = 0;
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

    private void PhaseGovernmentExecuteDirectives()
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

    private void PhaseImperialSpending()
    {
        var imperial = ImperialGovernment;
        if (imperial == null) return;
        float spend = imperial.Reserves * 0.1f;
        if (spend < 1f) return;
        imperial.Reserves -= spend;
        var allWorkers = new List<CsPerson>();
        for (int li = 0; li < Locations.Length; li++)
            allWorkers.AddRange(Locations[li].Population.GetByClass(SocialClass.Peasant));
        if (allWorkers.Count == 0) return;
        float perWorker = spend / allWorkers.Count;
        for (int i = 0; i < allWorkers.Count; i++)
            allWorkers[i].Money += perWorker;
    }

    // -----------------------------------------------------------------------
    // PostUpdate helpers (each called once from Tick — retained for navigation)
    // -----------------------------------------------------------------------

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
                    if (person.StarvationCounter >= 5) toRemove.Add(person);
                }
                else if (!person.FedThisTurn && person.Satisfaction < 20f)
                {
                    person.StarvationCounter++;
                    if (person.StarvationCounter >= 5) toRemove.Add(person);
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
                var peasants = loc.Population.GetByClass(SocialClass.Peasant);
                SocialClass newClass = peasants.Count > 0 ? SocialClass.Peasant : SocialClass.Bourgeois;
                JobType newJob = JobType.Laborer;
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

    // -----------------------------------------------------------------------
    // Snapshots and exports
    // -----------------------------------------------------------------------

    private void BuildSnapshots(CsEconomyTickResult result)
    {
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

    internal Dictionary<string, int> _locationIdToIdx;
    internal Dictionary<string, int> _thingIdToIdx;
}
