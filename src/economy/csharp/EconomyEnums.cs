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
}

public enum ContractType
{
    Construction,
    LuxuryGoods,
    MilitarySupply,
    FoodSupply,
}
