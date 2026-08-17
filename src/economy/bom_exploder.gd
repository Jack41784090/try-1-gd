extends RefCounted
class_name BomExploder

## Recursively flattens a crafted Thing's BOM (Thing.inputs) down to true
## leaf goods (things whose own .inputs is empty), multiplying quantities
## through every level. Pure function, no Location/guild coupling — reused
## by both explode_boms() (derived per-hour demand) and produce_crafted()
## (per-unit leaf requirement used to cap output by ACTUAL secured input).
##
## Deliberate simplification for this prototype: a multi-level chain (good
## needing another crafted good as input) is flattened straight to raw
## leaves and the TOP-level guild converts secured leaves directly into its
## output in one step — there is no separate intermediate-good production/
## settlement pass. This is sufficient to fix the priority-competition bug
## (the thing under test) without modeling a full multi-stage work-order
## system; the synthetic demo data is 2-level (Iron Sword/Hoe from raw Iron+
## Wood) so this collapse is behaviorally invisible there, but the function
## itself is written to recurse correctly to arbitrary depth.
static func flatten(thing: Thing, qty: float, out: Dictionary = {}) -> Dictionary:
	for input in thing.inputs:
		var needed: float = input.quantity * qty
		if input.thing.inputs.is_empty():
			out[input.thing] = out.get(input.thing, 0.0) + needed
		else:
			flatten(input.thing, needed, out)
	return out
