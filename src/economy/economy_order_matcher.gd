extends RefCounted
class_name EconomyOrderMatcher

## Fixes the "hard knot" bug: consumer demand and crafting-guild derived demand for the same good are both just EconomyOrder entries here, competing on `.priority` alone instead of via separate unordered mechanisms.
## Tie-break note: ties break by post-sort array order (sort_custom isn't guaranteed stable) — intentional, since the fixed bug was demand skipping the priority pass entirely, not tie-breaking within it.
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
