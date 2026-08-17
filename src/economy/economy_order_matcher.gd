extends RefCounted
class_name EconomyOrderMatcher

## Priority-sorted greedy demand/supply matcher — GDScript port of
## CsOrderMatcher.Match's shape (src/economy/csharp/CsOrderMatcher.cs:7-31),
## used by BOTH settle_base and settle_finished. This is the single unified
## pass that fixes the "hard knot" bug: consumer demand for a raw good and
## crafting-guild derived demand for that same good are both just
## EconomyOrder entries in the same array by the time this runs, so they
## compete on `.priority` alone — there is no longer a separate, unordered
## mechanism for either side.
##
## Tie-break note: ties in priority break by post-sort array order, same
## caveat CsOrderMatcher.Match itself has (Array.sort_custom is not
## guaranteed stable). This is intentional and NOT a regression: the bug
## this fixes was demand that never entered ANY priority-sorted pass at
## all, not tie-breaking within one already-sorted pass.
static func match(demands: Array[EconomyOrder], supplies: Array[EconomyOrder], loc: Location) -> Dictionary:
	var sorted_demands := demands.duplicate()
	sorted_demands.sort_custom(func(a: EconomyOrder, b: EconomyOrder) -> bool: return a.priority > b.priority)

	var filled: Dictionary = {}   # Thing -> float
	var unmet: Dictionary = {}    # Thing -> float

	for demand in sorted_demands:
		if demand.quantity <= 0.0:
			continue
		for supply in supplies:
			if supply.quantity <= 0.0 or supply.thing != demand.thing:
				continue
			var qty: float = minf(demand.quantity, supply.quantity)
			loc.inventory.consume(demand.thing, qty)
			demand.quantity -= qty
			supply.quantity -= qty
			filled[demand.thing] = filled.get(demand.thing, 0.0) + qty
			if demand.quantity <= 0.0:
				break
		if demand.quantity > 0.0:
			unmet[demand.thing] = unmet.get(demand.thing, 0.0) + demand.quantity

	return {"filled": filled, "unmet": unmet}
