using System;

namespace Condor.Economy;

/// <summary>
/// Lightweight per-person decision-making. Each social class gets a brain
/// subclass that evaluates actions the person *might* take during a tick.
/// Brains are stateless — all context comes from the person + location.
/// </summary>
public abstract class PersonBrain
{
    /// <summary>
    /// Run this person's decision-making for the current tick.
    /// Called once per tick from PhasePersonDecisions.
    /// </summary>
    public abstract void Think(CsPerson person, CsLocationData location, EconomyContext ctx);
}

/// <summary>
/// Shared context passed to all brains during a tick. Avoids passing
/// the entire engine — brains see only what they need.
/// </summary>
public sealed class EconomyContext
{
    public int CurrentTurn { get; set; }
    public CsCentralBank Bank { get; set; }
    public ThingDef[] Goods { get; set; }
    public float NobleLoanThreshold { get; set; }
    public float LoanAmount { get; set; }
    public Random Rng { get; set; }
}

/// <summary>
/// Noble brain: decides whether to apply for loans based on financial
/// situation rather than automatic threshold checks every turn.
/// </summary>
public sealed class NobleBrain : PersonBrain
{
    private const int LoanCooldownTurns = 5;

    public override void Think(CsPerson person, CsLocationData location, EconomyContext ctx)
    {
        if (ctx.Bank == null) return;
        EvaluateLoanApplication(person, location, ctx);
    }

    private static void EvaluateLoanApplication(CsPerson person, CsLocationData location, EconomyContext ctx)
    {
        // Cooldown: don't spam loan applications
        if (ctx.CurrentTurn - person.LastLoanTurn < LoanCooldownTurns) return;

        // Score the desirability of taking a loan (0-1)
        float score = 0f;

        // Factor 1: How broke are we? (0-1, higher = more desperate)
        float moneyRatio = person.Money / MathF.Max(ctx.NobleLoanThreshold, 1f);
        if (moneyRatio >= 1.5f) return; // Flush with cash — no loan needed
        float desperation = 1f - Math.Clamp(moneyRatio, 0f, 1f);
        score += desperation * 0.4f;

        // Factor 2: Low satisfaction signals trouble (hungry, no comfort)
        float satisfactionPressure = 1f - Math.Clamp(person.Satisfaction / 100f, 0f, 1f);
        score += satisfactionPressure * 0.25f;

        // Factor 3: Local economy health — high food prices signal crisis
        float foodPressure = 0f;
        for (int gi = 0; gi < ctx.Goods.Length; gi++)
        {
            if (ctx.Goods[gi].ThingType != ThingType.Food) continue;
            float priceRatio = location.Prices[gi] / MathF.Max(ctx.Goods[gi].BasePrice, 0.01f);
            foodPressure = Math.Clamp((priceRatio - 1f) * 0.5f, 0f, 1f);
            break;
        }
        score += foodPressure * 0.15f;

        // Factor 4: Existing debt dampens enthusiasm for more loans
        float existingDebt = 0f;
        foreach (var loan in ctx.Bank.ActiveLoans)
        {
            if (loan.Debtor.InternalId == person.InternalId)
                existingDebt += loan.TotalOwed;
        }
        float debtPenalty = Math.Clamp(existingDebt / (ctx.LoanAmount * 2f), 0f, 1f);
        score -= debtPenalty * 0.3f;

        // Factor 5: Risk tolerance — some nobles are more cautious
        // Use personId hash as stable personality trait
        float riskTolerance = ((person.InternalId * 2654435761u) & 0xFF) / 255f;
        float threshold = 0.3f + (1f - riskTolerance) * 0.3f; // 0.3-0.6 range

        if (score >= threshold)
            ctx.Bank.IssueLoan(person, ctx.LoanAmount, ctx.CurrentTurn);
    }
}

/// <summary>
/// Default brain for non-noble classes. Currently a no-op — exists so the
/// brain system is extensible without null checks everywhere.
/// </summary>
public sealed class CommonBrain : PersonBrain
{
    public static readonly CommonBrain Instance = new();

    public override void Think(CsPerson person, CsLocationData location, EconomyContext ctx)
    {
        // Future: peasant job-switching, merchant route preferences, etc.
    }
}
