extends RefCounted
class_name BomExploder

## Deliberate simplification: a multi-level chain is flattened straight to raw leaves in one step, with no intermediate-good production/settlement pass — sufficient for this prototype's 2-level demo data, though the function itself recurses correctly to arbitrary depth.
static func flatten(thing: Thing, qty: float, out: Dictionary = {}) -> Dictionary:
	for input in thing.inputs:
		var needed: float = input.quantity * qty
		if input.thing.inputs.is_empty():
			out[input.thing] = out.get(input.thing, 0.0) + needed
		else:
			flatten(input.thing, needed, out)
	return out
