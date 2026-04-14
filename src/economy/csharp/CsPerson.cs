using System;

namespace Condor.Economy;

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
    public PersonBrain Brain { get; set; }

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

            // Apply price elasticity if prices are available
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
    {
        var p = Create(name, SocialClass.Peasant, job, 5f, goodsCount);
        p.Brain = CommonBrain.Instance;
        return p;
    }

    public static CsPerson CreateBourgeois(string name, int goodsCount, JobType job = JobType.Merchant)
    {
        var p = Create(name, SocialClass.Bourgeois, job, 50f, goodsCount);
        p.Brain = CommonBrain.Instance;
        return p;
    }

    public static CsPerson CreateNoble(string name, int goodsCount)
    {
        var p = Create(name, SocialClass.Noble, JobType.Landlord, 200f, goodsCount);
        p.Brain = new NobleBrain();
        return p;
    }

    public override string ToString()
        => $"{PersonName} ({SocialClass}, {Job})";
}
