class_name ArmorFactory


const ARMORS: Registry = preload("res://resources/registries/armor_registry.tres")

static var _cached_key = SquadBattleTypes.ArmorClasses.keys()

static func get_armor(_armor: SquadBattleTypes.ArmorClasses) -> SquadArmor:
	var id: String = _cached_key[_armor].to_snake_case()
	var armor_template := ARMORS.load_entry(id) as ArmorConfig
	assert(armor_template != null, "Armor not registered in armor_registry.tres: %s" % id)
	var armor_conf = armor_template.duplicate(true)
	var armor = SquadArmor.new(armor_conf)
	return armor
