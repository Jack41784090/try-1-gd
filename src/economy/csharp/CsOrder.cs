namespace Condor.Economy;

public sealed class CsOrder
{
    public OrderSide Side;
    public ThingCategory Category;
    public ServiceType Service;
    public int ThingIdx = -1;
    public float Quantity;
    public float UnitPrice;
    public float Priority;
    public int LocationIdx;
    public string Tag;

    public CsEconomyActor IssuerActor;
    public CsPerson PersonActor;

    // ---- Good factories ----

    public static CsOrder GoodDemand(int locationIdx, int thingIdx, float qty, float priority,
        CsPerson personActor = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Demand,
            Category = ThingCategory.Good,
            ThingIdx = thingIdx,
            Quantity = qty,
            Priority = priority,
            LocationIdx = locationIdx,
            PersonActor = personActor,
        };
    }

    public static CsOrder GoodSupply(int locationIdx, int thingIdx, float qty, float priority,
        float unitPrice = 0f, CsEconomyActor issuer = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Supply,
            Category = ThingCategory.Good,
            ThingIdx = thingIdx,
            Quantity = qty,
            UnitPrice = unitPrice,
            Priority = priority,
            LocationIdx = locationIdx,
            IssuerActor = issuer,
        };
    }

    // ---- Service factories ----

    public static CsOrder ServiceDemand(int locationIdx, ServiceType service, float qty, float priority,
        CsPerson personActor = null, CsEconomyActor issuer = null, float unitPrice = 0f, string tag = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Demand,
            Category = ThingCategory.Service,
            Service = service,
            Quantity = qty,
            UnitPrice = unitPrice,
            Priority = priority,
            LocationIdx = locationIdx,
            PersonActor = personActor,
            IssuerActor = issuer,
            Tag = tag,
        };
    }

    public static CsOrder ServiceSupply(int locationIdx, ServiceType service, float qty, float priority,
        CsPerson personActor = null, CsEconomyActor issuer = null, float unitPrice = 0f, string tag = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Supply,
            Category = ThingCategory.Service,
            Service = service,
            Quantity = qty,
            UnitPrice = unitPrice,
            Priority = priority,
            LocationIdx = locationIdx,
            PersonActor = personActor,
            IssuerActor = issuer,
            Tag = tag,
        };
    }

    public override string ToString()
    {
        if (Category == ThingCategory.Good)
            return $"Good[{Side}] ThingIdx={ThingIdx} qty={Quantity:F2} pri={Priority:F2} issuer={IssuerActor?.GetType().Name}";
        return $"Service[{Side}] Service={Service} qty={Quantity:F2} pri={Priority:F2} issuer={IssuerActor?.GetType().Name}";
    }
}
