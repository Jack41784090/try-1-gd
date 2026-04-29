using System;
using System.Collections.Generic;

namespace Condor.Economy;

/// <summary>
/// Per-location government. Holds treasury, tax rate, hiring directives,
/// and (when IsImperial=true) the imperial bank's money-printing and loan
/// issuance. Replaces both GovernmentBrain (folded into GenerateOrders) and
/// CsCentralBank (folded as imperial-only fields).
/// </summary>
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

    // ---- Imperial bank (only meaningful when IsImperial=true) ----
    public bool IsImperial { get; set; }
    public float Reserves { get; set; }
    public float TotalPrinted { get; set; }
    public float TotalInterestCollected { get; set; }
    public float LoanInterestRate { get; set; } = 0.01f;
    public float PrintPerTurn { get; set; } = 500f;
    public List<CsLoan> ActiveLoans { get; } = new();

    // Per-tick mercenary demand diagnostic (computed in GenerateOrders)
    public float LastMercenaryDemand { get; set; }

    public float PrintMoney(float amount)
    {
        TotalPrinted += amount;
        return amount;
    }

    public CsLoan IssueLoan(CsPerson debtor, float amount, int currentTurn)
    {
        float fromReserves = MathF.Min(Reserves, amount);
        float toPrint = amount - fromReserves;
        Reserves -= fromReserves;
        if (toPrint > 0f) PrintMoney(toPrint);
        debtor.Money += amount;
        debtor.LastLoanTurn = currentTurn;
        var loan = CsLoan.Create(debtor, amount, LoanInterestRate);
        ActiveLoans.Add(loan);
        return loan;
    }

    public void CollectInterestAndRepayments()
    {
        if (!IsImperial) return;
        var completed = new List<CsLoan>();
        foreach (var loan in ActiveLoans)
        {
            loan.AccrueInterest();
            float canPay = MathF.Min(loan.Debtor.Money * 0.2f, loan.TotalOwed);
            canPay = MathF.Max(canPay, 0f);
            if (canPay > 0f)
            {
                float paid = loan.MakePayment(canPay);
                loan.Debtor.Money -= paid;
                Reserves += paid;
                TotalInterestCollected += paid;
            }
            if (loan.IsPaidOff()) completed.Add(loan);
        }
        foreach (var loan in completed)
            ActiveLoans.Remove(loan);
    }

    public float GetTotalOutstanding()
    {
        float total = 0f;
        foreach (var loan in ActiveLoans)
            total += loan.TotalOwed;
        return total;
    }

    public bool ShouldIssueLoan(CsPerson noble, float minThreshold, int currentTurn, int cooldown = 5)
        => noble.Money < minThreshold && (currentTurn - noble.LastLoanTurn) >= cooldown;

    /// <summary>
    /// Folded GovernmentBrain.Evaluate + mercenary demand calculation.
    /// Emits Labor demand orders for natural-resource gaps (within budget) and
    /// MercenaryWork demand orders proportional to local desperation.
    /// </summary>
    public void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        WorkersHiredLastTick = 0;
        WagesPaidLastTick = 0;
        LastMercenaryDemand = 0f;

        // ---- Labor demand: hire workers for under-staffed natural resources ----
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

                    // Mirror as a Labor demand order for diagnostics / future use
                    loc.Demands.Add(CsOrder.Demand(
                        LocationIndex, ServiceType.Labor, hireCount,
                        priority: 8f, govActor: this,
                        unitPrice: wage, tag: $"gov_hire_{resource.WorkerJob}"));

                    if (availableBudget < 1.0) break;
                }
            }
        }

        // ---- MercenaryWork demand: proportional to local desperation ----
        if (loc.Geist != null && loc.Geist.Desperation > 0.2f && Treasury > 50.0)
        {
            float demand = loc.Geist.Desperation * 2f;
            LastMercenaryDemand = demand;

            if (demand >= 1f)
            {
                loc.Demands.Add(CsOrder.Demand(
                    LocationIndex, ServiceType.MercenaryWork, demand,
                    priority: 6f, govActor: this,
                    unitPrice: 25f, tag: "gov_mercenary_bounty"));
            }
        }

        // ---- Loan supply (imperial only): nobles can draw on imperial reserves ----
        if (IsImperial)
        {
            float capacity = Reserves + PrintPerTurn;
            if (capacity > 0f)
            {
                loc.Supplies.Add(CsOrder.Supply(
                    LocationIndex, ServiceType.Loan, capacity,
                    priority: 3f, govActor: this,
                    unitPrice: LoanInterestRate, tag: "imperial_loan_capacity"));
            }
        }
    }

    public override string ToString()
    {
        if (IsImperial)
            return $"ImperialGov[{LocationId}]<treasury={Treasury:F0} reserves={Reserves:F0} loans={ActiveLoans.Count}>";
        return $"Gov[{LocationId}]<treasury={Treasury:F0} dirs={ActiveDirectives.Count}>";
    }
}
