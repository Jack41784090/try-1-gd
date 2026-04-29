using System;

namespace Condor.Economy;

/// <summary>
/// Shared context passed to actor.GenerateOrders during PhaseGenerateOrders.
/// Carries engine-wide state without exposing the entire engine to actors.
/// </summary>
public sealed class EconomyContext
{
    public int CurrentTurn { get; set; }
    public CsGovernment ImperialGovernment { get; set; }
    public ThingDef[] Goods { get; set; }
    public float NobleLoanThreshold { get; set; }
    public float LoanAmount { get; set; }
    public Random Rng { get; set; }
}

/// <summary>
/// A person in the economy. Folds the previous PersonBrain hierarchy into
/// per-class GenerateOrders methods on this type — no separate brain factory.
/// </summary>
public sealed class CsPerson
{
    private static int _nextId;

    public int InternalId { get; }
    public string PersonId { get; set; }
    public string PersonName { get; set; }
    public SocialClass SocialClass { get; set; }
    public JobType Job { get; set; }
    public float Money { get; set; }
    public float Satisfaction { get; set; }
    public float IncomePerTurn { get; set; }
    public string EmployerId { get; set; } = "";
    public bool FedThisTurn { get; set; }
    public float ComfortThisTurn { get; set; }
    public int StarvationCounter { get; set; }
    public int TurnsAlive { get; set; }
    public int LastLoanTurn { get; set; } = -10;

    // Inventory: indexed by ThingDef.Id
    private readonly float[] _inventory;
    // Wants: indexed by ThingDef.Id
    private readonly float[] _wants;
    private readonly int _goodsCount;

    public CsPerson(int goodsCount)
    {
        _goodsCount = goodsCount;
        _inventory = new float[goodsCount];
        _wants = new float[goodsCount];
        InternalId = _nextId++;
    }

    public float GetInventory(int thingIdx) => _inventory[thingIdx];
    public void SetInventory(int thingIdx, float value) => _inventory[thingIdx] = value;
    public void AddInventory(int thingIdx, float amount) => _inventory[thingIdx] += amount;

    public float GetWant(int thingIdx) => _wants[thingIdx];
    public void SetWant(int thingIdx, float value) => _wants[thingIdx] = value;

    public void ComputeWants(ThingDef[] goods)
    {
        ComputeWants(goods, null);
    }

    public void ComputeWants(ThingDef[] goods, float[] locationPrices)
    {
        for (int i = 0; i < _goodsCount; i++)
            _wants[i] = 0f;

        float classElasticityMod = SocialClass switch
        {
            SocialClass.Noble => 0.5f,
            SocialClass.Peasant => 1.5f,
            _ => 1.0f,
        };

        for (int i = 0; i < goods.Length; i++)
        {
            var thing = goods[i];
            float baseWant = 0f;
            switch (thing.ThingType)
            {
                case ThingType.Food:
                    baseWant = 1.0f;
                    break;
                case ThingType.Cloth:
                    baseWant = SocialClass switch
                    {
                        SocialClass.Peasant => 0.3f,
                        SocialClass.Bourgeois => 0.5f,
                        SocialClass.Noble => 1.0f,
                        _ => 0f,
                    };
                    break;
                case ThingType.Tools:
                    baseWant = SocialClass switch
                    {
                        SocialClass.Peasant => 0.1f,
                        SocialClass.Bourgeois => 0.3f,
                        SocialClass.Noble => 0.3f,
                        _ => 0f,
                    };
                    break;
                case ThingType.Luxury:
                    baseWant = SocialClass switch
                    {
                        SocialClass.Noble => 0.5f,
                        SocialClass.Bourgeois => 0.2f,
                        _ => 0f,
                    };
                    break;
                case ThingType.Weapons:
                    baseWant = SocialClass switch
                    {
                        SocialClass.Noble => 0.4f,
                        SocialClass.Bourgeois => 0.1f,
                        _ => 0f,
                    };
                    break;
            }

            if (locationPrices != null && baseWant > 0f && thing.BasePrice > 0f)
            {
                float currentPrice = locationPrices[i];
                if (currentPrice > 0f)
                {
                    float elasticity = thing.Elasticity * classElasticityMod;
                    float priceRatio = thing.BasePrice / currentPrice;
                    float modifier = MathF.Pow(priceRatio, elasticity);
                    baseWant *= Math.Clamp(modifier, 0.2f, 3.0f);
                }
            }

            _wants[i] = baseWant;
        }
    }

    public float Consume(int thingIdx, float qty)
    {
        float held = _inventory[thingIdx];
        float consumed = MathF.Min(held, qty);
        _inventory[thingIdx] = held - consumed;
        return consumed;
    }

    public float CanAfford(float price, float qty)
    {
        if (price <= 0f) return qty;
        return MathF.Min(qty, Money / price);
    }

