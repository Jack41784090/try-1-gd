@tool
class_name CombatEntityResource extends Resource

## `identification` is a live dropdown (see _get_property_list) whose options are
## scanned from CombatEntityFactory's folder, so it auto-updates as templates are
## added/removed. Not @export — the property list supplies the PROPERTY_HINT_ENUM.
var identification: String = ""

@export var codename: String
@export var stats: CombatEntityBaseStats
@export var icon: Texture2D
@export var weapon_class: WeaponResource
@export var armor_class: ArmorConfig
@export var logic_config: SimplifiedLogicConfig
@export var innate_skills: Array[Skill]


## Exposes `identification` as a live PROPERTY_HINT_ENUM dropdown sourced from the
## on-disk template folder (CombatEntityFactory), mirroring the rig config scene.
## Requires @tool so the editor inspector queries it.
func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "identification",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			# Leading comma = a blank "(none)" option.
			"hint_string": "," + ",".join(CombatEntityFactory.available_identifications()),
		},
	]
