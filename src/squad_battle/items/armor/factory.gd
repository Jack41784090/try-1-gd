class_name ArmorFactory


static var pathlib = {
	"Unarmored": "res://resources/combat/armor/unarmored.tres",
	"LeatherArmor": "res://resources/combat/armor/leather-armor.tres",
	"PaddedArmor": "res://resources/combat/armor/padded-armor.tres",
	"HalfPlate": "res://resources/combat/armor/half-plate.tres",
}

static var _cached_key = SquadBattleTypes.ArmorClasses.keys()

static func get_armor(_armor: SquadBattleTypes.ArmorClasses) -> SquadArmor:
	var path = pathlib.get(_cached_key[_armor]);
	var armor_template = load(path)
	assert(armor_template != null, "Failed to load armor from path: %s" % path)
	assert(armor_template is ArmorConfig, "Path %s loaded wrong type; got %s instead of ArmorConfig" % [path, armor_template.get_class()])
	var armor_conf = armor_template.duplicate(true)
	var armor = SquadArmor.new(armor_conf)
	return armor
