using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsGovernment : CsEconomyActor
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

    public bool IsImperial { get; set; }
    public float Reserves { get; set; }
    public float TotalPrinted { get; set; }
    public float TotalInterestCollected { get; set; }
    public float LoanInterestRate { get; set; } = 0.01f;
    public float PrintPerTurn { get; set; } = 500f;
    public List<CsLoan> ActiveLoans { get; } = new();
    public float LastMercenaryDemand { get; set; }

    public float GetTotalOutstanding()
    {
        float total = 0f;
        for (int i = 0; i < ActiveLoans.Count; i++)
            total += ActiveLoans[i].TotalOwed;
        return total;
    }

    public void CollectInterestAndRepayments()
    {
    }

    public float PrintMoney(float amount)
    {
        TotalPrinted += amount;
        return amount;
    }

    public override void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        WorkersHiredLastTick = 0;
        WagesPaidLastTick = 0;

        double availableBudget = Treasury * MaxBudgetRatio;
        if (availableBudget >= 1.0 && PushWeight > 0f)
        {
            double budgetUsedByActive = 0;
            foreach (var d in ActiveDirectives)
                budgetUsedByActive += (d.BudgetAllocated - d.BudgetSpent);
            availableBudget -= budgetUsedByActive;

            if (availableBudget >= 1.0)
            {
                foreach (var resource in loc.NaturalResources)
                {
                    if (PriorityGoodIndices.Count > 0 &&
                        !PriorityGoodIndices.Contains(resource.ThingIdx))
                        continue;

                    var workers = loc.Population.GetByJob(resource.WorkerJob);
                    float workerGap = resource.WorkersNeeded - workers.Count;
                    if (workerGap <= 0f) continue;

                    int availablePool = loc.Population.GetByJob(JobType.Unemployed).Count
                                     + loc.Population.GetByJob(JobType.Laborer).Count;
                    if (availablePool <= 0) continue;

                    int hireCount = Math.Min((int)MathF.Ceiling(workerGap), availablePool);
                    float wage = MathF.Min(MathF.Max(loc.Prices[resource.ThingIdx] * 0.1f, 0.5f), 5f);
                    int duration = 12;
                    double totalCost = hireCount * wage * duration;

                    if (totalCost > availableBudget)
                    {
                        hireCount = (int)(availableBudget / (wage * duration));
                        if (hireCount <= 0) continue;
                        totalCost = hireCount * wage * duration;
                    }

                    var directive = CsDirective.CreateHireWorkers(
                        resource.WorkerJob, hireCount, wage, duration, (float)totalCost);
                    ActiveDirectives.Add(directive);
                    availableBudget -= totalCost;

                    loc.Demands.Add(CsOrder.ServiceDemand(
                        LocationIndex, ServiceType.Labor, hireCount,
                        priority: 8f, issuer: this,
                        unitPrice: wage, tag: $"gov_hire_{resource.WorkerJob}"));

                    if (availableBudget < 1.0) break;
                }
            }
        }
    }

    public override void PayWorkers(CsLocationData loc)
    {
        WorkersHiredLastTick = 0;
        WagesPaidLastTick = 0;

        for (int di = ActiveDirectives.Count - 1; di >= 0; di--)
        {
            var directive = ActiveDirectives[di];
            if (directive.Type == DirectiveType.HireWorkers)
            {
                int remaining = directive.Quantity - directive.WorkersHired;
                float budgetLeft = directive.BudgetAllocated - directive.BudgetSpent;
                if (remaining > 0 && budgetLeft >= directive.WageOffered)
                {
                    var pool = new List<CsPerson>(loc.Population.GetByJob(JobType.Unemployed));
                    pool.AddRange(loc.Population.GetByJob(JobType.Laborer));

                    int hired = 0;
                    foreach (var p in pool)
                    {
                        if (hired >= remaining || budgetLeft < directive.WageOffered) break;
                        var oldClass = p.SocialClass;
                        var oldJob = p.Job;
                        p.Job = directive.JobTarget;
                        p.Money += directive.WageOffered;
                        loc.Population.NotifyClassChanged(p, oldClass, oldJob);

                        directive.BudgetSpent += directive.WageOffered;
                        budgetLeft -= directive.WageOffered;
                        Treasury -= directive.WageOffered;
                        WagesPaidLastTick += directive.WageOffered;
                        directive.WorkersHired++;
                        hired++;
                    }
                    WorkersHiredLastTick += hired;
                }
            }
            directive.AdvanceTurn();
            if (directive.IsExpired) ActiveDirectives.RemoveAt(di);
        }
    }

    public override void CollectRevenue(CsLocationData loc, ThingDef[] goods)
    {
        TaxCollectedLastTick = 0;
        double taxCollected = 0;
        var pop = loc.Population.People;
        for (int pi = 0; pi < pop.Count; pi++)
        {
            if (pop[pi].Money > 10f)
            {
                float tax = pop[pi].Money * (float)TaxRate;
                pop[pi].Money -= tax;
                taxCollected += tax;
            }
        }
        Treasury += taxCollected;
        TaxCollectedLastTick = taxCollected;
    }

    public override void ReceiveRevenue(double amount)
    {
        Treasury += amount;
    }

    public override string ToString()
    {
        if (IsImperial)
            return $"ImperialGov[{LocationId}]<treasury={Treasury:F0} reserves={Reserves:F0} loans={ActiveLoans.Count}>";
        return $"Gov[{LocationId}]<treasury={Treasury:F0} dirs={ActiveDirectives.Count}>";
    }
}
