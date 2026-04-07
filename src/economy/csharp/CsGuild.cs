using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsGuild
{
    public double Treasury { get; set; }
    public int MaxWorkers { get; set; } = 30;
    public float WagePerWorker { get; set; } = 1f;
    public int RecruitmentRate { get; set; } = 2;
    public int LocationIndex { get; set; }
    public string LocationId { get; set; } = "";
    public string GuildName { get; set; } = "Guild";
    public int SpecializationIdx { get; set; }

    public int WorkerCount { get; set; }
    public float ProducedLastTick { get; set; }
    public int RecruitedLastTick { get; set; }
    public double WagesPaidLastTick { get; set; }

    public void Recruit(CsLocationData loc)
    {
        RecruitedLastTick = 0;
        int currentWorkers = loc.Population.GetByJob(JobType.Craftsman).Count;
        int gap = MaxWorkers - currentWorkers;
        if (gap <= 0) return;

        int toRecruit = Math.Min(gap, RecruitmentRate);
        double costPerRecruit = WagePerWorker;
        if (Treasury < costPerRecruit) return;

        var unemployed = loc.Population.GetByJob(JobType.Unemployed);
        var laborers = loc.Population.GetByJob(JobType.Laborer);
        var pool = new List<CsPerson>();
        pool.AddRange(unemployed);
        pool.AddRange(laborers);

        int hired = 0;
        foreach (var person in pool)
        {
            if (hired >= toRecruit) break;
            if (Treasury < costPerRecruit) break;
            person.Job = JobType.Craftsman;
            person.Money += (float)costPerRecruit;
            Treasury -= costPerRecruit;
            hired++;
        }
        RecruitedLastTick = hired;
        WorkerCount = loc.Population.GetByJob(JobType.Craftsman).Count;
    }

    public void Produce(CsLocationData loc, ThingDef[] goods)
    {
        ProducedLastTick = 0f;
        var thingDef = goods[SpecializationIdx];
        int workerCount = loc.Population.GetByJob(JobType.Craftsman).Count;
        WorkerCount = workerCount;
        if (workerCount == 0) return;

        float ratio = MathF.Min((float)workerCount / MaxWorkers, 1f);
        float desiredQty = MaxWorkers * 0.5f * ratio;

        if (thingDef.Inputs.Length > 0)
        {
            desiredQty = LimitByInputs(loc, thingDef, desiredQty);
            if (desiredQty <= 0f) return;
            ConsumeInputs(loc, thingDef, desiredQty);
        }

        float costBasis = CalculateInputCost(loc, thingDef, goods);
        float existingStock = loc.Stocks[SpecializationIdx];
        float existingCost = loc.CostBasis[SpecializationIdx];
        float totalStock = existingStock + desiredQty;
        if (totalStock > 0f)
            loc.CostBasis[SpecializationIdx] = (existingCost * existingStock + costBasis * desiredQty) / totalStock;

        loc.Add(SpecializationIdx, desiredQty);
        ProducedLastTick = desiredQty;
    }

    public void PayWages(CsLocationData loc)
    {
        WagesPaidLastTick = 0;
        var craftsmen = loc.Population.GetByJob(JobType.Craftsman);
        int toPay = Math.Min(craftsmen.Count, MaxWorkers);
        double totalWages = toPay * WagePerWorker;
        if (Treasury < totalWages)
            totalWages = Treasury;
        if (totalWages <= 0) return;

        float perWorker = (float)(totalWages / toPay);
        for (int i = 0; i < toPay; i++)
            craftsmen[i].Money += perWorker;
        Treasury -= totalWages;
        WagesPaidLastTick = totalWages;
    }

    public void CollectRevenue(CsLocationData loc, ThingDef[] goods)
    {
        float price = loc.Prices[SpecializationIdx];
        float commission = price * ProducedLastTick * 0.10f;
        Treasury += commission;
    }

    private static float LimitByInputs(CsLocationData loc, ThingDef thingDef, float desiredQty)
    {
        float max = desiredQty;
        foreach (var input in thingDef.Inputs)
        {
            float available = loc.GetAvailable(input.ThingIdx);
            if (input.Quantity <= 0f) continue;
            float canProduce = available / input.Quantity;
            max = MathF.Min(max, canProduce);
        }
        return MathF.Max(max, 0f);
    }

    private static void ConsumeInputs(CsLocationData loc, ThingDef thingDef, float qty)
    {
        foreach (var input in thingDef.Inputs)
            loc.Consume(input.ThingIdx, input.Quantity * qty);
    }

    private static float CalculateInputCost(CsLocationData loc, ThingDef thingDef, ThingDef[] goods)
    {
        float cost = 0f;
        foreach (var input in thingDef.Inputs)
            cost += loc.Prices[input.ThingIdx] * input.Quantity;
        return cost;
    }
}

public static class GuildBrain
{
    public static void Evaluate(CsGuild guild, CsLocationData loc)
    {
        int currentWorkers = loc.Population.GetByJob(JobType.Craftsman).Count;
        if (currentWorkers >= guild.MaxWorkers) return;
        double costToRecruit = guild.RecruitmentRate * guild.WagePerWorker;
        if (guild.Treasury < costToRecruit) return;
        guild.Recruit(loc);
    }
}
