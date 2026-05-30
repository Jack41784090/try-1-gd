using System;

namespace Condor.Economy;

public sealed class CsGuildSpecialization
{
    public int ThingIdx { get; set; }
    public int MaxEfficiencyWorkers { get; set; } = 30;
    public JobType WorkerJob { get; set; } = JobType.Craftsman;
    public float WagePerWorker { get; set; } = 1f;
    public int RecruitmentRate { get; set; } = 2;

    public int WorkerCount { get; set; }
    public float ProducedLastTick { get; set; }
    public int RecruitedLastTick { get; set; }
    public double WagesPaidLastTick { get; set; }

    private bool _hasInputs;

    public CsEconomyActor.Timing ProductionTiming =>
        _hasInputs ? CsEconomyActor.Timing.OnDemand : CsEconomyActor.Timing.Always;

    public void Initialize(ThingDef[] goods)
    {
        if (ThingIdx < 0 || ThingIdx >= goods.Length) return;
        var def = goods[ThingIdx];
        _hasInputs = def.Inputs != null && def.Inputs.Length > 0;
    }

    public void GenerateOrders(CsLocationData loc, int specIdx, CsGuild guild)
    {
        int currentWorkers = loc.Population.GetByJob(WorkerJob).Count;
        int gap = MaxEfficiencyWorkers - currentWorkers;
        double costToRecruit = RecruitmentRate * WagePerWorker;
        if (gap > 0 && guild.Treasury >= costToRecruit)
        {
            loc.Demands.Add(CsOrder.ServiceDemand(
                loc.Idx, ServiceType.Labor, RecruitmentRate,
                priority: 7f, issuer: guild,
                unitPrice: WagePerWorker, tag: $"guild_recruit:{specIdx}"));
        }
    }

    public void Recruit(CsPerson person, CsGuild guild)
    {
        person.Job = WorkerJob;
        guild.Treasury -= WagePerWorker;
        person.Money += WagePerWorker;
        RecruitedLastTick += 1;
    }

    public void Produce(CsLocationData loc, ThingDef[] goods, CsGuild guild)
    {
        ProducedLastTick = 0f;
        int workerCount = loc.Population.GetByJob(WorkerJob).Count;
        WorkerCount = workerCount;

        float efficiencyRatio = MathF.Min((float)workerCount / MaxEfficiencyWorkers, 1f);
        float producingQty = MaxEfficiencyWorkers * efficiencyRatio;

        var thingDef = goods[ThingIdx];

        if (_hasInputs)
        {
            float unmet = CalculateUnmetDemand(loc);
            producingQty = MathF.Min(producingQty, unmet);
            if (producingQty <= 0f) return;
            ConsumeInputs(loc, thingDef, producingQty);
        }
        else
        {
            CsNaturalResource resource = null;
            foreach (var res in loc.NaturalResources)
            {
                if (res.ThingIdx == ThingIdx) { resource = res; break; }
            }
            producingQty = resource != null ? resource.BaseCapacity * efficiencyRatio : 0f;
        }

        if (producingQty <= 0f) return;
        producingQty = LimitByInputs(loc, thingDef, producingQty);
        if (producingQty <= 0f) return;

        float costBasis = CalculateInputCost(loc, thingDef);
        float existingStock = loc.Stocks[ThingIdx];
        float existingCost = loc.CostBasis[ThingIdx];
        float totalStock = existingStock + producingQty;
        if (totalStock > 0f)
            loc.CostBasis[ThingIdx] = (existingCost * existingStock + costBasis * producingQty) / totalStock;

        loc.Add(ThingIdx, producingQty);
        ProducedLastTick = producingQty;

        loc.Supplies.Add(CsOrder.GoodSupply(loc.Idx, ThingIdx, producingQty,
            priority: 5f, unitPrice: loc.Prices[ThingIdx], issuer: guild));
    }

    public void PayWorkers(CsLocationData loc, CsGuild guild)
    {
        WagesPaidLastTick = 0;
        var workers = loc.Population.GetByJob(WorkerJob);
        int toPay = Math.Min(workers.Count, MaxEfficiencyWorkers);
        double totalWages = toPay * WagePerWorker;
        if (guild.Treasury < totalWages) totalWages = guild.Treasury;
        if (totalWages <= 0) return;

        float perWorker = (float)(totalWages / toPay);
        for (int i = 0; i < toPay; i++)
            workers[i].Money += perWorker;
        guild.Treasury -= totalWages;
        WagesPaidLastTick = totalWages;
    }

    private float CalculateUnmetDemand(CsLocationData loc)
    {
        float totalDemand = 0f;
        for (int di = 0; di < loc.Demands.Count; di++)
        {
            var d = loc.Demands[di];
            if (d.Category == ThingCategory.Good && d.ThingIdx == ThingIdx)
                totalDemand += MathF.Max(d.Quantity, 0f);
        }
        float totalSupply = 0f;
        for (int si = 0; si < loc.Supplies.Count; si++)
        {
            var s = loc.Supplies[si];
            if (s.Category == ThingCategory.Good && s.ThingIdx == ThingIdx)
                totalSupply += MathF.Max(s.Quantity, 0f);
        }
        return MathF.Max(totalDemand - totalSupply, 0f);
    }

    private static float LimitByInputs(CsLocationData loc, ThingDef thingDef, float desiredQty)
    {
        float max = desiredQty;
        foreach (var input in thingDef.Inputs)
        {
            float available = loc.GetAvailable(input.ThingIdx);
            if (input.Quantity <= 0f) continue;
            max = MathF.Min(max, available / input.Quantity);
        }
        return MathF.Max(max, 0f);
    }

    private static void ConsumeInputs(CsLocationData loc, ThingDef thingDef, float qty)
    {
        foreach (var input in thingDef.Inputs)
            loc.Consume(input.ThingIdx, input.Quantity * qty);
    }

    private static float CalculateInputCost(CsLocationData loc, ThingDef thingDef)
    {
        float cost = 0f;
        foreach (var input in thingDef.Inputs)
            cost += loc.Prices[input.ThingIdx] * input.Quantity;
        return cost;
    }
}
