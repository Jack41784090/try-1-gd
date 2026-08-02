@tool
class_name StrategyEntity
extends Resource

@export var display_name: String
@export var resource: StrategyEntityResource:
	set(value):
		if resource == value:
			return
		resource = value
		_reinit()
@export_tool_button("Rebuild stats", "Reload") var rebuild: Callable = _reinit
@export var rs_arr: Dictionary[StatName.I, ReactiveStat] = {}
@export var is_dead: bool = false
@export var is_injured: bool = false
@export var location_prebattle: SquadBattleTypes.SquadEntityInSquadLocation = SquadBattleTypes.SquadEntityInSquadLocation.Front
@export var id: String = ""


func _init(_resource: StrategyEntityResource = null) -> void:
	id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	resource = _resource
	_reinit()


func _reinit() -> void:
	display_name = resource.name if resource else "Unnamed"
	var rebuilt: Dictionary[StatName.I, ReactiveStat] = {}
	if resource:
		for rs in resource.rs_array:
			var dup: ReactiveStat = rs.duplicate(true)
			dup.changed.connect(_on_rs_changed)
			rebuilt[rs.stat_name] = dup
	rs_arr = rebuilt
	emit_changed()
	notify_property_list_changed.call_deferred()


func _on_rs_changed(...any) -> void:
	emit_changed()


func get_stat(key: StatName.I) -> ReactiveStat:
	return rs_arr.get(key)


func get_stat_value(key: StatName.I) -> Variant:
	var s := get_stat(key)
	return s.stat_value if s else null


func modify_morale(amount: float) -> void:
	var m := get_stat(StatName.I.MORALE)
	m.stat_value = clamp(m.stat_value + amount, 0.0, 1.0)


func get_equipped_weapon() -> WeaponResource:
	return get_stat_value(StatName.I.WEAPON)


func get_equipped_armor() -> ArmorConfig:
	return get_stat_value(StatName.I.ARMOUR)


func equip_weapon(w: WeaponResource) -> void:
	get_stat(StatName.I.WEAPON).stat_value = w


func unequip_weapon() -> WeaponResource:
	var old = get_equipped_weapon()
	get_stat(StatName.I.WEAPON).stat_value = null
	return old


func equip_armor(a: ArmorConfig) -> void:
	get_stat(StatName.I.ARMOUR).stat_value = a


func unequip_armor() -> ArmorConfig:
	var old = get_equipped_armor()
	get_stat(StatName.I.ARMOUR).stat_value = null
	return old


func get_speed_kmh() -> float:
	return float(get_stat_value(StatName.I.MV_SPD))


func check_religion(religion_type: StrategyTypes.Religion) -> bool:
	return resource.religion == religion_type


func get_demand() -> Dictionary:
	return {
		StrategyTypes.SquadProperty.FOOD_SUPPLIES: 5,
	}


func get_attribute(_attribute: StrategyTypes.WarriorAttribute) -> int:
	assert(false, "StrategyEntity.get_attribute not implemented")
	return 0


func set_attribute(_attribute: StrategyTypes.WarriorAttribute, _value: int) -> void:
	assert(false, "StrategyEntity.set_attribute not implemented")
