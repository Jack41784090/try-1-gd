extends Resource
class_name Thing

@export var thing_id: String = ""
@export var thing_name: String = ""
@export var thing_type: EconomyTypes.ThingType = EconomyTypes.ThingType.FOOD
@export var base_price: float = 1.0
@export var description: String = ""
@export var inputs: Array[ThingInput] = []
@export var elasticity: float = -1.0
@export var weapon_config: WeaponResource

static func create(id: String, p_name: String, p_type: EconomyTypes.ThingType, price: float = 1.0, p_description: String = "", p_inputs: Array[ThingInput] = [], p_elasticity: float = -1.0, p_weapon_config: WeaponResource = null) -> Thing:
	var t := Thing.new()
	t.thing_id = id
	t.thing_name = p_name
	t.thing_type = p_type
	t.base_price = price
	t.description = p_description
	t.inputs = p_inputs
	t.elasticity = p_elasticity
	t.weapon_config = p_weapon_config
	return t

func get_elasticity() -> float:
	if elasticity >= 0.0:
		return elasticity
	match thing_type:
		EconomyTypes.ThingType.FOOD:
			return 0.1
		EconomyTypes.ThingType.CLOTH:
			return 0.4
		EconomyTypes.ThingType.TOOLS:
			return 0.3
		EconomyTypes.ThingType.LUXURY:
			return 0.8
		EconomyTypes.ThingType.WEAPONS:
			return 0.5
	return 0.3

func get_label() -> String:
	if thing_name != "":
		return thing_name
	return EconomyTypes.ThingType.keys()[thing_type].capitalize()

func _to_string() -> String:
	return thing_name
