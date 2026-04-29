namespace Condor.Economy;

public struct RecipeInput
{
    public int ThingIdx;
    public float Quantity;
}

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
    public RecipeInput[] Inputs { get; set; } = System.Array.Empty<RecipeInput>();
    public float Elasticity { get; set; }
    public ThingCategory Category { get; set; } = ThingCategory.Good;

    public ThingDef(int id, string thingId, string thingName, ThingType thingType, float basePrice)
    {
        Id = id;
        ThingId = thingId;
        ThingName = thingName;
        ThingType = thingType;
        BasePrice = basePrice;
        Elasticity = DefaultElasticity(thingType);
    }

    public static float DefaultElasticity(ThingType type) => type switch
    {
        ThingType.Food => 0.1f,
        ThingType.Cloth => 0.4f,
        ThingType.Tools => 0.3f,
        ThingType.Luxury => 0.8f,
        ThingType.Weapons => 0.5f,
        _ => 0.3f,
    };

    public override string ToString() => ThingName;
}
