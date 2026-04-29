namespace Condor.Economy;

public enum SocialClass
{
    Peasant,
    Bourgeois,
    Noble,
}

public enum JobType
{
    Farmer,
    Merchant,
    Landlord,
    Craftsman,
    Laborer,
    Servant,
    TaxCollector,
    Unemployed,
}

public enum MoveState
{
    Planned,
    InTransit,
    Completed,
    Cancelled,
    Captured,
}

public enum RuleAction
{
    Extract,
    Produce,
    Import,
}

public enum ThingType
{
    Food,
    Money,
    Cloth,
    Tools,
    Luxury,
    Weapons,
}

public enum ContractType
{
    Construction,
    LuxuryGoods,
    MilitarySupply,
    FoodSupply,
}

/// <summary>
/// Distinguishes tangible goods (carried in inventory, transported by caravans,
/// can spoil) from intangible services (resolved within a tick, not stored).
/// </summary>
public enum ThingCategory
{
    Good,
    Service,
}

/// <summary>
/// Service kinds traded through the order book without an associated ThingDef.
/// None means the order references a real ThingDef (a Good).
/// </summary>
public enum ServiceType
{
    None,
    Subsistence,    // Farmer→Self food channel, resolved before market
    Labor,          // Government / employer hiring workers
    MercenaryWork,  // Bandit-suppression contracts
    BanditSlot,     // Geist recruiting villagers into banditry
    Loan,           // Imperial bank → noble debt issuance
}

public enum OrderSide
{
    Supply,
    Demand,
}
