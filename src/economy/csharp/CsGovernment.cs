using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsGovernment
{
    public double Treasury { get; set; }
    public double TaxRate { get; set; } = 0.05;
    public float MaxBudgetRatio { get; set; } = 0.3f;
    public float PushWeight { get; set; } = 0.7f;
    public float PullWeight { get; set; } = 0.3f;
    public int LocationIndex { get; set; }
    public string LocationId { get; set; } = "";
    public List<int> PriorityGoodIndices { get; } = new();
    public List<CsDirective> ActiveDirectives { get; } = new();

    public double TaxCollectedLastTick { get; set; }
    public int WorkersHiredLastTick { get; set; }
    public double WagesPaidLastTick { get; set; }
}

/// <summary>
/// Hardcoded brain that analyzes a location's economy and produces directives.
/// Runs inside PhaseGovernmentPlan. Uses GovernmentConfig weights from .tres
/// but does all math in C#.
/// </summary>
public static class GovernmentBrain
{
    public static List<CsDirective> Evaluate(
        CsGovernment gov, CsLocationData loc, ThingDef[] goods, int goodsCount)
    {
        var directives = new List<CsDirective>();

        double availableBudget = gov.Treasury * gov.MaxBudgetRatio;
        if (availableBudget < 1.0) return directives;

        double budgetUsedByActive = 0;
        foreach (var d in gov.ActiveDirectives)
            budgetUsedByActive += (d.BudgetAllocated - d.BudgetSpent);
        availableBudget -= budgetUsedByActive;
        if (availableBudget < 1.0) return directives;

        if (gov.PushWeight <= 0f) return directives;

        // Analyze each natural resource for worker gaps
        foreach (var resource in loc.NaturalResources)
        {
            if (!ShouldPrioritize(gov, resource.ThingIdx, goods))
                continue;

            var workers = loc.Population.GetByJob(resource.WorkerJob);
            int workerCount = workers.Count;
            float workerGap = resource.WorkersNeeded - workerCount;
            if (workerGap <= 0f) continue;

            var unemployed = loc.Population.GetByJob(JobType.Unemployed);
            var laborers = loc.Population.GetByJob(JobType.Laborer);
            int availablePool = unemployed.Count + laborers.Count;
            if (availablePool <= 0) continue;

            int hireCount = Math.Min((int)MathF.Ceiling(workerGap), availablePool);

            float wage = CalculateWage(loc, goods, resource.ThingIdx);
            int duration = 12;
            double totalCost = hireCount * wage * duration;

            if (totalCost > availableBudget)
            {
                hireCount = (int)(availableBudget / (wage * duration));
                if (hireCount <= 0) continue;
                totalCost = hireCount * wage * duration;
            }

            directives.Add(CsDirective.CreateHireWorkers(
                resource.WorkerJob, hireCount, wage, duration, (float)totalCost));
            availableBudget -= totalCost;
            if (availableBudget < 1.0) break;
        }

        return directives;
    }

    private static bool ShouldPrioritize(CsGovernment gov, int thingIdx, ThingDef[] goods)
    {
        if (gov.PriorityGoodIndices.Count == 0) return true;
        return gov.PriorityGoodIndices.Contains(thingIdx);
    }

    private static float CalculateWage(CsLocationData loc, ThingDef[] goods, int thingIdx)
    {
        float price = loc.Prices[thingIdx];
        float wage = MathF.Max(price * 0.1f, 0.5f);
        return MathF.Min(wage, 5f);
    }
}
