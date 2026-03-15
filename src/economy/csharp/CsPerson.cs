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
        for (int i = 0; i < _goodsCount; i++)
            _wants[i] = 0f;

        for (int i = 0; i < goods.Length; i++)
        {
            var thing = goods[i];
            switch (thing.ThingType)
            {
                case ThingType.Food:
                    _wants[i] = 1.0f;
                    break;
                case ThingType.Cloth:
                    _wants[i] = SocialClass switch
                    {
                        SocialClass.Peasant => 0.3f,
                        SocialClass.Bourgeois => 0.5f,
                        SocialClass.Noble => 1.0f,
                        _ => 0f,
                    };
                    break;
                case ThingType.Tools:
                    _wants[i] = SocialClass switch
                    {
                        SocialClass.Peasant => 0.1f,
                        SocialClass.Bourgeois => 0.3f,
                        SocialClass.Noble => 0.3f,
                        _ => 0f,
                    };
                    break;
                case ThingType.Luxury:
                    _wants[i] = SocialClass switch
                    {
                        SocialClass.Noble => 0.5f,
                        SocialClass.Bourgeois => 0.2f,
                        _ => 0f,
                    };
                    break;
            }
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
        => Create(name, SocialClass.Peasant, job, 5f, goodsCount);

    public static CsPerson CreateBourgeois(string name, int goodsCount, JobType job = JobType.Merchant)
        => Create(name, SocialClass.Bourgeois, job, 50f, goodsCount);

    public static CsPerson CreateNoble(string name, int goodsCount)
        => Create(name, SocialClass.Noble, JobType.Landlord, 200f, goodsCount);

    public override string ToString()
        => $"{PersonName} ({SocialClass}, {Job})";
}
