using System;

namespace Condor.Economy;

/// <summary>
/// Per-location cultural / preternatural state. Sibling of CsGovernment:
/// where Government tracks money, taxes, and material directives, Geist
/// tracks intangibles — desperation, cohesion, piety, propensity for banditry.
///
/// Drives bandit recruitment supply (replaces GDScript BanditSpawner pressure
/// calculation) and biases luxury demand during cultural peaks.
///
/// State updates each tick from population aggregates (PhasePostUpdate),
/// using EMA smoothing to prevent whiplash.
/// </summary>
public sealed class CsGeist
{
    public int LocationIndex { get; set; }
    public string LocationId { get; set; } = "";

    // 0..1 normalized state
    public float Desperation { get; set; }
    public float CulturalCohesion { get; set; } = 0.5f;
    public float BanditAffinity { get; set; } = 0.5f;
    public float Piety { get; set; } = 0.5f;
    public float LuxuryDemandBias { get; set; } = 1.0f;

    // Running count of villagers committed to banditry but not yet materialized
    // as combat squads. GDScript BanditSpawner reads this to decide spawn rate.
    public int BanditPoolSize { get; set; }

    // Smoothed desperation across recent ticks (EMA, alpha=0.2)
    private float _smoothedDesperation;
    public float SmoothedDesperation => _smoothedDesperation;

    // Last-tick diagnostics for bridge exports
    public float LastBanditSlotsEmitted { get; set; }
    public float LastSpawnRecommendation { get; set; }

    /// <summary>
    /// Recompute desperation from population aggregates. Called in PhasePostUpdate.
    /// </summary>
    public void UpdateState(CsLocationData loc, ThingDef[] goods)
    {
        var pop = loc.Population;
        if (pop.Size() == 0)
        {
            _smoothedDesperation = 0f;
            Desperation = 0f;
            return;
        }

        float avgSat = pop.GetAverageSatisfaction();
        int peasantCount = pop.GetByClass(SocialClass.Peasant).Count;
        float peasantRatio = (float)peasantCount / MathF.Max(pop.Size(), 1);

        // Population scale: small villages → less raw desperation than cities
        float popScale = Math.Clamp(MathF.Sqrt(pop.Size() / 200f), 0.5f, 2.0f);

        float satPressure = 1f - Math.Clamp(avgSat / 100f, 0f, 1f);

        // Food price stress amplifies desperation
        float foodStress = 0f;
        for (int gi = 0; gi < goods.Length; gi++)
        {
            if (goods[gi].ThingType != ThingType.Food) continue;
            float ratio = loc.Prices[gi] / MathF.Max(goods[gi].BasePrice, 0.01f);
            foodStress = Math.Clamp((ratio - 1f) * 0.5f, 0f, 1f);
            break;
        }

        float raw = satPressure * peasantRatio * popScale + foodStress * 0.3f;
        raw = Math.Clamp(raw, 0f, 1f);

        // EMA smoothing — desperation builds and fades over ~5 ticks
        _smoothedDesperation = _smoothedDesperation * 0.8f + raw * 0.2f;
        Desperation = _smoothedDesperation;
    }

    /// <summary>
    /// Emit BanditSlot supply orders proportional to desperation. The supply
    /// represents desperate villagers willing to leave the local economy and
    /// join banditry. The strategic layer (GDScript BanditSpawner) reads
    /// engine.GetBanditPressure(loc) and converts pool growth into squads.
    /// </summary>
    public void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        LastBanditSlotsEmitted = 0f;
        LastSpawnRecommendation = 0f;

        if (Desperation < 0.2f) return;

        float supply = Desperation * BanditAffinity * 5f;
        if (supply <= 0f) return;

        loc.Supplies.Add(CsOrder.Supply(
            LocationIndex, ServiceType.BanditSlot, supply,
            priority: 3f, geistActor: this, tag: "geist_bandit_recruits"));
        LastBanditSlotsEmitted = supply;

        // Spawn recommendation: monotonic growth above threshold; mirrors
        // GDScript BanditSpawner.should_spawn semantics.
        if (Desperation > 0.3f)
            LastSpawnRecommendation = (Desperation - 0.3f) * 0.5f * BanditAffinity;
    }
}
