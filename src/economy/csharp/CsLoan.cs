namespace Condor.Economy;

public sealed class CsLoan
{
    private static int _nextId;

    public string LoanId { get; set; }
    public CsPerson Debtor { get; set; }
    public float Principal { get; set; }
    public float InterestRate { get; set; }
    public float TotalOwed { get; set; }
    public float TotalRepaid { get; set; }
    public int TurnsActive { get; set; }

    public float GetInterestDue() => TotalOwed * InterestRate;

    public float MakePayment(float amount)
    {
        float payment = amount < TotalOwed ? amount : TotalOwed;
        TotalOwed -= payment;
        TotalRepaid += payment;
        return payment;
    }

    public void AccrueInterest()
    {
        TotalOwed += GetInterestDue();
        TurnsActive++;
    }

    public bool IsPaidOff() => TotalOwed <= 0.01f;

    public static CsLoan Create(CsPerson debtor, float principal, float interestRate)
    {
        _nextId++;
        return new CsLoan
        {
            LoanId = $"loan_{_nextId}",
            Debtor = debtor,
            Principal = principal,
            InterestRate = interestRate,
            TotalOwed = principal,
        };
    }

    public override string ToString()
        => $"Loan[{LoanId}→{Debtor.PersonName}: owed={TotalOwed:F1} rate={InterestRate * 100f:F0}% age={TurnsActive}]";
}
