using System;

namespace Condor.Economy;

/// <summary>
/// Matches Demand and Supply orders within a location's tick-local order book.
/// Mirrors the GDScript TradeMatcher pattern but operates on intangible
/// services (Subsistence, Labor, MercenaryWork, BanditSlot, Loan).
///
/// Per-location flow:
///   1. Sort demands desc by priority.
///   2. For each demand, walk supplies of matching ServiceType, fulfill greedily.
///   3. Apply service-specific side-effects (loan issuance, bandit pool growth, etc.).
///
/// Subsistence is matched separately by the engine because it bypasses the
/// order book entirely (farmers self-feed).
/// </summary>
public sealed class CsOrderMatcher
{
    public void Match(CsLocationData loc, EconomyContext ctx)
    {
        if (loc.Demands.Count == 0) return;
        loc.Demands.Sort((a, b) => b.Priority.CompareTo(a.Priority));

        for (int di = 0; di < loc.Demands.Count; di++)
        {
            var demand = loc.Demands[di];
            if (demand.Quantity <= 0f) continue;

            for (int si = 0; si < loc.Supplies.Count; si++)
            {
                var supply = loc.Supplies[si];
                if (supply.Service != demand.Service) continue;
                if (supply.Quantity <= 0f) continue;

                float qty = MathF.Min(demand.Quantity, supply.Quantity);
                Execute(demand, supply, qty, ctx);
                demand.Quantity -= qty;
                supply.Quantity -= qty;

                if (demand.Quantity <= 0f) break;
            }
        }
    }

    private static void Execute(CsOrder demand, CsOrder supply, float qty, EconomyContext ctx)
    {
        switch (demand.Service)
        {
            case ServiceType.Loan:
                {
                    var imperial = supply.GovernmentActor;
                    var noble = demand.PersonActor;
                    if (imperial == null || noble == null) return;
                    if (!imperial.IsImperial) return;
                    imperial.IssueLoan(noble, qty, ctx.CurrentTurn);
                    break;
                }
            case ServiceType.BanditSlot:
                if (supply.GeistActor != null)
                    supply.GeistActor.BanditPoolSize += (int)MathF.Ceiling(qty);
                break;
            case ServiceType.Labor:
            case ServiceType.MercenaryWork:
            case ServiceType.Subsistence:
                // Diagnostic-only: side-effects already applied during GenerateOrders
                // (Government/Guild hire workers directly), or handled outside the
                // order book (Subsistence in engine, MercenaryWork on GDScript side).
                break;
        }
    }
}
