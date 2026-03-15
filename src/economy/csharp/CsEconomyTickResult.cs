using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsShipmentDispatch
{
    public string ShipmentId { get; set; }
    public CsEconomyMove Move { get; set; }
    public int GuardCount { get; set; }

    public static CsShipmentDispatch Create(string id, CsEconomyMove move, int guards)
    {
        return new CsShipmentDispatch
        {
            ShipmentId = id,
            Move = move,
            GuardCount = guards,
        };
    }
}

public sealed class CsLocationSnapshot
{
    public int LocationIdx { get; set; }
    public string LocationId { get; set; }
    public string LocationName { get; set; }
    public int PopulationCount { get; set; }
    public float AvgSatisfaction { get; set; }
    public float AvgMoney { get; set; }
    public float[] Stocks { get; set; }
    public float[] Prices { get; set; }
}

public sealed class CsEconomyTickResult
{
    public int Turn { get; set; }
    public List<CsLocationSnapshot> LocationSnapshots { get; } = new();
    public List<CsEconomyMove> MovesCreated { get; } = new();
    public List<CsEconomyMove> MovesCompleted { get; } = new();
    public List<CsShipmentDispatch> ShipmentDispatches { get; } = new();
}
