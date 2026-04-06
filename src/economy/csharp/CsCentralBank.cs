using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsCentralBank
{
    public string BankId { get; set; } = "imperial_bank";
    public float TotalPrinted { get; set; }
    public float TotalInterestCollected { get; set; }
    public float Reserves { get; set; }
    public List<CsLoan> ActiveLoans { get; } = new();
    public float LoanInterestRate { get; set; } = 0.01f;
    public float PrintPerTurn { get; set; } = 500f;

    public float PrintMoney(float amount)
    {
        TotalPrinted += amount;
        return amount;
    }

    public CsLoan IssueLoan(CsPerson debtor, float amount)
    {
        float fromReserves = MathF.Min(Reserves, amount);
        float toPrint = amount - fromReserves;
        Reserves -= fromReserves;
        if (toPrint > 0f) PrintMoney(toPrint);
        debtor.Money += amount;
        var loan = CsLoan.Create(debtor, amount, LoanInterestRate);
        ActiveLoans.Add(loan);
        return loan;
    }

    public void CollectInterestAndRepayments()
    {
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

    public bool ShouldIssueLoan(CsPerson noble, float minThreshold)
        => noble.Money < minThreshold;

    public override string ToString()
        => $"CentralBank[printed={TotalPrinted:F0} reserves={Reserves:F0} interest={TotalInterestCollected:F0} loans={ActiveLoans.Count} outstanding={GetTotalOutstanding():F0}]";
}
