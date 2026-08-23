extends Resource
class_name CraftingGuild

## Deliberately does NOT model workers/wages (no Population wired into this prototype). Distinct from GuildSpecialization/GuildConfig, which configure the real C# engine's guild setup.

@export var guild_id: String = ""
@export var output_thing: Thing
@export var max_capacity: float = 10.0   ## max units/hour this guild could make if fully supplied
@export var priority: float = 5.0        ## inherited verbatim by every exploded/derived demand order this guild's intent spawns

var treasury: float = 0.0
var produced_last_tick: float = 0.0
var sold_last_tick: float = 0.0
var secured_last_tick: Dictionary = {}   ## Thing -> float, populated each tick by LocationEconomySystem._produce_crafted

static func create(id: String, thing: Thing, capacity: float, p_priority: float) -> CraftingGuild:
	var g := CraftingGuild.new()
	g.guild_id = id
	g.output_thing = thing
	g.max_capacity = capacity
	g.priority = p_priority
	return g
