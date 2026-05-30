namespace Condor.Economy;

public abstract class CsEconomyActor
{
    public enum Timing { Always, OnDemand, Mixed }

    public virtual Timing ProductionTiming => Timing.Always;

    public virtual void UpdateState(CsLocationData loc, ThingDef[] goods) { }
    public abstract void GenerateOrders(CsLocationData loc, EconomyContext ctx);
    public virtual void Produce(CsLocationData loc, ThingDef[] goods, Timing phase = Timing.Always) { }
    public virtual void PayWorkers(CsLocationData loc) { }
    public virtual void CollectRevenue(CsLocationData loc, ThingDef[] goods) { }
    public virtual void ReceiveRevenue(double amount) { }
}