    public float Buy(int thingIdx, float qty, float price)
    {
        float affordable = CanAfford(price, qty);
        if (affordable <= 0f) return 0f;
        Money -= affordable * price;
        _inventory[thingIdx] += affordable;
        return affordable;
    }

    /// <summary>
    /// Per-tick decision-making, dispatched by social class. Replaces the
    /// previous PersonBrain hierarchy. Emits intangible-service orders into
    /// the location order book (loc.Demands / loc.Supplies).
    /// </summary>
    public void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        switch (SocialClass)
        {
            case SocialClass.Noble:
                GenerateNobleOrders(loc, ctx);
                break;
            case SocialClass.Peasant:
                GeneratePeasantOrders(loc, ctx);
                break;
            // Bourgeois currently has no service orders.
        }
    }

    /// <summary>
    /// Folded NobleBrain.EvaluateLoanApplication. Emits a Loan demand order
    /// when scoring exceeds the noble's stable risk threshold.
    /// </summary>
    private void GenerateNobleOrders(CsLocationData loc, EconomyContext ctx)
    {
        if (ctx.ImperialGovernment == null) return;

        const int LoanCooldownTurns = 5;
        if (ctx.CurrentTurn - LastLoanTurn < LoanCooldownTurns) return;

        float moneyRatio = Money / MathF.Max(ctx.NobleLoanThreshold, 1f);
        if (moneyRatio >= 1.5f) return;

        float score = 0f;
        float desperation = 1f - Math.Clamp(moneyRatio, 0f, 1f);
        score += desperation * 0.4f;

        float satisfactionPressure = 1f - Math.Clamp(Satisfaction / 100f, 0f, 1f);
        score += satisfactionPressure * 0.25f;

        float foodPressure = 0f;
        for (int gi = 0; gi < ctx.Goods.Length; gi++)
        {
            if (ctx.Goods[gi].ThingType != ThingType.Food) continue;
            float priceRatio = loc.Prices[gi] / MathF.Max(ctx.Goods[gi].BasePrice, 0.01f);
            foodPressure = Math.Clamp((priceRatio - 1f) * 0.5f, 0f, 1f);
            break;
        }
        score += foodPressure * 0.15f;

        float existingDebt = 0f;
        foreach (var loan in ctx.ImperialGovernment.ActiveLoans)
        {
            if (loan.Debtor.InternalId == InternalId)
                existingDebt += loan.TotalOwed;
        }
        float debtPenalty = Math.Clamp(existingDebt / (ctx.LoanAmount * 2f), 0f, 1f);
        score -= debtPenalty * 0.3f;

        // Stable per-person risk tolerance (deterministic from id)
        float riskTolerance = ((InternalId * 2654435761u) & 0xFF) / 255f;
        float threshold = 0.3f + (1f - riskTolerance) * 0.3f;

        if (score >= threshold)
        {
            loc.Demands.Add(CsOrder.Demand(
                loc.Idx, ServiceType.Loan, ctx.LoanAmount,
                priority: 3f, personActor: this,
                unitPrice: ctx.ImperialGovernment.LoanInterestRate,
                tag: "noble_loan_application"));
        }
    }

    /// <summary>
    /// Desperate peasants emit BanditSlot demand (willing to abandon the local
    /// economy and join banditry). Materialization happens via Geist's pool
    /// growth — this signal mostly aggregates to BanditPoolSize during execute.
    /// </summary>
    private void GeneratePeasantOrders(CsLocationData loc, EconomyContext ctx)
    {
        if (Satisfaction > 30f) return;
        if (loc.Geist == null) return;

        // Single slot demand per desperate peasant
        loc.Demands.Add(CsOrder.Demand(
            loc.Idx, ServiceType.BanditSlot, 1f,
            priority: 3f, personActor: this,
            tag: "peasant_to_bandit"));
    }

    public static CsPerson Create(string name, SocialClass socialClass, JobType job, float money, int goodsCount)
    {
        var p = new CsPerson(goodsCount)
        {
            PersonId = $"person_{_nextId}",
            PersonName = name,
            SocialClass = socialClass,
            Job = job,
            Money = money,
            Satisfaction = 50f,
        };
        return p;
    }

    public static CsPerson CreatePeasant(string name, int goodsCount, JobType job = JobType.Farmer)
        => Create(name, SocialClass.Peasant, job, 5f, goodsCount);

    public static CsPerson CreateBourgeois(string name, int goodsCount, JobType job = JobType.Merchant)
        => Create(name, SocialClass.Bourgeois, job, 50f, goodsCount);

    public static CsPerson CreateNoble(string name, int goodsCount)
        => Create(name, SocialClass.Noble, JobType.Landlord, 200f, goodsCount);

    public override string ToString()
        => $"{PersonName} ({SocialClass}, {Job})";
}
