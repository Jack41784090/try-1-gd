namespace Condor.Economy;

/// <summary>
/// Lightweight value-type identifier for a goods type.
/// The C# engine uses int IDs internally; mapping to GDScript Thing Resources
/// happens at the bridge boundary.
/// </summary>
public sealed class ThingDef
{
    public int Id { get; }
    public string ThingId { get; }
    public string ThingName { get; }
    public ThingType ThingType { get; }
    public float BasePrice { get; }

    public ThingDef(int id, string thingId, string thingName, ThingType thingType, float basePrice)
    {
        Id = id;
        ThingId = thingId;
        ThingName = thingName;
        ThingType = thingType;
        BasePrice = basePrice;
    }

    public override string ToString() => ThingName;
}
