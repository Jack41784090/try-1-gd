namespace Condor.Economy;

public enum DirectiveType
{
    HireWorkers,
    PostBuyOrder,
    SubsidizeProduction,
}

public sealed class CsDirective
{
    public DirectiveType Type { get; set; }
    public JobType JobTarget { get; set; }
    public int Quantity { get; set; }
    public float WageOffered { get; set; }
    public int TurnsRemaining { get; set; }
    public float BudgetAllocated { get; set; }
    public float BudgetSpent { get; set; }
    public int WorkersHired { get; set; }

    public static CsDirective CreateHireWorkers(JobType job, int qty, float wage, int duration, float budget)
    {
        return new CsDirective
        {
            Type = DirectiveType.HireWorkers,
            JobTarget = job,
            Quantity = qty,
            WageOffered = wage,
            TurnsRemaining = duration,
            BudgetAllocated = budget,
        };
    }

    public bool IsExpired => TurnsRemaining <= 0;

    public void AdvanceTurn()
    {
        TurnsRemaining--;
    }
}
