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
    public int PeasantCount { get; set; }
    public int BourgeoisCount { get; set; }
    public int NobleCount { get; set; }
    public float GovernmentTreasury { get; set; }
    public float GovernmentTaxCollected { get; set; }
    public int GovernmentDirectivesCount { get; set; }
    public int GovernmentWorkersHired { get; set; }
    public float GuildTreasury { get; set; }
    public float GuildProduced { get; set; }
    public int GuildWorkerCount { get; set; }
}

public sealed class CsEconomyTickResult
{
    public int Turn { get; set; }
    public int Deaths { get; set; }
    public int Births { get; set; }
    public List<CsLocationSnapshot> LocationSnapshots { get; } = new();
    public List<CsEconomyMove> MovesCreated { get; } = new();
    public List<CsEconomyMove> MovesCompleted { get; } = new();
    public List<CsShipmentDispatch> ShipmentDispatches { get; } = new();
}

public sealed class CsDemandExport
{
    public int ThingIdx { get; set; }
    public string ThingId { get; set; }
    public float Quantity { get; set; }
    public float MaxPrice { get; set; }
    public int LocationIdx { get; set; }
    public string LocationId { get; set; }
    public float Priority { get; set; }
}

public sealed class CsSupplyExport
{
    public int ThingIdx { get; set; }
    public string ThingId { get; set; }
    public float Quantity { get; set; }
    public float CostBasis { get; set; }
    public int LocationIdx { get; set; }
    public string LocationId { get; set; }
}

public sealed class CsTradeMatchImport
{
    public string ThingId { get; set; }
    public float Quantity { get; set; }
    public string SourceLocationId { get; set; }
    public string DestLocationId { get; set; }
}
