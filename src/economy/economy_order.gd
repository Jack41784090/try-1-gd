extends RefCounted
class_name EconomyOrder

## `quantity` is decremented in place during matching; `original_quantity` is fixed at creation so later phases can compute how much was actually secured.

var thing: Thing
var quantity: float
var original_quantity: float
var priority: float
var unit_price: float
var source_kind: String        ## "consumer" | "guild_intent" | "guild_derived" | "extraction" | "guild_supply" — debug tag only, not branched on
var guild: CraftingGuild        ## null for plain consumer/extraction orders
var origin_intent: EconomyOrder ## null except on guild_derived orders — back-ref to the guild_intent that spawned it

static func create(p_thing: Thing, p_qty: float, p_priority: float, p_source_kind: String, p_unit_price: float = 0.0, p_guild: CraftingGuild = null, p_origin_intent: EconomyOrder = null) -> EconomyOrder:
	var o := EconomyOrder.new()
	o.thing = p_thing
	o.quantity = p_qty
	o.original_quantity = p_qty
	o.priority = p_priority
	o.unit_price = p_unit_price
	o.source_kind = p_source_kind
	o.guild = p_guild
	o.origin_intent = p_origin_intent
	return o
