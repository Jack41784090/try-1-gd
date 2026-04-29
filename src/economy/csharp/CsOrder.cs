namespace Condor.Economy;

/// <summary>
/// A single supply or demand order in the unified order book. Orders are
/// emitted by actors (Person, Government, Geist, Guild, NaturalResource)
/// during PhaseGenerateOrders, then matched in PhaseMatchOrders.
///
/// For tangible goods (Category=Good), the order references a ThingDef via
/// ThingIdx and Service=None. For intangibles (Category=Service), ThingIdx
/// is -1 and Service indicates the kind. This avoids polluting the .tres-driven
/// Goods array with synthetic services while still routing both through one
/// pipeline.
/// </summary>
public sealed class CsOrder
{
    public OrderSide Side;
    public ThingCategory Category;
    public ServiceType Service;
    public int ThingIdx = -1;
    public float Quantity;
    public float UnitPrice;
    public float Priority;
    public int LocationIdx;
    public string Tag;

    // Issuing actor — one of these is populated for callbacks during execution.
    public CsPerson PersonActor;
    public CsGovernment GovernmentActor;
    public CsGuild GuildActor;
    public CsGeist GeistActor;

    public static CsOrder Demand(int locationIdx, ServiceType service, float qty, float priority,
        CsPerson personActor = null, CsGovernment govActor = null, CsGeist geistActor = null,
        CsGuild guildActor = null, float unitPrice = 0f, string tag = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Demand,
            Category = ThingCategory.Service,
            Service = service,
            Quantity = qty,
            UnitPrice = unitPrice,
            Priority = priority,
            LocationIdx = locationIdx,
            PersonActor = personActor,
            GovernmentActor = govActor,
            GeistActor = geistActor,
            GuildActor = guildActor,
            Tag = tag,
        };
    }

    public static CsOrder Supply(int locationIdx, ServiceType service, float qty, float priority,
        CsPerson personActor = null, CsGovernment govActor = null, CsGeist geistActor = null,
        CsGuild guildActor = null, float unitPrice = 0f, string tag = null)
    {
        return new CsOrder
        {
            Side = OrderSide.Supply,
            Category = ThingCategory.Service,
            Service = service,
            Quantity = qty,
            UnitPrice = unitPrice,
            Priority = priority,
            LocationIdx = locationIdx,
            PersonActor = personActor,
            GovernmentActor = govActor,
            GeistActor = geistActor,
            GuildActor = guildActor,
            Tag = tag,
        };
    }
}
