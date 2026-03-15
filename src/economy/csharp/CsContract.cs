using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsContract
{
    private static int _nextId;

    public string ContractId { get; set; }
    public ContractType Type { get; set; }
    public CsPerson Patron { get; set; }
    public string LocationId { get; set; }
    public float Budget { get; set; }
    public int LaborNeeded { get; set; }
    public List<CsPerson> WorkersAssigned { get; } = new();
    public CsPerson MerchantAssigned { get; set; }
    public int TurnsRemaining { get; set; }
    public float WagePerWorker { get; set; }
    public float MerchantFee { get; set; }
    public bool Completed { get; set; }

    public void AssignMerchant(CsPerson m) => MerchantAssigned = m;
    public void AssignWorker(CsPerson w) => WorkersAssigned.Add(w);

    public bool IsFullyStaffed()
        => WorkersAssigned.Count >= LaborNeeded && MerchantAssigned != null;

    public bool WorkOneTurn()
    {
        if (!IsFullyStaffed()) return false;
        TurnsRemaining--;
        if (TurnsRemaining <= 0) Completed = true;
        return Completed;
    }

    public float GetTotalWageCost() => WagePerWorker * WorkersAssigned.Count;
    public float GetTotalCostPerTurn() => GetTotalWageCost() + MerchantFee;

    public static CsContract Create(
        ContractType type, CsPerson patron, string locationId,
        float budget, int labor, int duration, float wage, float merchantFee)
    {
        _nextId++;
        return new CsContract
        {
            ContractId = $"contract_{_nextId}",
            Type = type,
            Patron = patron,
            LocationId = locationId,
            Budget = budget,
            LaborNeeded = labor,
            TurnsRemaining = duration,
            WagePerWorker = wage,
            MerchantFee = merchantFee,
        };
    }
}
