class_name WeaponFactory

enum WeaponClasses {
	Unarmed,
	Flammenschwert,
}

static var pathlib = {
	"Unarmed": "res://resources/combat/weapon/unarmed.tres",
	"Flammenschwert": "res://resources/combat/weapon/flammenschwert.tres",
}

static var _cached_key = WeaponClasses.keys()

static func get_weapon(_weapon: WeaponClasses) -> SquadWeapon:
	var path = pathlib.get(_cached_key[_weapon]);
	var weapon_template = load(path)
	assert(weapon_template != null, "Failed to load weapon from path: %s" % path)
	assert(weapon_template is WeaponConfig, "Path %s loaded wrong type; got %s instead of WeaponConfig" % [path, weapon_template.get_class()])
	var weapon_conf = weapon_template.duplicate(true)
	var weapon = SquadWeapon.new(weapon_conf)
	return weapon
