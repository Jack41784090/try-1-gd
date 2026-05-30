using System;

namespace Condor.Economy;

public sealed class CsOrderMatcher
{
    public void Match(CsLocationData loc, EconomyContext ctx)
    {
        if (loc.Demands.Count == 0 || loc.Supplies.Count == 0) return;

        loc.Demands.Sort((a, b) => b.Priority.CompareTo(a.Priority));

        for (int di = 0; di < loc.Demands.Count; di++)
        {
            var demand = loc.Demands[di];
            if (demand.Quantity <= 0f) continue;

            for (int si = 0; si < loc.Supplies.Count; si++)
            {
                var supply = loc.Supplies[si];
                if (supply.Quantity <= 0f) continue;
                if (!IsCompatible(demand, supply)) continue;

                float qty = ExecuteMatch(demand, supply, MathF.Min(demand.Quantity, supply.Quantity), loc, ctx);
                demand.Quantity -= qty;
                supply.Quantity -= qty;

                if (demand.Quantity <= 0f) break;
            }
        }
    }

    private static bool IsCompatible(CsOrder demand, CsOrder supply)
    {
        if (demand.Category != supply.Category) return false;

        if (demand.Category == ThingCategory.Good)
            return demand.ThingIdx == supply.ThingIdx;

        return demand.Service == supply.Service;
    }

    private static float ExecuteMatch(CsOrder demand, CsOrder supply, float qty, CsLocationData loc, EconomyContext ctx)
    {
        switch (demand.Category)
        {
            case ThingCategory.Good:
                return ExecuteGoodTrade(demand, supply, qty, loc);
            case ThingCategory.Service:
                return ExecuteServiceByType(demand, supply, qty, loc, ctx);
        }
        return 0f;
    }

    private static float ExecuteGoodTrade(CsOrder demand, CsOrder supply, float qty, CsLocationData loc)
    {
        float price = supply.UnitPrice;

        if (demand.PersonActor != null)
        {
            float affordable = demand.PersonActor.CanAfford(price, qty);
            if (affordable > 0f)
            {
                demand.PersonActor.Buy(demand.ThingIdx, affordable, price);
                qty = affordable;
            }
        }

        if (qty > 0f)
        {
            loc.Consume(demand.ThingIdx, qty);
            double revenue = qty * price;
            supply.IssuerActor?.ReceiveRevenue(revenue);
        }

        return qty;
    }

    private static float ExecuteServiceByType(CsOrder demand, CsOrder supply, float qty, CsLocationData loc, EconomyContext ctx)
    {
        switch (demand.Service)
        {
            case ServiceType.Subsistence:
                return ExecuteSubsistence(demand, supply, qty, loc);
            case ServiceType.Labor:
                return ExecuteLabor(demand, supply, qty, loc);
            case ServiceType.MercenaryWork:
                return ExecuteMercenaryWork(demand, supply, qty, loc, ctx);
            case ServiceType.BanditSlot:
                return ExecuteBanditSlot(demand, supply, qty, loc);
            case ServiceType.Loan:
                return ExecuteLoan(demand, supply, qty, loc, ctx);
            default:
                return qty;
        }
    }

    private static float ExecuteSubsistence(CsOrder demand, CsOrder supply, float qty, CsLocationData loc)
    {
        return qty;
    }

    private static float ExecuteLabor(CsOrder demand, CsOrder supply, float qty, CsLocationData loc)
    {
        if (demand.IssuerActor is CsGuild guild)
            guild.Recruit(supply.PersonActor, demand.Tag);
        return qty;
    }

    private static float ExecuteMercenaryWork(CsOrder demand, CsOrder supply, float qty, CsLocationData loc, EconomyContext ctx)
    {
        return qty;
    }

    private static float ExecuteBanditSlot(CsOrder demand, CsOrder supply, float qty, CsLocationData loc)
    {
        return qty;
    }

    private static float ExecuteLoan(CsOrder demand, CsOrder supply, float qty, CsLocationData loc, EconomyContext ctx)
    {
        return qty;
    }
}
