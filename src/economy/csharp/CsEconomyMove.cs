using System;

namespace Condor.Economy;

public sealed class CsEconomyMove
{
    public int ThingIdx { get; set; }
    public float Quantity { get; set; }
    public int SourceLocationIdx { get; set; }
    public int DestLocationIdx { get; set; }
    public MoveState State { get; set; } = MoveState.Planned;
    public int TurnsRemaining { get; set; } = 1;
    public string Origin { get; set; } = "";

    // For bridge output — string IDs matching GDScript side
    public string SourceLocationId { get; set; } = "";
    public string DestLocationId { get; set; } = "";
    public string ThingId { get; set; } = "";

    public bool Advance()
    {
        if (State != MoveState.InTransit) return false;
        TurnsRemaining--;
        if (TurnsRemaining <= 0)
        {
            State = MoveState.Completed;
            return true;
        }
        return false;
    }

    public void Start() => State = MoveState.InTransit;
    public void Cancel() => State = MoveState.Cancelled;
    public bool IsActive() => State == MoveState.InTransit || State == MoveState.Planned;

    public static CsEconomyMove Create(
        int thingIdx, float qty, int fromIdx, int toIdx,
        int travelTurns, string origin,
        string sourceId, string destId, string thingId)
    {
        return new CsEconomyMove
        {
            ThingIdx = thingIdx,
            Quantity = qty,
            SourceLocationIdx = fromIdx,
            DestLocationIdx = toIdx,
            TurnsRemaining = travelTurns,
            Origin = origin,
            State = MoveState.InTransit,
            SourceLocationId = sourceId,
            DestLocationId = destId,
            ThingId = thingId,
        };
    }
}
