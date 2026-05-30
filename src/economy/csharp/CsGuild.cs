using System;

namespace Condor.Economy;

public sealed class CsGuild : CsEconomyActor
{
    public double Treasury { get; set; }
    public int LocationIndex { get; set; }
    public string LocationId { get; set; } = "";
    public string GuildName { get; set; } = "Guild";
    public CsGuildSpecialization[] Specializations { get; set; } = Array.Empty<CsGuildSpecialization>();

    // Aggregated stats read by the engine snapshot
    public float ProducedLastTick { get { float t = 0f; foreach (var s in Specializations) t += s.ProducedLastTick; return t; } }
    public int RecruitedLastTick { get { int t = 0; foreach (var s in Specializations) t += s.RecruitedLastTick; return t; } }
    public double WagesPaidLastTick { get { double t = 0; foreach (var s in Specializations) t += s.WagesPaidLastTick; return t; } }
    public int WorkerCount { get { int t = 0; foreach (var s in Specializations) t += s.WorkerCount; return t; } }

    public override Timing ProductionTiming
    {
        get
        {
            bool hasAlways = false, hasOnDemand = false;
            foreach (var spec in Specializations)
            {
                if (spec.ProductionTiming == Timing.Always) hasAlways = true;
                else hasOnDemand = true;
            }
            if (hasAlways && hasOnDemand) return Timing.Mixed;
            return hasOnDemand ? Timing.OnDemand : Timing.Always;
        }
    }

    public void SetGoods(ThingDef[] goods)
    {
        foreach (var spec in Specializations)
            spec.Initialize(goods);
    }

    public override void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        for (int i = 0; i < Specializations.Length; i++)
            Specializations[i].GenerateOrders(loc, i, this);
    }

    public void Recruit(CsPerson person, string tag)
        => SpecFromTag(tag)?.Recruit(person, this);

    public override void Produce(CsLocationData loc, ThingDef[] goods, Timing phase = Timing.Always)
    {
        foreach (var spec in Specializations)
            if (spec.ProductionTiming == phase)
                spec.Produce(loc, goods, this);
    }

    public override void PayWorkers(CsLocationData loc)
    {
        foreach (var spec in Specializations)
            spec.PayWorkers(loc, this);
    }

    public override void CollectRevenue(CsLocationData loc, ThingDef[] goods) { }

    public override void ReceiveRevenue(double amount) => Treasury += amount;

    public int TotalWorkerCount(CsLocationData loc)
    {
        int total = 0;
        foreach (var spec in Specializations)
            total += loc.Population.GetByJob(spec.WorkerJob).Count;
        return total;
    }

    private CsGuildSpecialization SpecFromTag(string tag)
    {
        if (tag != null && tag.StartsWith("guild_recruit:") &&
            int.TryParse(tag.AsSpan("guild_recruit:".Length), out int idx) &&
            idx >= 0 && idx < Specializations.Length)
            return Specializations[idx];
        return Specializations.Length > 0 ? Specializations[0] : null;
    }
}
