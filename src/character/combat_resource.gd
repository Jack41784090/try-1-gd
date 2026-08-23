@tool
class_name CombatEntityResource
extends Resource

## Not @export — _get_property_list below supplies the live PROPERTY_HINT_ENUM dropdown instead.
var identification: String = ""

@export var codename: String
@export var icon: Texture2D
@export var weapon_class: WeaponResource
@export var armor_class: ArmorConfig
@export var logic_config: SimplifiedLogicConfig
@export var personal_rules: Array[Consideration] = []
@export var rs_array: Array[ReactiveStat] = []   ## 12 base-attribute ReactiveStats, inline per-class


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "identification",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			## Leading comma = a blank "(none)" option.
			"hint_string": "," + ",".join(CombatEntityFactory.available_identifications()),
		},
	]


func get_stat(key: StatName.I) -> ReactiveStat:
	for rs in rs_array:
		if rs.stat_name == key:
			return rs
	return null


func get_stat_value(key: StatName.I) -> Variant:
	var s := get_stat(key)
	return s.stat_value if s else null
