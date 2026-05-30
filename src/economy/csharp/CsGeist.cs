using System;

namespace Condor.Economy;

public sealed class CsGeist : CsEconomyActor
{
    public int LocationIndex { get; set; }
    public string LocationId { get; set; } = "";

    public float Desperation { get; set; }
    public float CulturalCohesion { get; set; } = 0.5f;
    public float BanditAffinity { get; set; } = 0.5f;
    public float Piety { get; set; } = 0.5f;
    public float LuxuryDemandBias { get; set; } = 1.0f;

    public int BanditPoolSize { get; set; }

    private float _smoothedDesperation;
    public float SmoothedDesperation => _smoothedDesperation;

    public float LastBanditSlotsEmitted { get; set; }
    public float LastSpawnRecommendation { get; set; }

    public override void UpdateState(CsLocationData loc, ThingDef[] goods)
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

        float popScale = Math.Clamp(MathF.Sqrt(pop.Size() / 200f), 0.5f, 2.0f);
        float satPressure = 1f - Math.Clamp(avgSat / 100f, 0f, 1f);

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

        float prev = _smoothedDesperation;
        _smoothedDesperation = _smoothedDesperation * 0.8f + raw * 0.2f;
        Desperation = _smoothedDesperation;

        LogThresholdCrossing(prev, _smoothedDesperation, 0.3f, "unrest");
        LogThresholdCrossing(prev, _smoothedDesperation, 0.5f, "crisis");
        LogThresholdCrossing(prev, _smoothedDesperation, 0.7f, "collapse");
    }

    private void LogThresholdCrossing(float prev, float now, float threshold, string label)
    {
        if (prev < threshold && now >= threshold)
            Godot.GD.Print($"[Geist] {LocationId} -> {label} (desperation={now:F2})");
        else if (prev >= threshold && now < threshold)
            Godot.GD.Print($"[Geist] {LocationId} <- {label} eased (desperation={now:F2})");
    }

    public override void GenerateOrders(CsLocationData loc, EconomyContext ctx)
    {
        // Banditry disabled — will be reimplemented later as actor
    }
}
